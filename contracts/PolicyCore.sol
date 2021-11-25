// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/NaughtyLibrary.sol";
import "./interfaces/IPolicyToken.sol";
import "./interfaces/INaughtyFactory.sol";
import "./interfaces/IPriceGetter.sol";
import "./interfaces/IPolicyCore.sol";

/**
 * @title  PolicyCore
 * @notice Core logic of Naughty Price Product
 *         Preset:
 *              (Done in the naughtyFactory contract)
 *              1. Deploy policyToken contract
 *              2. Deploy policyToken-Stablecoin pool contract
 *         User Interaction:
 *              1. Deposit Stablecoin and mint PolicyTokens
 *              2. Redeem their Stablecoin and burn the PolicyTokens (before settlement)
 *              3. Claim for payout with PolicyTokens (after settlement)
 *         PolicyTokens are minted with the ratio 1:1 to Stablecoin
 *         The PolicyTokens are traded in the pool with CFMM (xy=k)
 *         When the event happens, a PolicyToken can be burned for claiming 1 Stablecoin.
 *         When the event does not happen, the PolicyToken depositors can
 *         redeem their 1 deposited Stablecoin
 * @dev    Most of the functions to be called from outside will use the name of policyToken
 *         rather than the address(easy to read).
 *         Other variables or functions still use address to index.
 *         The rule of policyToken naming is Original Token Name + Strike Price + Lower or Higher + Date
 *         E.g.  AVAX30L202101, BTC30000L202102, ETH8000H202109
 */
contract PolicyCore is IPolicyCore {
    using SafeERC20 for IERC20;

    // Factory contract, responsible for deploying new contracts
    INaughtyFactory public factory;

    // Oracle contract, responsible for getting the final price
    IPriceGetter public priceGetter;

    // Lottery address
    address public lottery;

    // Owner address
    address public owner;

    // Current distribution index
    uint256 public currentDistributionIndex;

    // Policy toke name => Policy token information
    mapping(string => PolicyTokenInfo) policyTokenInfoMapping;

    mapping(address => string) policyTokenAddressToName;

    // Policy token name list
    string[] allPolicyTokens;

    // Stablecoin address => Supported or not
    mapping(address => bool) stablecoin;

    // Policy token address => Stablecoin address
    mapping(address => address) whichStablecoin;

    // PolicyToken => Strike Token (e.g. AVAX30L202101 address => AVAX address)
    mapping(address => address) policyTokenToOriginal;

    // User Address => Token Address => User Quota Amount
    mapping(address => mapping(address => uint256)) userQuota;

    // Policy token address => All the depositors for this round (store all the depositors in an array)
    mapping(address => address[]) public allDepositors;

    struct SettlementInfo {
        int256 price;
        bool isHappened;
        bool alreadySettled;
    }
    // Policy token address => Settlement result information
    mapping(address => SettlementInfo) settleResult;

    /**
     * @notice Constructor, for some addresses
     * @param _usdt USDT is the first stablecoin supported in the pool
     * @param _factory Address of naughty factory
     * @param _priceGetter Address of the oracle contract
     */
    constructor(
        address _usdt,
        address _factory,
        address _priceGetter
    ) {
        stablecoin[_usdt] = true;

        factory = INaughtyFactory(_factory);
        priceGetter = IPriceGetter(_priceGetter);

        owner = msg.sender;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************** Modifiers *************************************** //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Only the owner can call some functions
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    /**
     * @notice Check if this stablecoin is supported
     * @param _stablecoin Stablecoin address
     */
    modifier supportedStablecoin(address _stablecoin) {
        require(
            stablecoin[_stablecoin] == true,
            "Do not support this stablecoin currently"
        );
        _;
    }

    /**
     * @notice Check if the policy token has been deployed, used when deploying pools
     * @param _policyTokenName Name of the policy token inside the pair
     */
    modifier deployedPolicy(string memory _policyTokenName) {
        require(
            policyTokenInfoMapping[_policyTokenName].policyTokenAddress !=
                address(0),
            "This policy token has not been deployed, please deploy it first"
        );
        _;
    }

    /**
     * @notice Check if there are enough stablecoins in this contract
     * @param _stablecoin Address of the stablecoin
     * @param _amount Amount to be checked
     */
    modifier enoughUSD(address _stablecoin, uint256 _amount) {
        require(
            IERC20(_stablecoin).balanceOf(address(this)) >= _amount,
            "Not sufficient stablecoins in the contract"
        );
        _;
    }

    /**
     * @notice Deposit/Redeem/Swap only before deadline
     * @dev Each pool will also have this deadline
     *      That needs to be set inside naughtyFactory
     * @param _policyTokenName Name of the policy token
     */
    modifier beforeDeadline(string memory _policyTokenName) {
        uint256 deadline = policyTokenInfoMapping[_policyTokenName].deadline;
        require(
            block.timestamp <= deadline,
            "Can not deposit/redeem, has passed the deadline"
        );
        _;
    }

    /**
     * @notice Can only settle the result after the "_settleTimestamp"
     * @param _policyTokenName Name of the policy token
     */
    modifier afterSettlement(string memory _policyTokenName) {
        uint256 settleTimestamp = policyTokenInfoMapping[_policyTokenName]
            .settleTimestamp;
        require(
            block.timestamp >= settleTimestamp,
            "Can not settle/claim, have not reached settleTimestamp"
        );
        _;
    }

    /**
     * @notice Avoid multiple settlements
     * @param _policyTokenName Name of the policy token
     */
    modifier notAlreadySettled(string memory _policyTokenName) {
        address policyTokenAddress = policyTokenInfoMapping[_policyTokenName]
            .policyTokenAddress;
        require(
            settleResult[policyTokenAddress].alreadySettled == false,
            "This policy has already been settled"
        );
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Find the token address by its name
     * @param _policyTokenName Name of the policy token (e.g. "AVAX30L202103")
     * @return policyTokenAddress Address of the policy token
     */
    function findAddressbyName(string memory _policyTokenName)
        external
        view
        returns (address)
    {
        return policyTokenInfoMapping[_policyTokenName].policyTokenAddress;
    }

    /**
     * @notice Find the token name by its address
     * @param _policyTokenAddress Address of the policy token
     * @return policyTokenName Name of the policy token
     */
    function findNamebyAddress(address _policyTokenAddress)
        external
        view
        returns (string memory)
    {
        return policyTokenAddressToName[_policyTokenAddress];
    }

    /**
     * @notice Find the token information by its name
     * @param _policyTokenName Name of the policy token (e.g. "AVAX30L202103")
     * @return policyTokenInfo PolicyToken detail information
     */
    function getPolicyTokenInfo(string memory _policyTokenName)
        external
        view
        returns (PolicyTokenInfo memory)
    {
        return policyTokenInfoMapping[_policyTokenName];
    }

    /**
     * @notice Check if this is a stablecoin address supported, used in naughtyFactory
     * @param _coinAddress Address of the stablecoin
     * @return Whether it is a supported stablecoin
     */
    function isStablecoinAddress(address _coinAddress)
        external
        view
        returns (bool)
    {
        return stablecoin[_coinAddress];
    }

    /**
     * @notice Check a user's quota for a certain policy token
     * @param _userAddress Address of the user to be checked
     * @param _policyTokenAddress Address of the policy token
     * @return _quota User's quota result
     */
    function checkUserQuota(address _userAddress, address _policyTokenAddress)
        external
        view
        returns (uint256 _quota)
    {
        _quota = userQuota[_userAddress][_policyTokenAddress];
    }

    /**
     * @notice Get the information about all the tokens
     * @return tokensInfo Token information list
     */
    function getAllTokens() external view returns (PolicyTokenInfo[] memory) {
        uint256 length = allPolicyTokens.length;
        PolicyTokenInfo[] memory tokensInfo = new PolicyTokenInfo[](length);

        for (uint256 i = 0; i < length; i++) {
            tokensInfo[i] = policyTokenInfoMapping[allPolicyTokens[i]];
        }

        return tokensInfo;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Add a newly supported stablecoin
     * @param _newStablecoin Address of the new stablecoin
     */
    function addStablecoin(address _newStablecoin) external onlyOwner {
        stablecoin[_newStablecoin] = true;
        emit NewStablecoinAdded(_newStablecoin);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Deploy a new policy token and return the token address
     * @dev Only the owner can deploy new policy token
     * @param _policyTokenName Token name of policy token (e.g. "AVAX30L202101")
     * @param _tokenAddress Address of the original token (e.g. AVAX, BTC, ETH...)
     * @param _isCall The policy is for higher or lower than the strike price (call / put)
     * @param _strikePrice Strike price of the policy
     * @param _deadline Deadline of this policy token (deposit / redeem / swap)
     * @param _settleTimestamp Can settle after this timestamp (for oracle)
     * @return policyTokenAddress The address of the policy token just deployed
     */
    function deployPolicyToken(
        string memory _policyTokenName,
        address _tokenAddress,
        bool _isCall,
        uint256 _strikePrice,
        uint256 _deadline,
        uint256 _settleTimestamp
    ) public onlyOwner returns (address) {
        // Deploy a new policy token by the factory contract
        address policyTokenAddress = factory.deployPolicyToken(
            _policyTokenName
        );

        // Store the policyToken information in the mapping
        policyTokenInfoMapping[_policyTokenName] = PolicyTokenInfo(
            policyTokenAddress,
            _isCall,
            _strikePrice,
            _deadline,
            _settleTimestamp
        );

        // Keep the record from policy token to original token
        policyTokenToOriginal[policyTokenAddress] = _tokenAddress;

        // Record the address to name mapping
        policyTokenAddressToName[policyTokenAddress] = _policyTokenName;

        // You can not get the return value from outside, but keep it here.
        return policyTokenAddress;
    }

    /**
     * @notice Deploy a new pair (pool)
     * @param _policyTokenName Name of the policy token
     * @param _stablecoin Address of the stable coin
     * @param _poolDeadline Swapping deadline of the pool
     * @return poolAddress The address of the pool just deployed
     */
    function deployPool(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _poolDeadline
    )
        public
        onlyOwner
        supportedStablecoin(_stablecoin)
        deployedPolicy(_policyTokenName)
        returns (address)
    {
        address policyTokenAddress = policyTokenInfoMapping[_policyTokenName]
            .policyTokenAddress;

        // Deploy a new pool (policyToken <=> stablecoin)
        address poolAddress = factory.deployPool(
            policyTokenAddress,
            _stablecoin,
            _poolDeadline
        );

        // Record the mapping
        whichStablecoin[policyTokenAddress] = _stablecoin;
        return poolAddress;
    }

    /**
     * @notice Deposit stablecoins and get policy tokens
     * @param _policyTokenName Name of the policy token
     * @param _stablecoin Address of the sable coin
     * @param _amount Amount of stablecoin (also the amount of policy tokens)
     */
    function deposit(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount
    ) public beforeDeadline(_policyTokenName) {
        address policyTokenAddress = policyTokenInfoMapping[_policyTokenName]
            .policyTokenAddress;

        // Check if the user gives the right stablecoin
        require(
            whichStablecoin[policyTokenAddress] == _stablecoin,
            "PolicyToken and stablecoin not matched"
        );

        // Check if the user has enough balance
        require(
            IERC20(_stablecoin).balanceOf(msg.sender) >= _amount,
            "User's stablecoin balance not sufficient"
        );

        _mintPolicyToken(policyTokenAddress, _stablecoin, _amount, msg.sender);
    }

    /**
     * @notice Delegate deposit (deposit and mint for other addresses)
     * @param _policyTokenName Name of the policy token
     * @param _stablecoin Address of the sable coin
     * @param _amount Amount of stablecoin (also the amount of policy tokens)
     * @param _userAddress Address to receive the policy tokens
     */
    function delegateDeposit(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount,
        address _userAddress
    ) external beforeDeadline(_policyTokenName) {
        address policyTokenAddress = policyTokenInfoMapping[_policyTokenName]
            .policyTokenAddress;

        // Check if the user gives the right stablecoin
        require(
            whichStablecoin[policyTokenAddress] == _stablecoin,
            "PolicyToken and stablecoin not matched"
        );

        // Check if the user has enough balance
        require(
            IERC20(_stablecoin).balanceOf(_userAddress) >= _amount,
            "User's stablecoin balance not sufficient"
        );

        _mintPolicyToken(
            policyTokenAddress,
            _stablecoin,
            _amount,
            _userAddress
        );
    }

    /**
     * @notice Burn policy tokens and redeem USDT
     * @dev Redeem happens before the deadline and is different from claim/settle
     * @param _policyTokenName Name of the policy token
     * @param _stablecoin Address of the stablecoin
     * @param _amount Amount of USDT (also the amount of policy tokens)
     */
    function redeem(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount
    ) public enoughUSD(_stablecoin, _amount) beforeDeadline(_policyTokenName) {
        address policyTokenAddress = policyTokenInfoMapping[_policyTokenName]
            .policyTokenAddress;

        // Check if the user has enough quota (quota is only for those who mint policy tokens)
        require(
            userQuota[msg.sender][policyTokenAddress] >= _amount,
            "User's quota not sufficient"
        );

        _redeemPolicyToken(policyTokenAddress, _stablecoin, _amount);
    }

    /**
     * @notice Claim a payoff based on policy tokens
     * @dev It is done after result settlement and only if the result is true
     * @param _policyTokenName Name of the policy token
     * @param _stablecoin Address of the stable coin
     * @param _amount Amount of USDT (also the amount of policy tokens)
     */
    function claim(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount
    ) public enoughUSD(_stablecoin, _amount) afterSettlement(_policyTokenName) {
        address policyTokenAddress = policyTokenInfoMapping[_policyTokenName]
            .policyTokenAddress;

        // Check if we have already settle the final price
        require(
            settleResult[policyTokenAddress].alreadySettled == true,
            "Have not got the oracle result"
        );

        uint256 amountWithFee = (_amount * 990) / 1000;

        // If the event happens, let users claim the payoff
        if (settleResult[policyTokenAddress].isHappened == true) {
            IPolicyToken policyToken = IPolicyToken(policyTokenAddress);
            require(
                policyToken.balanceOf(msg.sender) >= _amount,
                "You do not have sufficient policy tokens to claim"
            );

            _claimPolicyToken(policyTokenAddress, _stablecoin, amountWithFee);
        }
    }

    /**
     * @notice Get the final price from the PriceGetter contract
     * @param _policyTokenName Name of the policy token
     */
    function settleFinalResult(string memory _policyTokenName)
        public
        afterSettlement(_policyTokenName)
        notAlreadySettled(_policyTokenName)
    {
        address policyTokenAddress = policyTokenInfoMapping[_policyTokenName]
            .policyTokenAddress;
        require(
            policyTokenAddress != address(0),
            "This policy token does not exist, maybe you input a wrong name"
        );

        SettlementInfo storage result = settleResult[policyTokenAddress];

        // Get the final price from oracle
        int256 price = IPriceGetter(priceGetter).getLatestPrice(
            _policyTokenName
        );
        require(price > 0, "Price can not be <= 0");
        result.price = price;

        // Get the final result
        uint256 strike = policyTokenInfoMapping[_policyTokenName].strikePrice;
        bool isCall = policyTokenInfoMapping[_policyTokenName].isCall;

        bool situationT1 = (uint256(price) >= strike) && isCall;
        bool situationT2 = (uint256(price) <= strike) && !isCall;

        if (situationT1 || situationT2) {
            result.isHappened = true;
        } else {
            result.isHappened = false;
        }

        result.alreadySettled = true;

        emit SettleFinalResult(_policyTokenName, price, result.isHappened);
    }

    /**
     * @notice Settle the policies when then insurance event do not happen
     *         Funds are automatically distributed back to the depositors
     * @dev    Take care of the gas cost and can use the _startIndex and _stopIndex to control the size
     * @param _policyTokenAddress Address of policy token
     * @param _stablecoin Address of stablecoin
     * @param _startIndex Settlement start index
     * @param _stopIndex Settlement stop index
     */
    function settleAllPolicyTokens(
        address _policyTokenAddress,
        address _stablecoin,
        uint256 _startIndex,
        uint256 _stopIndex
    ) public onlyOwner {
        // Copy to memory (will not change the result)
        SettlementInfo memory result = settleResult[_policyTokenAddress];

        // Must have got the final price
        require(
            result.price != 0 && result.alreadySettled == true,
            "Have not got the oracle result"
        );

        // The event must be "not happend"
        require(
            result.isHappened == false,
            "Only call this function when the event does not happen"
        );

        // Settle the policies in [_startIndex, _stopIndex)
        if (_startIndex == 0 && _stopIndex == 0) {
            uint256 length = allDepositors[_policyTokenAddress].length;
            _settlePolicy(_policyTokenAddress, _stablecoin, 0, length);
            currentDistributionIndex = length;
        } else {
            require(
                currentDistributionIndex == _startIndex,
                "You need to start from the last distribution point"
            );
            _settlePolicy(
                _policyTokenAddress,
                _stablecoin,
                _startIndex,
                _stopIndex
            );
            currentDistributionIndex = _stopIndex;
        }

        if (
            currentDistributionIndex ==
            allDepositors[_policyTokenAddress].length
        ) {
            _finishSettlement(_policyTokenAddress, _stablecoin);
        }
    }

    /**
     * @notice Finish settlement process
     * @param _policyTokenAddress Address of the policy token
     * @param _stablecoin Address of stable coin
     */
    function _finishSettlement(address _policyTokenAddress, address _stablecoin)
        internal
    {
        currentDistributionIndex = 0;

        uint256 feeToLottery = IERC20(_stablecoin).balanceOf(address(this));

        require(
            address(lottery) != address(0),
            "Please set the lottery address"
        );

        IERC20(_stablecoin).safeTransfer(lottery, feeToLottery);

        emit FinishSettlementPolicies(_policyTokenAddress, _stablecoin);
    }

    // ---------------------------------------------------------------------------------------- //
    // *********************************** Internal Functions ********************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Mint Policy Token 1:1 USD
     *         The policy token need to be deployed first!
     * @param _policyTokenAddress Address of the policy token
     * @param _stablecoin Address of the stablecoin
     * @param _amount Amount to mint
     */
    function _mintPolicyToken(
        address _policyTokenAddress,
        address _stablecoin,
        uint256 _amount,
        address _userAddress
    ) internal {
        IPolicyToken policyToken = IPolicyToken(_policyTokenAddress);

        // Transfer stablecoins to this contract
        IERC20(_stablecoin).safeTransferFrom(
            _userAddress,
            address(this),
            _amount
        );

        // Mint new policy tokens
        policyToken.mint(_userAddress, _amount);

        // If this is the first deposit, store the user address
        if (userQuota[_userAddress][_policyTokenAddress] == 0) {
            allDepositors[_policyTokenAddress].push(_userAddress);
        }

        // Update the user quota
        userQuota[_userAddress][_policyTokenAddress] += _amount;
    }

    /**
     * @notice Redeem policy tokens back, only for depositors
     * @param _policyTokenAddress Address of the policy token
     * @param _stablecoin Address of the stablecoin
     * @param _amount Amount to redeem
     */
    function _redeemPolicyToken(
        address _policyTokenAddress,
        address _stablecoin,
        uint256 _amount
    ) internal {
        IPolicyToken policyToken = IPolicyToken(_policyTokenAddress);

        // Give back the stablecoins
        IERC20(_stablecoin).safeTransfer(msg.sender, _amount);

        // Burn the policy tokens
        policyToken.burn(msg.sender, _amount);

        userQuota[msg.sender][_policyTokenAddress] -= _amount;

        if (userQuota[msg.sender][_policyTokenAddress] == 0)
            delete userQuota[msg.sender][_policyTokenAddress];
    }

    /**
     * @notice Claim policies when the insurance event happens
     * @param _policyTokenAddress Address of policy token
     * @param _stablecoin Address of stable coin
     * @param _amount Amount to claim
     */
    function _claimPolicyToken(
        address _policyTokenAddress,
        address _stablecoin,
        uint256 _amount
    ) internal {
        IPolicyToken policyToken = IPolicyToken(_policyTokenAddress);

        IERC20(_stablecoin).safeTransfer(msg.sender, _amount);

        policyToken.burn(msg.sender, _amount);

        userQuota[msg.sender][_policyTokenAddress] -= _amount;

        if (userQuota[msg.sender][_policyTokenAddress] == 0)
            delete userQuota[msg.sender][_policyTokenAddress];
    }

    /**
     * @notice Settle the policy
     * @param _policyTokenAddress Address of policy token
     * @param _stablecoin Address of stable coin
     * @param _start Start index
     * @param _stop Stop index
     */
    function _settlePolicy(
        address _policyTokenAddress,
        address _stablecoin,
        uint256 _start,
        uint256 _stop
    ) internal {
        for (uint256 i = _start; i < _stop; i++) {
            address user = allDepositors[_policyTokenAddress][i];
            uint256 amount = userQuota[user][_policyTokenAddress];
            uint256 amountWithFee = (amount * 990) / 1000;

            if (amountWithFee > 0) {
                IERC20(_stablecoin).safeTransfer(user, amountWithFee);

                // userQuota[user][_policyTokenAddress] -= amount;
                // if (userQuota[user][_policyTokenAddress] == 0)
                delete userQuota[user][_policyTokenAddress];
            } else continue;
        }
    }
}

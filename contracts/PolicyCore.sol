// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/NaughtyLibrary.sol";
import "./interfaces/IPolicyToken.sol";
import "./interfaces/INaughtyRouter.sol";
import "./interfaces/INaughtyFactory.sol";
import "./interfaces/IPriceGetter.sol";
import "./interfaces/IPolicyCore.sol";
import "./interfaces/IDegisToken.sol";

/**
 * @title  PolicyCore
 * @notice Core logic of Naughty Price
 *         Preset:
 *              1. Deploy policyToken contract
 *              2. Deploy policyToken-Stablecoin pool contract
 *         User Interaction:
 *              1. Deposit Stablecoin and mint PolicyTokens
 *              2. Redeem their Stablecoin and burn the PolicyTokens
 *              3. Claim for payout with PolicyTokens
 *         PolicyTokens are minted with the ratio 1:1 to Stablecoin
 *         The PolicyTokens are traded in the pool with CFMM (xy=k)
 *         When the event happens, a PolicyToken can be burned for claiming 1 Stablecoin.
 *         When the event does not happen, the PolicyToken depositors can
 *         redeem their 1 deposited Stablecoin
 * @dev    Most of the functions to be called from outside will use the name of policyToken
 *         rather than the address(easy to read).
 *         The rule of policyToken naming is <Original Token Name><Strike Price><Lower or Higher><Date>
 *         E.g.  AVAX30L202101, BTC30000L202102, ETH8000H202109
 */
contract PolicyCore is IPolicyCore {
    using SafeERC20 for IERC20;

    address public factory; // Factory contract, responsible for deploying new contracts
    address public router; // Router contract, responsible for pair swapping
    address public pricegetter;

    address public degis;

    address public owner;

    uint256 public purchaseIncentiveRatio;

    struct PolicyTokenInfo {
        address policyTokenAddress;
        bool isHigher;
        uint256 strikePrice;
        uint256 deadline;
        uint256 settleTimestamp;
    }
    mapping(string => PolicyTokenInfo) policyTokenInfoMapping; // Name => Information

    mapping(address => bool) stablecoin; // Stablecoin address => support or not

    mapping(address => address) whichStablecoin; // Policy token address => stable coin address

    mapping(address => address) policyTokenToOriginal; // PolicyToken => Token (e.g. AVAX30L202101 address => AVAX address)

    mapping(address => mapping(address => uint256)) userQuota; // User Address => Token Address => Quota Amount

    mapping(address => address[]) public allDepositors;

    struct SettlementInfo {
        int256 price;
        bool isHappened;
        bool alreadySettled;
    }
    mapping(address => SettlementInfo) settleResult;

    /**
     * @notice Constructor, for some addresses
     * @param _usdt Stablecoin(first supported) in the pool (can be other stablecoins)
     * @param _factory Address of naughty factory
     * @param _router Address of naughty router
     * @param _priceGetter Address of the oracle part
     * @param _degis Address of degis token, used for purchaseIncentive
     */
    constructor(
        address _usdt,
        address _factory,
        address _router,
        address _priceGetter,
        address _degis
    ) {
        stablecoin[_usdt] = true;

        factory = _factory;
        router = _router;
        pricegetter = _priceGetter;
        degis = _degis;

        owner = msg.sender;
    }

    /**
     * @notice Only the owner can call some functions
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the  owner can call this function");
        _;
    }

    /**
     * @notice Check if this stablecoin is supported
     * @param _stablecoin Stablecoin address
     */
    modifier supportedStablecoin(address _stablecoin) {
        require(
            stablecoin[_stablecoin] == true,
            "Do not support this stablecoin"
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
     * @dev Deadline for swap need to be set seperately
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
     */
    modifier afterSettlement(string memory _policyTokenName) {
        uint256 settleTimestamp = policyTokenInfoMapping[_policyTokenName]
            .settleTimestamp;
        require(
            block.timestamp >= settleTimestamp,
            "Can not settle/claim, not reached settleTimestamp"
        );
        _;
    }

    /**
     * @notice Avoid multiple settlement
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

    /**
     * @notice Find the token address by its name
     * @param _policyTokenName The name of policy token (e.g. "AVAX30L202103")
     * @return PolicyToken address
     */
    function findAddressbyName(string memory _policyTokenName)
        external
        view
        returns (address)
    {
        return policyTokenInfoMapping[_policyTokenName].policyTokenAddress;
    }

    /**
     * @notice Find the token information by its name
     * @param _policyTokenName The name of policy token (e.g. "AVAX30L202103")
     * @return PolicyToken detail information
     */
    function getPolicyTokenInfo(string memory _policyTokenName)
        external
        view
        returns (PolicyTokenInfo memory)
    {
        return policyTokenInfoMapping[_policyTokenName];
    }

    /**
     * @notice Check if this is a stablecoin address supported, used in factory
     */
    function isStablecoinAddress(address _coinAddress)
        external
        view
        returns (bool)
    {
        return stablecoin[_coinAddress];
    }

    /**
     * @notice Add new supported stablecoin
     */
    function addStablecoin(address _newStablecoin) external onlyOwner {
        stablecoin[_newStablecoin] = true;
        emit NewStablecoinAdded(_newStablecoin);
    }

    /**
     * @notice Change the purchase incentive amount
     * @dev policyToken amount(not happened) / ratio = incentive amount (in DEG)
     * @param _newRatio The amount is calculated by this ratio
     */
    function setPurchaseIncentiveAmount(uint256 _newRatio) external onlyOwner {
        purchaseIncentiveRatio = _newRatio;
        emit PurchaseIncentiveRatioSet(_newRatio);
    }

    /**
     * @notice Deploy a new policy token and return the token address
     * @dev Only the owner can deploy new policy token
     * @param _policyTokenName Token name of policy token (e.g. "AVAX30L202101")
     * @param _tokenAddress Address of the original token (e.g. AVAX, BTC, ETH...)
     * @param _isHigher The policy is for higher than strike price or lower than (call / put)
     * @param _strikePrice Strike price of the policy
     * @param _deadline Deadline of this policy token (deposit / redeem / swap)
     * @param _settleTimestamp Can settle after this timestamp (for oracle)
     * @return policyTokenAddress The address of the policy token just deployed
     */
    function deployPolicyToken(
        string memory _policyTokenName,
        address _tokenAddress,
        bool _isHigher,
        uint256 _strikePrice,
        uint256 _deadline,
        uint256 _settleTimestamp
    ) public onlyOwner returns (address) {
        address policyTokenAddress = INaughtyFactory(factory).deployPolicyToken(
            _policyTokenName
        );

        // Store the policyToken information in the mapping
        policyTokenInfoMapping[_policyTokenName] = PolicyTokenInfo(
            policyTokenAddress,
            _isHigher,
            _strikePrice,
            _deadline,
            _settleTimestamp
        );

        // Keep the record from policy token to original token
        policyTokenToOriginal[policyTokenAddress] = _tokenAddress;

        // You can not get the return value from outside, but keep it here.
        return policyTokenAddress;
    }

    /**
     * @notice Deploy a new pair (pool)
     * @param _policyTokenName Name of the policy token
     * @param _stablecoin Address of the stable coin
     * @return The address of the pool just deployed
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
        address poolAddress = INaughtyFactory(factory).deployPool(
            policyTokenAddress,
            _stablecoin,
            _poolDeadline
        );

        whichStablecoin[policyTokenAddress] = _stablecoin;
        return poolAddress;
    }

    /**
     * @notice Deposit stablecoins and get policy tokens
     * @param _policyTokenName Name of the policy token
     * @param _stablecoin Address of the sable coin
     * @param _amount Amount of USDT (also the amount of policy tokens)
     */
    function deposit(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount
    ) public beforeDeadline(_policyTokenName) {
        address policyTokenAddress = policyTokenInfoMapping[_policyTokenName]
            .policyTokenAddress;

        // Check if the user give the right stablecoin
        require(
            whichStablecoin[policyTokenAddress] == _stablecoin,
            "PolicyToken and stablecoin not matched"
        );

        // Check if the user has enough balance
        require(
            IERC20(_stablecoin).balanceOf(msg.sender) >= _amount,
            "User's stablecoin balance not sufficient"
        );

        _mintPolicyToken(policyTokenAddress, _stablecoin, _amount);
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
    ) public afterSettlement(_policyTokenName) {
        address policyTokenAddress = policyTokenInfoMapping[_policyTokenName]
            .policyTokenAddress;

        // Check if we have already settle the final price
        require(
            settleResult[policyTokenAddress].alreadySettled == true,
            "Have not got the oracle result"
        );

        // If the event happens, let users claim the payoff
        // If the event does not happen, let users get the purachse incentive (if any)
        if (settleResult[policyTokenAddress].isHappened == true) {
            IPolicyToken policyToken = IPolicyToken(policyTokenAddress);
            require(
                policyToken.balanceOf(msg.sender) >= _amount,
                "You do not have sufficient policy tokens to claim"
            );

            _claimPolicyToken(policyTokenAddress, _stablecoin, _amount);
        } else {
            _claimPurchaseIncentive(policyTokenAddress, _amount);
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
        int256 price = IPriceGetter(pricegetter).getLatestPrice(
            _policyTokenName
        );
        require(price > 0, "Price can not be <= 0");
        result.price = price;

        // Get the final result
        uint256 strike = policyTokenInfoMapping[_policyTokenName].strikePrice;
        bool isHigher = policyTokenInfoMapping[_policyTokenName].isHigher;

        bool situationT1 = (uint256(price) >= strike) && isHigher;
        bool situationT2 = (uint256(price) <= strike) && !isHigher;

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
        } else {
            _settlePolicy(
                _policyTokenAddress,
                _stablecoin,
                _startIndex,
                _stopIndex
            );
        }
    }

    /**
     * @notice Mint Policy Token 1:1 USD
     *         The policy token need to be deployed first!
     * @param _policyTokenAddress Address of policy token
     * @param _stablecoin Address of stable coin
     * @param _amount Amount to mint
     */
    function _mintPolicyToken(
        address _policyTokenAddress,
        address _stablecoin,
        uint256 _amount
    ) internal {
        IPolicyToken policyToken = IPolicyToken(_policyTokenAddress);

        IERC20(_stablecoin).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        policyToken.mint(msg.sender, _amount);

        if (userQuota[msg.sender][_policyTokenAddress] == 0) {
            allDepositors[_policyTokenAddress].push(msg.sender);
        }

        userQuota[msg.sender][_policyTokenAddress] += _amount;
    }

    /**
     * @notice Redeem policy tokens back, only for depositors
     * @param _policyTokenAddress Address of policy token
     * @param _stablecoin Address of stable coin
     * @param _amount Amount to redeem
     */
    function _redeemPolicyToken(
        address _policyTokenAddress,
        address _stablecoin,
        uint256 _amount
    ) internal {
        userQuota[msg.sender][_policyTokenAddress] -= _amount;

        if (userQuota[msg.sender][_policyTokenAddress] == 0)
            delete userQuota[msg.sender][_policyTokenAddress];

        IERC20(_stablecoin).safeTransfer(msg.sender, _amount);
        IPolicyToken(_policyTokenAddress).burn(msg.sender, _amount);
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
    ) internal enoughUSD(_stablecoin, _amount) {
        IPolicyToken policyToken = IPolicyToken(_policyTokenAddress);

        IERC20(_stablecoin).safeTransfer(msg.sender, _amount);

        policyToken.burn(msg.sender, _amount);

        userQuota[msg.sender][_policyTokenAddress] -= _amount;
    }

    /**
     * @notice Claim the purchase incentive when the event does not happen
     * @dev The incentive is in the form of DEG and there is a ratio
     * @param _policyTokenAddress Address of the policy token
     * @param _amount Amount of policy tokens to be claimed
     */
    function _claimPurchaseIncentive(
        address _policyTokenAddress,
        uint256 _amount
    ) internal {
        // Calculate the amount and mint
        uint256 purchaseIncentiveAmount = _amount / purchaseIncentiveRatio;
        IDegisToken(degis).mint(msg.sender, purchaseIncentiveAmount);

        // Burn the policy token
        IPolicyToken policyToken = IPolicyToken(_policyTokenAddress);
        policyToken.burn(msg.sender, _amount);
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

            if (amount > 0) {
                IERC20(_stablecoin).safeTransfer(user, amount);

                // userQuota[user][_policyTokenAddress] -= amount;
                // if (userQuota[user][_policyTokenAddress] == 0)
                delete userQuota[user][_policyTokenAddress];
            } else continue;
        }
    }
}

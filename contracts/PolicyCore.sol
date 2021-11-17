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

    address public owner;

    struct PolicyTokenInfo {
        address policyTokenAddress;
        bool _isHigher;
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

    mapping(address => int256) priceResult; // PolicyToken address => Price result

    /**
     * @notice Constructor, for some addresses
     */
    constructor(
        address _usdt,
        address _factory,
        address _router,
        address _pricegetter
    ) {
        stablecoin[_usdt] = true;

        factory = _factory;
        router = _router;
        pricegetter = _pricegetter;

        owner = msg.sender;
    }

    /**
     * @notice Only the owner can call some functions
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "only owner can call this function");
        _;
    }

    /**
     * @notice Check if this stablecoin is supported
     * @param _stablecoin: Stablecoin address
     */
    modifier supportedStablecoin(address _stablecoin) {
        require(
            stablecoin[_stablecoin] == true,
            "Do not support this stablecoin"
        );
        _;
    }

    /**
     * @notice Check if there is enough stablecoins in the contract
     */
    modifier enoughUSD(address _stablecoin, uint256 _amount) {
        require(
            IERC20(_stablecoin).balanceOf(address(this)) >= _amount,
            "not sufficient usdt in the contract"
        );
        _;
    }

    /// @notice Deposit/Redeem/Swap only before deadline
    modifier beforeDeadline(string memory _policyTokenName) {
        uint256 deadline = policyTokenInfoMapping[_policyTokenName].deadline;
        require(
            block.timestamp <= deadline,
            "Can not deposit/redeem, has passed the deadline"
        );
        _;
    }

    /// @notice Settle the result after the "_settleTimestamp"
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
     * @notice Find the token address by its name
     * @param _policyTokenName: The name of policy token (e.g. "AVAX30-202103")
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
     * @param _policyTokenName: The name of policy token (e.g. "AVAX30-202103")
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
     * @notice Add new supported stablecoin
     */
    function addStablecoin(address _newStablecoin) public onlyOwner {
        stablecoin[_newStablecoin] = true;
    }

    /**
     * @notice Deploy a new policy token and get the token address
     * @param _policyTokenName: Token name of policy token (e.g. "AVAX30L202101")
     * @param _tokenAddress: Address of the original token (e.g. AVAX, BTC, ETH...)
     * @return The address of the policy token just deployed
     */
    function deployPolicyToken(
        string memory _policyTokenName,
        address _tokenAddress,
        bool _isHigher,
        uint256 _strikePrice,
        uint256 _deadline,
        uint256 _settleTimestamp
    ) public returns (address) {
        address policyTokenAddress = INaughtyFactory(factory).deployPolicyToken(
            _policyTokenName
        );

        // Store the address in the mapping
        policyTokenInfoMapping[_policyTokenName] = PolicyTokenInfo(
            policyTokenAddress,
            _isHigher,
            _strikePrice,
            _deadline,
            _settleTimestamp
        );

        policyTokenToOriginal[policyTokenAddress] = _tokenAddress;

        return policyTokenAddress;
    }

    /**
     * @notice Deploy a new pair (pool)
     * @param _policyTokenName: Name of the policy token
     * @param _stablecoin: Address of the stable coin
     * @return The address of the pool just deployed
     */
    function deployPool(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _poolDeadline
    ) public supportedStablecoin(_stablecoin) returns (address) {
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
     * @notice Deposit USDT and get policy tokens
     * @param _policyTokenName: Name of the policy token
     * @param _stablecoin: Address of the sable coin
     * @param _amount: Amount of USDT (also the amount of policy tokens)
     */
    function deposit(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount
    ) public beforeDeadline(_policyTokenName) {
        address policyTokenAddress = policyTokenInfoMapping[_policyTokenName]
            .policyTokenAddress;
        require(
            whichStablecoin[policyTokenAddress] == _stablecoin,
            "PolicyToken and stablecoin not matched"
        );

        require(
            IERC20(_stablecoin).balanceOf(msg.sender) >= _amount,
            "User's stablecoin balance not sufficient"
        );

        _mintPolicyToken(policyTokenAddress, _stablecoin, _amount);
    }

    /**
     * @notice Burn policy tokens and redeem USDT
     * @param _policyTokenName: Name of the policy token
     * @param _stablecoin: Address of the stablecoin
     * @param _amount: Amount of USDT (also the amount of policy tokens)
     */
    function redeem(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount
    ) public enoughUSD(_stablecoin, _amount) beforeDeadline(_policyTokenName) {
        uint256 deadline = policyTokenInfoMapping[_policyTokenName].deadline;
        require(
            block.timestamp <= deadline,
            "Can not deposit, has passed the deadline"
        );

        address policyTokenAddress = policyTokenInfoMapping[_policyTokenName]
            .policyTokenAddress;
        require(
            userQuota[msg.sender][policyTokenAddress] >= _amount,
            "user's quota not sufficient"
        );

        _redeemPolicyToken(policyTokenAddress, _stablecoin, _amount);
    }

    /**
     * @notice Claim a payoff based on policy tokens
     * @param _policyTokenName: Name of the policy token
     * @param _stablecoin: Address of the stable coin
     * @param _amount: Amount of USDT (also the amount of policy tokens)
     */
    function claim(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount
    ) public afterSettlement(_policyTokenName) {
        address policyTokenAddress = policyTokenInfoMapping[_policyTokenName]
            .policyTokenAddress;

        IPolicyToken policyToken = IPolicyToken(policyTokenAddress);
        require(
            policyToken.balanceOf(msg.sender) >= _amount,
            "You do not have sufficient policy tokens to claim"
        );

        _claimPolicyToken(policyTokenAddress, _stablecoin, _amount);
    }

    /**
     * @notice Get the final price from the PriceGetter contract
     * @param _policyTokenName: Address of the token
     */
    function settleFinalResult(string memory _policyTokenName)
        public
        afterSettlement(_policyTokenName)
    {
        address policyTokenAddress = policyTokenInfoMapping[_policyTokenName]
            .policyTokenAddress;
        require(
            policyTokenAddress != address(0),
            "this policy token does not exist, maybe you input a wrong name"
        );

        // Get the price from oracle
        int256 price = IPriceGetter(pricegetter).getLatestPrice(
            _policyTokenName
        );

        priceResult[policyTokenAddress] = price;

        emit SettleFinalResult(_policyTokenName, price);
    }

    /**
     * @notice Mint Policy Token 1:1 USD
     *         The policy token need to be deployed first!
     * @param _policyTokenAddress: Address of policy token
     * @param _stablecoin: Address of stable coin
     * @param _amount: Amount to mint
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
     * @notice Claim policies when the insurance event happens
     * @param _policyTokenAddress: Address of policy token
     * @param _stablecoin: Address of stable coin
     * @param _amount: Amount to claim
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
     * @notice Redeem policy tokens back, only for depositors
     * @param _policyTokenAddress: Address of policy token
     * @param _stablecoin: Address of stable coin
     * @param _amount: Amount to redeem
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
     * @notice Settle the policies when then insurance event do not happen
     *         Funds are automatically distributed back to the depositors
     * @dev    Not recommended to use this function for the gas cost
     */
    function settlePolicyToken(address _policyTokenAddress, address _stablecoin)
        public
        onlyOwner
    {
        require(
            priceResult[_policyTokenAddress] != 0,
            "have not got the oracle result"
        );

        uint256 length = allDepositors[_policyTokenAddress].length;

        for (uint256 i = 0; i < length; i++) {
            address user = allDepositors[_policyTokenAddress][i];
            uint256 amount = userQuota[user][_policyTokenAddress];

            IERC20(_stablecoin).safeTransfer(user, amount);
        }
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
}

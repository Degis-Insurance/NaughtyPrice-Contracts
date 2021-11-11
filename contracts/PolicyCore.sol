// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./libraries/NaughtyLibrary.sol";
import "./interfaces/IPolicyToken.sol";
import "./interfaces/INaughtyRouter.sol";
import "./interfaces/INaughtyFactory.sol";

/**
 * @title  PolicyCore
 * @notice Core logic of Naughty Price
 *         Preset:
 *              1. Deploy policyToken contract
 *              2. Deploy policyToken-USDT pool contract
 *         User Interaction:
 *              1. Deposit USDT and mint PolicyTokens
 *              2. Redeem their USDT and burn the PolicyTokens
 *              3. Claim for payout with PolicyTokens
 *         PolicyTokens are minted with the ratio 1:1 to USDT
 *         The PolicyTokens are traded in the pool with CFMM (xy=k)
 *         When the event happens, a PolicyToken can be burned for claiming 1 USDT.
 *         When the event does not happen, the PolicyToken depositors can
 *         redeem their 1 deposited USDT
 */
contract PolicyCore {
    using SafeERC20 for IERC20;

    address public factory; // Factory contract, responsible for deploying new contracts
    address public router; // Router contract, responsible for pair swapping

    address public owner;
    address public USDT;

    mapping(string => address) policyTokenAddressMapping; // Name => Address

    mapping(address => mapping(address => uint256)) userQuota; // User Address => Token Address => Quota Amount

    mapping(address => uint256) public amountDepositors;
    mapping(address => address[]) public allDepositors;

    /**
     * @notice Constructor, for some addresses
     */
    constructor(
        address _usdt,
        address _factory,
        address _router
    ) {
        USDT = _usdt;
        factory = _factory;
        router = _router;
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
     * @notice Check if there is enough USDT in the contract
     */
    modifier enoughUSDT(uint256 _amount) {
        require(
            IERC20(USDT).balanceOf(address(this)) >= _amount,
            "not sufficient usdt in the contract"
        );
        _;
    }

    /**
     * @notice Find the token address by its name
     * @param _tokenName: The name of policy token (e.g. "AVAX30-202103")
     */
    function findAddressbyName(string memory _tokenName)
        public
        view
        returns (address)
    {
        return policyTokenAddressMapping[_tokenName];
    }

    /**
     * @notice Deploy a new policy token and get the token address
     * @param _tokenName: Token name of policy token
     * @return The address of the policy token just deployed
     */
    function deployPolicyToken(string memory _tokenName)
        public
        returns (address)
    {
        address tokenAddress = INaughtyFactory(factory).deployPolicyToken(
            _tokenName
        );

        // Store the address in the mapping
        policyTokenAddressMapping[_tokenName] = tokenAddress;

        return tokenAddress;
    }

    /**
     * @notice Deploy a new pair (pool)
     * @param _tokenAddress: Address of the policy token
     * @return The address of the pool just deployed
     */
    function deployPool(address _tokenAddress) public returns (address) {
        address poolAddress = INaughtyFactory(factory).deployPool(
            _tokenAddress
        );
        return poolAddress;
    }

    /**
     * @notice Deposit USDT and get policy tokens
     * @param _policyToken: Address of the policy token
     * @param _amount: Amount of USDT (also the amount of policy tokens)
     */
    function deposit(address _policyToken, uint256 _amount) public {
        require(
            IERC20(USDT).balanceOf(msg.sender) >= _amount,
            "user's USDT balance not sufficient"
        );

        _mintPolicyToken(_policyToken, _amount);
    }

    /**
     * @notice Burn policy tokens and redeem USDT
     * @param _policyToken: Address of the policy token
     * @param _amount: Amount of USDT (also the amount of policy tokens)
     */
    function redeem(address _policyToken, uint256 _amount)
        public
        enoughUSDT(_amount)
    {
        require(
            userQuota[msg.sender][_policyToken] >= _amount,
            "user's quota not sufficient"
        );
        _redeemPolicyToken(_policyToken, _amount);
    }

    /**
     * @notice Claim a payoff based on policy tokens
     * @param _policyToken: Address of the policy token
     * @param _amount: Amount of USDT (also the amount of policy tokens)
     */
    function claim(address _policyToken, uint256 _amount) public {
        IPolicyToken policyToken = IPolicyToken(_policyToken);
        require(
            policyToken.balanceOf(msg.sender) >= _amount,
            "you do not have sufficient policy tokens to claim"
        );

        _claimPolicyToken(_policyToken, _amount);
    }

    /**
     * @notice Mint Policy Token 1:1 USDT
     *         The policy token need to be deployed first!
     */
    function _mintPolicyToken(address _policyToken, uint256 _amount) internal {
        IPolicyToken policyToken = IPolicyToken(_policyToken);

        IERC20(USDT).safeTransferFrom(msg.sender, address(this), _amount);

        policyToken.mint(msg.sender, _amount);

        if (userQuota[msg.sender][_policyToken] == 0) {
            allDepositors[_policyToken].push(msg.sender);
            amountDepositors[_policyToken] += 1;
        }

        userQuota[msg.sender][_policyToken] += _amount;
    }

    /**
     * @notice Claim policies when the insurance event happens
     */
    function _claimPolicyToken(address _policyToken, uint256 _amount)
        internal
        enoughUSDT(_amount)
    {
        IPolicyToken policyToken = IPolicyToken(_policyToken);

        IERC20(USDT).safeTransfer(msg.sender, _amount);

        policyToken.burn(msg.sender, _amount);

        userQuota[msg.sender][_policyToken] -= _amount;
    }

    function _redeemPolicyToken(address _policyToken, uint256 _amount)
        internal
    {
        userQuota[msg.sender][_policyToken] -= _amount;

        if (userQuota[msg.sender][_policyToken] == 0)
            delete userQuota[msg.sender][_policyToken];

        IERC20(USDT).safeTransfer(msg.sender, _amount);
        IPolicyToken(_policyToken).burn(msg.sender, _amount);
    }

    /**
     * @notice Settle the policies when then insurance event do not happen
     *         Funds are automatically distributed back to the depositors
     * @dev    Not recommended to use this function for the gas cost
     */
    function settlePolicyToken(address _policyToken, address _user)
        public
        onlyOwner
    {
        uint256 length = allDepositors[_policyToken].length;

        for (uint256 i = 0; i < length; i++) {
            address user = allDepositors[_policyToken][i];
            uint256 amount = userQuota[user][_policyToken];
            IERC20(USDT).safeTransfer(user, amount);
        }
    }
}

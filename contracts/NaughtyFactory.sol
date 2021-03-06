// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./NPPolicyToken.sol";
import "./NaughtyPair.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/INaughtyPair.sol";
import "./interfaces/INaughtyFactory.sol";
import "./interfaces/IPolicyCore.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Naughty Factory
 * @dev Factory contract to deploy new pools periodically
 *      Each pool(product) will have a unique naughtyId
 *      Each pool will have its pool token
 *      PolicyToken - Stablecoin
 *      Token 0 may change but Token 1 is always stablecoin.
 */

contract NaughtyFactory is INaughtyFactory {
    using Strings for uint256;

    // PolicyToken Address => StableCoin Address => Pool Address
    mapping(address => mapping(address => address)) getPair;

    // Store all the pairs' addresses
    address[] allPairs;

    // Store all policy token addresses
    address[] allTokens;

    uint256 public _nextId;

    // Address of policyCore
    address public policyCore;

    // Used for the management fee (currently not open)
    address public feeTo;
    address public feeToSetter;

    // INIT_CODE_HASH, we do not use it, but put it here
    bytes32 public constant INIT_CODE_HASH =
        keccak256(abi.encodePacked(type(NaughtyPair).creationCode));

    constructor(address _feeToSetter) {
        feeToSetter = _feeToSetter;
    }

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Modifiers ************************************** //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Only feeToSetter can call some functions
     */
    modifier onlyFeeToSetter() {
        require(
            msg.sender == feeToSetter,
            "Only feeToSetter can call this function"
        );
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Next token to be deployed
     * @return Latest token address
     */
    function getLatestTokenAddress() public view returns (address) {
        uint256 currentToken = _nextId - 1;
        return allTokens[currentToken];
    }

    /**
     * @notice Get all pair addresses
     */
    function getAllPairs() external view returns (address[] memory) {
        return allPairs;
    }

    /**
     * @notice Get all token addresses
     */
    function getAllTokens() external view returns (address[] memory) {
        return allTokens;
    }

    /**
     * @notice Get the pair address deployed by the factory
     *         PolicyToken address first, and then stablecoin address
     *         The order of the tokens will be sorted inside the function
     * @param _tokenAddress1 Address of token1
     * @param _tokenAddress2 Address of toekn2
     * @return Pool address of the two tokens
     */
    function getPairAddress(address _tokenAddress1, address _tokenAddress2)
        public
        view
        returns (address)
    {
        // Policy token address at the first place
        (address token0, address token1) = IPolicyCore(policyCore)
            .isStablecoinAddress(_tokenAddress2)
            ? (_tokenAddress1, _tokenAddress2)
            : (_tokenAddress2, _tokenAddress1);

        address _pairAddress = getPair[token0][token1];

        return _pairAddress;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Set Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Remember to call this function to set the policyCore address
     *         < PolicyCore should be the owner of policyToken >
     * @param _policyCore: Address of policyCore contract
     */
    function setPolicyCoreAddress(address _policyCore) external {
        policyCore = _policyCore;
    }

    /**
     * @notice Set feeTo address
     * @param _feeTo Address to receive the fee
     */
    function setFeeTo(address _feeTo) external onlyFeeToSetter {
        feeTo = _feeTo;
    }

    /**
     * @notice Set feeToSetter address
     * @param _feeToSetter Address to control the feeTo
     */
    function setFeeToSetter(address _feeToSetter) external onlyFeeToSetter {
        feeToSetter = _feeToSetter;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Main Functions *********************************** //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice After deploy the policytoken and get the address,
     *         we deploy the policyToken - stablecoin pool contract
     * @param _policyTokenAddress: Address of policy token
     * @param _stablecoin: Address of the stable coin
     * @return Address of the pool
     */
    function deployPool(
        address _policyTokenAddress,
        address _stablecoin,
        uint256 _deadline
    ) public returns (address) {
        require(
            IPolicyCore(policyCore).isStablecoinAddress(_stablecoin) == true,
            "You give the wrong order of policyToken and stablecoin"
        );

        bytes memory bytecode = type(NaughtyPair).creationCode;

        bytes32 salt = keccak256(
            abi.encodePacked(
                addressToString(_policyTokenAddress),
                addressToString(_stablecoin)
            )
        );

        address _poolAddress = _deploy(bytecode, salt);

        INaughtyPair(_poolAddress).initialize(
            _policyTokenAddress,
            _stablecoin,
            _deadline
        );

        getPair[_policyTokenAddress][_stablecoin] = _poolAddress;

        allPairs.push(_poolAddress);

        return _poolAddress;
    }

    /**
     * @notice For each round we need to first create the policytoken(ERC20)
     * @param _policyTokenName: Name of the policyToken
     * @return PolicyToken address
     */
    function deployPolicyToken(string memory _policyTokenName)
        public
        returns (address)
    {
        bytes32 salt = keccak256(abi.encodePacked(_policyTokenName));

        bytes memory bytecode = getPolicyTokenBytecode(_policyTokenName);

        address _policTokenAddress = _deploy(bytecode, salt);

        allTokens.push(_policTokenAddress);

        _nextId++;

        return _policTokenAddress;
    }

    /**
     * @notice Deploy function with create2
     */
    function _deploy(bytes memory code, bytes32 salt)
        internal
        returns (address addr)
    {
        assembly {
            addr := create2(0, add(code, 0x20), mload(code), salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }
    }

    /**
     * @notice Transfer address to string
     * @param _addr: Input address
     * @return Output string form
     */
    function addressToString(address _addr)
        internal
        pure
        returns (string memory)
    {
        return (uint256(uint160(_addr))).toHexString(20);
    }

    /**
     * @notice Get the policyToken bytecode (with parameters)
     * @param _tokenName: Name of policyToken
     */
    function getPolicyTokenBytecode(string memory _tokenName)
        internal
        view
        returns (bytes memory)
    {
        bytes memory bytecode = type(NPPolicyToken).creationCode;

        // Encodepacked the parameters
        // The owner & minter is set to be the policyCore address
        return
            abi.encodePacked(
                bytecode,
                abi.encode(_tokenName, _tokenName, policyCore)
            );
    }
}

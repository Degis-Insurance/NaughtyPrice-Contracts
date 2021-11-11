// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./PolicyToken.sol";
import "./NaughtyPair.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/INaughtyPair.sol";
import "./interfaces/INaughtyFactory.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Naughty Factory
 * @dev Factory contract to deploy new pools periodically
 *      Each pool(product) will have a unique naughtyId
 *      Each pool will have its pool token
 *      InsuranceToken - USDT
 *      Token 0 may change but Token 1 is always USDT.
 */

contract NaughtyFactory is INaughtyFactory {
    using Strings for uint256;

    ///@dev Token0 Address => Pool Address
    mapping(address => address) getPair;
    address[] allPairs;
    address[] allTokens;

    address public feeTo;
    address public feeToSetter;

    uint256 public _nextId;

    address public USDT;

    address public policyCore;

    constructor(address _feeToSetter, address _USDT) {
        feeToSetter = _feeToSetter;
        USDT = _USDT;
    }

    /**
     * @notice Next token to be deployed
     */
    function getLatestTokenAddress() public view returns (address) {
        uint256 currentToken = _nextId - 1;
        return allTokens[currentToken];
    }

    /**
     * @notice Get the pair address deployed by the factory
     *         Index the pair address by the insurance token address rather than USDT address
     *         The order of the token not matters
     */
    function getPairAddress(address _tokenAddress1, address _tokenAddress2)
        public
        view
        returns (address _pairAddress)
    {
        if (_tokenAddress1 == USDT) {
            _pairAddress = getPair[_tokenAddress2];
        } else {
            _pairAddress = getPair[_tokenAddress1];
        }
    }

    /**
     * @notice Remember to call this function to set the policyCore address
     *         < PolicyCore should be the owner of policyToken >
     * @param _policyCore: Address of policyCore contract
     */
    function setPolicyCoreAddress(address _policyCore) external {
        policyCore = _policyCore;
    }

    /**
     * @notice After deploy the policytoken and get the address,
     *         we deploy the IT-USDT pool contract
     * @param _policyToken: Address of policy token
     */
    function deployPool(address _policyToken)
        public
        returns (address _poolAddress)
    {
        bytes memory bytecode = type(NaughtyPair).creationCode;

        bytes32 salt = keccak256(
            abi.encodePacked(
                addressToString(_policyToken),
                addressToString(USDT)
            )
        );

        _poolAddress = _deploy(bytecode, salt);

        INaughtyPair(_poolAddress).initialize(_policyToken, USDT);

        getPair[_policyToken] = _poolAddress;
    }

    /**
     * @notice For each round we need to first create the policytoken(ERC20)
     * @param _tokenName: Name of the policyToken
     */
    function deployPolicyToken(string memory _tokenName)
        public
        returns (address _tokenAddress)
    {
        bytes32 salt = keccak256(
            abi.encodePacked(_tokenName, addressToString(USDT))
        );

        bytes memory bytecode = getPolicyTokenBytecode(_tokenName);

        _tokenAddress = _deploy(bytecode, salt);

        allTokens.push(_tokenAddress);
        _nextId++;
    }

    /// @notice Deploy function with create2
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
     * @notice Set the "feeTo" account, only called by the "feeToSetter"
     */
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, "only feetosetter can call");
        feeTo = _feeTo;
    }

    /**
     * @notice Set the new "feeToSetter" account, only called by the old "feeToSetter"
     */
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, "only feetosetter can call");
        feeToSetter = _feeToSetter;
    }

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
        bytes memory bytecode = type(PolicyToken).creationCode;

        // Encodepacked the parameters
        return
            abi.encodePacked(
                bytecode,
                abi.encode(_tokenName, _tokenName, policyCore)
            );
    }
}

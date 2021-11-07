// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./PolicyToken.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Naughty Factory
 * @dev Factory contract to deploy new pools periodically
 *      Each pool(product) will have a unique naughtyId
 *      Each pool will have its pool token
 *      InsuranceToken - USDT
 *      Token 0 may change but Token 1 is always USDT.
 */

contract NaughtyFactory {
    ///@dev Token0 Address => Pool Address
    mapping(address => address) getPair;
    address[] allPairs;
    address[] allTokens;

    address public USDT;

    /**
     * @notice Get the pair address deployed by the factory
     *         Index the pair address by the insurance token address rather than USDT address
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
     * @notice For each round we need to first create the policytoken(ERC20)
     */
    function deployPolicyToken(string memory _tokenName)
        public
        returns (address _tokenAddress)
    {
        bytes32 salt = keccak256(abi.encodePacked(_tokenName, USDT));

        bytes memory bytecode = type(PolicyToken).creationCode;

        _tokenAddress = _deploy(bytecode, salt);
    }

    /**
     * @notice After deploy the policytoken and get the address, we deploy the IT-USDT pool contract
     */
    function deployPool(bytes32 _salt) public returns (address _poolAddress) {
        bytes memory bytecode = type(PolicyToken).creationCode;

        _poolAddress = _deploy(bytecode, _salt);
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
}

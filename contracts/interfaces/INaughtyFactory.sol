// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface INaughtyFactory {
    function getPairAddress(address _tokenAddress1, address _tokenAddress2)
        external
        returns (address);

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function deployPolicyToken(string memory) external returns (address);

    function deployPool(address) external returns (address);
}

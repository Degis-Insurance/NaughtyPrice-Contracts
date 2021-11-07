// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface INaughtyFactory {
    function getPairAddress(address _tokenAddress1, address _tokenAddress2)
        external
        returns (address);
}

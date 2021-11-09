// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

contract PriceGetter is ChainlinkClient {
    using Chainlink for Chainlink.Request;

    uint256 fee;
    address oracleAddress;
    bytes32 jobId;

    /**
     * Chainlink Price Feed to be added here
     */
}

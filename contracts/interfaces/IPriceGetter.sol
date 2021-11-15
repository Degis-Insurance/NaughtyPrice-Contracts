// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IPriceGetter {
    event SetPriceFeed(string _tokenName, address _feedAddress);

    event GetLatestPrice(
        uint80 roundID,
        int256 price,
        uint256 startedAt,
        uint256 timeStamp,
        uint80 answeredInRound
    );

    function setPriceFeed(string memory _tokenName, address _feedAddress)
        external;

    function getLatestPrice(string memory _tokenName) external returns (int256);
}

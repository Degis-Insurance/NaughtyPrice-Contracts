// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract PriceGetter {
    mapping(address => AggregatorV3Interface) internal priceFeed;

    uint256 fee;
    address oracleAddress;
    bytes32 jobId;

    address public owner;

    event SetPriceFeed(address _tokenAddress, address _feedAddress);

    /**
     * Chainlink Price Feed to be added here
     */
    constructor() {}

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier notZeroAddress(address _address) {
        require(_address != address(0), "can not give zero address");
        _;
    }

    function setPriceFeed(address _tokenAddress, address _feedAddress)
        public
        onlyOwner
        notZeroAddress(_feedAddress)
    {
        priceFeed[_tokenAddress] = AggregatorV3Interface(_feedAddress);

        emit SetPriceFeed(_tokenAddress, _feedAddress);
    }

    function getLatestPrice(address _tokenAddress)
        public
        view
        returns (int256)
    {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed[_tokenAddress].latestRoundData();
        return price;
    }
}

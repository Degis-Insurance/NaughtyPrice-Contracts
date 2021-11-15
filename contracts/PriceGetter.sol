// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IPriceGetter.sol";

contract PriceGetter is IPriceGetter {
    // Use token name (string) as the mapping key
    mapping(string => AggregatorV3Interface) internal priceFeed;

    address public owner;

    /**
     * @notice Constructor function, initialize some price feed
     */
    constructor() {
        // At first, launch three kind of pools
        priceFeed["AVAX"] = AggregatorV3Interface(
            0x0A77230d17318075983913bC2145DB16C7366156
        );

        priceFeed["ETH"] = AggregatorV3Interface(
            0x976B3D034E162d8bD72D6b9C989d545b839003b0
        );

        priceFeed["BTC"] = AggregatorV3Interface(
            0x2779D32d5166BAaa2B2b658333bA7e6Ec0C65743
        );
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    modifier notZeroAddress(address _address) {
        require(_address != address(0), "can not give zero address");
        _;
    }

    /**
     * @notice Set a price feed oracle address for a token
     * @param _tokenName: Address of the token
     * @param _feedAddress: Price feed oracle address
     */
    function setPriceFeed(string memory _tokenName, address _feedAddress)
        public
        onlyOwner
        notZeroAddress(_feedAddress)
    {
        priceFeed[_tokenName] = AggregatorV3Interface(_feedAddress);

        emit SetPriceFeed(_tokenName, _feedAddress);
    }

    /**
     * @notice Get latest price of a token
     * @param _tokenName: Address of the token
     */
    function getLatestPrice(string memory _tokenName) public returns (int256) {
        (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        ) = priceFeed[_tokenName].latestRoundData();

        emit GetLatestPrice(
            roundID,
            price,
            startedAt,
            timeStamp,
            answeredInRound
        );
        return price;
    }
}

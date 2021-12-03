// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IPriceGetter.sol";

/**
 * @title  Price Getter
 * @notice This is the contract for getting price feed from chainlink.
 *         The contract will keep a record from tokenName => priceFeed Address.
 *         Got the sponsorship and collaboration with Chainlink.
 */
contract PriceGetter is IPriceGetter {
    // Use token name (string) as the mapping key
    mapping(string => AggregatorV3Interface) internal priceFeed;
    mapping(string => address) currentPriceFeed;

    address public owner;

    /**
     * @notice Constructor function, initialize some price feed
     */
    constructor() {
        // At first, launch three kind of pools

        // This is the rinkeby eth price feed
        priceFeed["ETH"] = AggregatorV3Interface(
            0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
        );
        currentPriceFeed["ETH"] = 0x8A753747A1Fa494EC906cE90E9f37563A8AF630e;

        priceFeed["BTC"] = AggregatorV3Interface(
            0xECe365B379E1dD183B20fc5f022230C044d51404
        );
        currentPriceFeed["BTC"] = 0xECe365B379E1dD183B20fc5f022230C044d51404;

        // Uncomment below when launched on Avalanche
        // priceFeed["AVAX"] = AggregatorV3Interface(
        //     0x0A77230d17318075983913bC2145DB16C7366156
        // );

        // priceFeed["ETH"] = AggregatorV3Interface(
        //     0x976B3D034E162d8bD72D6b9C989d545b839003b0
        // );

        // priceFeed["BTC"] = AggregatorV3Interface(
        //     0x2779D32d5166BAaa2B2b658333bA7e6Ec0C65743
        // );

        owner = msg.sender;
    }

    // ---------------------------------------------------------------------------------------- //
    // *************************************** Modifiers ************************************** //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Only the owner can call this function
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    /**
     * @notice Can not give zero address
     */
    modifier notZeroAddress(address _address) {
        require(_address != address(0), "can not give zero address");
        _;
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ View Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Get the price feed address of a token
     * @param _tokenName Name of the strike token
     */
    function getPriceFeedAddress(string memory _tokenName)
        public
        view
        returns (address)
    {
        return currentPriceFeed[_tokenName];
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Set Functions ************************************* //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Set a price feed oracle address for a token
     * @param _tokenName Address of the token
     * @param _feedAddress Price feed oracle address
     */
    function setPriceFeed(string memory _tokenName, address _feedAddress)
        public
        onlyOwner
        notZeroAddress(_feedAddress)
    {
        priceFeed[_tokenName] = AggregatorV3Interface(_feedAddress);
        currentPriceFeed[_tokenName] = _feedAddress;

        emit SetPriceFeed(_tokenName, _feedAddress);
    }

    // ---------------------------------------------------------------------------------------- //
    // ************************************* Main Functions *********************************** //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Get latest price of a token
     * @param _tokenName Address of the token
     * @return price The latest price
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

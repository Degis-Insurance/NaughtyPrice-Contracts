// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IPolicyCore {
    event SettleFinalResult(
        string _policyTokenName,
        int256 price,
        bool isHappened
    );
    event NewStablecoinAdded(address _newStablecoin);
    event PurchaseIncentiveRatioSet(uint256 _newRatio);

    function isStablecoinAddress(address _coinAddress)
        external
        view
        returns (bool);

    function deployPolicyToken(
        string memory _policyTokenName,
        address _tokenAddress,
        bool _isHigher,
        uint256 _strikePrice,
        uint256 _deadline,
        uint256 _settleTimestamp
    ) external returns (address);

    function deployPool(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _poolDeadline
    ) external returns (address);

    function deposit(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount
    ) external;

    function redeem(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount
    ) external;

    function claim(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount
    ) external;
}

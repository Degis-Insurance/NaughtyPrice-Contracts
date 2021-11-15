// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IPolicyCore {
    event SettleFinalResult(string _policyTokenName, int256 price);

    function isStablecoinAddress(address _coinAddress) external returns (bool);

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

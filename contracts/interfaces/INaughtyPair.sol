// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface INaughtyPair is IERC20 {
    function deadline() external view returns (uint256);

    function getReserves() external view returns (uint112, uint112);

    function getPairAddress(
        address,
        address,
        address
    ) external returns (address);

    function swap(
        uint256,
        uint256,
        address
    ) external;

    function burn(address) external returns (uint256, uint256);

    function mint(address) external returns (uint256);

    function initialize(
        address _token0,
        address _token1,
        uint256 _deadline
    ) external;
}

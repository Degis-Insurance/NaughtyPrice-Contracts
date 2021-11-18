// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20("USDT", "USDT") {
    uint256 initial_mint = 1000e18;

    constructor() {
        _mint(msg.sender, initial_mint);
    }

    function mint(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }
}

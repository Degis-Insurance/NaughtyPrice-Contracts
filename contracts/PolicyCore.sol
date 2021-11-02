// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract PolicyCore {
    address public owner;
    IERC20 public USDT;
    IERC721 public 

    constructor(address _usdt) {
        USDT = IERC20(_usdt);
    }

    function mintPolicyToken(address _policyAddress) public {}
}

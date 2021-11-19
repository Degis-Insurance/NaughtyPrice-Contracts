// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IPolicyToken.sol";

contract PolicyToken is ERC20, IPolicyToken {
    address public owner;
    address public minter;

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner
    ) ERC20(_name, _symbol) {
        owner = _owner;
        minter = _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner can call this function");
        _;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "only minter can call this function");
        _;
    }

    function passMinterRole(address _newMinter) public onlyOwner {
        address oldMinter = minter;
        minter = _newMinter;
        emit MinterRoleChanged(oldMinter, _newMinter);
    }

    function mint(address _account, uint256 _amount) public onlyMinter {
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) public onlyMinter {
        _burn(_account, _amount);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBuyerToken is IERC20 {
    event MinterAdded(address _newMinter);
    event MinterRemoved(address _oldMinter);

    event BurnerAdded(address _newBurner);
    event BurnerRemoved(address _oldBurner);

    event OwnerChanged(address indexed _oldOwner, address indexed _newOwner);
    event ReleaseOwnership(address indexed _oldOwner);

    function mint(address _account, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;

    function addMinter(address _newMinter) external;

    function removeMinter(address _oldMinter) external;

    function addBurner(address _newBurner) external;

    function removeBurner(address _oldBurner) external;
}

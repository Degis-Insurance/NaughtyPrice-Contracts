pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPolicyToken is IERC20 {
    function passMinterRole(address _newMinter) external;

    function mint(address _account, uint256 _amount) external;

    function burn(address _account, uint256 _amount) external;
}

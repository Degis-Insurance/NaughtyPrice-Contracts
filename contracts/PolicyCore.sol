// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title PolicyCore
 * @dev Deposit USDT and mint PolicyTokens
 */
contract PolicyCore {
    using SafeERC20 for IERC20;

    address public owner;
    IERC20 public USDT;

    mapping(address => mapping(uint256 => uint256)) userQuota;

    constructor(address _usdt) {
        USDT = IERC20(_usdt);
    }

    /**
     @notice Mint Policy Token 1:1 USDT
     */
    function mintPolicyToken(address _policyToken, uint256 _amount) public {
        IERC20 policyToken = IERC20(_policyToken);

        USDT.safeTransferFrom(msg.sender, address(this), _amount);

        policyToken.mint(msg.sender, _amount);
    }

    /**
     * @notice
     */
    function addLiquidity() external {}

    function removeLiquidity() external {}

    function swapTokensforExactTokens(
        uint256 _amountIn,
        uint256 _amountOut,
        address _to
    ) external {}

    function swapExactTokensforTokens(
        uint256 _amountIn,
        uint256 _amountOut,
        address _to
    ) external {}
}

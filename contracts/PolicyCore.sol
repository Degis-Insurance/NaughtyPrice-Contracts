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

    address public factory;

    address public owner;
    IERC20 public USDT;

    mapping(address => mapping(uint256 => uint256)) userQuota;

    constructor(address _usdt) {
        USDT = IERC20(_usdt);
    }

    modifer beforeDeadline(uint256 _deadLine) {
        require (block.timestamp < _deadLine, "expired transaction");
        _;
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

    /**
     * @notice 指定换出的token数量
     * @param _amountIn:
     */
    function swapTokensforExactTokens(
        uint256 _amountInMax,
        uint256 _amountOut,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    ) external beforeDeadLine(_deadLine) returns(uint256 amounts){
        uint256 amounts = NaughtyLibrary.getAmountsIn(factory, _amountOut, _tokenIn, _tokenOut);
        require(
            amounts<= amountInMax,
            "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
        );
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            UniswapV2Library.pairFor(factory, path[0], path[1]),
            amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapExactTokensforTokens(
        uint256 _amountIn,
        uint256 _amountOut,
        address _to
    ) external {}
}

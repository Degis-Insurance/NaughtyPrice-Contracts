// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./libraries/NaughtyLibrary.sol";

import "./interfaces/IPolicyToken.sol";

contract NaughtyRouter {
    using SafeERC20 for IERC20;
    using SafeERC20 for INaughtyPair;

    address public factory;

    address public owner;
    address public USDT;

    mapping(address => mapping(uint256 => uint256)) userQuota;

    constructor(address _usdt, address _factory) {
        USDT = _usdt;
        owner = msg.sender;
        factory = _factory;
    }

    modifier beforeDeadline(uint256 _deadLine) {
        require(block.timestamp < _deadLine, "expired transaction");
        _;
    }

    /**
     * @notice Add liquidity
     */
    function addLiquidity(
        address _token0,
        address _token1,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    )
        external
        beforeDeadline(_deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        {
            (amountA, amountB) = _addLiquidity(
                _token0,
                _token1,
                _amountADesired,
                _amountBDesired,
                _amountAMin,
                _amountBMin
            );
        }

        address pair = NaughtyLibrary.getPairAddress(factory, _token0, _token1);

        transferHelper(_token0, msg.sender, pair, amountA);
        transferHelper(_token1, msg.sender, pair, amountB);
        // {
        //     IERC20(_token0).safeTransferFrom(msg.sender, pair, amountA);
        //     IERC20(_token1).safeTransferFrom(msg.sender, pair, amountB);
        // }

        liquidity = INaughtyPair(pair).mint(_to);
    }

    function transferHelper(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        IERC20(_token).safeTransferFrom(_from, _to, _amount);
    }

    /**
     * @notice Add liquidity
     */
    function _addLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin
    ) private returns (uint256 amountA, uint256 amountB) {
        require(_tokenB == USDT, "please put usdt as tokenB parameter");

        (uint256 reserveA, uint256 reserveB) = NaughtyLibrary.getReserves(
            factory,
            _tokenA,
            _tokenB
        );
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (_amountADesired, _amountBDesired);
        } else {
            uint256 amountBOptimal = NaughtyLibrary.quote(
                _amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= _amountBDesired) {
                require(amountBOptimal >= _amountBMin, "INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (_amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = NaughtyLibrary.quote(
                    _amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= _amountADesired);
                require(amountAOptimal >= _amountAMin, "INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, _amountBDesired);
            }
        }
    }

    /**
     * @notice Remove liquidity from the pool
     * @param _tokenA: Insurance token address
     * @param _liquidity: The lptoken amount to be removed
     * @param _amountAMin:
     */
    function removeLiquidity(
        address _tokenA,
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 deadline
    )
        public
        beforeDeadline(deadline)
        returns (uint256 amount0, uint256 amount1)
    {
        address pair = NaughtyLibrary.getPairAddress(factory, _tokenA, USDT);

        INaughtyPair(pair).safeTransferFrom(msg.sender, pair, _liquidity); // send liquidity to pair

        // amount0: insurance token
        (amount0, amount1) = INaughtyPair(pair).burn(_to);

        require(amount0 >= _amountAMin, "Insufficient insurance token amount");
        require(amount1 >= _amountBMin, "Insufficient USDT token");
    }

    /**
     * @notice 指定换出的token数量
     * @param _amountInMax: zz
     */
    function swapTokensforExactTokens(
        uint256 _amountInMax,
        uint256 _amountOut,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    ) external beforeDeadline(_deadline) returns (uint256 amounts) {
        amounts = NaughtyLibrary.getAmountsIn(
            factory,
            _amountOut,
            _tokenIn,
            _tokenOut
        );

        require(amounts <= _amountInMax, "excessive output amount");

        IERC20(_tokenIn).safeTransferFrom(
            msg.sender,
            NaughtyLibrary.getPairAddress(factory, _tokenIn, _tokenOut),
            amounts
        );

        uint256 amount0Out = (_tokenIn == USDT) ? _amountOut : 0;
        uint256 amount1Out = (_tokenIn == USDT) ? 0 : _amountOut;

        address pair = NaughtyLibrary.getPairAddress(
            factory,
            _tokenIn,
            _tokenOut
        );

        INaughtyPair(pair).swap(amount0Out, amount1Out, _to);
    }

    /**
     * @notice 指定输入的token数量
     * @param _amountIn: The exact amount of the tokens put in
     * @param _amountOutMin: Minimum amount of tokens out, if not reach then revert
     */
    function swapExactTokensforTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    ) external beforeDeadline(_deadline) returns (uint256 amounts) {
        amounts = NaughtyLibrary.getAmountsOut(
            factory,
            _amountIn,
            _tokenIn,
            _tokenOut
        );

        require(amounts >= _amountOutMin, "excessive output amount");

        IERC20(_tokenIn).safeTransferFrom(
            msg.sender,
            NaughtyLibrary.getPairAddress(factory, _tokenIn, _tokenOut),
            _amountIn
        );

        uint256 amount0Out = (_tokenIn == USDT) ? amounts : 0;
        uint256 amount1Out = (_tokenIn == USDT) ? 0 : amounts;

        address pair = NaughtyLibrary.getPairAddress(
            factory,
            _tokenIn,
            _tokenOut
        );

        INaughtyPair(pair).swap(amount0Out, amount1Out, _to);
    }
}

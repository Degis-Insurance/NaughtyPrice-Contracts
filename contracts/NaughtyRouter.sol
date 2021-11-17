// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./libraries/NaughtyLibrary.sol";

import "./interfaces/IPolicyToken.sol";

/**
 * @title NaughtyRouter

 */
contract NaughtyRouter {
    using SafeERC20 for IERC20;
    using SafeERC20 for INaughtyPair;

    // Some other contracts
    address public factory;
    address public policyCore;

    address public owner;

    mapping(address => mapping(uint256 => uint256)) userQuota;

    constructor(address _factory) {
        owner = msg.sender;
        factory = _factory;
    }

    modifier beforeDeadline(uint256 _deadLine) {
        require(block.timestamp < _deadLine, "expired transaction");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function setPolicyCore(address _coreAddress) public onlyOwner {
        policyCore = _coreAddress;
    }

    /**
     * @notice Add liquidity
     * @param _token0: Address of policyToken
     * @param _token1: Address of USDT
     * @param _amountADesired: Amount of policyToken desired
     * @param _amountBDesired: Amount of USDT desired
     * @param _amountAMin: Minimum amoutn of policyToken
     * @param _amountBMin: Minimum amount of USDT
     * @param _to: Address that receive the lp token, normally the user himself
     * @param _deadline: Transaction will revert after this deadline
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

        liquidity = INaughtyPair(pair).mint(_to);
    }

    /**
     * @notice Remove liquidity from the pool
     * @param _tokenA: Insurance token address
     * @param _liquidity: The lptoken amount to be removed
     * @param _amountAMin: Minimum
     */
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    )
        public
        beforeDeadline(_deadline)
        returns (uint256 amount0, uint256 amount1)
    {
        address pair = NaughtyLibrary.getPairAddress(factory, _tokenA, _tokenB);

        INaughtyPair(pair).safeTransferFrom(msg.sender, pair, _liquidity); // send liquidity to pair

        // Amount0: insurance token
        (amount0, amount1) = INaughtyPair(pair).burn(_to);

        require(amount0 >= _amountAMin, "Insufficient insurance token amount");
        require(amount1 >= _amountBMin, "Insufficient USDT token");
    }

    /**
     * @notice Amount out is fixed
     * @param _amountInMax: Maximum token input
     * @param _amountOut: Fixed token output
     * @param _tokenIn: Address of input token
     * @param _tokenOut: Address of output token
     * @param _to: Swapper address
     * @param _deadline: Deadline for this specific swap
     */
    function swapTokensforExactTokens(
        uint256 _amountInMax,
        uint256 _amountOut,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    ) external beforeDeadline(_deadline) returns (uint256 amounts) {
        address pair = NaughtyLibrary.getPairAddress(
            factory,
            _tokenIn,
            _tokenOut
        );
        // Each pool has a deadline
        uint256 poolDeadline = INaughtyPair(pair).deadline();
        require(
            block.timestamp <= poolDeadline,
            "This pool has been frozen for swapping"
        );

        // Get how many tokens should be put in
        amounts = NaughtyLibrary.getAmountsIn(
            factory,
            _amountOut,
            _tokenIn,
            _tokenOut
        );

        require(amounts <= _amountInMax, "excessive input amount");

        IERC20(_tokenIn).safeTransferFrom(msg.sender, pair, amounts);

        // If tokenIn is usd then amount0Out = amountOut
        bool isStablecoin = NaughtyLibrary.checkStablecoin(
            policyCore,
            _tokenIn
        );
        uint256 amount0Out = isStablecoin ? _amountOut : 0;
        uint256 amount1Out = isStablecoin ? 0 : _amountOut;

        INaughtyPair(pair).swap(amount0Out, amount1Out, _to);
    }

    /**
     * @notice Amount in is fixed
     * @param _amountIn: Fixed token input
     * @param _amountOutMin: Minimum token output
     * @param _tokenIn: Address of input token
     * @param _tokenOut: Address of output token
     * @param _to: Swapper address
     * @param _deadline: Deadline for this specific swap
     */
    function swapExactTokensforTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    ) external beforeDeadline(_deadline) returns (uint256 amounts) {
        address pair = NaughtyLibrary.getPairAddress(
            factory,
            _tokenIn,
            _tokenOut
        );
        // Each pool has a deadline
        uint256 poolDeadline = INaughtyPair(pair).deadline();
        require(
            block.timestamp <= poolDeadline,
            "This pool has been frozen for swapping"
        );

        amounts = NaughtyLibrary.getAmountsOut(
            factory,
            _amountIn,
            _tokenIn,
            _tokenOut
        );

        require(amounts >= _amountOutMin, "excessive output amount");

        IERC20(_tokenIn).safeTransferFrom(msg.sender, pair, _amountIn);

        // Check if the tokenIn is stablecoin
        bool isStablecoin = NaughtyLibrary.checkStablecoin(
            policyCore,
            _tokenIn
        );

        uint256 amount0Out = isStablecoin ? amounts : 0;
        uint256 amount1Out = isStablecoin ? 0 : amounts;

        INaughtyPair(pair).swap(amount0Out, amount1Out, _to);
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
    ) private view returns (uint256 amountA, uint256 amountB) {
        bool isStablecoin = NaughtyLibrary.checkStablecoin(policyCore, _tokenB);
        require(isStablecoin, "please put stablecoin as tokenB parameter");

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
                require(amountAOptimal <= _amountADesired, "nonono");
                require(amountAOptimal >= _amountAMin, "INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, _amountBDesired);
            }
        }
    }

    /**
     * @notice Finish the erc20 transfer operation
     * @param _token: ERC20 token address
     * @param _from: Address to give out the token
     * @param _to: Pair address to receive the token
     * @param _amount: Transfer amount
     */
    function transferHelper(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        IERC20(_token).safeTransferFrom(_from, _to, _amount);
    }
}

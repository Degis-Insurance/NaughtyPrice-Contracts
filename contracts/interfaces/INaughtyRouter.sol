// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface INaughtyRouter {
    function setPolicyCore(address _coreAddress) external;

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
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidiyWithUSD(
        address _tokenA,
        address _tokenB,
        uint256 _amountUSD,
        address _to,
        uint256 _minRatio,
        uint256 _deadline
    ) external;

    /**
     * @notice Remove liquidity from the pool
     * @param _tokenA: Insurance token address
     * @param _tokenB: Stablecoin address
     * @param _liquidity: The lptoken amount to be removed
     * @param _amountAMin: Minimum policy token amount
     * @param _amountBMin: Minimum stablecoin amount
     */
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 deadline
    ) external returns (uint256 amount0, uint256 amount1);

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
    ) external returns (uint256 amounts);

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
    ) external returns (uint256 amounts);
}

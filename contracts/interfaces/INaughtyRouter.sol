// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface INaughtyRouter {
    /**
     * @notice Interfaces for public variables
     */
    function factory() external view returns (address);

    function policyCore() external view returns (address);

    function buyerToken() external view returns (address);

    /**
     * @notice Interfaces for set functions
     *         These functions normally are only available for the owner
     */
    function setPolicyCore(address _coreAddress) external;

    function setBuyerToken(address _buyerToken) external;

    // ---------------------------------------------------------------------------------------- //
    // ************************************ Main Functions ************************************ //
    // ---------------------------------------------------------------------------------------- //

    /**
     * @notice Add liquidity function
     * @param _tokenA Address of policyToken
     * @param _tokenB Address of stablecoin
     * @param _amountADesired Amount of policyToken desired
     * @param _amountBDesired Amount of stablecoin desired
     * @param _amountAMin Minimum amoutn of policy token
     * @param _amountBMin Minimum amount of stablecoin
     * @param _to Address that receive the lp token, normally the user himself
     * @param _deadline Transaction will revert after this deadline
     * @return amountA Amount of tokenA to be input
     * @return amountB Amount of tokenB to be input
     * @return liquidity LP token to be mint
     */
    function addLiquidity(
        address _tokenA,
        address _tokenB,
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

    /**
     * @notice Add liquidity but only provide stablecoins
     * @param _tokenA Address of policyToken
     * @param _tokenB Address of stablecoin
     * @param _amountUSD Amount of stablecoins provided
     * @param _to Address that receive the lp token, normally the user himself
     * @param _minRatio Minimum ratio (divided by 100)(amountMin / amountDesired)
     * @param _deadline Transaction will revert after this deadline
     */
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
     * @param _tokenA Address of policy token
     * @param _tokenB Address of stablecoin
     * @param _liquidity The lptoken amount to be removed
     * @param _amountAMin Minimum amount of tokenA given out
     * @param _amountBMin Minimum amount of tokenB given out
     * @param _to User address
     * @param _deadline Deadline of this transaction
     * @return amountA Amount of token0 given out
     * @return amountB Amount of token1 given out
     */
    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external returns (uint256 amountA, uint256 amountB);

    /**
     * @notice Amount out is fixed
     * @param _amountInMax Maximum token input
     * @param _amountOut Fixed token output
     * @param _tokenIn Address of input token
     * @param _tokenOut Address of output token
     * @param _to User address
     * @param _deadline Deadline for this specific swap
     * @return amounts Amounts to be really put in
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
     * @notice Amount in is fixed
     * @param _amountIn Fixed token input
     * @param _amountOutMin Minimum token output
     * @param _tokenIn Address of input token
     * @param _tokenOut Address of output token
     * @param _to User address
     * @param _deadline Deadline for this specific swap
     * @return amounts Amounts to be really given out
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

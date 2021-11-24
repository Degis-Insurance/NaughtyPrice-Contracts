// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../interfaces/INaughtyPair.sol";
import "../interfaces/INaughtyFactory.sol";
import "../interfaces/IPolicyCore.sol";

library NaughtyLibrary {
    /**
     * @notice Used when swap exact tokens for tokens (in is fixed)
     */
    function getAmountsOut(
        address factory,
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) internal view returns (uint256 amounts) {
        (uint256 reserveIn, uint256 reserveOut) = getReserves(
            factory,
            _tokenIn,
            _tokenOut
        );
        amounts = getAmountOut(_amountIn, reserveIn, reserveOut);
    }

    /**
     * @notice Used when swap tokens for exact tokens (out is fixed)
     */
    function getAmountsIn(
        address factory,
        uint256 _amountOut,
        address _tokenIn,
        address _tokenOut
    ) internal view returns (uint256 amounts) {
        (uint256 reserveIn, uint256 reserveOut) = getReserves(
            factory,
            _tokenIn,
            _tokenOut
        );
        amounts = getAmountIn(_amountOut, reserveIn, reserveOut);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "insufficient liquidity");

        uint256 amountInWithFee = amountIn * 980;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;

        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "insufficient output amount");
        require(reserveIn > 0 && reserveOut > 0, "insufficient liquidity");

        uint256 numerator = reserveIn * amountOut * 1000;
        uint256 denominator = (reserveOut - amountOut) * 980;
        amountIn = (numerator / denominator) + 1;
    }

    // fetches and sorts the reserves for a pair
    function getReserves(
        address factory,
        address tokenA,
        address tokenB
    ) public view returns (uint112 reserve0, uint112 reserve1) {
        address pairAddress = INaughtyFactory(factory).getPairAddress(
            tokenA,
            tokenB
        );

        (reserve0, reserve1) = INaughtyPair(pairAddress).getReserves();
    }

    /**
     * @notice Get pair address
     * @param factory: Naughty price factory address
     * @param tokenA: TokenA address
     * @param tokenB: TokenB address
     */
    function getPairAddress(
        address factory,
        address tokenA,
        address tokenB
    ) external view returns (address) {
        address pairAddress = INaughtyFactory(factory).getPairAddress(
            tokenA,
            tokenB
        );

        return pairAddress;
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, "insufficient amount");
        require(reserveA > 0 && reserveB > 0, "insufficient liquidity");

        amountB = (amountA * reserveB) / reserveA;
    }

    function checkStablecoin(address policyCore, address _coinAddress)
        public
        view
        returns (bool)
    {
        return IPolicyCore(policyCore).isStablecoinAddress(_coinAddress);
    }
}

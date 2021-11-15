// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "./interfaces/IPolicyCore.sol";
import "./interfaces/INaughtyRouter.sol";

/**
 * @title  NaughtyProxy
 * @notice Proxy contract for naughty price containing all functions
 *         that need to be called from the outside
 */
contract NaughtyProxy {
    address public policyCore;
    address public naughtyRouter;

    address public owner;

    constructor(address _policyCore, address _naughtyRouter) {
        policyCore = _policyCore;
        naughtyRouter = _naughtyRouter;

        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function");
        _;
    }

    function setPolicyCore(address _newPolicyCore) external onlyOwner {
        policyCore = _newPolicyCore;
    }

    function setNaughtyRouter(address _newRouter) external onlyOwner {
        naughtyRouter = _newRouter;
    }

    function deposit(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount
    ) external {
        IPolicyCore(policyCore).deposit(_policyTokenName, _stablecoin, _amount);
    }

    function redeem(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount
    ) external {
        IPolicyCore(policyCore).redeem(_policyTokenName, _stablecoin, _amount);
    }

    function claim(
        string memory _policyTokenName,
        address _stablecoin,
        uint256 _amount
    ) external {
        IPolicyCore(policyCore).claim(_policyTokenName, _stablecoin, _amount);
    }

    function swapExactTokensforTokens(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    ) external {
        INaughtyRouter(naughtyRouter).swapExactTokensforTokens(
            _amountIn,
            _amountOutMin,
            _tokenIn,
            _tokenOut,
            _to,
            _deadline
        );
    }

    function swapTokensforExactTokens(
        uint256 _amountInMax,
        uint256 _amountOut,
        address _tokenIn,
        address _tokenOut,
        address _to,
        uint256 _deadline
    ) external {
        INaughtyRouter(naughtyRouter).swapTokensforExactTokens(
            _amountInMax,
            _amountOut,
            _tokenIn,
            _tokenOut,
            _to,
            _deadline
        );
    }

    function addLiquidity(
        address _token0,
        address _token1,
        uint256 _amountADesired,
        uint256 _amountBDesired,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external {
        INaughtyRouter(naughtyRouter).addLiquidity(
            _token0,
            _token1,
            _amountADesired,
            _amountBDesired,
            _amountAMin,
            _amountBMin,
            _to,
            _deadline
        );
    }

    function removeLiquidity(
        address _tokenA,
        address _tokenB,
        uint256 _liquidity,
        uint256 _amountAMin,
        uint256 _amountBMin,
        address _to,
        uint256 _deadline
    ) external {
        INaughtyRouter(naughtyRouter).removeLiquidity(
            _tokenA,
            _tokenB,
            _liquidity,
            _amountAMin,
            _amountBMin,
            _to,
            _deadline
        );
    }
}

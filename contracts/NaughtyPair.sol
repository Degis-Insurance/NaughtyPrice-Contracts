// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./PoolLPToken.sol";
import "prb-math/contracts/PRBMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/INaughtyFactory.sol";

contract NaughtyPair is PoolLPToken {
    using SafeERC20 for IERC20;

    address public factory; // Factory contract address

    address public token0; // Insurance Token
    address public token1; // USDT

    uint112 private reserve0; // Amount of Insurance Token
    uint112 private reserve1; // Amount of USDT

    bool public unlocked = true;

    uint256 public deadline; // Every pool will have a deadline

    uint256 public constant MINIMUM_LIQUIDITY = 10**3; // minimum liquidity locked

    // uint256 public totalSupply; // Total supply of LP Tokens

    // event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    // event Burn(address indexed sender, uint256 amount0, uint256 amount1);
    event ReserveUpdated(uint256 reserve0, uint256 reserve1);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );

    constructor() {
        factory = msg.sender; // deployed by factory contract
    }

    /**
     * @notice Check Unlock? => Lock => Function => Unlock
     */
    modifier lock() {
        require(unlocked == true, "LOCKED");
        unlocked = false;
        _;
        unlocked = true;
    }

    /**
     * @notice Initialize the contract status after the deployment by factory
     */
    function initialize(
        address _token0,
        address _token1,
        uint256 _deadline
    ) external {
        require(
            msg.sender == factory,
            "can only be initialized by the factory contract"
        );

        token0 = _token0;
        token1 = _token1;
        deadline = _deadline; // deadline for the whole pool after which no swap will be allowed
    }

    /**
     * @notice Get reserve0 (Policy token) and reserve1 (stablecoin)
     */
    function getReserves()
        public
        view
        returns (uint112 _reserve0, uint112 _reserve1)
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    /**
     * @notice Mint LP Token to liquidity providers
     *         Called when adding liquidity.
     */
    function mint(address to) external returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves(); // gas savings

        uint256 balance0 = IERC20(token0).balanceOf(address(this)); // policy token balance after deposit
        uint256 balance1 = IERC20(token1).balanceOf(address(this)); // stablecoin balance after deposit

        uint256 amount0 = balance0 - _reserve0; // just deposit
        uint256 amount1 = balance1 - _reserve1;

        uint256 _totalSupply = totalSupply(); // gas savings
        if (_totalSupply == 0) {
            liquidity = PRBMath.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            LPMint(address(this), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }
        require(liquidity > 0, "insufficient liquidity minted");
        LPMint(to, liquidity);

        _update(balance0, balance1);
    }

    /// @notice Burn LP tokens give back the original tokens
    function burn(address _to)
        external
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 balance0 = IERC20(token0).balanceOf(address(this)); // policy token balance
        uint256 balance1 = IERC20(token1).balanceOf(address(this)); // stablecoin balance

        uint256 liquidity = LPBalanceOf(address(this)); // lp token balance

        uint256 _totalSupply = totalSupply(); // gas savings
        // How many tokens to be sent back
        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;

        require(amount0 > 0 && amount1 > 0, "insufficient liquidity burned");

        // Currently all the liquidity in the pool was just sent by the user, so burn all
        LPBurn(address(this), liquidity);

        // Transfer tokens out and update the balance
        IERC20(token0).safeTransfer(_to, amount0);
        IERC20(token1).safeTransfer(_to, amount1);
        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        _update(balance0, balance1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(
        uint256 _amount0Out,
        uint256 _amount1Out,
        address _to
    ) external lock {
        require(
            _amount0Out > 0 || _amount1Out > 0,
            "Output amount need to be >0"
        );

        (uint256 _reserve0, uint256 _reserve1) = getReserves(); // gas savings
        require(
            _amount0Out < _reserve0 && _amount1Out < _reserve1,
            "Not enough liquidity"
        );

        uint256 balance0;
        uint256 balance1;
        {
            // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(_to != _token0 && _to != _token1, "INVALID_TO");

            if (_amount0Out > 0) IERC20(_token0).safeTransfer(_to, _amount0Out); // optimistically transfer tokens
            if (_amount1Out > 0) IERC20(_token1).safeTransfer(_to, _amount1Out); // optimistically transfer tokens

            balance0 = IERC20(_token0).balanceOf(address(this));
            balance1 = IERC20(_token1).balanceOf(address(this));
        }
        uint256 amount0In = balance0 > _reserve0 - _amount0Out
            ? balance0 - (_reserve0 - _amount0Out)
            : 0;
        uint256 amount1In = balance1 > _reserve1 - _amount1Out
            ? balance1 - (_reserve1 - _amount1Out)
            : 0;
        require(amount0In > 0 || amount1In > 0, "INSUFFICIENT_INPUT_AMOUNT");

        {
            // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
            uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
            require(
                balance0Adjusted * balance1Adjusted >=
                    _reserve0 * _reserve1 * 1000**2,
                "K"
            );
        }

        _update(balance0, balance1);
        emit Swap(
            msg.sender,
            amount0In,
            amount1In,
            _amount0Out,
            _amount1Out,
            _to
        );
    }

    /// @notice Update reserves
    function _update(uint256 balance0, uint256 balance1) private {
        uint112 MAX_NUM = type(uint112).max;
        require(balance0 <= MAX_NUM && balance1 <= MAX_NUM, "uint112 OVERFLOW");

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);

        emit ReserveUpdated(reserve0, reserve1);
    }

    /// @notice Return the smaller one in x and y
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }
}

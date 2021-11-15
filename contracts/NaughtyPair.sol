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

    uint256 private reserve0; // Amount of Insurance Token
    uint256 private reserve1; // Amount of USDT

    bool public unlocked = true;

    uint256 public deadline; // Every pool will have a deadline

    uint256 public kLast; // K after last swap

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
        deadline = _deadline;
    }

    /**
     * @notice Get reserve 0(Insurance token) and reserve 1(USDT)
     */
    function getReserves()
        public
        view
        returns (uint256 _reserve0, uint256 _reserve1)
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
    }

    /**
     * @notice Mint LP Token to liquidity providers
     *         Called when adding liquidity.
     */
    function mint(address to) external returns (uint256 liquidity) {
        (uint256 _reserve0, uint256 _reserve1) = getReserves(); // gas savings

        uint256 balance0 = IERC20(token0).balanceOf(address(this)); //钱已经转进来了之后的balance
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        uint256 amount0 = balance0 - _reserve0; // 转进来的那部分钱
        uint256 amount1 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);

        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
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

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = reserve0 * reserve1; // reserve0 and reserve1 are up-to-date
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint256 _reserve0, uint256 _reserve1)
        private
        returns (bool feeOn)
    {
        address feeTo = INaughtyFactory(factory).feeTo();
        feeOn = feeTo != address(0); // 地址是0就是没开启0.5%fee
        uint256 _kLast = kLast; // gas savings

        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = PRBMath.sqrt(_reserve0 * _reserve1); // sqrt(k)
                uint256 rootKLast = PRBMath.sqrt(_kLast); // sqrt(kLast)
                // sqrt(k) increase => transaction fee got => 1/6 to feeTo address
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = rootK * 5 + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) LPMint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    /// @notice Burn LP tokens give back the original tokens
    function burn(address _to)
        external
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        (uint256 _reserve0, uint256 _reserve1) = getReserves(); // gas savings
        address _token0 = token0; // gas savings Insurance Token
        address _token1 = token1; // gas savings USDT

        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));

        uint256 liquidity = LPBalanceOf(address(this)); // how many lp tokens in the pool

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee

        amount0 = (liquidity * balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = (liquidity * balance1) / _totalSupply; // using balances ensures pro-rata distribution

        require(amount0 > 0 && amount1 > 0, "INSUFFICIENT_LIQUIDITY_BURNED");

        LPBurn(address(this), liquidity);

        IERC20(_token0).safeTransfer(_to, amount0);
        IERC20(_token1).safeTransfer(_to, amount1);

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);

        if (feeOn) kLast = reserve0 * reserve1; // reserve0 and reserve1 are up-to-date
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

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(
            msg.sender,
            amount0In,
            amount1In,
            _amount0Out,
            _amount1Out,
            _to
        );
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(
        uint256 balance0,
        uint256 balance1,
        uint256 _reserve0,
        uint256 _reserve1
    ) private {
        uint256 MAX_NUM = type(uint256).max;
        require(balance0 <= MAX_NUM && balance1 <= MAX_NUM, "uint256 OVERFLOW");

        reserve0 = balance0;
        reserve1 = balance1;

        emit ReserveUpdated(reserve0, reserve1);
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }
}

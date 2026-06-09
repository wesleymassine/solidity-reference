// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// ============================================================
//  DEFI.SOL - Decentralized Finance: Complete Reference
// ============================================================
//
//  Covers the core mechanics behind major DeFi primitives:
//  AMMs, flash loans, oracles, lending/liquidations, yield,
//  stablecoins, governance, and MEV protection.
//
//  All math is shown step by step. Interfaces match the real
//  deployed protocols (Uniswap V2/V3, Aave V3, Chainlink).
//
//  SECTIONS:
//  1.  AMM — Uniswap V2 (constant product x*y=k)
//  2.  AMM — Uniswap V3 (concentrated liquidity)
//  3.  Flash Loans — Aave V3
//  4.  Flash Swaps — Uniswap V3
//  5.  Oracles — Chainlink Price Feeds (push)
//  6.  Oracles — TWAP (Time-Weighted Average Price)
//  6b. Oracles — Pull (Pyth / RedStone / Chronicle)
//  7.  Lending & Borrowing — Core Mechanics
//  8.  Liquidations
//  9.  Interest Rate Models
//  10. Yield Aggregators
//  11. Stablecoins
//  12. Governance & Timelocks
//  13. MEV — Front-running & Protection
//  14. DeFi Security Checklist
//
// ============================================================

// ============================================================
// SECTION 1: AMM — UNISWAP V2 (CONSTANT PRODUCT x * y = k)
// ============================================================

/*
 * CORE INVARIANT: x * y = k
 *   x = reserve of token A
 *   y = reserve of token B
 *   k = constant (must hold after every swap, minus fee)
 *
 * PRICE:
 *   price of A in terms of B = y / x
 *   price of B in terms of A = x / y
 *
 * SWAP OUTPUT (with 0.3% fee):
 *   amountOut = (amountIn * 997 * reserveOut)
 *               / (reserveIn * 1000 + amountIn * 997)
 *
 * PRICE IMPACT:
 *   impact = amountIn / (reserveIn + amountIn)
 *   Large trades relative to pool size → high slippage
 *
 * LIQUIDITY:
 *   L = sqrt(x * y)
 *   When providing liquidity: mint shares proportional to contribution
 *   shares = min(dx/x, dy/y) * totalSupply
 */

interface IUniswapV2Pair {
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function totalSupply() external view returns (uint256);
    function price0CumulativeLast() external view returns (uint256);
    function price1CumulativeLast() external view returns (uint256);
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,   // slippage protection
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA, address tokenB,
        uint256 amountADesired, uint256 amountBDesired,
        uint256 amountAMin,     uint256 amountBMin,
        address to, uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external view returns (uint256[] memory amounts);
}

/// @title UniswapV2Math — Core AMM formulas with full explanations
library UniswapV2Math {

    uint256 constant FEE_NUMERATOR   = 997;  // 0.3% fee  → 997/1000
    uint256 constant FEE_DENOMINATOR = 1000;

    /// @notice Calculate output amount for a swap (getAmountOut)
    /// @dev    Implements: amountOut = (amountIn * 997 * reserveOut)
    ///                                / (reserveIn * 1000 + amountIn * 997)
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0,  "Insufficient input");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        uint256 numerator       = amountInWithFee * reserveOut;
        uint256 denominator     = (reserveIn * FEE_DENOMINATOR) + amountInWithFee;
        amountOut               = numerator / denominator;
    }

    /// @notice Calculate required input to get a specific output
    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "Insufficient output");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 numerator   = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) * FEE_NUMERATOR;
        amountIn            = (numerator / denominator) + 1; // +1 rounds up
    }

    /// @notice Spot price of token0 in terms of token1 (in WAD = 1e18)
    function spotPrice(uint256 reserve0, uint256 reserve1)
        internal pure returns (uint256 price)
    {
        return (reserve1 * 1e18) / reserve0;
    }

    /// @notice Price impact of a trade as a fraction (1e18 = 100%)
    function priceImpact(uint256 amountIn, uint256 reserveIn)
        internal pure returns (uint256)
    {
        return (amountIn * 1e18) / (reserveIn + amountIn);
    }

    /// @notice Liquidity minted for a given deposit
    function getLiquidityMinted(
        uint256 totalSupply,
        uint256 amount0, uint256 amount1,
        uint256 reserve0, uint256 reserve1
    ) internal pure returns (uint256 liquidity) {
        if (totalSupply == 0) {
            // First deposit: geometric mean to set initial price
            liquidity = _sqrt(amount0 * amount1) - 1000; // MINIMUM_LIQUIDITY
        } else {
            // Subsequent deposits: proportional to existing reserves
            liquidity = _min(
                (amount0 * totalSupply) / reserve0,
                (amount1 * totalSupply) / reserve1
            );
        }
    }

    function _sqrt(uint256 x) private pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) { y = z; z = (x / z + z) / 2; }
    }

    function _min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}

/// @title Simple AMM — reference implementation of x*y=k
contract SimpleAMM {

    address public immutable token0;
    address public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint256 public  totalShares;

    mapping(address => uint256) public shares;

    error InsufficientLiquidity();
    error InsufficientOutputAmount();
    error InvalidK();

    event Swap(address indexed sender, uint256 amountIn, uint256 amountOut, bool zeroForOne);
    event LiquidityAdded(address indexed provider, uint256 shares, uint256 amount0, uint256 amount1);
    event LiquidityRemoved(address indexed provider, uint256 shares, uint256 amount0, uint256 amount1);

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    // -------------------------------------------------------
    // Add Liquidity
    // -------------------------------------------------------
    function addLiquidity(uint256 amount0, uint256 amount1)
        external returns (uint256 liquidityShares)
    {
        IERC20(token0).transferFrom(msg.sender, address(this), amount0);
        IERC20(token1).transferFrom(msg.sender, address(this), amount1);

        liquidityShares = UniswapV2Math.getLiquidityMinted(
            totalShares, amount0, amount1, reserve0, reserve1
        );
        require(liquidityShares > 0, "Zero shares");

        shares[msg.sender] += liquidityShares;
        totalShares         += liquidityShares;

        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );

        emit LiquidityAdded(msg.sender, liquidityShares, amount0, amount1);
    }

    // -------------------------------------------------------
    // Remove Liquidity — burn shares, receive proportional tokens
    // -------------------------------------------------------
    function removeLiquidity(uint256 liquidityShares)
        external returns (uint256 amount0, uint256 amount1)
    {
        require(shares[msg.sender] >= liquidityShares, "Insufficient shares");

        uint256 bal0 = IERC20(token0).balanceOf(address(this));
        uint256 bal1 = IERC20(token1).balanceOf(address(this));

        // Proportional withdrawal
        amount0 = (liquidityShares * bal0) / totalShares;
        amount1 = (liquidityShares * bal1) / totalShares;

        shares[msg.sender] -= liquidityShares;
        totalShares         -= liquidityShares;

        IERC20(token0).transfer(msg.sender, amount0);
        IERC20(token1).transfer(msg.sender, amount1);

        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );

        emit LiquidityRemoved(msg.sender, liquidityShares, amount0, amount1);
    }

    // -------------------------------------------------------
    // Swap token0 for token1 (or vice versa)
    // -------------------------------------------------------
    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut  // slippage protection
    ) external returns (uint256 amountOut) {
        require(tokenIn == token0 || tokenIn == token1, "Invalid token");

        bool    zeroForOne = tokenIn == token0;
        address tokenOut   = zeroForOne ? token1 : token0;

        uint256 reserveIn  = zeroForOne ? reserve0 : reserve1;
        uint256 reserveOut = zeroForOne ? reserve1 : reserve0;

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        amountOut = UniswapV2Math.getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut < minAmountOut) revert InsufficientOutputAmount();

        IERC20(tokenOut).transfer(msg.sender, amountOut);

        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );

        emit Swap(msg.sender, amountIn, amountOut, zeroForOne);
    }

    // -------------------------------------------------------
    // Query functions
    // -------------------------------------------------------
    function getReserves() external view returns (uint112, uint112) {
        return (reserve0, reserve1);
    }

    function getAmountOut(address tokenIn, uint256 amountIn)
        external view returns (uint256)
    {
        bool zeroForOne = tokenIn == token0;
        return UniswapV2Math.getAmountOut(
            amountIn,
            zeroForOne ? reserve0 : reserve1,
            zeroForOne ? reserve1 : reserve0
        );
    }

    function _update(uint256 bal0, uint256 bal1) private {
        reserve0 = uint112(bal0);
        reserve1 = uint112(bal1);
    }
}

// ============================================================
// SECTION 2: AMM — UNISWAP V3 (CONCENTRATED LIQUIDITY)
// ============================================================

/*
 * KEY INNOVATIONS vs V2:
 * - Liquidity providers choose a price RANGE [tickLower, tickUpper]
 * - Capital is only active when price is within the range
 * - Much more capital-efficient (up to 4000x for stable pairs)
 * - Multiple fee tiers: 0.01%, 0.05%, 0.3%, 1%
 *
 * MATH CONCEPTS:
 * - Price is represented as sqrt(price) × Q96 (fixed-point)
 * - sqrtPriceX96 = sqrt(price) * 2^96
 * - Ticks: log base 1.0001 of price → each tick = 0.01% price move
 * - Active liquidity: L = sqrt(x * y) within the current tick
 *
 * REAL PRICE from sqrtPriceX96:
 *   price = (sqrtPriceX96 / 2^96)^2
 *
 * TICK from PRICE:
 *   tick = floor(log(price) / log(1.0001))
 *
 * TOKEN AMOUNTS from L and tick range:
 *   amount0 = L * (1/sqrt(lower) - 1/sqrt(upper))
 *   amount1 = L * (sqrt(upper) - sqrt(lower))
 */

interface IUniswapV3Pool {
    function slot0() external view returns (
        uint160 sqrtPriceX96,
        int24   tick,
        uint16  observationIndex,
        uint16  observationCardinality,
        uint16  observationCardinalityNext,
        uint8   feeProtocol,
        bool    unlocked
    );

    function liquidity() external view returns (uint128);
    function fee() external view returns (uint24);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function swap(
        address recipient,
        bool    zeroForOne,
        int256  amountSpecified,   // positive = exactIn, negative = exactOut
        uint160 sqrtPriceLimitX96,
        bytes   calldata data
    ) external returns (int256 amount0, int256 amount1);

    function flash(
        address recipient,
        uint256 amount0,
        uint256 amount1,
        bytes   calldata data
    ) external;

    function observe(uint32[] calldata secondsAgos)
        external view returns (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s);
}

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes  calldata data
    ) external;
}

interface IUniswapV3FlashCallback {
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes   calldata data
    ) external;
}

/// @notice Helper library for V3 price math
library UniswapV3Math {

    uint256 constant Q96 = 2 ** 96;

    /// @notice Convert sqrtPriceX96 to a human-readable price (token1 per token0)
    /// @dev    price = (sqrtPriceX96 / Q96)^2, adjusted for decimal differences
    function sqrtPriceX96ToPrice(
        uint160 sqrtPriceX96,
        uint8   decimals0,
        uint8   decimals1
    ) internal pure returns (uint256 price) {
        uint256 sq = uint256(sqrtPriceX96) * uint256(sqrtPriceX96);
        // sq / Q96^2 * 10^decimals0 / 10^decimals1
        price = (sq * 10 ** decimals0) / (Q96 * Q96 * 10 ** decimals1);
    }

    /// @notice Convert a tick to the sqrt price at that tick boundary
    function tickToSqrtPrice(int24 tick) internal pure returns (uint160 sqrtPriceX96) {
        // Approximation for illustrative purposes
        // Real implementation uses precomputed constants (TickMath library)
        uint256 ratio = 1_000_100 ** uint256(uint24(tick > 0 ? tick : -tick));
        if (tick < 0) {
            sqrtPriceX96 = uint160((Q96 * Q96 * 1e12) / ratio);
        } else {
            sqrtPriceX96 = uint160((ratio * Q96) / 1e12);
        }
    }

    /// @notice Current price as token1/token0
    function getCurrentPrice(address pool, uint8 d0, uint8 d1)
        internal view returns (uint256)
    {
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3Pool(pool).slot0();
        return sqrtPriceX96ToPrice(sqrtPriceX96, d0, d1);
    }
}

// ============================================================
// SECTION 3: FLASH LOANS — AAVE V3
// ============================================================

/*
 * FLASH LOAN = borrow any amount, use it, repay within the same transaction.
 * If repayment (+ fee) fails → entire transaction reverts.
 * No collateral required — risk is zero for the protocol.
 *
 * AAVE V3 FEE: 0.09% (9 bps) of the borrowed amount
 *
 * USE CASES:
 * - Arbitrage between DEXes
 * - Self-liquidation (repay your own loan to avoid penalty)
 * - Collateral swap (change collateral type atomically)
 * - Leveraged positions in one transaction
 *
 * FLOW:
 * 1. Call pool.flashLoan(receiver, assets, amounts, modes, ...)
 * 2. Aave transfers assets to receiver
 * 3. Aave calls receiver.executeOperation(...)
 * 4. Inside executeOperation: do whatever you need
 * 5. Before returning: approve Aave to pull back amount + fee
 * 6. Aave pulls the repayment — done
 */

interface IAavePool {
    function flashLoan(
        address receiverAddress,
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata interestRateModes, // 0 = no debt (must repay in same tx)
        address onBehalfOf,
        bytes   calldata params,
        uint16  referralCode
    ) external;

    function flashLoanSimple(
        address receiverAddress,
        address asset,
        uint256 amount,
        bytes   calldata params,
        uint16  referralCode
    ) external;

    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf) external returns (uint256);
    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external;

    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );

    function FLASHLOAN_PREMIUM_TOTAL() external view returns (uint128); // in basis points
}

interface IFlashLoanReceiver {
    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,  // fees owed
        address initiator,
        bytes   calldata params
    ) external returns (bool);
}

/// @title AaveFlashLoanBase — base contract for Aave V3 flash loan receivers
abstract contract AaveFlashLoanBase is IFlashLoanReceiver {

    IAavePool public immutable POOL;

    error NotPool();

    constructor(address pool) {
        POOL = IAavePool(pool);
    }

    modifier onlyPool() {
        if (msg.sender != address(POOL)) revert NotPool();
        _;
    }

    /// @notice Override in your strategy contract
    function _executeFlashLoan(
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory premiums,
        bytes memory params
    ) internal virtual;

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address, /*initiator*/
        bytes calldata params
    ) external override onlyPool returns (bool) {
        _executeFlashLoan(assets, amounts, premiums, params);

        // Approve repayment for each borrowed asset
        for (uint256 i = 0; i < assets.length; i++) {
            uint256 repayAmount = amounts[i] + premiums[i];
            IERC20(assets[i]).approve(address(POOL), repayAmount);
        }

        return true;
    }
}

/// @title FlashLoanArbitrage — arbitrage between two DEX pools using a flash loan
contract FlashLoanArbitrage is AaveFlashLoanBase {

    address public immutable DEX_A; // buy cheap
    address public immutable DEX_B; // sell expensive
    address public immutable OWNER;

    error NotProfitable(uint256 profit, uint256 minProfit);

    event ArbitrageExecuted(address token, uint256 borrowed, uint256 profit);

    constructor(address _pool, address _dexA, address _dexB) AaveFlashLoanBase(_pool) {
        DEX_A = _dexA;
        DEX_B = _dexB;
        OWNER = msg.sender;
    }

    /// @notice Initiate the flash loan arbitrage
    /// @param token  Asset to borrow and arbitrage
    /// @param amount Amount to borrow
    /// @param minProfit Minimum acceptable profit (slippage guard)
    function executeArbitrage(
        address token,
        uint256 amount,
        uint256 minProfit
    ) external {
        require(msg.sender == OWNER, "Not owner");

        address[] memory assets  = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory modes   = new uint256[](1);

        assets[0]  = token;
        amounts[0] = amount;
        modes[0]   = 0; // repay in same tx (true flash loan)

        bytes memory params = abi.encode(minProfit);

        POOL.flashLoan(address(this), assets, amounts, modes, address(this), params, 0);
    }

    function _executeFlashLoan(
        address[] memory assets,
        uint256[] memory amounts,
        uint256[] memory premiums,
        bytes memory params
    ) internal override {
        address token    = assets[0];
        uint256 borrowed = amounts[0];
        uint256 fee      = premiums[0];
        uint256 minProfit = abi.decode(params, (uint256));

        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        // Step 1: Buy on DEX A (where token is cheaper)
        IERC20(token).approve(DEX_A, borrowed);
        uint256 received = ISimpleDEX(DEX_A).swap(token, borrowed);

        // Step 2: Sell on DEX B (where token is more expensive)
        address tokenOut = ISimpleDEX(DEX_A).tokenOut(token);
        IERC20(tokenOut).approve(DEX_B, received);
        uint256 finalAmount = ISimpleDEX(DEX_B).swap(tokenOut, received);

        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        uint256 repayAmount  = borrowed + fee;

        require(balanceAfter >= repayAmount, "Cannot repay flash loan");

        uint256 profit = balanceAfter - repayAmount;
        if (profit < minProfit) revert NotProfitable(profit, minProfit);

        // Profit stays in this contract — owner can withdraw
        emit ArbitrageExecuted(token, borrowed, profit);
    }

    function withdraw(address token) external {
        require(msg.sender == OWNER);
        IERC20(token).transfer(OWNER, IERC20(token).balanceOf(address(this)));
    }
}

// ============================================================
// SECTION 4: FLASH SWAPS — UNISWAP V3
// ============================================================

/*
 * Flash swaps are Uniswap's native flash loan mechanism.
 * Unlike Aave, you receive tokens FIRST, then the callback runs,
 * and you must repay (or provide the other token as payment).
 *
 * V3 FLASH (pool.flash):
 * - Borrow token0 and/or token1 from any V3 pool
 * - Fee = pool fee tier (0.05%, 0.3%, or 1%)
 * - Repay in the callback via uniswapV3FlashCallback
 */

/// @title UniswapV3FlashSwap — example flash swap receiver
contract UniswapV3FlashSwap is IUniswapV3FlashCallback {

    IUniswapV3Pool public immutable pool;
    address public immutable owner;

    error NotPool();

    constructor(address _pool) {
        pool  = IUniswapV3Pool(_pool);
        owner = msg.sender;
    }

    /// @notice Initiate a flash swap borrowing amount0 of token0
    function initiateFlash(uint256 amount0, uint256 amount1, bytes calldata data) external {
        require(msg.sender == owner);
        pool.flash(address(this), amount0, amount1, data);
    }

    /// @notice Called by pool after sending tokens — must repay here
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes   calldata data
    ) external override {
        require(msg.sender == address(pool), "Not pool");

        address token0 = pool.token0();
        address token1 = pool.token1();

        // Decode what we borrowed
        (uint256 amount0, uint256 amount1) = abi.decode(data, (uint256, uint256));

        // --- YOUR STRATEGY HERE ---
        // e.g., use borrowed tokens for arbitrage, liquidation, etc.
        // --- END STRATEGY ---

        // Repay: borrowed amount + fee
        if (amount0 > 0) IERC20(token0).transfer(address(pool), amount0 + fee0);
        if (amount1 > 0) IERC20(token1).transfer(address(pool), amount1 + fee1);
    }
}

// ============================================================
// SECTION 5: ORACLES — CHAINLINK PRICE FEEDS
// ============================================================

/*
 * Oracles provide off-chain data (prices, randomness, sports scores)
 * to on-chain contracts. Price manipulation via oracles is one of
 * the most common DeFi attack vectors.
 *
 * CHAINLINK AGGREGATOR:
 * - Decentralized network of nodes
 * - Each price feed has a heartbeat (e.g., 1 hour) and deviation threshold (e.g., 0.5%)
 * - Answers are in 8 decimals (most USD pairs) or 18 decimals (ETH pairs)
 *
 * SAFETY CHECKS:
 * 1. Check roundId > 0        — feed has data
 * 2. Check answeredInRound >= roundId — data is not stale
 * 3. Check updatedAt != 0    — round was completed
 * 4. Check block.timestamp - updatedAt < heartbeat — data is fresh
 * 5. Check price > 0          — no negative prices
 *
 * MAINNET FEED ADDRESSES (ETH/USD):
 * Ethereum:  0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
 * Arbitrum:  0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612
 * Base:      0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70
 */

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80  roundId,
        int256  answer,      // price × 10^decimals
        uint256 startedAt,
        uint256 updatedAt,   // timestamp of last update
        uint80  answeredInRound
    );
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
}

/// @title ChainlinkOracle — safe price feed wrapper with all required checks
contract ChainlinkOracle {

    uint256 public constant MAX_STALENESS = 1 hours; // adjust per feed heartbeat

    error StalePrice(uint256 updatedAt, uint256 currentTime);
    error InvalidPrice(int256 price);
    error IncompleteRound(uint80 roundId, uint80 answeredInRound);

    /// @notice Returns the latest price with full validation
    /// @param feed  Chainlink AggregatorV3 address
    /// @return price in 18 decimals (normalized from feed decimals)
    function getPrice(address feed) public view returns (uint256 price) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(feed);

        (
            uint80  roundId,
            int256  answer,
            ,
            uint256 updatedAt,
            uint80  answeredInRound
        ) = priceFeed.latestRoundData();

        // Check 1: Price must be positive
        if (answer <= 0) revert InvalidPrice(answer);

        // Check 2: Round must be complete
        if (answeredInRound < roundId) revert IncompleteRound(roundId, answeredInRound);

        // Check 3: Price must not be stale
        if (block.timestamp - updatedAt > MAX_STALENESS)
            revert StalePrice(updatedAt, block.timestamp);

        // Normalize to 18 decimals
        uint8 feedDecimals = priceFeed.decimals();
        price = uint256(answer) * 10 ** (18 - feedDecimals);
    }

    /// @notice Get prices of two assets and compute their ratio
    function getPriceRatio(address feedA, address feedB)
        external view returns (uint256 ratio)
    {
        uint256 priceA = getPrice(feedA);
        uint256 priceB = getPrice(feedB);
        ratio = (priceA * 1e18) / priceB;
    }

    /// @notice Convert an amount in USD to token quantity
    function usdToToken(
        uint256 usdAmount,  // in 18 decimals
        address feed,
        uint8   tokenDecimals
    ) external view returns (uint256 tokenAmount) {
        uint256 price = getPrice(feed); // token price in USD (18 dec)
        tokenAmount   = (usdAmount * 10 ** tokenDecimals) / price;
    }
}

// ============================================================
// SECTION 6: ORACLES — TWAP (TIME-WEIGHTED AVERAGE PRICE)
// ============================================================

/*
 * TWAP = average price over a time window.
 * Resistant to flash loan price manipulation because:
 *   - Manipulation requires holding an inflated price across multiple blocks
 *   - Expensive (capital locked) and visible to arbitrageurs
 *
 * UNISWAP V2 TWAP:
 *   price0Cumulative = sum of (price0 × secondsElapsed) for each block
 *   TWAP = (cumulative_now - cumulative_then) / (time_now - time_then)
 *
 * UNISWAP V3 TWAP:
 *   Uses the observe() function with secondsAgos array
 *   More precise with tick-based accumulator
 *
 * TRADEOFF:
 *   Shorter window  → more responsive, easier to manipulate
 *   Longer window   → more manipulation-resistant, but lagging
 *   Typical: 30 minutes for DeFi protocols
 */

/// @title UniswapV2TWAP — TWAP oracle using Uniswap V2 cumulative prices
contract UniswapV2TWAP {

    IUniswapV2Pair public immutable pair;
    bool           public immutable token0IsBase; // true = price of token1 in token0

    uint256 private price0CumulativeLast;
    uint256 private price1CumulativeLast;
    uint32  private blockTimestampLast;
    uint256 private price0Average; // stored as UQ112x112 fixed-point (× 2^112)
    uint256 private price1Average;

    uint32  public constant PERIOD = 30 minutes;

    error PeriodNotElapsed(uint256 remaining);

    constructor(address _pair, bool _token0IsBase) {
        pair           = IUniswapV2Pair(_pair);
        token0IsBase   = _token0IsBase;

        (, , blockTimestampLast)    = pair.getReserves();
        price0CumulativeLast        = pair.price0CumulativeLast();
        price1CumulativeLast        = pair.price1CumulativeLast();
    }

    /// @notice Update the TWAP — must be called at least once per PERIOD
    function update() external {
        (, , uint32 blockTimestamp) = pair.getReserves();
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        if (timeElapsed < PERIOD) revert PeriodNotElapsed(PERIOD - timeElapsed);

        uint256 price0Cumulative = pair.price0CumulativeLast();
        uint256 price1Cumulative = pair.price1CumulativeLast();

        // Average price = delta_cumulative / delta_time
        // Stored as UQ112x112 (Uniswap's fixed-point format)
        price0Average = (price0Cumulative - price0CumulativeLast) / timeElapsed;
        price1Average = (price1Cumulative - price1CumulativeLast) / timeElapsed;

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast   = blockTimestamp;
    }

    /// @notice Get TWAP price of token0 in token1 terms
    function getPrice0() external view returns (uint256) {
        return price0Average; // UQ112x112 — divide by 2^112 for human-readable
    }

    /// @notice Consult: how many token1 for a given amount of token0
    function consult(address token, uint256 amountIn)
        external view returns (uint256 amountOut)
    {
        address token0 = pair.token0();
        if (token == token0) {
            // price0Average is token1 per token0, in UQ112x112
            amountOut = (price0Average * amountIn) >> 112;
        } else {
            amountOut = (price1Average * amountIn) >> 112;
        }
    }
}

/// @title UniswapV3TWAP — TWAP using V3 observe()
contract UniswapV3TWAP {

    IUniswapV3Pool public immutable pool;

    constructor(address _pool) {
        pool = IUniswapV3Pool(_pool);
    }

    /// @notice Returns the TWAP tick over the last `secondsAgo` seconds
    function getTWAPTick(uint32 secondsAgo) public view returns (int24 twapTick) {
        uint32[] memory secondsAgos = new uint32[](2);
        secondsAgos[0] = secondsAgo;
        secondsAgos[1] = 0; // now

        (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);

        // TWAP tick = delta_tickCumulative / delta_time
        int56 tickCumulativeDelta = tickCumulatives[1] - tickCumulatives[0];
        twapTick = int24(tickCumulativeDelta / int56(uint56(secondsAgo)));

        // Round toward negative infinity
        if (tickCumulativeDelta < 0 && (tickCumulativeDelta % int56(uint56(secondsAgo)) != 0)) {
            twapTick--;
        }
    }

    /// @notice Returns TWAP price of token0 in token1 (18 decimals)
    function getTWAPPrice(uint32 secondsAgo, uint8 d0, uint8 d1)
        external view returns (uint256)
    {
        int24 tick = getTWAPTick(secondsAgo);
        // 1.0001^tick = price (in fixed-point)
        // For a full implementation use TickMath.getSqrtRatioAtTick()
        uint160 sqrtPriceX96 = UniswapV3Math.tickToSqrtPrice(tick);
        return UniswapV3Math.sqrtPriceX96ToPrice(sqrtPriceX96, d0, d1);
    }
}

// ============================================================
// SECTION 6b: ORACLES — PULL (PYTH / REDSTONE / CHRONICLE)
// ============================================================

/*
 * PUSH vs PULL ORACLES:
 *
 * PUSH (Chainlink classic): a decentralized network writes prices on-chain on
 *   its own schedule. You just read the latest answer. Simple, but you pay for
 *   updates you may not need and coverage/heartbeats are fixed.
 *
 * PULL (Pyth, RedStone, Chronicle): prices live off-chain, signed by the
 *   provider. The USER submits a fresh signed update in the SAME transaction,
 *   then reads it. Dominant on L2s/appchains in 2025-2026 because it is cheap,
 *   has thousands of feeds, and sub-second freshness.
 *
 *   Flow (Pyth):
 *     1. Off-chain: fetch `updateData` (signed VAA) from Hermes/price service.
 *     2. On-chain: pay `getUpdateFee`, call `updatePriceFeeds(updateData)`.
 *     3. Read `getPriceNoOlderThan(id, maxAge)` — REVERTS if stale.
 *
 *   PROVIDER NOTES:
 *   - Pyth      : `updatePriceFeeds` + pull; price has a confidence interval.
 *   - RedStone  : signed data is APPENDED to calldata; an on-chain extractor
 *                 reads it (no separate update tx). Great for gas.
 *   - Chronicle : `read()` gated to authorized readers (`kiss`/`diss`), MakerDAO lineage.
 *
 *   SECURITY:
 *   - ALWAYS bound staleness (maxAge) and reject price <= 0.
 *   - Use the confidence interval: reject if conf/price is too wide.
 *   - Pull updates are permissionless — never trust caller-provided prices
 *     without verifying through the oracle contract.
 */

/// @notice Minimal Pyth interface (pull oracle).
interface IPyth {
    struct Price {
        int64  price;        // scaled by 10^expo
        uint64 conf;         // confidence interval (same exponent)
        int32  expo;         // e.g. -8
        uint256 publishTime; // unix seconds
    }

    function getUpdateFee(bytes[] calldata updateData) external view returns (uint256 fee);
    function updatePriceFeeds(bytes[] calldata updateData) external payable;
    function getPriceNoOlderThan(bytes32 id, uint256 age) external view returns (Price memory);
}

/// @title PythConsumer — update-then-read a pull oracle in one transaction
contract PythConsumer {
    IPyth public immutable pyth;

    error StalePrice();
    error InvalidPrice();
    error ConfidenceTooWide();

    constructor(address _pyth) {
        pyth = IPyth(_pyth);
    }

    /// @notice Submit a fresh signed update, then read it. Returns price scaled to 1e18.
    /// @param updateData signed price update fetched off-chain (Hermes)
    /// @param priceId    the Pyth feed id (e.g. ETH/USD)
    /// @param maxAge     maximum acceptable staleness in seconds
    function updateAndGetPrice(bytes[] calldata updateData, bytes32 priceId, uint256 maxAge)
        external
        payable
        returns (uint256 price18)
    {
        uint256 fee = pyth.getUpdateFee(updateData);
        pyth.updatePriceFeeds{value: fee}(updateData);

        IPyth.Price memory p = pyth.getPriceNoOlderThan(priceId, maxAge); // reverts if stale
        if (p.price <= 0) revert InvalidPrice();

        // reject quotes whose confidence band is wider than 2% of the price
        if (p.conf != 0 && (uint256(p.conf) * 50) > uint256(uint64(p.price))) {
            revert ConfidenceTooWide();
        }

        price18 = _scaleTo1e18(uint256(uint64(p.price)), p.expo);

        // refund any unused fee to the caller
        if (msg.value > fee) {
            (bool ok, ) = msg.sender.call{value: msg.value - fee}("");
            ok;
        }
    }

    function _scaleTo1e18(uint256 priceU, int32 expo) internal pure returns (uint256) {
        if (expo >= 0) {
            return priceU * (10 ** uint256(uint32(expo))) * 1e18;
        }
        uint256 d = uint256(uint32(-expo));
        return d <= 18 ? priceU * (10 ** (18 - d)) : priceU / (10 ** (d - 18));
    }
}

// ============================================================
// SECTION 7: LENDING & BORROWING — CORE MECHANICS
// ============================================================

/*
 * COLLATERAL RATIO & HEALTH FACTOR:
 *
 *   Collateral Value  = deposited × collateralFactor (e.g., 80%)
 *   Max Borrow        = Collateral Value in base currency (e.g., USD)
 *   Health Factor     = (Collateral × liquidationThreshold) / totalDebt
 *   → HF < 1.0 = position is undercollateralized → liquidatable
 *
 * INTEREST:
 *   borrowAPR  = base + slope × utilization
 *   supplyAPR  = borrowAPR × utilization × (1 - reserveFactor)
 *
 * AAVE V3 aTokens:
 *   When you supply 100 USDC you receive 100 aUSDC
 *   aUSDC balance grows automatically with interest (rebaseable)
 *
 * AAVE V3 MODES:
 *   Variable rate: fluctuates with utilization
 *   Stable rate:   fixed at time of borrow (higher base, more predictable)
 *   E-Mode:        optimized LTV for correlated assets (e.g., stablecoins)
 */

/// @title SimpleLendingPool — reference implementation of lending mechanics
contract SimpleLendingPool {

    struct Market {
        address asset;
        uint256 totalSupplied;       // total deposits (in asset units)
        uint256 totalBorrowed;       // total debt outstanding
        uint256 reserveFactor;       // fraction of interest kept as reserves (1e18 = 100%)
        uint256 baseRate;            // minimum APR (1e18 = 100%)
        uint256 slope;               // additional APR per unit of utilization
        uint256 liquidationThreshold;// 80% → position liquidatable when LTV > 80%
        uint256 liquidationBonus;    // 5% bonus for liquidators
        uint256 lastUpdateTimestamp;
        uint256 borrowIndex;         // cumulative borrow interest multiplier (1e27 = 1.0)
        uint256 supplyIndex;         // cumulative supply interest multiplier
    }

    struct UserPosition {
        uint256 supplied;            // principal supplied (unscaled)
        uint256 borrowed;            // principal borrowed (unscaled)
        uint256 borrowIndexAtEntry;  // index when user last borrowed
    }

    mapping(address => Market)                       public markets;
    mapping(address => mapping(address => UserPosition)) public positions; // user → asset → position

    uint256 constant RAY = 1e27; // index precision
    uint256 constant WAD = 1e18;

    event Supplied(address indexed user, address indexed asset, uint256 amount);
    event Borrowed(address indexed user, address indexed asset, uint256 amount);
    event Repaid(address indexed user, address indexed asset, uint256 amount);
    event Liquidated(address indexed user, address indexed collateral, uint256 amount);

    // -------------------------------------------------------
    // Utilization Rate = totalBorrowed / totalSupplied
    // -------------------------------------------------------
    function getUtilizationRate(address asset) public view returns (uint256) {
        Market storage m = markets[asset];
        if (m.totalSupplied == 0) return 0;
        return (m.totalBorrowed * WAD) / m.totalSupplied;
    }

    // -------------------------------------------------------
    // Borrow APR = baseRate + slope × utilization
    // -------------------------------------------------------
    function getBorrowAPR(address asset) public view returns (uint256) {
        Market storage m = markets[asset];
        uint256 util     = getUtilizationRate(asset);
        return m.baseRate + (m.slope * util) / WAD;
    }

    // -------------------------------------------------------
    // Supply APR = borrowAPR × utilization × (1 - reserveFactor)
    // -------------------------------------------------------
    function getSupplyAPR(address asset) public view returns (uint256) {
        uint256 borrowAPR = getBorrowAPR(asset);
        uint256 util      = getUtilizationRate(asset);
        uint256 reserve   = markets[asset].reserveFactor;
        return (borrowAPR * util * (WAD - reserve)) / (WAD * WAD);
    }

    // -------------------------------------------------------
    // Health Factor = (collateralValue × liquidationThreshold) / debtValue
    // Returns in WAD (1e18 = 1.0, healthy if > 1e18)
    // -------------------------------------------------------
    function getHealthFactor(
        address user,
        address collateralAsset,
        address debtAsset,
        uint256 collateralPrice, // in USD, 18 dec
        uint256 debtPrice        // in USD, 18 dec
    ) public view returns (uint256 healthFactor) {
        UserPosition storage pos       = positions[user][collateralAsset];
        UserPosition storage debtPos   = positions[user][debtAsset];
        Market storage collateralMarket = markets[collateralAsset];

        uint256 collateralValueUSD = (pos.supplied * collateralPrice) / WAD;
        uint256 adjustedCollateral = (collateralValueUSD * collateralMarket.liquidationThreshold) / WAD;
        uint256 debtValueUSD       = (debtPos.borrowed * debtPrice) / WAD;

        if (debtValueUSD == 0) return type(uint256).max; // no debt = infinite health
        healthFactor = (adjustedCollateral * WAD) / debtValueUSD;
    }

    function supply(address asset, uint256 amount) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        markets[asset].totalSupplied += amount;
        positions[msg.sender][asset].supplied += amount;
        emit Supplied(msg.sender, asset, amount);
    }

    function borrow(address asset, uint256 amount) external {
        // In production: check health factor before allowing borrow
        markets[asset].totalBorrowed += amount;
        positions[msg.sender][asset].borrowed += amount;
        IERC20(asset).transfer(msg.sender, amount);
        emit Borrowed(msg.sender, asset, amount);
    }

    function repay(address asset, uint256 amount) external {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        positions[msg.sender][asset].borrowed -= amount;
        markets[asset].totalBorrowed -= amount;
        emit Repaid(msg.sender, asset, amount);
    }
}

// ============================================================
// SECTION 8: LIQUIDATIONS
// ============================================================

/*
 * WHEN A POSITION IS LIQUIDATABLE:
 *   healthFactor < 1.0 (collateral value × threshold < debt value)
 *
 * LIQUIDATION PROCESS:
 * 1. Liquidator repays part of the borrower's debt (up to CLOSE_FACTOR, e.g., 50%)
 * 2. In return, liquidator receives the borrower's collateral + BONUS (e.g., 5%)
 * 3. Liquidator profits = bonus × amount repaid
 *
 * EXAMPLE:
 *   User borrowed 1000 USDC, has 1.3 ETH as collateral
 *   ETH drops → health factor < 1.0 → position is liquidatable
 *   Liquidator repays 500 USDC (50% close factor)
 *   Liquidator receives 500 USDC worth of ETH + 5% bonus = 525 USDC of ETH
 *   Liquidator profit: 25 USDC
 *
 * BAD DEBT:
 *   If position is so underwater that collateral < debt after bonus,
 *   the shortfall is socialized among the protocol's reserve or insurance fund.
 *
 * BOTS:
 *   Liquidation bots monitor mempool and health factors off-chain,
 *   submit liquidation txs when positions become eligible.
 *   Competitive: use Flashbots bundles to avoid front-running.
 */

/// @title LiquidationEngine — reference liquidation implementation
contract LiquidationEngine {

    IAavePool public immutable pool;
    ChainlinkOracle public immutable oracle;

    address public immutable ETH_USD_FEED;
    address public immutable USDC_USD_FEED;

    uint256 constant CLOSE_FACTOR = 0.5e18;     // 50% max liquidation per call
    uint256 constant HEALTH_FACTOR_MIN = 1e18;  // below 1.0 = liquidatable

    event LiquidationAttempt(address indexed user, uint256 healthFactor, bool eligible);
    event LiquidationProfit(address indexed liquidator, uint256 profitUSD);

    constructor(address _pool, address _oracle, address _ethFeed, address _usdcFeed) {
        pool         = IAavePool(_pool);
        oracle       = ChainlinkOracle(_oracle);
        ETH_USD_FEED = _ethFeed;
        USDC_USD_FEED = _usdcFeed;
    }

    /// @notice Check if a user's position is liquidatable on Aave
    function isLiquidatable(address user) public view returns (bool, uint256 healthFactor) {
        (,,,,,uint256 hf) = pool.getUserAccountData(user);
        return (hf < HEALTH_FACTOR_MIN, hf);
    }

    /// @notice Liquidate an underwater Aave position
    /// @param  user            The borrower to liquidate
    /// @param  collateralAsset The collateral to receive
    /// @param  debtAsset       The debt token to repay
    /// @param  debtToCover     Amount of debt to repay (≤ 50% of total debt)
    function liquidate(
        address user,
        address collateralAsset,
        address debtAsset,
        uint256 debtToCover
    ) external {
        (bool eligible, uint256 hf) = isLiquidatable(user);
        emit LiquidationAttempt(user, hf, eligible);
        require(eligible, "Position healthy");

        // Pull debt asset from liquidator
        IERC20(debtAsset).transferFrom(msg.sender, address(this), debtToCover);
        IERC20(debtAsset).approve(address(pool), debtToCover);

        uint256 collateralBefore = IERC20(collateralAsset).balanceOf(address(this));

        // Call Aave to execute the liquidation
        pool.liquidationCall(
            collateralAsset,
            debtAsset,
            user,
            debtToCover,
            false // false = receive underlying collateral, not aToken
        );

        uint256 collateralReceived = IERC20(collateralAsset).balanceOf(address(this)) - collateralBefore;

        // Send collateral to liquidator
        IERC20(collateralAsset).transfer(msg.sender, collateralReceived);
    }

    /// @notice Flash loan liquidation — no upfront capital required
    /// @dev    Borrow debtAsset → liquidate → sell collateral → repay flash loan
    function flashLiquidate(
        address user,
        address collateralAsset,
        address debtAsset,
        uint256 debtToCover
    ) external {
        // Encode params for executeOperation callback
        bytes memory params = abi.encode(user, collateralAsset, msg.sender);

        address[] memory assets  = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        uint256[] memory modes   = new uint256[](1);

        assets[0]  = debtAsset;
        amounts[0] = debtToCover;
        modes[0]   = 0;

        pool.flashLoan(address(this), assets, amounts, modes, address(this), params, 0);
    }
}

// ============================================================
// SECTION 9: INTEREST RATE MODELS
// ============================================================

/*
 * TWO-SLOPE INTEREST RATE MODEL (Aave/Compound style):
 *
 * Below optimal utilization (U*):
 *   borrowRate = baseRate + (U / U*) × slope1
 *
 * Above optimal utilization (U*):
 *   borrowRate = baseRate + slope1 + ((U - U*) / (1 - U*)) × slope2
 *
 * slope2 >> slope1 → aggressive rate increase when pool is nearly drained
 * This incentivizes suppliers to add liquidity and borrowers to repay.
 *
 * COMPOUND INTEREST (continuous):
 *   balance(t) = principal × e^(rate × t)
 *
 * SIMPLE COMPOUND (per-second approximation):
 *   index(t) = index(0) × (1 + rate/secondsPerYear) ^ t
 */

library InterestRateModel {

    uint256 constant SECONDS_PER_YEAR = 365 days;
    uint256 constant WAD = 1e18;

    struct Params {
        uint256 baseRate;          // minimum borrow rate (WAD)
        uint256 slope1;            // rate increase up to optimal utilization
        uint256 slope2;            // aggressive rate increase above optimal
        uint256 optimalUtilization; // kink point (WAD)
    }

    /// @notice Two-slope borrow rate model
    function getBorrowRate(Params memory p, uint256 utilizationRate)
        internal pure returns (uint256 borrowRate)
    {
        if (utilizationRate <= p.optimalUtilization) {
            // Below kink: linear increase
            borrowRate = p.baseRate + (utilizationRate * p.slope1) / p.optimalUtilization;
        } else {
            // Above kink: steep increase to protect suppliers
            uint256 excessUtil = utilizationRate - p.optimalUtilization;
            uint256 maxExcess  = WAD - p.optimalUtilization;
            borrowRate = p.baseRate + p.slope1 + (excessUtil * p.slope2) / maxExcess;
        }
    }

    /// @notice Accrue interest: new index = old index × (1 + rate × dt)
    function accrueInterest(
        uint256 index,
        uint256 borrowRate,    // annual rate in WAD
        uint256 dt             // seconds elapsed
    ) internal pure returns (uint256 newIndex) {
        // Per-second rate = borrowRate / secondsPerYear
        uint256 ratePerSecond  = borrowRate / SECONDS_PER_YEAR;
        uint256 interestFactor = WAD + (ratePerSecond * dt);
        newIndex = (index * interestFactor) / WAD;
    }

    /// @notice Current debt of a user given their borrow index at entry
    function currentDebt(
        uint256 principalBorrowed,
        uint256 borrowIndexNow,
        uint256 borrowIndexAtEntry
    ) internal pure returns (uint256) {
        if (borrowIndexAtEntry == 0) return 0;
        return (principalBorrowed * borrowIndexNow) / borrowIndexAtEntry;
    }
}

// ============================================================
// SECTION 10: YIELD AGGREGATORS
// ============================================================

/*
 * A yield aggregator automatically moves funds between protocols
 * to maximize return. Core pattern: Vault ERC-4626.
 *
 * ERC-4626 (Tokenized Vault Standard):
 * - deposit(assets) → mints shares
 * - redeem(shares)  → burns shares, returns assets
 * - share price appreciates as yield accrues
 * - share price = totalAssets / totalShares
 *
 * POPULAR AGGREGATORS: Yearn, Beefy, Morpho
 */

interface IERC4626 {
    function asset() external view returns (address);
    function totalAssets() external view returns (uint256);
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}

/// @title SimpleVault — minimal ERC-4626 yield vault
contract SimpleVault {

    IERC20 public immutable underlying; // e.g., USDC
    IAavePool public immutable aave;
    address public immutable aToken;    // aUSDC

    uint256 public totalShares;
    mapping(address => uint256) public shares;

    uint256 constant WAD = 1e18;

    event Deposit(address indexed user, uint256 assets, uint256 sharesIssued);
    event Withdraw(address indexed user, uint256 assets, uint256 sharesBurned);

    constructor(address _underlying, address _aave, address _aToken) {
        underlying = IERC20(_underlying);
        aave       = IAavePool(_aave);
        aToken     = _aToken;
    }

    /// @notice Total assets under management (principal + accrued interest)
    function totalAssets() public view returns (uint256) {
        return IERC20(aToken).balanceOf(address(this));
    }

    /// @notice Share price = totalAssets / totalShares
    function sharePrice() public view returns (uint256) {
        if (totalShares == 0) return WAD;
        return (totalAssets() * WAD) / totalShares;
    }

    /// @notice Deposit assets, receive shares
    function deposit(uint256 assets) external returns (uint256 sharesIssued) {
        underlying.transferFrom(msg.sender, address(this), assets);

        // Calculate shares BEFORE the deposit to avoid sandwich manipulation
        sharesIssued = totalShares == 0
            ? assets
            : (assets * totalShares) / totalAssets();

        // Deploy capital to Aave for yield
        underlying.approve(address(aave), assets);
        aave.supply(address(underlying), assets, address(this), 0);

        totalShares          += sharesIssued;
        shares[msg.sender]   += sharesIssued;

        emit Deposit(msg.sender, assets, sharesIssued);
    }

    /// @notice Burn shares, receive assets + yield
    function withdraw(uint256 sharesBurned) external returns (uint256 assets) {
        require(shares[msg.sender] >= sharesBurned, "Insufficient shares");

        assets = (sharesBurned * totalAssets()) / totalShares;

        shares[msg.sender] -= sharesBurned;
        totalShares        -= sharesBurned;

        // Withdraw from Aave
        aave.repay(address(underlying), assets, 2, address(this)); // mode 2 = variable

        underlying.transfer(msg.sender, assets);

        emit Withdraw(msg.sender, assets, sharesBurned);
    }

    /// @notice Annual yield estimate based on Aave supply APR
    function estimatedAPR() external pure returns (uint256) {
        // In production: read from Aave data provider
        // aaveDataProvider.getReserveData(underlying).currentLiquidityRate / RAY
        return 0; // placeholder
    }
}

// ============================================================
// SECTION 11: STABLECOINS
// ============================================================

/*
 * TYPES OF STABLECOINS:
 *
 * 1. FIAT-BACKED (USDC, USDT)
 *    Off-chain reserves 1:1. Centralized risk, highest stability.
 *
 * 2. CRYPTO-COLLATERALIZED (DAI/MakerDAO style)
 *    Overcollateralized with crypto. Decentralized but capital inefficient.
 *    Stability maintained via liquidations and stability fee.
 *
 * 3. ALGORITHMIC (FRAX, LUSD)
 *    Partial or full algorithmic backing. Higher risk, more capital-efficient.
 *
 * CRYPTO-COLLATERALIZED MECHANICS (MakerDAO/CDP):
 *   - Open a Vault (CDP) by locking ETH
 *   - Mint DAI up to the collateralization ratio (e.g., 150%)
 *   - If ETH price drops and ratio < 150%, vault is liquidated
 *   - Stability fee (interest) accrues on minted DAI
 *   - Repay DAI + fee to unlock collateral
 */

/// @title CryptoStablecoin — overcollateralized stablecoin (CDP model)
contract CryptoStablecoin {

    IERC20 public immutable collateralToken;  // e.g., WETH
    ChainlinkOracle public immutable priceOracle;
    address public immutable priceFeed;       // ETH/USD Chainlink feed

    uint256 constant MIN_RATIO   = 150e16;    // 150% collateralization
    uint256 constant LIQ_RATIO   = 120e16;    // liquidatable below 120%
    uint256 constant LIQ_BONUS   = 10e16;     // 10% bonus for liquidators
    uint256 constant STABILITY_FEE = 2e16;    // 2% annual fee on minted amount
    uint256 constant WAD = 1e18;

    struct Vault {
        uint256 collateral;       // locked collateral amount
        uint256 debt;             // minted stablecoin
        uint256 lastUpdateTime;   // for fee accrual
    }

    mapping(address => Vault) public vaults;
    uint256 public totalSupply;   // total stablecoin in circulation

    mapping(address => uint256) public balanceOf;

    error BelowMinRatio(uint256 current, uint256 minimum);
    error InsufficientCollateral();

    event VaultOpened(address indexed user, uint256 collateral, uint256 minted);
    event VaultClosed(address indexed user);
    event Liquidated(address indexed vault, address indexed liquidator, uint256 bonus);

    constructor(address _collateral, address _oracle, address _feed) {
        collateralToken = IERC20(_collateral);
        priceOracle     = ChainlinkOracle(_oracle);
        priceFeed       = _feed;
    }

    /// @notice Current collateral ratio of a vault (WAD = 1.0)
    function getCollateralRatio(address user) public view returns (uint256) {
        Vault storage v = vaults[user];
        if (v.debt == 0) return type(uint256).max;

        uint256 price          = priceOracle.getPrice(priceFeed);
        uint256 collateralUSD  = (v.collateral * price) / WAD;
        return (collateralUSD * WAD) / v.debt;
    }

    /// @notice Open a vault: deposit collateral, mint stablecoin
    function openVault(uint256 collateralAmount, uint256 mintAmount) external {
        collateralToken.transferFrom(msg.sender, address(this), collateralAmount);

        Vault storage v   = vaults[msg.sender];
        v.collateral     += collateralAmount;
        v.debt           += mintAmount;
        v.lastUpdateTime  = block.timestamp;

        uint256 ratio = getCollateralRatio(msg.sender);
        if (ratio < MIN_RATIO) revert BelowMinRatio(ratio, MIN_RATIO);

        // Mint stablecoin to user
        balanceOf[msg.sender] += mintAmount;
        totalSupply           += mintAmount;

        emit VaultOpened(msg.sender, collateralAmount, mintAmount);
    }

    /// @notice Repay debt and unlock collateral
    function closeVault(uint256 repayAmount) external {
        Vault storage v = vaults[msg.sender];
        require(balanceOf[msg.sender] >= repayAmount, "Insufficient stablecoin");

        uint256 fee = _accrueStabilityFee(msg.sender);

        balanceOf[msg.sender] -= repayAmount;
        totalSupply           -= repayAmount;

        uint256 collateralToReturn = (repayAmount * v.collateral) / (v.debt + fee);

        v.debt       -= repayAmount;
        v.collateral -= collateralToReturn;

        collateralToken.transfer(msg.sender, collateralToReturn);
        emit VaultClosed(msg.sender);
    }

    /// @notice Liquidate an undercollateralized vault
    function liquidate(address user) external {
        uint256 ratio = getCollateralRatio(user);
        require(ratio < LIQ_RATIO, "Vault healthy");

        Vault storage v = vaults[user];

        // Liquidator repays all debt
        uint256 debt = v.debt;
        balanceOf[msg.sender] -= debt;
        totalSupply           -= debt;

        // Liquidator receives collateral + bonus
        uint256 bonus = (v.collateral * LIQ_BONUS) / WAD;
        uint256 collateralForLiquidator = v.collateral + bonus;

        v.collateral = 0;
        v.debt       = 0;

        collateralToken.transfer(msg.sender, collateralForLiquidator);

        emit Liquidated(user, msg.sender, bonus);
    }

    function _accrueStabilityFee(address user) private returns (uint256 fee) {
        Vault storage v  = vaults[user];
        uint256 elapsed  = block.timestamp - v.lastUpdateTime;
        fee              = (v.debt * STABILITY_FEE * elapsed) / (365 days * WAD);
        v.debt          += fee;
        v.lastUpdateTime = block.timestamp;
    }
}

// ============================================================
// SECTION 12: GOVERNANCE & TIMELOCKS
// ============================================================

/*
 * GOVERNANCE TOKEN FLOW:
 * 1. Token holders delegate voting power (to self or delegate)
 * 2. Any holder (above threshold) creates a proposal
 * 3. Voting period: holders vote FOR/AGAINST/ABSTAIN
 * 4. If quorum and majority met: proposal is queued in Timelock
 * 5. After delay (e.g., 48 hours): anyone can execute
 *
 * TIMELOCK PURPOSE:
 * - Gives community time to react to malicious proposals
 * - Allows exit before a change takes effect
 * - Standard: 2-day delay for parameter changes, 7-day for upgrades
 *
 * POPULAR FRAMEWORKS: OpenZeppelin Governor, Compound GovernorBravo
 */

/// @title SimpleTimelock — executes approved transactions after a delay
contract SimpleTimelock {

    uint256 public constant MIN_DELAY = 1 days;
    uint256 public constant MAX_DELAY = 30 days;
    uint256 public immutable delay;
    address public immutable admin;

    mapping(bytes32 => bool) public queuedTransactions;

    error NotAdmin();
    error DelayNotMet(uint256 eta, uint256 current);
    error NotQueued(bytes32 txHash);
    error AlreadyQueued(bytes32 txHash);
    error StaleTransaction(bytes32 txHash);
    error ExecutionFailed();

    event Queued(bytes32 indexed txHash, address target, uint256 value, bytes data, uint256 eta);
    event Executed(bytes32 indexed txHash, address target, uint256 value, bytes data);
    event Cancelled(bytes32 indexed txHash);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    constructor(uint256 _delay) {
        require(_delay >= MIN_DELAY && _delay <= MAX_DELAY, "Invalid delay");
        delay = _delay;
        admin = msg.sender;
    }

    receive() external payable {}

    function queueTransaction(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 eta         // must be >= block.timestamp + delay
    ) external onlyAdmin returns (bytes32 txHash) {
        require(eta >= block.timestamp + delay, "ETA too soon");

        txHash = keccak256(abi.encode(target, value, data, eta));
        if (queuedTransactions[txHash]) revert AlreadyQueued(txHash);

        queuedTransactions[txHash] = true;
        emit Queued(txHash, target, value, data, eta);
    }

    function executeTransaction(
        address target,
        uint256 value,
        bytes calldata data,
        uint256 eta
    ) external payable onlyAdmin returns (bytes memory result) {
        if (block.timestamp < eta)                          revert DelayNotMet(eta, block.timestamp);
        if (block.timestamp > eta + 14 days)               revert StaleTransaction(keccak256(abi.encode(target, value, data, eta)));

        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        if (!queuedTransactions[txHash])                   revert NotQueued(txHash);

        queuedTransactions[txHash] = false;

        (bool ok, bytes memory res) = target.call{value: value}(data);
        if (!ok) revert ExecutionFailed();

        emit Executed(txHash, target, value, data);
        return res;
    }

    function cancelTransaction(
        address target, uint256 value, bytes calldata data, uint256 eta
    ) external onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        if (!queuedTransactions[txHash]) revert NotQueued(txHash);
        queuedTransactions[txHash] = false;
        emit Cancelled(txHash);
    }
}

// ============================================================
// SECTION 13: MEV — FRONT-RUNNING & PROTECTION
// ============================================================

/*
 * MEV (Maximal Extractable Value) = profit extracted by reordering,
 * inserting, or censoring transactions within a block.
 *
 * COMMON MEV TYPES:
 *
 * 1. FRONT-RUNNING (sandwich attack on DEX):
 *    a. Bot sees large swap in mempool
 *    b. Bot buys same token first (higher gas) → price goes up
 *    c. Victim's swap executes at worse price
 *    d. Bot sells immediately → profit
 *
 * 2. BACK-RUNNING:
 *    Execute after a known transaction (e.g., liquidation)
 *
 * 3. ARBITRAGE:
 *    Price differences between DEXes, usually benign
 *
 * PROTECTION STRATEGIES:
 * a. Slippage tolerance: revert if output < minAmountOut
 * b. Commit-reveal: hide intent until execution
 * c. Private mempool: Flashbots Protect, MEV Blocker RPC
 * d. TWAP orders: spread large trades over multiple blocks
 * e. Batch auctions: CoW Protocol — all trades in a batch get the same clearing price
 */

/// @title AntiMEV — patterns to reduce MEV exposure
contract AntiMEV {

    // -------------------------------------------------------
    // Pattern 1: Commit-Reveal Swap
    // User commits to a swap without revealing amount → no front-running
    // -------------------------------------------------------
    mapping(bytes32 => uint256) public commitTimestamps;

    uint256 constant REVEAL_DELAY = 1 minutes;
    uint256 constant REVEAL_EXPIRY = 10 minutes;

    event SwapCommitted(bytes32 indexed commitment, address indexed user);
    event SwapRevealed(bytes32 indexed commitment, address indexed user, uint256 amountOut);

    function commitSwap(bytes32 commitment) external {
        commitTimestamps[commitment] = block.timestamp;
        emit SwapCommitted(commitment, msg.sender);
    }

    function revealSwap(
        address tokenIn,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes32 salt,
        address pool
    ) external returns (uint256 amountOut) {
        bytes32 commitment = keccak256(abi.encodePacked(
            msg.sender, tokenIn, amountIn, minAmountOut, salt
        ));

        uint256 committedAt = commitTimestamps[commitment];
        require(committedAt != 0,                                       "Not committed");
        require(block.timestamp >= committedAt + REVEAL_DELAY,          "Too early");
        require(block.timestamp <= committedAt + REVEAL_EXPIRY,         "Commitment expired");

        delete commitTimestamps[commitment];

        // Execute the actual swap — minAmountOut provides slippage protection
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(pool, amountIn);
        amountOut = ISimpleDEX(pool).swap(tokenIn, amountIn);
        require(amountOut >= minAmountOut, "Slippage exceeded");

        emit SwapRevealed(commitment, msg.sender, amountOut);
    }

    // -------------------------------------------------------
    // Pattern 2: TWAP Order — spread a large swap across blocks
    // Reduces price impact and makes sandwich attacks unprofitable
    // -------------------------------------------------------
    struct TWAPOrder {
        address tokenIn;
        address tokenOut;
        uint256 totalAmountIn;
        uint256 amountPerInterval;
        uint256 minAmountOutPerInterval;
        uint256 intervalSeconds;
        uint256 lastExecuted;
        uint256 executedSoFar;
        address owner;
    }

    mapping(uint256 => TWAPOrder) public orders;
    uint256 public nextOrderId;

    function createTWAPOrder(
        address tokenIn,
        address tokenOut,
        uint256 totalAmount,
        uint256 intervals,           // number of swaps
        uint256 intervalSeconds,     // seconds between each swap
        uint256 minAmountOutPerInterval
    ) external returns (uint256 orderId) {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), totalAmount);

        orderId = nextOrderId++;
        orders[orderId] = TWAPOrder({
            tokenIn:                 tokenIn,
            tokenOut:                tokenOut,
            totalAmountIn:           totalAmount,
            amountPerInterval:       totalAmount / intervals,
            minAmountOutPerInterval: minAmountOutPerInterval,
            intervalSeconds:         intervalSeconds,
            lastExecuted:            0,
            executedSoFar:           0,
            owner:                   msg.sender
        });
    }

    function executeTWAPInterval(uint256 orderId, address pool) external {
        TWAPOrder storage order = orders[orderId];
        require(block.timestamp >= order.lastExecuted + order.intervalSeconds, "Too early");
        require(order.executedSoFar < order.totalAmountIn, "Order complete");

        order.lastExecuted  = block.timestamp;
        order.executedSoFar += order.amountPerInterval;

        IERC20(order.tokenIn).approve(pool, order.amountPerInterval);
        uint256 out = ISimpleDEX(pool).swap(order.tokenIn, order.amountPerInterval);
        require(out >= order.minAmountOutPerInterval, "Slippage exceeded");

        IERC20(order.tokenOut).transfer(order.owner, out);
    }

    // -------------------------------------------------------
    // Pattern 3: Deadline guard — protect against delayed inclusion
    // -------------------------------------------------------
    modifier validDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, "Transaction expired");
        _;
    }

    // -------------------------------------------------------
    // Pattern 4: Slippage guard on any numeric output
    // -------------------------------------------------------
    modifier minOutput(uint256 actual, uint256 minimum) {
        require(actual >= minimum, "Slippage: output too low");
        _;
    }
}

// ============================================================
// SECTION 14: DEFI SECURITY CHECKLIST
// ============================================================

/*
 * ORACLE SECURITY
 * [ ] Using Chainlink with staleness check (updatedAt + heartbeat)
 * [ ] Checking answeredInRound >= roundId
 * [ ] Never using spot price for collateral valuation — use TWAP
 * [ ] Multiple oracle sources for critical price feeds
 * [ ] Circuit breaker if price moves > X% in short time
 *
 * FLASH LOAN PROTECTION
 * [ ] Any state that can be changed in one tx has proper guards
 * [ ] Price calculations do not rely on on-chain spot price
 * [ ] Reentrancy guards on all state-changing functions
 * [ ] nonReentrant on all external calls that handle funds
 *
 * AMM INTEGRATION
 * [ ] Always setting minAmountOut (slippage tolerance)
 * [ ] Always setting deadline parameter
 * [ ] Using TWAP instead of spot for valuations
 * [ ] Checking pool liquidity before large swaps
 *
 * LIQUIDATION
 * [ ] Health factor updates happen before external calls
 * [ ] Bad debt handled explicitly (not silently socialized)
 * [ ] Close factor limits liquidation to ≤ 50% per call
 * [ ] Liquidation bonus is reasonable (too high → griefing)
 *
 * GOVERNANCE
 * [ ] Timelock on all parameter changes
 * [ ] Proposal threshold prevents spam
 * [ ] Quorum requirement prevents low-participation attacks
 * [ ] Voting power snapshot at proposal creation (not execution)
 * [ ] Emergency pause mechanism separate from governance
 *
 * FLASH LOANS
 * [ ] Validating initiator in executeOperation / callback
 * [ ] All paths repay the loan (no way to exit without repaying)
 * [ ] Fee calculation correct (principal + premium)
 * [ ] msg.sender check in callback (only pool can call)
 *
 * MEV
 * [ ] All user-facing swaps have slippage protection
 * [ ] Large protocol swaps use TWAP or private mempool
 * [ ] Commit-reveal for sensitive actions
 * [ ] Deadline parameter on all time-sensitive operations
 *
 * INTEREST & YIELD
 * [ ] Interest accrued before any balance check
 * [ ] No rounding in favor of the protocol that accumulates over time
 * [ ] Index-based accounting instead of per-user timestamps
 * [ ] Correct order: accrue → update state → transfer
 */

// ============================================================
// MINIMAL INTERFACES (used across sections)
// ============================================================

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface ISimpleDEX {
    function swap(address tokenIn, uint256 amountIn) external returns (uint256 amountOut);
    function tokenOut(address tokenIn) external view returns (address);
}

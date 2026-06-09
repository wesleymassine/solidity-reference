// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// =============================================================================
// UNISWAP V4: HOOKS ARCHITECTURE & SINGLETON POOL MANAGER
// =============================================================================
// Uniswap V4 (2024-2025) is a complete redesign with three radical changes:
//
// 1. SINGLETON POOL MANAGER
//    - All pools live in a single contract (vs one contract per pool in V2/V3)
//    - Massive gas savings: ETH transfers are internal accounting (ERC-6909)
//    - One deployment address for all pools on each chain
//
// 2. HOOKS
//    - Contracts that plug into pool lifecycle events (before/after swap, etc.)
//    - Enable: custom curves, dynamic fees, limit orders, TWAMM, MEV capture
//    - Hook address encodes which callbacks are enabled (permissions bitmap)
//
// 3. FLASH ACCOUNTING (ERC-6909 + transient storage)
//    - Within a tx, balances can go negative temporarily ("delta")
//    - All deltas must net to zero by end of tx (BalanceDelta settlement)
//    - Removes token transfer overhead during complex multi-step operations
//
// Key contracts:
//   PoolManager      — the singleton: all pools, all liquidity, all swaps
//   IHooks           — interface your hook must implement
//   PoolKey          — identifies a pool (token0, token1, fee, tickSpacing, hook)
//   BalanceDelta     — signed int128 pair representing token0 and token1 changes
//   Currency         — wrapper for address (address(0) = native ETH)
// =============================================================================

// =============================================================================
// SECTION 1 — CORE TYPES
// =============================================================================

// Currency wraps a token address. address(0) = native ETH in V4.
type Currency is address;

library CurrencyLibrary {
    Currency public constant NATIVE = Currency.wrap(address(0));

    function isNative(Currency currency) internal pure returns (bool) {
        return Currency.unwrap(currency) == address(0);
    }

    function toId(Currency currency) internal pure returns (uint256) {
        return uint256(uint160(Currency.unwrap(currency)));
    }
}

// PoolKey uniquely identifies a V4 pool
struct PoolKey {
    Currency currency0;     // must be < currency1 (sorted)
    Currency currency1;
    uint24   fee;           // 500, 3000, 10000 — or dynamic fee flag
    int24    tickSpacing;   // granularity of price ticks
    IHooks   hooks;         // hook contract address (encodes permissions)
}

// BalanceDelta: packed int128 pair — amount0 and amount1 owed/received
type BalanceDelta is int256;

library BalanceDeltaLibrary {
    function amount0(BalanceDelta delta) internal pure returns (int128) {
        return int128(BalanceDelta.unwrap(delta) >> 128);
    }
    function amount1(BalanceDelta delta) internal pure returns (int128) {
        return int128(BalanceDelta.unwrap(delta));
    }
    function toBalanceDelta(int128 _amount0, int128 _amount1)
        internal pure returns (BalanceDelta delta)
    {
        assembly {
            delta := or(shl(128, _amount0), and(sub(shl(128, 1), 1), _amount1))
        }
    }
}

// Swap parameters
struct SwapParams {
    bool    zeroForOne;         // true = swap currency0 → currency1
    int256  amountSpecified;    // positive = exact input, negative = exact output
    uint160 sqrtPriceLimitX96;  // price boundary (like V3)
}

// Modify liquidity parameters
struct ModifyLiquidityParams {
    int24  tickLower;
    int24  tickUpper;
    int256 liquidityDelta;   // positive = add, negative = remove
    bytes32 salt;            // allows multiple positions at same tick range
}

// =============================================================================
// SECTION 2 — IHOOKS INTERFACE (THE CORE OF V4)
// =============================================================================
// A hook is a contract that the PoolManager calls at specific lifecycle points.
// The hook's ADDRESS encodes which callbacks are active (low-order bits).
// This means you must deploy your hook to an address that has the right bits set
// (use a CREATE2 salt miner to find the right address).
//
// Bit layout of hook address (low 14 bits):
//   Bit 13: BEFORE_INITIALIZE
//   Bit 12: AFTER_INITIALIZE
//   Bit 11: BEFORE_ADD_LIQUIDITY
//   Bit 10: AFTER_ADD_LIQUIDITY
//   Bit  9: BEFORE_REMOVE_LIQUIDITY
//   Bit  8: AFTER_REMOVE_LIQUIDITY
//   Bit  7: BEFORE_SWAP
//   Bit  6: AFTER_SWAP
//   Bit  5: BEFORE_DONATE
//   Bit  4: AFTER_DONATE
//   Bit  3: BEFORE_SWAP_RETURNS_DELTA   (hook can modify swap delta)
//   Bit  2: AFTER_SWAP_RETURNS_DELTA    (hook can take/return tokens after swap)
//   Bit  1: AFTER_ADD_LIQUIDITY_RETURNS_DELTA
//   Bit  0: AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA

interface IHooks {
    function beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96)
        external returns (bytes4);

    function afterInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick)
        external returns (bytes4);

    function beforeAddLiquidity(
        address sender, PoolKey calldata key,
        ModifyLiquidityParams calldata params, bytes calldata hookData
    ) external returns (bytes4);

    function afterAddLiquidity(
        address sender, PoolKey calldata key,
        ModifyLiquidityParams calldata params, BalanceDelta delta,
        BalanceDelta feesAccrued, bytes calldata hookData
    ) external returns (bytes4, BalanceDelta);

    function beforeRemoveLiquidity(
        address sender, PoolKey calldata key,
        ModifyLiquidityParams calldata params, bytes calldata hookData
    ) external returns (bytes4);

    function afterRemoveLiquidity(
        address sender, PoolKey calldata key,
        ModifyLiquidityParams calldata params, BalanceDelta delta,
        BalanceDelta feesAccrued, bytes calldata hookData
    ) external returns (bytes4, BalanceDelta);

    function beforeSwap(
        address sender, PoolKey calldata key,
        SwapParams calldata params, bytes calldata hookData
    ) external returns (bytes4, BeforeSwapDelta, uint24);

    function afterSwap(
        address sender, PoolKey calldata key,
        SwapParams calldata params, BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128);

    function beforeDonate(
        address sender, PoolKey calldata key,
        uint256 amount0, uint256 amount1, bytes calldata hookData
    ) external returns (bytes4);

    function afterDonate(
        address sender, PoolKey calldata key,
        uint256 amount0, uint256 amount1, bytes calldata hookData
    ) external returns (bytes4);
}

// BeforeSwapDelta: hook's modification to the swap amounts
type BeforeSwapDelta is int256;

// =============================================================================
// SECTION 3 — POOL MANAGER INTERFACE
// =============================================================================

interface IPoolManager {
    // Initialize a new pool (deploys no contract — state stored in PoolManager)
    function initialize(PoolKey calldata key, uint160 sqrtPriceX96)
        external returns (int24 tick);

    // Add/remove liquidity to a pool
    function modifyLiquidity(
        PoolKey calldata key,
        ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (BalanceDelta callerDelta, BalanceDelta feesAccrued);

    // Swap tokens in a pool
    function swap(
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata hookData
    ) external returns (BalanceDelta swapDelta);

    // Flash accounting: settle a positive delta (pay what you owe)
    function settle() external payable returns (uint256 paid);

    // Flash accounting: take tokens you are owed
    function take(Currency currency, address to, uint256 amount) external;

    // Flash accounting: sync token balance (used before settle)
    function sync(Currency currency) external;

    // ERC-6909: internal token balances (avoid actual transfers)
    function mint(address to, uint256 id, uint256 amount) external;
    function burn(address from, uint256 id, uint256 amount) external;

    // Execute a series of actions atomically via callback
    function unlock(bytes calldata data) external returns (bytes memory);

    // Get current pool state
    function getSlot0(PoolId id) external view
        returns (uint160 sqrtPriceX96, int24 tick, uint24 protocolFee, uint24 lpFee);

    function getLiquidity(PoolId id) external view returns (uint128 liquidity);
}

type PoolId is bytes32;

library PoolIdLibrary {
    function toId(PoolKey calldata key) internal pure returns (PoolId) {
        return PoolId.wrap(keccak256(abi.encode(key)));
    }
}

// =============================================================================
// SECTION 4 — BASE HOOK (INHERIT THIS IN YOUR HOOKS)
// =============================================================================
// Provides default implementations that return the correct selector.
// Override only the callbacks you need.

abstract contract BaseHook is IHooks {
    IPoolManager public immutable poolManager;

    error NotPoolManager();

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        _;
    }

    // Default implementations return the function selector (no-op)
    function beforeInitialize(address, PoolKey calldata, uint160)
        external virtual override returns (bytes4) {
        return IHooks.beforeInitialize.selector;
    }
    function afterInitialize(address, PoolKey calldata, uint160, int24)
        external virtual override returns (bytes4) {
        return IHooks.afterInitialize.selector;
    }
    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external virtual override returns (bytes4) {
        return IHooks.beforeAddLiquidity.selector;
    }
    function afterAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, BalanceDelta, BalanceDelta, bytes calldata)
        external virtual override returns (bytes4, BalanceDelta) {
        return (IHooks.afterAddLiquidity.selector, BalanceDeltaLibrary.toBalanceDelta(0, 0));
    }
    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external virtual override returns (bytes4) {
        return IHooks.beforeRemoveLiquidity.selector;
    }
    function afterRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, BalanceDelta, BalanceDelta, bytes calldata)
        external virtual override returns (bytes4, BalanceDelta) {
        return (IHooks.afterRemoveLiquidity.selector, BalanceDeltaLibrary.toBalanceDelta(0, 0));
    }
    function beforeSwap(address, PoolKey calldata, SwapParams calldata, bytes calldata)
        external virtual override returns (bytes4, BeforeSwapDelta, uint24) {
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }
    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        external virtual override returns (bytes4, int128) {
        return (IHooks.afterSwap.selector, 0);
    }
    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external virtual override returns (bytes4) {
        return IHooks.beforeDonate.selector;
    }
    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external virtual override returns (bytes4) {
        return IHooks.afterDonate.selector;
    }
}

// =============================================================================
// SECTION 5 — DYNAMIC FEE HOOK
// =============================================================================
// A hook that adjusts the swap fee based on pool volatility.
// High volatility → higher fee (protects LPs from impermanent loss).
// This is one of the most common and valuable hook patterns.

contract DynamicFeeHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    // Volatility oracle — tracks price variance per pool
    mapping(PoolId => uint256) public lastSqrtPrice;
    mapping(PoolId => uint256) public volatilityAccumulator;
    mapping(PoolId => uint256) public lastUpdateBlock;

    // Fee bounds (in hundredths of a bip — same as V3)
    uint24 public constant MIN_FEE = 500;    // 0.05%
    uint24 public constant MAX_FEE = 10_000; // 1%
    uint24 public constant BASE_FEE = 3_000; // 0.3%

    // Flag to signal PoolManager this pool uses dynamic fees
    uint24 public constant DYNAMIC_FEE_FLAG = 0x800000;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function beforeInitialize(address, PoolKey calldata key, uint160 sqrtPriceX96)
        external override onlyPoolManager returns (bytes4)
    {
        // Ensure pool is configured with dynamic fee flag
        require(key.fee == DYNAMIC_FEE_FLAG, "Must use dynamic fee");

        PoolId id = key.toId();
        lastSqrtPrice[id] = sqrtPriceX96;
        lastUpdateBlock[id] = block.number;

        return IHooks.beforeInitialize.selector;
    }

    // Called before every swap — returns the fee for this specific swap
    function beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId id = key.toId();
        uint24 dynamicFee = _computeFee(id);
        // Update volatility tracker
        _updateVolatility(id);
        // Return: selector, no delta override, the fee to use
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), dynamicFee);
    }

    function _computeFee(PoolId id) internal view returns (uint24) {
        uint256 vol = volatilityAccumulator[id];
        // Simple linear fee: higher volatility → higher fee
        // vol = 0 → MIN_FEE, vol >= 100 → MAX_FEE
        if (vol == 0) return BASE_FEE;
        uint256 fee = BASE_FEE + (vol * (MAX_FEE - BASE_FEE)) / 100;
        if (fee > MAX_FEE) fee = MAX_FEE;
        if (fee < MIN_FEE) fee = MIN_FEE;
        return uint24(fee);
    }

    function _updateVolatility(PoolId id) internal {
        (uint160 currentSqrtPrice,,,) = poolManager.getSlot0(id);
        uint256 last = lastSqrtPrice[id];
        if (last > 0) {
            // Measure relative price change as a volatility proxy
            uint256 change = currentSqrtPrice > last
                ? (currentSqrtPrice - last) * 100 / last
                : (last - currentSqrtPrice) * 100 / last;
            // Decay accumulator + add current change (exponential moving average style)
            volatilityAccumulator[id] = (volatilityAccumulator[id] * 9 + change * 10) / 10;
        }
        lastSqrtPrice[id] = currentSqrtPrice;
        lastUpdateBlock[id] = block.number;
    }
}

// =============================================================================
// SECTION 6 — LIMIT ORDER HOOK (ON-CHAIN LIMIT ORDERS VIA HOOKS)
// =============================================================================
// Users place limit orders at specific tick prices.
// When the pool price crosses that tick, the hook fills the order.
// This is not possible in V2/V3 without off-chain infrastructure.

contract LimitOrderHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    struct LimitOrder {
        address owner;
        bool    zeroForOne;    // direction of the order
        int24   tickToFill;    // fill when price crosses this tick
        uint256 inputAmount;
        bool    filled;
    }

    mapping(PoolId => mapping(int24 => LimitOrder[])) public orders;
    mapping(PoolId => int24) public lastTick;

    event LimitOrderPlaced(PoolId indexed poolId, int24 tick, address owner, uint256 amount);
    event LimitOrderFilled(PoolId indexed poolId, int24 tick, address owner);

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    // User places a limit order at a specific tick
    function placeLimitOrder(
        PoolKey calldata key,
        int24 tick,
        bool zeroForOne,
        uint256 inputAmount
    ) external {
        PoolId id = key.toId();
        orders[id][tick].push(LimitOrder({
            owner:       msg.sender,
            zeroForOne:  zeroForOne,
            tickToFill:  tick,
            inputAmount: inputAmount,
            filled:      false
        }));
        emit LimitOrderPlaced(id, tick, msg.sender, inputAmount);
    }

    // After each swap, check if any limit orders should be filled
    function afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, int128) {
        PoolId id = key.toId();
        (, int24 currentTick,,) = poolManager.getSlot0(id);
        int24 prevTick = lastTick[id];

        // Check if price crossed any limit order ticks
        if (params.zeroForOne) {
            // Price moved down: fill zeroForOne sell orders in crossed range
            for (int24 t = prevTick; t >= currentTick; t -= key.tickSpacing) {
                _fillOrdersAtTick(id, t, true);
            }
        } else {
            // Price moved up: fill oneForZero buy orders in crossed range
            for (int24 t = prevTick; t <= currentTick; t += key.tickSpacing) {
                _fillOrdersAtTick(id, t, false);
            }
        }

        lastTick[id] = currentTick;
        return (IHooks.afterSwap.selector, 0);
    }

    function _fillOrdersAtTick(PoolId id, int24 tick, bool zeroForOne) internal {
        LimitOrder[] storage tickOrders = orders[id][tick];
        for (uint256 i = 0; i < tickOrders.length; i++) {
            LimitOrder storage order = tickOrders[i];
            if (!order.filled && order.zeroForOne == zeroForOne) {
                order.filled = true;
                emit LimitOrderFilled(id, tick, order.owner);
                // In production: execute the swap and settle tokens to order.owner
            }
        }
    }
}

// =============================================================================
// SECTION 7 — TWAMM HOOK (TIME-WEIGHTED AVERAGE MARKET MAKER)
// =============================================================================
// TWAMM allows users to execute large orders over time, averaging the price.
// Prevents market impact of large trades (whale orders).
// Orders are split into infinitely many infinitesimally small swaps over time.
// In practice: orders execute block-by-block using virtual swap math.

contract TWAMMHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    struct LongTermOrder {
        address owner;
        bool    sellToken0;   // direction
        uint256 sellRate;     // tokens to sell per block
        uint256 startBlock;
        uint256 endBlock;
        uint256 claimable0;
        uint256 claimable1;
    }

    mapping(PoolId => LongTermOrder[]) public longTermOrders;
    mapping(PoolId => uint256) public lastExecutionBlock;

    event LTOPlaced(PoolId indexed poolId, uint256 indexed orderId, address owner, uint256 sellRate);
    event LTOExecuted(PoolId indexed poolId, uint256 blocksExecuted);

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    // User submits a long-term order (e.g., sell 1000 USDC over 100 blocks)
    function submitLongTermOrder(
        PoolKey calldata key,
        bool sellToken0,
        uint256 totalAmount,
        uint256 durationBlocks
    ) external returns (uint256 orderId) {
        PoolId id = key.toId();
        uint256 sellRate = totalAmount / durationBlocks;

        orderId = longTermOrders[id].length;
        longTermOrders[id].push(LongTermOrder({
            owner:      msg.sender,
            sellToken0: sellToken0,
            sellRate:   sellRate,
            startBlock: block.number,
            endBlock:   block.number + durationBlocks,
            claimable0: 0,
            claimable1: 0
        }));
        emit LTOPlaced(id, orderId, msg.sender, sellRate);
    }

    // Execute pending TWAMM orders before each swap
    // Ensures TWAMM state is always up-to-date with market price
    function beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, BeforeSwapDelta, uint24) {
        _executeTWAMM(key);
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }

    function _executeTWAMM(PoolKey calldata key) internal {
        PoolId id = key.toId();
        uint256 last = lastExecutionBlock[id];
        if (last >= block.number) return;

        uint256 blocksElapsed = block.number - last;
        lastExecutionBlock[id] = block.number;

        // Execute virtual swaps for each active long-term order
        LongTermOrder[] storage orders = longTermOrders[id];
        for (uint256 i = 0; i < orders.length; i++) {
            LongTermOrder storage order = orders[i];
            if (block.number <= order.startBlock || last >= order.endBlock) continue;

            uint256 startBlock = last < order.startBlock ? order.startBlock : last;
            uint256 endBlock   = block.number > order.endBlock ? order.endBlock : block.number;
            uint256 blocks     = endBlock - startBlock;
            uint256 sellAmount = order.sellRate * blocks;

            // In production: execute virtual swap via PoolManager.swap() using
            // `sellAmount` and accumulate claimable amounts for the order owner.
            // This is simplified — real TWAMM math uses continuous-time formulas.
            sellAmount; // placeholder: consumed by the swap in production
        }
        emit LTOExecuted(id, blocksElapsed);
    }
}

// =============================================================================
// SECTION 8 — CUSTOM CURVE HOOK (NON-XY=K POOLS)
// =============================================================================
// V4 hooks can override the AMM math entirely, implementing any curve:
// - Constant sum (stableswap-like)
// - Geometric mean market maker
// - Custom bonding curves
// This uses the BEFORE_SWAP_RETURNS_DELTA flag — hook handles the swap itself.

contract ConstantSumHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    // Pool reserves managed by the hook (not the PoolManager's tick math)
    mapping(PoolId => uint256) public reserve0;
    mapping(PoolId => uint256) public reserve1;

    error InsufficientReserves();

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    // Hook handles the entire swap using constant-sum math (P = 1:1 always)
    // Returns a BeforeSwapDelta that tells PoolManager to skip its own math
    function beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, BeforeSwapDelta, uint24) {
        PoolId id = key.toId();

        // Constant sum: for every unit of token0 in, give 1 unit of token1 out
        // Only valid for equal-value tokens (stablecoins, wrapped equivalents)
        int256 amountIn  = params.amountSpecified;
        int256 amountOut = -amountIn; // 1:1 swap

        if (params.zeroForOne) {
            if (reserve1[id] < uint256(-amountOut)) revert InsufficientReserves();
            reserve0[id] += uint256(amountIn);
            reserve1[id] -= uint256(-amountOut);
        } else {
            if (reserve0[id] < uint256(-amountOut)) revert InsufficientReserves();
            reserve1[id] += uint256(amountIn);
            reserve0[id] -= uint256(-amountOut);
        }

        // Encode as BeforeSwapDelta: tells PoolManager the hook consumed/produced these amounts
        BeforeSwapDelta hookDelta = BeforeSwapDelta.wrap(
            int256(abi.decode(abi.encode(amountIn, amountOut), (int256)))
        );

        return (IHooks.beforeSwap.selector, hookDelta, 0);
    }
}

// =============================================================================
// SECTION 9 — SWAP ROUTER (HOW USERS INTERACT WITH V4)
// =============================================================================
// In V4, users don't call PoolManager directly.
// They use a router that handles the flash accounting settlement.
// The router calls poolManager.unlock() which calls back into the router.

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract V4SwapRouter {
    IPoolManager public immutable poolManager;

    struct SwapCallbackData {
        address payer;
        PoolKey key;
        SwapParams params;
    }

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    // User-facing swap function
    function swap(
        PoolKey calldata key,
        SwapParams calldata params,
        uint256 amountInMax,
        uint256 amountOutMin
    ) external payable returns (BalanceDelta delta) {
        // Encode callback data and unlock the PoolManager
        bytes memory callbackData = abi.encode(
            SwapCallbackData({ payer: msg.sender, key: key, params: params })
        );
        bytes memory result = poolManager.unlock(callbackData);
        delta = abi.decode(result, (BalanceDelta));

        // Slippage checks
        int128 a0 = BalanceDeltaLibrary.amount0(delta);
        int128 a1 = BalanceDeltaLibrary.amount1(delta);
        if (params.zeroForOne) {
            require(uint256(int256(a0)) <= amountInMax, "Too much input");
            require(uint256(int256(-a1)) >= amountOutMin, "Too little output");
        } else {
            require(uint256(int256(a1)) <= amountInMax, "Too much input");
            require(uint256(int256(-a0)) >= amountOutMin, "Too little output");
        }
    }

    // Called back by PoolManager.unlock() — this is where the swap executes
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "Not pool manager");

        SwapCallbackData memory callbackData = abi.decode(data, (SwapCallbackData));
        BalanceDelta delta = poolManager.swap(
            callbackData.key,
            callbackData.params,
            ""
        );

        // Settle: pay what we owe, take what we're owed
        _settleDeltas(callbackData.payer, callbackData.key, delta);

        return abi.encode(delta);
    }

    function _settleDeltas(
        address payer,
        PoolKey memory key,
        BalanceDelta delta
    ) internal {
        int128 a0 = BalanceDeltaLibrary.amount0(delta);
        int128 a1 = BalanceDeltaLibrary.amount1(delta);

        // Positive delta = we owe tokens to the pool (pay)
        // Negative delta = pool owes us tokens (take)
        if (a0 > 0) {
            _pay(key.currency0, payer, uint128(a0));
        } else if (a0 < 0) {
            poolManager.take(key.currency0, payer, uint128(-a0));
        }

        if (a1 > 0) {
            _pay(key.currency1, payer, uint128(a1));
        } else if (a1 < 0) {
            poolManager.take(key.currency1, payer, uint128(-a1));
        }
    }

    function _pay(Currency currency, address payer, uint128 amount) internal {
        if (CurrencyLibrary.isNative(currency)) {
            poolManager.settle{value: amount}();
        } else {
            address token = Currency.unwrap(currency);
            IERC20(token).transferFrom(payer, address(poolManager), amount);
            poolManager.settle();
        }
    }

    receive() external payable {}
}

// =============================================================================
// SECTION 10 — DEPLOYING A HOOK WITH CORRECT ADDRESS
// =============================================================================
// The hook address's lower 14 bits MUST match the permissions it claims.
// Deploy with CREATE2 using a mined salt to get the right address.
//
// Required bit positions for a beforeSwap + afterSwap hook:
//   bit 7 (beforeSwap)  = 1 → address must have bit 7 set
//   bit 6 (afterSwap)   = 1 → address must have bit 6 set
//   Required suffix: 0b00000011000000 = 0x0C0
//
// Foundry hook deployment pattern:
//
//   // In your deploy script:
//   bytes32 salt = bytes32(0);
//   while (true) {
//       address predicted = CREATE2_FACTORY.computeAddress(salt, bytecodeHash);
//       if (uint160(predicted) & HookMiner.ALL_HOOK_MASK == requiredFlags) break;
//       salt = bytes32(uint256(salt) + 1);
//   }
//   hook = new MyHook{salt: salt}(poolManager);
//
// Use the HookMiner utility from v4-periphery:
//   import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
//   (address hookAddress, bytes32 salt) = HookMiner.find(
//       CREATE2_DEPLOYER, flags, type(MyHook).creationCode, abi.encode(poolManager)
//   );

// =============================================================================
// SECTION 11 — HOOK PERMISSIONS FLAGS REFERENCE
// =============================================================================
//
// Use Hooks.Permissions struct from v4-core to specify which callbacks your hook uses.
// Only implement callbacks whose bits are set in the hook address.
//
// Example: a hook that only intercepts beforeSwap
//
//   uint160 constant FLAGS = uint160(Hooks.BEFORE_SWAP_FLAG);
//   // Mine a CREATE2 salt so that hook address has bit 7 set in low 14 bits
//
// Hooks.sol constants (from v4-core):
//   BEFORE_INITIALIZE_FLAG              = 1 << 13  // 0x2000
//   AFTER_INITIALIZE_FLAG               = 1 << 12  // 0x1000
//   BEFORE_ADD_LIQUIDITY_FLAG           = 1 << 11  // 0x0800
//   AFTER_ADD_LIQUIDITY_FLAG            = 1 << 10  // 0x0400
//   BEFORE_REMOVE_LIQUIDITY_FLAG        = 1 << 9   // 0x0200
//   AFTER_REMOVE_LIQUIDITY_FLAG         = 1 << 8   // 0x0100
//   BEFORE_SWAP_FLAG                    = 1 << 7   // 0x0080
//   AFTER_SWAP_FLAG                     = 1 << 6   // 0x0040
//   BEFORE_DONATE_FLAG                  = 1 << 5   // 0x0020
//   AFTER_DONATE_FLAG                   = 1 << 4   // 0x0010
//   BEFORE_SWAP_RETURNS_DELTA_FLAG      = 1 << 3   // 0x0008
//   AFTER_SWAP_RETURNS_DELTA_FLAG       = 1 << 2   // 0x0004
//   AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG  = 1 << 1  // 0x0002
//   AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG = 1 << 0 // 0x0001

// =============================================================================
// PROFESSIONAL CHECKLIST: UNISWAP V4 HOOK AUDIT POINTS
// =============================================================================
//
// [ ] Hook address bits: lower 14 bits match exactly the callbacks implemented
// [ ] onlyPoolManager: all hook callbacks restricted to poolManager address
// [ ] No reentrancy: hook callbacks cannot re-enter PoolManager (lock is held)
// [ ] BalanceDelta sign convention: positive = owe pool, negative = pool owes you
// [ ] Delta accounting: if hook takes/mints tokens, must be reflected in returned delta
// [ ] Dynamic fee flag: fee must be DYNAMIC_FEE_FLAG (0x800000) if hook sets fee
// [ ] CREATE2 salt: use HookMiner to find correct deployment salt
// [ ] Gas usage: hook callbacks are inside the swap path — keep them cheap
// [ ] Flash accounting: settle() must be called before end of unlock() callback
// [ ] Currency sort: PoolKey.currency0 < currency1 always (sort before creating key)
// [ ] TWAMM timing: execute pending virtual orders before each swap (stale = wrong price)
// [ ] Limit order ticks: iterate only valid ticks (multiples of tickSpacing)
// [ ] Custom curve: BEFORE_SWAP_RETURNS_DELTA required if hook bypasses AMM math
// [ ] Test with v4-template: use the official Foundry template for hook testing

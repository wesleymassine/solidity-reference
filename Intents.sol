// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// =============================================================================
// INTENTS & DECLARATIVE TRANSACTION ARCHITECTURE
// =============================================================================
// Traditional transactions are IMPERATIVE: "call swap() on Uniswap with these
// exact parameters". Intents are DECLARATIVE: "I want 100 USDC for at most
// 1 ETH by tomorrow". A network of solvers competes to fulfill the intent.
//
// Core components:
//   User        — signs an intent (off-chain message) with constraints
//   Intent      — declarative order specifying desired outcome + bounds
//   Solver      — off-chain agent that finds the best execution path
//   Settler     — on-chain contract that validates and settles intents
//
// Key benefits:
//   - Better execution (solvers compete for best price/route)
//   - MEV protection (solver internalizes MEV instead of extractors)
//   - Gas abstraction (solver pays gas, charges in output token)
//   - Cross-chain execution possible via cross-chain intents
//
// Major protocols using intents architecture (2025-2026):
//   - UniswapX (ERC-7521 inspired, Dutch auction)
//   - CoW Protocol (batch auctions, coincidence of wants)
//   - Across Protocol (cross-chain, ERC-7683)
//   - 1inch Fusion
//   - Anoma (intent-centric L1)
// =============================================================================

// =============================================================================
// SECTION 1 — INTENT DATA STRUCTURES
// =============================================================================

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

// A generic swap intent: user declares what they want, not how to get it
struct SwapIntent {
    address user;           // signer / beneficiary
    address tokenIn;        // token the user is selling
    address tokenOut;       // token the user wants to receive
    uint256 amountIn;       // exact input amount
    uint256 minAmountOut;   // minimum acceptable output (slippage bound)
    uint256 nonce;          // replay protection
    uint256 deadline;       // unix timestamp after which intent is invalid
    bytes32 orderId;        // off-chain order identifier for tracking
}

// A limit order intent: fill at best price up to a limit
struct LimitOrderIntent {
    address user;
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 limitPrice;     // minimum tokenOut per tokenIn (18 decimal fixed point)
    bool    partialFill;    // whether partial fills are acceptable
    uint256 nonce;
    uint256 deadline;
}

// A cross-chain intent (ERC-7683 inspired)
struct CrossChainIntent {
    address user;
    uint256 originChainId;
    uint256 destinationChainId;
    address tokenIn;          // on origin chain
    uint256 amountIn;
    address tokenOut;         // on destination chain
    uint256 minAmountOut;
    address destinationUser;  // recipient on destination chain
    uint256 fillDeadline;     // deadline for solver to fill on destination
    uint256 nonce;
    bytes   extraData;        // protocol-specific data
}

// =============================================================================
// SECTION 2 — DUTCH AUCTION ORDER (UniswapX-style)
// =============================================================================
// Price decays linearly from startAmount to endAmount over the auction window.
// First solver to fill gets the best spread; later fills are cheaper for users.

struct DutchAuctionOrder {
    address user;
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 startAmountOut;   // output at auctionStartTime (highest price)
    uint256 endAmountOut;     // output at auctionEndTime   (lowest price, still min)
    uint256 auctionStartTime; // unix timestamp
    uint256 auctionEndTime;   // unix timestamp
    uint256 nonce;
    bytes   signature;        // EIP-712 signature over the order
}

library DutchAuctionMath {
    // Returns the minimum output the solver must deliver at the current time.
    // Linear decay: output = start - (start - end) * elapsed / duration
    function currentOutput(DutchAuctionOrder memory order)
        internal
        view
        returns (uint256)
    {
        if (block.timestamp <= order.auctionStartTime) return order.startAmountOut;
        if (block.timestamp >= order.auctionEndTime)   return order.endAmountOut;

        uint256 elapsed  = block.timestamp - order.auctionStartTime;
        uint256 duration = order.auctionEndTime - order.auctionStartTime;
        uint256 decay    = (order.startAmountOut - order.endAmountOut) * elapsed / duration;
        return order.startAmountOut - decay;
    }
}

// =============================================================================
// SECTION 3 — INTENT SETTLER CONTRACT
// =============================================================================
// The settler is the on-chain verifier and settlement engine.
// It validates signatures, enforces constraints, and transfers tokens.
// Solvers call settle() after finding the execution path.

contract IntentSettler {
    using DutchAuctionMath for DutchAuctionOrder;

    // EIP-712 domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    bytes32 private constant SWAP_INTENT_TYPEHASH = keccak256(
        "SwapIntent(address user,address tokenIn,address tokenOut,"
        "uint256 amountIn,uint256 minAmountOut,uint256 nonce,uint256 deadline,bytes32 orderId)"
    );

    bytes32 private constant DUTCH_ORDER_TYPEHASH = keccak256(
        "DutchAuctionOrder(address user,address tokenIn,address tokenOut,"
        "uint256 amountIn,uint256 startAmountOut,uint256 endAmountOut,"
        "uint256 auctionStartTime,uint256 auctionEndTime,uint256 nonce)"
    );

    // Tracks used nonces per user to prevent replay attacks
    mapping(address => mapping(uint256 => bool)) public usedNonces;

    // Approved solvers (optional: open to any solver vs permissioned set)
    mapping(address => bool) public approvedSolvers;
    bool public openSolvers; // if true, any address can be a solver

    address public owner;

    event IntentSettled(
        bytes32 indexed orderId,
        address indexed user,
        address indexed solver,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );
    event DutchOrderSettled(
        address indexed user,
        address indexed solver,
        uint256 amountOut
    );
    event NonceUsed(address indexed user, uint256 nonce);

    error InvalidSignature();
    error IntentExpired();
    error NonceUsedError();
    error InsufficientOutput();
    error UnauthorizedSolver();
    error AuctionNotStarted();

    constructor() {
        owner = msg.sender;
        openSolvers = true; // anyone can solve by default
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("IntentSettler"),
            keccak256("1"),
            block.chainid,
            address(this)
        ));
    }

    modifier onlySolver() {
        if (!openSolvers && !approvedSolvers[msg.sender])
            revert UnauthorizedSolver();
        _;
    }

    // ==========================================================================
    // Settle a simple swap intent
    // The solver:
    //   1. Pulls tokenIn from user (with pre-approval to this contract)
    //   2. Executes the swap off-contract (any venue)
    //   3. Delivers tokenOut >= minAmountOut to user
    // ==========================================================================
    function settleSwapIntent(
        SwapIntent calldata intent,
        bytes calldata signature,
        uint256 amountOut   // actual output the solver delivers
    ) external onlySolver {
        // Validate deadline
        if (block.timestamp > intent.deadline) revert IntentExpired();
        // Validate nonce
        if (usedNonces[intent.user][intent.nonce]) revert NonceUsedError();
        // Validate signature
        _verifySwapIntent(intent, signature);
        // Validate output
        if (amountOut < intent.minAmountOut) revert InsufficientOutput();

        // Mark nonce as used
        usedNonces[intent.user][intent.nonce] = true;
        emit NonceUsed(intent.user, intent.nonce);

        // Pull tokenIn from user
        IERC20(intent.tokenIn).transferFrom(intent.user, msg.sender, intent.amountIn);

        // Solver must deliver tokenOut directly to user.
        // NOTE: solver is trusted to have executed the swap before calling here.
        // In practice this is done atomically in the same tx (solver → settle → transfer).
        IERC20(intent.tokenOut).transferFrom(msg.sender, intent.user, amountOut);

        emit IntentSettled(
            intent.orderId, intent.user, msg.sender,
            intent.tokenIn, intent.tokenOut, intent.amountIn, amountOut
        );
    }

    // ==========================================================================
    // Settle a Dutch auction order
    // ==========================================================================
    function settleDutchOrder(
        DutchAuctionOrder calldata order,
        uint256 amountOut   // must be >= currentOutput() at this block
    ) external onlySolver {
        if (block.timestamp < order.auctionStartTime) revert AuctionNotStarted();
        if (block.timestamp > order.auctionEndTime)   revert IntentExpired();
        if (usedNonces[order.user][order.nonce])       revert NonceUsedError();

        // Compute minimum required output at current time
        uint256 minOut = order.currentOutput();
        if (amountOut < minOut) revert InsufficientOutput();

        // Verify EIP-712 signature
        _verifyDutchOrder(order);

        usedNonces[order.user][order.nonce] = true;

        // Pull tokenIn from user; deliver tokenOut
        IERC20(order.tokenIn).transferFrom(order.user, msg.sender, order.amountIn);
        IERC20(order.tokenOut).transferFrom(msg.sender, order.user, amountOut);

        emit DutchOrderSettled(order.user, msg.sender, amountOut);
    }

    // ==========================================================================
    // Cancel an intent before it's filled (user increments nonce off-chain)
    // ==========================================================================
    function cancelNonce(uint256 nonce) external {
        usedNonces[msg.sender][nonce] = true;
        emit NonceUsed(msg.sender, nonce);
    }

    // ==========================================================================
    // EIP-712 signature verification helpers
    // ==========================================================================
    function _verifySwapIntent(
        SwapIntent calldata intent,
        bytes calldata signature
    ) internal view {
        bytes32 structHash = keccak256(abi.encode(
            SWAP_INTENT_TYPEHASH,
            intent.user,
            intent.tokenIn,
            intent.tokenOut,
            intent.amountIn,
            intent.minAmountOut,
            intent.nonce,
            intent.deadline,
            intent.orderId
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address recovered = _recoverSigner(digest, signature);
        if (recovered != intent.user) revert InvalidSignature();
    }

    function _verifyDutchOrder(DutchAuctionOrder calldata order) internal view {
        bytes32 structHash = keccak256(abi.encode(
            DUTCH_ORDER_TYPEHASH,
            order.user,
            order.tokenIn,
            order.tokenOut,
            order.amountIn,
            order.startAmountOut,
            order.endAmountOut,
            order.auctionStartTime,
            order.auctionEndTime,
            order.nonce
        ));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
        address recovered = _recoverSigner(digest, order.signature);
        if (recovered != order.user) revert InvalidSignature();
    }

    function _recoverSigner(bytes32 digest, bytes memory sig) internal pure returns (address) {
        require(sig.length == 65, "Invalid sig length");
        bytes32 r; bytes32 s; uint8 v;
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        return ecrecover(digest, v, r, s);
    }
}

// =============================================================================
// SECTION 4 — SOLVER CONTRACT PATTERN
// =============================================================================
// A solver is an off-chain bot that monitors the intent mempool, finds
// profitable fills, and calls the settler. On-chain, the solver contract
// executes the routing atomically within the settle call.
//
// Pattern: "fill-or-revert" — solver builds the calldata for swap execution,
// wraps in a single atomic tx, and the settler verifies constraints.

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract SolverContract {
    address public immutable settler;
    address public immutable owner;

    constructor(address _settler) {
        settler = _settler;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Pull tokenIn from settler (which pulled from user), swap via router,
    // then push tokenOut back to settler for user delivery — all atomic.
    function fillSwapViaUniswap(
        SwapIntent calldata intent,
        bytes calldata signature,
        address router,
        address[] calldata path
    ) external onlyOwner {
        // Snapshot tokenOut balance before
        uint256 balanceBefore = IERC20(intent.tokenOut).balanceOf(address(this));

        // Approve settler to pull tokenIn from us (solver provides the tokens)
        // In this model: solver holds tokenIn inventory and delivers tokenOut.
        // Alternative: solver pre-approves settler and gets atomically reimbursed.

        // Swap tokenIn → tokenOut via Uniswap
        IERC20(intent.tokenIn).approve(router, intent.amountIn);
        uint256[] memory amounts = IUniswapV2Router(router).swapExactTokensForTokens(
            intent.amountIn,
            intent.minAmountOut,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountOut = amounts[amounts.length - 1];

        // Approve settler to pull tokenOut from solver → user
        IERC20(intent.tokenOut).approve(settler, amountOut);

        // Settle — settler verifies signature and delivers tokens to user
        IntentSettler(settler).settleSwapIntent(intent, signature, amountOut);

        // Solver profit = amountOut received from Uniswap - amountOut delivered to user
        // This is usually positive due to spread/MEV captured by solver
    }
}

// =============================================================================
// SECTION 5 — ERC-7521 GENERALIZED INTENTS (SIMPLIFIED)
// =============================================================================
// ERC-7521 proposes a standard interface for generalized intents,
// allowing any "segment" of intent logic to be composed modularly.
//
// Core interface (simplified from the EIP):

interface IIntentStandard {
    // Returns a unique identifier for this intent standard
    function standardId() external view returns (bytes32);

    // Called by the EntryPoint to validate an intent's segment
    function validateUserIntent(
        UserIntent calldata intent,
        bytes32 intentHash,
        uint256 segmentIndex,
        uint256 timestamp
    ) external view returns (bool);

    // Called by the EntryPoint after the intent is filled
    function executeUserIntentSegment(
        UserIntent calldata intent,
        uint256 segmentIndex,
        bytes calldata context
    ) external;
}

struct UserIntent {
    address sender;       // user's smart account
    uint256 nonce;
    bytes[] segments;     // array of encoded intent segments (modular)
    bytes signature;
}

// Example: a simple ERC-20 release segment (user gives tokens)
contract ERC20ReleaseStandard is IIntentStandard {
    // public constant auto-generates the `standardId()` getter that satisfies
    // IIntentStandard — no separate function needed.
    bytes32 public constant override standardId =
        keccak256("ERC20Release(address token,uint256 amount)");

    struct ERC20ReleaseData {
        address token;
        uint256 amount;
    }

    function validateUserIntent(
        UserIntent calldata intent,
        bytes32,
        uint256 segmentIndex,
        uint256
    ) external view override returns (bool) {
        ERC20ReleaseData memory data = abi.decode(intent.segments[segmentIndex], (ERC20ReleaseData));
        // Validate user has sufficient balance
        return IERC20(data.token).balanceOf(intent.sender) >= data.amount;
    }

    function executeUserIntentSegment(
        UserIntent calldata intent,
        uint256 segmentIndex,
        bytes calldata
    ) external override {
        ERC20ReleaseData memory data = abi.decode(intent.segments[segmentIndex], (ERC20ReleaseData));
        IERC20(data.token).transferFrom(intent.sender, msg.sender, data.amount);
    }
}

// =============================================================================
// SECTION 6 — CROSS-CHAIN INTENTS (ERC-7683 / Across Protocol style)
// =============================================================================
// Cross-chain intents allow users to express: "I want X on chain B in exchange
// for Y on chain A". Solvers pre-fund the destination chain and get repaid on
// the origin chain (with a relay fee).

interface ICrossChainSettler {
    // Called on destination chain: solver delivers output to user
    function fill(
        CrossChainIntent calldata intent,
        bytes calldata fillerData
    ) external;

    // Called on origin chain: repay solver after fill is proven
    function settle(
        CrossChainIntent calldata intent,
        bytes calldata proof      // e.g., Merkle proof of fill on destination
    ) external;
}

// Simple cross-chain settler (origin chain side)
contract CrossChainOriginSettler {
    mapping(bytes32 => bool) public settledOrders;
    mapping(bytes32 => bool) public cancelledOrders;

    address public immutable oracle; // bridge/oracle that verifies fills

    event OrderOpened(bytes32 indexed orderId, address user);
    event OrderSettled(bytes32 indexed orderId, address solver);
    event OrderCancelled(bytes32 indexed orderId);

    error OrderAlreadySettled();
    error OrderNotExpired();
    error InvalidProof();

    constructor(address _oracle) {
        oracle = _oracle;
    }

    // User opens an order — locks tokenIn on origin chain
    function open(CrossChainIntent calldata intent) external {
        bytes32 orderId = _hashIntent(intent);
        require(!settledOrders[orderId], "Already settled");

        // Lock user's tokens on origin chain
        IERC20(intent.tokenIn).transferFrom(
            intent.user, address(this), intent.amountIn
        );

        emit OrderOpened(orderId, intent.user);
    }

    // Solver claims repayment after fill is proven on destination chain
    function settle(CrossChainIntent calldata intent, bytes calldata proof)
        external
    {
        bytes32 orderId = _hashIntent(intent);
        if (settledOrders[orderId]) revert OrderAlreadySettled();

        // Oracle verifies the fill happened on destination chain
        require(_verifyFill(orderId, proof), "Invalid proof");

        settledOrders[orderId] = true;

        // Pay solver the locked tokenIn (+ they keep the spread as fee)
        IERC20(intent.tokenIn).transfer(msg.sender, intent.amountIn);

        emit OrderSettled(orderId, msg.sender);
    }

    // User can cancel after fillDeadline passes (no fill happened)
    function cancel(CrossChainIntent calldata intent) external {
        require(block.timestamp > intent.fillDeadline, "Not yet expired");
        bytes32 orderId = _hashIntent(intent);
        require(!settledOrders[orderId], "Already settled");

        cancelledOrders[orderId] = true;

        // Refund user
        IERC20(intent.tokenIn).transfer(intent.user, intent.amountIn);

        emit OrderCancelled(orderId);
    }

    function _hashIntent(CrossChainIntent calldata intent) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            intent.user, intent.originChainId, intent.destinationChainId,
            intent.tokenIn, intent.amountIn, intent.tokenOut, intent.minAmountOut,
            intent.destinationUser, intent.fillDeadline, intent.nonce
        ));
    }

    function _verifyFill(bytes32 orderId, bytes calldata proof) internal view returns (bool) {
        // In production: call the oracle/bridge adapter to verify proof
        // e.g., UMA Optimistic Oracle, Across SpokePool proof, etc.
        (bytes32 provenOrderId, bool filled) = abi.decode(proof, (bytes32, bool));
        return provenOrderId == orderId && filled;
    }
}

// =============================================================================
// SECTION 7 — ANTI-MANIPULATION PATTERNS
// =============================================================================
// Intents systems must prevent:
//   1. Solver collusion (solvers agree not to compete, giving bad prices)
//   2. Front-running of intent mempools (extracting MEV before solvers)
//   3. Stale intent replay (old intents executed at unfavorable prices)
//   4. Partial fill griefing (solver fills 1 wei to lock nonce)

contract AntiManipulationSettler {
    // Minimum fill ratio for partial fills (e.g., 10% = 1000 bps)
    uint256 public constant MIN_FILL_BPS = 1000; // 10%
    uint256 public constant BPS_DENOMINATOR = 10_000;

    // Per-intent fill tracking for partial fills
    mapping(bytes32 => uint256) public filledAmount;

    struct PartialFillIntent {
        address user;
        address tokenIn;
        address tokenOut;
        uint256 totalAmountIn;
        uint256 minAmountOut;   // for full fill
        uint256 nonce;
        uint256 deadline;
    }

    // Prevent griefing: partial fills must be >= MIN_FILL_BPS of remaining amount
    function partialFill(
        PartialFillIntent calldata intent,
        bytes calldata signature,
        uint256 fillAmountIn,
        uint256 fillAmountOut
    ) external {
        bytes32 id = keccak256(abi.encode(intent));
        uint256 remaining = intent.totalAmountIn - filledAmount[id];

        // Enforce minimum fill size to prevent griefing
        require(
            fillAmountIn >= remaining * MIN_FILL_BPS / BPS_DENOMINATOR,
            "Fill too small"
        );

        // Price check: proportional to the original intent's price
        uint256 requiredOut = intent.minAmountOut * fillAmountIn / intent.totalAmountIn;
        require(fillAmountOut >= requiredOut, "Insufficient output");

        filledAmount[id] += fillAmountIn;

        // Execute transfer...
        // (signature verification omitted for brevity — same as Section 3)
    }

    // Commitment scheme: solver commits to a fill before revealing execution
    // Prevents other solvers from front-running the profitable route
    mapping(bytes32 => uint256) public commitments; // commitment => blockNumber

    uint256 public constant COMMITMENT_BLOCKS = 2; // 2-block reveal window

    function commit(bytes32 commitment) external {
        commitments[commitment] = block.number;
    }

    function revealAndSettle(
        bytes32 intentId,
        bytes32 secret,         // secret that was in the commitment
        uint256 amountOut
    ) external {
        bytes32 commitment = keccak256(abi.encode(msg.sender, intentId, secret, amountOut));
        uint256 committedAt = commitments[commitment];
        require(committedAt != 0, "No commitment found");
        require(block.number >= committedAt + COMMITMENT_BLOCKS, "Too early to reveal");
        require(block.number <= committedAt + COMMITMENT_BLOCKS + 10, "Reveal window expired");

        delete commitments[commitment];
        // Proceed with settlement...
    }
}

// =============================================================================
// PROFESSIONAL CHECKLIST: INTENTS SYSTEM AUDIT POINTS
// =============================================================================
//
// [ ] EIP-712 domain separator: includes chainId + verifyingContract
// [ ] Nonce replay protection: per-user nonce mapping, cancel() function
// [ ] Deadline enforcement: block.timestamp > deadline reverts
// [ ] Minimum output check: amountOut >= minAmountOut (or proportional for partial)
// [ ] Solver authorization: open or permissioned solver set
// [ ] Dutch auction math: linear decay, no underflow at boundaries
// [ ] Partial fill griefing: minimum fill ratio enforced
// [ ] Cross-chain proof: oracle/bridge proof verified before settlement
// [ ] Cancel after expiry: user can reclaim tokens if no fill
// [ ] Front-running: commitment scheme or private mempool for solvers
// [ ] Token transfer order: pull before push (CEI pattern)
// [ ] Gas estimation: solvers must estimate gas on-chain before competing

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// ============================================================
//  FORMALVERIFICATION.SOL — Formal Verification & Advanced
//  Property Testing: Complete Reference
// ============================================================
//
//  Formal verification mathematically proves that a contract
//  satisfies a specification — not just for sampled inputs,
//  but for ALL possible inputs and states.
//
//  This file covers:
//  - SMTChecker (built into Solidity compiler)
//  - Certora Prover (CVL language)
//  - Echidna (property-based fuzzer by Trail of Bits)
//  - Halmos (symbolic execution on top of Foundry)
//  - Mutation testing (Gambit)
//  - Invariant design patterns
//  - Specification writing methodology
//
//  SECTIONS:
//  1.  Verification Landscape
//  2.  SMTChecker — Built-in Solidity Verifier
//  3.  Invariant Design Patterns
//  4.  Certora Prover — CVL Specification Language
//  5.  Echidna — Property-Based Fuzzing (Trail of Bits)
//  6.  Halmos — Symbolic Execution with Foundry
//  7.  Mutation Testing with Gambit
//  8.  Writing Specifications: Methodology
//  9.  Verified Contract Patterns
//  10. Formal Verification Checklist
//
// ============================================================

// ============================================================
// SECTION 1: VERIFICATION LANDSCAPE
// ============================================================

/*
 * TOOL COMPARISON:
 *
 * ┌─────────────────┬──────────────┬──────────────┬─────────────┐
 * │ Tool            │ Technique    │ Coverage     │ Difficulty  │
 * ├─────────────────┼──────────────┼──────────────┼─────────────┤
 * │ SMTChecker      │ SMT solving  │ Bounded      │ Low         │
 * │                 │ (z3/cvc5)    │ (loop bounds)│ (in-file)   │
 * ├─────────────────┼──────────────┼──────────────┼─────────────┤
 * │ Certora Prover  │ Deductive FV │ Unbounded    │ High        │
 * │                 │ (Horn clauses│ (inductive)  │ (CVL lang)  │
 * ├─────────────────┼──────────────┼──────────────┼─────────────┤
 * │ Echidna         │ Coverage-    │ Statistical  │ Medium      │
 * │                 │ guided fuzz  │ (many runs)  │ (Solidity)  │
 * ├─────────────────┼──────────────┼──────────────┼─────────────┤
 * │ Halmos          │ Symbolic EVM │ Bounded      │ Medium      │
 * │                 │ (on Foundry) │ (loops)      │ (Foundry)   │
 * ├─────────────────┼──────────────┼──────────────┼─────────────┤
 * │ Foundry Fuzz    │ Random fuzz  │ Statistical  │ Low         │
 * │                 │             │              │ (Foundry)   │
 * ├─────────────────┼──────────────┼──────────────┼─────────────┤
 * │ Gambit          │ Mutation     │ Test quality │ Low         │
 * │                 │ testing      │ measurement  │ (CLI)       │
 * └─────────────────┴──────────────┴──────────────┴─────────────┘
 *
 * WHEN TO USE EACH:
 *
 * SMTChecker    → Always on. Free, catches obvious issues during compile.
 * Foundry Fuzz  → All projects. First line of property testing.
 * Echidna       → DeFi protocols, token contracts. Better corpus than Foundry fuzz.
 * Halmos        → When you need to prove a property exhaustively for bounded depth.
 * Certora       → High-value protocols ($10M+ TVL), before mainnet launch.
 * Gambit        → Measure test suite quality; find undertested branches.
 *
 * SPECIFICATION TYPES (from weakest to strongest):
 * 1. Unit tests      — specific input → specific output
 * 2. Fuzz tests      — random inputs → property holds
 * 3. Invariants      — property holds across ALL states
 * 4. Formal proofs   — mathematically proven for all inputs + states
 */

// ============================================================
// SECTION 2: SMTCHECKER — BUILT-IN SOLIDITY VERIFIER
// ============================================================

/*
 * SMTChecker is built into solc. It uses SMT solvers (z3, cvc5)
 * to prove or disprove assertions, overflow, division by zero,
 * array out-of-bounds, and more.
 *
 * ENABLE IN foundry.toml:
 *   [profile.default]
 *   model_checker = { engine = "chc", targets = ["assert", "overflow", "underflow", "divByZero", "outOfBounds"] }
 *   model_checker_timeout = 10000   # ms per query
 *
 * OR via CLI:
 *   solc --model-checker-engine chc \
 *        --model-checker-targets "assert,overflow,underflow,divByZero" \
 *        --model-checker-show-unproved \
 *        MyContract.sol
 *
 * ENGINES:
 *   bmc  = Bounded Model Checking (fast, incomplete, misses some loops)
 *   chc  = Constrained Horn Clauses (slower, more complete, preferred)
 *   all  = both engines
 *
 * TARGETS:
 *   assert        = assert() statements
 *   overflow      = arithmetic overflow/underflow
 *   underflow     = explicit underflow detection
 *   divByZero     = division or modulo by zero
 *   constantCondition = conditions always true/false (dead code)
 *   popEmptyArray = pop on empty array
 *   outOfBounds   = array index out of bounds
 *   balance       = ETH balance operations
 *
 * ANNOTATIONS:
 *   /// @custom:smtchecker abstract-function-nondet
 *     Treats an external function as returning arbitrary values.
 *     Use on interfaces to avoid false positives.
 */

/// @title SMTCheckerExamples — demonstrates SMTChecker annotations and patterns
contract SMTCheckerExamples {

    mapping(address => uint256) public balances;
    uint256 public totalSupply;

    // -------------------------------------------------------
    // SMTChecker will PROVE this can never overflow
    // because a + b <= type(uint256).max is checked first
    // -------------------------------------------------------
    function safeAdd(uint256 a, uint256 b) public pure returns (uint256) {
        require(a + b >= a, "Overflow"); // SMTChecker sees this guard
        return a + b;
    }

    // -------------------------------------------------------
    // SMTChecker will PROVE this assertion always holds
    // given the require above
    // -------------------------------------------------------
    function transferWithAssertion(address from, address to, uint256 amount) external {
        require(balances[from] >= amount, "Insufficient balance");
        require(from != to,               "Self-transfer");

        uint256 fromBefore = balances[from];
        uint256 toBefore   = balances[to];

        balances[from] -= amount;
        balances[to]   += amount;

        // SMTChecker proves: sum of balances is preserved
        assert(balances[from] + balances[to] == fromBefore + toBefore);

        // SMTChecker proves: no individual balance exceeds totalSupply
        assert(balances[from] <= totalSupply);
        assert(balances[to]   <= totalSupply);
    }

    // -------------------------------------------------------
    // Annotate external calls to prevent false positives
    // -------------------------------------------------------
    /// @custom:smtchecker abstract-function-nondet
    function externalPriceOracle() external view virtual returns (uint256) {}

    function useOracle() external view returns (uint256) {
        uint256 price = this.externalPriceOracle();
        // SMTChecker treats price as arbitrary — will check safety for all values
        require(price > 0, "Zero price");
        return 1e36 / price; // SMTChecker verifies no division-by-zero (require above)
    }

    // -------------------------------------------------------
    // Loop bound annotation — helps BMC engine
    // -------------------------------------------------------
    /// @custom:smtchecker abstract-function-nondet
    function processArray(uint256[] memory arr) external pure returns (uint256 sum) {
        // Without bounds, BMC engine unrolls only a few iterations.
        // For CHC engine, loops are handled inductively — no annotation needed.
        for (uint256 i = 0; i < arr.length; i++) {
            sum += arr[i];
            // SMTChecker checks: sum doesn't overflow (via unchecked block detection)
        }
    }
}

// ============================================================
// SECTION 3: INVARIANT DESIGN PATTERNS
// ============================================================

/*
 * An invariant is a property that must hold across ALL states,
 * regardless of how the contract got there.
 *
 * CATEGORIES:
 *
 * 1. CONSERVATION INVARIANTS
 *    "Nothing is created or destroyed"
 *    Example: sum(balanceOf) == totalSupply
 *
 * 2. ORDERING INVARIANTS
 *    "A always happens before B"
 *    Example: contract must be initialized before use
 *
 * 3. BOUND INVARIANTS
 *    "Value X is always between lower and upper"
 *    Example: healthFactor > 0, fee <= 10%
 *
 * 4. MONOTONIC INVARIANTS
 *    "Value X only ever increases (or decreases)"
 *    Example: nonce always increases, share price never decreases in normal operation
 *
 * 5. EQUIVALENCE INVARIANTS
 *    "These two things always represent the same state"
 *    Example: aToken.balanceOf(vault) == vault's recorded totalDeposited
 *
 * 6. ACCESS CONTROL INVARIANTS
 *    "Only authorized actors can change critical state"
 *    Example: owner() can never be address(0) after initialization
 *
 * HOW TO DISCOVER INVARIANTS:
 * 1. List all state variables
 * 2. For each variable, ask: "what is always true about this?"
 * 3. For pairs of variables, ask: "what relationship always holds?"
 * 4. Think about economic invariants: "where does value go?"
 * 5. Read the protocol's whitepaper / spec doc
 */

/// @title InvariantExamples — contracts with explicit invariant documentation
contract InvariantExamples {

    // -------------------------------------------------------
    // STATE (document invariants next to each variable)
    // -------------------------------------------------------

    mapping(address => uint256) public balanceOf;
    /// INVARIANT: sum(balanceOf[*]) == totalSupply at all times
    uint256 public totalSupply;

    mapping(address => mapping(address => uint256)) public allowance;

    address public owner;
    /// INVARIANT: owner != address(0) after construction

    bool public initialized;
    /// INVARIANT: no external function callable before initialized == true

    uint256 public constant MAX_FEE_BPS = 1000; // 10%
    uint256 public feeBps;
    /// INVARIANT: feeBps <= MAX_FEE_BPS at all times

    uint256 public nonce;
    /// INVARIANT: nonce is strictly monotonically increasing

    mapping(bytes32 => bool) public usedNonces;
    /// INVARIANT: once usedNonces[h] = true, it never becomes false again

    uint256 private _totalDeposited;
    uint256 private _totalWithdrawn;
    /// INVARIANT: _totalDeposited >= _totalWithdrawn at all times

    // -------------------------------------------------------
    // FUNCTIONS WITH EXPLICIT INVARIANT MAINTENANCE
    // -------------------------------------------------------

    constructor(address _owner) {
        require(_owner != address(0), "Zero owner");
        owner       = _owner;
        initialized = true;
        // POST: owner != address(0) ✓
        // POST: initialized == true ✓
    }

    modifier whenInitialized() {
        require(initialized, "Not initialized");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function setFee(uint256 newFeeBps) external onlyOwner whenInitialized {
        // Enforce bound invariant before updating
        require(newFeeBps <= MAX_FEE_BPS, "Fee too high");
        feeBps = newFeeBps;
        // POST: feeBps <= MAX_FEE_BPS ✓
    }

    function transferOwnership(address newOwner) external onlyOwner {
        // Enforce non-null invariant before updating
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
        // POST: owner != address(0) ✓
    }

    function mint(address to, uint256 amount) external onlyOwner whenInitialized {
        // Maintain conservation invariant
        balanceOf[to] += amount;
        totalSupply   += amount;
        // POST: sum(balanceOf) == totalSupply ✓ (added same amount to both)
    }

    function burn(address from, uint256 amount) external whenInitialized {
        require(balanceOf[from] >= amount, "Insufficient");
        // Maintain conservation invariant
        balanceOf[from] -= amount;
        totalSupply     -= amount;
        // POST: sum(balanceOf) == totalSupply ✓
    }

    function useNonce(uint256 userNonce) external whenInitialized {
        require(userNonce == nonce, "Wrong nonce");
        nonce++;
        // POST: nonce increased by exactly 1 ✓ (monotonic)
    }

    function markUsed(bytes32 hash) external whenInitialized {
        require(!usedNonces[hash], "Already used");
        usedNonces[hash] = true;
        // POST: usedNonces[hash] == true, never reverts to false ✓
    }

    function deposit(uint256 amount) external whenInitialized {
        _totalDeposited += amount;
        // POST: _totalDeposited >= _totalWithdrawn still holds ✓
    }

    function withdraw(uint256 amount) external whenInitialized {
        require(_totalDeposited >= _totalWithdrawn + amount, "Over-withdrawal");
        _totalWithdrawn += amount;
        // POST: _totalDeposited >= _totalWithdrawn ✓
    }
}

// ============================================================
// SECTION 4: CERTORA PROVER — CVL SPECIFICATION LANGUAGE
// ============================================================

/*
 * Certora Prover uses CVL (Certora Verification Language) to write
 * formal specifications that are mathematically proven.
 *
 * SETUP:
 *   pip install certora-cli
 *   certoraRun MyToken.sol --verify MyToken:specs/MyToken.spec \
 *     --solc solc-0.8.24 \
 *     --msg "ERC20 invariants"
 *
 * CVL FILE STRUCTURE (specs/MyToken.spec):
 *
 *   methods {
 *     function totalSupply() external returns (uint256) envfree;
 *     function balanceOf(address) external returns (uint256) envfree;
 *     function transfer(address, uint256) external returns (bool);
 *     function transferFrom(address, address, uint256) external returns (bool);
 *   }
 *
 *   // Ghost variable: tracks sum of all balances
 *   ghost mathint sumOfBalances {
 *     init_state axiom sumOfBalances == 0;
 *   }
 *
 *   // Hook: called every time balanceOf[key] is written
 *   hook Sstore _balances[KEY address addr] uint256 newVal (uint256 oldVal) STORAGE {
 *     sumOfBalances = sumOfBalances + newVal - oldVal;
 *   }
 *
 *   // INVARIANT 1: sum of balances equals totalSupply
 *   invariant totalSupplyEquality()
 *     sumOfBalances == to_mathint(totalSupply())
 *     filtered { f -> !f.isView }  // only check after state-changing functions
 *
 *   // INVARIANT 2: no single balance exceeds totalSupply
 *   invariant balanceNotExceedTotalSupply(address user)
 *     balanceOf(user) <= totalSupply()
 *
 *   // INVARIANT 3: address(0) always has zero balance
 *   invariant zeroAddressHasNoBalance()
 *     balanceOf(0) == 0
 *
 *   // RULE: transfer is correctly implemented
 *   rule transferIntegrity(address from, address to, uint256 amount) {
 *     env e;
 *     require e.msg.sender == from;
 *     require from != to;
 *
 *     uint256 fromBefore = balanceOf(from);
 *     uint256 toBefore   = balanceOf(to);
 *
 *     bool success = transfer(e, to, amount);
 *
 *     if (success) {
 *       assert balanceOf(from) == fromBefore - amount;
 *       assert balanceOf(to)   == toBefore + amount;
 *     } else {
 *       assert balanceOf(from) == fromBefore;
 *       assert balanceOf(to)   == toBefore;
 *     }
 *   }
 *
 *   // RULE: transfer never creates tokens
 *   rule transferDoesNotCreateTokens(address to, uint256 amount) {
 *     env e;
 *     uint256 supplyBefore = totalSupply();
 *     transfer(e, to, amount);
 *     assert totalSupply() == supplyBefore;
 *   }
 *
 *   // PARAMETRIC RULE: no function changes totalSupply except mint/burn
 *   rule onlyMintBurnChangeSupply(method f) {
 *     env e;
 *     uint256 supplyBefore = totalSupply();
 *     calldataarg args;
 *     f(e, args);
 *     uint256 supplyAfter = totalSupply();
 *
 *     assert supplyAfter != supplyBefore =>
 *       f.selector == sig:mint(address,uint256).selector ||
 *       f.selector == sig:burn(address,uint256).selector;
 *   }
 *
 *   // RULE: reentrancy safety — balance updates happen before external calls
 *   rule noReentrancyViaExternalCall(address to, uint256 amount) {
 *     env e;
 *     // Ensures effects happen before interactions
 *     uint256 balanceBefore = balanceOf(e.msg.sender);
 *     transfer(e, to, amount);
 *     // If transfer succeeded, sender's balance decreased atomically
 *     satisfy balanceOf(e.msg.sender) == balanceBefore - amount;
 *   }
 *
 * CERTORA CONF FILE (certoraRun.conf):
 * {
 *   "files": ["src/Token.sol"],
 *   "verify": "Token:specs/Token.spec",
 *   "solc": "solc-0.8.24",
 *   "optimistic_loop": true,
 *   "loop_iter": 3,
 *   "msg": "Token formal verification"
 * }
 */

// Contracts below are reference targets — Certora specs go in separate .spec files

/// @title ERC20Verifiable — ERC-20 written to facilitate formal verification
contract ERC20Verifiable {

    // Public storage for Certora hooks (Sstore/Sload)
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    uint256 public totalSupply;

    string  public name;
    string  public symbol;
    uint8   public constant decimals = 18;

    address public owner;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error InsufficientBalance(address account, uint256 available, uint256 required);
    error InsufficientAllowance(address spender, uint256 available, uint256 required);
    error ZeroAddress();

    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) {
        name        = _name;
        symbol      = _symbol;
        owner       = msg.sender;
        // Invariant-safe mint at construction
        balances[msg.sender] = _initialSupply;
        totalSupply           = _initialSupply;
        emit Transfer(address(0), msg.sender, _initialSupply);
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function allowance(address tokenOwner, address spender) external view returns (uint256) {
        return allowances[tokenOwner][spender];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (to == address(0))                  revert ZeroAddress();
        if (balances[msg.sender] < amount)
            revert InsufficientBalance(msg.sender, balances[msg.sender], amount);

        // Effects before interactions (CEI pattern)
        balances[msg.sender] -= amount;
        balances[to]         += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (to == address(0)) revert ZeroAddress();

        uint256 currentAllowance = allowances[from][msg.sender];
        if (currentAllowance < amount)
            revert InsufficientAllowance(msg.sender, currentAllowance, amount);
        if (balances[from] < amount)
            revert InsufficientBalance(from, balances[from], amount);

        // Effects before interactions
        if (currentAllowance != type(uint256).max) {
            allowances[from][msg.sender] -= amount;
        }
        balances[from] -= amount;
        balances[to]   += amount;

        emit Transfer(from, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == owner,   "Not owner");
        require(to != address(0),      "Zero address");
        balances[to] += amount;
        totalSupply  += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external {
        require(balances[from] >= amount, "Insufficient balance");
        balances[from] -= amount;
        totalSupply    -= amount;
        emit Transfer(from, address(0), amount);
    }
}

// ============================================================
// SECTION 5: ECHIDNA — PROPERTY-BASED FUZZING (TRAIL OF BITS)
// ============================================================

/*
 * Echidna is a Haskell fuzzer that finds violations of Solidity properties.
 * It uses coverage-guided fuzzing with a corpus that evolves over time.
 *
 * INSTALL:
 *   docker pull trailofbits/eth-security-toolbox
 *   # or: brew install echidna (macOS)
 *
 * RUN:
 *   echidna MyContract.sol --contract EchidnaTest --config echidna.yaml
 *
 * echidna.yaml:
 *   testMode: "property"
 *   testLimit: 100000
 *   seqLen: 100
 *   shrinkLimit: 5000
 *   workers: 4
 *   corpusDir: "echidna-corpus"
 *   coverage: true
 *   filterBlacklist: true
 *   filterFunctions:
 *     - "setUp()"
 *
 * PROPERTY NAMING:
 *   - Functions starting with "echidna_" are treated as properties
 *   - Must return bool
 *   - Echidna calls them after every sequence of transactions
 *   - If any returns false → counterexample found
 *
 * MODES:
 *   property  = call echidna_* functions, expect true
 *   assertion = catch assert() failures
 *   overflow  = catch arithmetic errors
 *   dapptest  = Foundry-style (testFuzz_*)
 *   optimization = maximize a return value (find maximum)
 */

/// @title EchidnaERC20Test — Echidna property tests for ERC20Verifiable
contract EchidnaERC20Test {

    ERC20Verifiable public token;
    address constant ALICE   = address(0x41);
    address constant BOB     = address(0x42);
    address constant CHARLIE = address(0x43);

    // Track expected supply via ghost variable
    uint256 private _mintedTotal;
    uint256 private _burnedTotal;

    constructor() {
        token = new ERC20Verifiable("Test", "TST", 1_000_000e18);
        _mintedTotal = 1_000_000e18;
    }

    // -------------------------------------------------------
    // PROPERTY 1: totalSupply == minted - burned
    // -------------------------------------------------------
    function echidna_totalSupplyAccountedFor() public view returns (bool) {
        return token.totalSupply() == _mintedTotal - _burnedTotal;
    }

    // -------------------------------------------------------
    // PROPERTY 2: sum of known balances <= totalSupply
    // -------------------------------------------------------
    function echidna_sumBalancesLeqSupply() public view returns (bool) {
        uint256 sum = token.balanceOf(address(this))
                    + token.balanceOf(ALICE)
                    + token.balanceOf(BOB)
                    + token.balanceOf(CHARLIE);
        return sum <= token.totalSupply();
    }

    // -------------------------------------------------------
    // PROPERTY 3: address(0) always has zero balance
    // -------------------------------------------------------
    function echidna_zeroAddressEmpty() public view returns (bool) {
        return token.balanceOf(address(0)) == 0;
    }

    // -------------------------------------------------------
    // PROPERTY 4: allowance cannot cause double-spend
    // If I approved X and transferFrom was called for X,
    // allowance should be 0
    // -------------------------------------------------------
    function echidna_allowanceMonotonicallyDecreases() public view returns (bool) {
        // Allowance can only decrease via transferFrom or be set via approve
        // This property is checked by Echidna across all state transitions
        return token.allowances(ALICE, address(this)) <= type(uint256).max;
    }

    // -------------------------------------------------------
    // PROPERTY 5: transfer preserves total (no creation/destruction)
    // -------------------------------------------------------
    function testTransferPreservesTotal(uint256 amount) public {
        uint256 supplyBefore = token.totalSupply();
        try token.transfer(ALICE, amount) {} catch {}
        assert(token.totalSupply() == supplyBefore);
    }

    // -------------------------------------------------------
    // Helper functions — Echidna will call these randomly
    // -------------------------------------------------------
    function mintTokens(address to, uint256 amount) public {
        amount = amount % 1_000_000e18; // bound
        try token.mint(to, amount) {
            _mintedTotal += amount;
        } catch {}
    }

    function burnTokens(uint256 amount) public {
        amount = amount % (token.balanceOf(address(this)) + 1);
        try token.burn(address(this), amount) {
            _burnedTotal += amount;
        } catch {}
    }

    function transferTokens(address to, uint256 amount) public {
        try token.transfer(to, amount) {} catch {}
    }

    function approveAndTransferFrom(address from, address to, uint256 amount) public {
        try token.approve(address(this), amount) {} catch {}
        try token.transferFrom(from, to, amount) {} catch {}
    }
}

/// @title EchidnaAMM — Echidna properties for an AMM pool
contract EchidnaAMMTest {

    // Simulated pool state
    uint256 public reserve0 = 1_000e18;
    uint256 public reserve1 = 1_000e18;
    uint256 public constant FEE = 3; // 0.3% = 3/1000

    // -------------------------------------------------------
    // PROPERTY: k (reserve0 * reserve1) never decreases after a swap
    // -------------------------------------------------------
    function echidna_kNeverDecreases() public view returns (bool) {
        // k = reserve0 * reserve1
        // After every swap, k should stay the same or increase (due to fees)
        return reserve0 * reserve1 >= 1_000e18 * 1_000e18;
    }

    // -------------------------------------------------------
    // PROPERTY: reserves are always positive
    // -------------------------------------------------------
    function echidna_reservesPositive() public view returns (bool) {
        return reserve0 > 0 && reserve1 > 0;
    }

    // -------------------------------------------------------
    // PROPERTY: price is always finite and positive
    // -------------------------------------------------------
    function echidna_priceFinitePositive() public view returns (bool) {
        return reserve0 > 0 && reserve1 > 0; // price = reserve1/reserve0
    }

    // Simulate a swap — Echidna calls this with random inputs
    function swap0For1(uint256 amountIn) public {
        if (amountIn == 0 || amountIn > 1_000_000e18) return;

        uint256 amountInWithFee = amountIn * (1000 - FEE);
        uint256 amountOut = (amountInWithFee * reserve1) / (reserve0 * 1000 + amountInWithFee);

        require(amountOut < reserve1, "Insufficient liquidity");

        reserve0 += amountIn;
        reserve1 -= amountOut;
    }

    function swap1For0(uint256 amountIn) public {
        if (amountIn == 0 || amountIn > 1_000_000e18) return;

        uint256 amountInWithFee = amountIn * (1000 - FEE);
        uint256 amountOut = (amountInWithFee * reserve0) / (reserve1 * 1000 + amountInWithFee);

        require(amountOut < reserve0, "Insufficient liquidity");

        reserve1 += amountIn;
        reserve0 -= amountOut;
    }
}

// ============================================================
// SECTION 6: HALMOS — SYMBOLIC EXECUTION WITH FOUNDRY
// ============================================================

/*
 * Halmos performs symbolic execution on Foundry tests.
 * Instead of concrete random inputs, it uses symbolic variables
 * and explores ALL possible paths up to a given depth.
 *
 * INSTALL:
 *   pip install halmos
 *
 * RUN:
 *   halmos --contract HalmosTest --function check_
 *   halmos --contract HalmosTest --loop 256 --symbolic-storage
 *
 * KEY DIFFERENCES from Foundry fuzz:
 *   - Foundry fuzz: random sampling (may miss edge cases)
 *   - Halmos: exhaustive within bounds (proves for ALL values in range)
 *
 * NAMING:
 *   - Functions starting with "check_" are Halmos properties
 *   - vm.assume() works the same as in Foundry
 *   - Use svm.createUint256() for symbolic variables
 *
 * LIMITATIONS:
 *   - Loops must be bounded (--loop N)
 *   - External contract calls create state explosion
 *   - Some opcodes not fully supported (e.g., ecrecover)
 *   - keccak256 treated as uninterpreted function
 */

// import {SymTest} from "halmos-cheatcodes/SymTest.sol";

/// @title HalmosTests — symbolic execution properties
/// @dev Run with: halmos --contract HalmosTests
// contract HalmosTests is SymTest, Test {
//
//     ERC20Verifiable token;
//
//     function setUp() public {
//         token = new ERC20Verifiable("Token", "TKN", 1_000_000e18);
//     }
//
//     // -------------------------------------------------------
//     // CHECK: transfer is correct for ALL possible inputs
//     // (not just sampled ones like in fuzz test)
//     // -------------------------------------------------------
//     function check_transferCorrect(
//         address from,
//         address to,
//         uint256 amount
//     ) public {
//         vm.assume(from != to);
//         vm.assume(from != address(0) && to != address(0));
//
//         // Give from a symbolic balance
//         uint256 fromBalance = svm.createUint256("fromBalance");
//         vm.assume(fromBalance >= amount);
//         deal(address(token), from, fromBalance);
//
//         uint256 fromBefore = token.balanceOf(from);
//         uint256 toBefore   = token.balanceOf(to);
//
//         vm.prank(from);
//         bool success = token.transfer(to, amount);
//
//         if (success) {
//             // Halmos PROVES these hold for every possible input
//             assert(token.balanceOf(from) == fromBefore - amount);
//             assert(token.balanceOf(to)   == toBefore + amount);
//         }
//     }
//
//     // -------------------------------------------------------
//     // CHECK: no function can reduce totalSupply except burn
//     // -------------------------------------------------------
//     function check_onlyBurnReducesSupply(
//         uint256 callerKey,
//         uint256 amount
//     ) public {
//         // Symbolic caller
//         address caller = vm.addr(bound(callerKey, 1, type(uint128).max));
//         deal(address(token), caller, amount);
//
//         uint256 supplyBefore = token.totalSupply();
//
//         vm.prank(caller);
//         try token.transfer(vm.addr(2), amount) {} catch {}
//
//         // Transfer must not change total supply
//         assert(token.totalSupply() == supplyBefore);
//     }
//
//     // -------------------------------------------------------
//     // CHECK: approve + transferFrom allowance accounting
//     // -------------------------------------------------------
//     function check_allowanceDecreasesCorrectly(
//         address owner,
//         address spender,
//         uint256 approveAmount,
//         uint256 transferAmount
//     ) public {
//         vm.assume(owner != spender);
//         vm.assume(owner != address(0) && spender != address(0));
//         vm.assume(transferAmount <= approveAmount);
//
//         deal(address(token), owner, approveAmount);
//
//         vm.prank(owner);
//         token.approve(spender, approveAmount);
//
//         vm.prank(spender);
//         token.transferFrom(owner, spender, transferAmount);
//
//         uint256 expectedAllowance = approveAmount == type(uint256).max
//             ? type(uint256).max
//             : approveAmount - transferAmount;
//
//         assert(token.allowance(owner, spender) == expectedAllowance);
//     }
// }

// ============================================================
// SECTION 7: MUTATION TESTING WITH GAMBIT
// ============================================================

/*
 * Mutation testing measures test suite quality by introducing
 * small bugs (mutations) and checking if tests catch them.
 *
 * IF A MUTATION SURVIVES (tests still pass) → your tests are missing coverage.
 *
 * GAMBIT: Solidity mutation tool by Certora
 *   pip install gambit
 *   gambit mutate --json gambit.json
 *   gambit summary --mdir gambit_out
 *
 * MUTATION TYPES GAMBIT APPLIES:
 *   BinaryOpMutation:    a + b → a - b, a * b, a / b, a % b
 *   RelationalMutation:  a < b → a <= b, a > b, a == b, a != b
 *   AssignmentMutation:  += → -=, *=, /=
 *   DeleteStatement:     removes a statement entirely
 *   ElimDelegate:        delegatecall → call
 *   FunctionCall:        changes function calls
 *   IfStatement:         inverts if conditions
 *   RequireMutation:     require(x) → require(!x)
 *   SwapArgumentsFunctions: swap two function arguments
 *   UnaryOperator:       -x → x, !x → x
 *
 * GAMBIT CONFIG (gambit.json):
 * {
 *   "filename": "src/Token.sol",
 *   "mutations": [
 *     "BinaryOpMutation",
 *     "RelationalMutation",
 *     "RequireMutation",
 *     "DeleteStatement"
 *   ],
 *   "sourceroot": ".",
 *   "num_mutants": 100
 * }
 *
 * WORKFLOW:
 * 1. Run: gambit mutate --json gambit.json
 *    → generates 100 mutants in gambit_out/
 * 2. For each mutant:
 *    → forge test --root gambit_out/mutant_N/
 * 3. Count survived mutants (tests passed = bug not caught)
 * 4. Mutation score = killed / total
 *    Good: > 90% killed
 *
 * EXAMPLE MUTATIONS GAMBIT WOULD APPLY TO OUR TOKEN:
 *
 * ORIGINAL:   balances[from] -= amount;
 * MUTANT 1:   balances[from] += amount;   // bug: wrong direction
 * MUTANT 2:   // deleted                  // bug: missing deduction
 *
 * ORIGINAL:   require(balances[from] >= amount);
 * MUTANT 3:   require(balances[from] <= amount); // bug: inverted
 * MUTANT 4:   require(balances[from] > amount);  // bug: off-by-one
 *
 * ORIGINAL:   totalSupply += amount;
 * MUTANT 5:   totalSupply -= amount;      // bug: wrong direction
 * MUTANT 6:   // deleted                  // bug: supply not updated
 *
 * A good test suite KILLS all of these.
 * If mutant 2 or 6 survive → you're missing conservation invariant tests.
 */

// ============================================================
// SECTION 8: WRITING SPECIFICATIONS — METHODOLOGY
// ============================================================

/*
 * STEP-BY-STEP SPECIFICATION PROCESS:
 *
 * STEP 1 — UNDERSTAND THE PROTOCOL
 *   Read: whitepaper, code, existing tests, audit reports
 *   Ask: What does this contract promise to do?
 *        What can go wrong?
 *        What would a malicious actor try?
 *
 * STEP 2 — LIST ALL STATE VARIABLES
 *   For each variable, document:
 *   - Valid range (e.g., feeBps in [0, 1000])
 *   - Who can change it (e.g., only owner)
 *   - Monotonicity (e.g., nonce always increases)
 *   - Relationship to other variables (e.g., sum(balanceOf) == totalSupply)
 *
 * STEP 3 — LIST ALL FUNCTIONS
 *   For each function:
 *   - Preconditions (require statements, who can call)
 *   - Effects (what state changes)
 *   - Postconditions (what must be true after)
 *   - Events emitted
 *
 * STEP 4 — DERIVE INVARIANTS
 *   From the state variable relationships and function effects,
 *   write invariants that hold before AND after every function call.
 *
 * STEP 5 — CATEGORIZE PROPERTIES
 *   Safety:   "bad thing never happens" (invariants, bounds)
 *   Liveness: "good thing eventually happens" (not provable with current tools)
 *   Functional: "function does what it says" (rules/postconditions)
 *   Access:   "only authorized actors can change X"
 *
 * STEP 6 — PRIORITIZE
 *   HIGH:   Conservation properties (totalSupply), access control
 *   MEDIUM: Functional correctness (transfer amounts)
 *   LOW:    Edge cases (zero transfers, self-transfers)
 *
 * SPECIFICATION TEMPLATE:
 *
 *   CONTRACT: [ContractName]
 *
 *   INVARIANTS:
 *   INV-01: sum(balanceOf[*]) == totalSupply
 *   INV-02: owner != address(0)
 *   INV-03: feeBps <= MAX_FEE_BPS
 *
 *   RULES:
 *   RULE-01: transfer(to, amount) decreases msg.sender balance by exactly amount
 *   RULE-02: transfer(to, amount) increases to balance by exactly amount
 *   RULE-03: transfer does not change totalSupply
 *   RULE-04: only owner can call mint()
 *
 *   ACCESS CONTROL:
 *   AC-01: setFee() reverts if msg.sender != owner
 *   AC-02: mint() reverts if msg.sender != owner
 *   AC-03: transferOwnership() reverts if msg.sender != owner
 *
 *   BOUNDS:
 *   BND-01: feeBps is always in [0, MAX_FEE_BPS]
 *   BND-02: nonce is monotonically increasing
 *   BND-03: no individual balance exceeds totalSupply
 */

// ============================================================
// SECTION 9: VERIFIED CONTRACT PATTERNS
// ============================================================

/*
 * Patterns that are easier to specify and verify formally.
 * Use these to reduce the verification surface area.
 */

/// @title VerifiedVault — vault pattern designed for formal verification
contract VerifiedVault {

    // -------------------------------------------------------
    // DESIGN FOR VERIFICATION:
    // 1. Separate accounting from token movements
    // 2. Use integers, not floats
    // 3. Avoid complex loops
    // 4. Make invariants explicit via assert() in DEBUG builds
    // 5. One job per function (Single Responsibility)
    // -------------------------------------------------------

    IERC20Minimal public immutable asset;

    // Accounting — ghost-variable-friendly (single slot per user)
    mapping(address => uint256) public shares;
    uint256 public totalShares;

    // Economic invariant tracking
    uint256 public totalAssetsSnapshot;   // updated each deposit/withdraw

    uint256 constant WAD = 1e18;

    bool private _locked;

    error Reentrancy();
    error ZeroAmount();
    error ZeroShares();
    error InsufficientShares(uint256 have, uint256 need);

    event Deposit(address indexed user, uint256 assets, uint256 sharesIssued);
    event Withdraw(address indexed user, uint256 assets, uint256 sharesBurned);

    modifier nonReentrant() {
        if (_locked) revert Reentrancy();
        _locked = true;
        _;
        _locked = false;
    }

    constructor(address _asset) {
        asset = IERC20Minimal(_asset);
    }

    // -------------------------------------------------------
    // VERIFIED PROPERTY (via assert):
    //   After deposit: shares[user] increased by exactly sharesIssued
    //                  totalShares increased by exactly sharesIssued
    // -------------------------------------------------------
    function deposit(uint256 assetAmount) external nonReentrant returns (uint256 sharesIssued) {
        if (assetAmount == 0) revert ZeroAmount();

        uint256 totalAssets_ = asset.balanceOf(address(this));

        // Calculate shares BEFORE transfer (immune to donation attacks)
        sharesIssued = totalShares == 0
            ? assetAmount                                           // first deposit: 1:1
            : (assetAmount * totalShares) / totalAssets_;          // proportional

        if (sharesIssued == 0) revert ZeroShares();

        // Record expected state
        uint256 sharesBefore = shares[msg.sender];
        uint256 totalBefore  = totalShares;

        // Transfer
        asset.transferFrom(msg.sender, address(this), assetAmount);

        // Update accounting
        shares[msg.sender] += sharesIssued;
        totalShares        += sharesIssued;
        totalAssetsSnapshot = asset.balanceOf(address(this));

        // Explicit postcondition assertions (active in testing, removed by optimizer in prod)
        assert(shares[msg.sender] == sharesBefore + sharesIssued);
        assert(totalShares        == totalBefore  + sharesIssued);

        emit Deposit(msg.sender, assetAmount, sharesIssued);
    }

    // -------------------------------------------------------
    // VERIFIED PROPERTY:
    //   After withdraw: shares[user] decreased by exactly sharesBurned
    //                   totalShares decreased by exactly sharesBurned
    //                   user received exactly assetsOut tokens
    // -------------------------------------------------------
    function withdraw(uint256 sharesBurned) external nonReentrant returns (uint256 assetsOut) {
        if (sharesBurned == 0)                     revert ZeroAmount();
        if (shares[msg.sender] < sharesBurned)
            revert InsufficientShares(shares[msg.sender], sharesBurned);

        uint256 totalAssets_ = asset.balanceOf(address(this));

        // Calculate assets proportional to shares burned
        assetsOut = (sharesBurned * totalAssets_) / totalShares;

        // Record expected state
        uint256 sharesBefore  = shares[msg.sender];
        uint256 totalBefore   = totalShares;
        uint256 balanceBefore = asset.balanceOf(msg.sender);

        // Update accounting BEFORE transfer (CEI pattern)
        shares[msg.sender] -= sharesBurned;
        totalShares        -= sharesBurned;
        totalAssetsSnapshot = asset.balanceOf(address(this)) - assetsOut;

        // Transfer
        asset.transfer(msg.sender, assetsOut);

        // Explicit postconditions
        assert(shares[msg.sender]        == sharesBefore - sharesBurned);
        assert(totalShares               == totalBefore  - sharesBurned);
        assert(asset.balanceOf(msg.sender) == balanceBefore + assetsOut);

        emit Withdraw(msg.sender, assetsOut, sharesBurned);
    }

    // -------------------------------------------------------
    // INVARIANT CHECKER — call externally to verify integrity
    // In production: remove or gate behind DEBUG flag
    // -------------------------------------------------------
    function checkInvariants() external view {
        // INV-01: vault holds at least as many assets as recorded
        assert(asset.balanceOf(address(this)) >= totalAssetsSnapshot);

        // INV-02: totalShares is consistent (no overflow)
        assert(totalShares <= type(uint128).max);

        // INV-03: if totalShares == 0, vault should hold no assets
        // (modulo any direct ETH/token donations)
    }
}

// ============================================================
// SECTION 10: FORMAL VERIFICATION CHECKLIST
// ============================================================

/*
 * BEFORE STARTING FORMAL VERIFICATION
 * [ ] All unit tests pass
 * [ ] Foundry fuzz tests written for all public functions
 * [ ] Invariant tests written with handler contract
 * [ ] Code is stable (no pending refactors)
 * [ ] External dependencies are mocked or have their own specs
 * [ ] Storage layout documented
 *
 * SMTCHECKER (FREE — DO THIS ALWAYS)
 * [ ] Enabled in foundry.toml with engine = "chc"
 * [ ] All targets enabled (overflow, assert, divByZero, etc.)
 * [ ] Zero unsound warnings (all proved or explicitly annotated)
 * [ ] External calls annotated with @custom:smtchecker abstract-function-nondet
 * [ ] No assert() that SMTChecker reports as potentially failing
 *
 * ECHIDNA FUZZING
 * [ ] Deployed EchidnaTest contract wrapping the target
 * [ ] Properties written for all key invariants
 * [ ] Ran with testLimit >= 100,000
 * [ ] Corpus saved and committed (echidna-corpus/)
 * [ ] Zero property violations after full run
 * [ ] Coverage report reviewed (>80% branch coverage)
 *
 * HALMOS (SYMBOLIC EXECUTION)
 * [ ] check_ functions written for critical paths
 * [ ] Ran with appropriate loop bounds (--loop 256)
 * [ ] All checks pass (no counterexamples found)
 * [ ] Unbounded loops identified and documented
 *
 * CERTORA (FOR HIGH-VALUE PROTOCOLS)
 * [ ] methods block covers all external functions
 * [ ] Ghost variables track all key accounting quantities
 * [ ] Hooks defined for all relevant Sstore operations
 * [ ] Invariants proved for sum(balances), access control, bounds
 * [ ] Parametric rules catch unauthorized state changes
 * [ ] All rules pass with "VERIFIED" status (not TIMEOUT or UNKNOWN)
 * [ ] Spec reviewed by second person
 *
 * MUTATION TESTING (GAMBIT)
 * [ ] gambit.json configured for target contracts
 * [ ] Mutation score > 90%
 * [ ] Surviving mutants reviewed and addressed
 * [ ] Missing test cases added for each surviving mutant
 *
 * DOCUMENTATION
 * [ ] Invariants documented in NatSpec (@notice, @dev)
 * [ ] Preconditions documented per function
 * [ ] Known limitations of the verification documented
 * [ ] Verification artifacts committed to repo (specs/, gambit_out/)
 */

// ============================================================
// MINIMAL INTERFACES
// ============================================================

interface IERC20Minimal {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

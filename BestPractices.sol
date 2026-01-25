// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY BEST PRACTICES vs BAD PRACTICES - Complete Guide
// Senior Level Professional Development
// ============================================================================

// ============================================================================
// 1. NAMING CONVENTIONS & CODE STYLE
// ============================================================================

// BAD: Inconsistent naming, unclear purpose
contract bad_contract {
    uint x;
    uint Y;
    address Owner;
    mapping(address => uint) BALANCES;

    function DoSomething(uint _a) public returns (uint) {
        return _a * 2;
    }
}

// GOOD: Consistent naming, clear purpose
contract TokenVault {
    uint256 public totalSupply;
    uint256 public lastUpdateBlock;
    address public owner;
    mapping(address => uint256) public balances;

    function calculateReward(uint256 amount) public pure returns (uint256) {
        return amount * 2;
    }
}

// ============================================================================
// 2. STATE VARIABLE ORGANIZATION
// ============================================================================

// BAD: Poor organization, no grouping
contract BadOrganization {
    uint256 public balance;
    address private owner;
    uint256 public constant MAX = 100;
    mapping(address => bool) public whitelist;
    uint256 private secret;
    address public immutable token;
    bool public paused;

    constructor(address _token) {
        token = _token;
        owner = msg.sender;
    }
}

// GOOD: Logical grouping, clear sections
contract GoodOrganization {
    // Constants
    uint256 public constant MAX_SUPPLY = 100;
    uint256 public constant MIN_DEPOSIT = 1 ether;

    // Immutables
    address public immutable token;
    address public immutable factory;

    // State variables
    address public owner;
    bool public paused;

    // Storage
    uint256 public totalBalance;
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public deposits;

    constructor(address _token, address _factory) {
        token = _token;
        factory = _factory;
        owner = msg.sender;
    }
}

// ============================================================================
// 3. FUNCTION VISIBILITY & ORDERING
// ============================================================================

// BAD: Random order, unclear visibility
contract BadFunctionOrder {
    function helper() internal pure returns (uint256) {
        return 42;
    }

    constructor() {}

    function publicFunc() public {}

    receive() external payable {}

    function _internalFunc() private {}

    function externalFunc() external {}
}

// GOOD: Proper ordering (constructor → receive/fallback → external → public → internal → private)
contract GoodFunctionOrder {
    constructor() {}

    receive() external payable {}

    fallback() external payable {}

    // External functions
    function deposit() external payable {}

    function withdraw(uint256 amount) external {}

    // Public functions
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Internal functions
    function _updateState() internal {}

    // Private functions
    function _validate() private pure returns (bool) {
        return true;
    }
}

// ============================================================================
// 4. ERROR HANDLING - MODERN APPROACH
// ============================================================================

// BAD: String errors (expensive gas)
contract BadErrors {
    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(
            amount <= address(this).balance,
            "Insufficient contract balance"
        );
        require(msg.sender != address(0), "Invalid sender address");
    }
}

// GOOD: Custom errors (cheaper gas)
contract GoodErrors {
    error InvalidAmount(uint256 requested, uint256 minimum);
    error InsufficientBalance(uint256 requested, uint256 available);
    error ZeroAddress();

    function withdraw(uint256 amount) external {
        if (amount == 0) revert InvalidAmount(amount, 1);
        uint256 balance = address(this).balance;
        if (amount > balance) revert InsufficientBalance(amount, balance);
        if (msg.sender == address(0)) revert ZeroAddress();

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success);
    }
}

// ============================================================================
// 5. EVENT DESIGN
// ============================================================================

// BAD: Missing events, poor indexing
contract BadEvents {
    mapping(address => uint256) public balances;

    function transfer(address to, uint256 amount) external {
        balances[msg.sender] -= amount;
        balances[to] += amount;
        // No event emitted!
    }
}

// GOOD: Comprehensive events, proper indexing
contract GoodEvents {
    mapping(address => uint256) public balances;

    // Index important parameters (max 3)
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );
    event BalanceUpdated(address indexed account, uint256 newBalance);

    function transfer(address to, uint256 amount) external {
        balances[msg.sender] -= amount;
        balances[to] += amount;

        emit Transfer(msg.sender, to, amount, block.timestamp);
        emit BalanceUpdated(msg.sender, balances[msg.sender]);
        emit BalanceUpdated(to, balances[to]);
    }
}

// ============================================================================
// 6. CHECKS-EFFECTS-INTERACTIONS PATTERN
// ============================================================================

// BAD: External call before state update (reentrancy risk)
contract BadCEI {
    mapping(address => uint256) public balances;

    function withdraw() external {
        uint256 amount = balances[msg.sender];

        // External interaction BEFORE state change - DANGER!
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success);

        balances[msg.sender] = 0; // Too late!
    }
}

// GOOD: Follow Checks-Effects-Interactions
contract GoodCEI {
    mapping(address => uint256) public balances;

    event Withdrawal(address indexed user, uint256 amount);

    function withdraw() external {
        // 1. CHECKS
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");

        // 2. EFFECTS
        balances[msg.sender] = 0;
        emit Withdrawal(msg.sender, amount);

        // 3. INTERACTIONS
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success);
    }
}

// ============================================================================
// 7. INPUT VALIDATION
// ============================================================================

// BAD: No validation
contract BadValidation {
    address public owner;

    function setOwner(address newOwner) external {
        owner = newOwner; // Could be address(0)!
    }

    function transfer(address to, uint256 amount) external {
        // No checks!
    }
}

// GOOD: Comprehensive validation
contract GoodValidation {
    address public owner;

    error ZeroAddress();
    error InvalidAmount(uint256 amount);
    error Unauthorized(address caller);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized(msg.sender);
        _;
    }

    function setOwner(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        owner = newOwner;
    }

    function transfer(address to, uint256 amount) external {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert InvalidAmount(amount);
        // Process transfer...
    }
}

// ============================================================================
// 8. MODIFIERS - PROPER USE
// ============================================================================

// BAD: Complex logic in modifiers, multiple side effects
contract BadModifiers {
    uint256 public counter;

    modifier badModifier() {
        counter++; // Side effect in modifier!
        require(counter < 10, "Limit reached");
        _;
        counter++; // More side effects!
        // Complex calculations...
    }

    function doSomething() external badModifier {
        // Function logic
    }
}

// GOOD: Simple checks only, clear purpose
contract GoodModifiers {
    address public owner;
    bool public paused;

    error Unauthorized();
    error ContractPaused();

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    function adminFunction() external onlyOwner whenNotPaused {
        // Function logic
    }
}

// ============================================================================
// 9. RETURN VALUES
// ============================================================================

// BAD: Unused return values, no handling
contract BadReturns {
    function transfer(address token, address to, uint256 amount) external {
        // Ignoring return value is dangerous!
        IERC20(token).transfer(to, amount);
    }
}

// GOOD: Check return values, handle errors
contract GoodReturns {
    error TransferFailed();

    function transfer(address token, address to, uint256 amount) external {
        bool success = IERC20(token).transfer(to, amount);
        if (!success) revert TransferFailed();
    }

    // Or use SafeERC20
    function safeTransfer(address token, address to, uint256 amount) external {
        SafeERC20.safeTransfer(IERC20(token), to, amount);
    }
}

// ============================================================================
// 10. TIMESTAMP USAGE
// ============================================================================

// BAD: Precise timestamp comparisons (miner manipulation)
contract BadTimestamp {
    uint256 public deadline;

    function checkDeadline() external view returns (bool) {
        return block.timestamp == deadline; // Exact match - bad!
    }

    function timelock() external view {
        require(block.timestamp == deadline, "Not exact time"); // Vulnerable!
    }
}

// GOOD: Use ranges, not exact comparisons
contract GoodTimestamp {
    uint256 public constant TIMELOCK_DURATION = 2 days;
    uint256 public unlockTime;

    error TooEarly(uint256 currentTime, uint256 unlockTime);

    function setUnlockTime() external {
        unlockTime = block.timestamp + TIMELOCK_DURATION;
    }

    function withdraw() external {
        if (block.timestamp < unlockTime) {
            revert TooEarly(block.timestamp, unlockTime);
        }
        // Process withdrawal
    }
}

// ============================================================================
// 11. LOOPS & GAS LIMITS
// ============================================================================

// BAD: Unbounded loops (DoS risk)
contract BadLoops {
    address[] public users;

    function addUser(address user) external {
        users.push(user);
    }

    function payAllUsers() external {
        // Dangerous! Could run out of gas
        for (uint256 i = 0; i < users.length; i++) {
            payable(users[i]).transfer(1 ether);
        }
    }
}

// GOOD: Bounded loops or pull pattern
contract GoodLoops {
    mapping(address => uint256) public pendingPayments;
    address[] public users;
    uint256 public constant MAX_BATCH = 50;

    // Pull pattern - users withdraw themselves
    function withdraw() external {
        uint256 amount = pendingPayments[msg.sender];
        require(amount > 0, "No payment");

        pendingPayments[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    // Batch processing with limits
    function processBatch(uint256 startIndex, uint256 count) external {
        require(count <= MAX_BATCH, "Batch too large");
        uint256 end = startIndex + count;
        require(end <= users.length, "Out of bounds");

        for (uint256 i = startIndex; i < end; i++) {
            // Process user
        }
    }
}

// ============================================================================
// 12. DOCUMENTATION & NATSPEC
// ============================================================================

// BAD: No documentation
contract BadDocs {
    function calc(uint256 a, uint256 b) external pure returns (uint256) {
        return a * b + 100;
    }
}

// GOOD: Complete NatSpec documentation
contract GoodDocs {
    /// @title Reward Calculator
    /// @author Your Name
    /// @notice Calculates rewards with bonus
    /// @dev Uses fixed point math for precision

    /// @notice Calculate total reward with bonus
    /// @param baseAmount The base amount to calculate from
    /// @param multiplier The multiplier to apply
    /// @return totalReward The calculated reward including bonus
    /// @dev Reverts if multiplication overflows
    function calculateReward(
        uint256 baseAmount,
        uint256 multiplier
    ) external pure returns (uint256 totalReward) {
        totalReward = baseAmount * multiplier + 100;
    }
}

// ============================================================================
// 13. TESTING CONSIDERATIONS
// ============================================================================

// BAD: Untestable code, tightly coupled
contract BadTestability {
    function process() external {
        uint256 random = uint256(
            keccak256(abi.encodePacked(block.timestamp, msg.sender))
        );
        // Hard to test!
    }
}

// GOOD: Testable, injectable dependencies
contract GoodTestability {
    IOracle public oracle;

    constructor(address _oracle) {
        oracle = IOracle(_oracle);
    }

    function process() external view returns (uint256) {
        return oracle.getRandomNumber(); // Easy to mock!
    }

    // Allow admin to update oracle for testing
    function setOracle(address _oracle) external {
        oracle = IOracle(_oracle);
    }
}

// ============================================================================
// 14. UPGRADE SAFETY
// ============================================================================

// BAD: No upgrade path, locked forever
contract BadUpgradeability {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }
    // No way to fix bugs or add features!
}

// GOOD: Proxy pattern or planned upgrades
contract GoodUpgradeability {
    address public implementation;
    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    function upgrade(address newImplementation) external onlyAdmin {
        // Add timelock in production!
        implementation = newImplementation;
    }

    fallback() external payable {
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}

// ============================================================================
// 15. PROFESSIONAL CHECKLIST
// ============================================================================

/*
✅ Code Quality:
- [ ] Consistent naming (camelCase for functions, PascalCase for contracts)
- [ ] Proper variable ordering (constants → immutables → state)
- [ ] Function ordering (constructor → receive → external → public → internal → private)
- [ ] NatSpec documentation for all public functions
- [ ] Custom errors instead of string errors (0.8.4+)

✅ Security:
- [ ] Checks-Effects-Interactions pattern
- [ ] ReentrancyGuard on external calls
- [ ] Input validation (address(0), zero amounts, bounds)
- [ ] Access control (onlyOwner, roles)
- [ ] No timestamp manipulation risks
- [ ] Pull over push pattern for payments
- [ ] SafeERC20 for token transfers

✅ Gas Optimization:
- [ ] Pack storage variables (<32 bytes together)
- [ ] Use calldata instead of memory for external functions
- [ ] Cache storage variables in memory
- [ ] Short-circuit boolean expressions
- [ ] Batch operations when possible
- [ ] Use immutable for contract addresses
- [ ] Avoid loops over dynamic arrays

✅ Testing:
- [ ] Unit tests for all functions
- [ ] Edge case testing (zero, max, boundaries)
- [ ] Fuzz testing for complex logic
- [ ] Integration tests with other contracts
- [ ] Gas profiling and optimization
- [ ] Test coverage >90%

✅ Deployment:
- [ ] Upgrade strategy planned
- [ ] Pause mechanism for emergencies
- [ ] Event emission for all state changes
- [ ] Verified contract source on Etherscan
- [ ] Multi-sig for admin functions
- [ ] Timelock for critical changes
*/

// Helper interfaces
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IOracle {
    function getRandomNumber() external view returns (uint256);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 amount) internal {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(token.transfer.selector, to, amount)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Transfer failed"
        );
    }
}

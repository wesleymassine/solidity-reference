// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY DESIGN PATTERNS - Complete Reference
// From Zero to Professional
// ============================================================================

// ============================================================================
// 1. ACCESS CONTROL PATTERNS
// ============================================================================

// Basic Ownable Pattern
contract Ownable {
    address public owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(owner, address(0));
        owner = address(0);
    }
}

// Role-Based Access Control (RBAC)
contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private roles;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    constructor() {
        roles[ADMIN_ROLE][msg.sender] = true;
        emit RoleGranted(ADMIN_ROLE, msg.sender, msg.sender);
    }

    modifier onlyRole(bytes32 role) {
        require(hasRole(role, msg.sender), "AccessControl: unauthorized");
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return roles[role][account];
    }

    function grantRole(
        bytes32 role,
        address account
    ) public onlyRole(ADMIN_ROLE) {
        if (!hasRole(role, account)) {
            roles[role][account] = true;
            emit RoleGranted(role, account, msg.sender);
        }
    }

    function revokeRole(
        bytes32 role,
        address account
    ) public onlyRole(ADMIN_ROLE) {
        if (hasRole(role, account)) {
            roles[role][account] = false;
            emit RoleRevoked(role, account, msg.sender);
        }
    }
}

// ============================================================================
// 2. PAUSABLE PATTERN
// ============================================================================

contract Pausable is Ownable {
    bool private _paused;

    event Paused(address account);
    event Unpaused(address account);

    constructor() {
        _paused = false;
    }

    function paused() public view returns (bool) {
        return _paused;
    }

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }

    modifier whenPaused() {
        require(_paused, "Pausable: not paused");
        _;
    }

    function pause() public onlyOwner whenNotPaused {
        _paused = true;
        emit Paused(msg.sender);
    }

    function unpause() public onlyOwner whenPaused {
        _paused = false;
        emit Unpaused(msg.sender);
    }
}

// ============================================================================
// 3. REENTRANCY GUARD PATTERN
// ============================================================================

contract ReentrancyGuard {
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");

        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }

    // Example usage
    mapping(address => uint256) public balances;

    function withdraw(uint256 amount) public nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}

// ============================================================================
// 4. PULL OVER PUSH PATTERN
// ============================================================================

contract PullPayment {
    mapping(address => uint256) public payments;

    // BAD: Push pattern (vulnerable to reentrancy and DOS)
    function badDistribute(
        address[] memory recipients,
        uint256[] memory amounts
    ) external {
        for (uint256 i = 0; i < recipients.length; i++) {
            (bool success, ) = recipients[i].call{value: amounts[i]}("");
            require(success, "Transfer failed");
        }
    }

    // GOOD: Pull pattern (secure)
    function allowWithdrawal(address recipient, uint256 amount) external {
        payments[recipient] += amount;
    }

    function withdrawPayment() external {
        uint256 payment = payments[msg.sender];
        require(payment > 0, "No payment available");

        payments[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: payment}("");
        require(success, "Transfer failed");
    }
}

// ============================================================================
// 5. FACTORY PATTERN
// ============================================================================

contract ChildContract {
    address public parent;
    address public owner;
    uint256 public value;

    constructor(address _owner, uint256 _value) {
        parent = msg.sender;
        owner = _owner;
        value = _value;
    }
}

contract Factory {
    ChildContract[] public children;
    mapping(address => ChildContract[]) public userContracts;

    event ContractCreated(
        address indexed creator,
        address indexed contractAddress
    );

    function createContract(uint256 value) public returns (address) {
        ChildContract child = new ChildContract(msg.sender, value);
        children.push(child);
        userContracts[msg.sender].push(child);

        emit ContractCreated(msg.sender, address(child));
        return address(child);
    }

    function createContractWithSalt(
        uint256 value,
        bytes32 salt
    ) public returns (address) {
        ChildContract child = new ChildContract{salt: salt}(msg.sender, value);
        children.push(child);
        userContracts[msg.sender].push(child);

        emit ContractCreated(msg.sender, address(child));
        return address(child);
    }

    function getChildrenCount() public view returns (uint256) {
        return children.length;
    }

    function getUserContractsCount(address user) public view returns (uint256) {
        return userContracts[user].length;
    }
}

// ============================================================================
// 6. PROXY PATTERN (UPGRADEABLE CONTRACTS)
// ============================================================================

// Simple proxy contract
contract SimpleProxy {
    address public implementation;
    address public admin;

    constructor(address _implementation) {
        implementation = _implementation;
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin");
        _;
    }

    function upgrade(address newImplementation) external onlyAdmin {
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

    receive() external payable {}
}

// Implementation contract V1
contract ImplementationV1 {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }

    function getValue() external view returns (uint256) {
        return value;
    }
}

// Implementation contract V2 (upgraded)
contract ImplementationV2 {
    uint256 public value;

    function setValue(uint256 _value) external {
        value = _value;
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    // New functionality
    function doubleValue() external {
        value *= 2;
    }
}

// ============================================================================
// 7. STATE MACHINE PATTERN
// ============================================================================

contract StateMachine {
    enum State {
        Pending,
        Active,
        Completed,
        Cancelled
    }

    State public currentState;
    address public owner;

    event StateChanged(State indexed from, State indexed to);

    constructor() {
        owner = msg.sender;
        currentState = State.Pending;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier inState(State state) {
        require(currentState == state, "Invalid state");
        _;
    }

    function activate() public onlyOwner inState(State.Pending) {
        _transitionTo(State.Active);
    }

    function complete() public onlyOwner inState(State.Active) {
        _transitionTo(State.Completed);
    }

    function cancel() public onlyOwner {
        require(
            currentState == State.Pending || currentState == State.Active,
            "Cannot cancel"
        );
        _transitionTo(State.Cancelled);
    }

    function _transitionTo(State newState) private {
        emit StateChanged(currentState, newState);
        currentState = newState;
    }
}

// ============================================================================
// 8. ORACLE PATTERN
// ============================================================================

contract SimpleOracle {
    address public oracle;
    mapping(bytes32 => uint256) public data;

    event DataRequested(bytes32 indexed id);
    event DataReceived(bytes32 indexed id, uint256 value);

    constructor() {
        oracle = msg.sender;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "Not oracle");
        _;
    }

    function requestData(bytes32 id) external {
        emit DataRequested(id);
    }

    function fulfillData(bytes32 id, uint256 value) external onlyOracle {
        data[id] = value;
        emit DataReceived(id, value);
    }

    function getData(bytes32 id) external view returns (uint256) {
        require(data[id] != 0, "Data not available");
        return data[id];
    }
}

// ============================================================================
// 9. COMMIT-REVEAL PATTERN
// ============================================================================

contract CommitReveal {
    struct Commit {
        bytes32 commitment;
        uint256 timestamp;
        bool revealed;
        uint256 value;
    }

    mapping(address => Commit) public commits;
    uint256 public constant REVEAL_PERIOD = 1 hours;

    event Committed(address indexed user, bytes32 commitment);
    event Revealed(address indexed user, uint256 value);

    function commit(bytes32 commitment) external {
        require(
            commits[msg.sender].commitment == bytes32(0),
            "Already committed"
        );

        commits[msg.sender] = Commit({
            commitment: commitment,
            timestamp: block.timestamp,
            revealed: false,
            value: 0
        });

        emit Committed(msg.sender, commitment);
    }

    function reveal(uint256 value, bytes32 salt) external {
        Commit storage userCommit = commits[msg.sender];

        require(userCommit.commitment != bytes32(0), "No commitment");
        require(!userCommit.revealed, "Already revealed");
        require(
            block.timestamp <= userCommit.timestamp + REVEAL_PERIOD,
            "Reveal period expired"
        );

        bytes32 hash = keccak256(abi.encodePacked(value, salt));
        require(hash == userCommit.commitment, "Invalid reveal");

        userCommit.revealed = true;
        userCommit.value = value;

        emit Revealed(msg.sender, value);
    }

    function generateCommitment(
        uint256 value,
        bytes32 salt
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(value, salt));
    }
}

// ============================================================================
// 10. CHECKS-EFFECTS-INTERACTIONS PATTERN
// ============================================================================

contract ChecksEffectsInteractions {
    mapping(address => uint256) public balances;

    // BAD: Interactions before effects (vulnerable to reentrancy)
    function badWithdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // INTERACTION before EFFECT - DANGEROUS!
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        balances[msg.sender] -= amount;
    }

    // GOOD: Checks -> Effects -> Interactions
    function goodWithdraw(uint256 amount) external {
        // CHECKS: Validate conditions
        require(balances[msg.sender] >= amount, "Insufficient balance");
        require(amount > 0, "Amount must be positive");

        // EFFECTS: Update state
        balances[msg.sender] -= amount;

        // INTERACTIONS: External calls last
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}

// ============================================================================
// 11. ETERNAL STORAGE PATTERN
// ============================================================================

contract EternalStorage {
    mapping(bytes32 => uint256) uintStorage;
    mapping(bytes32 => address) addressStorage;
    mapping(bytes32 => bool) boolStorage;
    mapping(bytes32 => string) stringStorage;

    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function getUint(bytes32 key) external view returns (uint256) {
        return uintStorage[key];
    }

    function setUint(bytes32 key, uint256 value) external onlyOwner {
        uintStorage[key] = value;
    }

    function getAddress(bytes32 key) external view returns (address) {
        return addressStorage[key];
    }

    function setAddress(bytes32 key, address value) external onlyOwner {
        addressStorage[key] = value;
    }
}

// ============================================================================
// 12. EMERGENCY STOP PATTERN
// ============================================================================

contract EmergencyStop is Ownable {
    bool public stopped = false;

    event EmergencyStopActivated();
    event EmergencyStopDeactivated();

    modifier stopInEmergency() {
        require(!stopped, "Emergency stop active");
        _;
    }

    modifier onlyInEmergency() {
        require(stopped, "Not in emergency");
        _;
    }

    function emergencyStop() external onlyOwner {
        stopped = true;
        emit EmergencyStopActivated();
    }

    function resume() external onlyOwner {
        stopped = false;
        emit EmergencyStopDeactivated();
    }

    // Normal function
    function normalOperation() external stopInEmergency {
        // Business logic
    }

    // Emergency function
    function emergencyWithdraw() external onlyOwner onlyInEmergency {
        payable(owner).transfer(address(this).balance);
    }
}

// ============================================================================
// 13. RATE LIMITING PATTERN
// ============================================================================

contract RateLimiter {
    mapping(address => uint256) public lastActionTime;
    uint256 public constant COOLDOWN = 1 minutes;

    modifier rateLimit() {
        require(
            block.timestamp >= lastActionTime[msg.sender] + COOLDOWN,
            "Rate limit exceeded"
        );
        _;
        lastActionTime[msg.sender] = block.timestamp;
    }

    function limitedAction() external rateLimit {
        // Perform action
    }
}

// ============================================================================
// KEY TAKEAWAYS FOR PROFESSIONAL DEVELOPERS:
// ============================================================================
// 1. Access Control: Use Ownable for single admin, RBAC for multiple roles
// 2. Pausable: Circuit breaker for emergency situations
// 3. ReentrancyGuard: Essential for functions with external calls
// 4. Pull over Push: Safer payment distribution
// 5. Factory: Deploy multiple contracts systematically
// 6. Proxy: Enable upgradeable contracts (use with caution)
// 7. State Machine: Clear state transitions and validation
// 8. Oracle: Bridge blockchain with off-chain data
// 9. Commit-Reveal: Prevent front-running
// 10. Checks-Effects-Interactions: Always follow this order!
// 11. Eternal Storage: Separate data from logic
// 12. Emergency Stop: Circuit breaker for critical issues
// 13. Rate Limiting: Prevent spam and abuse
// 14. Combine patterns as needed for robust systems
// 15. Test patterns thoroughly before production
// ============================================================================

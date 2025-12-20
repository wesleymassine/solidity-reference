// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY SECURITY VULNERABILITIES - Complete Reference
// From Zero to Professional
// ============================================================================

// ============================================================================
// 1. REENTRANCY ATTACKS
// ============================================================================

contract ReentrancyVulnerable {
    mapping(address => uint256) public balances;

    // ❌ VULNERABLE: Reentrancy attack possible
    function vulnerableWithdraw() external {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "Insufficient balance");

        // External call BEFORE state update - DANGEROUS!
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");

        balances[msg.sender] = 0; // State updated AFTER external call
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }
}

contract ReentrancySecure {
    mapping(address => uint256) public balances;
    uint256 private locked;

    modifier noReentrant() {
        require(locked == 0, "No reentrancy");
        locked = 1;
        _;
        locked = 0;
    }

    // ✅ SECURE: Checks-Effects-Interactions pattern
    function secureWithdraw() external noReentrant {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "Insufficient balance");

        // Update state BEFORE external call
        balances[msg.sender] = 0;

        // External call AFTER state update
        (bool success, ) = msg.sender.call{value: balance}("");
        require(success, "Transfer failed");
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }
}

// Malicious contract that exploits reentrancy
contract ReentrancyAttacker {
    ReentrancyVulnerable public victim;

    constructor(address _victim) {
        victim = ReentrancyVulnerable(_victim);
    }

    function attack() external payable {
        victim.deposit{value: msg.value}();
        victim.vulnerableWithdraw();
    }

    receive() external payable {
        if (address(victim).balance >= 1 ether) {
            victim.vulnerableWithdraw();
        }
    }
}

// ============================================================================
// 2. INTEGER OVERFLOW/UNDERFLOW (Pre-0.8.0)
// ============================================================================

// Note: Solidity 0.8.0+ has built-in overflow/underflow protection
// This section demonstrates the old vulnerability

contract OverflowExample {
    // ❌ In Solidity < 0.8.0, this could overflow
    // ✅ In Solidity >= 0.8.0, this automatically reverts
    function willRevert(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b; // Reverts on overflow in 0.8.0+
    }

    // Using unchecked to bypass overflow protection (dangerous!)
    function uncheckedOverflow(
        uint256 a,
        uint256 b
    ) external pure returns (uint256) {
        unchecked {
            return a + b; // Can overflow! Use with extreme caution
        }
    }

    // ✅ SECURE: Explicit checks
    function secureAdd(uint256 a, uint256 b) external pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "Overflow detected");
        return c;
    }
}

// ============================================================================
// 3. ACCESS CONTROL VULNERABILITIES
// ============================================================================

contract AccessControlVulnerable {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    // ❌ VULNERABLE: Uses tx.origin instead of msg.sender
    function vulnerableOnlyOwner() external {
        require(tx.origin == owner, "Not owner"); // DANGEROUS!
        // If owner calls malicious contract, that contract can call this
    }

    // ❌ VULNERABLE: Missing access control
    function vulnerableSetOwner(address newOwner) external {
        owner = newOwner; // Anyone can call this!
    }
}

contract AccessControlSecure {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner"); // Use msg.sender!
        _;
    }

    // ✅ SECURE: Proper access control
    function secureSetOwner(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }
}

// ============================================================================
// 4. FRONT-RUNNING ATTACKS
// ============================================================================

contract FrontRunningVulnerable {
    uint256 public secretNumber = 42;

    // ❌ VULNERABLE: Anyone can see the answer before submitting
    function guess(uint256 number) external payable {
        require(msg.value == 1 ether, "Must send 1 ETH");

        if (number == secretNumber) {
            payable(msg.sender).transfer(address(this).balance);
        }
    }
}

contract FrontRunningSecure {
    uint256 public secretNumber = 42;
    mapping(address => bytes32) public commitments;
    mapping(address => uint256) public commitTime;

    uint256 public constant REVEAL_DELAY = 10 minutes;

    // ✅ SECURE: Commit-reveal pattern
    function commit(bytes32 commitment) external {
        commitments[msg.sender] = commitment;
        commitTime[msg.sender] = block.timestamp;
    }

    function reveal(uint256 number, bytes32 salt) external payable {
        require(msg.value == 1 ether, "Must send 1 ETH");
        require(
            block.timestamp >= commitTime[msg.sender] + REVEAL_DELAY,
            "Too early"
        );

        bytes32 commitment = keccak256(abi.encodePacked(number, salt));
        require(commitment == commitments[msg.sender], "Invalid reveal");

        if (number == secretNumber) {
            payable(msg.sender).transfer(address(this).balance);
        }

        delete commitments[msg.sender];
    }
}

// ============================================================================
// 5. DENIAL OF SERVICE (DOS) ATTACKS
// ============================================================================

contract DOSVulnerable {
    address[] public players;

    // ❌ VULNERABLE: Unbounded loop
    function distributePrizes() external {
        for (uint256 i = 0; i < players.length; i++) {
            (bool success, ) = players[i].call{value: 1 ether}("");
            require(success, "Transfer failed"); // One failure blocks all
        }
    }
}

contract DOSSecure {
    address[] public players;
    mapping(address => uint256) public pendingWithdrawals;

    // ✅ SECURE: Pull payment pattern
    function calculatePrizes() external {
        for (uint256 i = 0; i < players.length; i++) {
            pendingWithdrawals[players[i]] += 1 ether;
        }
    }

    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending withdrawal");

        pendingWithdrawals[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}

// ============================================================================
// 6. TIMESTAMP DEPENDENCE
// ============================================================================

contract TimestampVulnerable {
    // ❌ VULNERABLE: Miners can manipulate block.timestamp by ~900 seconds
    function vulnerableLottery() external view returns (bool) {
        return block.timestamp % 2 == 0;
    }

    // ❌ VULNERABLE: Using timestamp for randomness
    function vulnerableRandom() external view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp))) % 100;
    }
}

contract TimestampSecure {
    // ✅ ACCEPTABLE: Using timestamp for long periods
    uint256 public constant LOCK_PERIOD = 30 days;
    mapping(address => uint256) public lockTime;

    function lock() external {
        lockTime[msg.sender] = block.timestamp;
    }

    function canUnlock() external view returns (bool) {
        return block.timestamp >= lockTime[msg.sender] + LOCK_PERIOD;
    }

    // ✅ BETTER: Use Chainlink VRF for true randomness
    // (This is pseudocode - requires Chainlink integration)
    // function requestRandomness() external { }
}

// ============================================================================
// 7. DELEGATECALL VULNERABILITIES
// ============================================================================

contract DelegateCallVulnerable {
    address public owner;
    uint256 public value;

    // ❌ VULNERABLE: Delegatecall to user-supplied address
    function vulnerableDelegate(address target, bytes memory data) external {
        (bool success, ) = target.delegatecall(data);
        require(success, "Delegatecall failed");
    }
}

contract Exploit {
    address public owner;
    uint256 public value;

    function attack() external {
        owner = msg.sender; // This modifies the caller's storage!
    }
}

contract DelegateCallSecure {
    address public immutable trustedImplementation;
    address public owner;
    uint256 public value;

    constructor(address _implementation) {
        trustedImplementation = _implementation;
        owner = msg.sender;
    }

    // ✅ SECURE: Only delegatecall to trusted address
    function secureDelegate(bytes memory data) external {
        (bool success, ) = trustedImplementation.delegatecall(data);
        require(success, "Delegatecall failed");
    }
}

// ============================================================================
// 8. SIGNATURE REPLAY ATTACKS
// ============================================================================

contract SignatureVulnerable {
    mapping(address => uint256) public balances;

    // ❌ VULNERABLE: Signature can be reused
    function vulnerableTransfer(
        address to,
        uint256 amount,
        bytes memory signature
    ) external {
        bytes32 message = keccak256(abi.encodePacked(to, amount));
        address signer = recoverSigner(message, signature);

        require(balances[signer] >= amount, "Insufficient balance");
        balances[signer] -= amount;
        balances[to] += amount;
    }

    function recoverSigner(
        bytes32 message,
        bytes memory sig
    ) internal pure returns (address) {
        bytes32 ethSignedMessage = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );

        (bytes32 r, bytes32 s, uint8 v) = splitSignature(sig);
        return ecrecover(ethSignedMessage, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}

contract SignatureSecure {
    mapping(address => uint256) public balances;
    mapping(bytes32 => bool) public usedSignatures;
    uint256 public chainId;

    constructor() {
        chainId = block.chainid;
    }

    // ✅ SECURE: Nonce and chain ID prevent replay
    function secureTransfer(
        address to,
        uint256 amount,
        uint256 nonce,
        bytes memory signature
    ) external {
        bytes32 message = keccak256(
            abi.encodePacked(to, amount, nonce, chainId, address(this))
        );

        require(!usedSignatures[message], "Signature already used");

        address signer = recoverSigner(message, signature);
        require(balances[signer] >= amount, "Insufficient balance");

        usedSignatures[message] = true;
        balances[signer] -= amount;
        balances[to] += amount;
    }

    function recoverSigner(
        bytes32 message,
        bytes memory sig
    ) internal pure returns (address) {
        bytes32 ethSignedMessage = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );

        (bytes32 r, bytes32 s, uint8 v) = splitSignature(sig);
        return ecrecover(ethSignedMessage, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
}

// ============================================================================
// 9. UNCHECKED EXTERNAL CALLS
// ============================================================================

contract UncheckedCallVulnerable {
    // ❌ VULNERABLE: Ignoring return value
    function vulnerableSend(address payable recipient) external {
        recipient.send(1 ether); // Returns false on failure, doesn't revert
    }
}

contract UncheckedCallSecure {
    // ✅ SECURE: Check return values
    function secureSend(address payable recipient) external {
        bool success = recipient.send(1 ether);
        require(success, "Send failed");
    }

    // ✅ BETTER: Use call with proper checks
    function betterSend(address payable recipient) external {
        (bool success, ) = recipient.call{value: 1 ether}("");
        require(success, "Transfer failed");
    }
}

// ============================================================================
// 10. UNPROTECTED SELF-DESTRUCT
// ============================================================================

contract SelfDestructVulnerable {
    // ❌ VULNERABLE: Anyone can destroy the contract
    function destroy() external {
        selfdestruct(payable(msg.sender));
    }
}

contract SelfDestructSecure {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    // ✅ SECURE: Only owner can destroy
    function destroy() external {
        require(msg.sender == owner, "Not owner");
        selfdestruct(payable(owner));
    }
}

// ============================================================================
// 11. FLOATING PRAGMA
// ============================================================================

// ❌ VULNERABLE: Floating pragma
// pragma solidity ^0.8.0;

// ✅ SECURE: Fixed pragma
// pragma solidity 0.8.24;

// ============================================================================
// 12. UNINITIALIZED STORAGE POINTERS (Pre-0.5.0)
// ============================================================================

// This vulnerability is fixed in Solidity 0.5.0+, shown for educational purposes

contract UninitializedStorageExample {
    struct User {
        string name;
        uint256 balance;
    }

    User[] public users;

    // In Solidity < 0.5.0, this was dangerous
    // Now the compiler prevents uninitialized storage pointers
    function safeAddUser(string memory name, uint256 balance) external {
        User memory newUser = User(name, balance); // Must specify storage location
        users.push(newUser);
    }
}

// ============================================================================
// 13. DEFAULT VISIBILITY
// ============================================================================

contract DefaultVisibilityVulnerable {
    // ❌ VULNERABLE: In old Solidity, default visibility was public
    // Now you must explicitly specify visibility
    // This won't compile in modern Solidity without visibility
    // function dangerous() { }
}

contract DefaultVisibilitySecure {
    // ✅ SECURE: Always specify visibility
    function public_function() external pure returns (string memory) {
        return "External";
    }

    function internal_function() internal pure returns (string memory) {
        return "Internal";
    }

    function private_function() private pure returns (string memory) {
        return "Private";
    }
}

// ============================================================================
// 14. FORCEFULLY SENDING ETHER
// ============================================================================

contract ForcedEtherVulnerable {
    uint256 public totalDeposits;

    // ❌ VULNERABLE: Assumes balance == totalDeposits
    function withdraw() external {
        require(address(this).balance == totalDeposits, "Balance mismatch");
        // This check can be bypassed!
    }
}

contract ForcedEtherSecure {
    uint256 public totalDeposits;

    // ✅ SECURE: Don't rely on exact balance
    function withdraw() external {
        require(address(this).balance >= totalDeposits, "Insufficient balance");
        // Use >= instead of ==
    }
}

// Contract that forces ether
contract EtherForcer {
    constructor(address payable target) payable {
        selfdestruct(target); // Forcefully sends ether
    }
}

// ============================================================================
// 15. SHORT ADDRESS ATTACK
// ============================================================================

// This is a client-side vulnerability but worth knowing
// Occurs when client sends fewer bytes than expected
// Modern wallets and interfaces prevent this

contract ShortAddressExample {
    mapping(address => uint256) public balances;

    // ✅ SECURE: Solidity 0.8.0+ has built-in protection
    function transfer(address to, uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }
}

// ============================================================================
// KEY SECURITY TAKEAWAYS FOR PROFESSIONAL DEVELOPERS:
// ============================================================================
// 1. Reentrancy: Always use Checks-Effects-Interactions pattern
// 2. Integer Overflow: Use Solidity 0.8.0+ or SafeMath
// 3. Access Control: Use msg.sender, never tx.origin
// 4. Front-running: Use commit-reveal for sensitive operations
// 5. DOS: Avoid unbounded loops, use pull over push
// 6. Timestamp: Don't use for randomness or precise timing
// 7. Delegatecall: Only to trusted addresses, understand storage layout
// 8. Signatures: Include nonce, chain ID, contract address
// 9. External Calls: Always check return values
// 10. Self-destruct: Protect with access control
// 11. Pragma: Use fixed pragma versions
// 12. Visibility: Always specify function visibility
// 13. Balance: Don't assume exact balance
// 14. Testing: Comprehensive testing and auditing essential
// 15. Tools: Use Slither, Mythril, Echidna for security analysis
// ============================================================================

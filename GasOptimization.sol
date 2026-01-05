// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY GAS OPTIMIZATION - Complete Reference
// From Zero to Professional
// ============================================================================

// ============================================================================
// 1. STORAGE OPTIMIZATION
// ============================================================================

contract StorageOptimization {
    // ❌ EXPENSIVE: Each variable uses full storage slot (32 bytes)
    struct BadStruct {
        uint8 a; // Uses slot 0 (wastes 31 bytes)
        uint256 b; // Uses slot 1
        uint8 c; // Uses slot 2 (wastes 31 bytes)
        uint256 d; // Uses slot 3
    }

    // ✅ OPTIMIZED: Pack variables together
    struct GoodStruct {
        uint8 a; // Packed in slot 0
        uint8 c; // Packed in slot 0
        uint256 b; // Uses slot 1
        uint256 d; // Uses slot 2
    }

    // Storage packing example
    uint128 public packed1 = 100; // Shares slot with packed2
    uint128 public packed2 = 200; // Shares slot with packed1

    uint256 public notPacked = 300; // Uses separate slot

    // ✅ BEST: Pack multiple small variables in single slot
    struct OptimalStruct {
        uint32 timestamp; // All fit in one slot!
        uint32 amount;
        uint64 id;
        uint128 value;
    }
}

// ============================================================================
// 2. VARIABLE TYPES OPTIMIZATION
// ============================================================================

contract VariableTypesOptimization {
    // ❌ EXPENSIVE: Using uint256 when smaller types work
    function badLoop() external pure returns (uint256 sum) {
        for (uint256 i = 0; i < 100; i++) {
            sum += i;
        }
    }

    // ✅ CHEAPER: uint256 is actually cheaper for locals (no packing overhead)
    // Note: uint256 is cheapest for calculations despite being larger
    function goodLoop() external pure returns (uint256 sum) {
        for (uint256 i = 0; i < 100; i++) {
            sum += i;
        }
    }

    // Gas tip: uint256 for local variables, pack storage variables
}

// ============================================================================
// 3. CALLDATA VS MEMORY
// ============================================================================

contract CalldataVsMemory {
    // ❌ EXPENSIVE: Memory copies data
    function expensiveSum(
        uint256[] memory arr
    ) external pure returns (uint256 sum) {
        for (uint256 i = 0; i < arr.length; i++) {
            sum += arr[i];
        }
    }

    // ✅ CHEAPER: Calldata is read-only and doesn't copy
    function cheapSum(
        uint256[] calldata arr
    ) external pure returns (uint256 sum) {
        for (uint256 i = 0; i < arr.length; i++) {
            sum += arr[i];
        }
    }

    // Savings: ~3000 gas for 100-element array
}

// ============================================================================
// 4. SHORT CIRCUIT EVALUATION
// ============================================================================

contract ShortCircuit {
    uint256 public expensiveValue = 1000;

    // ❌ EXPENSIVE: Calls expensive function even when not needed
    function badCheck(bool condition) external view returns (bool) {
        return isExpensive() && condition; // Always calls isExpensive()
    }

    // ✅ CHEAPER: Short circuits if condition is false
    function goodCheck(bool condition) external view returns (bool) {
        return condition && isExpensive(); // Only calls if condition is true
    }

    function isExpensive() internal view returns (bool) {
        return expensiveValue > 500;
    }
}

// ============================================================================
// 5. CACHING STORAGE VARIABLES
// ============================================================================

contract CachingOptimization {
    uint256[] public data;

    // ❌ EXPENSIVE: Multiple SLOAD operations
    function badSum() external view returns (uint256 sum) {
        for (uint256 i = 0; i < data.length; i++) {
            sum += data[i]; // SLOAD every iteration
        }
    }

    // ✅ CHEAPER: Cache in memory
    function goodSum() external view returns (uint256 sum) {
        uint256[] memory cachedData = data; // One-time SLOAD
        uint256 len = cachedData.length;

        for (uint256 i = 0; i < len; i++) {
            sum += cachedData[i]; // MLOAD (cheaper)
        }
    }

    // ✅ OPTIMAL: Cache length separately
    function optimalSum() external view returns (uint256 sum) {
        uint256 len = data.length; // Cache length

        for (uint256 i = 0; i < len; i++) {
            sum += data[i];
        }
    }
}

// ============================================================================
// 6. CUSTOM ERRORS
// ============================================================================

contract CustomErrorsOptimization {
    // ❌ EXPENSIVE: String errors are costly
    function badRequire(uint256 x) external pure {
        require(x > 10, "Value must be greater than 10"); // ~50 gas per character
    }

    error TooSmall(uint256 value, uint256 minimum);

    // ✅ CHEAPER: Custom errors save gas
    function goodRevert(uint256 x) external pure {
        if (x <= 10) {
            revert TooSmall(x, 10); // Much cheaper!
        }
    }

    // Savings: ~2000 gas
}

// ============================================================================
// 7. FUNCTION VISIBILITY
// ============================================================================

contract VisibilityOptimization {
    // ❌ EXPENSIVE: Public functions cost more
    function publicFunction(uint256 x) public pure returns (uint256) {
        return x * 2;
    }

    // ✅ CHEAPER: External is cheaper for large data
    function externalFunction(uint256 x) external pure returns (uint256) {
        return x * 2;
    }

    // ✅ CHEAPEST: Private/internal for internal use
    function internalFunction(uint256 x) internal pure returns (uint256) {
        return x * 2;
    }
}

// ============================================================================
// 8. LOOP OPTIMIZATIONS
// ============================================================================

contract LoopOptimization {
    uint256[] public array;

    // ❌ EXPENSIVE: Reading length every iteration
    function badLoop() external view returns (uint256 sum) {
        for (uint256 i = 0; i < array.length; i++) {
            sum += array[i];
        }
    }

    // ✅ CHEAPER: Cache length
    function goodLoop() external view returns (uint256 sum) {
        uint256 len = array.length;
        for (uint256 i = 0; i < len; i++) {
            sum += array[i];
        }
    }

    // ✅ BETTER: Unchecked increment (Solidity 0.8.0+)
    function betterLoop() external view returns (uint256 sum) {
        uint256 len = array.length;
        for (uint256 i = 0; i < len; ) {
            sum += array[i];
            unchecked {
                ++i;
            } // Saves ~40 gas per iteration
        }
    }

    // ✅ OPTIMAL: ++i instead of i++
    function optimalLoop() external view returns (uint256 sum) {
        uint256 len = array.length;
        for (uint256 i = 0; i < len; ) {
            sum += array[i];
            unchecked {
                ++i;
            } // ++i cheaper than i++
        }
    }
}

// ============================================================================
// 9. BATCH OPERATIONS
// ============================================================================

contract BatchOptimization {
    mapping(address => uint256) public balances;

    // ❌ EXPENSIVE: Multiple transactions
    function singleTransfer(address to, uint256 amount) external {
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }

    // ✅ CHEAPER: Batch in one transaction
    function batchTransfer(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external {
        require(recipients.length == amounts.length, "Length mismatch");

        uint256 total;
        uint256 len = recipients.length;

        for (uint256 i = 0; i < len; ) {
            total += amounts[i];
            unchecked {
                ++i;
            }
        }

        balances[msg.sender] -= total;

        for (uint256 i = 0; i < len; ) {
            balances[recipients[i]] += amounts[i];
            unchecked {
                ++i;
            }
        }
    }
}

// ============================================================================
// 10. IMMUTABLE AND CONSTANT
// ============================================================================

contract ImmutableConstantOptimization {
    // ❌ EXPENSIVE: Regular storage variable
    address public owner1;

    // ✅ CHEAPER: Immutable (set in constructor)
    address public immutable owner2;

    // ✅ CHEAPEST: Constant (compile-time)
    uint256 public constant MAX_SUPPLY = 1_000_000;

    constructor() {
        owner1 = msg.sender; // SSTORE (20,000 gas)
        owner2 = msg.sender; // Embedded in bytecode
    }

    // Reading owner2 is much cheaper than owner1
}

// ============================================================================
// 11. BITMAP OPTIMIZATION
// ============================================================================

contract BitmapOptimization {
    // ❌ EXPENSIVE: Using mapping for boolean flags
    mapping(uint256 => bool) public badFlags;

    // ✅ CHEAPER: Using bitmap
    uint256 public goodFlags;

    function setBadFlag(uint256 index) external {
        badFlags[index] = true; // 20,000 gas for new entry
    }

    function setGoodFlag(uint256 index) external {
        require(index < 256, "Index out of bounds");
        goodFlags |= (1 << index); // Much cheaper!
    }

    function getGoodFlag(uint256 index) external view returns (bool) {
        return (goodFlags & (1 << index)) != 0;
    }
}

// ============================================================================
// 12. FUNCTION ORDERING
// ============================================================================

contract FunctionOrdering {
    // Functions are dispatched based on selector (first 4 bytes of keccak256)
    // Most called functions should have lower selector values

    // ✅ OPTIMIZED: Prefix function names to control selector
    // Use: https://emn178.github.io/online-tools/keccak_256.html

    function execute_30() external pure returns (string memory) {
        // Low selector
        return "Most called";
    }

    function process_89() external pure returns (string memory) {
        return "Medium called";
    }

    function handle_FF() external pure returns (string memory) {
        // High selector
        return "Rarely called";
    }
}

// ============================================================================
// 13. DELETE VARIABLES
// ============================================================================

contract DeleteOptimization {
    mapping(address => uint256) public balances;

    // ✅ OPTIMIZED: Delete refunds gas
    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");

        delete balances[msg.sender]; // Refunds gas!

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}

// ============================================================================
// 14. PAYABLE FUNCTIONS
// ============================================================================

contract PayableOptimization {
    address public owner;

    // ❌ EXPENSIVE: Non-payable check adds gas
    function badOwnerFunction() external {
        require(msg.sender == owner, "Not owner");
    }

    // ✅ CHEAPER: Payable removes check (only if appropriate!)
    function goodOwnerFunction() external payable {
        require(msg.sender == owner, "Not owner");
        // Be careful: function can now receive ETH
    }

    // Savings: ~24 gas per call
}

// ============================================================================
// 15. MERKLE PROOFS FOR WHITELISTS
// ============================================================================

contract MerkleOptimization {
    // ❌ EXPENSIVE: Storing all whitelist addresses
    mapping(address => bool) public badWhitelist;

    function addToBadWhitelist(address[] calldata addresses) external {
        for (uint256 i = 0; i < addresses.length; i++) {
            badWhitelist[addresses[i]] = true; // 20k gas each!
        }
    }

    // ✅ CHEAPER: Using Merkle root
    bytes32 public merkleRoot;

    function setMerkleRoot(bytes32 root) external {
        merkleRoot = root; // Single storage write!
    }

    function verifyProof(
        bytes32[] calldata proof,
        bytes32 leaf
    ) external view returns (bool) {
        bytes32 computedHash = leaf;

        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];

            if (computedHash <= proofElement) {
                computedHash = keccak256(
                    abi.encodePacked(computedHash, proofElement)
                );
            } else {
                computedHash = keccak256(
                    abi.encodePacked(proofElement, computedHash)
                );
            }
        }

        return computedHash == merkleRoot;
    }
}

// ============================================================================
// 16. ASSEMBLY OPTIMIZATIONS
// ============================================================================

contract AssemblyOptimization {
    // ❌ EXPENSIVE: Solidity operations
    function addSolidity(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }

    // ✅ CHEAPER: Assembly operations
    function addAssembly(
        uint256 a,
        uint256 b
    ) external pure returns (uint256 result) {
        assembly {
            result := add(a, b)
        }
    }

    // Efficient hash
    function efficientHash(
        uint256 a,
        uint256 b
    ) external pure returns (bytes32 hash) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            hash := keccak256(0x00, 0x40)
        }
    }
}

// ============================================================================
// 17. AVOID COPYING STORAGE TO MEMORY
// ============================================================================

contract MemoryCopyOptimization {
    struct User {
        string name;
        uint256 balance;
        uint256 score;
    }

    mapping(address => User) public users;

    // ❌ EXPENSIVE: Copies entire struct to memory
    function badGetBalance(address addr) external view returns (uint256) {
        User memory user = users[addr]; // Full copy!
        return user.balance;
    }

    // ✅ CHEAPER: Access storage directly
    function goodGetBalance(address addr) external view returns (uint256) {
        return users[addr].balance; // Direct access
    }
}

// ============================================================================
// 18. FREE MEMORY POINTER
// ============================================================================

contract FreeMemoryPointer {
    // Understanding memory allocation for gas optimization

    function demonstrateMemory() external pure returns (uint256 fmp) {
        assembly {
            // Free memory pointer is at 0x40
            fmp := mload(0x40)
        }
    }
}

// ============================================================================
// 19. GAS PROFILING EXAMPLE
// ============================================================================

contract GasProfiler {
    event GasUsed(string indexed operation, uint256 gasUsed);

    function profileOperation() external {
        uint256 startGas = gasleft();

        // Your operation here
        uint256 result = 0;
        for (uint256 i = 0; i < 100; i++) {
            result += i;
        }

        uint256 gasUsed = startGas - gasleft();
        emit GasUsed("loop", gasUsed);
    }
}

// ============================================================================
// KEY GAS OPTIMIZATION TAKEAWAYS FOR PROFESSIONAL DEVELOPERS:
// ============================================================================
// 1. Storage: Pack variables, use uint256 for calculations
// 2. Calldata: Use calldata instead of memory for external functions
// 3. Caching: Cache storage variables in memory/stack
// 4. Errors: Use custom errors instead of string messages
// 5. Loops: Cache length, use unchecked, prefer ++i
// 6. Batch: Combine operations in single transaction
// 7. Immutable: Use immutable/constant when possible
// 8. Delete: Delete variables to get gas refunds
// 9. Payable: Add payable to trusted functions (carefully!)
// 10. Merkle: Use Merkle trees for large whitelists
// 11. Assembly: Use for critical optimizations
// 12. Memory: Avoid unnecessary copying
// 13. Short-circuit: Order conditions properly
// 14. Visibility: Use appropriate function visibility
// 15. Measure: Always profile before/after optimization
// ============================================================================

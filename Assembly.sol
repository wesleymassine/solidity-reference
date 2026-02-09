// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY INLINE ASSEMBLY (YUL) - Complete Reference
// From Zero to Professional
// ============================================================================

contract Assembly {
    // ============================================================================
    // 1. INTRODUCTION TO INLINE ASSEMBLY
    // ============================================================================
    // Inline assembly allows low-level access to the EVM1
    // Uses Yul language (intermediate language for Ethereum)
    // Benefits: Gas optimization, low-level operations
    // Risks: Bypasses Solidity's safety checks, harder to audit

    // Basic assembly block
    function basicAssembly() public pure returns (uint256 result) {
        assembly {
            // Assembly code goes here
            result := 42
        }
    }

    // ============================================================================
    // 2. YUL BASICS
    // ============================================================================
    // Variables: let x := 5
    // Assignment: x := 10
    // Comments: // or /* */
    // No type system: everything is 256-bit

    function yulBasics() public pure returns (uint256 a, uint256 b, uint256 c) {
        assembly {
            // Declare variables with 'let'
            let x := 10
            let y := 20

            // Arithmetic operations
            a := add(x, y) // 30
            b := mul(x, y) // 200
            c := sub(b, a) // 170
        }
    }

    // ============================================================================
    // 3. ARITHMETIC OPERATIONS
    // ============================================================================

    function arithmeticOperations(
        uint256 x,
        uint256 y
    )
        public
        pure
        returns (
            uint256 addition,
            uint256 subtraction,
            uint256 multiplication,
            uint256 division,
            uint256 modulo,
            uint256 exponent
        )
    {
        assembly {
            addition := add(x, y) // x + y
            subtraction := sub(x, y) // x - y
            multiplication := mul(x, y) // x * y
            division := div(x, y) // x / y (integer division)
            modulo := mod(x, y) // x % y
            exponent := exp(x, y) // x ** y
        }
    }

    // Signed arithmetic
    function signedArithmetic(
        int256 x,
        int256 y
    )
        public
        pure
        returns (
            int256 addition,
            int256 multiplication,
            int256 division,
            int256 modulo
        )
    {
        assembly {
            addition := add(x, y) // Same as unsigned
            multiplication := mul(x, y) // Same as unsigned
            division := sdiv(x, y) // SIGNED division
            modulo := smod(x, y) // SIGNED modulo
        }
    }

    // ============================================================================
    // 4. COMPARISON AND LOGICAL OPERATIONS
    // ============================================================================

    function comparisonOperations(
        uint256 x,
        uint256 y
    )
        public
        pure
        returns (bool lessThan, bool greaterThan, bool equal, bool isZero)
    {
        assembly {
            lessThan := lt(x, y) // x < y (1 if true, 0 if false)
            greaterThan := gt(x, y) // x > y
            equal := eq(x, y) // x == y
            isZero := iszero(x) // x == 0
        }
    }

    function logicalOperations(
        uint256 a,
        uint256 b
    )
        public
        pure
        returns (
            uint256 andResult,
            uint256 orResult,
            uint256 xorResult,
            uint256 notResult
        )
    {
        assembly {
            andResult := and(a, b) // Bitwise AND
            orResult := or(a, b) // Bitwise OR
            xorResult := xor(a, b) // Bitwise XOR
            notResult := not(a) // Bitwise NOT
        }
    }

    // ============================================================================
    // 5. BIT OPERATIONS
    // ============================================================================

    function bitOperations(
        uint256 x
    )
        public
        pure
        returns (
            uint256 leftShift,
            uint256 rightShift,
            uint256 signedRightShift,
            uint256 byte0
        )
    {
        assembly {
            leftShift := shl(2, x) // x << 2
            rightShift := shr(2, x) // x >> 2 (logical shift)
            signedRightShift := sar(2, x) // x >> 2 (arithmetic shift)
            byte0 := byte(0, x) // Get byte at position 0
        }
    }

    // ============================================================================
    // 6. MEMORY OPERATIONS
    // ============================================================================
    // Memory is a byte array that expands as needed
    // Memory offsets: 0x00-0x3f (64 bytes) reserved as scratch space
    // Memory offsets: 0x40-0x5f free memory pointer
    // Memory offsets: 0x60-0x7f zero slot (never used)

    function memoryOperations() public pure returns (uint256 result) {
        assembly {
            // Store value at memory position 0x80
            mstore(0x80, 42)

            // Load value from memory position 0x80
            result := mload(0x80)

            // Store byte at memory position
            mstore8(0x80, 0xff)

            // Get free memory pointer (points to next free memory slot)
            let freeMemPtr := mload(0x40)
        }
    }

    // Memory copy
    function memoryCopy(bytes memory data) public view returns (bytes memory) {
        bytes memory result = new bytes(data.length);

        assembly {
            // Get length
            let len := mload(data)

            // Copy from data to result
            // add(data, 32) skips length prefix
            // add(result, 32) skips length prefix
            // Copy 'len' bytes
            let success := staticcall(
                gas(),
                0x04, // identity precompile
                add(data, 32),
                len,
                add(result, 32),
                len
            )
        }

        return result;
    }

    // ============================================================================
    // 7. STORAGE OPERATIONS
    // ============================================================================
    // Storage is persistent key-value store
    // Each slot is 32 bytes

    uint256 public storageVar = 100;

    function storageOperations() public returns (uint256 value) {
        assembly {
            // Load from storage slot 0
            value := sload(0)

            // Store to storage slot 0
            sstore(0, 200)
        }
    }

    // Calculate storage slot for mapping
    function getMappingSlot(
        address key,
        uint256 mappingSlot
    ) public pure returns (bytes32) {
        bytes32 slot;
        assembly {
            // Store key at memory position 0
            mstore(0, key)
            // Store mapping slot at memory position 32
            mstore(32, mappingSlot)
            // Hash to get storage slot
            slot := keccak256(0, 64)
        }
        return slot;
    }

    // ============================================================================
    // 8. CONTROL FLOW
    // ============================================================================

    function controlFlow(uint256 x) public pure returns (uint256 result) {
        assembly {
            // If-else using jumps (old style, not recommended)
            // Modern Yul uses if/switch

            // If statement
            if gt(x, 10) {
                result := 1
            }

            // If-else
            if lt(x, 5) {
                result := 2
            }
            if iszero(lt(x, 5)) {
                result := 3
            }

            // Switch statement
            switch x
            case 0 {
                result := 100
            }
            case 1 {
                result := 200
            }
            default {
                result := 300
            }
        }
    }

    // Loops
    function loopsInAssembly(uint256 n) public pure returns (uint256 sum) {
        assembly {
            // For loop equivalent
            for {
                let i := 0
            } lt(i, n) {
                i := add(i, 1)
            } {
                sum := add(sum, i)
            }
        }
    }

    // ============================================================================
    // 9. FUNCTION CALLS
    // ============================================================================

    // Internal function calls in assembly
    function assemblyFunctionCalls() public pure returns (uint256) {
        assembly {
            // Define internal assembly function
            function double(x) -> result {
                result := mul(x, 2)
            }

            function triple(x) -> result {
                result := mul(x, 3)
            }

            // Call assembly functions
            let a := double(5) // 10
            let b := triple(a) // 30

            mstore(0x80, b)
        }

        uint256 result;
        assembly {
            result := mload(0x80)
        }
        return result;
    }

    // ============================================================================
    // 10. EXTERNAL CALLS
    // ============================================================================

    // call: Execute code in another contract
    function assemblyCall(
        address target,
        bytes memory data
    ) public returns (bool success, bytes memory returnData) {
        assembly {
            // Allocate memory for return data
            let ptr := mload(0x40)

            // call(gas, address, value, inputOffset, inputSize, outputOffset, outputSize)
            success := call(
                gas(), // Forward all gas
                target, // Target address
                0, // No value sent
                add(data, 32), // Input data (skip length prefix)
                mload(data), // Input size
                0, // Output written to memory at 0
                0 // We don't know output size yet
            )

            // Get return data size
            let size := returndatasize()

            // Allocate memory for return data
            returnData := mload(0x40)
            mstore(returnData, size)
            mstore(0x40, add(returnData, add(size, 32)))

            // Copy return data
            returndatacopy(add(returnData, 32), 0, size)
        }
    }

    // delegatecall: Execute code in context of current contract
    function assemblyDelegateCall(
        address target,
        bytes memory data
    ) public returns (bool success) {
        assembly {
            success := delegatecall(
                gas(),
                target,
                add(data, 32),
                mload(data),
                0,
                0
            )
        }
    }

    // staticcall: Read-only call (no state changes)
    function assemblyStaticCall(
        address target,
        bytes memory data
    ) public view returns (bool success) {
        assembly {
            success := staticcall(
                gas(),
                target,
                add(data, 32),
                mload(data),
                0,
                0
            )
        }
    }

    // ============================================================================
    // 11. CREATE AND CREATE2
    // ============================================================================

    // Deploy contract with CREATE
    function deployWithCreate(
        bytes memory bytecode
    ) public returns (address addr) {
        assembly {
            // create(value, offset, size)
            addr := create(
                0, // No value sent
                add(bytecode, 32), // Bytecode location (skip length)
                mload(bytecode) // Bytecode size
            )

            // Check if deployment failed
            if iszero(addr) {
                revert(0, 0)
            }
        }
    }

    // Deploy contract with CREATE2 (deterministic address)
    function deployWithCreate2(
        bytes memory bytecode,
        bytes32 salt
    ) public returns (address addr) {
        assembly {
            // create2(value, offset, size, salt)
            addr := create2(0, add(bytecode, 32), mload(bytecode), salt)

            if iszero(addr) {
                revert(0, 0)
            }
        }
    }

    // Calculate CREATE2 address
    function getCreate2Address(
        bytes32 salt,
        bytes32 bytecodeHash
    ) public view returns (address) {
        bytes32 hash;
        assembly {
            // Store 0xff
            mstore(0, 0xff)
            // Store address(this)
            mstore(1, shl(96, address()))
            // Store salt
            mstore(21, salt)
            // Store bytecode hash
            mstore(53, bytecodeHash)
            // Hash and convert to address
            hash := keccak256(0, 85)
        }
        return address(uint160(uint256(hash)));
    }

    // ============================================================================
    // 12. BLOCK AND TRANSACTION INFO
    // ============================================================================

    function blockInfo()
        public
        view
        returns (
            uint256 blockNumber,
            uint256 blockTimestamp,
            uint256 gasLimit,
            uint256 difficulty,
            address coinbaseAddr
        )
    {
        assembly {
            blockNumber := number()
            blockTimestamp := timestamp()
            gasLimit := gaslimit()
            difficulty := prevrandao() // Was difficulty() pre-merge
            coinbaseAddr := coinbase()
        }
    }

    function transactionInfo()
        public
        view
        returns (address txOrigin, uint256 gasPrice, uint256 gasLeft)
    {
        assembly {
            txOrigin := origin()
            gasPrice := gasprice()
            gasLeft := gas()
        }
    }

    function messageInfo()
        public
        payable
        returns (address sender, uint256 value, bytes32 dataHash)
    {
        assembly {
            sender := caller()
            value := callvalue()

            // Hash calldata
            dataHash := keccak256(0, calldatasize())
        }
    }

    // ============================================================================
    // 13. CALLDATA OPERATIONS
    // ============================================================================

    function calldataOperations()
        public
        pure
        returns (uint256 size, bytes4 selector)
    {
        assembly {
            // Get calldata size
            size := calldatasize()

            // Get function selector (first 4 bytes)
            selector := calldataload(0)

            // Copy calldata to memory
            calldatacopy(0x80, 0, size)
        }
    }

    // ============================================================================
    // 14. RETURN DATA OPERATIONS
    // ============================================================================

    function returnExample(uint256 x) public pure returns (uint256) {
        assembly {
            // Store return value in memory
            mstore(0x80, mul(x, 2))

            // Return 32 bytes from position 0x80
            return(0x80, 32)
        }
    }

    function revertExample(string memory reason) public pure {
        assembly {
            // Get free memory pointer
            let ptr := mload(0x40)

            // Store Error(string) selector
            mstore(
                ptr,
                0x08c379a000000000000000000000000000000000000000000000000000000000
            )

            // Store offset to string
            mstore(add(ptr, 4), 32)

            // Store string length
            let len := mload(reason)
            mstore(add(ptr, 36), len)

            // Copy string data
            let dataPtr := add(reason, 32)
            let destPtr := add(ptr, 68)

            for {
                let i := 0
            } lt(i, len) {
                i := add(i, 32)
            } {
                mstore(add(destPtr, i), mload(add(dataPtr, i)))
            }

            // Revert with error message
            revert(ptr, add(68, len))
        }
    }

    // ============================================================================
    // 15. GAS OPTIMIZATION EXAMPLES
    // ============================================================================

    // Optimized addition (saves ~3 gas)
    function optimizedAdd(
        uint256 a,
        uint256 b
    ) public pure returns (uint256 result) {
        assembly {
            result := add(a, b)
        }
    }

    // Efficient array sum
    function efficientArraySum(
        uint256[] memory arr
    ) public pure returns (uint256 sum) {
        assembly {
            let len := mload(arr)
            let data := add(arr, 32)

            for {
                let i := 0
            } lt(i, len) {
                i := add(i, 1)
            } {
                sum := add(sum, mload(add(data, mul(i, 32))))
            }
        }
    }

    // Pack and unpack values (save storage)
    function packValues(
        uint128 a,
        uint128 b
    ) public pure returns (uint256 packed) {
        assembly {
            packed := or(shl(128, a), b)
        }
    }

    function unpackValues(
        uint256 packed
    ) public pure returns (uint128 a, uint128 b) {
        assembly {
            a := shr(128, packed)
            b := and(packed, 0xffffffffffffffffffffffffffffffff)
        }
    }

    // ============================================================================
    // 16. ADVANCED: MEMORY LAYOUT
    // ============================================================================

    function memoryLayout()
        public
        pure
        returns (uint256 scratchSpace, uint256 freeMemPtr, uint256 zeroSlot)
    {
        assembly {
            // 0x00-0x3f: Scratch space (can be used between statements)
            scratchSpace := 0x00

            // 0x40-0x5f: Free memory pointer
            freeMemPtr := mload(0x40)

            // 0x60-0x7f: Zero slot (always zero)
            zeroSlot := 0x60
        }
    }

    // ============================================================================
    // 17. SECURITY CONSIDERATIONS
    // ============================================================================

    // ⚠️ Assembly bypasses Solidity safety checks
    // - No overflow/underflow protection
    // - No bounds checking
    // - Direct memory/storage access
    // - Easy to introduce vulnerabilities

    // Example: Overflow in assembly (no protection)
    function unsafeOverflow(uint256 x) public pure returns (uint256) {
        assembly {
            // This can overflow without reverting!
            x := add(x, 1)
        }
        return x;
    }

    // ============================================================================
    // 18. PRACTICAL EXAMPLES
    // ============================================================================

    // Efficient keccak256 for two uint256 values
    function efficientHash(
        uint256 a,
        uint256 b
    ) public pure returns (bytes32 hash) {
        assembly {
            mstore(0, a)
            mstore(32, b)
            hash := keccak256(0, 64)
        }
    }

    // Get contract code
    function getCode(address addr) public view returns (bytes memory code) {
        assembly {
            let size := extcodesize(addr)
            code := mload(0x40)
            mstore(code, size)
            extcodecopy(addr, add(code, 32), 0, size)
            mstore(0x40, add(code, add(size, 32)))
        }
    }

    // ============================================================================
    // KEY TAKEAWAYS FOR PROFESSIONAL DEVELOPERS:
    // ============================================================================
    // 1. Assembly provides gas optimization and low-level control
    // 2. Use sparingly - only when necessary for optimization
    // 3. Yul has no type system - everything is 256-bit
    // 4. Memory: 0x00-0x3f scratch, 0x40-0x5f free ptr, 0x60+ safe
    // 5. Storage operations: sload/sstore are expensive
    // 6. call/delegatecall/staticcall for external interactions
    // 7. create/create2 for contract deployment
    // 8. Assembly bypasses safety checks - be extremely careful!
    // 9. Always audit assembly code thoroughly
    // 10. Document assembly code extensively
    // 11. Test assembly code rigorously
    // 12. Consider readability vs optimization tradeoff
    // 13. Use assembly for: gas optimization, low-level ops, specific EVM features
    // 14. Avoid assembly for: business logic, complex operations
    // 15. Memory is cheaper than storage
    // ============================================================================
}

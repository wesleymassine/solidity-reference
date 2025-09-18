// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY OPERATORS - Complete Reference
// From Zero to Professional
// ============================================================================

contract Operators {
    // ============================================================================
    // 1. ARITHMETIC OPERATORS
    // ============================================================================
    // Basic mathematical operations
    // Solidity 0.8.0+ has built-in overflow/underflow protection

    function arithmeticOperators(
        uint256 a,
        uint256 b
    )
        public
        pure
        returns (
            uint256 addition,
            uint256 subtraction,
            uint256 multiplication,
            uint256 division,
            uint256 modulo,
            uint256 exponentiation
        )
    {
        addition = a + b; // Addition
        subtraction = a - b; // Subtraction (will revert if a < b in uint)
        multiplication = a * b; // Multiplication
        division = a / b; // Division (will revert if b == 0)
        modulo = a % b; // Modulo/Remainder (will revert if b == 0)
        exponentiation = a ** b; // Exponentiation (a to the power of b)

        return (
            addition,
            subtraction,
            multiplication,
            division,
            modulo,
            exponentiation
        );
    }

    // Integer division (rounds down)
    function integerDivision() public pure returns (uint256, uint256, uint256) {
        return (
            uint256(7) / 2, // 3 (not 3.5)
            uint256(10) / 3, // 3
            uint256(5) / 10 // 0
        );
    }

    // Modulo examples
    function moduloExamples() public pure returns (uint256, uint256, uint256) {
        return (
            10 % 3, // 1
            17 % 5, // 2
            20 % 4 // 0
        );
    }

    // Exponentiation
    function exponentiationExamples()
        public
        pure
        returns (uint256, uint256, uint256)
    {
        return (
            2 ** 3, // 8
            10 ** 2, // 100
            5 ** 0 // 1
        );
    }

    // Negative numbers with signed integers
    function signedArithmetic(
        int256 a,
        int256 b
    )
        public
        pure
        returns (
            int256 addition,
            int256 subtraction,
            int256 multiplication,
            int256 division
        )
    {
        addition = a + b;
        subtraction = a - b;
        multiplication = a * b;
        division = a / b;

        return (addition, subtraction, multiplication, division);
    }

    // ============================================================================
    // 2. COMPARISON OPERATORS
    // ============================================================================
    // Compare values and return boolean results

    function comparisonOperators(
        uint256 a,
        uint256 b
    )
        public
        pure
        returns (
            bool equal,
            bool notEqual,
            bool lessThan,
            bool lessOrEqual,
            bool greaterThan,
            bool greaterOrEqual
        )
    {
        equal = (a == b); // Equal to
        notEqual = (a != b); // Not equal to
        lessThan = (a < b); // Less than
        lessOrEqual = (a <= b); // Less than or equal to
        greaterThan = (a > b); // Greater than
        greaterOrEqual = (a >= b); // Greater than or equal to

        return (
            equal,
            notEqual,
            lessThan,
            lessOrEqual,
            greaterThan,
            greaterOrEqual
        );
    }

    // Comparing addresses
    function compareAddresses(
        address addr1,
        address addr2
    ) public pure returns (bool, bool) {
        return (addr1 == addr2, addr1 != addr2);
    }

    // Comparing strings (must use keccak256)
    function compareStrings(
        string memory str1,
        string memory str2
    ) public pure returns (bool) {
        return keccak256(bytes(str1)) == keccak256(bytes(str2));
    }

    // ============================================================================
    // 3. LOGICAL OPERATORS
    // ============================================================================
    // Boolean logic operations
    // Use short-circuit evaluation for gas optimization

    function logicalOperators(
        bool a,
        bool b
    ) public pure returns (bool andResult, bool orResult, bool notResult) {
        andResult = a && b; // Logical AND (both must be true)
        orResult = a || b; // Logical OR (at least one must be true)
        notResult = !a; // Logical NOT (negation)

        return (andResult, orResult, notResult);
    }

    // Short-circuit evaluation
    function shortCircuitExample(uint256 x) public pure returns (bool) {
        // If x == 0, second condition is NOT evaluated (saves gas)
        return x == 0 || x > 10;
    }

    // Complex logical expressions
    function complexLogic(
        uint256 x,
        uint256 y,
        bool flag
    ) public pure returns (bool) {
        return (x > 0 && y > 0) || (flag && x == y);
    }

    // ============================================================================
    // 4. BITWISE OPERATORS
    // ============================================================================
    // Operations on individual bits
    // Very gas-efficient for certain operations

    function bitwiseOperators(
        uint8 a,
        uint8 b
    )
        public
        pure
        returns (
            uint8 andResult,
            uint8 orResult,
            uint8 xorResult,
            uint8 notResult,
            uint8 leftShift,
            uint8 rightShift
        )
    {
        andResult = a & b; // Bitwise AND
        orResult = a | b; // Bitwise OR
        xorResult = a ^ b; // Bitwise XOR
        notResult = ~a; // Bitwise NOT
        leftShift = a << 2; // Left shift by 2 bits
        rightShift = a >> 2; // Right shift by 2 bits

        return (
            andResult,
            orResult,
            xorResult,
            notResult,
            leftShift,
            rightShift
        );
    }

    // Practical bitwise examples
    function bitwiseExamples() public pure returns (uint256, uint256, uint256) {
        uint256 a = 12; // Binary: 1100
        uint256 b = 10; // Binary: 1010

        return (
            a & b, // 1000 = 8  (AND)
            a | b, // 1110 = 14 (OR)
            a ^ b // 0110 = 6  (XOR)
        );
    }

    // Bit shifting for multiplication/division by powers of 2
    function bitShiftOptimization(
        uint256 x
    )
        public
        pure
        returns (
            uint256 multiply4,
            uint256 multiply8,
            uint256 divide4,
            uint256 divide8
        )
    {
        multiply4 = x << 2; // Multiply by 4 (2^2)
        multiply8 = x << 3; // Multiply by 8 (2^3)
        divide4 = x >> 2; // Divide by 4 (2^2)
        divide8 = x >> 3; // Divide by 8 (2^3)

        return (multiply4, multiply8, divide4, divide8);
    }

    // Check if specific bit is set
    function isBitSet(
        uint256 value,
        uint256 position
    ) public pure returns (bool) {
        return (value & (1 << position)) != 0;
    }

    // Set specific bit
    function setBit(
        uint256 value,
        uint256 position
    ) public pure returns (uint256) {
        return value | (1 << position);
    }

    // Clear specific bit
    function clearBit(
        uint256 value,
        uint256 position
    ) public pure returns (uint256) {
        return value & ~(1 << position);
    }

    // Toggle specific bit
    function toggleBit(
        uint256 value,
        uint256 position
    ) public pure returns (uint256) {
        return value ^ (1 << position);
    }

    // ============================================================================
    // 5. ASSIGNMENT OPERATORS
    // ============================================================================
    // Assign and modify values

    function assignmentOperators() public pure returns (uint256) {
        uint256 x = 10; // Simple assignment

        x += 5; // Addition assignment (x = x + 5)
        x -= 3; // Subtraction assignment (x = x - 3)
        x *= 2; // Multiplication assignment (x = x * 2)
        x /= 4; // Division assignment (x = x / 4)
        x %= 3; // Modulo assignment (x = x % 3)

        return x;
    }

    // Bitwise assignment operators
    function bitwiseAssignment() public pure returns (uint8) {
        uint8 x = 12; // Binary: 1100

        x |= 3; // OR assignment (x = x | 3)
        x &= 14; // AND assignment (x = x & 14)
        x ^= 5; // XOR assignment (x = x ^ 5)
        x <<= 1; // Left shift assignment
        x >>= 1; // Right shift assignment

        return x;
    }

    // ============================================================================
    // 6. INCREMENT/DECREMENT OPERATORS
    // ============================================================================
    // Increase or decrease by 1
    // Prefix (++x) vs Postfix (x++) have different behaviors

    function incrementDecrement()
        public
        pure
        returns (
            uint256 postIncrement,
            uint256 preIncrement,
            uint256 postDecrement,
            uint256 preDecrement
        )
    {
        uint256 x = 5;

        // Post-increment: returns current value, then increments
        postIncrement = x++; // postIncrement = 5, x becomes 6

        // Pre-increment: increments first, then returns new value
        x = 5; // Reset
        preIncrement = ++x; // preIncrement = 6, x becomes 6

        // Post-decrement: returns current value, then decrements
        x = 5; // Reset
        postDecrement = x--; // postDecrement = 5, x becomes 4

        // Pre-decrement: decrements first, then returns new value
        x = 5; // Reset
        preDecrement = --x; // preDecrement = 4, x becomes 4

        return (postIncrement, preIncrement, postDecrement, preDecrement);
    }

    // Increment in loops (prefix is slightly more gas-efficient)
    function loopIncrement() public pure returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = 0; i < 10; ++i) {
            // Prefix increment
            sum += i;
        }

        return sum;
    }

    // ============================================================================
    // 7. TERNARY OPERATOR
    // ============================================================================
    // Conditional expression: condition ? valueIfTrue : valueIfFalse
    // More gas-efficient than if-else for simple conditions

    function ternaryOperator(uint256 x) public pure returns (string memory) {
        return x > 10 ? "Greater than 10" : "Not greater than 10";
    }

    // Nested ternary
    function nestedTernary(uint256 x) public pure returns (string memory) {
        return
            x > 100
                ? "High"
                : x > 50
                    ? "Medium"
                    : "Low";
    }

    // Ternary with calculations
    function ternaryCalculation(uint256 x) public pure returns (uint256) {
        return x > 0 ? x * 2 : 0;
    }

    // ============================================================================
    // 8. DELETE OPERATOR
    // ============================================================================
    // Resets variable to its default value
    // For integers: 0, for bool: false, for arrays: length 0

    uint256 public storedValue = 100;
    bool public storedBool = true;

    function deleteOperator() public {
        delete storedValue; // storedValue becomes 0
        delete storedBool; // storedBool becomes false
    }

    // Delete array element (sets to default, doesn't remove)
    function deleteArrayElement() public pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](5);
        arr[0] = 10;
        arr[1] = 20;
        arr[2] = 30;

        delete arr[1]; // arr[1] becomes 0, but array length stays 5

        return arr; // [10, 0, 30, 0, 0]
    }

    // ============================================================================
    // 9. TYPE CASTING OPERATORS
    // ============================================================================
    // Convert between types

    function typeCasting()
        public
        pure
        returns (
            uint256 fromInt,
            int256 fromUint,
            uint8 fromUint256,
            address fromUint160
        )
    {
        // Explicit casting
        int256 signedValue = -10;
        fromInt = uint256(signedValue); // Careful: -10 becomes very large number

        uint256 unsignedValue = 100;
        fromUint = int256(unsignedValue); // Safe conversion

        uint256 largeValue = 1000;
        fromUint256 = uint8(largeValue); // Truncated to 232 (1000 % 256)

        uint160 addressValue = 123456789;
        fromUint160 = address(addressValue); // Convert to address

        return (fromInt, fromUint, fromUint256, fromUint160);
    }

    // Address casting
    function addressCasting(
        address addr
    ) public pure returns (address payable payableAddr, uint160 addrAsUint) {
        payableAddr = payable(addr); // Cast to payable address
        addrAsUint = uint160(addr); // Cast to uint160

        return (payableAddr, addrAsUint);
    }

    // Bytes casting
    function bytesCasting() public pure returns (bytes32, bytes4, uint256) {
        bytes32 b32 = "Hello";
        bytes4 b4 = bytes4(b32); // Take first 4 bytes
        uint256 asUint = uint256(b32); // Convert to uint256

        return (b32, b4, asUint);
    }

    // ============================================================================
    // 10. OPERATOR PRECEDENCE
    // ============================================================================
    // Order of operations (highest to lowest precedence)
    // 1. Postfix increment/decrement: x++, x--
    // 2. Prefix increment/decrement, unary: ++x, --x, +x, -x, !
    // 3. Exponentiation: **
    // 4. Multiplication, division, modulo: *, /, %
    // 5. Addition, subtraction: +, -
    // 6. Bitwise shift: <<, >>
    // 7. Bitwise AND: &
    // 8. Bitwise XOR: ^
    // 9. Bitwise OR: |
    // 10. Comparison: <, >, <=, >=
    // 11. Equality: ==, !=
    // 12. Logical AND: &&
    // 13. Logical OR: ||
    // 14. Ternary: ? :
    // 15. Assignment: =, +=, -=, etc.

    function precedenceExample()
        public
        pure
        returns (uint256, uint256, uint256)
    {
        uint256 a = 2 + 3 * 4; // 14 (not 20) - multiplication first
        uint256 b = (2 + 3) * 4; // 20 - parentheses override
        uint256 c = 2 ** 3 * 2; // 16 (not 64) - exponentiation first

        return (a, b, c);
    }

    function complexPrecedence() public pure returns (bool, bool) {
        uint256 x = 10;
        uint256 y = 20;
        bool flag = true;

        // && has higher precedence than ||
        bool result1 = flag || (x > 5 && y < 30); // true (AND evaluated first)

        // With parentheses for clarity
        bool result2 = flag || (x > 5 && y < 30);

        return (result1, result2);
    }

    // ============================================================================
    // 11. PRACTICAL OPERATOR PATTERNS
    // ============================================================================

    // Swap values using XOR (no temporary variable)
    function xorSwap(
        uint256 a,
        uint256 b
    ) public pure returns (uint256, uint256) {
        a = a ^ b;
        b = a ^ b;
        a = a ^ b;
        return (a, b);
    }

    // Check if number is power of 2
    function isPowerOfTwo(uint256 x) public pure returns (bool) {
        return x > 0 && (x & (x - 1)) == 0;
    }

    // Count set bits (number of 1s in binary)
    function countSetBits(uint256 x) public pure returns (uint256) {
        uint256 count = 0;
        while (x > 0) {
            count += x & 1;
            x >>= 1;
        }
        return count;
    }

    // Find absolute value (for signed integers)
    function absoluteValue(int256 x) public pure returns (int256) {
        return x >= 0 ? x : -x;
    }

    // Safe percentage calculation
    function percentage(
        uint256 amount,
        uint256 percent
    ) public pure returns (uint256) {
        require(percent <= 100, "Invalid percentage");
        return (amount * percent) / 100;
    }

    // Clamp value between min and max
    function clamp(
        uint256 value,
        uint256 minVal,
        uint256 maxVal
    ) public pure returns (uint256) {
        return value < minVal ? minVal : (value > maxVal ? maxVal : value);
    }

    // ============================================================================
    // KEY TAKEAWAYS FOR PROFESSIONAL DEVELOPERS:
    // ============================================================================
    // 1. Solidity 0.8.0+ has automatic overflow/underflow checks
    // 2. Integer division rounds down (no floating point)
    // 3. Bitwise operators are very gas-efficient
    // 4. Use bit shifting for multiplication/division by powers of 2
    // 5. Prefix increment (++i) is slightly more gas-efficient than postfix (i++)
    // 6. Ternary operator is more gas-efficient than if-else
    // 7. Short-circuit evaluation: && and || stop evaluating when result is determined
    // 8. delete operator resets to default value, doesn't remove from arrays
    // 9. Be careful with type casting - can cause unexpected results
    // 10. Use parentheses to make operator precedence explicit
    // 11. Bitwise operations useful for flags and gas optimization
    // 12. XOR (^) useful for toggling and swapping
    // 13. Understanding precedence prevents logical errors
    // 14. Modulo (%) useful for cyclic operations and remainders
    // ============================================================================
}

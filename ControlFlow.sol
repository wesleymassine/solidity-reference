// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY CONTROL FLOW - Complete Reference
// From Zero to Senior Level
// ============================================================================

contract ControlFlow {
    // ============================================================================
    // 1. IF-ELSE STATEMENTS
    // ============================================================================
    // Basic conditional logic
    // Syntax: if (condition) { } else if (condition) { } else { }

    function ifElseBasic(uint256 x) public pure returns (string memory) {
        if (x > 100) {
            return "Greater than 100";
        } else if (x > 50) {
            return "Greater than 50";
        } else if (x > 0) {
            return "Greater than 0";
        } else {
            return "Zero or negative";
        }
    }

    // Nested if statements
    function nestedIf(
        uint256 x,
        uint256 y
    ) public pure returns (string memory) {
        if (x > 10) {
            if (y > 10) {
                return "Both greater than 10";
            } else {
                return "Only x greater than 10";
            }
        } else {
            return "x not greater than 10";
        }
    }

    // If without else
    function ifWithoutElse(uint256 x) public pure returns (uint256) {
        uint256 result = x;

        if (x > 100) {
            result = 100;
        }

        return result;
    }

    // ============================================================================
    // 2. TERNARY OPERATOR
    // ============================================================================
    // Compact conditional expression
    // Syntax: condition ? valueIfTrue : valueIfFalse
    // More gas-efficient than if-else for simple conditions

    function ternaryBasic(uint256 x) public pure returns (string memory) {
        return x > 10 ? "Greater" : "Not greater";
    }

    function ternaryWithCalculation(uint256 x) public pure returns (uint256) {
        return x > 100 ? x * 2 : x / 2;
    }

    // Nested ternary (use sparingly for readability)
    function nestedTernary(uint256 x) public pure returns (string memory) {
        return
            x > 100
                ? "High"
                : x > 50
                    ? "Medium"
                    : "Low";
    }

    // Finding min/max with ternary
    function min(uint256 a, uint256 b) public pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) public pure returns (uint256) {
        return a > b ? a : b;
    }

    // ============================================================================
    // 3. FOR LOOPS
    // ============================================================================
    // Standard loop for iteration
    // Syntax: for (initialization; condition; increment) { }
    // Be careful with gas costs in loops

    // Basic for loop
    function forLoopBasic() public pure returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = 0; i < 10; i++) {
            sum += i;
        }

        return sum;
    }

    // Loop through array
    function sumArray(uint256[] memory arr) public pure returns (uint256) {
        uint256 total = 0;

        for (uint256 i = 0; i < arr.length; i++) {
            total += arr[i];
        }

        return total;
    }

    // Optimized loop (cache array length)
    function sumArrayOptimized(
        uint256[] memory arr
    ) public pure returns (uint256) {
        uint256 total = 0;
        uint256 length = arr.length; // Cache length to save gas

        for (uint256 i = 0; i < length; i++) {
            total += arr[i];
        }

        return total;
    }

    // Loop with step
    function forLoopWithStep() public pure returns (uint256) {
        uint256 sum = 0;

        // Increment by 2
        for (uint256 i = 0; i < 20; i += 2) {
            sum += i;
        }

        return sum;
    }

    // Reverse loop
    function reverseLoop() public pure returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = 10; i > 0; i--) {
            sum += i;
        }

        return sum;
    }

    // Nested loops
    function nestedLoops() public pure returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = 0; j < 5; j++) {
                sum += i * j;
            }
        }

        return sum;
    }

    // ============================================================================
    // 4. WHILE LOOPS
    // ============================================================================
    // Loop that continues while condition is true
    // Syntax: while (condition) { }
    // Less common than for loops in Solidity

    function whileLoopBasic(uint256 x) public pure returns (uint256) {
        uint256 result = 0;
        uint256 counter = 0;

        while (counter < x) {
            result += counter;
            counter++;
        }

        return result;
    }

    // While loop with complex condition
    function whileLoopComplex(uint256 x) public pure returns (uint256) {
        uint256 result = x;

        while (result > 1 && result % 2 == 0) {
            result = result / 2;
        }

        return result;
    }

    // ============================================================================
    // 5. DO-WHILE LOOPS
    // ============================================================================
    // Loop that executes at least once before checking condition
    // Syntax: do { } while (condition);
    // Executes body first, then checks condition

    function doWhileLoop(uint256 x) public pure returns (uint256) {
        uint256 result = 0;
        uint256 counter = 0;

        do {
            result += counter;
            counter++;
        } while (counter < x);

        return result;
    }

    // Do-while guarantees at least one execution
    function doWhileGuaranteedExecution() public pure returns (uint256) {
        uint256 result = 0;

        do {
            result = 100; // This executes even though condition is false
        } while (false);

        return result; // Returns 100
    }

    // ============================================================================
    // 6. BREAK STATEMENT
    // ============================================================================
    // Exit loop early
    // Works in for, while, and do-while loops

    function breakExample() public pure returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = 0; i < 100; i++) {
            if (i == 10) {
                break; // Exit loop when i reaches 10
            }
            sum += i;
        }

        return sum; // Returns sum of 0-9
    }

    // Break in nested loop (only exits inner loop)
    function breakNestedLoop() public pure returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = 0; j < 5; j++) {
                if (j == 3) {
                    break; // Only exits inner loop
                }
                sum += i + j;
            }
        }

        return sum;
    }

    // Find first occurrence
    function findFirst(
        uint256[] memory arr,
        uint256 target
    ) public pure returns (int256) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == target) {
                return int256(i); // Found, return index
            }
        }
        return -1; // Not found
    }

    // ============================================================================
    // 7. CONTINUE STATEMENT
    // ============================================================================
    // Skip current iteration and continue with next
    // Works in for, while, and do-while loops

    function continueExample() public pure returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = 0; i < 10; i++) {
            if (i % 2 == 0) {
                continue; // Skip even numbers
            }
            sum += i;
        }

        return sum; // Returns sum of odd numbers only
    }

    // Continue with multiple conditions
    function continueMultiple() public pure returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = 0; i < 100; i++) {
            if (i % 2 == 0) continue; // Skip even
            if (i % 3 == 0) continue; // Skip multiples of 3
            if (i > 50) continue; // Skip numbers > 50

            sum += i;
        }

        return sum;
    }

    // ============================================================================
    // 8. RETURN STATEMENT
    // ============================================================================
    // Exit function and return value
    // Can be used to exit early from function

    function earlyReturn(uint256 x) public pure returns (string memory) {
        if (x == 0) {
            return "Zero"; // Early return
        }

        if (x < 10) {
            return "Small";
        }

        return "Large";
    }

    // Multiple return points
    function multipleReturns(uint256 x) public pure returns (uint256) {
        if (x > 100) return 100;
        if (x < 10) return 10;
        return x;
    }

    // ============================================================================
    // 9. REQUIRE - INPUT VALIDATION
    // ============================================================================
    // Validate conditions, revert if false
    // Gas refund on failure
    // Use for validating inputs and conditions
    // Syntax: require(condition, "error message");

    function requireBasic(uint256 x) public pure returns (uint256) {
        require(x > 0, "Value must be positive");
        require(x < 1000, "Value too large");

        return x * 2;
    }

    // Require with complex conditions
    function requireComplex(
        uint256 x,
        uint256 y,
        address addr
    ) public pure returns (uint256) {
        require(x > 0 && y > 0, "Both values must be positive");
        require(addr != address(0), "Invalid address");
        require(x != y, "Values must be different");

        return x + y;
    }

    // Require in loops
    function requireInLoop(uint256[] memory arr) public pure returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = 0; i < arr.length; i++) {
            require(arr[i] > 0, "All values must be positive");
            sum += arr[i];
        }

        return sum;
    }

    // ============================================================================
    // 10. ASSERT - INTERNAL ERROR CHECKING
    // ============================================================================
    // Check for internal errors and invariants
    // Should never fail in correct code
    // No gas refund on failure (uses all remaining gas)
    // Use for testing invariants and preventing impossible states

    function assertExample(uint256 x) public pure returns (uint256) {
        uint256 result = x * 2;

        // Assert invariant: result should always be even
        assert(result % 2 == 0);

        return result;
    }

    // Assert for overflow check (pre-0.8.0 pattern)
    function assertOverflow(
        uint256 a,
        uint256 b
    ) public pure returns (uint256) {
        uint256 c = a + b;

        // In Solidity 0.8.0+, this is automatic, but shown for educational purposes
        assert(c >= a); // Check no overflow occurred

        return c;
    }

    // ============================================================================
    // 11. REVERT - EXPLICIT REVERSION
    // ============================================================================
    // Explicitly revert transaction
    // More flexible than require
    // Can be used with custom errors (0.8.4+)

    function revertBasic(uint256 x) public pure returns (uint256) {
        if (x == 0) {
            revert("Value cannot be zero");
        }

        return x * 2;
    }

    // Revert with conditional
    function revertConditional(
        uint256 x,
        bool shouldRevert
    ) public pure returns (uint256) {
        if (shouldRevert) {
            revert("Intentional revert");
        }

        return x;
    }

    // Custom errors (more gas efficient)
    error InvalidValue(uint256 value, string reason);
    error InsufficientAmount(uint256 provided, uint256 required);

    function revertWithCustomError(uint256 x) public pure returns (uint256) {
        if (x == 0) {
            revert InvalidValue(x, "Cannot be zero");
        }

        if (x < 10) {
            revert InsufficientAmount(x, 10);
        }

        return x;
    }

    // ============================================================================
    // 12. TRY-CATCH - ERROR HANDLING
    // ============================================================================
    // Handle errors from external calls
    // Cannot be used for internal function calls
    // Three types of catch blocks

    // Helper contract for demonstration
    function externalFunction(uint256 x) external pure returns (uint256) {
        require(x > 0, "Value must be positive");
        return x * 2;
    }

    // Basic try-catch
    function tryCatchBasic(
        uint256 x
    ) public returns (bool success, uint256 result) {
        try this.externalFunction(x) returns (uint256 value) {
            // Success path
            return (true, value);
        } catch {
            // Any error
            return (false, 0);
        }
    }

    // Try-catch with error types
    function tryCatchDetailed(
        uint256 x
    )
        public
        returns (bool success, uint256 result, string memory errorMessage)
    {
        try this.externalFunction(x) returns (uint256 value) {
            // Success
            return (true, value, "");
        } catch Error(string memory reason) {
            // Catch revert with reason string
            return (false, 0, reason);
        } catch Panic(uint256 errorCode) {
            // Catch panic errors (assert, overflow, etc.)
            return (false, 0, string(abi.encodePacked("Panic: ", errorCode)));
        } catch (bytes memory lowLevelData) {
            // Catch other errors
            return (false, 0, "Unknown error");
        }
    }

    // ============================================================================
    // 13. UNCHECKED BLOCKS (Solidity 0.8.0+)
    // ============================================================================
    // Disable overflow/underflow checks for gas optimization
    // Use only when overflow is impossible or desired
    // Saves gas but removes safety checks

    function uncheckedExample() public pure returns (uint256) {
        uint256 x = 10;

        // Normal arithmetic (with overflow checks)
        uint256 y = x + 5;

        // Unchecked arithmetic (no overflow checks)
        unchecked {
            uint256 z = x + 5; // Saves gas
            return z;
        }
    }

    // Unchecked in loops (common optimization)
    function uncheckedLoop() public pure returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = 0; i < 100; ) {
            sum += i;

            unchecked {
                i++; // Save gas on increment (overflow impossible)
            }
        }

        return sum;
    }

    // Unchecked for known safe operations
    function uncheckedSafeOperation(uint256 x) public pure returns (uint256) {
        require(x <= 100, "Value too large");

        unchecked {
            // Safe because we validated x <= 100
            return x + 50;
        }
    }

    // ============================================================================
    // 14. SHORT-CIRCUIT EVALUATION
    // ============================================================================
    // Boolean operators && and || use short-circuit evaluation
    // Can save gas by ordering conditions efficiently

    function shortCircuitAnd(uint256 x) public pure returns (bool) {
        // If first condition is false, second is not evaluated
        return x > 0 && expensiveCheck(x);
    }

    function shortCircuitOr(uint256 x) public pure returns (bool) {
        // If first condition is true, second is not evaluated
        return x == 0 || expensiveCheck(x);
    }

    function expensiveCheck(uint256 x) private pure returns (bool) {
        // Simulate expensive operation
        uint256 result = 0;
        for (uint256 i = 0; i < x; i++) {
            result += i;
        }
        return result > 0;
    }

    // Optimal ordering: cheap checks first
    function optimizedConditions(
        address addr,
        uint256 x
    ) public view returns (bool) {
        // Cheap checks first
        return
            addr != address(0) && // Cheap
            x > 0 && // Cheap
            x < 1000 && // Cheap
            expensiveCheck(x); // Expensive - evaluated last
    }

    // ============================================================================
    // 15. COMPLEX CONTROL FLOW PATTERNS
    // ============================================================================

    // State machine pattern
    enum State {
        Pending,
        Active,
        Completed,
        Cancelled
    }
    State public currentState = State.Pending;

    function stateMachine(State newState) public returns (string memory) {
        if (currentState == State.Pending) {
            if (newState == State.Active) {
                currentState = newState;
                return "Activated";
            }
            revert("Invalid state transition");
        }

        if (currentState == State.Active) {
            if (newState == State.Completed || newState == State.Cancelled) {
                currentState = newState;
                return "State updated";
            }
            revert("Invalid state transition");
        }

        revert("Cannot change completed or cancelled state");
    }

    // Guard clauses pattern (early returns)
    function guardClausesPattern(
        uint256 x,
        address addr
    ) public pure returns (uint256) {
        // Validate inputs with early returns
        if (x == 0) revert("X cannot be zero");
        if (addr == address(0)) revert("Invalid address");
        if (x > 1000) revert("X too large");

        // Main logic after validations
        return x * 2;
    }

    // ============================================================================
    // KEY TAKEAWAYS FOR PROFESSIONAL DEVELOPERS:
    // ============================================================================
    // 1. Use require() for input validation (gas refund on failure)
    // 2. Use assert() for invariants (should never fail)
    // 3. Use revert() for complex error handling, custom errors save gas
    // 4. Minimize loops, especially nested loops (gas costs)
    // 5. Cache array length in loops to save gas
    // 6. Use unchecked for known safe operations (0.8.0+)
    // 7. Break and continue can optimize loop execution
    // 8. Try-catch only works for external calls
    // 9. Short-circuit evaluation: order conditions by gas cost
    // 10. Ternary operators are more gas-efficient than if-else
    // 11. Guard clauses improve readability and security
    // 12. State machines provide clear control flow
    // 13. Early returns reduce nesting and improve readability
    // 14. Custom errors (0.8.4+) are more gas-efficient than strings
    // ============================================================================
}

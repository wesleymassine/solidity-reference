// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY LIBRARIES - Complete Reference
// From Zero to Professional
// ============================================================================

// ============================================================================
// 1. BASIC LIBRARY CONCEPTS
// ============================================================================
// Libraries are similar to contracts but with key differences:
// - Cannot have state variables (except constants)
// - Cannot inherit or be inherited
// - Cannot receive Ether
// - Cannot be destroyed
// - All library functions are stateless
// - Used for reusable code across contracts
// - Can save gas by avoiding code duplication

// Simple mathematical library
library MathLib {
    // Library functions are internal by default
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    function subtract(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "MathLib: subtraction overflow");
        return a - b;
    }

    function multiply(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "MathLib: multiplication overflow");
        return c;
    }

    function divide(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "MathLib: division by zero");
        return a / b;
    }
}

// Using library with direct calls
contract MathUser {
    // Call library functions directly
    function calculate(uint256 a, uint256 b) public pure returns (uint256) {
        uint256 sum = MathLib.add(a, b);
        uint256 product = MathLib.multiply(sum, 2);
        return product;
    }
}

// ============================================================================
// 2. USING FOR DIRECTIVE
// ============================================================================
// "using for" attaches library functions to types
// Makes code more readable and intuitive
// Syntax: using LibraryName for Type;
// Can use * to attach all functions
// Can use for user-defined types

// String utility library
library StringLib {
    // Check if string is empty
    function isEmpty(string memory str) internal pure returns (bool) {
        return bytes(str).length == 0;
    }

    // Get string length
    function length(string memory str) internal pure returns (uint256) {
        return bytes(str).length;
    }

    // Concatenate two strings
    function concat(
        string memory a,
        string memory b
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a, b));
    }

    // Compare two strings
    function equal(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// Using "using for" directive
contract StringUser {
    // Attach StringLib functions to string type
    using StringLib for string;

    function processString(
        string memory text
    ) public pure returns (bool, uint256) {
        // Can call library functions as if they were methods
        bool empty = text.isEmpty();
        uint256 len = text.length();
        return (empty, len);
    }

    function combineStrings(
        string memory a,
        string memory b
    ) public pure returns (string memory) {
        return a.concat(b); // Called like a method
    }

    function compareStrings(
        string memory a,
        string memory b
    ) public pure returns (bool) {
        return a.equal(b);
    }
}

// ============================================================================
// 3. INTERNAL VS EXTERNAL LIBRARY FUNCTIONS
// ============================================================================
// Internal functions: embedded into calling contract (no DELEGATECALL)
// External functions: called via DELEGATECALL (library must be deployed)

library InternalLib {
    // Internal functions are embedded into the contract
    // More gas efficient for simple operations
    function internalFunc(uint256 x) internal pure returns (uint256) {
        return x * 2;
    }
}

library ExternalLib {
    // External functions require library deployment
    // Called via DELEGATECALL
    // Useful for complex logic to reduce contract size
    function externalFunc(uint256 x) external pure returns (uint256) {
        return x * 3;
    }

    // Can have public functions too (acts like external)
    function publicFunc(uint256 x) public pure returns (uint256) {
        return x * 4;
    }
}

// ============================================================================
// 4. ADVANCED MATH LIBRARY
// ============================================================================
// Comprehensive math operations with safety checks

library AdvancedMath {
    // Calculate percentage
    function percentage(
        uint256 amount,
        uint256 percent
    ) internal pure returns (uint256) {
        require(percent <= 100, "AdvancedMath: percent must be <= 100");
        return (amount * percent) / 100;
    }

    // Calculate average
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a + b) / 2;
    }

    // Find minimum of two numbers
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // Find maximum of two numbers
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    // Power function (a^b)
    function power(
        uint256 base,
        uint256 exponent
    ) internal pure returns (uint256) {
        if (exponent == 0) return 1;

        uint256 result = 1;
        for (uint256 i = 0; i < exponent; i++) {
            result *= base;
        }
        return result;
    }

    // Square root (Babylonian method)
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        uint256 y = x;

        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return y;
    }

    // Absolute difference
    function absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }
}

// Using advanced math library
contract AdvancedMathUser {
    using AdvancedMath for uint256;

    function calculateStats(
        uint256 a,
        uint256 b
    )
        public
        pure
        returns (uint256 _min, uint256 _max, uint256 _avg, uint256 _diff)
    {
        _min = a.min(b);
        _max = a.max(b);
        _avg = a.average(b);
        _diff = a.absDiff(b);
    }

    function calculatePower(
        uint256 base,
        uint256 exp
    ) public pure returns (uint256) {
        return base.power(exp);
    }

    function calculateSqrt(uint256 x) public pure returns (uint256) {
        return x.sqrt();
    }
}

// ============================================================================
// 5. ARRAY LIBRARY
// ============================================================================
// Utility functions for array manipulation

library ArrayLib {
    // Find element in array
    function indexOf(
        uint256[] memory arr,
        uint256 element
    ) internal pure returns (int256) {
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == element) {
                return int256(i);
            }
        }
        return -1; // Not found
    }

    // Check if array contains element
    function contains(
        uint256[] memory arr,
        uint256 element
    ) internal pure returns (bool) {
        return indexOf(arr, element) != -1;
    }

    // Sum all elements
    function sum(uint256[] memory arr) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < arr.length; i++) {
            total += arr[i];
        }
        return total;
    }

    // Find maximum element
    function max(uint256[] memory arr) internal pure returns (uint256) {
        require(arr.length > 0, "ArrayLib: empty array");
        uint256 maximum = arr[0];
        for (uint256 i = 1; i < arr.length; i++) {
            if (arr[i] > maximum) {
                maximum = arr[i];
            }
        }
        return maximum;
    }

    // Find minimum element
    function min(uint256[] memory arr) internal pure returns (uint256) {
        require(arr.length > 0, "ArrayLib: empty array");
        uint256 minimum = arr[0];
        for (uint256 i = 1; i < arr.length; i++) {
            if (arr[i] < minimum) {
                minimum = arr[i];
            }
        }
        return minimum;
    }

    // Reverse array
    function reverse(
        uint256[] memory arr
    ) internal pure returns (uint256[] memory) {
        uint256 length = arr.length;
        uint256[] memory reversed = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            reversed[i] = arr[length - 1 - i];
        }

        return reversed;
    }
}

// ============================================================================
// 6. ADDRESS LIBRARY
// ============================================================================
// Utility functions for address manipulation and checks

library AddressLib {
    // Check if address is a contract
    function isContract(address account) internal view returns (bool) {
        // Check if account has code
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    // Send Ether with error handling
    function sendValue(address payable recipient, uint256 amount) internal {
        require(
            address(this).balance >= amount,
            "AddressLib: insufficient balance"
        );

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "AddressLib: send failed");
    }

    // Function call with error handling
    function functionCall(
        address target,
        bytes memory data
    ) internal returns (bytes memory) {
        return
            functionCallWithValue(
                target,
                data,
                0,
                "AddressLib: low-level call failed"
            );
    }

    // Function call with value
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(
            address(this).balance >= value,
            "AddressLib: insufficient balance"
        );
        require(isContract(target), "AddressLib: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(
            data
        );
        return verifyCallResult(success, returndata, errorMessage);
    }

    // Verify call result
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// ============================================================================
// 7. SAFE MATH LIBRARY (Historical - Built-in since 0.8.0)
// ============================================================================
// Before Solidity 0.8.0, SafeMath was essential
// Now built-in, but understanding it is important for legacy code

library SafeMath {
    // These functions are now redundant in Solidity 0.8.0+
    // Included for educational purposes

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

// ============================================================================
// 8. STRUCT LIBRARY PATTERN
// ============================================================================
// Libraries can work with structs defined elsewhere
// Useful for encapsulating struct logic

// Define struct in a separate contract/library
library StructDefinitions {
    struct User {
        string name;
        uint256 age;
        uint256 balance;
        bool active;
    }
}

// Library for struct operations
library UserLib {
    using StructDefinitions for StructDefinitions.User;

    // Initialize user
    function init(
        StructDefinitions.User storage user,
        string memory name,
        uint256 age
    ) internal {
        user.name = name;
        user.age = age;
        user.balance = 0;
        user.active = true;
    }

    // Update balance
    function deposit(
        StructDefinitions.User storage user,
        uint256 amount
    ) internal {
        require(user.active, "UserLib: user not active");
        user.balance += amount;
    }

    // Withdraw
    function withdraw(
        StructDefinitions.User storage user,
        uint256 amount
    ) internal {
        require(user.active, "UserLib: user not active");
        require(user.balance >= amount, "UserLib: insufficient balance");
        user.balance -= amount;
    }

    // Deactivate user
    function deactivate(StructDefinitions.User storage user) internal {
        user.active = false;
    }
}

// Using struct library
contract UserManager {
    using UserLib for StructDefinitions.User;

    mapping(address => StructDefinitions.User) public users;

    function createUser(string memory name, uint256 age) public {
        users[msg.sender].init(name, age);
    }

    function depositFunds(uint256 amount) public {
        users[msg.sender].deposit(amount);
    }

    function withdrawFunds(uint256 amount) public {
        users[msg.sender].withdraw(amount);
    }

    function deactivateAccount() public {
        users[msg.sender].deactivate();
    }
}

// ============================================================================
// 9. LIBRARY WITH EVENTS
// ============================================================================
// Libraries can define events that calling contracts will emit

library LibraryWithEvents {
    // Event defined in library
    event ValueChanged(
        address indexed changer,
        uint256 oldValue,
        uint256 newValue
    );

    struct Data {
        uint256 value;
    }

    function setValue(Data storage data, uint256 newValue) internal {
        uint256 oldValue = data.value;
        data.value = newValue;
        emit ValueChanged(msg.sender, oldValue, newValue);
    }
}

contract EventUser {
    using LibraryWithEvents for LibraryWithEvents.Data;

    LibraryWithEvents.Data private data;

    // Event from library will be emitted by this contract
    function updateValue(uint256 newValue) public {
        data.setValue(newValue);
    }

    function getValue() public view returns (uint256) {
        return data.value;
    }
}

// ============================================================================
// 10. LIBRARY FOR CUSTOM TYPES (Solidity 0.8.8+)
// ============================================================================
// Libraries can work with user-defined value types

// Define custom type
type Price is uint256;

library PriceLib {
    // Wrap uint256 to Price
    function wrap(uint256 value) internal pure returns (Price) {
        return Price.wrap(value);
    }

    // Unwrap Price to uint256
    function unwrap(Price price) internal pure returns (uint256) {
        return Price.unwrap(price);
    }

    // Add two prices
    function add(Price a, Price b) internal pure returns (Price) {
        return Price.wrap(Price.unwrap(a) + Price.unwrap(b));
    }

    // Multiply price by scalar
    function multiply(
        Price price,
        uint256 multiplier
    ) internal pure returns (Price) {
        return Price.wrap(Price.unwrap(price) * multiplier);
    }

    // Apply discount percentage
    function applyDiscount(
        Price price,
        uint256 discountPercent
    ) internal pure returns (Price) {
        require(discountPercent <= 100, "PriceLib: invalid discount");
        uint256 discountAmount = (Price.unwrap(price) * discountPercent) / 100;
        return Price.wrap(Price.unwrap(price) - discountAmount);
    }
}

contract PriceManager {
    using PriceLib for Price;

    Price public basePrice = PriceLib.wrap(1000);

    function calculateFinalPrice(
        uint256 quantity,
        uint256 discount
    ) public view returns (uint256) {
        Price total = basePrice.multiply(quantity);
        Price discounted = total.applyDiscount(discount);
        return discounted.unwrap();
    }
}

// ============================================================================
// 11. REAL-WORLD LIBRARY EXAMPLE: TOKEN ALLOWANCE
// ============================================================================

library AllowanceLib {
    struct Allowance {
        mapping(address => mapping(address => uint256)) allowances;
    }

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function approve(
        Allowance storage self,
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "AllowanceLib: approve from zero address");
        require(spender != address(0), "AllowanceLib: approve to zero address");

        self.allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function increaseAllowance(
        Allowance storage self,
        address owner,
        address spender,
        uint256 addedValue
    ) internal {
        uint256 newAllowance = self.allowances[owner][spender] + addedValue;
        approve(self, owner, spender, newAllowance);
    }

    function decreaseAllowance(
        Allowance storage self,
        address owner,
        address spender,
        uint256 subtractedValue
    ) internal {
        uint256 currentAllowance = self.allowances[owner][spender];
        require(
            currentAllowance >= subtractedValue,
            "AllowanceLib: decreased below zero"
        );
        approve(self, owner, spender, currentAllowance - subtractedValue);
    }

    function spendAllowance(
        Allowance storage self,
        address owner,
        address spender,
        uint256 amount
    ) internal {
        uint256 currentAllowance = self.allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "AllowanceLib: insufficient allowance"
            );
            approve(self, owner, spender, currentAllowance - amount);
        }
    }
}

// ============================================================================
// 12. LIBRARY DEPLOYMENT AND LINKING
// ============================================================================
// External libraries must be deployed separately and linked
// Internal libraries are embedded in contract bytecode

// This library would need to be deployed separately
library ExternalMathLib {
    function complexCalculation(
        uint256 x,
        uint256 y
    ) external pure returns (uint256) {
        // Complex logic that would bloat contract size
        return (x ** 2 + y ** 2) / (x + y);
    }
}

// When deploying contracts using external libraries:
// 1. Deploy the library first
// 2. Get library address
// 3. Link library address when deploying contract
// 4. Contract will use DELEGATECALL to library

// ============================================================================
// KEY TAKEAWAYS FOR PROFESSIONAL DEVELOPERS:
// ============================================================================
// 1. Use libraries for reusable, stateless logic
// 2. Internal functions are more gas-efficient (embedded in contract)
// 3. External functions reduce contract size but cost more gas
// 4. "using for" makes code more readable and intuitive
// 5. Libraries cannot have state variables (except constants)
// 6. Libraries can emit events through calling contracts
// 7. SafeMath is obsolete in 0.8.0+ (built-in overflow checks)
// 8. Use libraries for complex struct operations
// 9. Libraries can work with user-defined types (0.8.8+)
// 10. External libraries require separate deployment and linking
// 11. Consider library vs inheritance based on use case
// 12. Libraries are ideal for utility functions shared across projects
// ============================================================================

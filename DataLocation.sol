// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY DATA LOCATIONS - Complete Reference
// storage, memory, calldata
// From Zero to Senior Level
// ============================================================================

contract DataLocation {
    // ============================================================================
    // 1. STORAGE
    // ============================================================================
    // - Permanent data stored on blockchain
    // - State variables are always in storage
    // - Most expensive in terms of gas
    // - Persists between function calls
    // - Can be modified

    // State variables (automatically storage)
    uint256 public storageNumber = 100;
    string public storageString = "Hello";
    uint256[] public storageArray;
    mapping(address => uint256) public storageMapping;

    struct User {
        string name;
        uint256 age;
    }

    User[] public users;

    // Storage reference in function
    function modifyStorage() public {
        // Direct modification
        storageNumber = 200;

        // Storage reference
        User storage user = users[0];
        user.age = 30; // Modifies actual storage
    }

    // ============================================================================
    // 2. MEMORY
    // ============================================================================
    // - Temporary data, erased between external function calls
    // - Function parameters and local variables use memory
    // - Less expensive than storage
    // - Can be modified
    // - Does NOT persist

    function memoryExample() public pure {
        // Memory variables
        uint256 memoryNumber = 100;
        string memory memoryString = "Temporary";

        // Memory array
        uint256[] memory memoryArray = new uint256[](5);
        memoryArray[0] = 10;

        // Memory struct
        User memory memoryUser = User("Alice", 25);
    }

    // Memory parameters
    function processMemory(
        string memory text,
        uint256[] memory numbers
    ) public pure returns (string memory) {
        // Can modify memory parameters
        numbers[0] = 999;
        return text;
    }

    // ============================================================================
    // 3. CALLDATA
    // ============================================================================
    // - Temporary data, like memory
    // - READ-ONLY, cannot be modified
    // - Most gas-efficient for external function parameters
    // - Only available in external functions
    // - Best practice for external function parameters

    function calldataExample(
        string calldata text,
        uint256[] calldata numbers
    ) external pure returns (string calldata) {
        // Cannot modify calldata
        // numbers[0] = 999;  // ERROR: Cannot modify calldata

        return text; // Can return calldata
    }

    // ============================================================================
    // 4. STORAGE VS MEMORY VS CALLDATA
    // ============================================================================

    /*
    | Location | Lifetime        | Modifiable | Gas Cost | Use Case                  |
    |----------|-----------------|------------|----------|---------------------------|
    | storage  | Permanent       | Yes        | High     | State variables           |
    | memory   | Function call   | Yes        | Medium   | Temp data, computation    |
    | calldata | Function call   | No         | Low      | External params (optimal) |
    */

    // ============================================================================
    // 5. STORAGE REFERENCES
    // ============================================================================
    // Storage references point to actual storage location
    // Modifications affect the actual state

    function storageReference() public {
        storageArray.push(10);
        storageArray.push(20);
        storageArray.push(30);

        // Storage reference - points to actual storage
        uint256[] storage arrayRef = storageArray;
        arrayRef[0] = 999; // Modifies actual storage

        // storageArray[0] is now 999
    }

    // Storage struct reference
    function storageStructReference() public {
        users.push(User("Bob", 30));

        // Storage reference to struct
        User storage userRef = users[0];
        userRef.name = "Robert"; // Modifies actual storage
    }

    // ============================================================================
    // 6. MEMORY COPIES
    // ============================================================================
    // Memory assignments create copies
    // Modifications don't affect originals

    function memoryCopy() public view returns (uint256) {
        // Memory copy from storage
        uint256[] memory arrayCopy = storageArray;
        arrayCopy[0] = 999; // Only modifies copy

        // storageArray remains unchanged
        return storageArray[0];
    }

    // Memory to memory also creates copy
    function memoryToMemory()
        public
        pure
        returns (uint256[] memory, uint256[] memory)
    {
        uint256[] memory arr1 = new uint256[](3);
        arr1[0] = 10;
        arr1[1] = 20;
        arr1[2] = 30;

        // Creates a copy
        uint256[] memory arr2 = arr1;
        arr2[0] = 999;

        // arr1[0] is still 10
        return (arr1, arr2);
    }

    // ============================================================================
    // 7. DATA LOCATION FOR COMPLEX TYPES
    // ============================================================================

    // Arrays
    function arrayLocations() public {
        // Storage array (state variable)
        // uint256[] public storageArray;  // Already declared

        // Memory array
        uint256[] memory memArray = new uint256[](5);

        // Cannot declare storage array in function
        // uint256[] storage localStorage;  // ERROR
    }

    // Strings
    function stringLocations(
        string memory memStr,
        string calldata calldataStr
    ) external pure returns (string memory) {
        // Memory string can be modified
        memStr = "Modified";

        // Calldata string cannot be modified
        // calldataStr = "Error";  // ERROR

        return memStr;
    }

    // Structs
    function structLocations() public {
        // Memory struct
        User memory memUser = User("Alice", 25);
        memUser.age = 30; // Can modify

        // Storage struct
        users.push(User("Bob", 40));
        User storage storageUser = users[0];
        storageUser.age = 45; // Modifies storage
    }

    // ============================================================================
    // 8. DEFAULT DATA LOCATIONS
    // ============================================================================

    // State variables: always storage (no keyword needed)
    uint256 public stateVar;

    // Function parameters
    function defaultLocations(
        uint256 valueType, // Value types don't have location
        string memory refTypeMemory, // Reference types need explicit location
        string calldata refTypeCalldata // Calldata for external only
    ) external pure returns (uint256) {
        // Local value types: stored in stack/memory automatically
        uint256 localValue = 100;

        // Local reference types: must specify location
        string memory localString = "Hello";
        uint256[] memory localArray = new uint256[](5);

        return localValue;
    }

    // ============================================================================
    // 9. GAS OPTIMIZATION
    // ============================================================================

    // BAD: Using memory for external parameters
    function badGasUsage(
        uint256[] memory numbers
    ) external pure returns (uint256) {
        return numbers[0];
    }

    // GOOD: Using calldata for external parameters
    function goodGasUsage(
        uint256[] calldata numbers
    ) external pure returns (uint256) {
        return numbers[0];
    }

    // Reading from storage multiple times
    function badStorageReads() public view returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < storageArray.length; i++) {
            result += storageArray[i]; // Multiple SLOAD operations
        }
        return result;
    }

    // Cache storage in memory
    function goodStorageReads() public view returns (uint256) {
        uint256[] memory cached = storageArray; // One SLOAD per element
        uint256 result = 0;
        for (uint256 i = 0; i < cached.length; i++) {
            result += cached[i]; // Memory reads (cheaper)
        }
        return result;
    }

    // ============================================================================
    // 10. STORAGE LAYOUT
    // ============================================================================
    // Understanding how storage is organized

    // Storage slots (32 bytes each)
    uint256 slot0 = 100; // Slot 0
    uint256 slot1 = 200; // Slot 1
    uint128 slot2a = 300; // Slot 2 (first 16 bytes)
    uint128 slot2b = 400; // Slot 2 (second 16 bytes) - PACKED
    address slot3 = address(0); // Slot 3

    // Packing small variables saves gas
    struct Packed {
        uint128 a; // }
        uint128 b; // } Both in same slot
    }

    struct Unpacked {
        uint256 a; // Full slot
        uint256 b; // Full slot
    }

    // ============================================================================
    // 11. MAPPINGS AND DATA LOCATION
    // ============================================================================

    mapping(address => User) public userMapping;

    function mappingLocation() public {
        // Mappings are always storage
        // Cannot be memory or calldata

        // Storage reference to mapping value
        User storage user = userMapping[msg.sender];
        user.name = "Updated";

        // Memory copy from mapping
        User memory userCopy = userMapping[msg.sender];
        userCopy.name = "Changed"; // Doesn't affect storage
    }

    // ============================================================================
    // 12. NESTED DATA STRUCTURES
    // ============================================================================

    struct ComplexStruct {
        uint256 id;
        string name;
        uint256[] numbers;
    }

    ComplexStruct[] public complexArray;

    function nestedDataLocations() public {
        complexArray.push(
            ComplexStruct({id: 1, name: "Test", numbers: new uint256[](0)})
        );

        // Storage reference to nested structure
        ComplexStruct storage item = complexArray[0];
        item.numbers.push(100); // Modifies storage

        // Memory copy
        ComplexStruct memory itemCopy = complexArray[0];
        // itemCopy.numbers.push(200); // ERROR: Cannot push to memory array
        // Memory arrays have fixed size, can only modify existing elements
    }

    // ============================================================================
    // 13. RETURN VALUES AND DATA LOCATIONS
    // ============================================================================

    // Return memory (most common)
    function returnMemory() public pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](3);
        arr[0] = 1;
        arr[1] = 2;
        arr[2] = 3;
        return arr;
    }

    // Return storage (rare, usually for view functions)
    function returnStorage() public view returns (uint256[] memory) {
        return storageArray; // Automatically converts to memory
    }

    // Return calldata (external functions)
    function returnCalldata(
        string calldata text
    ) external pure returns (string calldata) {
        return text;
    }

    // ============================================================================
    // 14. COMMON PITFALLS
    // ============================================================================

    // ❌ PITFALL 1: Unintended storage reference
    function pitfall1() public {
        users.push(User("Alice", 25));

        // Intended: Memory copy
        // Actual: Storage reference (if not specified)
        // User user = users[0];  // ERROR in 0.5.0+: Must specify data location

        // Correct:
        User memory user = users[0]; // Memory copy
    }

    // ❌ PITFALL 2: Modifying memory doesn't affect storage
    function pitfall2() public {
        users.push(User("Bob", 30));

        User memory user = users[0];
        user.age = 40; // Only changes memory copy!

        // users[0].age is still 30
    }

    // ✅ CORRECT: Use storage reference
    function correctModification() public {
        users.push(User("Charlie", 35));

        User storage user = users[0];
        user.age = 40; // Modifies actual storage
    }

    // ❌ PITFALL 3: Unnecessary memory copies
    function pitfall3() public view returns (uint256) {
        // Unnecessary copy
        uint256[] memory arr = storageArray;
        return arr[0];

        // Better:
        // return storageArray[0];
    }

    // ============================================================================
    // 15. BEST PRACTICES
    // ============================================================================

    // ✅ Use calldata for external function parameters (gas efficient)
    function bestPractice1(
        string calldata text
    ) external pure returns (bytes32) {
        return keccak256(bytes(text));
    }

    // ✅ Cache storage values in memory for multiple reads
    function bestPractice2() public view returns (uint256) {
        uint256 number = storageNumber; // Cache in local variable

        return number * 2 + number * 3; // Multiple uses
    }

    // ✅ Use storage references to modify state
    function bestPractice3() public {
        User storage user = users[0];
        user.name = "Updated";
        user.age = 30;
    }

    // ✅ Use memory for temporary computations
    function bestPractice4() public pure returns (uint256) {
        uint256[] memory temp = new uint256[](100);
        for (uint256 i = 0; i < 100; i++) {
            temp[i] = i * 2;
        }
        return temp[50];
    }

    // ============================================================================
    // KEY TAKEAWAYS FOR PROFESSIONAL DEVELOPERS:
    // ============================================================================
    // 1. storage: Permanent, expensive, for state variables
    // 2. memory: Temporary, medium cost, modifiable
    // 3. calldata: Temporary, cheapest, read-only, external only
    // 4. **Use calldata for external function parameters** (gas optimization)
    // 5. Storage references modify actual state
    // 6. Memory assignments create copies
    // 7. Cache storage reads in memory for loops
    // 8. Value types (uint, bool, address) don't need location specifier
    // 9. Reference types (arrays, structs, strings) require explicit location
    // 10. Mappings are always storage
    // 11. Pack small storage variables to save gas
    // 12. Memory to memory creates copies (not references)
    // 13. External functions with calldata save ~3x gas vs memory
    // 14. Understanding data locations prevents bugs
    // 15. Always specify data location for reference types in functions
    // ============================================================================
}

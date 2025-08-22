// License
// SPDX-License-Identifier: LGPL-3.0-only

// Version
pragma solidity 0.8.24;

// ============================================================================
// COMPLETE SOLIDITY DATA TYPES REFERENCE - Version 0.8.24
// ============================================================================

contract DataTypes {
    
    // ========================================================================
    // 1. VALUE TYPES (stored directly in the variable's memory location)
    // ========================================================================
    
    // ------------------------------------------------------------------------
    // 1.1 BOOLEAN TYPE
    // ------------------------------------------------------------------------
    // Can only have two values: true or false
    // Default value: false
    // Used for logical operations and conditions
    bool public boolExample1 = true;
    bool public boolExample2 = false;
    
    // ------------------------------------------------------------------------
    // 1.2 UNSIGNED INTEGERS (uint) - Only non-negative numbers (0 and above)
    // ------------------------------------------------------------------------
    // Available in steps of 8 bits: uint8 to uint256
    // uint is an alias for uint256
    // Default value: 0
    
    uint8   public u8  = 255;                    // Range: 0 to 2^8-1 (255)
    uint16  public u16 = 65535;                  // Range: 0 to 2^16-1 (65,535)
    uint32  public u32 = 4294967295;             // Range: 0 to 2^32-1 (~4.29 billion)
    uint64  public u64 = 18446744073709551615;   // Range: 0 to 2^64-1
    uint128 public u128 = 340282366920938463463374607431768211455; // Range: 0 to 2^128-1
    uint256 public u256 = 115792089237316195423570985008687907853269984665640564039457584007913129639935; // Range: 0 to 2^256-1
    
    // uint is equivalent to uint256 (most commonly used)
    uint public defaultUint = 1000;
    
    // Other available sizes: uint24, uint40, uint48, uint56, uint72, uint80, uint88, uint96, 
    // uint104, uint112, uint120, uint136, uint144, uint152, uint160, uint168, uint176, uint184, 
    // uint192, uint200, uint208, uint216, uint224, uint232, uint240, uint248
    
    // ------------------------------------------------------------------------
    // 1.3 SIGNED INTEGERS (int) - Can represent negative and positive numbers
    // ------------------------------------------------------------------------
    // Available in steps of 8 bits: int8 to int256
    // int is an alias for int256
    // Default value: 0
    
    int8   public i8  = -128;                    // Range: -2^7 to 2^7-1 (-128 to 127)
    int16  public i16 = -32768;                  // Range: -2^15 to 2^15-1 (-32,768 to 32,767)
    int32  public i32 = -2147483648;             // Range: -2^31 to 2^31-1
    int64  public i64 = -9223372036854775808;    // Range: -2^63 to 2^63-1
    int128 public i128 = -170141183460469231731687303715884105728; // Range: -2^127 to 2^127-1
    int256 public i256 = -57896044618658097711785492504343953926634992332820282019728792003956564819968; // Range: -2^255 to 2^255-1
    
    // int is equivalent to int256
    int public defaultInt = -500;
    
    // Same intermediate sizes available as uint: int24, int40, int48, etc.
    
    // ------------------------------------------------------------------------
    // 1.4 ADDRESS TYPES
    // ------------------------------------------------------------------------
    // Represents a 20-byte Ethereum address
    // Default value: 0x0000000000000000000000000000000000000000
    
    // address - basic address type
    address public basicAddress = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    
    // address payable - address that can receive Ether (has transfer and send methods)
    address payable public payableAddress = payable(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2);
    
    // Special address properties:
    // - balance: returns the balance in Wei
    // - code: returns the contract code
    // - codehash: returns the keccak256 hash of the code
    
    // ------------------------------------------------------------------------
    // 1.5 FIXED-SIZE BYTE ARRAYS (bytes1 to bytes32)
    // ------------------------------------------------------------------------
    // More gas-efficient than dynamic bytes for fixed sizes
    // Default value: all bits set to 0
    
    bytes1  public b1  = 0x41;                   // 1 byte  = 8 bits  (hex: 2 characters)
    bytes2  public b2  = 0x4142;                 // 2 bytes = 16 bits (hex: 4 characters)
    bytes4  public b4  = 0x41424344;             // 4 bytes = 32 bits (hex: 8 characters)
    bytes8  public b8  = 0x4142434445464748;     // 8 bytes = 64 bits
    bytes16 public b16 = 0x41424344454647484950515253545556; // 16 bytes = 128 bits
    bytes32 public b32 = 0x4142434445464748495051525354555657585960616263646566676869707172; // 32 bytes = 256 bits (most common)
    
    // Other available sizes: bytes3, bytes5, bytes6, bytes7, bytes9, bytes10, bytes11, bytes12,
    // bytes13, bytes14, bytes15, bytes17, bytes18, bytes19, bytes20, bytes21, bytes22, bytes23,
    // bytes24, bytes25, bytes26, bytes27, bytes28, bytes29, bytes30, bytes31
    
    // ------------------------------------------------------------------------
    // 1.6 ENUMS (User-defined types)
    // ------------------------------------------------------------------------
    // Enumeration of named constants (internally represented as uint8)
    // Default value: first element (0)
    // Used to create custom types with a restricted set of values
    
    enum Status { 
        Pending,      // 0
        Approved,     // 1
        Rejected,     // 2
        Cancelled     // 3
    }
    
    enum OrderState {
        Created,
        Paid,
        Shipped,
        Delivered,
        Completed
    }
    
    Status public currentStatus = Status.Pending;
    OrderState public orderState;
    
    // ========================================================================
    // 2. REFERENCE TYPES (store a reference to the data location)
    // ========================================================================
    
    // ------------------------------------------------------------------------
    // 2.1 ARRAYS
    // ------------------------------------------------------------------------
    
    // Fixed-size array - size defined at declaration, cannot be changed
    uint256[5] public fixedArray = [1, 2, 3, 4, 5];
    address[3] public addressArray;
    bool[10] public boolArray;
    
    // Dynamic array - size can change (push, pop operations)
    uint256[] public dynamicArray;
    string[] public stringArray;
    address[] public dynamicAddressArray;
    
    // Multidimensional arrays
    uint256[][] public twoDimensionalArray;
    uint256[3][4] public fixedMultiArray; // 4 arrays of 3 elements each
    
    // Array of structs
    Person[] public people;
    
    // ------------------------------------------------------------------------
    // 2.2 STRINGS
    // ------------------------------------------------------------------------
    // Dynamic UTF-8 encoded text data
    // Internally stored as bytes
    // More expensive than bytes for storage
    // Default value: empty string ""
    
    string public greeting = "Hello, Solidity!";
    string public emptyString;
    string public unicodeString = "Hello Word!";
    
    // ------------------------------------------------------------------------
    // 2.3 BYTES (dynamic byte array)
    // ------------------------------------------------------------------------
    // Similar to string but for arbitrary-length raw byte data
    // More gas-efficient than string for binary data
    // Default value: empty bytes
    
    bytes public dynamicBytes = "0x123456";
    bytes public emptyBytes;
    
    // ------------------------------------------------------------------------
    // 2.4 STRUCTS (Custom composite types)
    // ------------------------------------------------------------------------
    // Group related data of different types together
    // Can contain any value types, arrays, mappings, or other structs
    
    struct Person {
        string name;
        uint256 age;
        address wallet;
        bool isActive;
    }
    
    struct Book {
        string title;
        string author;
        uint256 pages;
        bool available;
        uint256 publishYear;
    }
    
    struct ComplexStruct {
        uint256 id;
        string data;
        address owner;
        uint256[] numbers;
        mapping(address => uint256) balances; // Note: structs with mappings can't be passed as function parameters
    }
    
    Person public person1;
    Book public book1;
    
    // ------------------------------------------------------------------------
    // 2.5 MAPPINGS
    // ------------------------------------------------------------------------
    // Hash table key-value data structure
    // Keys are not stored, only their keccak256 hash is used to look up values
    // All possible keys exist and are initialized to default values
    // Cannot iterate over mappings (no length, no keys list)
    // Can only have storage data location
    
    // Simple mappings
    mapping(address => uint256) public balances;           // Address to balance
    mapping(uint256 => string) public idToName;            // ID to name
    mapping(address => bool) public whitelist;             // Address to boolean flag
    mapping(bytes32 => address) public hashToAddress;      // Hash to address
    
    // Nested mappings
    mapping(address => mapping(uint256 => bool)) public nestedMapping1; // Address to ID to boolean
    mapping(address => mapping(address => uint256)) public allowances;  // ERC20 allowances pattern
    
    // Mapping with struct values
    mapping(address => Person) public addressToPerson;
    
    // Mapping with array values
    mapping(address => uint256[]) public addressToNumbers;
    
    // ========================================================================
    // 3. SPECIAL TYPES & LITERALS
    // ========================================================================
    
    // ------------------------------------------------------------------------
    // 3.1 FUNCTION TYPES
    // ------------------------------------------------------------------------
    // Functions can be assigned to variables and passed as parameters
    
    // Internal function type (can only be called within the contract)
    function(uint256, uint256) internal pure returns (uint256) private mathOperation;
    
    // External function type (can be called from other contracts)
    function(uint256) external view returns (uint256) public externalFunction;
    
    // ------------------------------------------------------------------------
    // 3.2 CONTRACT TYPES
    // ------------------------------------------------------------------------
    // Variables can hold contract instances
    // Contracts can be explicitly converted to/from address
    
    DataTypes public anotherContract;
    
    // ------------------------------------------------------------------------
    // 3.3 LITERALS
    // ------------------------------------------------------------------------
    
    // Integer literals
    uint256 public decimalLiteral = 1000;
    uint256 public hexLiteral = 0x3E8;           // 1000 in hex
    uint256 public scientificLiteral = 1e3;      // 1000 in scientific notation
    uint256 public withUnderscores = 1_000_000;  // Underscores for readability (Solidity 0.5.0+)
    
    // Address literals
    address public addressLiteral = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    
    // String literals
    string public stringLiteral1 = "Double quotes";
    string public stringLiteral2 = 'Single quotes';
    string public stringLiteral3 = unicode"Unicode: 😀";
    string public hexStringLiteral = hex"48656c6c6f"; // "Hello" in hex
    
    // Boolean literals
    bool public trueLiteral = true;
    bool public falseLiteral = false;
    
    // ========================================================================
    // 4. DATA LOCATION SPECIFIERS (for reference types)
    // ========================================================================
    
    // storage   - persistent data stored on blockchain (state variables)
    // memory    - temporary data erased between external function calls
    // calldata  - non-modifiable, temporary location for function parameters (gas efficient)
    
    // Examples in functions:
    function dataLocationExample(
        string calldata _calldataParam,  // Most gas efficient for external function parameters
        string memory _memoryParam        // Modifiable temporary variable
    ) external pure returns (string memory) {
        // string storage storageVar;     // Would reference a state variable
        string memory memoryVar = _memoryParam; // Local temporary variable
        return memoryVar;
    }
    
    // ========================================================================
    // 5. VISIBILITY SPECIFIERS
    // ========================================================================
    
    // public    - accessible from anywhere (generates automatic getter)
    // private   - only accessible within this contract
    // internal  - accessible within this contract and derived contracts (default for state variables)
    // external  - only for functions, callable from outside (not from within)
    
    uint256 public publicVar = 100;
    uint256 private privateVar = 200;
    uint256 internal internalVar = 300;
    
    // ========================================================================
    // 6. CONSTANTS AND IMMUTABLES
    // ========================================================================
    
    // constant - value must be fixed at compile-time, cannot be modified
    // More gas efficient than regular state variables
    uint256 public constant CONSTANT_VALUE = 1000;
    address public constant CONSTANT_ADDRESS = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    string public constant CONSTANT_STRING = "This never changes";
    
    // immutable - value can be set in constructor, cannot be modified after deployment
    // More gas efficient than regular state variables, but more flexible than constant
    uint256 public immutable IMMUTABLE_VALUE;
    address public immutable IMMUTABLE_OWNER;
    
    constructor() {
        IMMUTABLE_VALUE = 5000;
        IMMUTABLE_OWNER = msg.sender;
    }
    
    // ========================================================================
    // 7. DEFAULT VALUES
    // ========================================================================
    // All types have default values when declared but not initialized:
    
    bool public defaultBool;            // false
    uint256 public defaultUint256;      // 0
    int256 public defaultInt256;        // 0
    address public defaultAddress;      // 0x0000000000000000000000000000000000000000
    bytes32 public defaultBytes32;      // 0x0000000000000000000000000000000000000000000000000000000000000000
    string public defaultString;        // "" (empty string)
    bytes public defaultBytes;          // "" (empty bytes)
    
    // Enums default to first value (index 0)
    Status public defaultStatus;        // Status.Pending (0)
    
    // ========================================================================
    // 8. USER-DEFINED VALUE TYPES (Solidity 0.8.8+)
    // ========================================================================
    // Create custom types with underlying value types for better type safety
    
    type Price is uint256;
    type TokenId is uint256;
    type AccountId is bytes32;
    
    Price public itemPrice;
    TokenId public nftId;
    
    // ========================================================================
    // 9. TYPE INFERENCE WITH var (DEPRECATED - DO NOT USE)
    // ========================================================================
    // Note: 'var' keyword was removed in Solidity 0.5.0
    // Always explicitly declare types
    
    // ========================================================================
    // ADDITIONAL NOTES:
    // ========================================================================
    // 1. Solidity 0.8.0+ has built-in overflow/underflow checks
    // 2. Use 'unchecked' block to disable overflow checks for gas optimization
    // 3. Smaller types (< 32 bytes) don't save gas in storage, only in memory
    // 4. Pack multiple small variables together to save storage slots
    // 5. Use appropriate type sizes to avoid unnecessary gas costs
    // ========================================================================
}
// License
// SPDX-License-Identifier: LGPL-3.0-only

// Version
pragma solidity 0.8.24;

// ============================================================================
// COMPLETE SOLIDITY FUNCTIONS REFERENCE - Version 0.8.24
// ============================================================================

contract Functions {
    
    // ========================================================================
    // 1. STATE VARIABLES & STORAGE
    // ========================================================================
    
    address public owner;
    uint256 public counter;
    uint256 public balance;
    
    mapping(address => uint256) public userBalances;
    
    // ========================================================================
    // 2. CUSTOM ERRORS (Solidity 0.8.4+)
    // ========================================================================
    // More gas-efficient than require with string messages
    // Provide better error handling and can include parameters
    
    error Unauthorized(address caller);
    error InsufficientBalance(uint256 available, uint256 required);
    error InvalidAmount(uint256 amount);
    error NotEven(uint256 number);
    error TransferFailed();
    error ExampleNameError(string message, uint256 code);
    
    // ========================================================================
    // 3. EVENTS
    // ========================================================================
    // Used to log information on the blockchain
    // Can be listened to by external applications (frontend, indexers)
    // Indexed parameters allow filtering (max 3 indexed parameters)
    // More gas-efficient than storing data in state
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Multiplied(uint256 num1, uint256 num2, uint256 result);
    event PaymentReceived(address indexed payer, uint256 amount, uint256 timestamp);
    event DataUpdated(string indexed key, string value);
    event MultipleValues(uint256 indexed id, string name, bool status, bytes data);
    
    // ========================================================================
    // 4. MODIFIERS
    // ========================================================================
    // Used to modify function behavior
    // Common uses: access control, validation, state checks
    // Can take parameters and be chained
    // Use _ to indicate where the function body executes
    
    // Basic access control modifier
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Unauthorized(msg.sender);
        }
        _;
    }
    
    // Modifier with parameters
    modifier onlyEven(uint256 num) {
        if (num % 2 != 0) {
            revert NotEven(num);
        }
        _;
    }
    
    // Modifier with pre and post conditions
    modifier incrementCounter() {
        counter++; // Executes BEFORE the function
        _;
        // Code here would execute AFTER the function
    }
    
    // Modifier with validation
    modifier validAmount(uint256 amount) {
        if (amount == 0) {
            revert InvalidAmount(amount);
        }
        _;
    }
    
    // Modifier checking contract state
    modifier sufficientBalance(uint256 required) {
        if (balance < required) {
            revert InsufficientBalance(balance, required);
        }
        _;
    }
    
    // ========================================================================
    // 5. CONSTRUCTOR
    // ========================================================================
    // Special function executed ONLY ONCE when contract is deployed
    // Used to initialize state variables
    // Can be payable to receive Ether during deployment
    // Cannot be called again after deployment
    
    constructor() {
        owner = msg.sender;
        balance = 0;
        counter = 0;
        emit OwnershipTransferred(address(0), msg.sender);
    }
    
    // Example of payable constructor (not used here but shown for reference)
    // constructor() payable {
    //     owner = msg.sender;
    //     balance = msg.value;
    // }
    
    // ========================================================================
    // 6. FUNCTION VISIBILITY MODIFIERS
    // ========================================================================
    
    // ------------------------------------------------------------------------
    // 6.1 PUBLIC FUNCTIONS
    // ------------------------------------------------------------------------
    // Can be called:
    // - Internally (from within the contract)
    // - Externally (from other contracts or transactions)
    // - By derived contracts
    // Automatically creates a getter for state variables
    // More gas expensive when called internally (creates internal call)
    
    function publicFunction(uint256 num1, uint256 num2) 
        public 
        pure 
        returns (uint256) 
    {
        return num1 + num2;
    }
    
    // Public function with state modification
    function publicSetBalance(uint256 newBalance) public onlyOwner {
        balance = newBalance;
    }
    
    // ------------------------------------------------------------------------
    // 6.2 EXTERNAL FUNCTIONS
    // ------------------------------------------------------------------------
    // Can ONLY be called:
    // - From outside the contract (other contracts or transactions)
    // Cannot be called internally (must use this.functionName() for internal calls)
    // More gas efficient than public for external calls
    // Best practice: use external for functions only called externally
    
    function externalFunction(uint256 num1, uint256 num2) 
        external 
        pure 
        returns (uint256) 
    {
        return num1 * num2;
    }
    
    // External function with state modification and event
    function externalMultiply(uint256 num1, uint256 num2) 
        external 
        onlyOwner 
        returns (uint256 result) 
    {
        result = num1 * num2;
        emit Multiplied(num1, num2, result);
    }
    
    // ------------------------------------------------------------------------
    // 6.3 INTERNAL FUNCTIONS
    // ------------------------------------------------------------------------
    // Can be called:
    // - From within the contract
    // - By derived contracts (inheritance)
    // Cannot be called externally
    // Convention: prefix with underscore (_functionName)
    // Used for helper/utility functions
    
    function _internalAdd(uint256 a, uint256 b) 
        internal 
        pure 
        returns (uint256) 
    {
        return a + b;
    }
    
    function _internalUpdateBalance(uint256 amount) internal {
        balance += amount;
    }
    
    // Internal function used by public function
    function useInternalFunction(uint256 a, uint256 b) 
        public 
        pure 
        returns (uint256) 
    {
        return _internalAdd(a, b);
    }
    
    // ------------------------------------------------------------------------
    // 6.4 PRIVATE FUNCTIONS
    // ------------------------------------------------------------------------
    // Can ONLY be called from within THIS contract
    // Cannot be called by derived contracts
    // Most restrictive visibility
    // Convention: prefix with underscore (_functionName)
    // Used for internal implementation details
    
    function _privateMultiply(uint256 a, uint256 b) 
        private 
        pure 
        returns (uint256) 
    {
        return a * b;
    }
    
    function _privateHelper() private view returns (address) {
        return owner;
    }
    
    // ========================================================================
    // 7. STATE MUTABILITY MODIFIERS
    // ========================================================================
    
    // ------------------------------------------------------------------------
    // 7.1 VIEW FUNCTIONS
    // ------------------------------------------------------------------------
    // Can READ state variables but CANNOT modify them
    // Can read: state variables, other view/pure functions
    // Cannot: modify state, emit events, create contracts, send Ether, call non-view functions
    // No gas cost when called externally (off-chain)
    // Gas cost applies when called by another contract
    
    function viewGetOwner() public view returns (address) {
        return owner;
    }
    
    function viewGetBalance() public view returns (uint256) {
        return balance;
    }
    
    function viewComplexCalculation(uint256 multiplier) 
        public 
        view 
        returns (uint256) 
    {
        return balance * multiplier + counter;
    }
    
    // View function reading from mapping
    function viewUserBalance(address user) public view returns (uint256) {
        return userBalances[user];
    }
    
    // ------------------------------------------------------------------------
    // 7.2 PURE FUNCTIONS
    // ------------------------------------------------------------------------
    // Cannot READ or MODIFY state variables
    // Only uses function parameters and local variables
    // Most restrictive - completely isolated from blockchain state
    // No gas cost when called externally
    // Used for utility functions and calculations
    
    function pureAdd(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }
    
    function pureMultiply(uint256 a, uint256 b) public pure returns (uint256) {
        return a * b;
    }
    
    // Pure function with modifiers
    function pureMultiplyEven(uint256 a, uint256 b) 
        public 
        pure 
        onlyEven(a) 
        onlyEven(b) 
        returns (uint256) 
    {
        return a * b;
    }
    
    // Pure function with complex logic
    function pureCalculateDiscount(uint256 price, uint256 discountPercent) 
        public 
        pure 
        returns (uint256) 
    {
        if (discountPercent > 100) {
            return 0;
        }
        return price - (price * discountPercent) / 100;
    }
    
    // ------------------------------------------------------------------------
    // 7.3 PAYABLE FUNCTIONS
    // ------------------------------------------------------------------------
    // Can RECEIVE Ether (msg.value > 0)
    // Without payable, function will reject Ether transfers
    // Used for functions that handle payments
    // Access msg.value to get amount of Ether sent
    
    function payableDeposit() public payable {
        if (msg.value == 0) {
            revert InvalidAmount(0);
        }
        balance += msg.value;
        userBalances[msg.sender] += msg.value;
        emit PaymentReceived(msg.sender, msg.value, block.timestamp);
    }
    
    function payableReceivePayment() external payable validAmount(msg.value) {
        balance += msg.value;
    }
    
    // Payable with access control
    function payableOwnerDeposit() external payable onlyOwner {
        balance += msg.value;
    }
    
    // ========================================================================
    // 8. SPECIAL FUNCTIONS
    // ========================================================================
    
    // ------------------------------------------------------------------------
    // 8.1 RECEIVE FUNCTION
    // ------------------------------------------------------------------------
    // Called when:
    // - Ether is sent to contract with EMPTY calldata
    // - Plain Ether transfers (address.transfer(), address.send())
    // Must be: external payable
    // Only ONE receive function per contract
    // Cannot have parameters or return values
    // Should be simple (low gas usage)
    
    receive() external payable {
        balance += msg.value;
        userBalances[msg.sender] += msg.value;
        emit PaymentReceived(msg.sender, msg.value, block.timestamp);
    }
    
    // ------------------------------------------------------------------------
    // 8.2 FALLBACK FUNCTION
    // ------------------------------------------------------------------------
    // Called when:
    // - Function signature doesn't match any existing function
    // - Ether is sent with data but no receive() exists
    // - No receive() and no matching function
    // Must be: external
    // Can be payable (to accept Ether)
    // Only ONE fallback function per contract
    // Should be simple (limited gas in some scenarios)
    
    fallback() external payable {
        // Log unexpected calls
        emit DataUpdated("fallback", "called");
    }
    
    // Example of non-payable fallback (rejects Ether)
    // fallback() external {
    //     revert("Fallback called");
    // }
    
    // ========================================================================
    // 9. RETURN VALUES & PATTERNS
    // ========================================================================
    
    // ------------------------------------------------------------------------
    // 9.1 SINGLE RETURN VALUE
    // ------------------------------------------------------------------------
    
    function singleReturn(uint256 x) public pure returns (uint256) {
        return x * 2;
    }
    
    // Named return variable (automatically returned)
    function namedSingleReturn(uint256 x) public pure returns (uint256 result) {
        result = x * 2;
        // Implicit return
    }
    
    // Named return with explicit return
    function namedExplicitReturn(uint256 x) public pure returns (uint256 result) {
        result = x * 2;
        return result;
    }
    
    // ------------------------------------------------------------------------
    // 9.2 MULTIPLE RETURN VALUES
    // ------------------------------------------------------------------------
    
    function multipleReturns(uint256 x) 
        public 
        pure 
        returns (uint256, uint256, uint256) 
    {
        return (x, x * 2, x * 3);
    }
    
    // Named multiple returns
    function namedMultipleReturns(uint256 x) 
        public 
        pure 
        returns (uint256 original, uint256 doubled, uint256 tripled) 
    {
        original = x;
        doubled = x * 2;
        tripled = x * 3;
    }
    
    // Destructuring multiple returns
    function useMultipleReturns() public pure returns (uint256) {
        (uint256 a, uint256 b, uint256 c) = multipleReturns(5);
        return a + b + c;
    }
    
    // Partial destructuring (skip values with empty slots)
    function partialDestructuring() public pure returns (uint256) {
        (, uint256 doubled, ) = multipleReturns(5);
        return doubled;
    }
    
    // ------------------------------------------------------------------------
    // 9.3 RETURNING COMPLEX TYPES
    // ------------------------------------------------------------------------
    
    // Return array
    function returnArray() public pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](3); // Create dynamic array in memory
        arr[0] = 1;
        arr[1] = 2;
        arr[2] = 3;
        return arr;
    }
    
    // Return string
    function returnString(string memory name) 
        public 
        pure 
        returns (string memory) 
    {
        return string(abi.encodePacked("Hello, ", name)); // Concatenate string
    }
    
    // Return struct (must define struct first)
    struct UserInfo {
        address userAddress;
        uint256 userBalance;
        bool isActive;
    }
    
    function returnStruct(address user) 
        public 
        view 
        returns (UserInfo memory) 
    {
        return UserInfo({
            userAddress: user,
            userBalance: userBalances[user],
            isActive: true
        });
    }
    
    // ========================================================================
    // 10. FUNCTION OVERLOADING
    // ========================================================================
    // Multiple functions with same name but different parameters
    // Solidity resolves based on parameter types and count
    // Return type alone is NOT enough to distinguish
    // Be careful with type conversions (can cause ambiguity)
    
    // Overload 1: Single parameter
    function calculate(uint256 x) public pure returns (uint256) {
        return x * 2;
    }
    
    // Overload 2: Two parameters
    function calculate(uint256 x, uint256 y) public pure returns (uint256) {
        return x * y;
    }
    
    // Overload 3: Different parameter type
    function calculate(int256 x) public pure returns (int256) {
        return x * 2;
    }
    
    // Overload 4: String parameter
    function process(string memory text) public pure returns (string memory) {
        return string(abi.encodePacked("Text: ", text)); // Concatenate string
    }
    
    // Overload 5: Uint parameter
    function process(uint256 num) public pure returns (uint256) {
        return num * 10;
    }
    
    // Overload 6: Address parameter
    function process(address addr) public pure returns (address) {
        return addr;
    }
    
    // ========================================================================
    // 11. ADVANCED FUNCTION PATTERNS
    // ========================================================================
    
    // ------------------------------------------------------------------------
    // 11.1 FUNCTION WITH MULTIPLE MODIFIERS
    // ------------------------------------------------------------------------
    // Modifiers execute in order from left to right
    
    function multipleModifiers(uint256 amount) 
        public 
        onlyOwner 
        validAmount(amount) 
        sufficientBalance(amount) 
        incrementCounter 
        returns (bool) 
    {
        balance -= amount;
        return true;
    }
    
    // ------------------------------------------------------------------------
    // 11.2 VIRTUAL AND OVERRIDE (Inheritance)
    // ------------------------------------------------------------------------
    // virtual: function can be overridden by derived contracts
    // override: function overrides a parent function
    
    function virtualFunction() public virtual pure returns (string memory) {
        return "Base implementation";
    }
    
    // ------------------------------------------------------------------------
    // 11.3 FUNCTIONS WITH MEMORY/CALLDATA
    // ------------------------------------------------------------------------
    
    // calldata: most gas-efficient, read-only, for external function parameters
    function calldataExample(string calldata text) 
        external 
        pure 
        returns (string calldata) 
    {
        return text;
    }
    
    // memory: modifiable, temporary storage
    function memoryExample(uint256[] memory numbers) 
        public 
        pure 
        returns (uint256) 
    {
        numbers[0] = 999; // Can modify
        return numbers[0];
    }
    
    // storage: reference to state variable (persistent)
    mapping(uint256 => uint256[]) public storedArrays;
    
    function storageExample(uint256 id) public returns (uint256) {
        uint256[] storage arr = storedArrays[id]; // Reference to state
        arr.push(100); // Modifies state permanently
        return arr.length;
    }
    
    // ------------------------------------------------------------------------
    // 11.4 ASSEMBLY FUNCTIONS (Advanced)
    // ------------------------------------------------------------------------
    // Inline assembly for gas optimization and low-level operations
    
    function assemblyExample(uint256 x) public pure returns (uint256 result) {
        assembly {
            result := mul(x, 2)
        }
    }
    
    // ------------------------------------------------------------------------
    // 11.5 TRY/CATCH (Error Handling)
    // ------------------------------------------------------------------------
    // Available for external function calls and contract creation
    // Cannot be used with internal function calls
    
    function tryCatchExample(address target) public returns (bool success) {
        try Functions(payable(target)).publicFunction(10, 20) returns (uint256 result) {
            // Success path
            balance = result;
            return true;
        } catch Error(string memory reason) {
            // Catch revert with reason string
            emit DataUpdated("error", reason);
            return false;
        } catch Panic(uint256 errorCode) {
            // Catch panic errors (assert failures, overflow, etc.)
            emit MultipleValues(errorCode, "panic", false, "");
            return false;
        } catch (bytes memory lowLevelData) {
            // Catch all other errors
            emit MultipleValues(0, "unknown", false, lowLevelData);
            return false;
        }
    }
    
    // ========================================================================
    // 12. FUNCTION SELECTORS & ABI ENCODING
    // ========================================================================
    
    // Get function selector (first 4 bytes of keccak256 hash)
    function getFunctionSelector(string memory signature) 
        public 
        pure 
        returns (bytes4) 
    {
        return bytes4(keccak256(bytes(signature))); // Example: "transfer(address,uint256)"
    }
    
    // Example: getFunctionSelector("transfer(address,uint256)") returns 0xa9059cbb

    
    // ABI encoding examples
    function encodeExample(address addr, uint256 amount) 
        public 
        pure 
        returns (bytes memory) 
    {
        return abi.encode(addr, amount); // Encodes with padding (32 bytes per parameter)
    }
    
    function encodePackedExample(address addr, uint256 amount) 
        public 
        pure 
        returns (bytes memory) 
    {
        return abi.encodePacked(addr, amount); // Encodes without padding (tightly packed)
    }
    
    // ========================================================================
    // 13. BEST PRACTICES & GAS OPTIMIZATION
    // ========================================================================
    
    // 1. Use external for functions only called externally (gas efficient)
    // 2. Use calldata instead of memory for external function parameters
    // 3. Use custom errors instead of require with strings (Solidity 0.8.4+)
    // 4. Use events for data that doesn't need to be accessed on-chain
    // 5. Mark functions as pure/view when appropriate (no gas for external calls)
    // 6. Use unchecked for gas optimization when overflow is impossible
    // 7. Short-circuit evaluation in conditions (check cheapest conditions first)
    // 8. Batch operations to reduce transaction overhead
    // 9. Use function modifiers for common checks (cleaner code)
    // 10. Avoid loops with unbounded iterations
    
    // Gas optimized function example
    function gasOptimized(uint256[] calldata numbers) 
        external 
        pure 
        returns (uint256 total) 
    {
        uint256 length = numbers.length; // Cache array length
        for (uint256 i; i < length; ) {
            unchecked { // Use unchecked for gas optimization (no overflow check)
                total += numbers[i];
                ++i; // Prefix increment is more gas efficient
            }
        }
    }
    
    // ========================================================================
    // 14. AUXILIARY FUNCTIONS FOR EXAMPLES
    // ========================================================================
    
    // Transfer ownership
    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner == address(0)) {
            revert Unauthorized(newOwner);
        }
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
    
    // Withdraw function
    function withdraw(uint256 amount) 
        public 
        onlyOwner 
        sufficientBalance(amount) 
    {
        balance -= amount;
        (bool success, ) = payable(owner).call{value: amount}(""); // Use call for better gas handling and to avoid 2300 gas limit of transfer/send
        if (!success) {
            revert TransferFailed();
        }
    }
    
    // Get contract balance
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
    // ========================================================================
    // END OF FUNCTIONS REFERENCE
    // ========================================================================
}

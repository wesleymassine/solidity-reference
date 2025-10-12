// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY INHERITANCE - Complete Reference
// From Zero to Professional
// ============================================================================

// ============================================================================
// 1. BASIC INHERITANCE
// ============================================================================
// Inheritance allows contracts to inherit properties and methods from parent contracts
// Uses the "is" keyword
// Supports single and multiple inheritance
// Child contracts inherit all non-private members (state variables and functions)

// Simple parent contract
contract Animal {
    string public name;
    uint256 public age;

    event AnimalCreated(string name, uint256 age);

    constructor(string memory _name, uint256 _age) {
        name = _name;
        age = _age;
        emit AnimalCreated(_name, _age);
    }

    // Virtual function - can be overridden by child contracts
    function makeSound() public pure virtual returns (string memory) {
        return "Some generic animal sound";
    }

    function getInfo() public view returns (string memory, uint256) {
        return (name, age);
    }
}

// Child contract inheriting from Animal
contract Dog is Animal {
    string public breed;

    // Constructor must call parent constructor
    constructor(
        string memory _name,
        uint256 _age,
        string memory _breed
    )
        Animal(_name, _age) // Call parent constructor
    {
        breed = _breed;
    }

    // Override parent function
    // Must use "override" keyword
    function makeSound() public pure override returns (string memory) {
        return "Woof! Woof!";
    }

    // New function specific to Dog
    function fetch() public pure returns (string memory) {
        return "Dog is fetching the ball";
    }
}

// ============================================================================
// 2. MULTIPLE INHERITANCE
// ============================================================================
// Solidity supports multiple inheritance
// Order matters: most base-like to most derived
// Uses C3 Linearization (similar to Python)
// If a function is defined in multiple parent contracts, you must override it

contract Flyable {
    function fly() public pure virtual returns (string memory) {
        return "Flying in the sky";
    }
}

contract Swimmable {
    function swim() public pure virtual returns (string memory) {
        return "Swimming in water";
    }
}

// Multiple inheritance: inherits from both Flyable and Swimmable
// Order: from most base-like to most derived
contract Duck is Animal, Flyable, Swimmable {
    constructor(string memory _name, uint256 _age) Animal(_name, _age) {}

    // Override function from Animal
    function makeSound() public pure override returns (string memory) {
        return "Quack! Quack!";
    }

    // Override function from Flyable
    function fly() public pure override returns (string memory) {
        return "Duck is flying";
    }

    // Override function from Swimmable
    function swim() public pure override returns (string memory) {
        return "Duck is swimming";
    }
}

// ============================================================================
// 3. VIRTUAL AND OVERRIDE
// ============================================================================
// virtual: marks a function as overridable by child contracts
// override: indicates that a function overrides a parent function
// Both keywords are required for inheritance to work properly (Solidity 0.6.0+)

contract Parent {
    // Virtual function - can be overridden
    function getValue() public pure virtual returns (uint256) {
        return 100;
    }

    // Non-virtual function - cannot be overridden
    function getFixed() public pure returns (uint256) {
        return 50;
    }
}

contract Child is Parent {
    // Must use override keyword
    function getValue() public pure override returns (uint256) {
        return 200;
    }

    // Cannot override getFixed() - will cause compilation error
    // function getFixed() public pure override returns (uint256) {
    //     return 75;
    // }
}

// ============================================================================
// 4. SUPER KEYWORD
// ============================================================================
// "super" refers to the parent contract
// Used to call parent functions from child contracts
// In multiple inheritance, follows the C3 linearization order

contract GrandParent {
    event Log(string message);

    function logMessage() public virtual {
        emit Log("GrandParent");
    }
}

contract ParentA is GrandParent {
    function logMessage() public virtual override {
        emit Log("ParentA");
        super.logMessage(); // Calls GrandParent.logMessage()
    }
}

contract ParentB is GrandParent {
    function logMessage() public virtual override {
        emit Log("ParentB");
        super.logMessage(); // Calls GrandParent.logMessage()
    }
}

// Multiple inheritance with super
// Linearization order: GrandChild -> ParentB -> ParentA -> GrandParent
contract GrandChild is ParentA, ParentB {
    function logMessage() public override(ParentA, ParentB) {
        emit Log("GrandChild");
        super.logMessage(); // Calls ParentB.logMessage() due to linearization
    }

    // When overriding from multiple parents, must specify all parent contracts
}

// ============================================================================
// 5. ABSTRACT CONTRACTS
// ============================================================================
// Abstract contracts contain at least one unimplemented function
// Cannot be deployed directly
// Must be inherited and implemented by child contracts
// Use "abstract" keyword
// Functions without implementation must be marked "virtual"

abstract contract AbstractAnimal {
    string public name;

    constructor(string memory _name) {
        name = _name;
    }

    // Abstract function - no implementation
    // Must be implemented by child contracts
    function makeSound() public pure virtual returns (string memory);

    // Concrete function - has implementation
    function getName() public view returns (string memory) {
        return name;
    }

    // Another abstract function
    function move() public pure virtual returns (string memory);
}

// Concrete implementation of abstract contract
contract Cat is AbstractAnimal {
    constructor(string memory _name) AbstractAnimal(_name) {}

    // Must implement all abstract functions
    function makeSound() public pure override returns (string memory) {
        return "Meow!";
    }

    function move() public pure override returns (string memory) {
        return "Cat is walking silently";
    }
}

// ============================================================================
// 6. INTERFACES
// ============================================================================
// Interfaces are similar to abstract contracts but with stricter rules:
// - Cannot have any implemented functions
// - Cannot have state variables
// - Cannot have constructors
// - All functions must be external
// - Cannot inherit from other contracts (only from other interfaces)
// - Automatically marked as virtual

interface IToken {
    // All functions must be external
    // No function body
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);

    // Events are allowed in interfaces
    event Transfer(address indexed from, address indexed to, uint256 amount);
}

// Implementing an interface
contract MyToken is IToken {
    mapping(address => uint256) private balances;
    uint256 private _totalSupply;

    constructor(uint256 initialSupply) {
        _totalSupply = initialSupply;
        balances[msg.sender] = initialSupply;
    }

    // Must implement all interface functions with exact signature
    function transfer(
        address to,
        uint256 amount
    ) external override returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function balanceOf(
        address account
    ) external view override returns (uint256) {
        return balances[account];
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }
}

// ============================================================================
// 7. CONSTRUCTOR INHERITANCE
// ============================================================================
// Child contracts must call parent constructors
// Two ways to call parent constructors:
// 1. In the inheritance list
// 2. In the child constructor body (modifier-like syntax)

contract Base1 {
    uint256 public value1;

    constructor(uint256 _value1) {
        value1 = _value1;
    }
}

contract Base2 {
    uint256 public value2;

    constructor(uint256 _value2) {
        value2 = _value2;
    }
}

// Method 1: Call parent constructors in inheritance list
contract Derived1 is Base1(100), Base2(200) {
    // Parent constructors called with hardcoded values
    uint256 public value3;

    constructor(uint256 _value3) {
        value3 = _value3;
    }
}

// Method 2: Call parent constructors in child constructor
contract Derived2 is Base1, Base2 {
    uint256 public value3;

    // Pass parameters to parent constructors
    constructor(
        uint256 _value1,
        uint256 _value2,
        uint256 _value3
    ) Base1(_value1) Base2(_value2) {
        value3 = _value3;
    }
}

// Method 3: Mixed approach
contract Derived3 is Base1(100), Base2 {
    uint256 public value3;

    constructor(uint256 _value2, uint256 _value3) Base2(_value2) {
        value3 = _value3;
    }
}

// ============================================================================
// 8. FUNCTION OVERRIDING RULES
// ============================================================================

contract OverrideRules {
    // Rule 1: Virtual functions can be overridden
    function virtualFunc() public pure virtual returns (string memory) {
        return "Base virtual";
    }

    // Rule 2: Public functions can be overridden by public or external
    function publicFunc() public pure virtual returns (string memory) {
        return "Base public";
    }

    // Rule 3: External functions can only be overridden by external
    function externalFunc() external pure virtual returns (string memory) {
        return "Base external";
    }
}

contract OverrideRulesChild is OverrideRules {
    // Override virtual function
    function virtualFunc() public pure override returns (string memory) {
        return "Child virtual";
    }

    // Override public with public (same visibility)
    function publicFunc() public pure override returns (string memory) {
        return "Child public";
    }

    // Override external with external
    function externalFunc() external pure override returns (string memory) {
        return "Child external";
    }
}

// ============================================================================
// 9. STATE VARIABLE SHADOWING
// ============================================================================
// WARNING: State variable shadowing is NOT allowed in Solidity
// If parent has a state variable, child cannot declare same name

contract ParentWithState {
    uint256 public value = 100;

    function getValue() public view virtual returns (uint256) {
        return value;
    }
}

contract ChildWithState is ParentWithState {
    // ERROR: Cannot shadow state variable
    // uint256 public value = 200; // This will cause compilation error

    // Instead, override function to change behavior
    function getValue() public pure override returns (uint256) {
        return 200;
    }
}

// ============================================================================
// 10. MODIFIERS IN INHERITANCE
// ============================================================================
// Modifiers can also be inherited and overridden
// Same rules as functions: virtual and override

contract ModifierBase {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    // Virtual modifier
    modifier onlyOwner() virtual {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function restrictedFunction()
        public
        view
        onlyOwner
        returns (string memory)
    {
        return "Owner access granted";
    }
}

contract ModifierChild is ModifierBase {
    // Override modifier with additional logic
    modifier onlyOwner() override {
        require(msg.sender == owner, "Not owner in child");
        _; // Call function body
        // Can add post-execution logic here
    }

    // Can also have new modifiers
    modifier whenNotPaused() {
        // Custom logic
        _;
    }
}

// ============================================================================
// 11. DIAMOND PROBLEM RESOLUTION
// ============================================================================
// The diamond problem occurs when a contract inherits from two contracts
// that both inherit from the same base contract
// Solidity resolves this using C3 Linearization

contract BaseContract {
    function getValue() public pure virtual returns (string memory) {
        return "Base";
    }
}

contract LeftContract is BaseContract {
    function getValue() public pure virtual override returns (string memory) {
        return "Left";
    }
}

contract RightContract is BaseContract {
    function getValue() public pure virtual override returns (string memory) {
        return "Right";
    }
}

// Diamond inheritance
// Linearization: DiamondContract -> RightContract -> LeftContract -> BaseContract
// The rightmost parent in the inheritance list takes precedence
contract DiamondContract is LeftContract, RightContract {
    // Must specify all parent contracts being overridden
    function getValue()
        public
        pure
        override(LeftContract, RightContract)
        returns (string memory)
    {
        return "Diamond";
    }

    // To call specific parent implementation
    function getLeftValue() public pure returns (string memory) {
        return LeftContract.getValue();
    }

    function getRightValue() public pure returns (string memory) {
        return RightContract.getValue();
    }
}

// ============================================================================
// 12. PRACTICAL INHERITANCE PATTERNS
// ============================================================================

// Pattern 1: Access Control Hierarchy
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
}

// Pattern 2: Pausable functionality
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

// Pattern 3: Business logic contract using inherited utilities
contract TokenVault is Pausable {
    mapping(address => uint256) private deposits;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    function deposit() public payable whenNotPaused {
        deposits[msg.sender] += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public whenNotPaused {
        require(deposits[msg.sender] >= amount, "Insufficient balance");
        deposits[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getBalance(address user) public view returns (uint256) {
        return deposits[user];
    }

    // Emergency function using owner privileges
    function emergencyWithdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}

// ============================================================================
// 13. ADVANCED: LINEARIZATION EXAMPLE
// ============================================================================
// Understanding the Method Resolution Order (MRO)

contract A {
    function foo() public pure virtual returns (string memory) {
        return "A";
    }
}

contract B is A {
    function foo() public pure virtual override returns (string memory) {
        return "B";
    }
}

contract C is A {
    function foo() public pure virtual override returns (string memory) {
        return "C";
    }
}

contract D is B, C {
    // Linearization: D -> C -> B -> A
    // Must override because inherited from multiple contracts
    function foo() public pure override(B, C) returns (string memory) {
        return "D";
    }

    // Using super calls the next in linearization (C)
    function callSuper() public pure returns (string memory) {
        return super.foo(); // Returns "C"
    }

    // Explicitly call specific parent
    function callB() public pure returns (string memory) {
        return B.foo();
    }

    function callC() public pure returns (string memory) {
        return C.foo();
    }
}

// ============================================================================
// KEY TAKEAWAYS FOR PROFESSIONAL DEVELOPERS:
// ============================================================================
// 1. Always use "virtual" and "override" keywords explicitly (required since 0.6.0)
// 2. Be aware of C3 Linearization order in multiple inheritance
// 3. Use abstract contracts for partial implementations, interfaces for pure contracts
// 4. Modifiers can be overridden like functions
// 5. State variable shadowing is NOT allowed
// 6. Constructor execution order follows linearization
// 7. Use super carefully - it follows linearization, not direct parent
// 8. Explicitly specify all parent contracts when overriding from multiple parents
// 9. Interface functions are automatically external and virtual
// 10. Consider composition over inheritance for complex systems
// ============================================================================

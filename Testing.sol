// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// ============================================================
//  TESTING.SOL - Foundry Testing: Zero to Professional
// ============================================================
//
//  This file is a complete reference guide for testing with
//  Foundry. In a real project, test files live in test/ with
//  the *.t.sol extension and import from forge-std.
//
//  PROJECT SETUP:
//  forge init my-project
//  forge install foundry-rs/forge-std
//
//  ESSENTIAL COMMANDS:
//  forge test                          Run all tests
//  forge test -vvvv                    Maximum verbosity (stack traces)
//  forge test --match-test testName    Filter by function name
//  forge test --match-contract Name    Filter by contract name
//  forge test --match-path test/       Filter by path
//  forge test --gas-report             Gas usage report per function
//  forge snapshot                      Generate .gas-snapshot
//  forge coverage                      Coverage report
//  forge test --fork-url $RPC_URL      Fork mainnet/testnet
//  forge test --fork-block-number N    Fork at specific block
//
//  PROJECT STRUCTURE:
//  src/          Production contracts
//  test/         Tests (*.t.sol)
//  script/       Deploy scripts (*.s.sol)
//  lib/          Dependencies (forge-std, OpenZeppelin)
//  foundry.toml  Project configuration
//
// ============================================================

// ---------------------------------------------------------------------------
// IMPORTS (in a real .t.sol file)
// ---------------------------------------------------------------------------
// import {Test, console, console2} from "forge-std/Test.sol";
// import {Vm} from "forge-std/Vm.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {StdCheats} from "forge-std/StdCheats.sol";
// import {ERC20Token} from "../src/Standards.sol";
// import {ERC721Token} from "../src/Standards.sol";
// import {ReentrancyGuard, PullPayment, Factory} from "../src/Patterns.sol";
// import {ReentrancyVulnerable, ReentrancySecure} from "../src/Security.sol";

// ============================================================
// SECTION 1: FUNDAMENTALS — FOUNDRY TEST STRUCTURE
// ============================================================

/*
 * Every test contract inherits from Test (forge-std).
 * Mandatory conventions:
 *   - Functions starting with "test" are automatically executed
 *   - setUp() runs before EACH test (state is NOT shared between tests)
 *   - Prefix "testFail" expects the transaction to revert
 *   - Prefix "invariant_" defines invariant tests
 */

// contract BasicTest is Test {
//
//     ERC20Token public token;
//     address public owner  = makeAddr("owner");   // deterministic address with label
//     address public alice  = makeAddr("alice");
//     address public bob    = makeAddr("bob");
//     uint256 public constant INITIAL_SUPPLY = 1_000_000e18;
//
//     // -------------------------------------------------------
//     // setUp — runs before EACH test* function
//     // -------------------------------------------------------
//     function setUp() public {
//         vm.prank(owner);                          // next call comes from owner
//         token = new ERC20Token("TestToken", "TTK", INITIAL_SUPPLY);
//     }
//
//     // -------------------------------------------------------
//     // Basic test — assert conventions
//     // -------------------------------------------------------
//     function test_InitialState() public {
//         assertEq(token.name(), "TestToken");
//         assertEq(token.symbol(), "TTK");
//         assertEq(token.totalSupply(), INITIAL_SUPPLY);
//         assertEq(token.balanceOf(owner), INITIAL_SUPPLY);
//         assertTrue(token.totalSupply() > 0);
//         assertFalse(token.totalSupply() == 0);
//         assertGt(token.totalSupply(), 0);        // greater than
//         assertLt(token.totalSupply(), type(uint256).max); // less than
//         assertGe(token.balanceOf(owner), INITIAL_SUPPLY); // >=
//         assertApproxEqAbs(token.totalSupply(), INITIAL_SUPPLY, 1e15); // absolute delta
//         assertApproxEqRel(token.totalSupply(), INITIAL_SUPPLY, 1e15); // relative delta (1e18 = 100%)
//     }
//
//     // -------------------------------------------------------
//     // Recommended naming convention (readable in reports)
//     // -------------------------------------------------------
//     // test_[function]_[scenario]_[result]
//     function test_Transfer_SufficientBalance_Succeeds() public {
//         vm.prank(owner);
//         bool ok = token.transfer(alice, 100e18);
//         assertTrue(ok);
//         assertEq(token.balanceOf(alice), 100e18);
//         assertEq(token.balanceOf(owner), INITIAL_SUPPLY - 100e18);
//     }
//
//     function test_Transfer_InsufficientBalance_Reverts() public {
//         vm.prank(alice);                          // alice has zero balance
//         vm.expectRevert();                        // any revert
//         token.transfer(bob, 1);
//     }
// }

// ============================================================
// SECTION 2: TESTING REVERTS AND CUSTOM ERRORS
// ============================================================

/*
 * Testing reverts correctly is critical.
 * Foundry lets you verify: message, custom error, and even error arguments.
 */

// contract RevertTest is Test {
//
//     ERC20Token public token;
//     address owner = makeAddr("owner");
//     address alice = makeAddr("alice");
//
//     function setUp() public {
//         vm.prank(owner);
//         token = new ERC20Token("Token", "TKN", 1000e18);
//     }
//
//     // -------------------------------------------------------
//     // expectRevert — usage forms
//     // -------------------------------------------------------
//
//     // 1. Any revert (less precise, avoid when possible)
//     function test_Revert_AnyError() public {
//         vm.expectRevert();
//         token.transfer(address(0), 1e18);
//     }
//
//     // 2. Revert with string message
//     function test_Revert_WithMessage() public {
//         vm.expectRevert("ERC20: transfer to zero address");
//         token.transfer(address(0), 1e18);
//     }
//
//     // 3. Custom error without arguments
//     //    (StandardToken uses: error InsufficientBalance(uint256 available, uint256 required))
//     function test_Revert_CustomError_NoArgs() public {
//         vm.prank(alice);
//         vm.expectRevert(ERC20Token.InsufficientBalance.selector);
//         token.transfer(owner, 1);
//     }
//
//     // 4. Custom error WITH arguments — full verification
//     function test_Revert_CustomError_WithArgs() public {
//         vm.prank(alice);
//         vm.expectRevert(
//             abi.encodeWithSelector(
//                 ERC20Token.InsufficientBalance.selector,
//                 0,      // available (alice has 0)
//                 1       // required
//             )
//         );
//         token.transfer(owner, 1);
//     }
//
//     // 5. expectRevert with custom error using encodeWithSignature
//     function test_Revert_EncodeWithSignature() public {
//         vm.expectRevert(
//             abi.encodeWithSignature("InsufficientBalance(uint256,uint256)", 0, 1)
//         );
//         vm.prank(alice);
//         token.transfer(owner, 1);
//     }
//
//     // -------------------------------------------------------
//     // Testing require and panic codes
//     // -------------------------------------------------------
//
//     // Panic 0x01 = assert() failed
//     // Panic 0x11 = arithmetic overflow
//     // Panic 0x12 = division by zero
//     // Panic 0x32 = out-of-bounds array access
//     function test_Revert_PanicDivisionByZero() public {
//         vm.expectRevert(stdError.divisionError);   // forge-std helper
//         token.divideByZero();                      // hypothetical function
//     }
// }

// ============================================================
// SECTION 3: TESTING EVENTS (expectEmit)
// ============================================================

/*
 * expectEmit verifies that an event was emitted with the correct parameters.
 * Signature: expectEmit(checkTopic1, checkTopic2, checkTopic3, checkData)
 *   - Topics = indexed arguments
 *   - Data   = non-indexed arguments
 */

// contract EventTest is Test {
//
//     ERC20Token public token;
//     address owner = makeAddr("owner");
//     address alice = makeAddr("alice");
//
//     // events copied from Standards.sol / ERC20Token
//     event Transfer(address indexed from, address indexed to, uint256 value);
//     event Approval(address indexed owner, address indexed spender, uint256 value);
//
//     function setUp() public {
//         vm.prank(owner);
//         token = new ERC20Token("Token", "TKN", 1000e18);
//     }
//
//     // -------------------------------------------------------
//     // Full verification — all fields checked
//     // -------------------------------------------------------
//     function test_Event_Transfer_FullCheck() public {
//         // Declare that the next emitted event MUST match exactly
//         vm.expectEmit(true, true, false, true); // topic1(from), topic2(to), topic3(N/A), data(value)
//         emit Transfer(owner, alice, 100e18);    // expected event
//
//         vm.prank(owner);
//         token.transfer(alice, 100e18);          // action that triggers the event
//     }
//
//     // -------------------------------------------------------
//     // Partial verification — only indexed fields
//     // -------------------------------------------------------
//     function test_Event_Transfer_PartialCheck() public {
//         vm.expectEmit(true, true, false, false); // only verify from and to
//         emit Transfer(owner, alice, 0);          // value ignored (false on last param)
//
//         vm.prank(owner);
//         token.transfer(alice, 100e18);
//     }
//
//     // -------------------------------------------------------
//     // Verification with emitter address
//     // -------------------------------------------------------
//     function test_Event_CheckEmitter() public {
//         vm.expectEmit(true, true, false, true, address(token)); // filter by emitter
//         emit Transfer(owner, alice, 100e18);
//
//         vm.prank(owner);
//         token.transfer(alice, 100e18);
//     }
//
//     // -------------------------------------------------------
//     // Multiple events in sequence
//     // -------------------------------------------------------
//     function test_Events_MultipleInOrder() public {
//         vm.expectEmit(true, true, false, true);
//         emit Approval(owner, alice, 500e18);
//
//         vm.expectEmit(true, true, false, true);
//         emit Transfer(owner, alice, 100e18);
//
//         vm.startPrank(owner);
//         token.approve(alice, 500e18);
//         token.transfer(alice, 100e18);
//         vm.stopPrank();
//     }
// }

// ============================================================
// SECTION 4: CHEATCODES — ENVIRONMENT MANIPULATION
// ============================================================

/*
 * Cheatcodes are calls to the special vm address (0x7109...) that
 * allow manipulating the EVM state during tests.
 * Full reference: https://book.getfoundry.sh/cheatcodes/
 */

// contract CheatcodesTest is Test {
//
//     ERC20Token public token;
//     address owner = makeAddr("owner");
//     address alice = makeAddr("alice");
//
//     function setUp() public {
//         vm.prank(owner);
//         token = new ERC20Token("Token", "TKN", 1_000_000e18);
//     }
//
//     // -------------------------------------------------------
//     // IDENTITY — who is calling
//     // -------------------------------------------------------
//     function test_Cheat_Prank() public {
//         vm.prank(alice);          // msg.sender = alice ONLY for the next call
//         token.transfer(owner, 0);
//     }
//
//     function test_Cheat_StartStopPrank() public {
//         vm.startPrank(alice);     // alice until stopPrank()
//         token.approve(owner, 1000e18);
//         // ... multiple calls
//         vm.stopPrank();
//     }
//
//     function test_Cheat_PrankWithTxOrigin() public {
//         vm.prank(alice, alice);   // msg.sender = alice, tx.origin = alice
//         token.transfer(owner, 0);
//     }
//
//     // -------------------------------------------------------
//     // BALANCE — manipulate ETH and tokens
//     // -------------------------------------------------------
//     function test_Cheat_Deal_ETH() public {
//         deal(alice, 10 ether);
//         assertEq(alice.balance, 10 ether);
//     }
//
//     function test_Cheat_Deal_ERC20() public {
//         deal(address(token), alice, 500e18); // deal directly to any ERC20
//         assertEq(token.balanceOf(alice), 500e18);
//     }
//
//     function test_Cheat_HoaxPattern() public {
//         hoax(alice, 5 ether);     // prank + deal ETH in one line
//         // next call comes from alice with 5 ETH
//     }
//
//     // -------------------------------------------------------
//     // TIME — manipulate block and timestamp
//     // -------------------------------------------------------
//     function test_Cheat_TimeWarp() public {
//         uint256 startTime = block.timestamp;
//         vm.warp(startTime + 7 days);   // advance timestamp
//         assertEq(block.timestamp, startTime + 7 days);
//     }
//
//     function test_Cheat_RollBlock() public {
//         uint256 startBlock = block.number;
//         vm.roll(startBlock + 100);    // advance block number
//         assertEq(block.number, startBlock + 100);
//     }
//
//     // -------------------------------------------------------
//     // STORAGE — direct read and write
//     // -------------------------------------------------------
//     function test_Cheat_ReadStorage() public {
//         // Slot 0 of an ERC20 is usually the totalSupply or owner
//         bytes32 slot0 = vm.load(address(token), bytes32(0));
//         console.logBytes32(slot0);
//     }
//
//     function test_Cheat_WriteStorage() public {
//         // Force a value into a specific storage slot
//         // NOTE: requires knowing the contract's storage layout
//         vm.store(
//             address(token),
//             bytes32(uint256(0)),   // slot 0
//             bytes32(uint256(999))  // new value
//         );
//     }
//
//     // -------------------------------------------------------
//     // CODE — replace bytecode at runtime
//     // -------------------------------------------------------
//     function test_Cheat_Etch() public {
//         address mockAddr = makeAddr("mock");
//         vm.etch(mockAddr, address(token).code); // copy token bytecode to mock
//     }
//
//     // -------------------------------------------------------
//     // MOCKING — simulate return values and reverts
//     // -------------------------------------------------------
//     function test_Cheat_MockCall() public {
//         // Make address(token).balanceOf(alice) return 9999e18 without changing state
//         vm.mockCall(
//             address(token),
//             abi.encodeWithSelector(token.balanceOf.selector, alice),
//             abi.encode(9999e18)
//         );
//         assertEq(token.balanceOf(alice), 9999e18);
//         vm.clearMockedCalls(); // clear after test
//     }
//
//     function test_Cheat_MockCallRevert() public {
//         vm.mockCallRevert(
//             address(token),
//             abi.encodeWithSelector(token.transfer.selector, alice, 1),
//             abi.encodeWithSignature("Error(string)", "mocked revert")
//         );
//         vm.expectRevert("mocked revert");
//         token.transfer(alice, 1);
//     }
//
//     // -------------------------------------------------------
//     // SNAPSHOT — save and restore state
//     // -------------------------------------------------------
//     function test_Cheat_Snapshot() public {
//         vm.prank(owner);
//         token.transfer(alice, 100e18);
//
//         uint256 snap = vm.snapshot();   // save state
//
//         vm.prank(alice);
//         token.transfer(owner, 50e18);
//         assertEq(token.balanceOf(alice), 50e18);
//
//         vm.revertTo(snap);              // restore state
//         assertEq(token.balanceOf(alice), 100e18); // back to snapshot
//     }
//
//     // -------------------------------------------------------
//     // CALL EXPECTATIONS
//     // -------------------------------------------------------
//     function test_Cheat_ExpectCall() public {
//         // Verify that transfer() is called with these exact arguments
//         vm.expectCall(
//             address(token),
//             abi.encodeWithSelector(token.transfer.selector, alice, 100e18)
//         );
//         vm.prank(owner);
//         token.transfer(alice, 100e18);
//     }
//
//     // -------------------------------------------------------
//     // SIGNATURES — sign messages inside tests
//     // -------------------------------------------------------
//     function test_Cheat_Sign() public {
//         uint256 privKey = 0xA11CE; // test private key
//         address signer  = vm.addr(privKey);
//
//         bytes32 digest = keccak256("test message");
//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, digest);
//
//         address recovered = ecrecover(digest, v, r, s);
//         assertEq(recovered, signer);
//     }
//
//     // -------------------------------------------------------
//     // CONSOLE LOGGING — debug during tests
//     // -------------------------------------------------------
//     function test_ConsoleLogs() public {
//         console.log("Owner balance:", token.balanceOf(owner));
//         console.log("Timestamp:", block.timestamp);
//         console.log("Block:", block.number);
//         console2.log("Token address:", address(token)); // console2 supports more types
//     }
// }

// ============================================================
// SECTION 5: FUZZ TESTING — PROPERTY-BASED TESTS
// ============================================================

/*
 * Fuzz testing automatically generates hundreds/thousands of random inputs.
 * Foundry runs 256 iterations by default (configurable in foundry.toml).
 *
 * [fuzz]
 * runs = 1000
 * seed = "0x1234"      # seed for reproducibility
 * max_test_rejects = 65536
 *
 * INVARIANT PROPERTIES that fuzz tests well:
 * - totalSupply never decreases without a burn
 * - balanceOf(a) + balanceOf(b) = constant after transfer
 * - approve -> transferFrom always works with sufficient balance
 */

// contract FuzzTest is Test {
//
//     ERC20Token public token;
//     address owner = makeAddr("owner");
//
//     function setUp() public {
//         vm.prank(owner);
//         token = new ERC20Token("Token", "TKN", type(uint128).max); // large supply
//     }
//
//     // -------------------------------------------------------
//     // Basic fuzz — Foundry generates random `amount`
//     // -------------------------------------------------------
//     function testFuzz_Transfer_PreservesTotalSupply(uint256 amount) public {
//         // bound() restricts the input to a valid range
//         amount = bound(amount, 0, token.balanceOf(owner));
//
//         uint256 supplyBefore = token.totalSupply();
//
//         vm.prank(owner);
//         token.transfer(makeAddr("recipient"), amount);
//
//         assertEq(token.totalSupply(), supplyBefore); // totalSupply must not change
//     }
//
//     // -------------------------------------------------------
//     // assume() — filters invalid inputs (use sparingly)
//     // assume causes "reject", bound is more efficient
//     // -------------------------------------------------------
//     function testFuzz_Transfer_NonZeroAmount(address recipient, uint256 amount) public {
//         vm.assume(recipient != address(0));         // discard address(0)
//         vm.assume(recipient != owner);
//         vm.assume(amount > 0);
//         amount = bound(amount, 1, token.balanceOf(owner));
//
//         vm.prank(owner);
//         token.transfer(recipient, amount);
//
//         assertGt(token.balanceOf(recipient), 0);
//     }
//
//     // -------------------------------------------------------
//     // Fuzz with multiple parameters
//     // -------------------------------------------------------
//     function testFuzz_Approve_And_TransferFrom(
//         address spender,
//         uint256 approveAmount,
//         uint256 transferAmount
//     ) public {
//         vm.assume(spender != address(0) && spender != owner);
//         approveAmount  = bound(approveAmount,  1, token.balanceOf(owner));
//         transferAmount = bound(transferAmount, 1, approveAmount);
//
//         vm.prank(owner);
//         token.approve(spender, approveAmount);
//
//         vm.prank(spender);
//         token.transferFrom(owner, spender, transferAmount);
//
//         assertEq(token.allowance(owner, spender), approveAmount - transferAmount);
//         assertEq(token.balanceOf(spender), transferAmount);
//     }
//
//     // -------------------------------------------------------
//     // Fuzz testing overflow protection (Solidity 0.8+)
//     // -------------------------------------------------------
//     function testFuzz_NoOverflow(uint256 a, uint256 b) public pure {
//         // If a + b overflows, Solidity 0.8+ reverts automatically.
//         // The fuzzer will find inputs that trigger overflow and verify the revert.
//         if (a > type(uint256).max - b) {
//             // overflow expected — cannot test addition directly
//             return;
//         }
//         uint256 result = a + b;
//         assertGe(result, a); // basic math property
//         assertGe(result, b);
//     }
//
//     // -------------------------------------------------------
//     // Fuzz with structs — Foundry supports them automatically
//     // -------------------------------------------------------
//     struct FuzzParams {
//         address to;
//         uint128 amount;  // uint128 avoids overflow in calculations
//         uint64  deadline;
//     }
//
//     function testFuzz_WithStruct(FuzzParams memory p) public {
//         vm.assume(p.to != address(0) && p.to != owner);
//         uint256 amount = bound(p.amount, 0, token.balanceOf(owner));
//
//         vm.prank(owner);
//         bool ok = token.transfer(p.to, amount);
//         assertTrue(ok);
//     }
//
//     // -------------------------------------------------------
//     // Fuzz testing the ReentrancyGuard from Patterns.sol
//     // -------------------------------------------------------
//     function testFuzz_ReentrancyGuard_PreventsDrain(uint256 depositAmount) public {
//         depositAmount = bound(depositAmount, 1, 100 ether);
//         address attacker = makeAddr("attacker");
//
//         // Deploy the secure vault
//         ReentrancySecureVault vault = new ReentrancySecureVault();
//
//         // Deposit legitimate ETH
//         deal(address(this), depositAmount);
//         vault.deposit{value: depositAmount}();
//
//         // Attempt reentrancy attack — must fail
//         deal(attacker, 1 ether);
//         vm.prank(attacker);
//         vm.expectRevert(); // ReentrancyGuard must block this
//         vault.attackReentrant{value: 1 ether}();
//     }
// }

// ============================================================
// SECTION 6: INVARIANT TESTING — STATEFUL FUZZING
// ============================================================

/*
 * Invariant testing (stateful fuzzing) is the most advanced level.
 * Foundry calls random handler functions in sequence, accumulates state,
 * and checks invariants after each sequence.
 *
 * ANATOMY:
 * 1. Handler contract — exposes available actions (bounded inputs)
 * 2. Invariant contract — inherits StdInvariant, defines invariant_* functions
 * 3. setUp() — registers the handler with targetContract()
 *
 * [invariant]
 * runs  = 256    # call sequences
 * depth = 15     # calls per sequence
 * fail_on_revert = false  # ignore handler reverts
 */

// -------------------------------------------------------
// Handler: defines the actions the fuzzer can execute
// -------------------------------------------------------
// contract ERC20Handler is Test {
//
//     ERC20Token public token;
//     address[] public actors;
//
//     // Ghost variables — track what should be true
//     uint256 public ghost_totalMinted;
//     uint256 public ghost_totalBurned;
//
//     constructor(ERC20Token _token, address[] memory _actors) {
//         token  = _token;
//         actors = _actors;
//     }
//
//     // The fuzzer calls these functions with random inputs
//     function transfer(uint256 actorSeed, uint256 recipientSeed, uint256 amount) external {
//         address from = actors[actorSeed % actors.length];
//         address to   = actors[recipientSeed % actors.length];
//         if (from == to) return;
//         amount = bound(amount, 0, token.balanceOf(from));
//
//         vm.prank(from);
//         token.transfer(to, amount);
//     }
//
//     function mint(uint256 recipientSeed, uint256 amount) external {
//         address to = actors[recipientSeed % actors.length];
//         amount = bound(amount, 0, 1_000_000e18);
//
//         vm.prank(token.owner());
//         token.mint(to, amount);
//         ghost_totalMinted += amount;
//     }
//
//     function burn(uint256 actorSeed, uint256 amount) external {
//         address from = actors[actorSeed % actors.length];
//         amount = bound(amount, 0, token.balanceOf(from));
//
//         vm.prank(from);
//         token.burn(amount);
//         ghost_totalBurned += amount;
//     }
// }

// -------------------------------------------------------
// Invariant contract — defines what must NEVER break
// -------------------------------------------------------
// contract ERC20InvariantTest is StdInvariant, Test {
//
//     ERC20Token   public token;
//     ERC20Handler public handler;
//
//     address owner   = makeAddr("owner");
//     address alice   = makeAddr("alice");
//     address bob     = makeAddr("bob");
//     address charlie = makeAddr("charlie");
//
//     uint256 constant INITIAL = 1_000_000e18;
//
//     function setUp() public {
//         vm.prank(owner);
//         token = new ERC20Token("Token", "TKN", INITIAL);
//
//         address[] memory actors = new address[](4);
//         actors[0] = owner;
//         actors[1] = alice;
//         actors[2] = bob;
//         actors[3] = charlie;
//
//         handler = new ERC20Handler(token, actors);
//
//         // Distribute initial tokens to actors
//         vm.startPrank(owner);
//         token.transfer(alice,   250_000e18);
//         token.transfer(bob,     250_000e18);
//         token.transfer(charlie, 250_000e18);
//         vm.stopPrank();
//
//         // Register handler — fuzzer only calls its functions
//         targetContract(address(handler));
//     }
//
//     // -------------------------------------------------------
//     // INVARIANT 1: totalSupply = INITIAL + minted - burned
//     // The most fundamental property of any token
//     // -------------------------------------------------------
//     function invariant_TotalSupplyEqualsMintedMinusBurned() public {
//         assertEq(
//             token.totalSupply(),
//             INITIAL + handler.ghost_totalMinted() - handler.ghost_totalBurned()
//         );
//     }
//
//     // -------------------------------------------------------
//     // INVARIANT 2: sum of balances = totalSupply
//     // Tokens cannot appear or disappear out of thin air
//     // -------------------------------------------------------
//     function invariant_SumOfBalancesEqualsTotalSupply() public {
//         uint256 sum = token.balanceOf(owner)
//                     + token.balanceOf(alice)
//                     + token.balanceOf(bob)
//                     + token.balanceOf(charlie);
//         assertEq(sum, token.totalSupply());
//     }
//
//     // -------------------------------------------------------
//     // INVARIANT 3: no balance can be negative (guaranteed by type)
//     // Useful to document as an explicit test
//     // -------------------------------------------------------
//     function invariant_NoNegativeBalances() public {
//         assertTrue(token.balanceOf(owner)   <= token.totalSupply());
//         assertTrue(token.balanceOf(alice)   <= token.totalSupply());
//         assertTrue(token.balanceOf(bob)     <= token.totalSupply());
//         assertTrue(token.balanceOf(charlie) <= token.totalSupply());
//     }
//
//     // -------------------------------------------------------
//     // INVARIANT 4: allowance cannot exceed uint256.max
//     // -------------------------------------------------------
//     function invariant_AllowanceDoesNotExceedMax() public {
//         assertLe(token.allowance(owner, alice), type(uint256).max);
//     }
//
//     // -------------------------------------------------------
//     // Print stats after all runs
//     // -------------------------------------------------------
//     function invariant_PrintStats() public view {
//         console.log("Total minted:", handler.ghost_totalMinted());
//         console.log("Total burned:", handler.ghost_totalBurned());
//         console.log("Final supply:", token.totalSupply());
//     }
// }

// ============================================================
// SECTION 7: FORK TESTING — TESTING AGAINST REAL MAINNET
// ============================================================

/*
 * Fork tests run against a real blockchain snapshot.
 * You can interact with deployed contracts (Uniswap, Aave, etc.)
 *
 * CONFIGURATION in foundry.toml:
 * [rpc_endpoints]
 * mainnet  = "${MAINNET_RPC_URL}"
 * arbitrum = "${ARBITRUM_RPC_URL}"
 * polygon  = "${POLYGON_RPC_URL}"
 *
 * CLI:
 * forge test --fork-url $MAINNET_RPC_URL --fork-block-number 19000000
 */

// contract ForkTest is Test {
//
//     // Known mainnet addresses
//     address constant USDC        = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
//     address constant WETH        = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
//     address constant UNISWAP_V2  = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
//     address constant AAVE_V3     = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
//     address constant WHALE       = 0xF977814e90dA44bFA03b6295A0616a897441aceC; // Binance 8
//
//     uint256 mainnetFork;
//
//     function setUp() public {
//         // Create fork pinned to a specific block (reproducible)
//         mainnetFork = vm.createFork(vm.envString("MAINNET_RPC_URL"), 19_500_000);
//         vm.selectFork(mainnetFork);
//     }
//
//     // -------------------------------------------------------
//     // Interact with a real mainnet contract
//     // -------------------------------------------------------
//     function test_Fork_USDC_BalanceOfWhale() public {
//         IERC20 usdc = IERC20(USDC);
//         uint256 balance = usdc.balanceOf(WHALE);
//         assertGt(balance, 0, "Whale should have USDC");
//         console.log("Whale USDC balance:", balance / 1e6, "USDC");
//     }
//
//     // -------------------------------------------------------
//     // Impersonate a whale — steal tokens with prank
//     // -------------------------------------------------------
//     function test_Fork_StealTokensFromWhale() public {
//         IERC20 usdc = IERC20(USDC);
//         address me   = makeAddr("me");
//         uint256 whaleBalance = usdc.balanceOf(WHALE);
//
//         vm.prank(WHALE);
//         usdc.transfer(me, whaleBalance);
//
//         assertEq(usdc.balanceOf(me), whaleBalance);
//     }
//
//     // -------------------------------------------------------
//     // Multiple forks — compare behavior across chains
//     // -------------------------------------------------------
//     function test_Fork_MultipleForks() public {
//         uint256 arbFork = vm.createFork(vm.envString("ARBITRUM_RPC_URL"));
//
//         vm.selectFork(mainnetFork);
//         uint256 mainnetBlock = block.number;
//
//         vm.selectFork(arbFork);
//         uint256 arbBlock = block.number;
//
//         console.log("Mainnet block:", mainnetBlock);
//         console.log("Arbitrum block:", arbBlock);
//         // Arbitrum produces blocks much faster than mainnet
//         assertGt(arbBlock, mainnetBlock);
//     }
//
//     // -------------------------------------------------------
//     // Fork + deploy your contract + integrate with real protocols
//     // -------------------------------------------------------
//     function test_Fork_DeployAndIntegrateWithAave() public {
//         // Deploy your contract on the fork
//         MyAaveStrategy strategy = new MyAaveStrategy(AAVE_V3, USDC);
//
//         // Obtain USDC — deal() works on forks too
//         deal(USDC, address(this), 10_000e6);
//
//         IERC20(USDC).approve(address(strategy), 10_000e6);
//         strategy.deposit(10_000e6);
//
//         // Advance 1 year of blocks to accumulate interest
//         vm.warp(block.timestamp + 365 days);
//         vm.roll(block.number + (365 * 7200)); // ~7200 blocks/day on mainnet
//
//         uint256 earned = strategy.harvest();
//         assertGt(earned, 0, "Should have accumulated interest");
//     }
// }

// ============================================================
// SECTION 8: GAS TESTING — BENCHMARKS AND SNAPSHOTS
// ============================================================

/*
 * Foundry allows measuring gas with surgical precision.
 *
 * TOOLS:
 * forge snapshot              Generate .gas-snapshot for all functions
 * forge snapshot --diff       Compare against previous snapshot (useful in CI)
 * forge test --gas-report     Table of min/avg/max gas per function
 *
 * In tests:
 * uint256 gas = gasleft();
 * ... operation ...
 * uint256 used = gas - gasleft();
 */

// contract GasTest is Test {
//
//     ERC20Token public token;
//     address owner = makeAddr("owner");
//     address alice = makeAddr("alice");
//
//     function setUp() public {
//         vm.prank(owner);
//         token = new ERC20Token("Token", "TKN", 1_000_000e18);
//     }
//
//     // -------------------------------------------------------
//     // Manual gas measurement
//     // -------------------------------------------------------
//     function test_Gas_Transfer() public {
//         vm.prank(owner);
//         uint256 gasBefore = gasleft();
//         token.transfer(alice, 100e18);
//         uint256 gasUsed = gasBefore - gasleft();
//
//         console.log("Gas used in transfer():", gasUsed);
//         assertLt(gasUsed, 60_000, "Transfer should use less than 60k gas");
//     }
//
//     // -------------------------------------------------------
//     // Comparing implementations (packed vs unpacked)
//     // -------------------------------------------------------
//     function test_Gas_Packed_vs_Unpacked() public {
//         StorageUnpacked unpacked = new StorageUnpacked();
//         StoragePacked   packed   = new StoragePacked();
//
//         uint256 gasUnpacked;
//         uint256 gasPacked;
//
//         uint256 g = gasleft();
//         unpacked.store(1, 2, 3);
//         gasUnpacked = g - gasleft();
//
//         g = gasleft();
//         packed.store(1, 2, 3);
//         gasPacked = g - gasleft();
//
//         console.log("Gas unpacked:", gasUnpacked);
//         console.log("Gas packed:  ", gasPacked);
//         assertLt(gasPacked, gasUnpacked, "Packed should be cheaper");
//     }
//
//     // Auxiliary contracts for comparison (mirrors GasOptimization.sol)
//     contract StorageUnpacked {
//         uint256 public a;
//         uint256 public b;
//         uint256 public c;
//         function store(uint256 _a, uint256 _b, uint256 _c) external {
//             a = _a; b = _b; c = _c; // 3 SSTOREs = 3 * 20000 = 60000 gas
//         }
//     }
//
//     contract StoragePacked {
//         uint128 public a;
//         uint64  public b;
//         uint64  public c; // a+b+c fit in 1 slot (32 bytes)
//         function store(uint128 _a, uint64 _b, uint64 _c) external {
//             a = _a; b = _b; c = _c; // 1 SSTORE = 20000 gas
//         }
//     }
// }

// ============================================================
// SECTION 9: ERC-4337 — ACCOUNT ABSTRACTION TESTING
// ============================================================

/*
 * ERC-4337 (Account Abstraction) lets contracts act as wallets,
 * separating validation from execution via UserOperation and EntryPoint.
 *
 * COMPONENTS:
 * EntryPoint    — singleton contract that orchestrates everything (v0.6 / v0.7)
 * UserOperation — struct representing a smart account "transaction"
 * Paymaster     — pays gas on behalf of the user (optional)
 * Bundler       — aggregates and submits UserOperations
 * SmartAccount  — the wallet (implements IAccount)
 *
 * ADDRESSES (mainnet/testnets):
 * EntryPoint v0.6: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789
 * EntryPoint v0.7: 0x0000000071727De22E5E9d8BAf0edAc6f37da032
 *
 * INSTALLATION:
 * forge install eth-infinitism/account-abstraction
 */

// -------------------------------------------------------
// Minimal EntryPoint interface (v0.7)
// -------------------------------------------------------
interface IEntryPoint {
    struct UserOperation {
        address sender;
        uint256 nonce;
        bytes   initCode;
        bytes   callData;
        uint256 callGasLimit;
        uint256 executionGasLimit;
        uint256 preVerificationGas;
        uint256 maxFeePerGas;
        uint256 maxPriorityFeePerGas;
        bytes   paymasterAndData;
        bytes   signature;
    }

    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external;
    function getNonce(address sender, uint192 key) external view returns (uint256);
    function depositTo(address account) external payable;
    function getDepositInfo(address account) external view returns (uint112 deposit, bool staked, uint112 stake, uint32 unstakeDelaySec, uint48 withdrawTime);
}

// -------------------------------------------------------
// Smart Account interface
// -------------------------------------------------------
interface IAccount {
    function validateUserOp(
        IEntryPoint.UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external returns (uint256 validationData);
}

// -------------------------------------------------------
// Simple Smart Account — reference implementation
// -------------------------------------------------------
contract SimpleSmartAccount is IAccount {

    address public entryPoint;
    address public owner;
    uint256 public nonce;

    // SIG_VALIDATION_FAILED — return this value to signal failure to EntryPoint
    uint256 internal constant SIG_VALIDATION_FAILED = 1;

    error NotEntryPoint();
    error NotOwner();
    error ExecutionFailed();

    event Executed(address indexed target, uint256 value, bytes data);

    modifier onlyEntryPoint() {
        if (msg.sender != entryPoint) revert NotEntryPoint();
        _;
    }

    constructor(address _entryPoint, address _owner) {
        entryPoint = _entryPoint;
        owner      = _owner;
    }

    receive() external payable {}

    // -------------------------------------------------------
    // validateUserOp — called by EntryPoint before execution
    // Must verify the signature and pay funds if necessary
    // -------------------------------------------------------
    function validateUserOp(
        IEntryPoint.UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external override onlyEntryPoint returns (uint256 validationData) {
        // 1. Validate ECDSA signature
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", userOpHash));
        address recovered = _recoverSigner(ethHash, userOp.signature);

        if (recovered != owner) {
            return SIG_VALIDATION_FAILED;
        }

        // 2. Pay missing funds to EntryPoint
        if (missingAccountFunds > 0) {
            (bool ok,) = payable(entryPoint).call{value: missingAccountFunds}("");
            require(ok, "Failed to pay EntryPoint");
        }

        // 3. Return 0 = success, or a packed validUntil/validAfter value
        return 0;
    }

    // -------------------------------------------------------
    // execute — called by EntryPoint after validation
    // -------------------------------------------------------
    function execute(
        address target,
        uint256 value,
        bytes calldata data
    ) external onlyEntryPoint {
        (bool ok, bytes memory result) = target.call{value: value}(data);
        if (!ok) {
            assembly { revert(add(result, 32), mload(result)) }
        }
        emit Executed(target, value, data);
    }

    // -------------------------------------------------------
    // executeBatch — multiple calls in a single UserOp
    // -------------------------------------------------------
    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[]   calldata datas
    ) external onlyEntryPoint {
        require(targets.length == values.length && values.length == datas.length, "Length mismatch");
        for (uint256 i = 0; i < targets.length; i++) {
            (bool ok,) = targets[i].call{value: values[i]}(datas[i]);
            if (!ok) revert ExecutionFailed();
        }
    }

    function _recoverSigner(bytes32 hash, bytes memory sig) internal pure returns (address) {
        require(sig.length == 65, "Invalid signature length");
        bytes32 r; bytes32 s; uint8 v;
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        return ecrecover(hash, v, r, s);
    }
}

// -------------------------------------------------------
// Paymaster — pays gas on behalf of users
// Use cases: gasless onboarding, gas in ERC20, subsidies
// -------------------------------------------------------
contract SimplePaymaster {

    address public entryPoint;
    address public owner;
    mapping(address => bool) public sponsored; // sponsored accounts

    error NotOwner();
    error NotEntryPoint();

    modifier onlyOwner() { if (msg.sender != owner) revert NotOwner(); _; }
    modifier onlyEntryPoint() { if (msg.sender != entryPoint) revert NotEntryPoint(); _; }

    constructor(address _entryPoint) {
        entryPoint = _entryPoint;
        owner      = msg.sender;
    }

    receive() external payable {}

    function setSponsored(address account, bool status) external onlyOwner {
        sponsored[account] = status;
    }

    // Called before execution — decides whether to pay gas
    function validatePaymasterUserOp(
        IEntryPoint.UserOperation calldata userOp,
        bytes32, /*userOpHash*/
        uint256 maxCost
    ) external onlyEntryPoint returns (bytes memory context, uint256 validationData) {
        require(sponsored[userOp.sender], "Account not sponsored");
        require(address(this).balance >= maxCost, "Insufficient paymaster balance");
        context        = abi.encode(userOp.sender, maxCost);
        validationData = 0; // success
    }

    // Called after execution — allows refund or ERC20 charge
    function postOp(
        uint8, /*mode*/
        bytes calldata context,
        uint256 actualGasCost
    ) external onlyEntryPoint {
        (address account,) = abi.decode(context, (address, uint256));
        emit GasSponsored(account, actualGasCost);
    }

    event GasSponsored(address indexed account, uint256 gasCost);

    // Deposit to EntryPoint to fund gas payments
    function depositToEntryPoint() external payable onlyOwner {
        IEntryPoint(entryPoint).depositTo{value: msg.value}(address(this));
    }
}

// -------------------------------------------------------
// ERC-4337 tests with Foundry
// -------------------------------------------------------

// contract ERC4337Test is Test {
//
//     // Real EntryPoint from fork, or mock in unit test
//     IEntryPoint  public entryPoint;
//     SimpleSmartAccount public account;
//     SimplePaymaster    public paymaster;
//
//     uint256 ownerPrivKey = 0xDEADBEEF;
//     address owner        = vm.addr(ownerPrivKey);
//     address bundler      = makeAddr("bundler");
//
//     function setUp() public {
//         // In fork test: use the real EntryPoint
//         // entryPoint = IEntryPoint(0x0000000071727De22E5E9d8BAf0edAc6f37da032);
//
//         // In unit test: use a mock or local deployment
//         entryPoint = IEntryPoint(deployEntryPoint());
//
//         account   = new SimpleSmartAccount(address(entryPoint), owner);
//         paymaster = new SimplePaymaster(address(entryPoint));
//
//         // Fund the account and paymaster
//         deal(address(account), 1 ether);
//         deal(address(paymaster), 1 ether);
//
//         // Deposit to EntryPoint to cover gas
//         vm.deal(address(this), 1 ether);
//         entryPoint.depositTo{value: 0.1 ether}(address(account));
//     }
//
//     // -------------------------------------------------------
//     // Basic test: valid UserOp executes successfully
//     // -------------------------------------------------------
//     function test_4337_ValidUserOp_Executes() public {
//         address recipient = makeAddr("recipient");
//         uint256 value     = 0.1 ether;
//
//         // Build the UserOp
//         IEntryPoint.UserOperation memory userOp = _buildUserOp(
//             address(account),
//             abi.encodeCall(account.execute, (recipient, value, ""))
//         );
//
//         // Sign with owner key
//         bytes32 userOpHash = _getUserOpHash(userOp);
//         userOp.signature   = _sign(ownerPrivKey, userOpHash);
//
//         // Bundler submits
//         IEntryPoint.UserOperation[] memory ops = new IEntryPoint.UserOperation[](1);
//         ops[0] = userOp;
//
//         vm.prank(bundler);
//         entryPoint.handleOps(ops, payable(bundler));
//
//         assertEq(recipient.balance, value, "Recipient did not receive ETH");
//     }
//
//     // -------------------------------------------------------
//     // Test: invalid signature must fail
//     // -------------------------------------------------------
//     function test_4337_InvalidSignature_Fails() public {
//         IEntryPoint.UserOperation memory userOp = _buildUserOp(
//             address(account),
//             abi.encodeCall(account.execute, (makeAddr("r"), 0, ""))
//         );
//
//         // Sign with WRONG key
//         userOp.signature = _sign(0xBADBAD, _getUserOpHash(userOp));
//
//         IEntryPoint.UserOperation[] memory ops = new IEntryPoint.UserOperation[](1);
//         ops[0] = userOp;
//
//         vm.expectRevert(); // FailedOp: AA24 signature error
//         vm.prank(bundler);
//         entryPoint.handleOps(ops, payable(bundler));
//     }
//
//     // -------------------------------------------------------
//     // Test: Paymaster sponsors gas
//     // -------------------------------------------------------
//     function test_4337_Paymaster_SponsorGas() public {
//         // Sponsor the account
//         paymaster.setSponsored(address(account), true);
//         paymaster.depositToEntryPoint{value: 0.5 ether}();
//
//         IEntryPoint.UserOperation memory userOp = _buildUserOp(
//             address(account),
//             abi.encodeCall(account.execute, (makeAddr("r"), 0, ""))
//         );
//         // Include paymaster in UserOp
//         userOp.paymasterAndData = abi.encodePacked(address(paymaster));
//         userOp.signature        = _sign(ownerPrivKey, _getUserOpHash(userOp));
//
//         IEntryPoint.UserOperation[] memory ops = new IEntryPoint.UserOperation[](1);
//         ops[0] = userOp;
//
//         vm.prank(bundler);
//         entryPoint.handleOps(ops, payable(bundler)); // must not revert
//     }
//
//     // -------------------------------------------------------
//     // Fuzz: nonce is always incremental — each UserOp uses a unique nonce
//     // -------------------------------------------------------
//     function testFuzz_4337_NonceAlwaysIncrements(uint8 numOps) public {
//         numOps = uint8(bound(numOps, 1, 10));
//
//         for (uint256 i = 0; i < numOps; i++) {
//             uint256 nonceBefore = entryPoint.getNonce(address(account), 0);
//
//             IEntryPoint.UserOperation memory op = _buildUserOp(
//                 address(account),
//                 abi.encodeCall(account.execute, (makeAddr("r"), 0, ""))
//             );
//             op.nonce     = nonceBefore;
//             op.signature = _sign(ownerPrivKey, _getUserOpHash(op));
//
//             IEntryPoint.UserOperation[] memory ops = new IEntryPoint.UserOperation[](1);
//             ops[0] = op;
//             vm.prank(bundler);
//             entryPoint.handleOps(ops, payable(bundler));
//
//             assertEq(entryPoint.getNonce(address(account), 0), nonceBefore + 1);
//         }
//     }
//
//     // -------------------------------------------------------
//     // Internal helpers
//     // -------------------------------------------------------
//     function _buildUserOp(
//         address sender,
//         bytes memory callData
//     ) internal view returns (IEntryPoint.UserOperation memory) {
//         return IEntryPoint.UserOperation({
//             sender:               sender,
//             nonce:                entryPoint.getNonce(sender, 0),
//             initCode:             "",
//             callData:             callData,
//             callGasLimit:         200_000,
//             executionGasLimit:    200_000,
//             preVerificationGas:   50_000,
//             maxFeePerGas:         1 gwei,
//             maxPriorityFeePerGas: 1 gwei,
//             paymasterAndData:     "",
//             signature:            ""
//         });
//     }
//
//     function _getUserOpHash(IEntryPoint.UserOperation memory op)
//         internal view returns (bytes32)
//     {
//         return keccak256(abi.encode(
//             keccak256(abi.encode(
//                 op.sender, op.nonce, keccak256(op.initCode),
//                 keccak256(op.callData), op.callGasLimit, op.executionGasLimit,
//                 op.preVerificationGas, op.maxFeePerGas, op.maxPriorityFeePerGas,
//                 keccak256(op.paymasterAndData)
//             )),
//             address(entryPoint),
//             block.chainid
//         ));
//     }
//
//     function _sign(uint256 privKey, bytes32 hash)
//         internal pure returns (bytes memory)
//     {
//         bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(privKey, ethHash);
//         return abi.encodePacked(r, s, v);
//     }
// }

// ============================================================
// SECTION 10: TRANSIENT STORAGE — EIP-1153 (Solidity 0.8.24+)
// ============================================================

/*
 * Transient storage (tstore/tload) is a new data location:
 * - Persists only during the transaction (like memory, but shared across calls)
 * - Much cheaper than storage (100 gas vs 20,000 gas cold SSTORE)
 * - Ideal for: reentrancy guards, temporary flags, per-transaction caches
 *
 * Available since EIP-1153 (activated in Dencun, March 2024)
 * Solidity supports it via assembly: tstore(slot, value) / tload(slot)
 */

contract TransientReentrancyGuard {

    // Lock slot — value is automatically cleared at end of transaction.
    // Inline assembly only accepts literal constants, so we precompute the slot:
    //   uint256(keccak256("reentrancy.lock"))
    uint256 private constant LOCK_SLOT =
        0x64a9b57dc8f37d6cf7ade67df9cbc2d8e07dcc05c05f7585101d6985cc3bd3f6;

    error Reentrancy();

    modifier nonReentrant() {
        assembly {
            if tload(LOCK_SLOT) { revert(0, 0) } // if locked, revert
            tstore(LOCK_SLOT, 1)                  // lock
        }
        _;
        assembly {
            tstore(LOCK_SLOT, 0)                  // unlock
        }
    }

    // Gas comparison: transient vs storage reentrancy guard
    // tstore/tload: ~100 gas (warm) vs SSTORE/SLOAD: ~20,000/~2,100 gas
}

// contract TransientStorageTest is Test {
//
//     TransientReentrancyGuard guard;
//
//     function setUp() public {
//         guard = new TransientReentrancyGuard();
//     }
//
//     // Verify that the lock clears between transactions
//     function test_Transient_LockClearsAfterTx() public {
//         // Tx 1: uses the lock
//         guard.protectedOperation();
//
//         // Tx 2: lock must be cleared (new transaction)
//         guard.protectedOperation(); // must not revert
//     }
//
//     // Gas benchmark: transient vs storage guard
//     function test_Gas_TransientVsStorage() public {
//         StorageGuard sg = new StorageGuard();
//         TransientReentrancyGuard tg = new TransientReentrancyGuard();
//
//         uint256 g1 = gasleft();
//         sg.protectedOperation();
//         uint256 gasStorage = g1 - gasleft();
//
//         uint256 g2 = gasleft();
//         tg.protectedOperation();
//         uint256 gasTransient = g2 - gasleft();
//
//         console.log("Gas (storage guard):", gasStorage);
//         console.log("Gas (transient guard):", gasTransient);
//         assertLt(gasTransient, gasStorage);
//     }
// }

// ============================================================
// SECTION 11: ADVANCED TESTING PATTERNS
// ============================================================

/*
 * DIFFERENTIAL TESTING
 * Compares two implementations of the same algorithm.
 * Useful for: verifying refactors, optimizations, ports from other languages.
 */

// contract DifferentialTest is Test {
//
//     // Two implementations of the same royalty calculation
//     ERC2981Royalty v1 = new ERC2981RoyaltyV1();
//     ERC2981Royalty v2 = new ERC2981RoyaltyV2();  // optimized version
//
//     function testFuzz_Differential_RoyaltyCalc(
//         uint256 tokenId,
//         uint256 salePrice
//     ) public {
//         salePrice = bound(salePrice, 0, type(uint128).max);
//
//         (address r1, uint256 amount1) = v1.royaltyInfo(tokenId, salePrice);
//         (address r2, uint256 amount2) = v2.royaltyInfo(tokenId, salePrice);
//
//         // Both must return exactly the same result
//         assertEq(r1, r2, "Different recipient");
//         assertEq(amount1, amount2, "Different amount");
//     }
// }

/*
 * SYMBOLIC EXECUTION HINTS
 * Solidity's SMTChecker can be enabled for basic formal verification.
 * foundry.toml:
 * [profile.default]
 * via_ir = true
 *
 * In the contract:
 * /// @custom:smtchecker abstract-function-nondet
 */

/*
 * INTEGRATION TEST PATTERN
 * Tests the complete end-to-end flow without mocks.
 */

// contract IntegrationTest is Test {
//
//     ERC20Token    token;
//     Factory       factory;
//     PullPayment   payment;
//     address       owner   = makeAddr("owner");
//     address       alice   = makeAddr("alice");
//     address       bob     = makeAddr("bob");
//
//     function setUp() public {
//         vm.startPrank(owner);
//         token   = new ERC20Token("Token", "TKN", 1_000_000e18);
//         factory = new Factory();
//         payment = new PullPayment();
//         vm.stopPrank();
//     }
//
//     // Full flow: mint → approve → transferFrom → burn
//     function test_Integration_FullTokenLifecycle() public {
//         // 1. Mint to alice
//         vm.prank(owner);
//         token.mint(alice, 500e18);
//         assertEq(token.balanceOf(alice), 500e18);
//
//         // 2. Alice approves bob
//         vm.prank(alice);
//         token.approve(bob, 200e18);
//         assertEq(token.allowance(alice, bob), 200e18);
//
//         // 3. Bob transfers from alice's account
//         vm.prank(bob);
//         token.transferFrom(alice, bob, 150e18);
//         assertEq(token.balanceOf(bob),   150e18);
//         assertEq(token.balanceOf(alice), 350e18);
//         assertEq(token.allowance(alice, bob), 50e18);
//
//         // 4. Bob burns his tokens
//         vm.prank(bob);
//         token.burn(150e18);
//         assertEq(token.totalSupply(), 1_000_000e18 + 500e18 - 150e18);
//     }
// }

// ============================================================
// SECTION 12: FOUNDRY.TOML — COMPLETE REFERENCE CONFIGURATION
// ============================================================

/*
 * Complete foundry.toml for a professional project:
 *
 * [profile.default]
 * src            = "src"
 * out            = "out"
 * libs           = ["lib"]
 * solc           = "0.8.24"
 * optimizer      = true
 * optimizer_runs = 200
 * via_ir         = false        # true for maximum optimization (slower compile)
 * verbosity      = 3
 *
 * [profile.default.fuzz]
 * runs             = 1000       # default 256
 * max_test_rejects = 65536
 * seed             = "0x1"      # reproducible; remove for random seeds
 * dictionary_weight= 40         # % of inputs from dictionary vs random
 *
 * [profile.default.invariant]
 * runs             = 256
 * depth            = 50         # calls per sequence
 * fail_on_revert   = false      # true = treat reverts as failures
 * call_override_selector = false
 *
 * [profile.ci]                  # CI profile (more runs, slower)
 * fuzz      = { runs = 10000 }
 * invariant = { runs = 1000, depth = 100 }
 *
 * [rpc_endpoints]
 * mainnet  = "${MAINNET_RPC_URL}"
 * arbitrum = "${ARBITRUM_RPC_URL}"
 * optimism = "${OPTIMISM_RPC_URL}"
 * base     = "${BASE_RPC_URL}"
 *
 * [etherscan]
 * mainnet = { key = "${ETHERSCAN_API_KEY}" }
 *
 * [fmt]
 * line_length       = 100
 * tab_width         = 4
 * bracket_spacing   = true
 * int_types         = "long"    # uint256 not uint
 * multiline_func_header = "params_first"
 *
 * # Remappings (alternative to remappings.txt)
 * remappings = [
 *   "@openzeppelin/=lib/openzeppelin-contracts/",
 *   "forge-std/=lib/forge-std/src/",
 *   "@aa/=lib/account-abstraction/contracts/",
 * ]
 */

// ============================================================
// SECTION 13: PROFESSIONAL TESTING CHECKLIST
// ============================================================

/*
 * Before considering a contract "tested":
 *
 * UNIT TESTS
 * [ ] Happy path for every public/external function
 * [ ] Every revert path covered (custom errors and strings)
 * [ ] All emitted events verified
 * [ ] Edge cases: 0, type(uint256).max, address(0)
 * [ ] view/pure functions return correct values
 * [ ] Modifiers work correctly (onlyOwner, nonReentrant, etc.)
 *
 * FUZZ TESTS
 * [ ] Mathematical properties (totalSupply, balance, etc.)
 * [ ] No unexpected reverts on valid inputs
 * [ ] Commutativity/associativity where applicable
 * [ ] Minimum 1000 runs in CI
 *
 * INVARIANT TESTS
 * [ ] Value conservation (tokens don't disappear or appear)
 * [ ] Access control never breaks
 * [ ] State never becomes inconsistent
 * [ ] Minimum 1000 runs x 50 depth in CI
 *
 * INTEGRATION TESTS
 * [ ] End-to-end flows without mocks
 * [ ] Interaction with external contracts (via fork)
 * [ ] Multi-user scenarios
 *
 * GAS
 * [ ] forge snapshot generated and committed to repo
 * [ ] CI fails if gas exceeds defined threshold
 * [ ] Critical functions have assertLt(gasUsed, limit)
 *
 * COVERAGE
 * [ ] forge coverage > 90% line coverage
 * [ ] forge coverage > 85% branch coverage
 * [ ] 100% coverage on security-critical functions
 *
 * SECURITY-SPECIFIC
 * [ ] Reentrancy tested with attacker contract
 * [ ] Overflow/underflow tested via fuzz
 * [ ] Signatures tested with replay attack
 * [ ] Front-running mitigated and tested
 */

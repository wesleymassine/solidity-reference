// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// ============================================================================
// SOLIDITY ETHER TRANSFER METHODS - Complete Reference
// From Zero to Professional
// ============================================================================

contract EtherTransfer {
    // Track balances
    mapping(address => uint256) public balances;

    // Events
    event Received(address indexed from, uint256 amount);
    event Sent(address indexed to, uint256 amount, string method);
    event TransferFailed(address indexed to, uint256 amount, string reason);

    // ============================================================================
    // 1. RECEIVING ETHER
    // ============================================================================

    // Receive function - called when Ether is sent with empty calldata
    receive() external payable {
        balances[msg.sender] += msg.value;
        emit Received(msg.sender, msg.value);
    }

    // Fallback function - called when no other function matches
    fallback() external payable {
        emit Received(msg.sender, msg.value);
    }

    // Regular payable function
    function deposit() external payable {
        require(msg.value > 0, "Must send Ether");
        balances[msg.sender] += msg.value;
        emit Received(msg.sender, msg.value);
    }

    // ============================================================================
    // 2. TRANSFER METHOD
    // ============================================================================
    // - Forwards 2300 gas (fixed)
    // - Reverts on failure
    // - Simple and safe for basic transfers
    // - LIMITED: Cannot call complex functions (gas limit too low)

    function transferMethod(
        address payable recipient,
        uint256 amount
    ) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;

        // transfer() reverts on failure
        recipient.transfer(amount);

        emit Sent(recipient, amount, "transfer");
    }

    // ============================================================================
    // 3. SEND METHOD
    // ============================================================================
    // - Forwards 2300 gas (fixed)
    // - Returns bool (true/false) instead of reverting
    // - Must check return value manually
    // - LIMITED: Same gas constraints as transfer()

    function sendMethod(
        address payable recipient,
        uint256 amount
    ) external returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;

        // send() returns false on failure, doesn't revert
        bool success = recipient.send(amount);

        if (success) {
            emit Sent(recipient, amount, "send");
        } else {
            // Revert on failure (or handle differently)
            balances[msg.sender] += amount; // Refund
            emit TransferFailed(recipient, amount, "send failed");
            revert("Send failed");
        }

        return success;
    }

    // ============================================================================
    // 4. CALL METHOD (RECOMMENDED)
    // ============================================================================
    // - Forwards all available gas (or specify amount)
    // - Returns (bool success, bytes memory data)
    // - Most flexible and recommended method
    // - MUST check return value
    // - Can trigger fallback/receive functions

    function callMethod(address payable recipient, uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;

        // call() returns (bool success, bytes memory returnData)
        (bool success, ) = recipient.call{value: amount}("");

        require(success, "Call failed");

        emit Sent(recipient, amount, "call");
    }

    // Call with gas limit
    function callWithGasLimit(
        address payable recipient,
        uint256 amount,
        uint256 gasLimit
    ) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;

        // Specify gas limit
        (bool success, ) = recipient.call{value: amount, gas: gasLimit}("");

        require(success, "Call failed");

        emit Sent(recipient, amount, "call with gas limit");
    }

    // ============================================================================
    // 5. COMPARISON: TRANSFER VS SEND VS CALL
    // ============================================================================

    /*
    | Method   | Gas Forwarded | On Failure | Use Case                    |
    |----------|---------------|------------|-----------------------------|
    | transfer | 2300 (fixed)  | Reverts    | Simple transfers (legacy)   |
    | send     | 2300 (fixed)  | Returns    | Simple transfers (legacy)   |
    | call     | All/Custom    | Returns    | **RECOMMENDED** (modern)    |
    
    WHY CALL IS RECOMMENDED:
    1. Works with smart contracts that need more than 2300 gas
    2. Forward custom gas amounts
    3. More flexible for complex interactions
    4. Industry best practice since EIP-1884
    */

    // ============================================================================
    // 6. REENTRANCY PROTECTION
    // ============================================================================
    // When using call(), protect against reentrancy attacks
    // Use Checks-Effects-Interactions pattern

    bool private locked;

    modifier noReentrancy() {
        require(!locked, "No reentrancy");
        locked = true;
        _;
        locked = false;
    }

    function safeWithdraw(uint256 amount) external noReentrancy {
        // CHECKS
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // EFFECTS (update state before external call)
        balances[msg.sender] -= amount;

        // INTERACTIONS (external call last)
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit Sent(msg.sender, amount, "withdraw");
    }

    // ============================================================================
    // 7. WITHDRAWAL PATTERN
    // ============================================================================
    // Instead of pushing Ether, let users pull it
    // Safer against reentrancy and failed transfers

    mapping(address => uint256) public pendingWithdrawals;

    function allowWithdrawal(address user, uint256 amount) external {
        // Mark Ether as withdrawable
        pendingWithdrawals[user] += amount;
    }

    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending withdrawal");

        // Set to zero before transfer (reentrancy protection)
        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            // Restore amount if transfer fails
            pendingWithdrawals[msg.sender] = amount;
            revert("Withdrawal failed");
        }

        emit Sent(msg.sender, amount, "withdrawal");
    }

    // ============================================================================
    // 8. BATCH TRANSFERS
    // ============================================================================

    function batchTransfer(
        address payable[] calldata recipients,
        uint256[] calldata amounts
    ) external payable {
        require(recipients.length == amounts.length, "Length mismatch");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }

        require(msg.value >= totalAmount, "Insufficient Ether sent");

        for (uint256 i = 0; i < recipients.length; i++) {
            (bool success, ) = recipients[i].call{value: amounts[i]}("");
            if (success) {
                emit Sent(recipients[i], amounts[i], "batch transfer");
            } else {
                emit TransferFailed(
                    recipients[i],
                    amounts[i],
                    "batch transfer failed"
                );
            }
        }
    }

    // ============================================================================
    // 9. ERROR HANDLING PATTERNS
    // ============================================================================

    // Pattern 1: Try-catch with call
    function safeSend(
        address payable recipient,
        uint256 amount
    ) external returns (bool) {
        (bool success, bytes memory data) = recipient.call{value: amount}("");

        if (!success) {
            // Handle specific failure reasons
            if (data.length > 0) {
                // Contract reverted with reason
                emit TransferFailed(recipient, amount, string(data));
            } else {
                // Transfer failed (out of gas, etc.)
                emit TransferFailed(recipient, amount, "Unknown error");
            }
            return false;
        }

        emit Sent(recipient, amount, "safe send");
        return true;
    }

    // Pattern 2: Pull over push
    function rewardUser(address user, uint256 amount) external {
        // DON'T push Ether directly
        // Instead, record it for user to pull later
        pendingWithdrawals[user] += amount;
    }

    // ============================================================================
    // 10. GAS CONSIDERATIONS
    // ============================================================================

    function demonstrateGasIssues() external view returns (string memory) {
        // transfer() and send() forward only 2300 gas
        // This may not be enough if recipient is a contract with:
        // - Complex receive/fallback functions
        // - State changes
        // - Event emissions
        // - External calls

        // call() forwards all available gas by default
        // Can be limited with: recipient.call{value: x, gas: gasLimit}("")

        return "See comments for gas details";
    }

    // ============================================================================
    // 11. SECURITY BEST PRACTICES
    // ============================================================================

    // GOOD: Checks-Effects-Interactions pattern
    function goodWithdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");

        balances[msg.sender] = 0; // Effect BEFORE interaction

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    // BAD: Interaction before effect (vulnerable to reentrancy)
    function badWithdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        balances[msg.sender] = 0; // Effect AFTER interaction - VULNERABLE!
    }

    // ============================================================================
    // 12. REAL-WORLD PATTERNS
    // ============================================================================

    // Escrow pattern
    mapping(bytes32 => Escrow) public escrows;

    struct Escrow {
        address payer;
        address payee;
        uint256 amount;
        bool released;
    }

    function createEscrow(bytes32 escrowId, address payee) external payable {
        require(msg.value > 0, "Must send Ether");
        require(escrows[escrowId].amount == 0, "Escrow exists");

        escrows[escrowId] = Escrow({
            payer: msg.sender,
            payee: payee,
            amount: msg.value,
            released: false
        });
    }

    function releaseEscrow(bytes32 escrowId) external {
        Escrow storage escrow = escrows[escrowId];
        require(msg.sender == escrow.payer, "Only payer can release");
        require(!escrow.released, "Already released");
        require(escrow.amount > 0, "No escrow");

        escrow.released = true;

        (bool success, ) = escrow.payee.call{value: escrow.amount}("");
        require(success, "Transfer failed");

        emit Sent(escrow.payee, escrow.amount, "escrow release");
    }

    // ============================================================================
    // 13. HELPER FUNCTIONS
    // ============================================================================

    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // ============================================================================
    // KEY TAKEAWAYS FOR PROFESSIONAL DEVELOPERS:
    // ============================================================================
    // 1. **USE CALL() - It's the recommended method**
    // 2. transfer() and send() forward only 2300 gas (often insufficient)
    // 3. Always check return value when using call() or send()
    // 4. Use Checks-Effects-Interactions pattern
    // 5. Protect against reentrancy attacks
    // 6. Consider withdrawal pattern (pull over push)
    // 7. Update state BEFORE external calls
    // 8. Use reentrancy guards for sensitive functions
    // 9. Handle failed transfers gracefully
    // 10. Test with both EOAs and contracts as recipients
    // 11. call() forwards all gas unless limited
    // 12. Empty string "" in call means no function call
    // 13. Batch operations need careful error handling
    // 14. Consider gas costs for recipient contracts
    // ============================================================================
}

// ============================================================================
// EXAMPLE: Malicious Contract (for testing)
// ============================================================================
contract MaliciousRecipient {
    uint256 public counter;

    // Expensive receive function (uses > 2300 gas)
    receive() external payable {
        // This will fail with transfer() or send()
        // But works with call()
        counter++;
        counter++;
        counter++;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AegisVault.sol";
import "../src/MockTokens.sol";

/// @title AegisVault Tests
/// @notice Basic tests for the private lending protocol
contract AegisVaultTest is Test {
    AegisVault public vault;
    MockETH public collateral;
    MockUSDC public debt;

    address public owner = address(this);
    address public alice = address(0x1);
    address public bob = address(0x2);

    // Mock SP1 verifier that always returns true (for testing)
    MockSP1Verifier public verifier;

    // Mock verification keys
    bytes32 public depositVkey = keccak256("DEPOSIT_VKEY");
    bytes32 public borrowVkey = keccak256("BORROW_VKEY");

    function setUp() public {
        // Deploy mock tokens
        collateral = new MockETH();
        debt = new MockUSDC();

        // Deploy mock verifier
        verifier = new MockSP1Verifier();

        // Deploy AegisVault
        vault = new AegisVault(
            address(verifier),
            depositVkey,
            borrowVkey,
            address(collateral),
            address(debt)
        );

        // Mint tokens to test users
        collateral.mint(alice, 100 ether);
        debt.mint(owner, 1000000e6); // 1M USDC

        // Fund the vault with debt tokens
        debt.approve(address(vault), 1000000e6);
        vault.fundVault(1000000e6);
    }

    function testDeployment() public view {
        assertEq(address(vault.COLLATERAL_TOKEN()), address(collateral));
        assertEq(address(vault.DEBT_TOKEN()), address(debt));
        assertEq(vault.owner(), owner);
    }

    function testDepositCreatesCommitment() public {
        vm.startPrank(alice);

        // Approve collateral
        uint256 depositAmount = 10 ether;
        collateral.approve(address(vault), depositAmount);

        // Create mock proof and public values
        bytes memory proof = hex"00"; // Dummy proof
        
        // Mock public values: commitment_hash (32 bytes) + is_valid (1 byte)
        bytes32 commitment = keccak256("test_commitment");
        bytes memory publicValues = abi.encodePacked(commitment, uint8(1));

        // Perform deposit
        vault.deposit(depositAmount, proof, publicValues);

        // Verify state changes
        assertEq(vault.getCommitmentCount(), 1);
        assertEq(vault.getCommitment(0), commitment);
        assertEq(vault.getCollateralBalance(), depositAmount);

        vm.stopPrank();
    }

    function testBorrowWithValidProof() public {
        // First, setup a deposit (alice deposits)
        vm.startPrank(alice);
        uint256 depositAmount = 10 ether;
        collateral.approve(address(vault), depositAmount);
        
        bytes32 depositCommitment = keccak256("alice_deposit");
        bytes memory depositProof = hex"00";
        bytes memory depositPublicValues = abi.encodePacked(depositCommitment, uint8(1));
        vault.deposit(depositAmount, depositProof, depositPublicValues);
        vm.stopPrank();

        // Now bob borrows (using alice's hidden collateral via ZK proof)
        uint256 borrowAmount = 5000e6; // 5000 USDC
        bytes32 nullifier = keccak256("alice_nullifier");
        bytes32 newCommitment = keccak256("alice_new_commitment");

        // Mock public values for borrow using helper
        bytes memory borrowPublicValues = _encodeBorrowOutput(
            nullifier,
            newCommitment,
            bob,
            // Safe cast: borrowAmount is within uint128 range for testing
            // forge-lint: disable-next-line(unsafe-typecast)
            uint128(borrowAmount),
            1 // is_valid
        );
        bytes memory borrowProof = hex"01";

        uint256 bobBalanceBefore = debt.balanceOf(bob);

        // Execute borrow
        vm.prank(bob);
        vault.borrow(borrowProof, borrowPublicValues);

        // Verify borrow succeeded
        assertEq(debt.balanceOf(bob), bobBalanceBefore + borrowAmount);
        assertTrue(vault.isNullifierSpent(nullifier));
        assertEq(vault.getCommitmentCount(), 2); // Original + new commitment
    }

    function testBorrowRevertsOnDoubleSpend() public {
        // Setup: alice deposits
        vm.startPrank(alice);
        collateral.approve(address(vault), 10 ether);
        bytes memory depositProof = hex"00";
        bytes32 depositCommitment = keccak256("commitment1");
        bytes memory depositPublicValues = abi.encodePacked(depositCommitment, uint8(1));
        vault.deposit(10 ether, depositProof, depositPublicValues);
        vm.stopPrank();

        // First borrow
        bytes32 nullifier = keccak256("nullifier1");
        bytes32 newCommitment1 = keccak256("commitment2");
        uint128 borrowAmt = 1000e6;
        
        bytes memory borrowPublicValues1 = _encodeBorrowOutput(
            nullifier, newCommitment1, bob, borrowAmt, 1
        );
        
        vault.borrow(hex"01", borrowPublicValues1);

        // Attempt second borrow with same nullifier (should fail)
        bytes32 newCommitment2 = keccak256("commitment3");
        bytes memory borrowPublicValues2 = _encodeBorrowOutput(
            nullifier, // Same nullifier!
            newCommitment2, bob, borrowAmt, 1
        );

        vm.expectRevert(AegisVault.NullifierAlreadySpent.selector);
        vault.borrow(hex"01", borrowPublicValues2);
    }

    function testGetters() public view {
        assertEq(vault.getCollateralBalance(), 0);
        assertGt(vault.getDebtBalance(), 0);
        assertEq(vault.getCommitmentCount(), 0);
    }

    // Helper function to encode borrow output like Rust does
    function _encodeBorrowOutput(
        bytes32 nullifier,
        bytes32 newCommitment,
        address recipient,
        uint128 amount,
        uint8 isValid
    ) internal pure returns (bytes memory) {
        bytes memory result = new bytes(101);
        
        // Copy nullifier (bytes 0-31)
        for (uint i = 0; i < 32; i++) {
            result[i] = nullifier[i];
        }
        
        // Copy new commitment (bytes 32-63)
        for (uint i = 0; i < 32; i++) {
            result[32 + i] = newCommitment[i];
        }
        
        // Copy recipient address (bytes 64-83)
        bytes20 recipientBytes = bytes20(recipient);
        for (uint i = 0; i < 20; i++) {
            result[64 + i] = recipientBytes[i];
        }
        
        // Copy amount as u128 (bytes 84-99, little-endian like Rust)
        for (uint i = 0; i < 16; i++) {
            // Safe cast: extracting single byte from amount
            // forge-lint: disable-next-line(unsafe-typecast)
            result[84 + i] = bytes1(uint8(amount >> (8 * i)));
        }
        
        // Set is_valid (byte 100)
        result[100] = bytes1(isValid);
        
        return result;
    }
}

/// @title MockSP1Verifier
/// @notice Mock verifier that always passes (for testing)
contract MockSP1Verifier is ISP1Verifier {
    function verifyProof(
        bytes32, // vkey
        bytes calldata, // publicValues  
        bytes calldata  // proofBytes
    ) external pure override {
        // Always pass verification for testing
        return;
    }
}

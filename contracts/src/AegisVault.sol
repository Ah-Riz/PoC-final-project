// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@sp1-contracts/ISP1Verifier.sol";

/// @title AegisVault - Private Lending Protocol with ZK Proofs
/// @notice Allows private deposits and borrows using SP1 zero-knowledge proofs
/// @dev This is a simplified PoC version for Mantle testnet
contract AegisVault {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    /// @notice SP1 proof verifier contract
    ISP1Verifier public immutable verifier;

    /// @notice Verification key for deposit proofs
    bytes32 public depositVkey;

    /// @notice Verification key for borrow proofs  
    bytes32 public borrowVkey;

    /// @notice Collateral token (e.g., mETH)
    IERC20 public immutable collateralToken;

    /// @notice Debt token (e.g., USDC)
    IERC20 public immutable debtToken;

    /// @notice Current Merkle root of all commitments
    bytes32 public merkleRoot;

    /// @notice Mapping of spent nullifiers (prevents double-spending)
    mapping(bytes32 => bool) public nullifiers;

    /// @notice Array of all commitments
    bytes32[] public commitments;

    /// @notice Contract owner
    address public owner;

    // ============ Events ============

    event Deposit(
        bytes32 indexed commitment,
        uint256 timestamp
    );

    event Borrow(
        bytes32 indexed nullifier,
        bytes32 indexed newCommitment,
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );

    event MerkleRootUpdated(bytes32 oldRoot, bytes32 newRoot);

    // ============ Errors ============

    error UnauthorizedCaller();
    error InvalidProof();
    error NullifierAlreadySpent();
    error InsufficientLiquidity();
    error InvalidCommitment();

    // ============ Modifiers ============

    modifier onlyOwner() {
        if (msg.sender != owner) revert UnauthorizedCaller();
        _;
    }

    // ============ Constructor ============

    constructor(
        address _verifier,
        bytes32 _depositVkey,
        bytes32 _borrowVkey,
        address _collateralToken,
        address _debtToken
    ) {
        verifier = ISP1Verifier(_verifier);
        depositVkey = _depositVkey;
        borrowVkey = _borrowVkey;
        collateralToken = IERC20(_collateralToken);
        debtToken = IERC20(_debtToken);
        owner = msg.sender;
        
        // Initialize with empty merkle root
        merkleRoot = bytes32(0);
    }

    // ============ Core Functions ============

    /// @notice Deposit collateral and create a private commitment
    /// @param amount Amount of collateral to deposit
    /// @param proof SP1 ZK proof that commitment is valid
    /// @param publicValues Public outputs from the ZK proof
    function deposit(
        uint256 amount,
        bytes calldata proof,
        bytes calldata publicValues
    ) external {
        // Transfer collateral from user
        collateralToken.safeTransferFrom(msg.sender, address(this), amount);

        // Verify the ZK proof
        verifier.verifyProof(depositVkey, publicValues, proof);

        // Decode the commitment from public values
        // publicValues format: DepositOutput { commitment_hash: [u8; 32], is_valid: u8 }
        bytes32 commitment;
        uint8 isValid;
        
        assembly {
            // Load commitment (first 32 bytes)
            commitment := calldataload(publicValues.offset)
            // Load is_valid (next byte)
            isValid := byte(0, calldataload(add(publicValues.offset, 32)))
        }

        if (isValid != 1) revert InvalidProof();
        if (commitment == bytes32(0)) revert InvalidCommitment();

        // Add commitment to tree
        commitments.push(commitment);
        bytes32 oldRoot = merkleRoot;
        merkleRoot = keccak256(abi.encodePacked(merkleRoot, commitment));

        emit Deposit(commitment, block.timestamp);
        emit MerkleRootUpdated(oldRoot, merkleRoot);
    }

    /// @notice Borrow funds against hidden collateral
    /// @param proof SP1 ZK proof that borrow is valid
    /// @param publicValues Public outputs from the ZK proof
    function borrow(
        bytes calldata proof,
        bytes calldata publicValues
    ) external {
        // Verify the ZK proof first
        verifier.verifyProof(borrowVkey, publicValues, proof);

        // Decode public values from proof
        // BorrowOutput format from Rust:
        // - nullifier_hash: [u8; 32]          offset: 0
        // - new_commitment_hash: [u8; 32]     offset: 32
        // - recipient_address: [u8; 20]       offset: 64
        // - borrow_amount: u128               offset: 84
        // - is_valid: u8                      offset: 100
        
        bytes32 nullifierHash;
        bytes32 newCommitment;
        address recipient;
        uint128 borrowAmount;
        uint8 isValid;

        // Decode from calldata - must handle dynamic bytes carefully
        require(publicValues.length >= 101, "Invalid public values length");
        
        assembly {
            //Load nullifier (bytes 0-31 of publicValues)
            nullifierHash := calldataload(publicValues.offset)
            
            // Load new commitment (bytes 32-63)
            newCommitment := calldataload(add(publicValues.offset, 32))
            
            // Load recipient address (bytes 64-83)
            // calldataload loads 32 bytes, but we only want the first 20
            let addrWord := calldataload(add(publicValues.offset, 64))
            recipient := shr(96, addrWord) // Shift right 96 bits (12 bytes) to get address
        }
        
        // Borrow amount: bytes 84-99 (16 bytes, little-endian u128)
        // Read byte by byte from calldata and convert to big-endian
        for (uint i = 0; i < 16; i++) {
            borrowAmount |= uint128(uint8(publicValues[84 + i])) << (8 * i);
        }
        
        // Is valid: byte 100
        isValid = uint8(publicValues[100]);

        // Validate proof result
        if (isValid != 1) revert InvalidProof();

        // Check nullifier not already spent
        if (nullifiers[nullifierHash]) revert NullifierAlreadySpent();

        // Check contract has enough liquidity
        uint256 balance = debtToken.balanceOf(address(this));
        if (balance < borrowAmount) revert InsufficientLiquidity();

        // Mark nullifier as spent
        nullifiers[nullifierHash] = true;

        // Add new commitment to tree
        commitments.push(newCommitment);
        bytes32 oldRoot = merkleRoot;
        merkleRoot = keccak256(abi.encodePacked(merkleRoot, newCommitment));

        // Transfer borrowed funds to recipient
        debtToken.safeTransfer(recipient, borrowAmount);

        emit Borrow(nullifierHash, newCommitment, recipient, borrowAmount, block.timestamp);
        emit MerkleRootUpdated(oldRoot, merkleRoot);
    }

    // ============ View Functions ============

    /// @notice Get the total number of commitments
    function getCommitmentCount() external view returns (uint256) {
        return commitments.length;
    }

    /// @notice Get a commitment by index
    function getCommitment(uint256 index) external view returns (bytes32) {
        return commitments[index];
    }

    /// @notice Check if a nullifier has been spent
    function isNullifierSpent(bytes32 nullifierHash) external view returns (bool) {
        return nullifiers[nullifierHash];
    }

    /// @notice Get contract collateral balance
    function getCollateralBalance() external view returns (uint256) {
        return collateralToken.balanceOf(address(this));
    }

    /// @notice Get contract debt token balance
    function getDebtBalance() external view returns (uint256) {
        return debtToken.balanceOf(address(this));
    }

    // ============ Admin Functions ============

    /// @notice Fund the vault with debt tokens (for testing)
    function fundVault(uint256 amount) external onlyOwner {
        debtToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Update verification keys (emergency use only)
    function updateVkeys(bytes32 _depositVkey, bytes32 _borrowVkey) external onlyOwner {
        depositVkey = _depositVkey;
        borrowVkey = _borrowVkey;
    }
}

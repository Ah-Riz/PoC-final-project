// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title TraditionalVault - Standard Lending Protocol (NO PRIVACY)
/// @notice Regular DeFi lending - all data is PUBLIC on blockchain
/// @dev This is for comparison with the private AegisVault
contract TraditionalVault {
    using SafeERC20 for IERC20;

    // ============ State Variables ============

    /// @notice Collateral token (e.g., ETH)
    IERC20 public immutable COLLATERAL_TOKEN;

    /// @notice Debt token (e.g., USDC)
    IERC20 public immutable DEBT_TOKEN;

    /// @notice Contract owner
    address public owner;

    /// @notice User collateral balances (PUBLIC!)
    mapping(address => uint256) public userCollateral;

    /// @notice User debt balances (PUBLIC!)
    mapping(address => uint256) public userDebt;

    /// @notice Maximum LTV ratio (80% = 8000 basis points)
    uint256 public constant MAX_LTV_BPS = 8000;
    uint256 public constant BPS_DENOMINATOR = 10000;

    /// @notice Collateral price in USDC (simplified for demo)
    uint256 public collateralPriceUSD = 2000e6; // $2000 per ETH

    // ============ Events ============

    event Deposit(address indexed user, uint256 amount, uint256 timestamp);
    event Borrow(address indexed user, uint256 amount, uint256 timestamp);
    event Repay(address indexed user, uint256 amount, uint256 timestamp);
    event Withdraw(address indexed user, uint256 amount, uint256 timestamp);

    // ============ Errors ============

    error UnauthorizedCaller();
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error NoDebt();
    error ExceedsLTV();

    // ============ Modifiers ============

    modifier onlyOwner() {
        if (msg.sender != owner) revert UnauthorizedCaller();
        _;
    }

    // ============ Constructor ============

    constructor(
        address _collateralToken,
        address _debtToken
    ) {
        COLLATERAL_TOKEN = IERC20(_collateralToken);
        DEBT_TOKEN = IERC20(_debtToken);
        owner = msg.sender;
    }

    // ============ Core Functions ============

    /// @notice Deposit collateral (PUBLIC - everyone can see your balance!)
    /// @param amount Amount of collateral to deposit
    function deposit(uint256 amount) external {
        // Transfer collateral from user
        COLLATERAL_TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        // Update PUBLIC balance (visible to everyone!)
        userCollateral[msg.sender] += amount;

        emit Deposit(msg.sender, amount, block.timestamp);
    }

    /// @notice Borrow against collateral (PUBLIC - everyone can see your debt!)
    /// @param amount Amount to borrow
    function borrow(uint256 amount) external {
        uint256 collateral = userCollateral[msg.sender];
        uint256 currentDebt = userDebt[msg.sender];
        uint256 newDebt = currentDebt + amount;

        // Check LTV ratio (all calculations PUBLIC!)
        uint256 collateralValue = (collateral * collateralPriceUSD) / 1e18;
        uint256 maxBorrow = (collateralValue * MAX_LTV_BPS) / BPS_DENOMINATOR;

        if (newDebt > maxBorrow) revert ExceedsLTV();

        // Check vault liquidity
        uint256 vaultBalance = DEBT_TOKEN.balanceOf(address(this));
        if (vaultBalance < amount) revert InsufficientLiquidity();

        // Update PUBLIC debt (visible to everyone!)
        userDebt[msg.sender] = newDebt;

        // Transfer borrowed funds
        DEBT_TOKEN.safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, amount, block.timestamp);
    }

    /// @notice Repay debt
    /// @param amount Amount to repay
    function repay(uint256 amount) external {
        uint256 debt = userDebt[msg.sender];
        if (debt == 0) revert NoDebt();

        uint256 repayAmount = amount > debt ? debt : amount;

        // Transfer repayment from user
        DEBT_TOKEN.safeTransferFrom(msg.sender, address(this), repayAmount);

        // Update PUBLIC debt
        userDebt[msg.sender] -= repayAmount;

        emit Repay(msg.sender, repayAmount, block.timestamp);
    }

    /// @notice Withdraw collateral
    /// @param amount Amount to withdraw
    function withdraw(uint256 amount) external {
        uint256 collateral = userCollateral[msg.sender];
        uint256 debt = userDebt[msg.sender];

        if (amount > collateral) revert InsufficientCollateral();

        // Calculate remaining collateral after withdrawal
        uint256 remainingCollateral = collateral - amount;
        
        // Check if remaining collateral covers debt
        if (debt > 0) {
            uint256 remainingValue = (remainingCollateral * collateralPriceUSD) / 1e18;
            uint256 maxBorrow = (remainingValue * MAX_LTV_BPS) / BPS_DENOMINATOR;
            
            if (debt > maxBorrow) revert ExceedsLTV();
        }

        // Update PUBLIC collateral
        userCollateral[msg.sender] = remainingCollateral;

        // Transfer collateral back to user
        COLLATERAL_TOKEN.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount, block.timestamp);
    }

    // ============ View Functions ============

    /// @notice Get user's collateral balance (PUBLIC!)
    function getUserCollateral(address user) external view returns (uint256) {
        return userCollateral[user];
    }

    /// @notice Get user's debt balance (PUBLIC!)
    function getUserDebt(address user) external view returns (uint256) {
        return userDebt[user];
    }

    /// @notice Get user's available borrow capacity (PUBLIC!)
    function getAvailableBorrow(address user) external view returns (uint256) {
        uint256 collateral = userCollateral[user];
        uint256 currentDebt = userDebt[user];

        uint256 collateralValue = (collateral * collateralPriceUSD) / 1e18;
        uint256 maxBorrow = (collateralValue * MAX_LTV_BPS) / BPS_DENOMINATOR;

        if (currentDebt >= maxBorrow) return 0;
        return maxBorrow - currentDebt;
    }

    /// @notice Get user's health factor (PUBLIC!)
    /// @return healthFactor Returns 100 for 100% (higher is safer)
    function getHealthFactor(address user) external view returns (uint256) {
        uint256 debt = userDebt[user];
        if (debt == 0) return type(uint256).max;

        uint256 collateral = userCollateral[user];
        uint256 collateralValue = (collateral * collateralPriceUSD) / 1e18;
        uint256 maxBorrow = (collateralValue * MAX_LTV_BPS) / BPS_DENOMINATOR;

        // Return percentage (100 = at limit, 200 = 2x safe, etc.)
        return (maxBorrow * 100) / debt;
    }

    /// @notice Get vault's total liquidity
    function getVaultLiquidity() external view returns (uint256) {
        return DEBT_TOKEN.balanceOf(address(this));
    }

    /// @notice Get vault's total collateral
    function getVaultCollateral() external view returns (uint256) {
        return COLLATERAL_TOKEN.balanceOf(address(this));
    }

    // ============ Admin Functions ============

    /// @notice Fund vault with debt tokens
    function fundVault(uint256 amount) external onlyOwner {
        DEBT_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Update collateral price
    function updatePrice(uint256 newPriceUSD) external onlyOwner {
        collateralPriceUSD = newPriceUSD;
    }
}

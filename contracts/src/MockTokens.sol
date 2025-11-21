// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockETH - Mock collateral token (simulates mETH/ETH)
/// @notice For testing purposes only
contract MockETH is ERC20, Ownable {
    constructor() ERC20("Mock ETH", "mETH") Ownable(msg.sender) {
        // Mint initial supply to deployer
        _mint(msg.sender, 1000000 * 10**decimals());
    }

    /// @notice Mint tokens for testing
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Returns 18 decimals (same as ETH)
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

/// @title MockUSDC - Mock stablecoin (simulates USDC)
/// @notice For testing purposes only
contract MockUSDC is ERC20, Ownable {
    constructor() ERC20("Mock USDC", "USDC") Ownable(msg.sender) {
        // Mint initial supply to deployer
        _mint(msg.sender, 10000000 * 10**decimals());
    }

    /// @notice Mint tokens for testing
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Returns 6 decimals (same as real USDC)
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

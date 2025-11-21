// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MockTokens.sol";
import "../src/AegisVault.sol";

/// @title Deploy Script for Aegis Protocol
/// @notice Deploys all contracts for local testing or testnet
contract DeployScript is Script {
    function run() external {
        // Get private key from environment or use Anvil's default first account
        uint256 deployerPrivateKey;
        try vm.envUint("PRIVATE_KEY") returns (uint256 key) {
            deployerPrivateKey = key;
        } catch {
            // Default Anvil account 0
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
            console.log("Using default Anvil account");
        }
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy mock tokens
        console.log("Deploying MockETH...");
        MockETH collateralToken = new MockETH();
        console.log("MockETH deployed at:", address(collateralToken));

        console.log("Deploying MockUSDC...");
        MockUSDC debtToken = new MockUSDC();
        console.log("MockUSDC deployed at:", address(debtToken));

        // 2. Deploy mock SP1 verifier (for local testing)
        console.log("Deploying MockSP1Verifier...");
        MockSP1Verifier verifier = new MockSP1Verifier();
        console.log("MockSP1Verifier deployed at:", address(verifier));

        // 3. Set verification keys (mock values for testing)
        bytes32 depositVkey = keccak256("DEPOSIT_VKEY_V1");
        bytes32 borrowVkey = keccak256("BORROW_VKEY_V1");

        // 4. Deploy AegisVault
        console.log("Deploying AegisVault...");
        AegisVault vault = new AegisVault(
            address(verifier),
            depositVkey,
            borrowVkey,
            address(collateralToken),
            address(debtToken)
        );
        console.log("AegisVault deployed at:", address(vault));

        // 5. Setup: Mint tokens and fund vault
        console.log("\nSetting up test environment...");
        
        // Mint collateral to deployer (for testing deposits)
        collateralToken.mint(msg.sender, 1000 ether);
        console.log("Minted 1000 ETH to deployer");
        
        // Mint debt tokens and fund vault
        debtToken.mint(msg.sender, 10_000_000e6); // 10M USDC
        debtToken.approve(address(vault), 10_000_000e6);
        vault.fundVault(10_000_000e6);
        console.log("Funded vault with 10M USDC");

        vm.stopBroadcast();

        // Print deployment addresses
        console.log("\n=================================");
        console.log("DEPLOYMENT COMPLETE");
        console.log("=================================");
        console.log("MockETH:", address(collateralToken));
        console.log("MockUSDC:", address(debtToken));
        console.log("MockSP1Verifier:", address(verifier));
        console.log("AegisVault:", address(vault));
        console.log("=================================");
        
        // Save addresses to file for prover script
        string memory addresses = string(abi.encodePacked(
            "COLLATERAL_TOKEN=", vm.toString(address(collateralToken)), "\n",
            "DEBT_TOKEN=", vm.toString(address(debtToken)), "\n",
            "VERIFIER=", vm.toString(address(verifier)), "\n",
            "VAULT=", vm.toString(address(vault)), "\n"
        ));
        vm.writeFile(".env.contracts", addresses);
        console.log("\nAddresses saved to .env.contracts");
    }
}

/// @notice Mock SP1 Verifier for local testing
contract MockSP1Verifier {
    function verifyProof(
        bytes32, // vkey
        bytes calldata, // publicValues
        bytes calldata // proofBytes
    ) external pure {
        // Always pass for local testing
        return;
    }
}

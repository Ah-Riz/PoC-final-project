// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/AegisVault.sol";
import "../src/MockTokens.sol";
import "../test/AegisVault.t.sol";
import {SP1Verifier} from "@sp1-contracts/v3.0.0/SP1VerifierGroth16.sol";

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

        // 2. Deploy SP1 verifier
        address verifier;
        bool useRealVerifier = vm.envOr("USE_REAL_SP1_VERIFIER", false);
        
        if (useRealVerifier) {
            console.log("Deploying REAL SP1 Verifier (Groth16)...");
            SP1Verifier realVerifier = new SP1Verifier();
            verifier = address(realVerifier);
            console.log("SP1Verifier deployed at:", verifier);
            console.log("*** USING REAL ZK PROOF VERIFICATION ***");
        } else {
            console.log("Deploying MockSP1Verifier (testing only)...");
            MockSP1Verifier mockVerifier = new MockSP1Verifier();
            verifier = address(mockVerifier);
            console.log("MockSP1Verifier deployed at:", verifier);
            console.log("*** WARNING: Proofs are NOT verified! ***");
        }

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
        if (useRealVerifier) {
            console.log("SP1Verifier (REAL):", verifier);
        } else {
            console.log("MockSP1Verifier:", verifier);
        }
        console.log("AegisVault:", address(vault));
        console.log("=================================");
        if (useRealVerifier) {
            console.log("*** Using REAL SP1 verification ***");
        } else {
            console.log("*** Using MOCK verifier (testing only) ***");
        }
        
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

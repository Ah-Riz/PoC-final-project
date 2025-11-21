use dotenv::dotenv;
use std::env;

// Import the integration module
#[path = "../integration.rs"]
mod integration;
use integration::IntegrationTest;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Load environment variables
    dotenv().ok();

    println!("\n╔══════════════════════════════════════════╗");
    println!("║  Aegis Protocol - E2E Integration Test  ║");
    println!("╚══════════════════════════════════════════╝\n");

    // Get configuration from environment
    let rpc_url = env::var("RPC_URL").unwrap_or_else(|_| "http://127.0.0.1:8545".to_string());
    let private_key = env::var("PRIVATE_KEY")
        .expect("PRIVATE_KEY must be set in .env file");
    
    // Load contract addresses from deployment
    let vault_addr = env::var("VAULT")
        .expect("VAULT address not found. Run deployment first.");
    let collateral_addr = env::var("COLLATERAL_TOKEN")
        .expect("COLLATERAL_TOKEN address not found");
    let debt_addr = env::var("DEBT_TOKEN")
        .expect("DEBT_TOKEN address not found");

    println!("Configuration:");
    println!("  RPC: {}", rpc_url);
    println!("  Vault: {}", vault_addr);
    println!("  Collateral: {}", collateral_addr);
    println!("  Debt: {}", debt_addr);

    // Create integration test instance
    let test = IntegrationTest::new(
        &rpc_url,
        &private_key,
        &vault_addr,
        &collateral_addr,
        &debt_addr,
    )
    .await?;

    // Run full flow
    test.run_full_flow().await?;

    Ok(())
}

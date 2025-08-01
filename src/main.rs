use dotenvy::dotenv;
use std::{env, str::FromStr};

use alloy::primitives::{Address, U256};
use vault::VaultClient;
use redeem::sign_redeem_hash;

mod vault;
mod bindings;
mod redeem;

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenv().ok();

    // OP = source chain
    let rpc_url = env::var("OP_RPC_URL")?;
    let vault_address = env::var("OP_VAULT_CONTRACT")?;
    let user_str = env::var("TEST_USER")?;
    let token_str = env::var("TEST_TOKEN")?;
    let private_key = env::var("PRIVATE_KEY")?;

    let user: Address = user_str.parse()?;
    let token: Address = token_str.parse()?;

    let amount = U256::from_str("100000000000000")?; // 0.001 ETH
    let nonce = U256::from(4); // Replace with actual nonce tracking later
    let vault = VaultClient::new(&rpc_url, &vault_address).await?;

    // Step 1: Get balance on OP/Base
    println!("🔍 Checking available balance on source chain...");
    let balance_str = vault.get_available_balance(&user_str, &token_str).await?;
    let balance = U256::from_str(&balance_str)?;
    println!("🧾 Available Balance: {}", balance); // CAB

    if balance < amount {
        println!("❌ Not enough balance to redeem.");
        return Ok(());
    }

    // Step 2: Lock on OP/Base
    println!("✍️ Signing redeem intent for Soneium...");
    let op_rpc_url = env::var("OP_RPC_URL")?;
    let op_vault_address = env::var("OP_VAULT_CONTRACT")?;
    let op_vault_addr: Address = op_vault_address.parse()?;
    let op_vault = VaultClient::new(&op_rpc_url, &op_vault_address).await?;
    let soneium_rpc_url = env::var("SONEIUM_RPC_URL")?;
    let soneium_vault_address = env::var("SONEIUM_VAULT_CONTRACT")?;
    let soneium_vault_addr: Address = soneium_vault_address.parse()?;


    let (digest, signature) = sign_redeem_hash(
        &private_key,
        user,
        token,
        amount,
        nonce,
        soneium_vault_addr,
    )?;

    println!("🔐 Digest: {digest:?}");
    println!("🖋️ Signature for Soneium: 0x{}", hex::encode(&signature));

    // For destination chain for claims
    let (digest, signature) = sign_redeem_hash(
        &private_key,
        user,
        token,
        amount,
        nonce,
        op_vault_addr,
    )?;

    println!("🔐 Digest: {digest:?}");
    println!("🖋️ Signature for OP: 0x{}", hex::encode(&signature));

    println!("🔐 Locking funds on OP/Base vault...");
    vault
        .lock(user, token, amount, nonce, signature.clone().into())
        .await?;
    println!("✅ Funds locked on OP/Base.");

    // Step 3: Sign Fill intent for Soneium => This happens trueless via layer-zero 
    // ----------------------------------------------------------------------------

    // Step 4: Claim the intent =>laiming from OP vault => This will happen (after redemption proof confirmed) - LockedFunds
    let (digest_op, signature_op) = sign_redeem_hash(
        &private_key,
        user,
        token,
        amount,
        nonce,
        op_vault_addr,
    )?;

    println!("🔐 Digest: {digest_op:?}");
    println!("🖋️ Signature: 0x{}", hex::encode(&signature_op));

    let tx_hash_op = vault
        .redeem_with_signature(user, token, amount, nonce, signature_op.into())
        .await?;
    println!("✅ OP/Base claim tx: {tx_hash_op:?}");

    Ok(())
}

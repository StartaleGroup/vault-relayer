// VaultClient with provider, methods

// This comes from `abigen!`
use crate::bindings::Vault as VaultBinding;

use alloy::network::Ethereum;
use alloy::primitives::{Address, U256, Bytes, TxHash};
use alloy::providers::{RootProvider};
use std::sync::Arc;
use url::Url;
use alloy::rpc::{client::RpcClient};
use alloy::transports::http::Http;

pub struct VaultClient {
    pub contract: VaultBinding::VaultInstance<Arc<RootProvider<Ethereum>>>,
}

impl VaultClient {
    pub async fn new(rpc_url: &str, contract_address: &str) -> anyhow::Result<Self> {
        // Parse RPC URL and create HTTP transport
        let url = Url::parse(rpc_url)?;
        let transport = Http::new(url);

        // Build RPC client and provider
        let rpc_client = RpcClient::new(transport, true);
        let provider = Arc::new(RootProvider::new(rpc_client));

        // Parse address and instantiate contract
        let address = contract_address.parse::<Address>()?;
        let contract = VaultBinding::new(address, provider);
        Ok(Self { contract })
    }


    pub async fn get_available_balance(
        &self,
        user: &str,
        token: &str,
    ) -> anyhow::Result<String> {
        let user_address = user.parse::<Address>()?;
        let token_address = token.parse::<Address>()?;

        let result = self
            .contract
            .availableBalance(user_address, token_address)
            .call()
            .await?;

        Ok(result.to_string())
    }

    pub async fn redeem_with_signature(
        &self,
        user: Address,
        token: Address,
        amount: U256,
        nonce: U256,
        signature: Bytes,
    ) -> anyhow::Result<TxHash> {
        
        let tx = self
            .contract
            .redeemWithSignature(user, token, amount, nonce, signature.into())
            .send()
            .await?;

        Ok(*tx.tx_hash())
    }

    pub async fn lock(
        &self,
        user: Address,
        token: Address,
        amount: U256,
        nonce: U256,
        signature: Bytes
    ) -> anyhow::Result<TxHash> {
        let tx = self
            .contract
            .lock(user, token, amount, nonce, signature)
            .send()
            .await?;
        Ok(*tx.tx_hash())
    }
}

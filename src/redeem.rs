use alloy_sol_types::{sol, SolValue};
use alloy::primitives::{Address, U256, B256, keccak256};
use hex::decode;
use alloy_dyn_abi::{DynSolValue, DynSolType};
use ethers::signers::{LocalWallet, Signer};

sol! {
    struct RedeemMessage {
        address user;
        address token;
        uint256 amount;
        uint256 nonce;
    }
}
pub fn sign_redeem_hash(
    private_key_hex: &str,
    user: Address,
    token: Address,
    amount: U256,
    nonce: U256,
    vault_address: Address,
) -> anyhow::Result<(B256, Vec<u8>)> {
    // Create the redeem message
    let message = RedeemMessage {
        user,
        token,
        amount,
        nonce,
    };
    // Encode using alloy's `DynSolValue` to mimic Solidity's `abi.encodePacked`
    let values: Vec<DynSolValue> = vec![
        DynSolValue::Address(message.user),
        DynSolValue::Address(message.token),
        DynSolValue::Uint(message.amount, 256),
        DynSolValue::Uint(nonce, 256),
        DynSolValue::Address(vault_address),
    ];

    let mut buf = Vec::new();
    for v in &values {
        v.abi_encode_packed_to(&mut buf);
    }

    let digest = keccak256(&buf);
    let eth_prefixed_digest = keccak256(
        [&b"\x19Ethereum Signed Message:\n32"[..], digest.as_slice()].concat()
    );

    // Sign using ethers
    let key = private_key_hex.parse::<LocalWallet>()?;
    let sig = key.sign_hash(ethers::types::H256::from_slice(eth_prefixed_digest.as_slice()))?;

    Ok((digest, sig.to_vec()))
}

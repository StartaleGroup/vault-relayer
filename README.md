
# 🧠 Chain Abstraction Flow – SuperApp on Soneium
---

## ✅ Step-by-Step User Journey

### 1. **User logs in to SuperApp**
- Logs in using Privy/Web3Auth
- Smart Account is created on **Soneium** and **OP/Base** via SCS/ SUPER APP SDK (counterfactual)
- Same address across chains

---

### 2. **User withdraws from CEX to OP/Base**
- User sends ETH/USDC from Binance, KuCoin, etc.
- Funds received by user’s Smart Account on OP/Base

---

### 3. **User deposits into OP/Base Vault**
- `Vault.depositETH()` or `Vault.depositERC20(token, amount)`
- Balance tracked per user

---

### 4. **User triggers action on Soneium**
- Example: stake, mint NFT, submit bet 0.01 eth
- SDK builds a transaction intent

---

### 5. **Relayer locks funds on OP/Base Vault**
- Calls:
  ```solidity
  lock(user, token, amount, nonce, signature)

### 6. Relayer or Layerzero sends redeem intent to Soneium
- Constructs digest:

keccak256(user, token, amount, nonce, vault_soneium_address)
- User signs digest via AbstractJS (Kernel Smart Account)

### 7. Soneium Vault fulfills the redemption
- Relayer or Layerzero calls:

redeemWithSignature(user, token, amount, nonce, signature)
- Vault verifies signature and transfers tokens to user’s Smart Account
- Emits FundsRedeemed(...)

✅ User now has funds on Soneium

### 8. SCS Paymaster sponsors the dApp transaction
AbstractJS submits a UserOperation

Paymaster:

Verifies vault redemption happened

Confirms available balance

Pays gas

Bundler submits the operation

✅ User interaction is gasless and cross-chain

### 9. Claim funds on OP/Base Vault
For post-fulfillment reconciliation:

redeemWithSignature(user, token, amount, nonce, signature) on OP vault contract to unlock locked funds 
Transfers real funds (burned or moved to relayer/bridge)

Emits Redeemed(...)

### 10. [Fallback] Refund if not redeemed in time
If Soneium fulfillment doesn’t happen in TTL window

Relayer or user can call:

refundExpiredLock(user, token, nonce)
Funds unlocked for reuse

🧱 Contracts Used
- Vault (OP/Base)
depositETH, depositERC20, lock, redeemWithSignature, refundExpiredLock

- Vault (Soneium)
redeemWithSignature (only verifies + fulfills with sig)

- Paymaster (SCS)
Sponsors final UserOp based on Vault state

- Smart Account (SCS)
Same address across chains
Signs intent digest


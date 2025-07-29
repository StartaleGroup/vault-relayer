// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract Vault is Ownable, NonblockingLzApp {
//     mapping(bytes32 => bool) public usedDigests;

//     uint16 public opChainId; // LayerZero chain ID for OP/Base
//     address public opVault;  // Destination Vault on OP chain

//     event FundsRedeemed(address indexed user, address indexed token, uint256 amount, uint256 nonce);
//     event RedemptionMessageSent(address indexed user, address indexed token, uint256 amount, uint256 nonce);

//     constructor(
//         address _lzEndpoint,
//         address _initialOwner,
//         uint16 _opChainId,
//         address _opVault
//     ) payable NonblockingLzApp(_lzEndpoint) Ownable(_initialOwner) {
//         opChainId = _opChainId;
//         opVault = _opVault;
//     }

//     /// To intiatiate fill once locked on source chain
//     function _nonblockingLzReceive(
//         uint16, // _srcChainId
//         bytes memory, // _srcAddress
//         uint64, // _nonce
//         bytes memory _payload
//     ) internal override {
//         (
//             address user,
//             address token,
//             uint256 amount,
//             uint256 nonce,
//             bytes memory signature
//         ) = abi.decode(_payload, (address, address, uint256, uint256, bytes));

//         redeemWithSignature(user, token, amount, nonce, signature);
//     }

//     function redeemWithSignature(
//         address user,
//         address token,
//         uint256 amount,
//         uint256 nonce,
//         bytes memory signature
//     ) public payable {
//         bytes32 digest = keccak256(abi.encodePacked(user, token, amount, nonce, address(this)));
//         require(!usedDigests[digest], "Already redeemed");
//         require(_verify(user, digest, signature), "Invalid signature");

//         usedDigests[digest] = true;

//         // Transfer funds
//         if (token == address(0)) {
//             (bool sent, ) = user.call{value: amount}("");
//             require(sent, "ETH transfer failed");
//         } else {
//             IERC20(token).transfer(user, amount);
//         }

//         emit FundsRedeemed(user, token, amount, nonce);

//         // 🔁 Send cross-chain message to OP Vault
//         _sendRedemptionMessage(user, token, amount, nonce, signature);
//     }

//     function _sendRedemptionMessage(
//         address user,
//         address token,
//         uint256 amount,
//         uint256 nonce,
//         bytes memory signature
//     ) internal {
//         bytes memory payload = abi.encode(user, token, amount, nonce, signature);

//         _lzSend(
//             opChainId,
//             payload,
//             payable(msg.sender), // refund address
//             address(0x0),        // zro payment address
//             bytes(""),
//             msg.value         // adapterParams
//         );

//         emit RedemptionMessageSent(user, token, amount, nonce);
//     }


//     // -------- Signature Utils --------

//     function _verify(address user, bytes32 digest, bytes memory sig) internal pure returns (bool) {
//         return recoverSigner(digest, sig) == user;
//     }

//     function recoverSigner(bytes32 digest, bytes memory sig) public pure returns (address) {
//         bytes32 ethSignedMessageHash = keccak256(
//             abi.encodePacked("\x19Ethereum Signed Message:\n32", digest)
//         );
//         (uint8 v, bytes32 r, bytes32 s) = splitSignature(sig);
//         return ecrecover(ethSignedMessageHash, v, r, s);
//     }

//     function splitSignature(bytes memory sig) internal pure returns (uint8, bytes32, bytes32) {
//         require(sig.length == 65, "Invalid signature length");

//         bytes32 r;
//         bytes32 s;
//         uint8 v;

//         assembly {
//             r := mload(add(sig, 32))
//             s := mload(add(sig, 64))
//             v := byte(0, mload(add(sig, 96)))
//         }

//         return (v, r, s);
//     }

//     receive() external payable {}

//     function withdraw(address token, uint256 amount) external onlyOwner {
//         if (token == address(0)) {
//             payable(owner()).transfer(amount);
//         } else {
//             IERC20(token).transfer(owner(), amount);
//         }
//     }
// }

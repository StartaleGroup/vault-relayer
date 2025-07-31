// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "@layerzerolabs/solidity-examples/contracts/lzApp/NonblockingLzApp.sol";

// contract Vault is Ownable, NonblockingLzApp {
//     using ECDSA for bytes32;

//     address public relayer;
//     uint256 public constant LOCK_TIMEOUT = 1 hours;

//     mapping(address => uint256) public ethBalances;
//     mapping(address => mapping(address => uint256)) public erc20Balances;

//     struct LockInfo {
//         uint256 amount;
//         uint256 timestamp;
//         bool redeemed;
//     }

//     mapping(address => mapping(address => mapping(uint256 => LockInfo))) public locks;
//     mapping(bytes32 => bool) public usedDigests;

//     uint16 public soneiumLzChainId;

//     // ----------- Events -----------

//     event DepositedETH(address indexed user, uint256 amount);
//     event DepositedERC20(address indexed user, address indexed token, uint256 amount);
//     event Locked(address indexed user, address indexed token, uint256 amount, uint256 nonce);
//     event Unlocked(address indexed user, address indexed token, uint256 amount, uint256 nonce);
//     event Redeemed(address indexed user, address indexed token, uint256 amount, uint256 nonce);
//     event Refunded(address indexed user, address indexed token, uint256 amount, uint256 nonce);

//     constructor(
//         address _relayer,
//         address _lzEndpoint,
//         address _initialOwner,
//         uint16 _soneiumLzChainId
//     ) payable NonblockingLzApp(_lzEndpoint) Ownable(_initialOwner) {
//         relayer = _relayer;
//         soneiumLzChainId = _soneiumLzChainId;
//     }

//     function depositERC20(address token, uint256 amount) external {
//         require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
//         erc20Balances[msg.sender][token] += amount;
//         emit DepositedERC20(msg.sender, token, amount);
//     }

//     function depositETH() external payable {
//         require(msg.value > 0, "No ETH sent");
//         ethBalances[msg.sender] += msg.value;
//         emit DepositedETH(msg.sender, msg.value);
//     }

//     // ----------- Lock / Unlock -----------

//     function lock(address user, address token, uint256 amount, uint256 nonce, bytes calldata signature) external payable {
//         require(msg.sender == relayer, "Only relayer");

//         require(locks[user][token][nonce].amount == 0, "Nonce used");

//         if (token == address(0)) {
//             require(ethBalances[user] >= amount, "Insufficient ETH");
//         } else {
//             require(erc20Balances[user][token] >= amount, "Insufficient token");
//         }

//         locks[user][token][nonce] = LockInfo({
//             amount: amount,
//             timestamp: block.timestamp,
//             redeemed: false
//         });

//         emit Locked(user, token, amount, nonce);

//         // Construct payload
//         bytes memory payload = abi.encode(user, token, amount, nonce, signature);

//         // Send to Soneium
//         _lzSend(
//             soneiumLzChainId,
//             payload,
//             payable(msg.sender),
//             address(0x0),
//             bytes(""),
//             msg.value
//         );
//     }
    
//     function unlock(address user, address token, uint256 nonce) external {
//         require(msg.sender == relayer, "Only relayer");

//         LockInfo storage lockInfo = locks[user][token][nonce];
//         require(lockInfo.amount > 0, "No lock");
//         require(!lockInfo.redeemed, "Already redeemed");

//         delete locks[user][token][nonce];

//         emit Unlocked(user, token, lockInfo.amount, nonce);
//     }

//     // ----------- Redemption -----------

//         /// To intiatiate fill once locked on source chain
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
//     ) public {
//         require(msg.sender == relayer, "Only relayer");

//         bytes32 digest = keccak256(abi.encodePacked(user, token, amount, nonce, address(this)));
//         require(!usedDigests[digest], "Already used");

//         bytes32 ethSigned = toEthSignedMessageHash(digest);
//         address recovered = ethSigned.recover(signature);
//         require(user == recovered, "Invalid sig");

//         LockInfo storage lockInfo = locks[user][token][nonce];
//         require(lockInfo.amount >= amount, "Not enough locked");
//         require(!lockInfo.redeemed, "Already redeemed");

//         usedDigests[digest] = true;
//         lockInfo.redeemed = true;

//         if (token == address(0)) {
//             require(ethBalances[user] >= amount, "Not enough ETH");
//             ethBalances[user] -= amount;
//             (bool sent, ) = user.call{value: amount}("");
//             require(sent, "ETH send failed");
//         } else {
//             require(erc20Balances[user][token] >= amount, "Not enough token");
//             erc20Balances[user][token] -= amount;
//             require(IERC20(token).transfer(user, amount), "ERC20 transfer failed");
//         }

//         emit Redeemed(user, token, amount, nonce);
//     }

//     // ----------- Refund if timeout -----------

//     function refundExpiredLock(address user, address token, uint256 nonce) external {
//         LockInfo storage lockInfo = locks[user][token][nonce];
//         require(lockInfo.amount > 0, "No lock");
//         require(!lockInfo.redeemed, "Already redeemed");
//         require(block.timestamp > lockInfo.timestamp + LOCK_TIMEOUT, "Not expired");

//         uint256 amount = lockInfo.amount;
//         delete locks[user][token][nonce];

//         emit Refunded(user, token, amount, nonce);
//         // Balance remains the same (still held in contract)
//         // User can reuse the balance later
//     }

//     function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
//         return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
//     }

//     receive() external payable {}

//     // ----------- View -----------

//     function availableBalance(address user, address token) external view returns (uint256) {
//         uint256 lockedTotal;
//         // Sum all locked amounts (could optimize if needed)
//         // For now, assume one active nonce at a time per user/token
//         for (uint256 i = 0; i < 1000; i++) {
//             LockInfo memory l = locks[user][token][i];
//             if (l.amount == 0) break;
//             if (!l.redeemed) lockedTotal += l.amount;
//         }

//         if (token == address(0)) {
//             return ethBalances[user] - lockedTotal;
//         } else {
//             return erc20Balances[user][token] - lockedTotal;
//         }
//     }
// }

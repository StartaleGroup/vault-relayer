use alloy_sol_types::sol;

sol! {
    #[sol(rpc)]
    contract Vault {
        // Constructor
        constructor(address _relayer);

        // Functions
        function availableBalance(address user, address token) external view returns (uint256);
        function depositERC20(address token, uint256 amount) external;
        function depositETH() external payable;
    function lock(address user, address token, uint256 amount, uint256 nonce,  bytes signature) external;
        function redeemWithSignature(address user, address token, uint256 amount, uint256 nonce, bytes signature) external;
        function unlock(address user, address token, uint256 nonce) external;
        function refundExpiredLock(address user, address token, uint256 nonce) external;

        // View state variables
        function ethBalances(address user) external view returns (uint256);
        function erc20Balances(address user, address token) external view returns (uint256);
        function locked(address user, address token) external view returns (uint256);
        function locks(address user, address token, uint256 nonce) external view returns (
            uint256 amount,
            uint256 timestamp,
            bool redeemed
        );
        function relayer() external view returns (address);
        function usedDigests(bytes32) external view returns (bool);
        function LOCK_TIMEOUT() external view returns (uint256);

        // Events
        event DepositedETH(address indexed user, uint256 amount);
        event DepositedERC20(address indexed user, address indexed token, uint256 amount);
        event Locked(address indexed user, address indexed token, uint256 amount, uint256 nonce);
        event Unlocked(address indexed user, address indexed token, uint256 amount, uint256 nonce);
        event Redeemed(address indexed user, address indexed token, uint256 amount, uint256 nonce);
        event Refunded(address indexed user, address indexed token, uint256 amount, uint256 nonce);

        // Errors
        error ECDSAInvalidSignature();
        error ECDSAInvalidSignatureLength(uint256 length);
        error ECDSAInvalidSignatureS(bytes32 s);
    }
}

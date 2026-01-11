// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TokenVaultV2.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

contract TokenVaultV3 is TokenVaultV2 {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    // ================= EVENTS =================
    event EmergencyWithdraw(address indexed user, uint256 amount);

    // ================= V3 STORAGE (APPENDED ONLY) =================
    uint256 internal withdrawalDelay; // seconds

    struct WithdrawalRequest {
        uint256 amount;
        uint256 requestTime;
    }

    mapping(address => WithdrawalRequest) internal withdrawalRequests;

    // Reduce gap size (V2 had 46 → now 44)
    uint256[44] private __gapV3;

    // ================= RE-INITIALIZER =================
    /// @custom:oz-upgrades-validate-as-initializer
    function initializeV3(uint256 _delaySeconds) external reinitializer(3) {
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_delaySeconds <= 30 days, "Delay too long");
        withdrawalDelay = _delaySeconds;
    }

    // ================= VIEW FUNCTIONS =================
    function getWithdrawalDelay() external view returns (uint256) {
        return withdrawalDelay;
    }

    function getWithdrawalRequest(address user)
        external
        view
        returns (uint256 amount, uint256 requestTime)
    {
        WithdrawalRequest memory req = withdrawalRequests[user];
        return (req.amount, req.requestTime);
    }

    function getImplementationVersion()
        external
        pure
        override
        returns (string memory)
    {
        return "V3";
    }

    // ================= ADMIN FUNCTIONS =================
    function setWithdrawalDelay(uint256 _delaySeconds)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_delaySeconds <= 30 days, "Delay too long");
        withdrawalDelay = _delaySeconds;
    }

    // ================= WITHDRAWAL FLOW =================
    function requestWithdrawal(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // New request cancels previous one
        withdrawalRequests[msg.sender] = WithdrawalRequest({
            amount: amount,
            requestTime: block.timestamp
        });
    }

    function executeWithdrawal()
        external
        nonReentrant
        returns (uint256)
    {
        WithdrawalRequest memory req = withdrawalRequests[msg.sender];

        require(req.amount > 0, "No pending request");
        require(withdrawalDelay > 0, "Withdrawal delay not set");
        require(
            block.timestamp >= req.requestTime + withdrawalDelay,
            "Withdrawal delay not passed"
        );

        delete withdrawalRequests[msg.sender];

        balances[msg.sender] -= req.amount;
        _totalDeposits -= req.amount;

        token.safeTransfer(msg.sender, req.amount);

        return req.amount;
    }

    // ================= EMERGENCY =================
    function emergencyWithdraw()
        external
        nonReentrant
        returns (uint256)
    {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");

        delete withdrawalRequests[msg.sender];

        balances[msg.sender] = 0;
        _totalDeposits -= amount;

        token.safeTransfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, amount);

        return amount;
    }
}

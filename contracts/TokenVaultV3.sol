// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TokenVaultV2.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @title TokenVaultV3
 * @author Vinay Gupta Kandula
 * @notice Extends V2 to add withdrawal delays and emergency exit mechanisms.
 * @dev Implements a strict request-delay-execute withdrawal flow for enhanced security.
 */
contract TokenVaultV3 is TokenVaultV2 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ================= EVENTS =================
    
    /// @notice Emitted when a user performs an emergency withdrawal bypassing the delay.
    event EmergencyWithdraw(address indexed user, uint256 amount);

    // ================= V3 STORAGE =================
    
    /// @notice The mandatory delay time between a request and execution in seconds.
    uint256 internal withdrawalDelay;

    /// @dev Structure to store details of a pending withdrawal request.
    struct WithdrawalRequest {
        uint256 amount;
        uint256 requestTime;
    }

    /// @notice Mapping of user addresses to their current withdrawal request.
    mapping(address => WithdrawalRequest) internal withdrawalRequests;

    /**
     * @dev Unified Storage Gap.
     * Overwrites the internal __gap from V1/V2.
     * V2 had a 46-slot gap. We added 2 new variables, so we shrink the gap to 44 slots.
     */
    uint256[44] internal __gapV3;

    // ================= RE-INITIALIZER =================

    /**
     * @notice Initializes the V3 implementation.
     * @dev Uses reinitializer(3) to prevent multiple initializations of the same version.
     * @custom:oz-upgrades-validate-as-initializer
     * @param _delaySeconds The mandatory withdrawal delay in seconds.
     */
    function initializeV3(uint256 _delaySeconds) external reinitializer(3) {
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_delaySeconds <= 30 days, "Delay too long");
        withdrawalDelay = _delaySeconds;
    }

    // ================= VIEW FUNCTIONS =================

    /**
     * @notice Returns the mandatory withdrawal delay.
     */
    function getWithdrawalDelay() external view returns (uint256) {
        return withdrawalDelay;
    }

    /**
     * @notice Returns the status of a user's pending withdrawal request.
     */
    function getWithdrawalRequest(address user)
        external
        view
        returns (uint256 amount, uint256 requestTime)
    {
        WithdrawalRequest memory req = withdrawalRequests[user];
        return (req.amount, req.requestTime);
    }

    /**
     * @notice Returns the implementation version string.
     */
    function getImplementationVersion()
        external
        pure
        override
        returns (string memory)
    {
        return "V3";
    }

    // ================= ADMIN FUNCTIONS =================

    /**
     * @notice Updates the withdrawal delay time.
     * @param _delaySeconds New delay in seconds (max 30 days).
     */
    function setWithdrawalDelay(uint256 _delaySeconds)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_delaySeconds <= 30 days, "Delay too long");
        withdrawalDelay = _delaySeconds;
    }

    // ================= WITHDRAWAL FLOW =================

    /**
     * @notice Initiates a withdrawal request. 
     * @dev Overwrites any previous request.
     * @param amount The number of tokens requested.
     */
    function requestWithdrawal(uint256 amount) external nonReentrant {
        require(amount > 0, "Invalid amount");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        withdrawalRequests[msg.sender] = WithdrawalRequest({
            amount: amount,
            requestTime: block.timestamp
        });
    }

    /**
     * @notice Executes a previously requested withdrawal after the delay has passed.
     * @dev Strictly follows the Checks-Effects-Interactions (CEI) pattern.
     */
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

        // Effects: State updates before external transfer
        delete withdrawalRequests[msg.sender];
        balances[msg.sender] -= req.amount;
        _totalDeposits -= req.amount;

        // Interaction: External transfer
        token.safeTransfer(msg.sender, req.amount);

        return req.amount;
    }

    // ================= EMERGENCY =================

    /**
     * @notice Withdraws the user's entire balance immediately, bypassing the delay.
     * @dev Clears all user state including pending requests before transfer.
     */
    function emergencyWithdraw()
        external
        nonReentrant
        returns (uint256)
    {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance");

        // Effects: Clear all state first (CEI Pattern)
        delete withdrawalRequests[msg.sender];
        balances[msg.sender] = 0;
        _totalDeposits -= amount;

        // Interaction: External transfer
        token.safeTransfer(msg.sender, amount);

        emit EmergencyWithdraw(msg.sender, amount);

        return amount;
    }
}
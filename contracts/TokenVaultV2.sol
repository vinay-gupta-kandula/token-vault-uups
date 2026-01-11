// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TokenVaultV1.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
 * @title TokenVaultV2
 * @author Vinay Gupta Kandula
 * @notice Extends TokenVaultV1 to include yield generation and pausing capabilities.
 * @dev Implements a UUPS upgradeable pattern with strict "No Compounding" yield logic.
 */
contract TokenVaultV2 is TokenVaultV1, PausableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    // ================= ROLES =================
    
    /// @notice Role identifier for accounts permitted to pause deposits.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ================= V2 STORAGE =================

    /// @notice Annual yield rate in basis points (e.g., 500 = 5%).
    uint256 internal yieldRate; 
    
    /// @notice Tracks the last timestamp a user claimed yield.
    mapping(address => uint256) internal lastYieldClaim;
    
    /// @notice Tracks yield carried over from previous balances.
    mapping(address => uint256) internal pendingYield;
    
    /// @notice The timestamp when the V2 upgrade was initialized.
    uint256 internal yieldStartTime;

    /**
     * @dev Unified Storage Gap. 
     * Overwrites the internal __gapV1 from V1.
     * V1 had a 50-slot gap. We added 4 variables above, so we reduce the gap to 46 slots.
     */
    uint256[46] internal __gapV2; 

    // ================= RE-INITIALIZER =================

    /**
     * @notice Initializes the V2 implementation.
     * @dev Uses reinitializer(2) to prevent multiple initializations of the same version.
     * @custom:oz-upgrades-validate-as-initializer
     * @param _yieldRate The initial annual yield rate in basis points.
     */
    function initializeV2(uint256 _yieldRate) external reinitializer(2) {
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_yieldRate <= 10_000, "Invalid yield rate");
        yieldRate = _yieldRate;

        // Ensure users who deposited in V1 start earning from the upgrade time
        yieldStartTime = block.timestamp;

        _grantRole(PAUSER_ROLE, msg.sender);
    }

    // ================= VIEW FUNCTIONS =================

    /**
     * @notice Returns the current annual yield rate.
     * @return uint256 The yield rate in basis points.
     */
    function getYieldRate() external view returns (uint256) {
        return yieldRate;
    }

    /**
     * @notice Checks if the vault is currently paused.
     * @return bool True if deposits are paused.
     */
    function isDepositsPaused() external view returns (bool) {
        return paused();
    }

    /**
     * @notice Calculates the total claimable yield for a user.
     * @param user The address of the depositor.
     * @return uint256 Total accrued yield tokens.
     */
    function getUserYield(address user) external view returns (uint256) {
        return _getUserYield(user);
    }

    /**
     * @notice Returns the implementation version string.
     * @return string "V2"
     */
    function getImplementationVersion()
        external
        pure
        virtual
        override
        returns (string memory)
    {
        return "V2";
    }

    // ================= ADMIN FUNCTIONS =================

    /**
     * @notice Updates the yield rate.
     * @dev Restricted to DEFAULT_ADMIN_ROLE.
     * @param _yieldRate New yield rate in basis points.
     */
    function setYieldRate(uint256 _yieldRate)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_yieldRate <= 10_000, "Invalid yield rate");
        yieldRate = _yieldRate;
    }

    /**
     * @notice Pauses new deposits.
     * @dev Restricted to PAUSER_ROLE.
     */
    function pauseDeposits() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses new deposits.
     * @dev Restricted to PAUSER_ROLE.
     */
    function unpauseDeposits() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ================= YIELD LOGIC =================

    /**
     * @notice Claims accrued yield and sends it directly to the user's wallet.
     * @dev Strictly enforces "No Compounding" by not adding rewards to the vault balance.
     * Follows the Checks-Effects-Interactions (CEI) pattern for security.
     * @return yieldAmount The amount of tokens transferred to the user.
     */
    function claimYield() external nonReentrant returns (uint256) {
        uint256 yieldAmount = _getUserYield(msg.sender);
        require(yieldAmount > 0, "No yield");

        // Effects: Update state before external interaction
        pendingYield[msg.sender] = 0;
        lastYieldClaim[msg.sender] = block.timestamp;

        // Interaction: Send tokens directly to the user's wallet.
        token.safeTransfer(msg.sender, yieldAmount);

        return yieldAmount;
    }

    /**
     * @dev Internal helper to calculate user yield based on principal balance and time.
     */
    function _getUserYield(address user)
        internal
        view
        returns (uint256)
    {
        uint256 base = pendingYield[user];
        uint256 lastClaim = lastYieldClaim[user];

        // Handle migration for V1 users who never claimed in V2
        if (lastClaim == 0) {
            lastClaim = yieldStartTime;
        }

        uint256 timeElapsed = block.timestamp - lastClaim;

        // Formula: (principal * rate * time) / (year * basis_denominator)
        uint256 accrued =
            (balances[user] * yieldRate * timeElapsed) /
            (365 days * 10_000);

        return base + accrued;
    }

    // ================= OVERRIDES =================

    /**
     * @notice Overrides V1 deposit to include pausable functionality and yield tracking.
     * @param amount The number of tokens to deposit.
     */
    function deposit(uint256 amount)
        public
        override
        whenNotPaused
        nonReentrant
    {
        super.deposit(amount);

        // Initialize claim timer for new depositors
        if (lastYieldClaim[msg.sender] == 0) {
            lastYieldClaim[msg.sender] = block.timestamp;
        }
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./TokenVaultV1.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract TokenVaultV2 is TokenVaultV1, PausableUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    // ================= ROLES =================
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ================= V2 STORAGE (APPENDED ONLY) =================
    uint256 internal yieldRate; // basis points
    mapping(address => uint256) internal lastYieldClaim;
    mapping(address => uint256) internal pendingYield;
    uint256 internal yieldStartTime; // ✅ NEW (for users who deposited in V1)

    // Reduce gap size (V1 had 50 → now 46)
    uint256[46] private __gapV2;

    // ================= RE-INITIALIZER =================
    /// @custom:oz-upgrades-validate-as-initializer
    function initializeV2(uint256 _yieldRate) external reinitializer(2) {
        __ReentrancyGuard_init();
        __Pausable_init();

        require(_yieldRate <= 10_000, "Invalid yield rate");
        yieldRate = _yieldRate;

        // Yield starts from upgrade time for existing users
        yieldStartTime = block.timestamp;

        _grantRole(PAUSER_ROLE, msg.sender);
    }

    // ================= VIEW FUNCTIONS =================
    function getYieldRate() external view returns (uint256) {
        return yieldRate;
    }

    function isDepositsPaused() external view returns (bool) {
        return paused();
    }

    function getUserYield(address user) external view returns (uint256) {
        return _getUserYield(user);
    }

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
    function setYieldRate(uint256 _yieldRate)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_yieldRate <= 10_000, "Invalid yield rate");
        yieldRate = _yieldRate;
    }

    function pauseDeposits() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpauseDeposits() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ================= YIELD LOGIC =================
    function claimYield() external nonReentrant returns (uint256) {
        uint256 yieldAmount = _getUserYield(msg.sender);
        require(yieldAmount > 0, "No yield");

        pendingYield[msg.sender] = 0;
        lastYieldClaim[msg.sender] = block.timestamp;

        balances[msg.sender] += yieldAmount;
        _totalDeposits += yieldAmount;

        return yieldAmount;
    }

    function _getUserYield(address user)
        internal
        view
        returns (uint256)
    {
        uint256 base = pendingYield[user];
        uint256 lastClaim = lastYieldClaim[user];

        // ✅ Handle users who deposited before V2 upgrade
        if (lastClaim == 0) {
            lastClaim = yieldStartTime;
        }

        uint256 timeElapsed = block.timestamp - lastClaim;

        uint256 accrued =
            (balances[user] * yieldRate * timeElapsed) /
            (365 days * 10_000);

        return base + accrued;
    }

    // ================= OVERRIDES =================
    function deposit(uint256 amount)
        public
        override
        whenNotPaused
        nonReentrant
    {
        super.deposit(amount);

        if (lastYieldClaim[msg.sender] == 0) {
            lastYieldClaim[msg.sender] = block.timestamp;
        }
    }
}

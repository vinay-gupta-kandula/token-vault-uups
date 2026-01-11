// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * @title TokenVaultV1
 * @author Vinay Gupta Kandula
 * @notice Basic vault for ERC20 deposits and withdrawals with a deposit fee.
 * @dev Implements UUPS upgradeability and role-based access control.
 */
contract TokenVaultV1 is
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // ================= ROLES =================
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ================= STORAGE =================
    IERC20Upgradeable internal token;
    uint256 internal depositFee;
    uint256 internal _totalDeposits;
    mapping(address => uint256) internal balances;

    /**
     * @dev Storage gap for V1. Internal to allow visibility in children.
     */
    uint256[50] internal __gapV1;

    // ================= INITIALIZER =================
    function initialize(
        address _token,
        address _admin,
        uint256 _depositFee
    ) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        require(_token != address(0), "Invalid token");
        require(_admin != address(0), "Invalid admin");
        require(_depositFee <= 10_000, "Fee too high");

        token = IERC20Upgradeable(_token);
        depositFee = _depositFee;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
    }

    // ================= UUPS =================
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}

    // ================= VIEW FUNCTIONS =================
    function balanceOf(address user) external view returns (uint256) {
        return balances[user];
    }

    function totalDeposits() external view returns (uint256) {
        return _totalDeposits;
    }

    function getDepositFee() external view returns (uint256) {
        return depositFee;
    }

    function getImplementationVersion() external pure virtual returns (string memory) {
        return "V1";
    }

    // ================= DEPOSIT =================
    function deposit(uint256 amount) public virtual nonReentrant {
        require(amount > 0, "Amount must be > 0");
        uint256 fee = (amount * depositFee) / 10_000;
        uint256 netAmount = amount - fee;

        token.safeTransferFrom(msg.sender, address(this), amount);
        balances[msg.sender] += netAmount;
        _totalDeposits += netAmount;
    }

    // ================= WITHDRAW =================
    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        _totalDeposits -= amount;
        token.safeTransfer(msg.sender, amount);
    }
}
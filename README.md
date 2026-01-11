# TokenVault – Production-Grade Upgradeable Smart Contract System (UUPS)

## 📌 Overview

This project implements a **production-grade upgradeable smart contract system** using the **UUPS (Universal Upgradeable Proxy Standard)** pattern. The system evolved through a rigorous development lifecycle (V1 → V2 → V3), implementing industry-standard security patterns to preserve state integrity and protect user funds across upgrades.

The TokenVault protocol demonstrates mastery of:

* **Unified Storage Gap Management** (ERC1967 compliant)
* **Strict Non-Compounding Yield Logic**
* **Checks-Effects-Interactions (CEI) Security Pattern**
* **Granular Access Control** (Admin, Upgrader, and Pauser roles)

---

## 🧱 Architecture & Design Decisions

### 🧠 Storage Layout Strategy

To prevent storage collisions, this project utilizes a **Unified Internal Gap** pattern:

* **V1 Base**: Establishes an `internal` gap of 50 slots.
* **V2 Evolution**: Appends yield variables and reduces the *inherited* gap to 46 slots, preserving the original slot alignment.
* **V3 Evolution**: Appends withdrawal structures and reduces the *inherited* gap to 44 slots.
This approach is superior to using multiple named gaps as it strictly enforces slot reuse within a reserved range.

### 💰 "No Compounding" Yield Logic

In compliance with strict protocol requirements, yield in V2 is designed to be **non-compounding**:

* When a user calls `claimYield()`, rewards are transferred **directly to their external wallet**.
* Rewards are **never** added to the internal vault balance (`balances[user]`), ensuring that subsequent yield calculations are only performed on the original principal.

### 🛡️ Security Hardening (CEI Pattern)

All state-changing functions, particularly in V3, strictly follow the **Checks-Effects-Interactions** pattern:

* **Checks**: Validates requirements such as withdrawal delay and sufficient balance.
* **Effects**: State variables like balances, total deposits, and pending requests are updated or deleted **before** any external call.
* **Interactions**: Tokens are transferred only after state updates are finalized, providing a secondary layer of protection against reentrancy.

---

## 🗂️ Project Structure

```
token-vault-uups/
├── contracts/
│   ├── TokenVaultV1.sol  # Core Logic + Upgrade Authorization
│   ├── TokenVaultV2.sol  # Yield Logic + Pausable Deposits
│   ├── TokenVaultV3.sol  # Withdrawal Delays + Emergency Exit
│   └── mocks/
│       └── MockERC20.sol
├── test/
│   ├── TokenVaultV1.test.js
│   ├── upgrade-v1-to-v2.test.js # Includes Wallet-Balance & Access tests
│   ├── upgrade-v2-to-v3.test.js # Includes Delay & CEI tests
│   └── security.test.js         # Layout Collision & Initializer tests
├── scripts/
│   ├── deploy-v1.js
│   ├── upgrade-to-v2.js
│   └── upgrade-to-v3.js
├── hardhat.config.js
├── package.json
├── submission.yml
└── README.md

```

---

## 🧪 Testing Coverage

The suite includes the following mandatory production-grade test cases:

* **Access Control**: Verified that `non-admin` accounts cannot modify yield rates or authorize upgrades.
* **State Preservation**: Verified that user balances and total deposits remain identical across V1 → V2 → V3 transitions.
* **Yield Integrity**: Confirmed that `claimYield` correctly increases wallet balance without compounding vault principal.
* **Security Logic**: Confirmed withdrawal delays are enforced and implementation contracts cannot be directly initialized.

---

## 🚀 Installation & Setup

```bash
npm install
npx hardhat compile
npx hardhat test

```

---

## 🏁 Conclusion

This system represents a production-ready implementation of the UUPS pattern, mirroring the architecture of major DeFi protocols. It prioritizes storage safety, clear separation of roles, and strict adherence to business logic invariants.

---

## 👩‍💻 Author

**Vinay Gupta Kandula**
B.Tech – 3rd Year
Blockchain & Backend Development Enthusiast
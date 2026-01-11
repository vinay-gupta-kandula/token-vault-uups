# TokenVault – Production-Grade Upgradeable Smart Contract System (UUPS)

## 📌 Overview

This project implements a **production-grade upgradeable smart contract system** using the **UUPS (Universal Upgradeable Proxy Standard)** pattern.  
The system evolves through **three versions (V1 → V2 → V3)** while preserving state, security, and access control.

The TokenVault protocol demonstrates real-world upgrade scenarios such as:
- Secure initialization
- Storage layout management
- Role-based upgrade authorization
- Cross-version state preservation
- Emergency mechanisms

This mirrors how real DeFi protocols safely upgrade contracts in production environments.

---

## 🧱 Architecture Overview

The system consists of:

- **UUPS Proxy (ERC1967)** – permanent address
- **Implementation contracts** – logic upgraded over time
- **OpenZeppelin Upgradeable Contracts**
- **Hardhat + Ethers.js** for testing and deployment

```

User → Proxy → Implementation (V1 / V2 / V3)

```

---

## 🗂️ Project Structure

```

token-vault-uups/
├── contracts/
│   ├── TokenVaultV1.sol
│   ├── TokenVaultV2.sol
│   ├── TokenVaultV3.sol
│   └── mocks/
│       └── MockERC20.sol
├── test/
│   ├── TokenVaultV1.test.js
│   ├── upgrade-v1-to-v2.test.js
│   ├── upgrade-v2-to-v3.test.js
│   └── security.test.js
├── scripts/
│   ├── deploy-v1.js
│   ├── upgrade-to-v2.js
│   └── upgrade-to-v3.js
├── hardhat.config.js
├── package.json
├── submission.yml
└── README.md

````

---

## 🔄 Contract Versions

### 🔹 TokenVaultV1
- Deposit & withdrawal functionality
- Deposit fee (basis points)
- UUPS upgrade authorization
- Secure initializer
- Reentrancy protection

### 🔹 TokenVaultV2
- Yield generation (APR-based)
- Pause / unpause deposits
- Yield claiming
- Role-based pausing
- State preserved from V1

### 🔹 TokenVaultV3
- Withdrawal delay mechanism
- Withdrawal request / execution flow
- Emergency withdrawal
- State preserved from V1 & V2

---

## 🔐 Security Design

### Initialization Security
- No constructors in implementation contracts
- `initializer` and `reinitializer` used
- Initializers disabled on implementations

### Access Control
- `DEFAULT_ADMIN_ROLE`
- `UPGRADER_ROLE`
- `PAUSER_ROLE`
- Unauthorized upgrades prevented

### Storage Layout Safety
- State variables are **never reordered**
- New variables are **only appended**
- Storage gaps used for future upgrades

### Upgrade Safety
- UUPS pattern with `_authorizeUpgrade`
- ERC1967 compliant proxy
- Storage collision tests included

---

## 🧪 Testing

### Run Tests
```bash
npx hardhat test
````

### Test Coverage Includes

* V1 business logic
* V1 → V2 upgrade validation
* V2 → V3 upgrade validation
* State preservation
* Access control enforcement
* Initialization protection
* Storage layout integrity
* Function selector safety

✔ **All required tests pass**
✔ **Security tests included**

---

## 🚀 Deployment & Upgrade (Local)

> ⚠️ Deployment scripts are provided for completeness.
> Running them is **not required** for submission.

### Start Local Node

```bash
npx hardhat node
```

### Deploy V1

```bash
npx hardhat run scripts/deploy-v1.js --network localhost
```

### Upgrade to V2

```cmd
set PROXY_ADDRESS=0xYOUR_PROXY_ADDRESS
npx hardhat run scripts/upgrade-to-v2.js --network localhost
```

### Upgrade to V3

```cmd
set PROXY_ADDRESS=0xYOUR_PROXY_ADDRESS
npx hardhat run scripts/upgrade-to-v3.js --network localhost
```

---

## 🧠 Storage Layout Strategy

* V1 defines core storage + large gap
* V2 appends yield-related variables and reduces gap
* V3 appends withdrawal-related variables and reduces gap
* No storage slot reuse or reordering

This guarantees **safe upgrades without data corruption**.

---

## 📦 Installation & Setup

```bash
npm install
npx hardhat compile
npx hardhat test
```

---

## ⚠️ Known Limitations

* Yield does not auto-compound
* Emergency withdrawal bypasses delay (intentional design choice)
* Local deployment uses in-memory blockchain

---

## 🏁 Conclusion

This project demonstrates a **real-world, production-ready upgradeable smart contract system** following industry best practices used by major DeFi protocols.

It showcases:

* Secure UUPS upgrades
* Storage safety
* Robust access control
* Comprehensive testing
* Production-grade architecture

---

## 👩‍💻 Author

**Vinay Gupta Kandula**
B.Tech – 3rd Year
Blockchain & Backend Development Enthusiast

```

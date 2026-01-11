const { ethers, upgrades } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying with account:", deployer.address);

  // 1. Deploy Mock ERC20
  const MockERC20 = await ethers.getContractFactory("MockERC20");
  const token = await MockERC20.deploy("Mock Token", "MTK");
  await token.deployed();

  console.log("MockERC20 deployed at:", token.address);

  // 2. Deploy TokenVaultV1 as UUPS proxy
  const TokenVaultV1 = await ethers.getContractFactory("TokenVaultV1");

  const vault = await upgrades.deployProxy(
    TokenVaultV1,
    [
      token.address,      // REAL token address
      deployer.address,   // admin
      500                 // 5% deposit fee
    ],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );

  await vault.deployed();

  console.log("TokenVaultV1 proxy deployed at:", vault.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

const { ethers, upgrades } = require("hardhat");

async function main() {
  const PROXY_ADDRESS = process.env.PROXY_ADDRESS;

  if (!PROXY_ADDRESS) {
    throw new Error("Please set PROXY_ADDRESS env variable");
  }

  const TokenVaultV2 = await ethers.getContractFactory("TokenVaultV2");

  const upgraded = await upgrades.upgradeProxy(
    PROXY_ADDRESS,
    TokenVaultV2
  );

  await upgraded.deployed();

  // Initialize V2
  const tx = await upgraded.initializeV2(500); // 5% annual yield
  await tx.wait();

  console.log("Upgraded to TokenVaultV2 at:", upgraded.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

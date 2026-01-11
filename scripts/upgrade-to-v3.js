const { ethers, upgrades } = require("hardhat");

async function main() {
  const PROXY_ADDRESS = process.env.PROXY_ADDRESS;

  if (!PROXY_ADDRESS) {
    throw new Error("Please set PROXY_ADDRESS env variable");
  }

  const TokenVaultV3 = await ethers.getContractFactory("TokenVaultV3");

  const upgraded = await upgrades.upgradeProxy(
    PROXY_ADDRESS,
    TokenVaultV3
  );

  await upgraded.deployed();

  // Initialize V3
  const tx = await upgraded.initializeV3(60); // 60 seconds withdrawal delay
  await tx.wait();

  console.log("Upgraded to TokenVaultV3 at:", upgraded.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

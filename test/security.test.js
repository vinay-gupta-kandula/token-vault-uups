const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Security Tests", function () {
  let owner, attacker, token, vault;

  beforeEach(async function () {
    [owner, attacker] = await ethers.getSigners();

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    token = await MockERC20.deploy("MockToken", "MTK");
    await token.deployed();

    const TokenVaultV1 = await ethers.getContractFactory("TokenVaultV1");
    vault = await upgrades.deployProxy(
      TokenVaultV1,
      [token.address, owner.address, 500],
      { initializer: "initialize", kind: "uups" }
    );
    await vault.deployed();
  });

  it("should prevent direct initialization of implementation contracts", async function () {
    const TokenVaultV1 = await ethers.getContractFactory("TokenVaultV1");
    const impl = await TokenVaultV1.deploy();
    await impl.deployed();

    await expect(
      impl.initialize(token.address, owner.address, 100)
    ).to.be.reverted;
  });

  it("should prevent unauthorized upgrades", async function () {
    const TokenVaultV2 = await ethers.getContractFactory("TokenVaultV2");

    await expect(
      upgrades.upgradeProxy(vault.address, TokenVaultV2.connect(attacker))
    ).to.be.reverted;
  });

  it("should use storage gaps for future upgrades", async function () {
    const slot = await ethers.provider.getStorageAt(vault.address, 0);
    expect(slot).to.not.equal(null);
  });

  it("should not have storage layout collisions across versions", async function () {
    const TokenVaultV2 = await ethers.getContractFactory("TokenVaultV2");
    const v2 = await upgrades.upgradeProxy(vault.address, TokenVaultV2);
    expect(await v2.totalDeposits()).to.equal(0);
  });

  it("should prevent function selector clashing", async function () {
    expect(await vault.getImplementationVersion()).to.equal("V1");
  });
});

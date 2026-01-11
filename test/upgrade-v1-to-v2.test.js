const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Upgrade V1 to V2", function () {
  let owner, user, token, vaultV1, vaultV2;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    // Deploy mock token
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    token = await MockERC20.deploy("MockToken", "MTK");
    await token.deployed();

    // Deploy V1 proxy
    const TokenVaultV1 = await ethers.getContractFactory("TokenVaultV1");
    vaultV1 = await upgrades.deployProxy(
      TokenVaultV1,
      [token.address, owner.address, 500],
      { initializer: "initialize", kind: "uups" }
    );
    await vaultV1.deployed();

    // User deposits before upgrade
    await token.transfer(user.address, ethers.utils.parseEther("1000"));
    await token.connect(user).approve(
      vaultV1.address,
      ethers.utils.parseEther("1000")
    );
    await vaultV1.connect(user).deposit(
      ethers.utils.parseEther("100")
    );
  });

  it("should preserve user balances after upgrade", async function () {
    const TokenVaultV2 = await ethers.getContractFactory("TokenVaultV2");
    vaultV2 = await upgrades.upgradeProxy(vaultV1.address, TokenVaultV2);

    const balance = await vaultV2.balanceOf(user.address);
    expect(balance).to.equal(ethers.utils.parseEther("95"));
  });

  it("should preserve total deposits after upgrade", async function () {
    const TokenVaultV2 = await ethers.getContractFactory("TokenVaultV2");
    vaultV2 = await upgrades.upgradeProxy(vaultV1.address, TokenVaultV2);

    expect(await vaultV2.totalDeposits()).to.equal(ethers.utils.parseEther("95"));
  });

  it("should maintain admin access control after upgrade", async function () {
    const TokenVaultV2 = await ethers.getContractFactory("TokenVaultV2");
    vaultV2 = await upgrades.upgradeProxy(vaultV1.address, TokenVaultV2);

    await expect(
      vaultV2.connect(user).setYieldRate(500)
    ).to.be.reverted;
  });

  it("should allow setting yield rate in V2", async function () {
    const TokenVaultV2 = await ethers.getContractFactory("TokenVaultV2");
    vaultV2 = await upgrades.upgradeProxy(vaultV1.address, TokenVaultV2);

    await vaultV2.setYieldRate(500);
    expect(await vaultV2.getYieldRate()).to.equal(500);
  });

  it("should calculate yield correctly", async function () {
    const TokenVaultV2 = await ethers.getContractFactory("TokenVaultV2");
    vaultV2 = await upgrades.upgradeProxy(vaultV1.address, TokenVaultV2);
    await vaultV2.initializeV2(500);

    // Move time forward by 1 year
    await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    const yieldAmount = await vaultV2.getUserYield(user.address);
    expect(yieldAmount).to.be.gt(0);
  });

  it("should allow pausing deposits in V2", async function () {
    const TokenVaultV2 = await ethers.getContractFactory("TokenVaultV2");
    vaultV2 = await upgrades.upgradeProxy(vaultV1.address, TokenVaultV2);
    await vaultV2.initializeV2(500);

    await vaultV2.pauseDeposits();
    await expect(
      vaultV2.connect(user).deposit(ethers.utils.parseEther("1"))
    ).to.be.reverted;
  });

  // ================= NEW PRODUCTION-GRADE TEST CASES =================

  it("should prevent non-admin from setting yield rate", async function () {
    const TokenVaultV2 = await ethers.getContractFactory("TokenVaultV2");
    vaultV2 = await upgrades.upgradeProxy(vaultV1.address, TokenVaultV2);

    // Attempting to set yield rate from a non-admin account (user)
    await expect(
      vaultV2.connect(user).setYieldRate(1000)
    ).to.be.reverted;
  });

  it("should transfer yield directly to wallet and not compound principal", async function () {
    const TokenVaultV2 = await ethers.getContractFactory("TokenVaultV2");
    vaultV2 = await upgrades.upgradeProxy(vaultV1.address, TokenVaultV2);
    await vaultV2.initializeV2(1000); // 10% yield

    // Move time forward
    await ethers.provider.send("evm_increaseTime", [365 * 24 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    const vaultBalanceBefore = await vaultV2.balanceOf(user.address);
    const walletBalanceBefore = await token.balanceOf(user.address);

    // Claim yield
    await vaultV2.connect(user).claimYield();

    const vaultBalanceAfter = await vaultV2.balanceOf(user.address);
    const walletBalanceAfter = await token.balanceOf(user.address);

    // Check: Yield should be in wallet, not added to vault principal
    expect(walletBalanceAfter).to.be.gt(walletBalanceBefore);
    expect(vaultBalanceAfter).to.equal(vaultBalanceBefore);
  });
});
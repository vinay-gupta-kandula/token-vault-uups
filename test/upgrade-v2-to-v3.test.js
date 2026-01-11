const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Upgrade V2 to V3", function () {
  let owner, user, token, vaultV2, vaultV3;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    // Deploy mock token
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    token = await MockERC20.deploy("MockToken", "MTK");
    await token.deployed();

    // Deploy V1
    const TokenVaultV1 = await ethers.getContractFactory("TokenVaultV1");
    const vaultV1 = await upgrades.deployProxy(
      TokenVaultV1,
      [token.address, owner.address, 500],
      { initializer: "initialize", kind: "uups" }
    );
    await vaultV1.deployed();

    // User deposit: 100 tokens - 5% fee = 95 tokens credited
    await token.transfer(user.address, ethers.utils.parseEther("100"));
    await token.connect(user).approve(vaultV1.address, ethers.utils.parseEther("100"));
    await vaultV1.connect(user).deposit(ethers.utils.parseEther("100"));

    // Upgrade to V2
    const TokenVaultV2 = await ethers.getContractFactory("TokenVaultV2");
    vaultV2 = await upgrades.upgradeProxy(vaultV1.address, TokenVaultV2);
    await vaultV2.initializeV2(500);

    // Upgrade to V3
    const TokenVaultV3 = await ethers.getContractFactory("TokenVaultV3");
    vaultV3 = await upgrades.upgradeProxy(vaultV2.address, TokenVaultV3);
    await vaultV3.initializeV3(10); // 10 seconds delay
  });

  it("should preserve all V2 state after upgrade", async function () {
    // Principal should be exactly 95 tokens (100 - 5% fee)
    const balance = await vaultV3.balanceOf(user.address);
    expect(balance).to.equal(ethers.utils.parseEther("95"));
    
    // Verify yield rate was preserved from V2
    expect(await vaultV3.getYieldRate()).to.equal(500);
  });

  it("should allow setting withdrawal delay", async function () {
    await vaultV3.setWithdrawalDelay(5);
    expect(await vaultV3.getWithdrawalDelay()).to.equal(5);
  });

  it("should handle withdrawal requests correctly", async function () {
    const amount = ethers.utils.parseEther("100"); // Attempting to request more than balance
    await expect(
        vaultV3.connect(user).requestWithdrawal(amount)
    ).to.be.revertedWith("Insufficient balance");

    await vaultV3.connect(user).requestWithdrawal(ethers.utils.parseEther("10"));
    const req = await vaultV3.getWithdrawalRequest(user.address);
    expect(req.amount).to.equal(ethers.utils.parseEther("10"));
  });

  it("should enforce withdrawal delay", async function () {
    await vaultV3.connect(user).requestWithdrawal(ethers.utils.parseEther("10"));

    await expect(
      vaultV3.connect(user).executeWithdrawal()
    ).to.be.revertedWith("Withdrawal delay not passed");
  });

  it("should prevent premature withdrawal execution", async function () {
    await vaultV3.connect(user).requestWithdrawal(ethers.utils.parseEther("10"));

    // Increase time but not enough to meet the 10s delay
    await ethers.provider.send("evm_increaseTime", [5]);
    await ethers.provider.send("evm_mine");

    await expect(
      vaultV3.connect(user).executeWithdrawal()
    ).to.be.revertedWith("Withdrawal delay not passed");
  });

  it("should allow execution after delay and follow CEI pattern", async function () {
    const withdrawAmount = ethers.utils.parseEther("10");
    await vaultV3.connect(user).requestWithdrawal(withdrawAmount);

    // Meet the 10s delay
    await ethers.provider.send("evm_increaseTime", [11]);
    await ethers.provider.send("evm_mine");

    const initialBalance = await vaultV3.balanceOf(user.address);
    await vaultV3.connect(user).executeWithdrawal();
    
    const finalBalance = await vaultV3.balanceOf(user.address);
    expect(finalBalance).to.equal(initialBalance.sub(withdrawAmount));
    
    // Request should be deleted (CEI check)
    const req = await vaultV3.getWithdrawalRequest(user.address);
    expect(req.amount).to.equal(0);
  });

  it("should allow emergency withdrawals and clear pending requests", async function () {
    // Setup a request first
    await vaultV3.connect(user).requestWithdrawal(ethers.utils.parseEther("10"));
    
    // Emergency withdraw should bypass delay and clear the request
    await vaultV3.connect(user).emergencyWithdraw();

    const balance = await vaultV3.balanceOf(user.address);
    expect(balance).to.equal(0);
    
    const req = await vaultV3.getWithdrawalRequest(user.address);
    expect(req.amount).to.equal(0);
  });
});
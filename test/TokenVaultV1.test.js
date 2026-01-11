const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("TokenVaultV1", function () {
  let Token, token, vault, owner, user;

  beforeEach(async function () {
    [owner, user] = await ethers.getSigners();

    // Deploy mock token
    const MockERC20 = await ethers.getContractFactory("MockERC20");
    token = await MockERC20.deploy("MockToken", "MTK");
    await token.deployed();

    // Deploy vault as UUPS proxy
    Token = await ethers.getContractFactory("TokenVaultV1");
    vault = await upgrades.deployProxy(
      Token,
      [token.address, owner.address, 500],
      { initializer: "initialize", kind: "uups" }
    );
    await vault.deployed();

    // Give user tokens
    await token.transfer(user.address, ethers.utils.parseEther("1000"));
  });

  it("should initialize with correct parameters", async function () {
    expect(await vault.getDepositFee()).to.equal(
      ethers.BigNumber.from(500)
    );
  });

  it("should allow deposits and update balances", async function () {
    const amount = ethers.utils.parseEther("100");

    await token.connect(user).approve(vault.address, amount);
    await vault.connect(user).deposit(amount);

    const expected = amount.mul(95).div(100);
    expect(await vault.balanceOf(user.address)).to.equal(expected);
  });

  it("should deduct deposit fee correctly", async function () {
    const amount = ethers.utils.parseEther("100");

    await token.connect(user).approve(vault.address, amount);
    await vault.connect(user).deposit(amount);

    const expected = amount.sub(amount.mul(500).div(10_000));
    expect(await vault.balanceOf(user.address)).to.equal(expected);
  });

  it("should allow withdrawals and update balances", async function () {
    const amount = ethers.utils.parseEther("100");

    await token.connect(user).approve(vault.address, amount);
    await vault.connect(user).deposit(amount);

    const net = amount.mul(95).div(100);
    await vault.connect(user).withdraw(net);

    expect(await vault.balanceOf(user.address)).to.equal(
      ethers.BigNumber.from(0)
    );
  });

  it("should prevent withdrawal of more than balance", async function () {
    await expect(
      vault.connect(user).withdraw(ethers.utils.parseEther("1"))
    ).to.be.revertedWith("Insufficient balance");
  });

  it("should prevent reinitialization", async function () {
    await expect(
      vault.initialize(token.address, owner.address, 100)
    ).to.be.reverted;
  });
});

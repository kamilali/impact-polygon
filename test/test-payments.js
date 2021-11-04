const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ImpactPayment", function () {
  it("Should make a deposit", async function () {
    const ImpactPayment = await ethers.getContractFactory("ImpactPayment");
    const impactPayment = await ImpactPayment.deploy();
    await impactPayment.deployed();

    const [_, donationAddress] = await ethers.getSigners();

    await impactPayment.connect(donationAddress).depositFundsETH(0, {value: ethers.utils.parseEther('0.01')});
  });
});

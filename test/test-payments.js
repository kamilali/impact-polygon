const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ImpactPayments", function () {
  it("Should make a deposit", async function () {
    const ImpactPayments = await ethers.getContractFactory("ImpactPayments");
    const impactPayments = await ImpactPayments.deploy(["0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa", "0xc2569dd7d0fd715b054fbf16e75b001e5c0c1115"]);
    await impactPayments.deployed();

    const [_, donationAddress] = await ethers.getSigners();

    await impactPayments.connect(donationAddress).depositFundsETH(0, {value: ethers.utils.parseEther('0.01')});
  });
});

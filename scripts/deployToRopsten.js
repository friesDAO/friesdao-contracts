const { deployAll } = require("../src/deploy");
const { whitelist} = require("./whitelist1");
const { ethers } = require("hardhat")

const TREASURY = "0x8aF77852423e7a55e77D16eFfA7347d4cF29B317"

async function deployUSDC() {
    const factory = await ethers.getContractFactory("TestUSDC");
    const usdc = await factory.deploy();
    return usdc.address;
}

async function deployToRopsten() {
    const usdcAddress = await deployUSDC();
    console.log("USDC deployed at", usdcAddress)
    await deployAll(usdcAddress, TREASURY, whitelist)
}

module.exports = { deployToRopsten }

deployToRopsten()
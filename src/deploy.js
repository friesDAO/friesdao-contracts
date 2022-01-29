const { ethers } = require("hardhat")
const { makeTree } = require("../src/merkle")
        
async function deployFries() {    
    const factory = await ethers.getContractFactory("FriesDAOToken");
    const fries = await factory.deploy();
    await fries.deployed();
    console.log("Fries deployed at", fries.address);
    return fries;
}

async function deploySale(usdcAddress, friesAddress, treasuryAddress, hexRoot) {    
    const factory = await ethers.getContractFactory("contracts/sale-usdc.sol:FriesDAOTokenSale")
    const sale = await factory.deploy(usdcAddress, friesAddress, treasuryAddress, hexRoot);
    await sale.deployed();
    console.log("Sale deployed at", sale.address);
    return sale;
}

async function deployAll(usdcAddress, treasuryAddress, whitelist) {
    const tree = makeTree(whitelist);
    const hexRoot = tree.getHexRoot();
    const fries = await deployFries();
    await deploySale(usdcAddress, fries.address, treasuryAddress, hexRoot);
}

module.exports = {
    deployFries, deploySale, deployAll
}
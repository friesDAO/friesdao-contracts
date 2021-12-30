// Files and modules

const { expect } = require("chai")
const { ethers } = require("hardhat")

const toETH = num => ethers.utils.parseEther(num.toString())

// Test FRIES token

describe("FriesDAOToken", async () => {
    // FRIES token test data

    let deployer, second, third
    let FriesContract
    let FRIES

    // Load deployment data

    before(async () => {
        [
            [ deployer, second, third ],
            FriesContract
        ] = await Promise.all([
            ethers.getSigners(),
            ethers.getContractFactory("FriesDAOToken")
        ])
    })

    // Test token deployment

    it("Deploy successfully", async () => {
        FRIES = await FriesContract.deploy()
    })

    // Test token parameters

    it("Correct token parameters", async () => {
        expect(await FRIES.name()).to.equal("friesDAO")
        expect(await FRIES.symbol()).to.equal("FRIES"),
        expect(await FRIES.decimals()).to.equal(18),
        expect(await FRIES.totalSupply()).to.equal(0),
        expect(await FRIES.owner()).to.equal(deployer.address)
    })

    // Test owner mint

    it("Mint from owner call", async () => {
        await FRIES.mint(second.address, toETH(1))
        expect(await FRIES.balanceOf(second.address)).to.equal(toETH(1))
    })

    // Test add admin

    it("Add admin correctly", async () => {
        await FRIES.addAdmin(second.address)
        expect(await FRIES.admins(second.address)).to.equal(true)
    })

    // Test admin mint

    it("Mint from admin call", async () => {
        await FRIES.connect(second).mint(third.address, toETH(1))
        expect(await FRIES.balanceOf(third.address)).to.equal(toETH(1))
    })

    // Test remove admin

    it("Remove admin correctly", async () => {
        await FRIES.removeAdmin(second.address)
        expect(await FRIES.admins(second.address)).to.equal(false)
    })

    // Test non-admin mint

    it("Mint from non-admin call should fail", async () => {
        await expect(FRIES.connect(second).mint(third.address, toETH(1))).to.be.reverted
    })

    // Test self burn

    it("Burn self balance", async () => {
        await FRIES.connect(second).burn(toETH(1))
        expect(await FRIES.balanceOf(second.address)).to.equal(0)
    })

    // Test burn from account without approval

    it("Burn from account without approval should fail", async () => {
        await expect(FRIES.connect(second).burnFrom(third.address, toETH(1))).to.be.reverted
    })

    // Test burn from account

    it("Burn from account", async () => {
        await FRIES.connect(third).approve(second.address, toETH(1))
        await FRIES.connect(second).burnFrom(third.address, toETH(1))
        expect(await FRIES.balanceOf(third.address)).to.equal(0)
        expect(await FRIES.allowance(third.address, second.address)).to.equal(0)
    })
})
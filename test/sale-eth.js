// Files and modules

const { expect } = require("chai")
const { ethers } = require("hardhat")

const toETH = num => ethers.utils.parseEther(num.toString())

// Test FRIES token sale

describe("FriesDAOTokenSale", () => {
    // FRIES token sale test data

    let deployer, second, third, fourth
    let FriesContract, SaleContract
    let FRIES, Sale

    // Load deployment data

    before(async () => {
        [
            [ deployer, second, third, fourth ],
            FriesContract,
            SaleContract
        ] = await Promise.all([
            ethers.getSigners(),
            ethers.getContractFactory("FriesDAOToken"),
            ethers.getContractFactory("contracts/sale-eth.sol:FriesDAOTokenSale")
        ])
    })

    // Test deployment

    it("Deploy successfully", async () => {
        FRIES = await FriesContract.deploy()
        Sale = await SaleContract.deploy(FRIES.address)
    })

    // Test sale parameters

    it("Correct sale parameters", async () => {
        expect(await Sale.whitelistSaleActive()).to.equal(false)
        expect(await Sale.publicSaleActive()).to.equal(false)
        expect(await Sale.redeemActive()).to.equal(false)
        expect(await Sale.refundActive()).to.equal(false)

        expect(await Sale.salePrice()).to.equal(69420)
        expect(await Sale.whitelistCap()).to.equal(toETH(2100))
        expect(await Sale.totalCap()).to.equal(toETH(4200))

        expect(await Sale.whitelistCount()).to.equal(0)
        expect(await Sale.totalPurchased()).to.equal(0)
    })

    // Test change sale parameters

    it("Owner can change parameters", async () => {
        await Sale.setSalePrice(10)
        expect(await Sale.salePrice()).to.equal(10)
        await Sale.setWhitelistCap(toETH(10))
        expect(await Sale.whitelistCap()).to.equal(toETH(10))
        await Sale.setSalePrice(69420)
        await Sale.setWhitelistCap(toETH(2100))
    })

    // Test sale whitelist

    it("Whitelist accounts", async () => {
        await Sale.whitelistAccounts([second.address, third.address])
        expect(await Sale.whitelist(second.address)).to.equal(true)
        expect(await Sale.whitelist(third.address)).to.equal(true)
        expect(await Sale.whitelistCount()).to.equal(2)
    })

    // Test whitelist purchase before enabled

    it("Whitelisted FRIES purchase before enabled should fail", async () => {
        await expect(Sale.connect(second).buyWhitelistFries({ value: toETH(1) })).to.be.reverted
    })

    // Test enabling whitelist sale

    it("Set whitelist sale active", async () => {
        await Sale.setWhitelistSaleActive(true)
        expect(await Sale.whitelistSaleActive()).to.equal(true)
    })

    // Test non-whitelisted whitelist purchase

    it("Non-whitelisted whitelist purchase should fail", async () => [
        await expect(Sale.connect(fourth).buyWhitelistFries({ value: toETH(1) })).to.be.reverted
    ])

    // Test whitelist purchase

    it("Whitelisted FRIES purchase", async () => {
        await Sale.connect(second).buyWhitelistFries({ value: toETH(1) })
        expect(await ethers.provider.getBalance(Sale.address)).to.equal(toETH(1))
        expect(await Sale.purchased(second.address)).to.equal(toETH(69420))
        expect(await Sale.redeemed(second.address)).to.equal(0)
        expect(await Sale.totalPurchased()).to.equal(toETH(69420))
    })

    // Test whitelist purchase over limit

    it("Whitelisted FRIES purchase over limit should fail", async () => {
        await expect(Sale.connect(second).buyWhitelistFries({ value: toETH(2100 / 2) })).to.be.reverted
    })

    // Test disabling whitelist sale

    it("Set whitelist sale ended", async () => {
        await Sale.setWhitelistSaleActive(false)
        expect(await Sale.whitelistSaleActive()).to.equal(false)
    })

    // Test regular purchase before enabled

    it("Regular FRIES purchase before enabled should fail", async () => {
        await expect(Sale.connect(fourth).buyWhitelistFries({ value: toETH(1) })).to.be.reverted
    })

    // Test enabling public sale

    it("Set public sale active", async () => {
        await Sale.setPublicSaleActive(true)
        expect(await Sale.publicSaleActive()).to.equal(true)
    })

    // Test regular purchase

    it("Regular FRIES purchase", async () => {
        await Sale.connect(fourth).buyFries({ value: toETH(1) })
        expect(await ethers.provider.getBalance(Sale.address)).to.equal(toETH(1 * 2))
        expect(await Sale.purchased(fourth.address)).to.equal(toETH(69420))
        expect(await Sale.redeemed(fourth.address)).to.equal(0)
        expect(await Sale.totalPurchased()).to.equal(toETH(69420 * 2))
    })

    // Test regular purchase over total limit

    it("Regular FRIES purchase over total limit should fail", async () => {
        await expect(Sale.connect(fourth).buyFries({ value: toETH(4200) })).to.be.reverted
    })

    // Test disabling regular sale

    it("Set regular sale ended", async () => {
        await Sale.setPublicSaleActive(false)
        expect(await Sale.publicSaleActive()).to.equal(false)
    })

    // Test mint FRIES to sale contract

    it("Mint FRIES to sale contract", async () => {
        await FRIES.mint(Sale.address, toETH(10 ** 6))
        expect(await FRIES.balanceOf(Sale.address)).to.equal(toETH(10 ** 6))
    })

    // Test redeem before enabled

    it("Redeem FRIES before enabled should fail", async () => {
        await expect(Sale.connect(second).redeemFries(toETH(69420))).to.be.reverted
    })

    // Test enabling redeem

    it("Set redeem enabled", async () => {
        await Sale.setRedeemActive(true)
        expect(await Sale.redeemActive()).to.equal(true)
    })

    // Test redeem FRIES without purchased

    it("Redeem FRIES without purchased should fail", async () => {
        await expect(Sale.connect(third).redeemFries()).to.be.reverted
    })

    // Test redeem FRIES

    it("Redeem FRIES", async () => {
        await Sale.connect(second).redeemFries()
        expect(await FRIES.balanceOf(second.address)).to.equal(toETH(69420))
        expect(await Sale.redeemed(second.address)).to.equal(toETH(69420))
    })

    // Test redeem FRIES after already redeemed

    it("Redeeming FRIES after already redeemed should fail", async () => {
        await expect(Sale.connect(second).redeemFries()).to.be.reverted
    })

    // Test disabling redeem

    it("Set redeem ended", async () => {
        await Sale.setRedeemActive(false)
        expect(await Sale.redeemActive()).to.equal(false)
    })

    // Test refund before refund enabled

    it("Refund call before refund enabled should fail", async () => {
        await expect(Sale.connect(second).refundFries(toETH(69420))).to.be.reverted
    })

    // Test enabling refunds

    it("Set refund enabled", async () => {
        await Sale.setRefundActive(true)
        expect(await Sale.refundActive()).to.equal(true)
    })

    // Test FRIES refund

    it("Refund FRIES purchase", async () => {
        const ethBefore = await ethers.provider.getBalance(second.address)
        await FRIES.connect(second).approve(Sale.address, toETH(69420))
        await Sale.connect(second).refundFries(toETH(69420))
        expect(await ethers.provider.getBalance(Sale.address)).to.equal(toETH(1))
        expect((await ethers.provider.getBalance(second.address)).gt(ethBefore)).to.equal(true)
        expect(await Sale.purchased(second.address)).to.equal(0)
        expect(await Sale.redeemed(second.address)).to.equal(0)
        expect(await FRIES.balanceOf(second.address)).to.equal(0)
    })

    // Test disabling refunds

    it("Set refund ended", async () => {
        await Sale.setRefundActive(false)
        expect(await Sale.refundActive()).to.equal(false)
    })

    // Test ETH withdraw

    it("Withdraw ETH", async () => {
        const [ balance, ethBefore ] = await Promise.all([
            ethers.provider.getBalance(Sale.address),
            ethers.provider.getBalance(deployer.address)
        ])
        await Sale.withdrawETH(balance)
        expect(await ethers.provider.getBalance(Sale.address)).to.equal(0)
        expect((await ethers.provider.getBalance(deployer.address)).gt(ethBefore)).to.equal(true)
    })
})
// Files and modules

const { expect } = require("chai")
const { ethers } = require("hardhat")

const toETH = num => ethers.utils.parseEther(num.toString())
const toUSDC = num => ethers.utils.parseUnits(num.toString(), 6)

// Test FRIES token sale

describe("FriesDAOTokenSale", () => {
    // FRIES token sale test data

    let deployer, second, third, fourth, fifth
    let USDCContract, FriesContract, SaleContract
    let USDC, FRIES, Sale

    // Load deployment data

    before(async () => {
        [
            [ deployer, second, third, fourth, fifth ],
            USDCContract,
            FriesContract,
            SaleContract
        ] = await Promise.all([
            ethers.getSigners(),
            ethers.getContractFactory("TestUSDC"),
            ethers.getContractFactory("FriesDAOToken"),
            ethers.getContractFactory("contracts/sale-usdc.sol:FriesDAOTokenSale")
        ])
    })

    // Test deployment

    it("Deploy successfully", async () => {
        USDC = await USDCContract.deploy()
        FRIES = await FriesContract.deploy()
        Sale = await SaleContract.deploy(USDC.address, FRIES.address, fifth.address)

        await Promise.all([
            USDC.mint(deployer.address, toUSDC(10**6)),
            USDC.mint(second.address, toUSDC(10**6)),
            USDC.mint(third.address, toUSDC(10**6)),
            USDC.mint(fourth.address, toUSDC(10**6)),
            USDC.connect(deployer).approve(Sale.address, toUSDC(10**18)),
            USDC.connect(second).approve(Sale.address, toUSDC(10**18)),
            USDC.connect(third).approve(Sale.address, toUSDC(10**18)),
            USDC.connect(fourth).approve(Sale.address, toUSDC(10**18))
        ])
    })

    // Test sale parameters

    it("Correct sale parameters", async () => {
        expect(await Sale.whitelistSaleActive()).to.equal(false)
        expect(await Sale.publicSaleActive()).to.equal(false)
        expect(await Sale.redeemActive()).to.equal(false)
        expect(await Sale.refundActive()).to.equal(false)

        expect(await Sale.salePrice()).to.equal(42)
        expect(await Sale.baseWhitelistAmount()).to.equal(toUSDC(5000))
        expect(await Sale.totalCap()).to.equal(toUSDC(18696969))
        expect(await Sale.totalPurchased()).to.equal(0)
    })

    // Test change sale parameters

    it("Owner can change parameters", async () => {
        await Sale.setSalePrice(10)
        expect(await Sale.salePrice()).to.equal(10)
        await Sale.setBaseWhitelistAmount(toUSDC(10))
        expect(await Sale.baseWhitelistAmount()).to.equal(toUSDC(10))
        await Sale.setSalePrice(42)
        await Sale.setBaseWhitelistAmount(toUSDC(5000))
    })

    // Test sale whitelist

    it("Whitelist accounts with default whitelist allocation", async () => {
        await Sale.whitelistAccounts([second.address])
        expect(await Sale.whitelist(second.address)).to.equal(toUSDC(5000))
    })

    // Test sale whitelist with custom allocation and vesting

    it("Whitelist accounts with custom allocation and vesting", async () => {
        await Sale.whitelistAccountsWithAllocation([third.address], [toUSDC(10000)], [true])
        expect(await Sale.whitelist(third.address)).to.equal(toUSDC(10000))
        expect(await Sale.vesting(third.address)).to.equal(true)
    })

    // Test whitelist purchase before enabled

    it("Whitelisted FRIES purchase before enabled should fail", async () => {
        await expect(Sale.connect(second).buyWhitelistFries(toUSDC(1))).to.be.reverted
    })

    // Test enabling whitelist sale

    it("Set whitelist sale active", async () => {
        await Sale.setWhitelistSaleActive(true)
        expect(await Sale.whitelistSaleActive()).to.equal(true)
    })

    // Test non-whitelisted whitelist purchase

    it("Non-whitelisted whitelist purchase should fail", async () => [
        await expect(Sale.connect(fourth).buyWhitelistFries(toUSDC(1))).to.be.reverted
    ])

    // Test whitelist purchase

    it("Whitelisted FRIES purchase", async () => {
        await Sale.connect(second).buyWhitelistFries(toUSDC(1))
        expect(await USDC.balanceOf(Sale.address)).to.equal(toUSDC(1))
        expect(await Sale.purchased(second.address)).to.equal(toETH(42))
        expect(await Sale.redeemed(second.address)).to.equal(0)
        expect(await Sale.totalPurchased()).to.equal(toETH(42))
    })

    // Test whitelist purchase over limit

    it("Whitelisted FRIES purchase over limit should fail", async () => {
        await expect(Sale.connect(second).buyWhitelistFries(toUSDC(6000))).to.be.reverted
    })

    // Test disabling whitelist sale

    it("Set whitelist sale ended", async () => {
        await Sale.setWhitelistSaleActive(false)
        expect(await Sale.whitelistSaleActive()).to.equal(false)
    })

    // Test regular purchase before enabled

    it("Regular FRIES purchase before enabled should fail", async () => {
        await expect(Sale.connect(fourth).buyWhitelistFries(toUSDC(1))).to.be.reverted
    })

    // Test enabling public sale

    it("Set public sale active", async () => {
        await Sale.setPublicSaleActive(true)
        expect(await Sale.publicSaleActive()).to.equal(true)
    })

    // Test regular purchase

    it("Regular FRIES purchase", async () => {
        await Sale.connect(fourth).buyFries(toUSDC(1))
        expect(await USDC.balanceOf(Sale.address)).to.equal(toUSDC(1 * 2))
        expect(await Sale.purchased(fourth.address)).to.equal(toETH(42))
        expect(await Sale.redeemed(fourth.address)).to.equal(0)
        expect(await Sale.totalPurchased()).to.equal(toETH(42 * 2))
    })

    // Test regular purchase over total limit

    it("Regular FRIES purchase over total limit should fail", async () => {
        await expect(Sale.connect(fourth).buyFries(toUSDC(18696969))).to.be.reverted
    })

    // Test disabling regular sale

    it("Set regular sale ended", async () => {
        await Sale.setPublicSaleActive(false)
        expect(await Sale.publicSaleActive()).to.equal(false)
    })

    // Test mint FRIES to sale contract

    it("Mint FRIES to sale contract", async () => {
        await FRIES.mint(Sale.address, toETH(10**6))
        expect(await FRIES.balanceOf(Sale.address)).to.equal(toETH(10**6))
    })

    // Test redeem before enabled

    it("Redeem FRIES before enabled should fail", async () => {
        await expect(Sale.connect(second).redeemFries(toETH(42))).to.be.reverted
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
        expect(await FRIES.balanceOf(second.address)).to.equal(toETH(42))
        expect(await Sale.redeemed(second.address)).to.equal(toETH(42))
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
        await expect(Sale.connect(second).refundFries(toETH(42))).to.be.reverted
    })

    // Test enabling refunds

    it("Set refund enabled", async () => {
        await Sale.setRefundActive(true)
        expect(await Sale.refundActive()).to.equal(true)
    })

    // Test FRIES refund

    it("Refund FRIES purchase", async () => {
        const usdcBefore = await USDC.balanceOf(second.address)
        await FRIES.connect(second).approve(Sale.address, toETH(42))
        await Sale.connect(second).refundFries(toETH(42))
        expect(await USDC.balanceOf(Sale.address)).to.equal(toUSDC(1))
        expect(await USDC.balanceOf(second.address)).to.equal(usdcBefore.add(toUSDC(1)))
        expect(await Sale.purchased(second.address)).to.equal(0)
        expect(await Sale.redeemed(second.address)).to.equal(0)
        expect(await FRIES.balanceOf(second.address)).to.equal(0)
    })

    // Test disabling refunds

    it("Set refund ended", async () => {
        await Sale.setRefundActive(false)
        expect(await Sale.refundActive()).to.equal(false)
    })
})
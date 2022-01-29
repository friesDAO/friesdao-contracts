// Files and modules

const { expect } = require("chai")
const { ethers } = require("hardhat")
const { makeLeaf, makeTree } = require("../src/merkle")

const toETH = num => ethers.utils.parseEther(num.toString())
const toUSDC = num => ethers.utils.parseUnits(num.toString(), 6)

const PRICE = 43.3125031

const whitelist = [
    ["0x70997970C51812dc3A010C7d01b50e0d17dc79C8", 210000, false],   // 5k WL (5k * 42) vesting FALSE      second
    ["0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", 420000, false],   // 10 WL vesting FALSE      third
    ["0x90F79bf6EB2c4f870365E785982E1f101E93b906", 5250000, true]    // 125k WL vesting TRUE     fourth
]

//////////////////////////////e /////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////

// Test FRIES token sale

describe("FriesDAOTokenSale", () => {
    // FRIES token sale test data

    let deployer, second, third, fourth, fifth, sixth
    let USDCContract, FriesContract, SaleContract
    let USDC, FRIES, Sale
    var leaf   
    var proof  
    let tree

    // Load deployment data

    before(async () => {
        [
            [ deployer, second, third, fourth, fifth, sixth ],
            USDCContract,
            FriesContract,
            SaleContract
        ] = await Promise.all([
            ethers.getSigners(),
            ethers.getContractFactory("TestUSDC"),
            ethers.getContractFactory("FriesDAOToken"),
            ethers.getContractFactory("contracts/sale-usdc.sol:FriesDAOTokenSale")
        ])
        tree = makeTree(whitelist);
    })

    // Test deployment

    it("Deploy successfully", async () => {
        USDC = await USDCContract.deploy()
        FRIES = await FriesContract.deploy()
        Sale = await SaleContract.deploy(USDC.address, FRIES.address, fifth.address, tree.getHexRoot())

        await Promise.all([
            USDC.mint(deployer.address, toUSDC(10**6)),
            USDC.mint(second.address, toUSDC(10**6)),
            USDC.mint(third.address, toUSDC(10**6)),
            USDC.mint(fourth.address, toUSDC(10**6)),
            USDC.mint(sixth.address, toUSDC(10**6)),
            USDC.connect(deployer).approve(Sale.address, toUSDC(10**18)),
            USDC.connect(second).approve(Sale.address, toUSDC(10**18)),
            USDC.connect(third).approve(Sale.address, toUSDC(10**18)),
            USDC.connect(fourth).approve(Sale.address, toUSDC(10**18)),
            USDC.connect(sixth).approve(Sale.address, toUSDC(10**18))
        ])
    })

    // Test sale parameters

    it("Correct sale parameters", async () => {
        expect(await Sale.whitelistSaleActive()).to.equal(false)
        expect(await Sale.publicSaleActive()).to.equal(false)
        expect(await Sale.redeemActive()).to.equal(false)
        expect(await Sale.refundActive()).to.equal(false)

        expect(await Sale.salePrice()).to.equal(toETH(PRICE))
        expect(await Sale.totalCap()).to.equal(toUSDC(9696969))
        expect(await Sale.totalPurchased()).to.equal(0)
    })

    // Test change sale parameters

    it("Owner can change parameters", async () => {
        await Sale.setSalePrice(toETH(10))
        expect(await Sale.salePrice()).to.equal(toETH(10))
        await Sale.setSalePrice(toETH(PRICE))
        await Sale.setRoot(tree.getHexRoot())      
        await expect(Sale.connect(second).setRoot(tree.getHexRoot())).to.reverted  
    })

    /*
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
    */

    // Test whitelist purchase before enabled

    it("Whitelisted FRIES purchase before enabled should fail", async () => {
        leaf = makeLeaf(second.address, 210000, false, 18)
        proof = tree.getHexProof(leaf)
        await expect(Sale.connect(second).buyWhitelistFries(
            toUSDC(1),
            toETH(210000),
            false,
            proof
        )).to.be.revertedWith("FriesDAOTokenSale: whitelist token sale is not active")
    })

    // Test enabling whitelist sale

    it("Set whitelist sale active", async () => {
        await Sale.setWhitelistSaleActive(true)
        expect(await Sale.whitelistSaleActive()).to.equal(true)
    })

    // Test non-whitelisted whitelist purchase

    it("Non-whitelisted whitelist purchase should fail", async () => {
        leaf = makeLeaf(deployer.address, 210000, false, 18)
        proof = tree.getHexProof(leaf)
        //await expect(Sale.connect(fourth).buyWhitelistFries(toUSDC(1))).to.be.reverted
        await expect(Sale.connect(deployer).buyWhitelistFries(
            toUSDC(1),
            toETH(210000),
            false,
            proof
        )).to.be.revertedWith("FriesDAOTokenSale: invalid whitelist parameters")
    })

    // Test whitelist purchase

    it("Whitelisted FRIES purchase", async () => {
        //await Sale.connect(second).buyWhitelistFries(toUSDC(1))
        leaf = makeLeaf(second.address, 210000, false, 18)
        proof = tree.getHexProof(leaf)
        await Sale.connect(second).buyWhitelistFries(
            toUSDC(1),
            toETH(210000),
            false,
            proof
        )
        expect(await USDC.balanceOf(fifth.address)).to.equal(toUSDC(1))
        expect(await Sale.purchased(second.address)).to.equal(toETH(PRICE))
        expect(await Sale.redeemed(second.address)).to.equal(0)
        expect(await Sale.totalPurchased()).to.equal(toUSDC(1))
    })

    // Test whitelist purchase over limit

    it("Whitelisted FRIES purchase over limit should fail", async () => {
        //await expect(Sale.connect(second).buyWhitelistFries(toUSDC(5000))).to.be.reverted
        await expect(Sale.connect(second).buyWhitelistFries(
            toUSDC(5000),
            toETH(210000),
            false,
            proof
        )).to.revertedWith("FriesDAOTokenSale: amount over whitelist limit")
    })

    // Test special whitelist purchase

    it("Special whitelisted FRIES purchase", async () => { 
        //await Sale.connect(third).buyWhitelistFries(toUSDC(100))
        leaf = makeLeaf(fourth.address, 5250000, true, 18)
        proof = tree.getHexProof(leaf)
        await Sale.connect(fourth).buyWhitelistFries(
            toUSDC(100),
            toETH(5250000),
            true,
            proof
        )
        expect(await USDC.balanceOf(fifth.address)).to.equal(toUSDC(101))
        expect(await Sale.purchased(fourth.address)).to.equal(toETH(4331.25031))
        expect(await Sale.redeemed(fourth.address)).to.equal(0)
        expect(await Sale.totalPurchased()).to.equal(toUSDC(101))
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
        //await Sale.connect(fourth).buyFries(toUSDC(1))
        await Sale.connect(sixth).buyFries(toUSDC(1))
        expect(await USDC.balanceOf(fifth.address)).to.equal(toUSDC(102))
        expect(await Sale.purchased(sixth.address)).to.equal(toETH(PRICE))
        expect(await Sale.redeemed(sixth.address)).to.equal(0)
        expect(await Sale.totalPurchased()).to.equal(toUSDC(102))
    })

    // Test regular purchase over total limit

    it("Regular FRIES purchase over total limit should fail", async () => {
        await expect(Sale.connect(sixth).buyFries(toUSDC(18696969))).to.be.reverted
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
        await expect(Sale.connect(deployer).redeemFries()).to.be.reverted
    })

    // Test redeem FRIES

    it("Redeem FRIES", async () => {
        await Sale.connect(second).redeemFries()
        expect(await FRIES.balanceOf(second.address)).to.equal(toETH(PRICE))
        expect(await Sale.redeemed(second.address)).to.equal(toETH(PRICE))
    })

    // Test special redeem FRIES

    it("Special redeem FRIES", async () => {
        await Sale.connect(fourth).redeemFries()
        expect(await FRIES.balanceOf(fourth.address)).to.equal(toETH(4331.25031 * 0.15))
        expect(await FRIES.balanceOf(fifth.address)).to.equal(toETH(4331.25031 * 0.85))
        expect(await Sale.redeemed(fourth.address)).to.equal(toETH(4331.25031))
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
        await USDC.connect(fifth).approve(Sale.address, toETH(10000000))
        const usdcBefore = await USDC.balanceOf(second.address)
        await FRIES.connect(second).approve(Sale.address, toETH(PRICE))
        await Sale.connect(second).refundFries(toETH(PRICE))
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
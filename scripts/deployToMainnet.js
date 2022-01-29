const { deployAll } = require("../src/deploy");
const { whitelist} = require("./whitelist1");

const USDC = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
const TREASURY = "0x7163beE2a0a4C75D1236Bf053E429f86eB45426E"

async function deployToMainnet() {
    await deployAll(USDC, TREASURY, whitelist)
}

module.exports = { deployToMainnet }

deployToMainnet()
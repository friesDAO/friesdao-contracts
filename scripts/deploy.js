const { deployAll } = require("../src/deploy");

const USDC = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
const TREASURY = "0x7163beE2a0a4C75D1236Bf053E429f86eB45426E"

const whitelist = [
    ["0x70997970C51812dc3A010C7d01b50e0d17dc79C8", 210000, false],   // 5k WL (5k * 42) vesting FALSE      second
    ["0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC", 420000, false],   // 10 WL vesting FALSE      third
    ["0x90F79bf6EB2c4f870365E785982E1f101E93b906", 5250000, true]    // 125k WL vesting TRUE     fourth
]

deployAll(USDC, TREASURY, whitelist)
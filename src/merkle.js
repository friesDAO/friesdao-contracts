
const keccak256  = require("keccak256")
const { MerkleTree } = require("merkletreejs")

function makeLeaf(address, amount, vesting, decimals) {
    const normalizedAddress = ethers.utils.getAddress(address)
    const value = ethers.utils.parseUnits(amount.toString(), decimals).toString()
    const keccak = ethers.utils.solidityKeccak256(
        ["address", "uint256", "bool"], 
        [normalizedAddress, value, vesting]
    ).slice(2)    
    return Buffer.from(keccak, "hex")
}

function makeTree(whitelist) {
    const leaves =  whitelist.map(([address, amount, vesting]) => 
        makeLeaf(address, amount, vesting, 18))
    return new MerkleTree(
        leaves,
        keccak256,
        { sort: true }
    )
}

module.exports = {
    makeLeaf, 
    makeTree
}
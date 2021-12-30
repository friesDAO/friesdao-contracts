require("@nomiclabs/hardhat-waffle")
module.exports = {
    networks: {
        hardhat: {},
        ropsten: {
            url: "https://ropsten.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
            accounts: []
        }
    },
    solidity: {
        compilers: [{
            version: "0.8.7",
            settings: {
                optimizer: {
                    enabled: true,
                    runs: 200
                }
            }
        }]
    }
}
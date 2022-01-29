const { deployToMainnet } = require("../scripts/deployToMainnet")

describe("Deploy script", async () => {
    it("Deploys successfully", async () => {
        await deployToMainnet()
    })
})

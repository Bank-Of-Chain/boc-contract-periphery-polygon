const {
    topUpWethByAddress,
    topUpUsdtByAddress,
    topUpDaiByAddress,
    topUpUsdcByAddress,
    topUpTusdByAddress,
} = require("../../utils/top-up-utils")
const Utils = require("../../utils/assert-utils")
const addresses = require("../../config/address-config")
const { default: BigNumber } = require("bignumber.js")
const ERC20 = hre.artifacts.require("@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20")

let accounts
let farmer1
describe("【Verify】Recharge Script", function () {
    before(async function () {
        await ethers.getSigners().then(resp => {
            accounts = resp
            farmer1 = accounts[1].address
        })
    })

    it("topUpWethByAddress", async function () {
        const contract = await ERC20.at(addresses.WETH_ADDRESS)
        const decimals = await contract.decimals();
        const topUpAmount = new BigNumber(10).pow(decimals).multipliedBy(new BigNumber(10).pow(9))
        Utils.assertBNEq(await contract.balanceOf(farmer1), 0)
        await topUpWethByAddress(topUpAmount, farmer1)
        Utils.assertBNEq(await contract.balanceOf(farmer1), topUpAmount)
    })

    it("topUpDaiByAddress", async function () {
        const contract = await ERC20.at(addresses.DAI_ADDRESS)
        const decimals = await contract.decimals();
        const topUpAmount = new BigNumber(10).pow(decimals).multipliedBy(new BigNumber(10).pow(9))
        Utils.assertBNEq(await contract.balanceOf(farmer1), 0)
        await topUpDaiByAddress(topUpAmount, farmer1)
        Utils.assertBNEq(await contract.balanceOf(farmer1), topUpAmount)
    })

    it("topUpUsdcByAddress", async function () {
        const contract = await ERC20.at(addresses.USDC_ADDRESS)
        const decimals = await contract.decimals();
        const topUpAmount = new BigNumber(10).pow(decimals).multipliedBy(new BigNumber(10).pow(9))
        Utils.assertBNEq(await contract.balanceOf(farmer1), 0)
        await topUpUsdcByAddress(topUpAmount, farmer1)
        Utils.assertBNEq(await contract.balanceOf(farmer1), topUpAmount)
    })

    it("topUpTusdByAddress", async function () {
        const contract = await ERC20.at(addresses.USDC_ADDRESS)
        const decimals = await contract.decimals();
        const topUpAmount = new BigNumber(10).pow(decimals).multipliedBy(new BigNumber(10).pow(9))
        Utils.assertBNEq(await contract.balanceOf(farmer1), 0)
        await topUpTusdByAddress(topUpAmount, farmer1)
        Utils.assertBNEq(await contract.balanceOf(farmer1), topUpAmount)
    })
})

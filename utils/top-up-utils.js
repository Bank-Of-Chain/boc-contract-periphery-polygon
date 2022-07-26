const { send } = require("@openzeppelin/test-helpers")
const BigNumber = require("bignumber.js")
const { web3 } = require("hardhat")

// === Constants === //
const addresses = require("../config/address-config")

// === Utils === //
const { isArray, isEmpty } = require("lodash")
const { ethers } = require('hardhat');

// === Contracts === //
const IEREC20_USDT = artifacts.require("IEREC20_USDT")
const IEREC20_USDC = artifacts.require("IEREC20_USDC")
const IEREC20_DAI = artifacts.require("IEREC20_DAI")
const IEREC20_TUSD = artifacts.require("IEREC20_TUSD")
const IERC20Metadata = artifacts.require(
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol:IERC20Metadata",
)

/**
 * impersonates
 * @param {*} targetAccounts
 * @returns
 */
async function impersonates (targetAccounts) {
    if (!isArray(targetAccounts)) return new Error("must be a array")
    await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: targetAccounts,
    })
    return async () => {
        await hre.network.provider.request({
            method: "hardhat_stopImpersonatingAccount",
            params: targetAccounts,
        })
    }
}

/**
 * Top up a specified amount of eth for the address(default 10 * 10 ** 18)
 * @param {*} reviver
 * @param {*} amount
 */
const sendEthers = async (reviver, amount = new BigNumber(10).pow(18).multipliedBy(10)) => {
    if (!BigNumber.isBigNumber(amount)) return new Error("must be a bignumber object")
    await network.provider.send("hardhat_setBalance", [reviver, `0x${amount.toString(16)}`])
}

/**
 * recharge core method
 */
async function topUpMain (token, tokenHolder, toAddress, amount) {
    const TOKEN = await IERC20Metadata.at(token)
    const tokenName = await TOKEN.name()
    const farmerBalance = await TOKEN.balanceOf(tokenHolder)
    console.log(
        `Start recharge ${tokenName}，Balance of token holder：%s`,
        new BigNumber(farmerBalance).toFormat(),
    )

    amount = amount.gt ? amount : new BigNumber(amount)
    // If the amount to be recharged is greater than the current account balance, the recharge is for the largest balance
    const nextAmount = amount.gt(farmerBalance) ? new BigNumber(farmerBalance) : amount
    await TOKEN.transfer(toAddress, nextAmount, {
        from: tokenHolder,
    })
    console.log(`${tokenName} recharge amount：` + nextAmount.toFormat())
    console.log(`${tokenName} recharge completed`)
    return nextAmount
}

/**
 * Top up a certain amount of USDT for a certain address(default 10 ** 6)
 */
async function topUpUsdtByAddress (amount = new BigNumber(10).pow(6), toAddress) {
    if (isEmpty(toAddress)) return 0
    const TOKEN = await IEREC20_USDT.at(addresses.USDT_ADDRESS)
    const tokenName = await TOKEN.symbol()
    const tokenOwner = "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa"
    const nextAmount = new BigNumber(amount)
    const nextAmountInHex = web3.utils.padLeft(web3.utils.toHex(amount), 64)
    await sendEthers(tokenOwner)
    console.log(`[Mint]Start recharge ${tokenName}，recharge amount：%s`, nextAmount.toFormat())
    const callback = await impersonates([tokenOwner])
    await TOKEN.deposit(toAddress, nextAmountInHex, {
        from: tokenOwner,
    })
    console.log(`${tokenName} Balance of toAddress：` + new BigNumber(await TOKEN.balanceOf(toAddress)).toFormat())
    console.log(`${tokenName} recharge completed`)
    await callback()
    return amount
}

/**
 * Top up a certain amount of USDC for a certain address(default 10 ** 6)
 */
async function topUpUsdcByAddress (amount = new BigNumber(10).pow(6), toAddress) {
    if (isEmpty(toAddress)) return 0
    const TOKEN = await IEREC20_USDC.at(addresses.USDC_ADDRESS)
    const tokenName = await TOKEN.symbol()
    const tokenOwner = "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa"
    const nextAmount = new BigNumber(amount)
    const nextAmountInHex = web3.utils.padLeft(web3.utils.toHex(amount), 64)
    await sendEthers(tokenOwner)
    console.log(`[Mint]Start recharge ${tokenName}，recharge amount：%s`, nextAmount.toFormat())
    const callback = await impersonates([tokenOwner])
    await TOKEN.deposit(toAddress, nextAmountInHex, {
        from: tokenOwner,
    })
    console.log(`${tokenName} Balance of toAddress：` + new BigNumber(await TOKEN.balanceOf(toAddress)).toFormat())
    console.log(`${tokenName} recharge completed`)
    await callback()
    return amount
}

/**
 * Top up a certain amount of DAI for a certain address(default 10 ** 18)
 */
async function topUpDaiByAddress (amount = new BigNumber(10).pow(18), toAddress) {
    if (isEmpty(toAddress)) return 0
    const TOKEN = await IEREC20_DAI.at(addresses.DAI_ADDRESS)
    const tokenName = await TOKEN.symbol()
    const tokenOwner = "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa"
    const nextAmount = new BigNumber(amount)
    const nextAmountInHex = web3.utils.padLeft(web3.utils.toHex(amount), 64)
    await sendEthers(tokenOwner)
    console.log(`[Mint]Start recharge ${tokenName}，recharge amount：%s`, nextAmount.toFormat())
    const callback = await impersonates([tokenOwner])
    await TOKEN.deposit(toAddress, nextAmountInHex, {
        from: tokenOwner,
    })
    console.log(`${tokenName} Balance of toAddress：` + new BigNumber(await TOKEN.balanceOf(toAddress)).toFormat())
    console.log(`${tokenName} recharge completed`)
    await callback()
    return amount
}

/**
 * Top up a certain amount of Stg for a certain address(default 10 ** 18)
 */
async function topUpStgByAddress (amount = new BigNumber(10).pow(18), to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[0].address, addresses.STG_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.STG_WHALE_ADDRESS])
    return topUpMain(addresses.STG_ADDRESS, addresses.STG_WHALE_ADDRESS, to, amount)
}
/**
 * Top up a certain amount of DODO for a certain address(default 10 ** 18)
 */
async function topUpDODOByAddress (amount = new BigNumber(10 ** 18), to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[0].address, addresses.DODO_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.DODO_WHALE_ADDRESS])
    return topUpMain(addresses.DODO_ADDRESS, addresses.DODO_WHALE_ADDRESS, to, amount)
}

/**
 * Top up a certain amount of Tusd for a certain address(default 10 ** 6)
 */
async function topUpTusdByAddress (amount = new BigNumber(10).pow(6), toAddress) {
    if (isEmpty(toAddress)) return 0
    const TOKEN = await IEREC20_TUSD.at(addresses.TUSD_ADDRESS)
    const tokenName = await TOKEN.symbol()
    const tokenOwner = "0xA6FA4fB5f76172d178d61B04b0ecd319C5d1C0aa"
    const nextAmount = new BigNumber(amount)
    const nextAmountInHex = web3.utils.padLeft(web3.utils.toHex(amount), 64)
    await sendEthers(tokenOwner)
    console.log(`[Mint]Start recharge ${tokenName}，recharge amount：%s`, nextAmount.toFormat())
    const callback = await impersonates([tokenOwner])
    await TOKEN.deposit(toAddress, nextAmountInHex, {
        from: tokenOwner,
    })
    console.log(`${tokenName} Balance of toAddress：` + new BigNumber(await TOKEN.balanceOf(toAddress)).toFormat())
    console.log(`${tokenName} recharge completed`)
    await callback()
    return amount
}

/**
 * Top up a certain amount of Qi for a certain address(default 10 ** 18)
 */
async function topUpQIByAddress (amount = new BigNumber(10).pow(18), to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[0].address, addresses.QI_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.QI_WHALE_ADDRESS])

    return topUpMain(addresses.QI_ADDRESS, addresses.QI_WHALE_ADDRESS, to, amount)
}

/**
 * Top up a certain amount of GFI for a certain address(default 10 ** 18)
 */
async function topUpGFIByAddress (amount = new BigNumber(10).pow(18), to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[0].address, addresses.GFI_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.GFI_WHALE_ADDRESS])

    return topUpMain(addresses.GFI_ADDRESS, addresses.GFI_WHALE_ADDRESS, to, amount)
}

/**
 * Top up a certain amount of QUICK for a certain address(default 10 ** 18)
 */
async function topUpQUICKByAddress (amount = new BigNumber(10).pow(18), to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[0].address, addresses.QUICK_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.QUICK_WHALE_ADDRESS])

    return topUpMain(addresses.QUICK_ADDRESS, addresses.QUICK_WHALE_ADDRESS, to, amount)
}

/**
 * Top up a certain amount of MAI for a certain address(default 10 ** 18)
 */
async function topUpMaiByAddress (amount = new BigNumber(10).pow(18), to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[0].address, addresses.MAI_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.MAI_WHALE_ADDRESS])
    return topUpMain(addresses.MAI_ADDRESS, addresses.MAI_WHALE_ADDRESS, to, amount)
}

/**
 * Top up a certain amount of UST for a certain address(default 10 ** 18)
 */
async function topUpUstByAddress (amount = new BigNumber(10).pow(18), to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[0].address, addresses.UST_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.UST_WHALE_ADDRESS])
    return topUpMain(addresses.UST_ADDRESS, addresses.UST_WHALE_ADDRESS, to, amount)
}

/**
 * Top up a certain amount of BOND for a certain address
 */
async function topUpBOND (amount, to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[16].address, addresses.BOND_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.BOND_WHALE_ADDRESS])
    return topUpMain(addresses.BOND_ADDRESS, addresses.BOND_WHALE_ADDRESS, to, amount)
}

/**
 * Top up a certain amount of STAKE_AAVE for a certain address
 */
async function topUpStkAave (amount, to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[16].address, addresses.STAKE_AAVE_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.STAKE_AAVE_WHALE_ADDRESS])
    return topUpMain(addresses.STAKE_AAVE_ADDRESS, addresses.STAKE_AAVE_WHALE_ADDRESS, to, amount)
}

/**
 * Top up a certain amount of WMATIC for a certain address(default 10 ** 18)
 */
async function topUpWmaticByAddress (amount = new BigNumber(10).pow(18), to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[0].address, addresses.WMATIC_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.WMATIC_WHALE_ADDRESS])
    return topUpMain(addresses.WMATIC_ADDRESS, addresses.WMATIC_WHALE_ADDRESS, to, amount)
}

/**
 * Top up a certain amount of CRV for a certain address(default 10 ** 18)
 */
async function topUpCrvByAddress (amount = new BigNumber(10).pow(18), to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[0].address, addresses.CRV_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.CRV_WHALE_ADDRESS])
    return topUpMain(addresses.CRV_ADDRESS, addresses.CRV_WHALE_ADDRESS, to, amount)
}

/**
 * Top up a certain amount of DQUICK for a certain address(default 10 ** 18)
 */
async function topUpDquickByAddress (amount = new BigNumber(10).pow(18), to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[0].address, addresses.DQUICK_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.DQUICK_WHALE_ADDRESS])
    return topUpMain(addresses.DQUICK_ADDRESS, addresses.DQUICK_WHALE_ADDRESS, to, amount)
}

/**
 * Top up a certain amount of SUSHI for a certain address(default 10 ** 18)
 */
async function topUpSushiByAddress (amount = new BigNumber(10).pow(18), to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[0].address, addresses.SUSHI_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.SUSHI_WHALE_ADDRESS])
    return topUpMain(addresses.SUSHI_ADDRESS, addresses.SUSHI_WHALE_ADDRESS, to, amount)
}

/**
 * Top up a certain amount of BAL for a certain address(default 10 ** 18)
 */
async function topUpBalByAddress (amount = new BigNumber(10).pow(18), to) {
    if (isEmpty(to)) return 0
    const accounts = await ethers.getSigners()
    // Send 10 ETH to the wallet account to make sure the transaction of withdrawing money from it works.
    await send.ether(accounts[0].address, addresses.BAL_WHALE_ADDRESS, 10 * 10 ** 18)
    await impersonates([addresses.BAL_WHALE_ADDRESS])
    return topUpMain(addresses.BAL_ADDRESS, addresses.BAL_WHALE_ADDRESS, to, amount)
}

/**
 * tranfer Back Usdt
 * @param {*} address
 */
const tranferBackUsdt = async address => {
    const underlying = await IERC20Metadata.at(addresses.USDT_ADDRESS)
    const tokenName = await underlying.name()
    const underlyingWhale = addresses.USDT_WHALE_ADDRESS
    await impersonates([underlyingWhale])
    const farmerBalance = await underlying.balanceOf(address)
    await underlying.transfer(underlyingWhale, farmerBalance, {
        from: address,
    })
    console.log(
        `${tokenName} balance of the whale：` +
            new BigNumber(await underlying.balanceOf(underlyingWhale)).toFormat(),
    )
}

/**
 * tranfer Back Usdc
 * @param {*} address
 */
const tranferBackUsdc = async address => {
    const underlying = await IERC20Metadata.at(addresses.USDC_ADDRESS)
    const tokenName = await underlying.name()
    const underlyingWhale = addresses.USDC_WHALE_ADDRESS
    await impersonates([underlyingWhale])
    const farmerBalance = await underlying.balanceOf(address)
    await underlying.transfer(underlyingWhale, farmerBalance, {
        from: address,
    })
    console.log(
        `${tokenName} balance of the whale：` +
            new BigNumber(await underlying.balanceOf(underlyingWhale)).toFormat(),
    )
}

/**
 * tranfer Back DAI
 * @param {*} address
 */
const tranferBackDai = async address => {
    const underlying = await IERC20Metadata.at(addresses.DAI_ADDRESS)
    const tokenName = await underlying.name()
    const underlyingWhale = addresses.DAI_WHALE_ADDRESS
    await impersonates([underlyingWhale])
    const farmerBalance = await underlying.balanceOf(address)
    await underlying.transfer(underlyingWhale, farmerBalance, {
        from: address,
    })
    console.log(
        `${tokenName} balance of the whale：` +
            new BigNumber(await underlying.balanceOf(underlyingWhale)).toFormat(),
    )
}

module.exports = {
    topUpMain,
    topUpUsdtByAddress,
    topUpDaiByAddress,
    topUpUsdcByAddress,
    topUpTusdByAddress,
    topUpQIByAddress,
    topUpMaiByAddress,
    topUpUstByAddress,
    topUpGFIByAddress,
    topUpWmaticByAddress,
    topUpCrvByAddress,
    topUpDquickByAddress,
    topUpSushiByAddress,
    topUpQUICKByAddress,
    topUpBalByAddress,
    tranferBackUsdt,
    tranferBackUsdc,
    tranferBackDai,
    topUpStgByAddress,
    topUpDODOByAddress,
    impersonates,
}

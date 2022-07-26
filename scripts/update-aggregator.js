const {
    CHAINLINK
} = require("../config/mainnet-fork-test-config")
const {
    impersonates
} = require('../utils/contract-utils')
const {
    send
} = require('@openzeppelin/test-helpers')

const Vault = hre.artifacts.require('IVault')
const ValueInterpreter = hre.artifacts.require('ValueInterpreter')
const ChainlinkPriceFeed = hre.artifacts.require('ChainlinkPriceFeed')

const admin = '0xc791B4A9B10b1bDb5FBE2614d389f0FE92105279'
const vaultAddr = '0xd3feAe6c4fdfDE73Bd2fE99c8fE6944904DAA68A'

const main = async () => {
    let vault
    let valueInterpreter
    let chainlinkPriceFeed

    vault = await Vault.at(vaultAddr);
    const valueInterpreterAddr = await vault.valueInterpreter()
    valueInterpreter = await ValueInterpreter.at(valueInterpreterAddr)
    const chainlinkPriceFeedAddr = await valueInterpreter.getPrimitivePriceFeed()

    chainlinkPriceFeed = await ChainlinkPriceFeed.at(chainlinkPriceFeedAddr)
    
    await impersonates([admin])
    const accounts = await ethers.getSigners()
    const nextManagement = accounts[0].address
    await send.ether(nextManagement, admin, 10 * (10 ** 18))
    
    let primitives = []
    let aggregators = []
    let heartbeats = []

    for (const key in CHAINLINK.aggregators) {
        if (Object.hasOwnProperty.call(CHAINLINK.aggregators, key)) {
            const aggregator = CHAINLINK.aggregators[key]
            if (await chainlinkPriceFeed.isSupportedAsset(aggregator.primitive)) {
                primitives.push(aggregator.primitive)
                aggregators.push(aggregator.aggregator)
                heartbeats.push(60 * 60 * 24 * 365)
                console.log(`will update ${aggregator.primitive} aggregator`)
            }
        }
    }
    
    await chainlinkPriceFeed.updatePrimitives(primitives, aggregators, heartbeats, {
        from: admin
    })
    
    console.log('update aggregator successfully')
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
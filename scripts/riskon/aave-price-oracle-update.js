const MockAavePriceOracleConsumer = hre.artifacts.require('MockAavePriceOracleConsumer');
const ILendingPoolAddressesProvider = hre.artifacts.require('ILendingPoolAddressesProvider');
const BigNumber = require('bignumber.js');
const {
    impersonates
} = require('../../utils/top-up-utils');

const {
    WETH_ADDRESS
} = require('../../config/mainnet-fork-test-config');

const main = async () => {
    const network = hre.network.name;
    console.log('\n\n 📡 mock aave price oracle ... At %s Network \n', network);

    const addressesProvider = await ILendingPoolAddressesProvider.at('0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb');
    const originPriceOracleConsumer = await MockAavePriceOracleConsumer.at(await addressesProvider.getPriceOracle());

    console.log('WETH change before: %d', new BigNumber(await originPriceOracleConsumer.getAssetPrice(WETH_ADDRESS)).toFixed());
    await originPriceOracleConsumer.setAssetPrice(WETH_ADDRESS, await originPriceOracleConsumer.getAssetPrice(WETH_ADDRESS) * 2);
    console.log('WETH change after: %d', new BigNumber(await originPriceOracleConsumer.getAssetPrice(WETH_ADDRESS)).toFixed());
};

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });

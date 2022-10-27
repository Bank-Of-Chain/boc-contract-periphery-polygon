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

    const mockPriceOracle = await MockAavePriceOracleConsumer.new();
    console.log('mockPriceOracle address: %s', mockPriceOracle.address);

    const addressesProvider = await ILendingPoolAddressesProvider.at('0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb');
    const addressPrividerOwner = '0xdc9A35B16DB4e126cFeDC41322b3a36454B1F772';
    await impersonates([addressPrividerOwner]);

    const originPriceOracleConsumer = await MockAavePriceOracleConsumer.at(await addressesProvider.getPriceOracle());
    console.log('WETH price: %d', new BigNumber(await originPriceOracleConsumer.getAssetPrice(WETH_ADDRESS)).toFixed());

    await sendEthers(addressPrividerOwner);
    await addressesProvider.setPriceOracle(mockPriceOracle.address, {from: addressPrividerOwner});
    console.log('addressesProvider priceOracle: %s', await addressesProvider.getPriceOracle());
};

const sendEthers = async (reviver, amount = new BigNumber(10).pow(18).multipliedBy(10)) => {
    if (!BigNumber.isBigNumber(amount)) return new Error("must be a bignumber object")
    await network.provider.send("hardhat_setBalance", [reviver, `0x${amount.toString(16)}`])
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });

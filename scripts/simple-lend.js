const { default: BigNumber } = require('bignumber.js');

const {
    topUpUsdtByAddress,
    topUpUsdcByAddress,
    topUpDaiByAddress
} = require('../utils/top-up-utils');

const IVault = hre.artifacts.require('boc-contract-core/contracts/vault/IVault.sol:IVault');
const IStrategy = hre.artifacts.require('IStrategy');
const ERC20 = hre.artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20');

const {
    USDT_ADDRESS,
    USDC_ADDRESS,
    DAI_ADDRESS,
} = require('../config/mainnet-fork-test-config');
const vaultAddress = '0x5416adf327242B7224413Dcd6E454FfcB5C1e73C';
const strategyAddresses = [
    // QUICK
    '0x9Be48cB9Eb443E850316DD09cdF1c2E150b09245',
    // SUSHI
    '0xC0939333007bD49D9f454dc81B4429740A74E475',
];

const main = async () => {
    const network = hre.network.name;
    console.log('\n\n 📡 simple lend ... At %s Network \n', network);
    if (network !== 'localhost') {
        return;
    }

    const accounts = await ethers.getSigners();
    const investor = accounts[0].address;

    // top up
    const usdtAmount = new BigNumber(100_000 * 10 ** 6);
    await topUpUsdtByAddress(usdtAmount, investor);
    const usdcAmount = new BigNumber(100_000 * 10 ** 6);
    await topUpUsdcByAddress(usdcAmount, investor);
    const daiAmount = new BigNumber(100_000 * 10 ** 18);
    await topUpDaiByAddress(daiAmount, investor);
    console.log(`top up successfully`);

    // approve
    const usdtContract = await ERC20.at(USDT_ADDRESS);
    await usdtContract.approve(vaultAddress, usdtAmount);
    const usdcContract = await ERC20.at(USDC_ADDRESS);
    await usdcContract.approve(vaultAddress, usdcAmount);
    const daiContract = await ERC20.at(DAI_ADDRESS);
    await daiContract.approve(vaultAddress, daiAmount);
    console.log(`approve successfully`);

    // invest
    const vault = await IVault.at(vaultAddress);
    await vault.mint(
        [USDT_ADDRESS, USDC_ADDRESS, DAI_ADDRESS],
        [usdtAmount, usdcAmount, daiAmount],
        0, {
        from: investor
    });
    console.log(`invest vault ${vaultAddress} successfully`);

    // lend
    // TODO: there are some errors while lending DAI
    let amountPerToken = new BigNumber(10_000);
    for(let i = 0; i < strategyAddresses.length; i++) {
        let strategyAddress = strategyAddresses[i];
        const strategy = await IStrategy.at(strategyAddress);

        let exchangeTokens = [];
        const wantsInfo = await strategy.getWantsInfo();
        for (let j = 0; j < wantsInfo._assets.length; j++) {
            const asset = wantsInfo._assets[j];
            const assetContract = await ERC20.at(asset);
            const precision = 10 ** (await assetContract.decimals());
            exchangeTokens.push({
                fromToken: asset,
                toToken: asset,
                fromAmount: (amountPerToken.multipliedBy(precision)).toString(),
                exchangeParam: {
                    platform: '0x0000000000000000000000000000000000000000',
                    method: 0,
                    encodeExchangeArgs: '0x',
                    slippage: 0,
                    oracleAdditionalSlippage: 0,
                }
            });
        }

        await vault.lend(strategyAddress, exchangeTokens);
        console.log(`invest strategy ${strategyAddress} successfully`);
    }
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
const BigNumber = require('bignumber.js');
const {
    ethers,
} = require('hardhat');
const {
    getStrategyDetails,
} = require('../../../utils/strategy-utils');
const {set} = require('lodash');
const {
    depositVault,
} = require("../../../utils/vault-utils");
const {
    setupCoreProtocol,
} = require('../../../utils/contract-utils');
const {
    topUpUsdtByAddress,
    tranferBackUsdt,
} = require('../../../utils/top-up-utils');
const {
    lend,
} = require('../../../utils/vault-utils');
const IStrategy = hre.artifacts.require('IStrategy');

// === Constants === //
const MFC = require('../../../config/mainnet-fork-test-config');

describe('strategy estimate gas', function () {
    const depositAmount = new BigNumber(1000000 * 10 ** 6);
    const lendStrategyAmount = new BigNumber(10000 * 10 ** 6);

    // parties in the protocol
    let accounts;
    let governance;
    let farmer1;
    let keeper;

    // Core protocol contracts
    let vault;
    let underlying;
    let valueInterpreter;
    let exchangePlatformAdapters;
    let addToVaultStrategies;

    before(async function () {
        await ethers.getSigners().then((resp) => {
            accounts = resp;
            governance = accounts[0].address;
            farmer1 = accounts[1].address;
            keeper = accounts[19].address;
        });
        await topUpUsdtByAddress(depositAmount, farmer1);
        await setupCoreProtocol(MFC.USDT_ADDRESS, governance, keeper).then((resp) => {
            vault = resp.vault;
            underlying = resp.underlying;
            valueInterpreter = resp.valueInterpreter;
            exchangePlatformAdapters = resp.exchangePlatformAdapters;
            addToVaultStrategies = resp.addToVaultStrategies;
        });
    });

    after(async function () {
        await tranferBackUsdt(farmer1);
    });

    it('deposit to vault', async function () {
        await depositVault(farmer1, underlying, vault, depositAmount);
    });

    it('strategy redeem from vault', async function () {
        const {result} = await getStrategyDetails(vault.address);
        let gasInfos = {};
        for (let strategy of result) {
            const strategyAddress = strategy.address;
            console.log('lend to strategy %s %d', strategy.name, lendStrategyAmount);
            let tx = await lend(strategyAddress, vault.address, lendStrategyAmount.toFixed(), exchangePlatformAdapters);
            const lendGas = tx.receipt.gasUsed * 1.5;

            const totalDebt = (await vault.strategies(strategy.address)).totalDebt;
            console.log('redeem from strategy %s %d', strategy.name, totalDebt);
            tx = await vault.redeem(strategyAddress, totalDebt);
            const redeemGas = tx.receipt.gasUsed * 1.5;

            gasInfos[strategy.address] = {
                name: strategy.name,
                redeemGas: redeemGas,
                lendGas: lendGas
            }

            // uniswap v3 harvest gas will not change
            if (strategy.name.indexOf('UniswapV3') !== -1) {
                let strategyC = await IStrategy.at(strategyAddress);
                tx = await strategyC.harvest();
                const harvestGas = tx.receipt.gasUsed * 1.5;
                set(gasInfos[strategy.address], 'harvestGas', harvestGas);
            }

            console.log(gasInfos);
        }
        console.log(gasInfos);
    });

});

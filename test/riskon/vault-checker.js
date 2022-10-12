const {default: BigNumber} = require('bignumber.js');
const {ethers} = require('hardhat');
const {assert} = require('chai');

const MFC = require('../../config/mainnet-fork-test-config');
const addressConfig = require('../../config/address-config');

const topUp = require('../../utils/top-up-utils');
const {advanceBlock} = require('../../utils/block-utils');

const ERC20 = hre.artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20');
const AccessControlProxy = hre.artifacts.require('AccessControlProxy');
const ChainlinkPriceFeed = hre.artifacts.require('ChainlinkPriceFeed');
const AggregatedDerivativePriceFeed = hre.artifacts.require('AggregatedDerivativePriceFeed');
const ValueInterpreter = hre.artifacts.require('ValueInterpreter');
const UniswapV3UsdcWeth500RiskOnVault = hre.artifacts.require('UniswapV3UsdcWeth500RiskOnVault');
const UniswapV3RiskOnHelper = hre.artifacts.require('UniswapV3RiskOnHelper');
const MockUniswapV3Router = hre.artifacts.require('MockUniswapV3Router');

let accessControlProxy;
let valueInterpreter;
let uniswapV3UsdcWeth500RiskOnVault;
let uniswapV3RiskOnHelper;
let mockUniswapV3Router;

let governance;
let investor;
let owner;
let keeper;

async function _initPriceFeed() {
    const primitives = new Array();
    const aggregators = new Array();
    const heartbeats = new Array();
    const rateAssets = new Array();
    for (const key in MFC.CHAINLINK.aggregators) {
        const value = MFC.CHAINLINK.aggregators[key];
        primitives.push(value.primitive);
        aggregators.push(value.aggregator);
        heartbeats.push(value.heartbeat);
        rateAssets.push(value.rateAsset);
    }
    const basePeggedPrimitives = new Array();
    const basePeggedRateAssets = new Array();
    for (const key in MFC.CHAINLINK.basePegged) {
        const value = MFC.CHAINLINK.basePegged[key];
        basePeggedPrimitives.push(value.primitive);
        basePeggedRateAssets.push(value.rateAsset);
    }
    const chainlinkPriceFeed = await ChainlinkPriceFeed.new(MFC.CHAINLINK.ETH_USD_AGGREGATOR, MFC.CHAINLINK.ETH_USD_HEARTBEAT, primitives, aggregators, heartbeats, rateAssets, basePeggedPrimitives, basePeggedRateAssets, accessControlProxy.address);
    let derivatives = new Array();
    const priceFeeds = new Array();
    const aggregatedDerivativePriceFeed = await AggregatedDerivativePriceFeed.new(derivatives, priceFeeds, accessControlProxy.address);
    valueInterpreter = await ValueInterpreter.new(chainlinkPriceFeed.address, aggregatedDerivativePriceFeed.address, accessControlProxy.address);
}

function contains(arr, obj) {
    let i = arr.length;
    while (i--) {
        if (arr[i].toLowerCase() === obj.toLowerCase()) {
            return true;
        }
    }
    return false;
}

async function getTokenPrecision(address) {
    const erc20Contract = await ERC20.at(address);
    return new BigNumber(10 ** await erc20Contract.decimals());
}

async function _topUpFamilyBucket() {
    const wantToken = await uniswapV3UsdcWeth500RiskOnVault.wantToken();
    console.log('wantToken:', wantToken);
    if (wantToken === MFC.USDC_ADDRESS) {
        console.log('top up USDC');
        await topUp.topUpUsdcByAddress(
            (await getTokenPrecision(MFC.USDC_ADDRESS)).multipliedBy(1e7),
            investor
        );
    }
    console.log('topUp finish!');
}

async function check(vaultName, callback, exchangeRewardTokenCallback, uniswapV3RebalanceCallback) {
    before(async function () {
        accounts = await ethers.getSigners();
        governance = accounts[0].address;
        investor = accounts[1].address;
        owner = accounts[2].address;
        keeper = accounts[19].address;

        accessControlProxy = await AccessControlProxy.new();
        await accessControlProxy.initialize(governance, governance, governance, keeper);
        // init priceFeed
        await _initPriceFeed();
        // init uniswapV3RiskOnHelper
        uniswapV3RiskOnHelper = await UniswapV3RiskOnHelper.new();
        // init uniswapV3UsdcWeth500RiskOnVault
        uniswapV3UsdcWeth500RiskOnVault = await UniswapV3UsdcWeth500RiskOnVault.new();
        uniswapV3UsdcWeth500RiskOnVault.initialize(investor, MFC.USDC_ADDRESS, uniswapV3RiskOnHelper.address, valueInterpreter.address);
        console.log('uniswapV3UsdcWeth500RiskOnVault address: %s', uniswapV3UsdcWeth500RiskOnVault.address);
        // init mockUniswapV3Router
        mockUniswapV3Router = await MockUniswapV3Router.new();
        // top up
        await _topUpFamilyBucket();
    });

    it('[vault name should match the file name]', async function () {
        const name = await uniswapV3UsdcWeth500RiskOnVault.name();
        console.log("name: %s, vaultName: %s", name, vaultName);
        assert.deepEqual(name, vaultName, 'vault name do not match the file name');
    });

    let wantToken;
    it('[wantToken]', async function () {
        wantToken = await uniswapV3UsdcWeth500RiskOnVault.wantToken();
        console.log("wantToken: %s", wantToken);
        assert(wantToken === MFC.USDC_ADDRESS, 'wantToken');
    });

    let wantTokenContract;
    let wantTokenDecimals;
    let depositedAmount;
    it('[estimatedTotalAssets = transferred tokens value]', async function () {
        wantTokenContract = await ERC20.at(wantToken);
        wantTokenDecimals = new BigNumber(10 ** (await wantTokenContract.decimals()));
        let initialAmount = new BigNumber(10000);
        depositedAmount = initialAmount.multipliedBy(wantTokenDecimals);
        console.log('Lend: wantToken: %s, depositedAmount: %d', wantToken, depositedAmount);

        await wantTokenContract.approve(uniswapV3UsdcWeth500RiskOnVault.address, 0, {from: investor})
        await wantTokenContract.approve(uniswapV3UsdcWeth500RiskOnVault.address, depositedAmount, {from: investor})
        await uniswapV3UsdcWeth500RiskOnVault.lend(depositedAmount, {from: investor});
        // await advanceBlock(1);
        const estimatedTotalAssets = new BigNumber(await uniswapV3UsdcWeth500RiskOnVault.estimatedTotalAssets());
        depositedAmount = depositedAmount;
        let delta = depositedAmount.minus(estimatedTotalAssets);
        console.log('depositedAmount: %d, estimatedTotalAssets: %d, delta: %d', depositedAmount, estimatedTotalAssets, delta);
        assert(delta.abs().isLessThan(depositedAmount.multipliedBy(3).dividedBy(10 ** 4)), 'estimatedTotalAssets does not match depositedAmount value');
    });

    let borrowToken;
    it('[the coins balance of vault should be zero]', async function () {
        let wantTokenContract = await ERC20.at(wantToken);
        let wantTokenBalance = await wantTokenContract.balanceOf(uniswapV3UsdcWeth500RiskOnVault.address);
        borrowToken = await uniswapV3UsdcWeth500RiskOnVault.borrowToken();
        let borrowTokenContract = await ERC20.at(borrowToken);
        let borrowTokenBalance = await borrowTokenContract.balanceOf(uniswapV3UsdcWeth500RiskOnVault.address);
        console.log('wantTokenBalance: %d, borrowTokenBalance: %d', wantTokenBalance, borrowTokenBalance);
        assert(wantTokenBalance.eq(0) && borrowTokenBalance.eq(0), 'there are some coins left in vault');
    });

    let pendingRewards;
    let produceReward = false;
    // it('[totalAssets should increase after 3 days]', async function () {
    //     const beforeTotalAssets = new BigNumber(await uniswapV3UsdcWeth500RiskOnVault.estimatedTotalAssets());
    //     if (callback) {
    //         await callback(uniswapV3UsdcWeth500RiskOnVault.address, keeper);
    //     }
    //     await advanceBlock(3);
    //     pendingRewards = await uniswapV3UsdcWeth500RiskOnVault.harvest.call({from: keeper});
    //     await uniswapV3UsdcWeth500RiskOnVault.harvest({from: keeper});
    //     const rewardsTokens = pendingRewards._rewardsTokens;
    //     for (let i = 0; i < rewardsTokens.length; i++) {
    //         const rewardToken = rewardsTokens[i];
    //         let rewardTokenContract = await ERC20.at(rewardToken);
    //         let rewardTokenBalance = await rewardTokenContract.balanceOf(harvester);
    //         if (rewardTokenBalance > 0) {
    //             produceReward = true;
    //         }
    //     }
    //     const afterTotalAssets = new BigNumber(await uniswapV3UsdcWeth500RiskOnVault.estimatedTotalAssets());
    //     console.log('beforeTotalAssets: %s, afterTotalAssets: %s, produceReward: %s', beforeTotalAssets.toFixed(), afterTotalAssets.toFixed(), produceReward);
    //     assert(afterTotalAssets.isGreaterThan(beforeTotalAssets) || produceReward, 'there is no profit after 3 days');
    // });
    //
    // if (uniswapV3RebalanceCallback) {
    //     it('[UniswapV3 rebalance]', async function () {
    //         await uniswapV3RebalanceCallback(uniswapV3UsdcWeth500RiskOnVault.address);
    //     });
    // }

    it('[estimatedTotalAssets should be 0 after withdraw all assets]', async function () {
        const estimatedTotalAssetsBefore = new BigNumber(await uniswapV3UsdcWeth500RiskOnVault.estimatedTotalAssets());
        await uniswapV3UsdcWeth500RiskOnVault.redeem(estimatedTotalAssetsBefore, estimatedTotalAssetsBefore, {from: investor});
        const estimatedTotalAssetsAfter = new BigNumber(await uniswapV3UsdcWeth500RiskOnVault.estimatedTotalAssets()).dividedBy(10 ** 18);
        console.log('After withdraw all shares,strategy assets: %d', estimatedTotalAssetsAfter);
        assert.isTrue(estimatedTotalAssetsAfter.multipliedBy(10000).isLessThan(depositedAmount), 'assets left in strategy should not be more than 1/10000');
    });
}

module.exports = {
    check
};

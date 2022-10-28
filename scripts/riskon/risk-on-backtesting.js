const axios = require("axios");
const lodash = require("lodash");
const {default: BigNumber} = require("bignumber.js");

const UniswapV3Pool = hre.artifacts.require("@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol");
const MockAavePriceOracleConsumer = hre.artifacts.require('MockAavePriceOracleConsumer');
const ILendingPoolAddressesProvider = hre.artifacts.require('ILendingPoolAddressesProvider');
const VaultFactory = hre.artifacts.require('VaultFactory.sol');
const RiskOnVault = hre.artifacts.require('UniswapV3UsdcWeth500RiskOnVault.sol');
const RiskOnHelper = hre.artifacts.require('UniswapV3RiskOnHelper.sol');
const MockUniswapV3Router = hre.artifacts.require('MockUniswapV3Router.sol');
const ERC20 = hre.artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20');

const address = require("../../config/address-config");
const topUp = require("../../utils/top-up-utils");
const {advanceBlock} = require("../../utils/block-utils");

const main = async () => {
    // init
    const dateBlockNumbers = [34476479, 34515959, 34556035, 34596552, 34637514];
    const accounts = await ethers.getSigners();
    const investor = accounts[10].address;
    const uniswapV3Mocker = accounts[11].address;
    const keeper = accounts[18].address;

    const ethVault = false;
    const poolAddress = "0x45dDa9cb7c25131DF268515131f647d726f50608";
    const riskOnHelperAddress = "0x3bB1490Ad830a59A7cFEe00Bf1ac65074Cc91f02";
    const riskOnVaultBaseAddress = "0x9c63D17213A5D6FCf1c7750Fa4F2567Ea088257C";
    const vaultFactoryAddress = "0x36036E1cEcb8ad353bFcbA7b9B6d9919E0F52d65";

    const uniswapV3Pool = await UniswapV3Pool.at(poolAddress);
    const token0Address = await uniswapV3Pool.token0();
    const token1Address = await uniswapV3Pool.token1();
    const token0 = await ERC20.at(token0Address);
    const token1 = await ERC20.at(token1Address);
    const token0Decimals = await token0.decimals();
    const token1Decimals = await token1.decimals();

    await uniswapV3Pool.increaseObservationCardinalityNext(360);

    const addressProvider = await ILendingPoolAddressesProvider.at('0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb');
    const originPriceOracleConsumer = await MockAavePriceOracleConsumer.at(await addressProvider.getPriceOracle());
    console.log('WETH price: %s', await originPriceOracleConsumer.getAssetPrice(address.WETH_ADDRESS));
    console.log('USDC price: %s', await originPriceOracleConsumer.getAssetPrice(address.USDC_ADDRESS));

    const mockUniswapV3Router = await MockUniswapV3Router.new();
    const riskOnHelper = await RiskOnHelper.at(riskOnHelperAddress);

    let riskOnVault;

    // invest
    await invest(ethVault);

    // topUp & approve
    await topUpAndApprove();

    // start data back to test
    let count = 0;
    for (let i = 0; i < dateBlockNumbers.length; i++) {
        let twap = await riskOnHelper.getTwap(poolAddress, 60);
        console.log("=== strategyHarvest twap: %d, assetPrice: %d ===", twap, new BigNumber(1e20 / Math.pow(1.0001, twap)).toFixed(0, 1));
        await eventsTracing(dateBlockNumbers[i], dateBlockNumbers[i + 1]);
        console.log(`=== blockNumberStart: ${dateBlockNumbers[i]}, blockNumberEnd: ${dateBlockNumbers[i + 1]} eventsTracing end ===`);
        await advanceBlock(1);
        console.log("======== getBlockNumber: %d ========", await ethers.provider.getBlockNumber());
        let estimatedTotalAssets = await riskOnVault.estimatedTotalAssets();
        console.log("=== strategyHarvest before strategy.estimatedTotalAssets: %d ===", estimatedTotalAssets);
        await strategyHarvest();
        estimatedTotalAssets = await riskOnVault.estimatedTotalAssets();
        console.log("=== strategyHarvest after strategy.estimatedTotalAssets: %d ===", estimatedTotalAssets);
        twap = await riskOnHelper.getTwap(poolAddress, 60);
        console.log("=== strategyHarvest twap: %d, assetPrice: %d ===", twap, new BigNumber(1e20 / Math.pow(1.0001, twap)).toFixed(0, 1));
        await originPriceOracleConsumer.setAssetPrice(address.WETH_ADDRESS, new BigNumber(1e20 / Math.pow(1.0001, twap)).toFixed(0, 1));
        await strategyBorrowRebalance();
        await strategyRebalance();
        estimatedTotalAssets = await riskOnVault.estimatedTotalAssets();
        console.log("=== strategyRebalance after strategy.estimatedTotalAssets: %d ===", estimatedTotalAssets);
        console.log("======== getBlockNumber: %d ========", await ethers.provider.getBlockNumber());
        return;
    }

    async function eventsTracing(blockNumberStart, blockNumberEnd) {
        // get events
        const eventsRes = await axios.get(`http://192.168.75.35:8081/event_log?chain_id=137&offset=0&limit=1000000&block_number_start=${blockNumberStart}&block_number_end=${blockNumberEnd}&event_name=Swap,Mint,Burn,Collect`);
        const events = eventsRes.data.records;
        if (lodash.isEmpty(events)) {
            return;
        }

        let swapEventDatas = [];
        for (let i = 0; i < events.length; i++) {
//            console.log('=== blockNumber: ===', events[i].blockNumber);
            const eventData = events[i].data;
            try {
                switch (events[i].eventName) {
                    case "Swap":
                        swapEventDatas.push(eventData);
                        break;
                    case "Mint":
                        if (swapEventDatas.length > 0) {
                            await batchSwapRetry(swapEventDatas);
                            swapEventDatas = [];
                        }
                        await mintRetry(eventData.owner, eventData.tickLower, eventData.tickUpper, new BigNumber(eventData.amount0), new BigNumber(eventData.amount1), new BigNumber(eventData.amount));
                        break;
                    case "Burn":
                        if (swapEventDatas.length > 0) {
                            await batchSwapRetry(swapEventDatas);
                            swapEventDatas = [];
                        }
                        await burnRetry(eventData.owner, eventData.tickLower, eventData.tickUpper, new BigNumber(eventData.amount), new BigNumber(eventData.amount0), new BigNumber(eventData.amount1));
                        break;
                    case "Collect":
                        if (swapEventDatas.length > 0) {
                            await batchSwapRetry(swapEventDatas);
                            swapEventDatas = [];
                        }
                        await collectRetry(eventData.owner, eventData.tickLower, eventData.tickUpper, new BigNumber(eventData.amount0), new BigNumber(eventData.amount1), eventData.recipient);
                        break;
                    default:
                        throw new Error("Unsupported product!");
                }
            } catch (e) {
                console.log("=== switch case error: ===", e);
            }
        }
        if (swapEventDatas.length > 0) {
            await batchSwapRetry(swapEventDatas);
        }
    }

    console.log(`=== while end count: ${count} ===`);

    // end data back to test

    async function mintRetry(ownerAddress, tickLower, tickUpper, amount0, amount1, amount) {
        let count = 0;
        while (true) {
            try {
                await mint(ownerAddress, tickLower, tickUpper, amount0, amount1, amount);
                return;
            } catch (e) {
                count++;
                console.log(`=== mintRetry count: ${count}, ownerAddress: ${ownerAddress}, tickLower: ${tickLower}, tickUpper: ${tickUpper}, amount0: ${amount0}, amount1: ${amount1}, amount: ${amount} ===`);
                console.log("=== mintRetry error: ===", e);
                if (count > 3) {
                    return;
                }
            }
        }
    }

    async function mint(ownerAddress, tickLower, tickUpper, amount0, amount1, amount) {
        let executeAmount0;
        if (amount0.gt(0)) {
            executeAmount0 = amount0.multipliedBy(10);
            await topUpAmount(token0Address, executeAmount0, ownerAddress);
        } else {
            executeAmount0 = new BigNumber(10000).multipliedBy(new BigNumber(10).pow(token0Decimals));
            await topUpAmount(token0Address, executeAmount0, ownerAddress);
        }
        let executeAmount1;
        if (amount1.gt(0)) {
            executeAmount1 = amount1.multipliedBy(10);
            await topUpAmount(token1Address, executeAmount1, ownerAddress);
        } else {
            executeAmount1 = new BigNumber(10).multipliedBy(new BigNumber(10).pow(token1Decimals));
            await topUpAmount(token1Address, executeAmount1, ownerAddress);
        }

        await topUp.sendEthers(ownerAddress);
        const callback = await topUp.impersonates([ownerAddress]);
        await token0.approve(mockUniswapV3Router.address, new BigNumber(0), {"from": ownerAddress});
        await token0.approve(mockUniswapV3Router.address, executeAmount0.multipliedBy(10), {"from": ownerAddress});
        await token1.approve(mockUniswapV3Router.address, new BigNumber(0), {"from": ownerAddress});
        await token1.approve(mockUniswapV3Router.address, executeAmount1.multipliedBy(10), {"from": ownerAddress});
        console.log(`=== mint before amount0: ${amount0}, amount1: ${amount1} ===`);
        console.log(`=== mint before token0.balanceOf: ${await token0.balanceOf(ownerAddress)}, token1.balanceOf: ${await token1.balanceOf(ownerAddress)} ===`);
        await mockUniswapV3Router.mint(poolAddress, tickLower, tickUpper, amount, {"from": ownerAddress});
        console.log(`=== mint after token0.balanceOf: ${await token0.balanceOf(ownerAddress)}, token1.balanceOf: ${await token1.balanceOf(ownerAddress)} ===`);
        await callback();
    }

    async function burnRetry(ownerAddress, tickLower, tickUpper, amount, amount0, amount1) {
        let count = 0;
        while (true) {
            try {
                await burn(ownerAddress, tickLower, tickUpper, amount, amount0, amount1);
                return;
            } catch (e) {
                count++;
                console.log(`=== burnRetry count: ${count}, ownerAddress: ${ownerAddress}, tickLower: ${tickLower}, tickUpper: ${tickUpper}, amount0: ${amount0}, amount1: ${amount1}, amount: ${amount} ===`);
                console.log("=== burnRetry error: ===", e);
                if (count > 3) {
                    return;
                }
            }
        }
    }

    async function burn(ownerAddress, tickLower, tickUpper, amount, amount0, amount1) {
        await topUp.sendEthers(ownerAddress);
        const callback = await topUp.impersonates([ownerAddress]);
        const liquidity = await riskOnVault.getLiquidityForAmounts(tickLower, tickUpper, amount0, amount1);
        if (new BigNumber(liquidity).lt(amount)) {
//            console.log('=== burn before riskOnVault.getLiquidityForAmounts: %d, amount: %d ===', liquidity, amount);
            amount = liquidity;
        }
//        console.log(`=== burn before uniswapV3Pool.liquidity: ${await uniswapV3Pool.liquidity()},  uniswapV3Pool.slot0: ${JSON.stringify(await uniswapV3Pool.slot0())} ===`);
        await uniswapV3Pool.burn(tickLower, tickUpper, amount, {"from": ownerAddress});
//        console.log(`=== burn after uniswapV3Pool.liquidity: ${await uniswapV3Pool.liquidity()},  uniswapV3Pool.slot0: ${JSON.stringify(await uniswapV3Pool.slot0())} ===`);
        await callback();
    }

    async function collectRetry(ownerAddress, tickLower, tickUpper, amount0Requested, amount1Requested, recipient) {
        let count = 0;
        while (true) {
            try {
                await collect(ownerAddress, tickLower, tickUpper, amount0Requested, amount1Requested, recipient);
                return;
            } catch (e) {
                count++;
                console.log(`=== collectRetry count: ${count}, ownerAddress: ${ownerAddress}, tickLower: ${tickLower}, tickUpper: ${tickUpper}, amount0Requested: ${amount0Requested}, amount1Requested: ${amount1Requested}, recipient: ${recipient} ===`);
                console.log("=== collectRetry error: ===", e);
                if (count > 3) {
                    return;
                }
            }
        }
    }

    async function collect(ownerAddress, tickLower, tickUpper, amount0Requested, amount1Requested, recipient) {
        await topUp.sendEthers(ownerAddress);
        const callback = await topUp.impersonates([ownerAddress]);
//        console.log(`=== collect before token0.balanceOf: ${await token0.balanceOf(recipient)}, token1.balanceOf: ${await token1.balanceOf(recipient)} ===`);
        await uniswapV3Pool.collect(recipient, tickLower, tickUpper, amount0Requested, amount1Requested, {"from": ownerAddress});
//        console.log(`=== collect after token0.balanceOf: ${await token0.balanceOf(recipient)}, token1.balanceOf: ${await token1.balanceOf(recipient)} ===`);
        await callback();
    }

    async function batchSwapRetry(swapEventDatas) {
        let count = 0;
        while (true) {
            try {
                await batchSwap(swapEventDatas);
                return;
            } catch (e) {
                count++;
                console.log(`=== batchSwapRetry count: ${count}, swapEventDatas: ${swapEventDatas} ===`);
                console.log("=== batchSwapRetry error: ===", e);
                if (count > 3) {
                    return;
                }
            }
        }
    }

    async function batchSwap(swapEventDatas) {
        let multicallFuns = [];
        for (const swapEvent of swapEventDatas) {
            let amount0 = new BigNumber(swapEvent.amount0);
            let amount1 = new BigNumber(swapEvent.amount1);

            let zeroForOne = true;
            let amountSpecified = amount0;
            if (amount0.lt(0)) {
                zeroForOne = false;
                amountSpecified = amount1;
            }

            if (amountSpecified.eq(0)) {
                continue;
            }

            multicallFuns.push(mockUniswapV3Router.contract.methods.swap(poolAddress, zeroForOne, amountSpecified).encodeABI());
            if (multicallFuns.length >= 150) {
                await mockUniswapV3Router.multicall(multicallFuns, {"from": uniswapV3Mocker});
                multicallFuns = [];
            }
        }
        await mockUniswapV3Router.multicall(multicallFuns, {"from": uniswapV3Mocker});
        console.log(`=== swap before swapEventDatas.length: ${swapEventDatas.length} ===`);
        const slot0 = await uniswapV3Pool.slot0();
        console.log(`=== swap after slot0.tick: ${slot0.tick}, swapEventDatas.amount0: ${new BigNumber(swapEventDatas[swapEventDatas.length - 1].amount0).toFixed()}, swapEventDatas.amount1: ${new BigNumber(swapEventDatas[swapEventDatas.length - 1].amount1).toFixed()} ===`);
    }

    async function invest(ethVault) {
        let wantToken = address.USDC_ADDRESS;
        let investAmount = new BigNumber(10000);
        let vaultFactoryPosition = 1;
        if (ethVault) {
            wantToken = address.WETH_ADDRESS;
            investAmount = new BigNumber(10);
            vaultFactoryPosition = 0;
        }

        // top up
        await topUpAmount(wantToken, investAmount, investor);
        console.log(`=== top up successfully ===`);

        const vaultFactory = await VaultFactory.at(vaultFactoryAddress);
        await vaultFactory.createNewVault(wantToken, riskOnVaultBaseAddress, {from: investor});
        const userVaultAddress = await vaultFactory.vaultAddressMap(investor, riskOnVaultBaseAddress, vaultFactoryPosition);
        console.log(`=== vaultFactory createNewVault successfully, userVaultAddress: %s ===`, userVaultAddress);

        riskOnVault = await RiskOnVault.at(userVaultAddress);
        const wantTokenContract = await ERC20.at(wantToken);
        const wantTokenDecimals = new BigNumber(10 ** (await wantTokenContract.decimals()));
        let wantTokenAmount = investAmount.multipliedBy(wantTokenDecimals);

        await wantTokenContract.approve(userVaultAddress, 0, {from: investor})
        await wantTokenContract.approve(userVaultAddress, wantTokenAmount, {from: investor})
        await riskOnVault.lend(wantTokenAmount, {from: investor});
        console.log(`=== riskOnVault lend successfully, estimatedTotalAssets: %d ===`, new BigNumber(await riskOnVault.estimatedTotalAssets()));
    }

    async function topUpAndApprove() {
        await topUpAmount(token0Address, new BigNumber(10).pow(10).multipliedBy(new BigNumber(10).pow(token0Decimals)), uniswapV3Mocker);
        await token0.approve(mockUniswapV3Router.address, new BigNumber(0), {"from": uniswapV3Mocker});
        await token0.approve(mockUniswapV3Router.address, new BigNumber(10).pow(10).multipliedBy(new BigNumber(10).pow(token0Decimals)), {"from": uniswapV3Mocker});
        await topUpAmount(token1Address, new BigNumber(10).pow(10).multipliedBy(new BigNumber(10).pow(token1Decimals)), uniswapV3Mocker);
        await token1.approve(mockUniswapV3Router.address, new BigNumber(0), {"from": uniswapV3Mocker});
        await token1.approve(mockUniswapV3Router.address, new BigNumber(10).pow(10).multipliedBy(new BigNumber(10).pow(token1Decimals)), {"from": uniswapV3Mocker});
    }

    async function strategyHarvest() {
        console.log(`=== strategyHarvest before token0.balanceOf: ${await token0.balanceOf(riskOnVault.address)}, token1.balanceOf: ${await token1.balanceOf(riskOnVault.address)} ===`);
        await riskOnVault.harvest();
        console.log(`=== strategyHarvest after token0.balanceOf: ${await token0.balanceOf(riskOnVault.address)}, token1.balanceOf: ${await token1.balanceOf(riskOnVault.address)} ===`);
    }

    async function strategyBorrowRebalance() {
        console.log(`=== strategyBorrowRebalance before token0.balanceOf: ${await token0.balanceOf(riskOnVault.address)}, token1.balanceOf: ${await token1.balanceOf(riskOnVault.address)} ===`);
        await riskOnVault.borrowRebalance({"from": keeper});
        console.log(`=== strategyBorrowRebalance after token0.balanceOf: ${await token0.balanceOf(riskOnVault.address)}, token1.balanceOf: ${await token1.balanceOf(riskOnVault.address)} ===`);
    }

    async function strategyRebalance() {
        const slot0 = await uniswapV3Pool.slot0();
        console.log(`=== rebalance slot0.tick: ${slot0.tick} ===`);
        const currentTick = slot0.tick;
        const shouldRebalance = await riskOnVault.shouldRebalance(currentTick);
        if (shouldRebalance) {
            console.log(`=== rebalanceByKeeper before riskOnVault.getMintInfo: ${JSON.stringify(await riskOnVault.getMintInfo())} ===`);
            await riskOnVault.rebalanceByKeeper({"from": keeper});
            console.log(`=== rebalanceByKeeper after riskOnVault.getMintInfo: ${JSON.stringify(await riskOnVault.getMintInfo())} ===`);
        }
    }

    async function topUpAmount(tokenAddress, tokenAmount, topUpTo) {
        let token;
        let tokenDecimals;
        switch (tokenAddress) {
            case address.USDC_ADDRESS:
                // console.log('top up USDC');
                token = await ERC20.at(address.USDC_ADDRESS);
                tokenDecimals = await token.decimals();
                await topUp.topUpUsdcByAddress(tokenAmount * 10 ** tokenDecimals, topUpTo);
                break;
            case address.WETH_ADDRESS:
                // console.log('top up WETH');
                token = await ERC20.at(address.WETH_ADDRESS);
                tokenDecimals = await token.decimals();
                await topUp.topUpWethByAddress(tokenAmount * 10 ** tokenDecimals, topUpTo);
                break;
            default:
                throw new Error('Unsupported token!');
        }
    }
};

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });

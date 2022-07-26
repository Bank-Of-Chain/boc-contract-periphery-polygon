/**
 * swap validation:
 */
const {
    topUpDaiByAddress,
    topUpSushiByAddress,
    topUpUsdcByAddress,
    topUpCrvByAddress,
    topUpStgByAddress,
    topUpDODOByAddress
} = require('../../utils/top-up-utils');
const {
    getOneInchV4SwapInfo,
    getParaSwapSwapInfo,
    getBestSwapInfo
} = require('piggy-finance-utils');
const BigNumber = require('bignumber.js');
const {
    ethers,
} = require('hardhat');
const Utils = require('../../utils/assert-utils');

// === Constants === //
const MFC = require('../../config/mainnet-fork-test-config');
const ERC20 = hre.artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20');
const ExchangeAggregator = hre.artifacts.require("ExchangeAggregator");
const ParaSwapV5Adapter = hre.artifacts.require("ParaSwapV5Adapter");
const OneInchV4Adapter = hre.artifacts.require("OneInchV4Adapter");

const TOKEN_ARRAY = [
    // [MFC.USDC_ADDRESS, MFC.USDT_ADDRESS],
    // [MFC.DAI_ADDRESS, MFC.USDT_ADDRESS],
    // [MFC.CRV_ADDRESS, MFC.USDT_ADDRESS],
    [MFC.STG_ADDRESS, MFC.USDT_ADDRESS]
    // [MFC.SUSHI_ADDRESS, MFC.USDT_ADDRESS],
    // [MFC.DODO_ADDRESS, MFC.USDT_ADDRESS],
];

async function topUp(want, amount, to) {
    if (want === MFC.STG_ADDRESS) {
        await topUpStgByAddress(amount, to);
    } else if (want === MFC.DAI_ADDRESS) {
        await topUpDaiByAddress(amount, to);
    } else if (want === MFC.CRV_ADDRESS) {
        await topUpCrvByAddress(amount, to);
    } else if (want === MFC.USDC_ADDRESS) {
        await topUpUsdcByAddress(amount, to);
    } else if (want === MFC.SUSHI_ADDRESS) {
        await topUpSushiByAddress(amount, to);
    } else if (want === MFC.DODO_ADDRESS) {
        await topUpDODOByAddress(amount, to);
    }else {
        console.log(`WARN:not recharged [${want}] coin`)
    }
}

// The values here are without precision, precision is automatically adapted before redemption
const SWAP_NUMBER_ARRAY = [{
    amount: 100,
    slippage: 40,
}];

const EXCHANGE_EXTRA_PARAMS = {
    oneInchV4: {
        useHttp: true,
        network: 137,
        protocols: ['DFYN', 'POLYGON_DODO_V2', 'POLYGON_MSTABLE', 'POLYGON_UNISWAP_V3', 'POLYGON_SUSHISWAP', 'POLYGON_BALANCER_V2', 'POLYGON_QUICKSWAP', 'POLYGON_CURVE', 'POLYGON_AAVE_V2']
    },
    paraswap: {
        network: 137,
        excludeContractMethods: ['swapOnZeroXv2', 'swapOnZeroXv4']
    }
}

async function aggregatorExchange(fromTokenAddress, toTokenAddress, amount, slippage) {
    const fromToken = await ERC20.at(fromTokenAddress);
    const toToken = await ERC20.at(toTokenAddress);
    const FROM_TOKEN = {
        decimals: (await fromToken.decimals()).toString(),
        address: fromTokenAddress
    }
    const TO_TOKEN = {
        decimals: (await toToken.decimals()).toString(),
        address: toTokenAddress
    }
    await topUp(fromTokenAddress, amount, farmer1);
    const srcAmount = new BigNumber(10).pow(FROM_TOKEN.decimals).multipliedBy(amount);
    const title = `[aggregatorExchange] ${await fromToken.name()} => ${await toToken.name()}, amount=${srcAmount.toFixed()},slippage=${slippage}`;
    console.log(title);
    // slippage is calculated with a precision of 10000, e.g. pass in slippage=100, slippage is 1%
    // console.log('[aggregatorExchange] oneInchV4Adapter:%s', oneInchV4Adapter.address);
    // const SWAP_INFO = await getOneInchV4SwapInfo(FROM_TOKEN, TO_TOKEN, srcAmount.toFixed(), slippage, 500, oneInchV4Adapter.address, EXCHANGE_EXTRA_PARAMS.oneInchV4);
    // const SWAP_INFO = await getParaSwapSwapInfo(FROM_TOKEN, TO_TOKEN, srcAmount.toFixed(), slippage, 500, paraSwapAdapter.address, EXCHANGE_EXTRA_PARAMS.paraswap);
    const SWAP_INFO = await getBestSwapInfo(FROM_TOKEN, TO_TOKEN, srcAmount.toFixed(), slippage, 500, platformAdapter, EXCHANGE_EXTRA_PARAMS);

    console.log('------------------SWAP_INFO-----------------------');
    console.log(SWAP_INFO);
    // Utils.assertBNEq(isEmpty(SWAP_INFO), false, '最佳兑换路径获取失败');
    if (SWAP_INFO) {
        await topUp(fromTokenAddress, srcAmount, farmer1);
        const swapDescription = {
            amount: srcAmount.toFixed(),
            srcToken: FROM_TOKEN.address,
            dstToken: TO_TOKEN.address,
            receiver: farmer1
        };
        try {
            await fromToken.approve(swapAdapter.address, 0, {from: farmer1});
            await fromToken.approve(swapAdapter.address, srcAmount, {from: farmer1});
            const fromTokenBalance = await fromToken.balanceOf(farmer1);
            console.log('===========fromTokenBalance======%s', fromTokenBalance);
            console.log('===========srcAmount======%s', srcAmount.toFixed());
            await swapAdapter.swap(SWAP_INFO.platform, SWAP_INFO.method, SWAP_INFO.encodeExchangeArgs, swapDescription, {from: farmer1});
        } catch (e) {
            console.log('SWAP_INFO=', SWAP_INFO, e.message);
            assert.equal(true, false, `Exception for performing exchange operations!,${title}`);
        }
    }
}

let platformAdapter, oneInchV4Adapter, paraSwapAdapter, swapAdapter, accounts, farmer1;

describe('【test swap】', function () {
    before(async function () {
        await ethers.getSigners().then(resp => {
            accounts = resp;
            farmer1 = accounts[1].address;
        });
        oneInchV4Adapter = await OneInchV4Adapter.new();
        paraSwapAdapter = await ParaSwapV5Adapter.new();
        // 根据key获取value，不可写错
        platformAdapter = {
            paraswap: paraSwapAdapter.address,
            oneInchV4: oneInchV4Adapter.address
        };
        swapAdapter = await ExchangeAggregator.new([oneInchV4Adapter.address, paraSwapAdapter.address], farmer1);
    });


    after(async function () {

    });

    it('aggregatorExchange', async function () {
        for (const item of TOKEN_ARRAY) {
            const [fromTokenAddress, toTokenAddress] = item
            for (const num of SWAP_NUMBER_ARRAY) {
                const {
                    amount,
                    slippage
                } = num;
                await aggregatorExchange(fromTokenAddress, toTokenAddress, amount, slippage, platformAdapter);
                // await aggregatorExchange(toTokenAddress, fromTokenAddress, amount, slippage, platformAdapter);
            }
        }
    });
});


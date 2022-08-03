const checker = require('../strategy-checker');
const { ethers } = require('hardhat');
const { default: BigNumber } = require('bignumber.js');
const ERC20 = hre.artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20');
const topUp = require('../../../utils/top-up-utils');
const { advanceBlock } = require('../../../utils/block-utils');
const MockUniswapV3Router = hre.artifacts.require('contracts/mock/MockUniswapV3Router.sol:MockUniswapV3Router');
const UniswapV3DaiUsdc500Strategy = hre.artifacts.require("UniswapV3DaiUsdc500Strategy");

describe('【UniswapV3DaiUsdc500Strategy Strategy Checker】', function () {
    checker.check('UniswapV3DaiUsdc500Strategy', async function (strategy) {
        const accounts = await ethers.getSigners();
        const investor = accounts[1].address;
        const mockUniswapV3Router = await MockUniswapV3Router.new();
        const uniswapV3DaiUsdc500Strategy = await UniswapV3DaiUsdc500Strategy.at(strategy);
        const wantsInfo = await uniswapV3DaiUsdc500Strategy.getWantsInfo();
        const wants = wantsInfo._assets;
        for (let i = 0; i < wants.length; i++) {
            let wantToken = await ERC20.at(wants[i]);
            let wantTokenDecimals = await wantToken.decimals();
            wantToken.approve(mockUniswapV3Router.address, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {"from": investor});
            await mockUniswapV3Router.swap('0x5f69C2ec01c22843f8273838d570243fd1963014', i === 0 ? true : false, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {"from": investor});
        }
    }, {}, async function (strategy) {
        const accounts = await ethers.getSigners();
        const investor = accounts[1].address;
        keeper = accounts[19].address;
        const mockUniswapV3Router = await MockUniswapV3Router.new();
        const uniswapV3DaiUsdc500Strategy = await UniswapV3DaiUsdc500Strategy.at(strategy);
        await advanceBlock(1);
        let twap = new BigNumber(await uniswapV3DaiUsdc500Strategy.getTwap());
        console.log('before swap twap: %s', twap.toFixed());

        const wantsInfo = await uniswapV3DaiUsdc500Strategy.getWantsInfo();
        const wants = wantsInfo._assets;

        let wantToken = await ERC20.at(wants[1]);
        let wantTokenDecimals = await wantToken.decimals();
        wantToken.approve(mockUniswapV3Router.address, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), { from: investor });
        await mockUniswapV3Router.swap("0x5f69C2ec01c22843f8273838d570243fd1963014", false, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {"from": investor});

        await advanceBlock(1);
        twap = new BigNumber(await uniswapV3DaiUsdc500Strategy.getTwap());
        console.log('after swap twap: %s', twap.toFixed());

        await topUp.topUpDaiByAddress(new BigNumber(10).pow(22), strategy);

        const beforeBaseMintInfo = await uniswapV3DaiUsdc500Strategy.baseMintInfo();
        console.log('before rebalance beforeBaseMintInfo.tokenId: ', beforeBaseMintInfo.tokenId);
        await uniswapV3DaiUsdc500Strategy.rebalanceByKeeper({"from": keeper});
        const afterBaseMintInfo = await uniswapV3DaiUsdc500Strategy.baseMintInfo();
        console.log('after rebalance afterBaseMintInfo.tokenId: ', afterBaseMintInfo.tokenId);
        assert(beforeBaseMintInfo.tokenId !== afterBaseMintInfo.tokenId, 'rebalance fail');

        wantToken.approve(mockUniswapV3Router.address, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), { from: investor });
        await mockUniswapV3Router.swap("0x5f69C2ec01c22843f8273838d570243fd1963014", false, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {"from": investor});

        await advanceBlock(1);

        twap = new BigNumber(await uniswapV3DaiUsdc500Strategy.getTwap());
        console.log('after rebalance swap twap: %s', twap.toFixed());

        pendingRewards = await uniswapV3DaiUsdc500Strategy.harvest.call({
            from: keeper,
        });
        await uniswapV3DaiUsdc500Strategy.harvest({ from: keeper });
    });
});

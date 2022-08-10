const checker = require('../strategy-checker');
const { ethers } = require('hardhat');
const { default: BigNumber } = require('bignumber.js');
const ERC20 = hre.artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20');
const topUp = require('../../../utils/top-up-utils');
const { advanceBlock } = require('../../../utils/block-utils');
const MockUniswapV3Router = hre.artifacts.require('contracts/mock/MockUniswapV3Router.sol:MockUniswapV3Router');
const UniswapV3UsdcUsdt100Strategy = hre.artifacts.require("UniswapV3Strategy");

describe('【UniswapV3UsdcUsdt100Strategy Strategy Checker】', function () {
    checker.check('UniswapV3UsdcUsdt100Strategy', async function (strategy) {
        const accounts = await ethers.getSigners();
        const investor = accounts[1].address;
        const mockUniswapV3Router = await MockUniswapV3Router.new();
        const uniswapV3UsdcUsdt100Strategy = await UniswapV3UsdcUsdt100Strategy.at(strategy);
        const wantsInfo = await uniswapV3UsdcUsdt100Strategy.getWantsInfo();
        const wants = wantsInfo._assets;
        for (let i = 0; i < wants.length; i++) {
            let wantToken = await ERC20.at(wants[i]);
            let wantTokenDecimals = await wantToken.decimals();
            wantToken.approve(mockUniswapV3Router.address, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {"from": investor});
            await mockUniswapV3Router.swap('0xDaC8A8E6DBf8c690ec6815e0fF03491B2770255D', i === 0 ? true : false, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {"from": investor});
        }
    }, {}, async function (strategy) {
        const accounts = await ethers.getSigners();
        const investor = accounts[1].address;
        keeper = accounts[19].address;
        const mockUniswapV3Router = await MockUniswapV3Router.new();
        const uniswapV3UsdcUsdt100Strategy = await UniswapV3UsdcUsdt100Strategy.at(strategy);

        let twap = new BigNumber(await uniswapV3UsdcUsdt100Strategy.getTwap());
        console.log('before swap twap: %s', twap.toFixed());

        const wantsInfo = await uniswapV3UsdcUsdt100Strategy.getWantsInfo();
        const wants = wantsInfo._assets;

        let wantToken = await ERC20.at(wants[1]);
        let wantTokenDecimals = await wantToken.decimals();
        wantToken.approve(mockUniswapV3Router.address, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), { from: investor });
        await mockUniswapV3Router.swap("0xDaC8A8E6DBf8c690ec6815e0fF03491B2770255D", false, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {"from": investor});

        await advanceBlock(1);
        twap = new BigNumber(await uniswapV3UsdcUsdt100Strategy.getTwap());
        console.log('after swap twap: %s', twap.toFixed());

        await topUp.topUpUsdcByAddress(new BigNumber(10).pow(10), strategy);

        const beforeBaseMintInfo = await uniswapV3UsdcUsdt100Strategy.baseMintInfo();
        console.log('before rebalance beforeBaseMintInfo.tokenId: ', beforeBaseMintInfo.tokenId);
        await uniswapV3UsdcUsdt100Strategy.rebalanceByKeeper({"from": keeper});
        const afterBaseMintInfo = await uniswapV3UsdcUsdt100Strategy.baseMintInfo();
        console.log('after rebalance afterBaseMintInfo.tokenId: ', afterBaseMintInfo.tokenId);
        assert(beforeBaseMintInfo.tokenId !== afterBaseMintInfo.tokenId, 'rebalance fail');

        wantToken.approve(mockUniswapV3Router.address, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), { from: investor });
        await mockUniswapV3Router.swap("0xDaC8A8E6DBf8c690ec6815e0fF03491B2770255D", false, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {"from": investor});

        await advanceBlock(1);

        twap = new BigNumber(await uniswapV3UsdcUsdt100Strategy.getTwap());
        console.log('after rebalance swap twap: %s', twap.toFixed());

        pendingRewards = await uniswapV3UsdcUsdt100Strategy.harvest.call({
            from: keeper,
        });
        await uniswapV3UsdcUsdt100Strategy.harvest({ from: keeper });
    });
});

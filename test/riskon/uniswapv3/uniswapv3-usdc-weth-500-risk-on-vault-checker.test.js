const checker = require('../vault-checker');
const {ethers} = require('hardhat');
const {default: BigNumber} = require('bignumber.js');
const ERC20 = hre.artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20');
const topUp = require('../../../utils/top-up-utils');
const {advanceBlock} = require('../../../utils/block-utils');
const MockUniswapV3Router = hre.artifacts.require('MockUniswapV3Router');
const UniswapV3UsdcWeth500RiskOnVault = hre.artifacts.require('UniswapV3UsdcWeth500RiskOnVault');

describe('【UniswapV3UsdcWeth500RiskOnVault Vault Checker】', function () {
    checker.check('UniswapV3UsdcWeth500', async function (vault) {
        const accounts = await ethers.getSigners();
        const investor = accounts[1].address;
        const mockUniswapV3Router = await MockUniswapV3Router.new();
        const uniswapV3UsdcWeth500RiskOnVault = await UniswapV3UsdcWeth500RiskOnVault.at(vault);
        const wantToken = await uniswapV3UsdcWeth500RiskOnVault.wantToken();
        let wantTokenContract = await ERC20.at(wantToken);
        let wantTokenDecimals = await wantTokenContract.decimals();
        wantTokenContract.approve(mockUniswapV3Router.address, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {"from": investor});
        await mockUniswapV3Router.swap('0x45dDa9cb7c25131DF268515131f647d726f50608', true, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {"from": investor});
    }, {}, async function (vault) {
        const accounts = await ethers.getSigners();
        const investor = accounts[1].address;
        keeper = accounts[19].address;
        const mockUniswapV3Router = await MockUniswapV3Router.new();
        const uniswapV3UsdcWeth500RiskOnVault = await UniswapV3UsdcWeth500RiskOnVault.at(vault);

        let twap = new BigNumber(await uniswapV3UsdcWeth500RiskOnVault.getTwap());
        console.log('before swap twap: %s', twap.toFixed());

        const wantToken = await uniswapV3UsdcWeth500RiskOnVault.wantToken();
        let wantTokenContract = await ERC20.at(wantToken);
        let wantTokenDecimals = await wantTokenContract.decimals();
        wantTokenContract.approve(mockUniswapV3Router.address, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {from: investor});
        await mockUniswapV3Router.swap("0x45dDa9cb7c25131DF268515131f647d726f50608", true, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {"from": investor});

        await advanceBlock(1);
        twap = new BigNumber(await uniswapV3UsdcWeth500RiskOnVault.getTwap());
        console.log('after swap twap: %s', twap.toFixed());

        await topUp.topUpUsdcByAddress(new BigNumber(10).pow(10), vault);

        const beforeBaseMintInfo = await uniswapV3UsdcWeth500RiskOnVault.getMintInfo();
        console.log('before rebalance beforeBaseMintInfo._baseTokenId: %d', beforeBaseMintInfo._baseTokenId);
        await uniswapV3UsdcWeth500RiskOnVault.rebalanceByKeeper({"from": keeper});
        const afterBaseMintInfo = await uniswapV3UsdcWeth500RiskOnVault.getMintInfo();
        console.log('after rebalance afterBaseMintInfo._baseTokenId: %d', afterBaseMintInfo._baseTokenId);
        assert(beforeBaseMintInfo._baseTokenId !== afterBaseMintInfo._baseTokenId, 'rebalance fail');

        wantTokenContract.approve(mockUniswapV3Router.address, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {from: investor});
        await mockUniswapV3Router.swap("0x45dDa9cb7c25131DF268515131f647d726f50608", true, new BigNumber(10).pow(6).multipliedBy(new BigNumber(10).pow(wantTokenDecimals)), {"from": investor});

        await advanceBlock(1);

        twap = new BigNumber(await uniswapV3UsdcWeth500RiskOnVault.getTwap());
        console.log('after rebalance swap twap: %s', twap.toFixed());

        pendingRewards = await uniswapV3UsdcWeth500RiskOnVault.harvest.call({
            from: keeper,
        });
        await uniswapV3UsdcWeth500RiskOnVault.harvest({from: keeper});
    });
});

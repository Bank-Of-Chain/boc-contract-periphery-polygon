const {default: BigNumber} = require('bignumber.js');
const address = require('./../config/address-config');
const topUp = require('./../utils/top-up-utils');
const {
    advanceBlock
} = require('../utils/block-utils');

const VaultFactory = hre.artifacts.require('VaultFactory.sol');
const RiskOnVault = hre.artifacts.require('UniswapV3UsdcWeth500RiskOnVault.sol');
const MockUniswapV3Router = hre.artifacts.require('MockUniswapV3Router.sol');
const ERC20 = hre.artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20');

const {
    WETH_ADDRESS,
    USDC_ADDRESS,
} = require('../config/mainnet-fork-test-config');

const vaultFactoryAddress = '0xcd34D0833406Bff8073e18AAFa3DC34EE48Df9BA';
const riskOnVaultBaseAddress = '0x8013Dd64084e9c9122567563AA86981F4C20576B';
const mockUniswapV3RouterAddress = '0x12087c013f6269A90F113F8935f51C713a09b173';
const poolAddress = '0x45dDa9cb7c25131DF268515131f647d726f50608';

const main = async () => {
    const network = hre.network.name;
    console.log('\n\n 📡 simple lend ... At %s Network \n', network);
    if (network !== 'localhost') {
        return;
    }

    const accounts = await ethers.getSigners();
    const investor = accounts[3].address;
    const keeper = accounts[19].address;

    // top up
    const usdcAmount = new BigNumber(10000);
    await topUpAmount(USDC_ADDRESS, usdcAmount, investor);
    console.log(`top up successfully`);

    const wantToken = USDC_ADDRESS;
    const vaultFactory = await VaultFactory.at(vaultFactoryAddress);
    await vaultFactory.createNewVault(wantToken, riskOnVaultBaseAddress, {from: investor});
    const userVaultAddress = await vaultFactory.vaultAddressMap(investor, riskOnVaultBaseAddress, 1);
    console.log(`vaultFactory createNewVault successfully, userVaultAddress: %s`, userVaultAddress);

    const riskOnVault = await RiskOnVault.at(userVaultAddress);
    const wantTokenContract = await ERC20.at(wantToken);
    const wantTokenDecimals = new BigNumber(10 ** (await wantTokenContract.decimals()));
    let wantTokenAmount = new BigNumber(10000).multipliedBy(wantTokenDecimals);

    await wantTokenContract.approve(userVaultAddress, 0, {from: investor})
    await wantTokenContract.approve(userVaultAddress, wantTokenAmount, {from: investor})
    await riskOnVault.lend(wantTokenAmount, {from: investor});
    console.log(`riskOnVault lend successfully, estimatedTotalAssets: %d`, new BigNumber(await riskOnVault.estimatedTotalAssets()));

    await advanceBlock(1);

    let swapTokenAddress = wantToken;
    console.log('swapTokenAddress: ', swapTokenAddress);
    let swapTokenPosition = '0';
    console.log('swapTokenPosition: ', swapTokenPosition);
    let swapAmount = 50000;
    console.log('swapAmount: ', swapAmount);
    await swap(swapTokenAddress, swapTokenPosition, swapAmount, investor);

    const borrowToken = await riskOnVault.borrowToken();
    swapTokenAddress = borrowToken;
    console.log('swapTokenAddress: ', swapTokenAddress);
    swapTokenPosition = '1';
    console.log('swapTokenPosition: ', swapTokenPosition);
    swapAmount = 50;
    console.log('swapAmount: ', swapAmount);
    await swap(swapTokenAddress, swapTokenPosition, swapAmount, investor);

    await advanceBlock(1);
    console.log(`riskOnVault harvest before, estimatedTotalAssets: %d`, new BigNumber(await riskOnVault.estimatedTotalAssets()));

    await riskOnVault.harvest({from: keeper});

    console.log(`riskOnVault harvest after, estimatedTotalAssets: %d`, new BigNumber(await riskOnVault.estimatedTotalAssets()));

    async function swap(swapTokenAddress, swapTokenPosition, swapAmount, investor) {
        const mockUniswapV3Router = await MockUniswapV3Router.at(mockUniswapV3RouterAddress);

        let swapToken = await ERC20.at(swapTokenAddress);
        let swapTokenDecimals = await swapToken.decimals();
        await topUpAmount(swapTokenAddress, swapAmount, investor);

        let swapTokenBalance = new BigNumber(await swapToken.balanceOf(investor));
        console.log('swapTokenBalance: ', swapTokenBalance.toFixed());
        await swapToken.approve(mockUniswapV3RouterAddress, new BigNumber(swapAmount).multipliedBy(new BigNumber(10).pow(swapTokenDecimals)), {"from": investor});
        await mockUniswapV3Router.swap(poolAddress, swapTokenPosition === '0', new BigNumber(swapAmount).multipliedBy(new BigNumber(10).pow(swapTokenDecimals)), {"from": investor});
        console.log('swap finish!!!');
    }

    async function topUpAmount(tokenAddress, tokenAmount, investor) {
        let token;
        let tokenDecimals;
        switch (tokenAddress) {
            case address.USDC_ADDRESS:
                console.log('top up USDC');
                token = await ERC20.at(address.USDC_ADDRESS);
                tokenDecimals = await token.decimals();
                await topUp.topUpUsdcByAddress(tokenAmount * 10 ** tokenDecimals, investor);
                break;
            case address.WETH_ADDRESS:
                console.log('top up WETH');
                token = await ERC20.at(address.WETH_ADDRESS);
                tokenDecimals = await token.decimals();
                await topUp.topUpWethByAddress(tokenAmount * 10 ** tokenDecimals, investor);
                break;
            default:
                throw new Error('Unsupported token!');
        }
        console.log('topUp finish!!!');
    }
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });

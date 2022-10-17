const address = require('./../config/address-config');
const topUp = require('./../utils/top-up-utils');
const ERC20 = hre.artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20');
const BigNumber = require('bignumber.js');
const MockUniswapV3Router = hre.artifacts.require('contracts/usd/mock/MockUniswapV3Router.sol:MockUniswapV3Router');

const {
    WETH_ADDRESS,
    USDC_ADDRESS,
} = require('../config/mainnet-fork-test-config');

const main = async () => {
    const network = hre.network.name;
    console.log('\n\n 📡 uniswapv3 swap ... At %s Network \n', network);

    const swapPoolAddress = '0x45dDa9cb7c25131DF268515131f647d726f50608';
    console.log('swapPoolAddress: ', swapPoolAddress);
    const swapTokenAddress = USDC_ADDRESS;
    console.log('swapTokenAddress: ', swapTokenAddress);
    const swapTokenPosition = '0';
    console.log('swapTokenPosition: ', swapTokenPosition);
    const swapAmount = 10000;
    console.log('swapAmount: ', swapAmount);

    const accounts = await ethers.getSigners();
    const investor = accounts[5].address;
    const mockUniswapV3Router = await MockUniswapV3Router.new();

    let swapToken = await ERC20.at(swapTokenAddress);
    let swapTokenDecimals = await swapToken.decimals();
    await topUpSwapAmount(swapTokenAddress, swapAmount, investor);

    let swapTokenBalance = new BigNumber(await swapToken.balanceOf(investor));
    console.log('swapTokenBalance: ', swapTokenBalance.toFixed());
    await swapToken.approve(mockUniswapV3Router.address, new BigNumber(swapAmount).multipliedBy(new BigNumber(10).pow(swapTokenDecimals)), {"from": investor});
    await mockUniswapV3Router.swap(swapPoolAddress, swapTokenPosition === '0', new BigNumber(swapAmount).multipliedBy(new BigNumber(10).pow(swapTokenDecimals)), {"from": investor});
    console.log('swap finish!!!');

    async function topUpSwapAmount(tokenAddress, tokenAmount, investor) {
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
};

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });

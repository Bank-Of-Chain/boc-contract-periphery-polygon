const {
    ethers
} = require('hardhat');
const MFC = require('../../config/mainnet-fork-test-config');
const topUp = require('../../utils/top-up-utils');
const BigNumber = require('bignumber.js');
const ERC20 = hre.artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20');
const TestAaveLendAction = hre.artifacts.require('TestAaveLendAction');

describe('AaveLendActionMixin test', function () {

    const interestRateMode = 2;
    // USDC
    const collateralToken = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
    // WETH
    const borrowToken = '0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619';
    const aCollateralToken = '0x030bA81f1c18d280636F32af80b9AAd02Cf0854e';

    let aaveLendAction;
    let farmer;

    before('INIT', async function () {
        aaveLendAction = await TestAaveLendAction.new(interestRateMode, collateralToken, borrowToken);
        await ethers.getSigners().then((resp) => {
            const accounts = resp;
            farmer = accounts[0].address;
        });
    });

    let collateralTokenContract;
    let collateralTokenDecimals;
    let collateralTokenPrecision;
    it('add collateral', async function () {
        collateralTokenContract = await ERC20.at(collateralToken);
        collateralTokenDecimals = await collateralTokenContract.decimals();
        collateralTokenPrecision = new BigNumber(10 ** collateralTokenDecimals);

        await topUp.topUpUsdcByAddress(collateralTokenPrecision.multipliedBy(20000), farmer);

        const collateralAmount = new BigNumber(collateralTokenPrecision.multipliedBy(10000));
        await collateralTokenContract.approve(aaveLendAction.address, 0, {from: farmer})
        await collateralTokenContract.approve(aaveLendAction.address, collateralAmount, {from: farmer})
        await aaveLendAction.addCollateral(collateralAmount);
        await logBorrowInfo();
    });

    it('remove collateral', async function () {
        const collateralAmount = new BigNumber(collateralTokenPrecision.multipliedBy(5000));
        await aaveLendAction.removeCollateral(collateralAmount);
        await logBorrowInfo();
    });

    let borrowTokenContract;
    let borrowTokenDecimals;
    let borrowTokenPrecision;
    it('borrow', async function () {
        borrowTokenContract = await ERC20.at(borrowToken);
        borrowTokenDecimals = await borrowTokenContract.decimals();
        borrowTokenPrecision = new BigNumber(10 ** borrowTokenDecimals);

        const borrowAmount = new BigNumber(2 * borrowTokenPrecision);
        await aaveLendAction.borrow(borrowAmount);
        await logBorrowInfo();
    });

    it('repay', async function () {
        const repayAmount = new BigNumber(borrowTokenPrecision);
        await aaveLendAction.repay(repayAmount);
        await logBorrowInfo();
    });

    async function logBorrowInfo() {
        const borrowInfo = await aaveLendAction.borrowInfo();
        console.log('===========borrow info===========');
        console.log('totalCollateralETH:%s', borrowInfo._totalCollateralETH,);
        console.log('totalDebtETH:%s', borrowInfo._totalDebtETH,);
        console.log('availableBorrowsETH:%s', borrowInfo._availableBorrowsETH,);
        console.log('currentLiquidationThreshol:%s', borrowInfo._currentLiquidationThreshold);
        console.log('ltv:%s', borrowInfo._ltv,);
        console.log('healthFactor:%s', borrowInfo._healthFactor);
        console.log('currentBorrow:%s', await aaveLendAction.getCurrentBorrow());
    }
});

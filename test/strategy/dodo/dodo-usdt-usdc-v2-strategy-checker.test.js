// npx hardhat test test\strategy\dodo\dodo-usdt-usdc-v2-strategy-checker.test.js
const checker = require('../strategy-checker');

describe('【DodoUsdtUsdcV2Strategy Strategy Checker】', function() {
    checker.check('DodoUsdtUsdcV2Strategy');
});
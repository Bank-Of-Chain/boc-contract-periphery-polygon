const checker = require('../strategy-checker');
const ADDRESS = require('../../../config/address-config');

describe('【BalancerUsdcUsdtDaiTusdStrategy Strategy Checker】', function() {
    checker.check('BalancerUsdcUsdtDaiTusdStrategy',null,null,null,3);
});
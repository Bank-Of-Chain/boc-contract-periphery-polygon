const checker = require('../strategy-checker');
const ADDRESS = require('../../../config/address-config');

describe('【Curve3CrvStrategy Strategy Checker】', function() {
    checker.check('Curve3CrvStrategy', null, async (pendingRewards, harvesterAddress, valueInterpreter) => {
        let rewardsExchangePath = new Map();
        rewardsExchangePath.set(ADDRESS.CRV_ADDRESS, [ADDRESS.CRV_ADDRESS, ADDRESS.USDT_ADDRESS]);
        rewardsExchangePath.set(ADDRESS.WMATIC_ADDRESS, [ADDRESS.WMATIC_ADDRESS, ADDRESS.USDT_ADDRESS]);
        return checker.exchangeRewardToken(pendingRewards, harvesterAddress, valueInterpreter, rewardsExchangePath, ADDRESS.SUSHISWAP_ROUTER);
    },null,2);
});
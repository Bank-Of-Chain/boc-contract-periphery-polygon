const checker = require('../strategy-checker');
const ADDRESS = require('../../../config/address-config');

describe('【Synapse4UStrategy Strategy Checker】', function() {
    checker.check('Synapse4UStrategy', null, async (pendingRewards, harvesterAddress, valueInterpreter) => {
        let rewardsExchangePath = new Map();
        rewardsExchangePath.set(ADDRESS.SYN_ADDRESS, [ADDRESS.SYN_ADDRESS, ADDRESS.USDC_ADDRESS, ADDRESS.USDT_ADDRESS]);
        return checker.exchangeRewardToken(pendingRewards, harvesterAddress, valueInterpreter, rewardsExchangePath);
    });
});
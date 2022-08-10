const balancerStrategies = [
    {
        name: "BalancerUsdcDaiMaiUsdtStrategy",
        contract: "BalancerUsdcDaiMaiUsdtStrategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
        ]
    },
    {
        name: "BalancerUsdcUsdtDaiTusdStrategy",
        contract: "BalancerUsdcUsdtDaiTusdStrategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
        ]
    },
];

module.exports = {
    balancerStrategies
};

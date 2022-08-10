const sushiStrategies = [
    {
        name: "SushiUsdcDaiStrategy",
        contract: "SushiSwapStrategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0xCD578F016888B57F1b1e3f887f392F0159E26747", //pair
            11
        ]
    },
    {
        name: "SushiUsdcUsdtStrategy",
        contract: "SushiSwapStrategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0x4B1F1e2435A9C96f7330FAea190Ef6A7C8D70001", //pair
            8
        ]
    },
];

module.exports = {
    sushiStrategies
};

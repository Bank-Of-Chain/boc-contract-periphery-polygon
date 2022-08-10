const quickswapStrategies = [
    {
        name: "QuickswapDaiUsdtStrategy",
        contract: "QuickswapStrategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0x59153f27eeFE07E5eCE4f9304EBBa1DA6F53CA88", //pair
            "0xc45aB79526Dd16B00505EB39222E6B1Aed0Ef079", //stakingPool
        ]
    },
    {
        name: "QuickswapUsdcDaiStrategy",
        contract: "QuickswapStrategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0xf04adBF75cDFc5eD26eeA4bbbb991DB002036Bdd", //pair
            "0xACb9EB5B52F495F09bA98aC96D8e61257F3daE14", //stakingPool
        ]
    },
    {
        name: "QuickswapUsdcUsdtStrategy",
        contract: "QuickswapStrategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0x2cF7252e74036d1Da831d11089D326296e64a728", //pair
            "0xAFB76771C98351Aa7fCA13B130c9972181612b54", //stakingPool
        ]
    },
];

module.exports = {
    quickswapStrategies
};

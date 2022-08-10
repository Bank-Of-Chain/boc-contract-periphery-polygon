const aaveStrategies = [
    {
        name: "AaveUsdcStrategy",
        contract: "AaveLendStrategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", //USDC
            "0x1a13F4Ca1d028320A707D99520AbFefca3998b7F", //AToken
            "0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf", //lendingPool
            "0x357D51124f59836DeD84c8a1730D72B749d8BC23"
        ]
    },
    {
        name: "AaveUsdtStrategy",
        contract: "AaveLendStrategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", //USDT
            "0x60D55F02A771d515e077c9C2403a1ef324885CeC", //AToken
            "0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf", //lendingPool
            "0x357D51124f59836DeD84c8a1730D72B749d8BC23"
        ]
    },
];

module.exports = {
    aaveStrategies
};

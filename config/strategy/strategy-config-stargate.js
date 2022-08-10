const stargateStrategies = [
    {
        name: "StargateUsdcStrategy",
        contract: "StargateSingleStrategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174", //underlying
            "0x45A01E4e04F14f7A4a6702c74187c5F6222033cd", //router
            "0x1205f31718499dBf1fCa446663B532Ef87481fe1", //lpToken
            1,
            0
        ]
    },
    {
        name: "StargateUsdtStrategy",
        contract: "StargateSingleStrategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0xc2132D05D31c914a87C6611C10748AEb04B58e8F", //underlying
            "0x45A01E4e04F14f7A4a6702c74187c5F6222033cd", //router
            "0x29e38769f23701A2e4A8Ef0492e19dA4604Be62c", //lpToken
            2,
            1
        ]
    },
];

module.exports = {
    stargateStrategies
};

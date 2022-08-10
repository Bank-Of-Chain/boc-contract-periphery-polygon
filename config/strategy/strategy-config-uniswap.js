const uniswapStrategies = [
    {
        name: "UniswapV3DaiUsdc100Strategy",
        contract: "UniswapV3Strategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0x5645dCB64c059aa11212707fbf4E7F984440a8Cf",
            5,
            2,
            41400,
            0,
            100,
            60,
            1
        ]
    },
    {
        name: "UniswapV3DaiUsdc500Strategy",
        contract: "UniswapV3Strategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0x5f69C2ec01c22843f8273838d570243fd1963014",
            10,
            10,
            41400,
            0,
            100,
            60,
            10
        ]
    },
    {
        name: "UniswapV3UsdcUsdt100Strategy",
        contract: "UniswapV3Strategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0xDaC8A8E6DBf8c690ec6815e0fF03491B2770255D",
            5,
            2,
            41400,
            0,
            100,
            60,
            1
        ]
    },
    {
        name: "UniswapV3UsdcUsdt500Strategy",
        contract: "UniswapV3Strategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0x3F5228d0e7D75467366be7De2c31D0d098bA2C23",
            10,
            10,
            41400,
            0,
            100,
            60,
            10
        ]
    },
];

module.exports = {
    uniswapStrategies
};

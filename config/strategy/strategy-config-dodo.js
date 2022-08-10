const dodoStrategies = [
    {
        name: "DodoUsdtUsdcV2Strategy",
        contract: "DodoV2Strategy",
        profitLimitRatio: 100,
        lossLimitRatio: 100,
        addToVault: true,
        customParams: [
            "0x813FddecCD0401c4Fa73B092b074802440544E52", //lpTokenPool
            "0x2C5CA709d9593F6Fd694D84971c55fB3032B87AB", //baseLpToken
            "0xB0B417A00E1831DeF11b242711C3d251856AADe3", //quoteLpToken
            "0xCd288Dd48d26a9f671a1a06bcc48c2A3ee800A13", //baseStakePool
            "0xF4Ae5322eD8B0af7A4f5161caf33C4894752F0f5"  //quoteStakePool
        ]
    },
];

module.exports = {
    dodoStrategies
};

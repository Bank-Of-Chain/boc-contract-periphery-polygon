const address = require('./address-config');
const {
    WETH_ADDRESS,
    DAI_ADDRESS,
    USDT_ADDRESS,
    USDC_ADDRESS,
    UST_ADDRESS,
    TUSD_ADDRESS,
    WMATIC_ADDRESS,
    MAI_ADDRESS,
    BAL_ADDRESS,
    CRV_ADDRESS,
    SUSHI_ADDRESS,
} = address;
const CHAINLINK_RATE_ASSETS = {
    ETH: 0,
    USD: 1,
};

const getChainlinkConfig = () => {
    const nextConfig = {
        ETH_USD_AGGREGATOR: '0xF9680D99D6C9589e2a93a78A04A279e509205945',
        ETH_USD_HEARTBEAT: 27,
        basePegged: {
            WETH: {
                primitive: WETH_ADDRESS,
                rateAsset: CHAINLINK_RATE_ASSETS.ETH,
            },
        },
        aggregators: {
            WETH_USD: {
                primitive: WETH_ADDRESS,
                aggregator: '0xF9680D99D6C9589e2a93a78A04A279e509205945',
                rateAsset: CHAINLINK_RATE_ASSETS.USD,
                heartbeat: 1 * 60 * 60
            },
            DAI_USD: {
                primitive: DAI_ADDRESS,
                aggregator: '0x4746DeC9e833A82EC7C2C1356372CcF2cfcD2F3D',
                rateAsset: CHAINLINK_RATE_ASSETS.USD,
                heartbeat: 90
            },
            USDT_USD: {
                primitive: USDT_ADDRESS,
                aggregator: '0x0A6513e40db6EB1b165753AD52E80663aeA50545',
                rateAsset: CHAINLINK_RATE_ASSETS.USD,
                heartbeat: 90
            },
            USDC_USD: {
                primitive: USDC_ADDRESS,
                aggregator: '0xfE4A8cc5b5B2366C1B58Bea3858e81843581b2F7',
                rateAsset: CHAINLINK_RATE_ASSETS.USD,
                heartbeat: 90
            },
            UST_USD: {
                primitive: UST_ADDRESS,
                aggregator: '0x2D455E55e8Ad3BA965E3e95e7AaB7dF1C671af19',
                rateAsset: CHAINLINK_RATE_ASSETS.USD,
                heartbeat: 24 * 60 * 60
            },
            WMATIC_USD: {
                primitive: WMATIC_ADDRESS,
                aggregator: '0xAB594600376Ec9fD91F8e885dADF0CE036862dE0',
                rateAsset: CHAINLINK_RATE_ASSETS.USD,
                heartbeat: 90
            },
            TUSD_USD: {
                primitive: TUSD_ADDRESS,
                aggregator: '0x7C5D415B64312D38c56B54358449d0a4058339d2',
                rateAsset: CHAINLINK_RATE_ASSETS.USD,
                heartbeat: 90
            },
            MAI_USD: {
                primitive: MAI_ADDRESS,
                aggregator: '0xd8d483d813547CfB624b8Dc33a00F2fcbCd2D428',
                rateAsset: CHAINLINK_RATE_ASSETS.USD,
                heartbeat: 24 * 60 * 60
            },
            BAL_USD: {
                primitive: BAL_ADDRESS,
                aggregator: '0xD106B538F2A868c28Ca1Ec7E298C3325E0251d66',
                rateAsset: CHAINLINK_RATE_ASSETS.USD,
                heartbeat: 24 * 60 * 60
            },
            CRV_USD: {
                primitive: CRV_ADDRESS,
                aggregator: '0x336584C8E6Dc19637A5b36206B1c79923111b405',
                rateAsset: CHAINLINK_RATE_ASSETS.USD,
                heartbeat: 8 * 60
            },
            SUSHI_USD: {
                primitive: SUSHI_ADDRESS,
                aggregator: '0x49B0c695039243BBfEb8EcD054EB70061fd54aa0',
                rateAsset: CHAINLINK_RATE_ASSETS.USD,
                heartbeat: 24 * 60 * 60
            }
        },
    }
    return nextConfig;
}

module.exports = {
    getChainlinkConfig
};

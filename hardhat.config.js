require('dotenv').config();
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');
require('@nomiclabs/hardhat-truffle5');
require('hardhat-gas-reporter');
require('hardhat-contract-sizer');
require('@openzeppelin/hardhat-upgrades');
require('@openzeppelin/hardhat-defender');
const { removeConsoleLog } = require('hardhat-preprocessor');

let keys = {};
try {
    keys = require('./dev-keys.json');
} catch (error) {
    keys = {
        alchemyKey: {
            dev: process.env.ALCHEMY_KEY,
        },
    };
}

process.env.FORCE_COLOR = '3';
process.env.TS_NODE_TRANSPILE_ONLY = 'true';

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async () => {
    const accounts = await ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const config = {
    defender: {
        apiKey: process.env.DEFENDER_TEAM_API_KEY,
        apiSecret: process.env.DEFENDER_TEAM_API_SECRET_KEY,
    },
    defaultNetwork: 'hardhat',
    networks: {
        hardhat: {
            chains: {
                137: {
                    hardforkHistory: {
                        berlin: 10000000,
                        london: 20000000,
                    }
                }
            },
            forking: {
                url: 'https://polygon-mainnet.g.alchemy.com/v2/' + keys.alchemyKey.dev,
                blockNumber: 31804149,
            },
            timeout: 1800000,
            allowUnlimitedContractSize: true,
        },
        localhost: {
            url: 'http://localhost:8545',
            gasPrice: 300000000000,
            timeout: 1800000,
            allowUnlimitedContractSize: true,
        },
        mumbai: {
            url: 'https://polygon-mumbai.g.alchemy.com/v2/' + keys.alchemyKey.mumbai,
            accounts: process.env.ACCOUNT_PRIVATE_KEY ? [`${process.env.ACCOUNT_PRIVATE_KEY}`] : undefined,
        },
        mainnet: {
            url: 'https://polygon-mainnet.g.alchemy.com/v2/' + keys.alchemyKey.prod,
            accounts: process.env.ACCOUNT_PRIVATE_KEY ? [`${process.env.ACCOUNT_PRIVATE_KEY}`] : undefined,
        },
    },
    etherscan: {
        // The api of etherscan is wrapped in the hardhat plugin for open source use
        apiKey: '1RJB3ZWPC7434KKPQ5F4AX445WVHTY26DK',
    },
    solidity: {
        compilers: [
            {
                version: '0.6.12',
                settings: {
                    optimizer: {
                        details: {
                            yul: false,
                        },
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: '0.8.3',
                settings: {
                    optimizer: {
                        details: {
                            yul: true,
                        },
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    paths: {
        sources: './contracts',
        tests: './test',
        cache: './cache',
        artifacts: './artifacts',
    },
    mocha: {
        timeout: 2000000,
    },
    preprocess: {
        eachLine: removeConsoleLog(bre => bre.network.name !== 'hardhat' && bre.network.name !== 'localhost'),
    },
    gasReporter: {
        enabled: true,
        gasPrice: 100,
        currency: 'USD',
    },
    contractSizer: {
        alphaSort: true,
        runOnCompile: true,
        disambiguatePaths: false,
    },
    spdxLicenseIdentifier: {
        overwrite: true,
        runOnCompile: true,
    }
};

const forkLatest = process.env.FORK_LATEST;
if(forkLatest){
    delete config.networks.hardhat.forking.blockNumber;
}
module.exports = config;

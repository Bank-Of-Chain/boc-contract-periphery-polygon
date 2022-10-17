const address = require('./../config/address-config');
const topUp = require('./../utils/top-up-utils');
const ERC20 = hre.artifacts.require('@openzeppelin/contracts/token/ERC20/ERC20.sol:ERC20');
const BigNumber = require('bignumber.js');
const VaultFactory = hre.artifacts.require('VaultFactory');
const swapParam = process.env.HARDHAT_TSCONFIG;

const main = async () => {
    const network = hre.network.name;
    console.log('\n\n 📡 uniswapv3 swap ... At %s Network \n', network);

    const accounts = await ethers.getSigners();
    const investor = accounts[0].address;

    let vaultFactory = await VaultFactory.at('0x8013Dd64084e9c9122567563AA86981F4C20576B');
    vaultFactory.createNewVault('0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619', '0x4054765d35be9b4b27C4A1db3B269ae40f0541Ad', {"from": investor});
    console.log(await vaultFactory.totalVaultAddrList(0));
    console.log('createNewVault finish!!!');
};

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });

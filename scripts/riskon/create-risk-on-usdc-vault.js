const VaultFactory = hre.artifacts.require('VaultFactory');

const {
    USDC_ADDRESS
} = require('../../config/mainnet-fork-test-config');

const vaultFactoryAddress = '0x4054765d35be9b4b27C4A1db3B269ae40f0541Ad';
const main = async () => {
    const network = hre.network.name;
    console.log('\n\n 📡 create riskOnVault ... At %s Network \n', network);

    const accounts = await ethers.getSigners();
    const investor = accounts[5].address;

    const vaultFactory = await VaultFactory.at(vaultFactoryAddress);
    vaultFactory.createNewVault(USDC_ADDRESS, '0xFdc146E92D892F326CB9a1A480f58fc30a766c98', {"from": investor});
    console.log(await vaultFactory.totalVaultAddrList(0));
    console.log('createNewVault finish!!!');
};

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });

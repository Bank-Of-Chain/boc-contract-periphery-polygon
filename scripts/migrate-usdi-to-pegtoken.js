const {
    ethers,
    upgrades
} = require('hardhat');

// const { Contract, Provider } = require('ethers-multicall');

const {
    deploy,
    deployProxy
} = require('../utils/deploy-utils');
const {
    send
} = require('@openzeppelin/test-helpers');
const ProxyAdmin = hre.artifacts.require('@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol:ProxyAdmin');
const IVault = hre.artifacts.require('IVault');
const USDi = hre.artifacts.require('USDi');
const PegToken = hre.artifacts.require('PegToken');
const vaultAbi = require('../artifacts/boc-contract-core/contracts/vault/IVault.sol/IVault.json');
const assert = require('assert');

const governance = '0xc791B4A9B10b1bDb5FBE2614d389f0FE92105279';
const proxyAdminAddress = '0x2BFe17F338Cb4554FDb949ddA5798c903c4a179A';


//contracts info List
const contractsList = [
    {
        "contract_name": "AaveUsdtStrategy",
        "contract_deployed_address": "0x005501a41Cb3959f73f84DF75761E22747975394",
        "upgrade": true,
    },
    {
        "contract_name": "AaveUsdcStrategy",
        "contract_deployed_address": "0x863D1ef13Ab12eDd8714B0b763405Bf77d61dAB8",
        "upgrade": true,
    },
    {
        "contract_name": "Curve3CrvStrategy",
        "contract_deployed_address": "0x482f6a3C9f9CcaA31c018BeAa750B3A258ecb4AA",
        "upgrade": true,
    },
    {
        "contract_name": "QuickswapDaiUsdtStrategy",
        "contract_deployed_address": "0x4cCe79cF22E11ADF992D7b98946CAF0724e80A63",
        "upgrade": true,
    },
    {
        "contract_name": "QuickswapUsdcDaiStrategy",
        "contract_deployed_address": "0x9DE9f35E558a7cC6E3F1E1951e1705b6c5bF9FA7",
        "upgrade": true,
    },
    {
        "contract_name": "QuickswapUsdcUsdtStrategy",
        "contract_deployed_address": "0xBf77d8396375d2d53D941c16A3DA9558d703FC1b",
        "upgrade": true,
    },
    {
        "contract_name": "SushiUsdcDaiStrategy",
        "contract_deployed_address": "0xfD750961F5965A260b071c3F32aded843fbc4f6d",
        "upgrade": true,
    },
    {
        "contract_name": "SushiUsdcUsdtStrategy",
        "contract_deployed_address": "0x7923aFa758A95aD3C3B92098C00a9c49F7f6448C",
        "upgrade": true,
    },
    {
        "contract_name": "DodoUsdtUsdcStrategy",
        "contract_deployed_address": "0x5fA1823c267767B91b13a8CbADd210927E4E21f1",
        "upgrade": true,
    },
    {
        "contract_name": "Synapse4UStrategy",
        "contract_deployed_address": "0x67a6f7475AB4fCcb2a94Bfa6BbF4E121a4d5d9d1",
        "upgrade": true,
    },
    {
        "contract_name": "BalancerUsdcUsdtDaiTusdStrategy",
        "contract_deployed_address": "0xf6aF026700Ded1919E4286946081F58Ab0D8087a",
        "upgrade": true,
    },
    {
        "contract_name": "StargateUsdtStrategy",
        "contract_deployed_address": "0x7Cd86D309c699d448215798007D7D5D52Fa1DF04",
        "upgrade": true,
    },
    {
        "contract_name": "StargateUsdcStrategy",
        "contract_deployed_address": "0x20a4441383F31CEF6eCEEBE23365CB2028444e78",
        "upgrade": true,
    },
    {
        "contract_name": "Harvester",
        "contract_deployed_address": "0x49b65109b0DE769f420BD46Fd288204f58aa9D8C",
        "upgrade": true,
    },
];

const vaultAddr = "0xd3feAe6c4fdfDE73Bd2fE99c8fE6944904DAA68A";
const usdiAddr = "0x8DEb399a86f28f62f0F24daF56c4aDD8e57EEcD5";
const accessControlProxy = "0xaDbeE9ac3565ED720Eb7D5a6c0B5BbCAD727fD5E";

const usdiHolders = [
    "0x047c6f1bd8c71adb1c146c4e96785b8e7dafd2e1",
    "0x04804b606bd8ff1e72bd4fcf195d5a5cba220c5a",
    "0x0c8be3d3af69b1b7cf5aeeefb92ca08a52619f0e",
    "0x12f4d99a7249e194a0b7990a3db41546cc1b1a7c",
    "0x16cccfc3c92b4d0250d3b2d885ec5c34f89ccf4c",
    "0x1acc9a040fd478e693dad407bdc37d41dc5a14a4",
    "0x31622091b2ddde1c0b6c81138a966d5a65f45aec",
    "0x375d80da4271f5dcdf821802f981a765a0f11763",
    "0x38b97043e369b841d6af26be20eee35f37bd7a4c",
    "0x42dc04aecd9d4215891874350729efa36234397d",
    "0x459fb50cca9d68526412ef33ede61592005fec36",
    "0x4f9f7cc1c03efe0390cd208dbffb4fa5f866190a",
    "0x51f868b45438ad8066b5816a5a153e96ae133ed6",
    "0x5c12bd5aff013cd60588aa1c1448ca1d41ca3318",
    "0x6b4b48ccdb446a109ae07d8b027ce521b5e2f1ff",
    "0x71a984f186e66291120f230a892c51f3744d2688",
    "0x82d0ca2edf47355fd1a3e65b59105ce70c192b21",
    "0x91370264b403c3ea0993cd2e1f59da4d34e7af0d",
    "0x959a6fa8b13ba63519412497502f833f38f33b25",
    "0x96f4f9f2cc629f73ce9146c6e2c8b3e4e5a2998d",
    "0xa29d8e961067b84f0570db889e67b5b1cf4ea33f",
    "0xacf962b7b7caff9c68a8f4d0a0f1d135bb84f442",
    "0xade721923ccfbd76da0de7948a87659faf811317",
    "0xb32bfc8c8f7efd7374a615eee828dbb894fc67fb",
    "0xbc29b36acab7f065f5d72f416ef29e2da3d7fdbd",
    "0xc2b7c321b7cf295e6fbc3fde056a4cb79fa178d1",
    "0xc85263b8a22b6ff09a849558a5aa68d9b26409a8",
    "0xcac2529b787ae8b3ed28671c9a5d868af7777777",
    "0xd73a62f9e584f40ef25b9a873be0eca6c7ebf622",
    "0xdb965bbad97d0784afc22a5d82a24c5478faf7f4",
    "0xe314699e527153b33789da34dfa2252f645805d0",
    "0xec5a69e63e31f91461d4011e0a35a39eb2c6dcad",
    "0xee3db241031c4aa79feca628f7a00aaa603901a6",
    "0xf35aab7025e9fd596a913ebaa4868718cad424d7",
    "0xf7843b0d0c5974b5da2295917d24ffaa913fa6e4",
    "0xfcd135a008bd38686846ea8f65fcab314dac194a"
];

const main = async () => {
    let network = hre.network.name;
    console.log('upgrade Vault on network-%s', network);

    /********* Local Fork environment impersonating a governance account start*******/
    if (network == 'localhost') {
        await impersonates([governance]);
        const accounts = await ethers.getSigners();
        const nextManagement = accounts[0].address;
        await send.ether(nextManagement, governance, 10 * (10 ** 18));
        //transfer ownership
        let proxyAdmin = await ProxyAdmin.at(proxyAdminAddress);
        let proxyAdminOwner = await proxyAdmin.owner();
        if (proxyAdminOwner == governance) {
            await proxyAdmin.transferOwnership(nextManagement, { from: governance });
        }
    }
    /********* Local Fork environment impersonating a governance account end*******/

    const usdi = await USDi.at(usdiAddr);
    const usdiTotalSupply = BigInt(await usdi.totalSupply());
    const rebasingCreditsPerToken = BigInt(await usdi.rebasingCreditsPerToken());
    const rebasingCreditsPerTokenRevert = BigInt(1e45) / rebasingCreditsPerToken;
    console.log('USDi total supply:%d,rebasingCreditsPerToken:%d,rebasingCreditsPerTokenRevert:%d',
        usdiTotalSupply,
        rebasingCreditsPerToken,
        rebasingCreditsPerTokenRevert);

    const pegTokenShares = [];
    let totalBalance = BigInt(0);
    for (let index = 0; index < usdiHolders.length; index++) {
        const account = usdiHolders[index];
        const usdiBalance = BigInt(await usdi.balanceOf(account));
        totalBalance = totalBalance + usdiBalance;
        pegTokenShares.push(usdiBalance * BigInt(1e27) / rebasingCreditsPerTokenRevert);
        console.log('%s USDi balance:%d', account, usdiBalance);
    }
    console.log('totalBalance:%d', totalBalance);
    console.log('Number(totalBalance):%d,Number(usdiTotalSupply):%d', Number(totalBalance), Number(usdiTotalSupply));
    assert(Number(totalBalance) == Number(usdiTotalSupply));

    //deploy PegToken
    const pegToken = await deployProxy("PegToken", ["USD Peg Token", "USDi", 18, vaultAddr, accessControlProxy]);

    //upgrade Vault
    const vaultArtifacts = await ethers.getContractFactory("Vault");
    let vaultUpgraded = await upgrades.upgradeProxy(vaultAddr, vaultArtifacts);
    console.log('vaultUpgraded:', vaultUpgraded.address);

    const iVault = await IVault.at(vaultAddr);
    console.log('finish upgraded Vault,version:%s', await iVault.getVersion());
    const balanceBefore = await ethers.provider.getBalance(governance);
    console.log('balanceBefore:%d', ethers.utils.formatEther(balanceBefore.toString()));

    //deploy VaultBuffer
    const vaultBuffer = await deployProxy("VaultBuffer", ['USD Peg Token Ticket', 'tUSDi', vaultAddr, pegToken.address, accessControlProxy]);

    //deploy VaultAdmin
    const vaultAdmin = await deploy("VaultAdmin");

    console.log('Vault setup start.');
    await iVault.setAdminImpl(vaultAdmin.address, { from: governance });
    await iVault.setPegTokenAddress(pegToken.address, { from: governance });
    await iVault.setVaultBufferAddress(vaultBuffer.address, { from: governance });
    await iVault.setUnderlyingUnitsPerShare(rebasingCreditsPerTokenRevert,{ from: governance });
    await iVault.setRebaseThreshold(10,{ from: governance });
    await iVault.setMaxTimestampBetweenTwoReported(604800,{ from: governance });
    await iVault.setEmergencyShutdown(true, { from: governance });
    console.log('Vault setup end.');

    //migrate
    const signedPegToken = await PegToken.at(pegToken.address);
    await signedPegToken.migrate(usdiHolders, pegTokenShares, { from: governance });
    
    await iVault.setEmergencyShutdown(false, { from: governance });
    console.log('Migrate finish!');
    console.log('UnderlyingUnit per share:%d', await iVault.underlyingUnitsPerShare());
    console.log('PegToken total shares:%d', await pegToken.totalShares());
    console.log('PegToken total supply:%d', await pegToken.totalSupply());
    console.log('Vault total assets:%d', await iVault.totalAssets());


    for (let index = 0; index < usdiHolders.length; index++) {
        const account = usdiHolders[index];
        const pegTokenShare = await pegToken.sharesOf(account);
        const pegTokenBalance = await pegToken.balanceOf(account);
        console.log('%s PegToken share:%d balance:%d', account, pegTokenShare, pegTokenBalance);
    }

    const balanceAfter = await ethers.provider.getBalance(governance);
    console.log('balanceAfter:%d', ethers.utils.formatEther(balanceAfter.toString()));
    console.log('use eth:%d', ethers.utils.formatEther((balanceBefore - balanceAfter).toString()));


    // upgrade Vault/All strategies/Harvester
    let upgradeStrategies = [];
    for (let i = 0; i < contractsList.length; i++) {
        let needUpgrade = contractsList[i]['upgrade'];
        if (needUpgrade){
            let contractName = contractsList[i]['contract_name'];
            let deployedAddress = contractsList[i]['contract_deployed_address'];

            try{
                console.log('start upgrade contract: %s,address: %s',contractName,deployedAddress);
                const contractArtifacts = await ethers.getContractFactory(contractName);
                let upgraded = await upgrades.upgradeProxy(deployedAddress,contractArtifacts);
                console.log('finish upgraded contract: %s',contractName);
                if(contractName.indexOf('Strategy') !== -1) {
                    upgradeStrategies.push(deployedAddress);
                }
            }catch(e){
                console.log('upgrade %s error:',contractName,e.message);
            }
        }
    }
    console.log('upgradeStrategies:',upgradeStrategies);

};

async function impersonates(targetAccounts) {
    for (i = 0; i < targetAccounts.length; i++) {
        await hre.network.provider.request({
            method: 'hardhat_impersonateAccount',
            params: [targetAccounts[i]],
        });
    }
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
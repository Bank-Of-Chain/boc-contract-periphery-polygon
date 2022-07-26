const {
    ethers,
} = require('hardhat');
const {
    impersonates
} = require('../utils/top-up-utils');

const Vault = hre.artifacts.require("IVault");
const AccessControlProxy = hre.artifacts.require("AccessControlProxy");
const ProxyAdmin = hre.artifacts.require('@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol:ProxyAdmin');

async function main() {
    // Production vault address
    const vaultAddress = '0xd3feAe6c4fdfDE73Bd2fE99c8fE6944904DAA68A'
    // Production administrator account, need to be disguised
    const admin = '0xc791B4A9B10b1bDb5FBE2614d389f0FE92105279'
    await impersonates([admin])

    const accounts = await ethers.getSigners();
    const nextManagement = accounts[0].address;
    const keeper = accounts[19].address;

    // get vault's accessControlProxy
    const accessControlProxyAddress = await (await Vault.at(vaultAddress)).accessControlProxy()
    console.log('access control proxy address：', accessControlProxyAddress)
    // Add account[0] to the administrator privilege group
    const constract = await AccessControlProxy.at(accessControlProxyAddress)

    const govRole = await constract.DEFAULT_ADMIN_ROLE()
    await constract.grantRole(govRole, nextManagement, {
        from: admin
    })

    const role = await constract.VAULT_ROLE()
    console.log('Permissions：', role)
    try {
        await constract.grantRole(role, nextManagement, {
            from: admin
        })
        await constract.grantRole(role, keeper, {
            from: admin
        })
        console.log('Add permission successfully!')
    } catch (e) {
        console.log('Add permission fail!', e)
    }
    // Determine whether the permission is added successfully
    console.log('Permission verification admin：', await constract.isVaultOrGov(admin))
    console.log('Permission Verification nextManagement：', await constract.isVaultOrGov(nextManagement))

    console.log('Transferring ownership of ProxyAdmin...');
    const proxyAdmin = await ProxyAdmin.at('0x2BFe17F338Cb4554FDb949ddA5798c903c4a179A');
    // The owner of the ProxyAdmin can upgrade our contracts
    await proxyAdmin.transferOwnership(nextManagement, {from: admin});
    console.log('Transferred ownership of ProxyAdmin to:', nextManagement);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });

const {
	ethers
} = require('hardhat');

const {
	isEmpty,
	get,
	reduce,
	keys,
	includes
} = require('lodash');
const inquirer = require('inquirer');

const MFC_TEST = require('../config/mainnet-fork-test-config');
const MFC_PRODUCTION = require('../config/mainnet-fork-config');
const {
	strategiesList
} = require('../config/strategy-config.js');

const {
	deploy,
	deployProxy
} = require('../utils/deploy-utils');

// === Constants === //
const UniswapV3UsdcWeth500RiskOnVault = 'UniswapV3UsdcWeth500RiskOnVault';
const UniswapV3RiskOnHelper = 'UniswapV3RiskOnHelper';
const Treasury = 'contracts/riskon/Treasury.sol:Treasury';
const AccessControlProxy = 'AccessControlProxy';
const VaultFactory = 'VaultFactory';
const USDC_ADDRESS = 'USDC_ADDRESS';
const WETH_ADDRESS = 'WETH_ADDRESS';

// Used to store address information during deployment
// ** Note that if an address is configured in this object, no publishing operation will be performed.
const addressMap = {
	...reduce(strategiesList, (rs, i) => {
		rs[i.name] = '';
		return rs
	}, {}),
	[UniswapV3UsdcWeth500RiskOnVault]: '',
	[AccessControlProxy]: '',
	[UniswapV3RiskOnHelper]: '',
	[Treasury]: '',
	[VaultFactory]: '',
	[WETH_ADDRESS]: MFC_PRODUCTION.WETH_ADDRESS,
	[USDC_ADDRESS]: MFC_PRODUCTION.USDC_ADDRESS
}

/**
 * Add dependent addresses to addressMap
 * @param {string} dependName Name of the dependency
 * @returns
 */
 const addDependAddress = async (dependName) => {
	const questions = [{
		type: 'input',
		name: 'address',
		message: `${dependName} The contract address is missing, please enter the latest address\n`,
		validate(value) {
			console.log('Start to continue calibration：', value);
			const pass = value.match(
				/^0x[a-fA-F0-9]{40}$/
			);
			if (pass) {
				return true;
			}
			return 'Please enter the correct contract address';
		}
	}];

	return inquirer.prompt(questions).then((answers) => {
		const {
			address
		} = answers;
		if (!isEmpty(address)) {
			addressMap[dependName] = address;
		}
		return;
	});
}

/**
 * Basic Deployment Logic
 * @param {string} contractName Contract Name
 * @param {string[]} depends Contract Fronting Dependency
 */
const depolyBase = async (contractName, depends = []) => {
	console.log(` 🛰  Deploying: ${contractName}`);
	const keyArray = keys(addressMap);
	const nextParams = [];
	for (const depend of depends) {
		if (includes(keyArray, depend)) {
			if (isEmpty(get(addressMap, depend))) {
				await addDependAddress(depend);
			}
			nextParams.push(addressMap[depend]);
			continue;
		}
		nextParams.push(depend);
	}

	console.log("nextParams is",nextParams);

	try {
		const constract = await deploy(contractName, nextParams);
		await constract.deployed();
		addressMap[contractName] = constract.address;
		return constract;
	} catch (error) {
		console.log('Contract Deployment Exceptions：', error);
		const questions = [{
			type: 'list',
			name: 'confirm',
			message: `${contractName} The contract release failed, do you want to retry？\n`,
			choices: [{
					key: 'y',
					name: 'Try again',
					value: 1,
				},
				{
					key: 'n',
					name: 'Exit Deployment',
					value: 2,
				},
				{
					key: 's',
					name: 'Ignore this deployment exception',
					value: 3,
				},
			],
		}];

		return inquirer.prompt(questions).then((answers) => {
			const {
				confirm
			} = answers;
			if (confirm === 1) {
				return depolyBase(contractName, depends);
			} else if (confirm === 2) {
				return process.exit(0)
			}
			return
		});
	}
}

/**
 * Basic Deployment Logic
 * @param {string} contractName Contract Name
 * @param {string[]} depends Contract Fronting Dependency
 */
const deployProxyBase = async (contractName, depends = []) => {
	console.log(` 🛰  Deploying[Proxy]: ${contractName}`);
	const keyArray = keys(addressMap);
	const nextParams = [];
	for (const depend of depends) {
		if (includes(keyArray, depend)) {
			if (isEmpty(get(addressMap, depend))) {
				await addDependAddress(depend);
			}
			nextParams.push(addressMap[depend]);
			continue;
		}
		nextParams.push(depend);
	}

	try {
		const constract = await deployProxy(contractName, nextParams);
		await constract.deployed();
		addressMap[contractName] = constract.address;
		return constract;
	} catch (error) {
		console.log('Contract Deployment Exceptions：', error);
		const questions = [{
			type: 'list',
			name: 'confirm',
			message: `${contractName} The contract release failed, do you want to retry？\n`,
			choices: [{
					key: 'y',
					name: 'Try again',
					value: 1,
				},
				{
					key: 'n',
					name: 'Exit Deployment',
					value: 2,
				},
				{
					key: 's',
					name: 'Ignore this deployment exception',
					value: 3,
				},
			],
		}];

		return inquirer.prompt(questions).then((answers) => {
			const {
				confirm
			} = answers;
			if (confirm === 1) {
				return deployProxyBase(contractName, depends);
			} else if (confirm === 2) {
				return process.exit(0)
			}
			return
		});
	}
}

const main = async () => {
    let accessControlProxy;
    let treasury;

    const network = hre.network.name;
	const MFC = network === 'localhost' || network === 'hardhat' ? MFC_TEST : MFC_PRODUCTION
	console.log('\n\n 📡 Deploying... At %s Network \n', network);
	const accounts = await ethers.getSigners();
	assert(accounts.length > 0, 'Need a Signer!');
	const governor = accounts[0].address;
	const delegator = process.env.DELEGATOR_ADDRESS || get(accounts, '16.address', '');
	const vaultManager = process.env.VAULT_MANAGER_ADDRESS || get(accounts, '17.address', '');
	const keeper = process.env.KEEPER_ACCOUNT_ADDRESS || get(accounts, '18.address', '');
	console.log('governor address:%s',governor);
	console.log('delegator address:%s',delegator);
	console.log('vaultManager address:%s',vaultManager);
	console.log('usd keeper address:%s',keeper);

	if (isEmpty(addressMap[AccessControlProxy])) {
		accessControlProxy = await deployProxyBase(AccessControlProxy, [governor, delegator, vaultManager, keeper]);
	}

	if (isEmpty(addressMap[UniswapV3RiskOnHelper])) {
		uniswapV3RiskOnHelper = await deployProxyBase(UniswapV3RiskOnHelper, []);
	}

	if (isEmpty(addressMap[Treasury])) {
		treasury = await deployProxyBase(Treasury, [AccessControlProxy,MFC_PRODUCTION.WETH_ADDRESS,MFC_PRODUCTION.USDC_ADDRESS,keeper]);
	}

	// only one vault impl now
	if (isEmpty(addressMap[UniswapV3UsdcWeth500RiskOnVault])) {
		uniswapV3UsdcWeth500RiskOnVaultImpl = await depolyBase(UniswapV3UsdcWeth500RiskOnVault, []);
	}

	// can use multi vault impl on VaultFactory
	if (isEmpty(addressMap[VaultFactory])) {
		vaultFactory = await deployProxyBase(VaultFactory, [[addressMap[UniswapV3UsdcWeth500RiskOnVault]], AccessControlProxy, UniswapV3RiskOnHelper, Treasury]);
	}

	console.table(addressMap);
};

main().then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});

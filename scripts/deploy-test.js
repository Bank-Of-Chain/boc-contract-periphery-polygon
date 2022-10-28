const {
	ethers
} = require('hardhat');

const BigNumber = require('bignumber.js');
const {
	isEmpty,
	get,
	reduce,
	keys,
	includes,
	isEqual
} = require('lodash');
const inquirer = require('inquirer');

const MFC_TEST = require('../config/mainnet-fork-test-config');
const MFC_PRODUCTION = require('../config/mainnet-fork-config');
const {
	strategiesList
} = require('../config/strategy/strategy-config.js');

const {
	deploy,
	deployProxy
} = require('../utils/deploy-utils');
const os = require("os");
const axios = require('axios');
const hardhatConfig = require('../hardhat.config');

// === Utils === //
const VaultContract = hre.artifacts.require("IVault");
const ValueInterpreterContract = hre.artifacts.require("ValueInterpreter");
const ChainlinkPriceFeedContract = hre.artifacts.require("ChainlinkPriceFeed");

// === Constants === //
const Vault = 'Vault';
const VaultBuffer = 'VaultBuffer';
const VaultAdmin = 'VaultAdmin';
const PegToken = 'PegToken';
const Treasury = 'Treasury';
const ValueInterpreter = 'ValueInterpreter';
const ParaSwapV5Adapter = 'ParaSwapV5Adapter';
const ChainlinkPriceFeed = 'ChainlinkPriceFeed';
const ExchangeAggregator = 'ExchangeAggregator';
const AccessControlProxy = 'AccessControlProxy';
const AggregatedDerivativePriceFeed = 'AggregatedDerivativePriceFeed';
const OneInchV4Adapter = 'OneInchV4Adapter';
const Harvester = 'Harvester';
const Dripper = 'Dripper';
const USDT_ADDRESS = 'USDT_ADDRESS';
const Verification = 'Verification';
const INITIAL_ASSET_LIST = [
	MFC_PRODUCTION.USDT_ADDRESS,
	MFC_PRODUCTION.USDC_ADDRESS,
	MFC_PRODUCTION.DAI_ADDRESS,
]

// Used to store address information during deployment
// ** Note that if an address is configured in this object, no publishing operation will be performed.
const addressMap = {
	...reduce(strategiesList, (rs, i) => {
		rs[i.name] = '';
		return rs
	}, {}),
	Curve3CrvStrategy: '',
	AaveUsdtStrategy: '',
	AaveUsdcStrategy: '',
	QuickswapDaiUsdtStrategy: '',
	QuickswapUsdcDaiStrategy: '',
	QuickswapUsdcUsdtStrategy: '',
	SushiUsdcDaiStrategy: '',
	SushiUsdcUsdtStrategy: '',
	BalancerUsdcUsdtDaiTusdStrategy: '',
	Synapse4UStrategy: '',
	StargateUsdcStrategy: '',
	StargateUsdtStrategy: '',
	[Verification]: '0xa43bF64d99cabcCE432310c54D0184d4D5A7d6c4',
	[AccessControlProxy]: '',
	[ChainlinkPriceFeed]: '',
	[AggregatedDerivativePriceFeed]: '',
	[ValueInterpreter]: '',
	[OneInchV4Adapter]: '',
	[ParaSwapV5Adapter]: '',
	[ExchangeAggregator]: '',
	[Treasury]: '',
	[PegToken]: '',
	[Vault]: '',
	[VaultBuffer]: '',
	[Harvester]: '',
	[Dripper]: '',
	[USDT_ADDRESS]: MFC_PRODUCTION.USDT_ADDRESS,
	[VaultAdmin]: '',
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
const deployProxyBase = async (contractName, depends = [], customParams = [], name = null) => {
	console.log(` 🛰  Deploying[Proxy]: ${contractName}`);
	const keyArray = keys(addressMap);
	const dependParams = [];
	for (const depend of depends) {
		if (includes(keyArray, depend)) {
			if (isEmpty(get(addressMap, depend))) {
				await addDependAddress(depend);
			}
			dependParams.push(addressMap[depend]);
			continue;
		}
		dependParams.push(depend);
	}

	try {
		const allParams = [
			...dependParams,
			...customParams
		];
		const constract = await deployProxy(contractName, allParams);
		await constract.deployed();
		addressMap[name == null ? contractName : name] = constract.address;
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

/**
 * Add strategy to vault
 */
const addStrategies = async (vault, allArray, increaseArray) => {
	const isFirst = isEqual(allArray, increaseArray);
	if (isFirst) {
		console.log('All strategies:');
		console.table(allArray);
	} else {
		console.log('All strategies:');
		console.table(allArray);
		console.log('New Strategy:');
		console.table(increaseArray);
	}

	const questions = [{
		type: 'list',
		name: 'type',
		message: 'Please select the list of policies to be added？\n',
		choices: isFirst ? [{
			key: 'y',
			name: 'All strategies',
			value: 1,
		}, {
			key: 'n',
			name: 'Exit, I will not add!',
			value: 0,
		}] : [{
			key: 'y',
			name: 'All strategies',
			value: 1,
		}, {
			key: 'n',
			name: 'Add new Strategy',
			value: 2,
		}, {
			key: 'n',
			name: 'Exit, I will not add!',
			value: 0,
		}],
	}];
	if (isEmpty(vault)) {
		vault = await VaultContract.at(addressMap[Vault]);
	}
	let type = process.env.STRATEGY_TYPE_VALUE;
	if (!type) {
		type = await inquirer.prompt(questions).then((answers) => {
			const {
				type
			} = answers;
			return type;
		});
	}
	if (!type) {
		return
	}
	const nextArray = type === 1 ? allArray : increaseArray

	return vault.addStrategy(nextArray.map(item => {
		return {
			strategy: item.strategy,
			profitLimitRatio: item.profitLimitRatio,
			lossLimitRatio: item.lossLimitRatio
		}
	}));
}

const main = async () => {
	let verification;
	let vault;
	let vaultAdmin;
	let vaultBuffer;
	let accessControlProxy;
	let chainlinkPriceFeed;
	let aggregatedDerivativePriceFeed;
	let oneInchV4Adapter;
	let paraSwapV5Adapter;
	let valueInterpreter;
	let treasury;
	let exchangeAggregator;
	let pegToken;
	let harvester;
	let dripper;

	const network = hre.network.name;
	const MFC = network === 'localhost' || network === 'hardhat' ? MFC_TEST : MFC_PRODUCTION
	console.log('\n\n 📡 Deploying... At %s Network \n', network);
	const accounts = await ethers.getSigners();
	assert(accounts.length > 0, 'Need a Signer!');
	const management = accounts[0].address;
	const keeper = process.env.KEEPER_ACCOUNT_ADDRESS || get(accounts, '19.address', '');

	if (isEmpty(addressMap[AccessControlProxy])) {
		accessControlProxy = await deployProxyBase(AccessControlProxy, [management, management, management, keeper]);
	}

	if (isEmpty(addressMap[ChainlinkPriceFeed])) {
		let primitives = new Array();
		let aggregators = new Array();
		let heartbeats = new Array();
		let rateAssets = new Array();
		for (const key in MFC.CHAINLINK.aggregators) {
			const value = MFC.CHAINLINK.aggregators[key];
			primitives.push(value.primitive);
			aggregators.push(value.aggregator);
			heartbeats.push(value.heartbeat);
			rateAssets.push(value.rateAsset);
		}
		let basePeggedPrimitives = new Array();
		let basePeggedRateAssets = new Array();
		for (const key in MFC.CHAINLINK.basePegged) {
			const value = MFC.CHAINLINK.basePegged[key];
			basePeggedPrimitives.push(value.primitive);
			basePeggedRateAssets.push(value.rateAsset);
		}
		chainlinkPriceFeed = await depolyBase(ChainlinkPriceFeed, [
			MFC.CHAINLINK.ETH_USD_AGGREGATOR,
			MFC.CHAINLINK.ETH_USD_HEARTBEAT,
			primitives,
			aggregators,
			heartbeats,
			rateAssets,
			basePeggedPrimitives,
			basePeggedRateAssets,
			AccessControlProxy
		]);
	}

	if (isEmpty(addressMap[AggregatedDerivativePriceFeed])) {
		let derivatives = [];
		let priceFeeds = [];
		aggregatedDerivativePriceFeed = await depolyBase(AggregatedDerivativePriceFeed, [derivatives, priceFeeds, AccessControlProxy]);
	}

	if (isEmpty(addressMap[ValueInterpreter])) {
		valueInterpreter = await depolyBase(ValueInterpreter, [ChainlinkPriceFeed, AggregatedDerivativePriceFeed, AccessControlProxy]);
	}

	if (isEmpty(addressMap[OneInchV4Adapter])) {
		oneInchV4Adapter = await depolyBase(OneInchV4Adapter);
	}
	if (isEmpty(addressMap[ParaSwapV5Adapter])) {
		paraSwapV5Adapter = await depolyBase(ParaSwapV5Adapter);
	}

	if (isEmpty(addressMap[ExchangeAggregator])) {
		const adapterArray = [addressMap[OneInchV4Adapter], addressMap[ParaSwapV5Adapter]];
		exchangeAggregator = await depolyBase(ExchangeAggregator, [adapterArray, AccessControlProxy]);
	}

	if (isEmpty(addressMap[VaultAdmin])) {
		vaultAdmin = await depolyBase(VaultAdmin);
	}

	if (isEmpty(addressMap[Treasury])) {
		treasury = await deployProxyBase(Treasury, [AccessControlProxy]);
	}

	let cVault;
	if (isEmpty(addressMap[Vault])) {
		vault = await deployProxyBase(Vault, [AccessControlProxy, Treasury, ExchangeAggregator, ValueInterpreter]);
		cVault = await VaultContract.at(addressMap[Vault]);
		await vault.setAdminImpl(vaultAdmin.address);
		for (let i = 0; i < INITIAL_ASSET_LIST.length; i++) {
			const asset = INITIAL_ASSET_LIST[i];
			await cVault.addAsset(asset);
		}
	} else {
		cVault = await VaultContract.at(addressMap[Vault]);
	}

	if (isEmpty(addressMap[PegToken])) {
		console.log(` 🛰  Deploying[Proxy]: ${PegToken}`);
		console.log('vault address=', addressMap[Vault]);
		pegToken = await deployProxy(PegToken, ["USD Peg Token", "USDi", 18, addressMap[Vault], addressMap[AccessControlProxy]], { timeout: 0 });
		await pegToken.deployed();
		addressMap[PegToken] = pegToken.address;
		await cVault.setPegTokenAddress(addressMap[PegToken]);
		// await cVault.setRebaseThreshold(1);
		// await cVault.setUnderlyingUnitsPerShare(new BigNumber(10).pow(18).toFixed());
		// await cVault.setMaxTimestampBetweenTwoReported(604800);
		console.log("maxTimestampBetweenTwoReported:", new BigNumber(await cVault.maxTimestampBetweenTwoReported()).toFixed());
	}

	if (isEmpty(addressMap[VaultBuffer])) {
		console.log(` 🛰  Deploying[Proxy]: ${VaultBuffer}`);
		console.log('vault address=', addressMap[Vault]);
		console.log('usdi address=', addressMap[PegToken]);
		const vaultBuffer = await deployProxy(VaultBuffer, ['USD Peg Token Ticket', 'tUSDi', addressMap[Vault], addressMap[PegToken], addressMap[AccessControlProxy]]);
		await vaultBuffer.deployed();
		addressMap[VaultBuffer] = vaultBuffer.address;
		await cVault.setVaultBufferAddress(addressMap[VaultBuffer]);
	}

	if (isEmpty(addressMap[Dripper])) {
		dripper = await deployProxyBase(Dripper, [AccessControlProxy, Vault, USDT_ADDRESS]);
		await dripper.setDripDuration(7 * 24 * 60 * 60);
	}

	if (isEmpty(addressMap[Harvester])) {
		harvester = await deployProxyBase(Harvester, [AccessControlProxy, Dripper, USDT_ADDRESS, Vault]);
	}

	const allArray = [];
	const increaseArray = [];
	for (const strategyItem of strategiesList) {
		const {
			name,
			contract,
			addToVault,
			profitLimitRatio,
			lossLimitRatio,
			customParams
		} = strategyItem
		let strategyAddress = addressMap[name];
		if (isEmpty(strategyAddress)) {
			const deployStrategy = await deployProxyBase(contract, [Vault, Harvester], [name, ...customParams],name);
			if (addToVault) {
				strategyAddress = deployStrategy.address;
				increaseArray.push({
					name,
					strategy: strategyAddress,
					profitLimitRatio,
					lossLimitRatio,
				})
			}
		}
		allArray.push({
			name,
			strategy: strategyAddress,
			profitLimitRatio,
			lossLimitRatio,
		})
	}

	await addStrategies(cVault, allArray, increaseArray);
	console.log('getStrategies=', await cVault.getStrategies());
	console.table(addressMap);

	if (hre.network.name == 'localhost') {
		console.log('start set apollo config');
		const {clusterName,host} = await get_apollo_cluster_name();
		console.log(clusterName,host);
		const blockNumber = hardhatConfig.networks.hardhat.forking.blockNumber;
		await modify_apollo_config('boc.networks.polygon.startBlock', blockNumber, clusterName, host);
		for (let key in addressMap) {
			if (Object.prototype.hasOwnProperty.call(addressMap, key)) {
				if (key == 'Vault') {
					await modify_apollo_config('boc.networks.polygon.vaultAddress', addressMap[key], clusterName, host);
				} else if (key == 'VaultBuffer') {
					await modify_apollo_config('boc.networks.polygon.vaultBufferAddress', addressMap[key], clusterName, host);
				} else if (key == 'PegToken') {
					await modify_apollo_config('boc.networks.polygon.pegTokenAddress', addressMap[key], clusterName, host);
				} else if (key == 'TestAdapter') {
					await modify_apollo_config('boc.networks.polygon.TestAdapter', addressMap[key], clusterName, host);
				} else if (key == 'Verification') {
					await modify_apollo_config('boc.networks.polygon.verificationAddress', addressMap[key], clusterName, host);
				} else if (key == 'Harvester') {
					await modify_apollo_config('boc.networks.polygon.harvester', addressMap[key], clusterName, host);
				} else if (key == 'Dripper') {
					await modify_apollo_config('boc.networks.polygon.dripper', addressMap[key], clusterName, host);
				} else {
					await modify_apollo_config(`boc.networks.polygon.${key}`, addressMap[key], clusterName, host);
				}
			}
		}

		await publish_apollo_config(clusterName, host);
		console.log('end set apollo config');
	}
};

const get_apollo_cluster_name = async () =>{
	let windowsIp = '127.0.0.1';
	let localIp = windowsIp;
	let host = '172.31.30.50:8070';
	const osType = os.type();
	const netInfo = os.networkInterfaces();
	if (osType === 'Windows_NT'){
		host = '13.215.137.222:8070';
		for (let devName  in netInfo) {
			const iface = netInfo[devName];
			for (let i = 0; i < iface.length; i++) {
				const alias = iface[i];
				if (alias.family === 'IPv4' && alias.address !== '127.0.0.1' && !alias.internal) {
					localIp = alias.address;
					break;
				}
			}
			if(localIp != windowsIp){
				break;
			}
		}
	} else{
		localIp = netInfo && netInfo.eth0 && netInfo.eth0.length>0 && netInfo.eth0[0].address || windowsIp;
	}
	console.log('localIp',localIp);
	let url = `http://${host}/openapi/v1/envs/DEV/apps/boc-common/clusters/default/namespaces/boc1.application`;
	let config = {
		headers: {
			Authorization:'e9ac544052e7e295e453f414363e8ccf5ff37ff3',
			'Content-Type':'application/json;charset=UTF-8'
		},
		params: {

		}
	};
	let resp =  await axios.get(url, config);
	const itemData =  resp.data?.items.find(function (item) {
		return item.key == localIp;
	});
	let clusterName = 'local';
	if(itemData && itemData.value){
		clusterName = itemData.value;
	}
	return {clusterName,host};
}

const publish_apollo_config = async (clusterName,host) =>{
	let url = `http://${host}/openapi/v1/envs/DEV/apps/boc-common/clusters/${clusterName}/namespaces/boc1.application/releases`;
	let questBody = {
		"releaseTitle": new Date().toLocaleDateString(),
		"releaseComment": 'publish smart contract',
		"releasedBy":"apollo"
	};
	let config = {
		headers: {
			Authorization:'e9ac544052e7e295e453f414363e8ccf5ff37ff3',
			'Content-Type':'application/json;charset=UTF-8'
		},
		params: {
			createIfNotExists: true
		}
	};
	await axios.post(url, questBody, config);
}

const modify_apollo_config = async (key,value,clusterName,host) =>{
	let url = `http://${host}/openapi/v1/envs/DEV/apps/boc-common/clusters/${clusterName}/namespaces/boc1.application/items/${key}`;
	let questBody = {
		"key": key,
		"value": value,
		"dataChangeLastModifiedBy":"apollo",
		"dataChangeCreatedBy":"apollo"
	};
	let config = {
		headers: {
			Authorization:'e9ac544052e7e295e453f414363e8ccf5ff37ff3',
			'Content-Type':'application/json;charset=UTF-8'
		},
		params: {
			createIfNotExists: true
		}
	};
	await axios.put(url, questBody, config);
}

main().then(() => process.exit(0))
	.catch(error => {
		console.error(error);
		process.exit(1);
	});

const {aaveStrategies} = require('./strategy-config-aave');
const {balancerStrategies} = require('./strategy-config-balancer');
const {curveStrategies} = require('./strategy-config-curve');
const {dodoStrategies} = require('./strategy-config-dodo');
const {quickswapStrategies} = require('./strategy-config-quickswap');
const {stargateStrategies} = require('./strategy-config-stargate');
const {sushiStrategies} = require('./strategy-config-sushi');
const {synapseStrategies} = require('./strategy-config-synapse');
const {uniswapStrategies} = require('./strategy-config-uniswap');

const strategiesList = [
    ...aaveStrategies,
    ...balancerStrategies,
    ...curveStrategies,
    ...dodoStrategies,
    ...quickswapStrategies,
    ...stargateStrategies,
    ...sushiStrategies,
    ...synapseStrategies,
    ...uniswapStrategies
]

exports.strategiesList = strategiesList

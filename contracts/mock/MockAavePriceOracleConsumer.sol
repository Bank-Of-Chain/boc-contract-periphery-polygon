// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../external/aave/IPriceOracleGetter.sol";

/// @title MockAavePriceOracleConsumer
/// @notice The mock contract of Aave's PriceOracleConsumer contract
contract MockAavePriceOracleConsumer is IPriceOracleGetter {

    mapping(address => uint) private priceMap;
    address private constant originPriceOracleConsumerAddr = 0xb023e699F5a33916Ea823A16485e259257cA8Bd1;

    constructor(){
        IPriceOracleGetter originPriceOracle = IPriceOracleGetter(originPriceOracleConsumerAddr);
        // init asset price
        // USDC
        address USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        priceMap[USDC] = originPriceOracle.getAssetPrice(USDC);
        // WETH
        address WETH = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
        priceMap[WETH] = originPriceOracle.getAssetPrice(WETH);
        // WWMATIC
        address WWMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        priceMap[WWMATIC] = originPriceOracle.getAssetPrice(WWMATIC);
    }

    /// @notice Sets the underlying _price of a `_asset` asset
    /// @param _asset The `_asset` to get the underlying `_price` of
    /// @param _price The new value of ``_asset``'s price
    function setAssetPrice(address _asset, uint256 _price) external {
        priceMap[_asset] = _price;
    }

    /// @notice Gets the price of a `_asset` asset
    /// @param _asset It is this `_asset` that gets it the price of
    /// @return the price of a `_asset` asset (scaled by 1e18).
    ///  Zero means the `_price` is unavailable.
    function getAssetPrice(address _asset) public override view returns (uint){
        return priceMap[_asset];
    }

    /// @notice Gets a list of prices from a list of assets addresses
    /// @param _assets The list of assets addresses
    function getAssetsPrices(address[] calldata _assets) external override view returns (uint256[] memory){
        uint256 _assetsLength = _assets.length;
        uint256[] memory _prices = new uint256[](_assetsLength);
        for (uint256 i = 0; i < _assetsLength; i++) {
            _prices[i] = getAssetPrice(_assets[i]);
        }
        return _prices;
    }
}

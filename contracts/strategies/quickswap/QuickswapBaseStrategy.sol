// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "hardhat/console.sol";
import "boc-contract-core/contracts/strategy/BaseClaimableStrategy.sol";
import "./../../enums/ProtocolEnum.sol";
import "./../../utils/actions/UniswapV2LiquidityActionsMixin.sol";

import "./../../external/uniswap/IUniswapV2Pair.sol";
import "./../../external/quickswap/IStakingRewards.sol";

abstract contract QuickswapBaseStrategy is BaseClaimableStrategy, UniswapV2LiquidityActionsMixin {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public constant routerAddress = address(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);
    // QUICK
    address public constant rewardsToken = address(0xf28164A485B0B2C90639E47b0f377b4a438a16B1);

    address internal pairToken0;
    address internal pairToken1;

    IUniswapV2Pair internal uniswapV2Pair;

    IStakingRewards internal stakingRewards;

    function _initialize(
        address _vault,
        address _harvester,
        address _uniswapV2Pair,
        address _stakingPool
    ) internal {
        uniswapV2Pair = IUniswapV2Pair(_uniswapV2Pair);
        stakingRewards = IStakingRewards(_stakingPool);
        pairToken0 = uniswapV2Pair.token0();
        pairToken1 = uniswapV2Pair.token1();
        address[] memory _wants = new address[](2);
        _wants[0] = pairToken0;
        _wants[1] = pairToken1;
        super._initialize(_vault, _harvester, uint16(ProtocolEnum.Quickswap), _wants);
        _initializeUniswapV2(routerAddress);
    }

    function getVersion() external pure override returns (string memory) {
        return "1.0.1";
    }

    function getWantsInfo()
        public
        view
        override
        returns (address[] memory _assets, uint256[] memory _ratios)
    {
        (uint112 reserve0, uint112 reserve1, ) = uniswapV2Pair.getReserves();
        _assets = wants;
        _ratios = new uint256[](2);
        _ratios[0] = reserve0;
        _ratios[1] = reserve1;
    }

    function getOutputsInfo()
        external
        view
        virtual
        override
        returns (OutputInfo[] memory outputsInfo)
    {
        outputsInfo = new OutputInfo[](1);
        OutputInfo memory info0 = outputsInfo[0];
        info0.outputCode = 0;
        info0.outputTokens = wants;
    }

    function getPositionDetail()
        public
        view
        override
        returns (
            address[] memory _tokens,
            uint256[] memory _amounts,
            bool isUsd,
            uint256 usdValue
        )
    {
        _tokens = wants;
        _amounts = new uint256[](2);
        (uint112 reserve0, uint112 reserve1, ) = uniswapV2Pair.getReserves();
        uint256 totalSupply = uniswapV2Pair.totalSupply();
        uint256 lpAmount = balanceOfLpToken();
        _amounts[0] = (uint256(reserve0) * lpAmount) / totalSupply + balanceOfToken(_tokens[0]);
        _amounts[1] = (uint256(reserve1) * lpAmount) / totalSupply + balanceOfToken(_tokens[1]);
    }

    function balanceOfLpToken() public view returns (uint256 lpAmount) {
        lpAmount = stakingRewards.balanceOf(address(this));
    }

    function valueOfLpToken() public view returns (uint256 value) {
        uint256 totalSupply = uniswapV2Pair.totalSupply();
        (uint112 reserve0, uint112 reserve1, ) = uniswapV2Pair.getReserves();
        uint256 lpDecimalUnit = decimalUnitOfToken(address(uniswapV2Pair));
        uint256 part0 = (uint256(reserve0) * (lpDecimalUnit)) / totalSupply;
        uint256 part1 = (uint256(reserve1) * (lpDecimalUnit)) / totalSupply;
        if (part0 > 0) {
            value += queryTokenValue(pairToken0, part0);
        }
        if (part1 > 0) {
            value += queryTokenValue(pairToken1, part1);
        }
    }

    function get3rdPoolAssets() external view override returns (uint256 targetPoolTotalAssets) {
        uint256 totalSupply = stakingRewards.totalSupply();
        uint256 pricePerShare = valueOfLpToken();
        targetPoolTotalAssets =
            (totalSupply * pricePerShare) /
            decimalUnitOfToken(stakingRewards.stakingToken());
    }

    function claimRewards()
        internal
        override
        returns (address[] memory _rewardsTokens, uint256[] memory _claimAmounts)
    {
        _rewardsTokens = new address[](1);
        _rewardsTokens[0] = rewardsToken;
        stakingRewards.getReward();
        _claimAmounts = new uint256[](1);
        _claimAmounts[0] = balanceOfToken(rewardsToken);
    }

    function depositTo3rdPool(address[] memory _assets, uint256[] memory _amounts)
        internal
        override
    {
        uint256 liquidity = __uniswapV2Lend(
            address(this),
            _assets[0],
            _assets[1],
            _amounts[0],
            _amounts[1],
            0,
            0
        );

        if (liquidity > 0) {
            IERC20Upgradeable(address(uniswapV2Pair)).safeApprove(address(stakingRewards), 0);
            IERC20Upgradeable(address(uniswapV2Pair)).safeApprove(
                address(stakingRewards),
                liquidity
            );
            stakingRewards.stake(liquidity);
            console.log("_deposit2:%d", liquidity);
        }
    }

    function withdrawFrom3rdPool(uint256 _withdrawShares, uint256 _totalShares,uint256 _outputCode) internal override {
        uint256 _lpAmount = (balanceOfLpToken() * _withdrawShares) / _totalShares;
        if (_lpAmount > 0) {
            stakingRewards.withdraw(_lpAmount);
            __uniswapV2Redeem(
                address(this),
                address(uniswapV2Pair),
                _lpAmount,
                pairToken0,
                pairToken1,
                0,
                0
            );
        }
    }

}

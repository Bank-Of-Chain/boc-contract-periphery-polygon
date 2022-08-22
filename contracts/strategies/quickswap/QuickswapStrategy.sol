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

contract QuickswapStrategy is BaseClaimableStrategy, UniswapV2LiquidityActionsMixin {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public constant ROUTER_ADDRESS = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
    // QUICK
    address public constant REWARD_TOKEN = 0xf28164A485B0B2C90639E47b0f377b4a438a16B1;

    address internal pairToken0;
    address internal pairToken1;

    IUniswapV2Pair internal uniswapV2Pair;

    IStakingRewards internal stakingRewards;

    function initialize(
        address _vault,
        address _harvester,
        string memory _name,
        address _uniswapV2Pair,
        address _stakingPool
    ) external initializer {
        uniswapV2Pair = IUniswapV2Pair(_uniswapV2Pair);
        stakingRewards = IStakingRewards(_stakingPool);
        pairToken0 = uniswapV2Pair.token0();
        pairToken1 = uniswapV2Pair.token1();
        address[] memory _wants = new address[](2);
        _wants[0] = pairToken0;
        _wants[1] = pairToken1;
        super._initialize(_vault, _harvester, _name, uint16(ProtocolEnum.Quickswap), _wants);
        _initializeUniswapV2(ROUTER_ADDRESS);
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
        (uint112 _reserve0, uint112 _reserve1, ) = uniswapV2Pair.getReserves();
        _assets = wants;
        _ratios = new uint256[](2);
        _ratios[0] = _reserve0;
        _ratios[1] = _reserve1;
    }

    function getOutputsInfo() external view virtual override returns (OutputInfo[] memory _outputsInfo) {
        _outputsInfo = new OutputInfo[](1);
        OutputInfo memory _info0 = _outputsInfo[0];
        _info0.outputCode = 0;
        _info0.outputTokens = wants;
    }

    function getPositionDetail()
        public
        view
        override
        returns (
            address[] memory _tokens,
            uint256[] memory _amounts,
            bool _isUsd,
            uint256 _usdValue
        )
    {
        _tokens = wants;
        _amounts = new uint256[](2);
        (uint112 _reserve0, uint112 _reserve1, ) = uniswapV2Pair.getReserves();
        uint256 _totalSupply = uniswapV2Pair.totalSupply();
        uint256 _lpAmount = balanceOfLpToken();
        _amounts[0] = (uint256(_reserve0) * _lpAmount) / _totalSupply + balanceOfToken(_tokens[0]);
        _amounts[1] = (uint256(_reserve1) * _lpAmount) / _totalSupply + balanceOfToken(_tokens[1]);
    }

    function balanceOfLpToken() public view returns (uint256 _lpAmount) {
        _lpAmount = stakingRewards.balanceOf(address(this));
    }

    function valueOfLpToken() public view returns (uint256 _value) {
        uint256 _totalSupply = uniswapV2Pair.totalSupply();
        (uint112 _reserve0, uint112 _reserve1, ) = uniswapV2Pair.getReserves();
        uint256 _lpDecimalUnit = decimalUnitOfToken(address(uniswapV2Pair));
        uint256 _part0 = (uint256(_reserve0) * (_lpDecimalUnit)) / _totalSupply;
        uint256 _part1 = (uint256(_reserve1) * (_lpDecimalUnit)) / _totalSupply;
        if (_part0 > 0) {
            _value += queryTokenValue(pairToken0, _part0);
        }
        if (_part1 > 0) {
            _value += queryTokenValue(pairToken1, _part1);
        }
    }

    function get3rdPoolAssets() external view override returns (uint256 _targetPoolTotalAssets) {
        uint256 _totalSupply = stakingRewards.totalSupply();
        uint256 _pricePerShare = valueOfLpToken();
        _targetPoolTotalAssets =
            (_totalSupply * _pricePerShare) /
            decimalUnitOfToken(stakingRewards.stakingToken());
    }

    function claimRewards()
        internal
        override
        returns (address[] memory _rewardsTokens, uint256[] memory _claimAmounts)
    {
        _rewardsTokens = new address[](1);
        _rewardsTokens[0] = REWARD_TOKEN;
        stakingRewards.getReward();
        _claimAmounts = new uint256[](1);
        _claimAmounts[0] = balanceOfToken(REWARD_TOKEN);
    }

    function depositTo3rdPool(address[] memory _assets, uint256[] memory _amounts) internal override {
        uint256 _liquidity = __uniswapV2Lend(
            address(this),
            _assets[0],
            _assets[1],
            _amounts[0],
            _amounts[1],
            0,
            0
        );

        if (_liquidity > 0) {
            IERC20Upgradeable(address(uniswapV2Pair)).safeApprove(address(stakingRewards), 0);
            IERC20Upgradeable(address(uniswapV2Pair)).safeApprove(address(stakingRewards), _liquidity);
            stakingRewards.stake(_liquidity);
            console.log("_deposit2:%d", _liquidity);
        }
    }

    function withdrawFrom3rdPool(
        uint256 _withdrawShares,
        uint256 _totalShares,
        uint256 _outputCode
    ) internal override {
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

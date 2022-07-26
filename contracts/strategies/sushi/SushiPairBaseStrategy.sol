// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "hardhat/console.sol";
import "./../../enums/ProtocolEnum.sol";
import "boc-contract-core/contracts/strategy/BaseClaimableStrategy.sol";
import "../../external/uniswap/IUniswapV2Router2.sol";
import "../../external/uniswap/IUniswapV2Pair.sol";
import "../../external/sushi/IMiniChef.sol";
import "../../external/sushi/IComplexRewarderTime.sol";
import "../../utils/actions/UniswapV2LiquidityActionsMixin.sol";

abstract contract SushiPairBaseStrategy is BaseClaimableStrategy, UniswapV2LiquidityActionsMixin {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // UniswapV2Router02
    address public constant ROUTER = address(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    // MiniChefV2
    address public constant POOL = address(0x0769fd68dFb93167989C6f7254cd0D766Fb2841F);
    // WMATIC
    address public constant REWARD = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    // SUSHI
    address public constant SUSHI = address(0x0b3F868E0BE5597D5DB7fEB59E1CADBb0fdDa50a);
    // ComplexRewarderTime
    address public constant REWARDER = address(0xa3378Ca78633B3b9b2255EAa26748770211163AE);

    uint256 public poolId;
    address public pair;

    function _initialize(
        address _vault,
        address _harvester,
        uint256 _poolId,
        address _pair
    ) internal {
        address[] memory _wants = new address[](2);
        _wants[0] = IUniswapV2Pair(_pair).token0();
        _wants[1] = IUniswapV2Pair(_pair).token1();
        super._initialize(_vault, _harvester, uint16(ProtocolEnum.Sushi), _wants);
        poolId = _poolId;
        pair = _pair;
        _initializeUniswapV2(ROUTER);
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
        _assets = wants;
        _ratios = new uint256[](2);
        (_ratios[0], _ratios[1], ) = IUniswapV2Pair(pair).getReserves();
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
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        uint256 totalSupply = IUniswapV2Pair(pair).totalSupply();
        uint256 lpAmount = balanceOfLpToken();
        _amounts[0] = (reserve0 * lpAmount) / totalSupply + balanceOfToken(_tokens[0]);
        _amounts[1] = (reserve1 * lpAmount) / totalSupply + balanceOfToken(_tokens[1]);
    }

    function balanceOfLpToken() public view returns (uint256 lpAmount) {
        return IMiniChef(POOL).userInfo(poolId, address(this)).amount;
    }

    function valueOfLpToken() public view returns (uint256) {
        uint256 totalValue;
        address[] memory _wants = wants;
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        if (reserve0 > 0) {
            totalValue += queryTokenValue(_wants[0], reserve0);
        }
        if (reserve1 > 0) {
            totalValue += queryTokenValue(_wants[1], reserve1);
        }
        return (totalValue * decimalUnitOfToken(pair)) / IUniswapV2Pair(pair).totalSupply();
    }

    function get3rdPoolAssets() external view override returns (uint256 targetPoolTotalAssets) {
        address[] memory _wants = wants;
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair).getReserves();
        if (reserve0 > 0) {
            targetPoolTotalAssets += queryTokenValue(_wants[0], reserve0);
        }
        if (reserve1 > 0) {
            targetPoolTotalAssets += queryTokenValue(_wants[1], reserve1);
        }
    }

    function claimRewards()
        internal
        override
        returns (address[] memory _rewardsTokens, uint256[] memory _claimAmounts)
    {
        // get reward
        _rewardsTokens = new address[](2);
        _rewardsTokens[0] = SUSHI;
        _rewardsTokens[1] = REWARD;
        IMiniChef(POOL).harvest(poolId, address(this));
        _claimAmounts = new uint256[](2);
        _claimAmounts[0] = balanceOfToken(SUSHI);
        _claimAmounts[1] = balanceOfToken(REWARD);
    }

    function depositTo3rdPool(address[] memory _assets, uint256[] memory _amounts)
        internal
        override
    {
        // should not deposit if one token is smaller than 1
        if (balanceOfToken(wants[0]) < 1 || balanceOfToken(wants[1]) < 1) {
            return;
        }

        uint256 lpAmount = __uniswapV2Lend(
            address(this),
            _assets[0],
            _assets[1],
            _amounts[0],
            _amounts[1],
            0,
            0
        );

        IERC20Upgradeable(pair).safeApprove(POOL, 0);
        IERC20Upgradeable(pair).safeApprove(POOL, lpAmount);
        IMiniChef(POOL).deposit(poolId, lpAmount, address(this));
        console.log("stakingPool.deposit(pid, liquidity) ok:");
    }

    function withdrawFrom3rdPool(uint256 _withdrawShares, uint256 _totalShares) internal override {
        uint256 _lpAmount = (balanceOfLpToken() * _withdrawShares) / _totalShares;
        if (_lpAmount > 0) {
            IMiniChef(POOL).withdraw(poolId, _lpAmount, address(this));

            __uniswapV2Redeem(address(this), pair, _lpAmount, wants[0], wants[1], 0, 0);
        }
    }

}

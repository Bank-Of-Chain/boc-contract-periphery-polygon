// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "hardhat/console.sol";
import "boc-contract-core/contracts/strategy/BaseClaimableStrategy.sol";
import "./../../enums/ProtocolEnum.sol";
import "./../../external/stargate/IStargateLiquidityPool.sol";
import "./../../external/stargate/IStargateStakePool.sol";
import "./../../external/stargate/IStargatePool.sol";

contract StargateSingleStrategy is BaseClaimableStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    address public constant rewardsTokenSTG = address(0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590);
    IStargateStakePool internal constant stargateStakePool =
        IStargateStakePool(0x8731d54E9D02c286767d56ac03e8037C07e01e98);
    IStargateRouterPool internal stargateRouterPool;
    IStargatePool internal stargatePool;
    uint256 poolId;
    uint256 stakePoolId;

    function initialize(
        address _vault,
        address _harvester,
        string memory _name,
        address _underlying,
        address _router,
        address _lpToken,
        uint256 _poolId,
        uint256 _stakePoolId
    ) external initializer {
        stargatePool = IStargatePool(_lpToken);
        stargateRouterPool = IStargateRouterPool(_router);
        poolId = _poolId;
        stakePoolId = _stakePoolId;

        address[] memory _wants = new address[](1);
        _wants[0] = _underlying;
        super._initialize(_vault, _harvester, _name, uint16(ProtocolEnum.Stargate), _wants);
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
        _ratios = new uint256[](1);
        _ratios[0] = 1e18;
    }

    function getOutputsInfo() external view virtual override returns (OutputInfo[] memory outputsInfo) {
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
        IStargatePool stargatePoolTmp = stargatePool;
        uint256 localDecimals = stargatePoolTmp.localDecimals();
        uint256 decimals = stargatePoolTmp.decimals();
        _tokens = wants;
        _amounts = new uint256[](1);
        _amounts[0] = balanceOfLpToken() * 10**(localDecimals - decimals) + balanceOfToken(_tokens[0]);
    }

    function balanceOfLpToken() private view returns (uint256 lpAmount) {
        (lpAmount, ) = stargateStakePool.userInfo(stakePoolId, address(this));
    }

    function get3rdPoolAssets() external view override returns (uint256) {
        IStargatePool stargatePoolTmp = stargatePool;
        uint256 localDecimals = stargatePoolTmp.localDecimals();
        uint256 decimals = stargatePoolTmp.decimals();
        uint256 totalLiquidity = stargatePoolTmp.totalLiquidity();
        return
            totalLiquidity != 0
                ? queryTokenValue(wants[0], totalLiquidity * 10**(localDecimals - decimals))
                : 0;
    }

    function claimRewards()
        internal
        override
        returns (address[] memory _rewardTokens, uint256[] memory _claimAmounts)
    {
        uint256 _stakePoolId = stakePoolId;
        _rewardTokens = new address[](1);
        _rewardTokens[0] = rewardsTokenSTG;
        _claimAmounts = new uint256[](1);
        _claimAmounts[0] = stargateStakePool.pendingStargate(_stakePoolId, address(this));
        if (_claimAmounts[0] > 0) {
            stargateStakePool.deposit(_stakePoolId, 0);
        }
    }

    function depositTo3rdPool(address[] memory _assets, uint256[] memory _amounts) internal override {
        // addLiquidity
        if (_amounts[0] > 0) {
            address lpTokenTmp = address(stargatePool);
            address router = address(stargateRouterPool);
            IERC20Upgradeable(_assets[0]).safeApprove(router, 0);
            IERC20Upgradeable(_assets[0]).safeApprove(router, _amounts[0]);
            IStargateRouterPool(router).addLiquidity(poolId, _amounts[0], address(this));
            // stake liquidity
            uint256 lpAmount = balanceOfToken(lpTokenTmp);
            IERC20Upgradeable(lpTokenTmp).safeApprove(address(stargateStakePool), 0);
            IERC20Upgradeable(lpTokenTmp).safeApprove(address(stargateStakePool), lpAmount);
            stargateStakePool.deposit(stakePoolId, lpAmount);
        }
    }

    function withdrawFrom3rdPool(
        uint256 _withdrawShares,
        uint256 _totalShares,
        uint256 _outputCode
    ) internal override {
        uint256 _lpAmount = (balanceOfLpToken() * _withdrawShares) / _totalShares;
        if (_lpAmount > 0) {
            // unstake liquidity
            stargateStakePool.withdraw(stakePoolId, _lpAmount);
            // remove liquidity
            stargateRouterPool.instantRedeemLocal(uint16(poolId), _lpAmount, address(this));
        }
    }
}

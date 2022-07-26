// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

import "boc-contract-core/contracts/strategy/BaseClaimableStrategy.sol";
import "./../../enums/ProtocolEnum.sol";
import "../../external/balancer/IAsset.sol";
import "../../external/balancer/IBalancerVault.sol";
import "../../external/balancer/IBalancerHelper.sol";
import "../../external/balancer/IStakingLiquidityGauge.sol";

abstract contract BalancerFreeInSingleOutStrategy is BaseClaimableStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    enum JoinKind {
        INIT,
        EXACT_TOKENS_IN_FOR_BPT_OUT,
        TOKEN_IN_FOR_EXACT_BPT_OUT
    }
    enum ExitKind {
        EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
        EXACT_BPT_IN_FOR_TOKENS_OUT,
        BPT_IN_FOR_EXACT_TOKENS_OUT
    }

    address public constant BAL = address(0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3);
    IBalancerVault public constant BALANCER_VAULT =
    IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IBalancerHelper public constant BALANCER_HELPER =
    IBalancerHelper(0x94905e703fEAd7f0fD0eEe355D267eE909784e6d);

    uint256 public exitTokenIndex;
    //measured by underlying token
    uint256 public _deposited3rdAssets;
    bytes32 public poolId;
    address public poolLpToken;
    // return token that withdraw from 3rdpool
    address private exitToken;
    //pool extra reward tokens beside BAL
    address[] public extraRewardTokens;
    IAsset[] public poolAssets;

    function initialize(
        address _vault,
        address _harvester,
        address[] memory _wants,
        address _exitToken,
        bytes32 _poolId,
        address _poolLpToken,
        address[] memory _extraRewardTokens
    ) internal {
        wants = _wants;
        exitToken = _exitToken;
        poolId = _poolId;
        poolLpToken = _poolLpToken;
        extraRewardTokens = _extraRewardTokens;

        super._initialize(_vault, _harvester, uint16(ProtocolEnum.Balancer), _wants);

        (address[] memory tokens, ,) = BALANCER_VAULT.getPoolTokens(_poolId);
        poolAssets = new IAsset[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            poolAssets[i] = IAsset(tokens[i]);
            if (tokens[i] == _exitToken) {
                exitTokenIndex = i;
            }
        }

        isWantRatioIgnorable = true;
    }

    function getPoolGauge() virtual public pure returns (address);

    function getWantsInfo()
    external
    view
    override
    returns (address[] memory _assets, uint256[] memory _ratios)
    {
        (_assets, _ratios,) = BALANCER_VAULT.getPoolTokens(poolId);
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
        address _exitToken = exitToken;
        _tokens = new address[](1);
        _tokens[0] = _exitToken;

        _amounts = new uint256[](1);
        _amounts[0] = balanceOfToken(_exitToken) + _deposited3rdAssets;
    }

    function get3rdPoolAssets() external view override returns (uint256) {
        uint256 totalAssets;
        (address[] memory tokens, uint256[] memory balances,) = BALANCER_VAULT.getPoolTokens(
            poolId
        );
        for (uint8 i = 0; i < tokens.length; i++) {
            totalAssets += queryTokenValue(tokens[i], balances[i]);
        }
        return totalAssets;
    }

    function claimRewards()
    internal
    override
    returns (address[] memory _rewardsTokens, uint256[] memory _claimAmounts)
    {
        IStakingLiquidityGauge(getPoolGauge()).claim_rewards();
        console.log('--------balanceOfToken(BAL):%d',balanceOfToken(BAL));
        address[] memory extraRewardTokensCopy = extraRewardTokens;
        _rewardsTokens = new address[](extraRewardTokensCopy.length + 1);
        _rewardsTokens[0] = BAL;
        for (uint256 i = 0; i < extraRewardTokensCopy.length; i++) {
            _rewardsTokens[i + 1] = extraRewardTokensCopy[i];
        }
        _claimAmounts = new uint256[](_rewardsTokens.length);
        for (uint256 i = 0; i < _claimAmounts.length; i++) {
            _claimAmounts[i] = balanceOfToken(_rewardsTokens[i]);
            console.log("_claimAmount:%d", _claimAmounts[i]);
        }
        _updateDeposited3rdAssets();
    }

    function depositTo3rdPool(address[] memory _assets, uint256[] memory _amounts)
    internal
    override
    {
        for (uint256 i = 0; i < _assets.length; i++) {
            uint256 amount = _amounts[i];
            if (amount > 0) {
                address token = _assets[i];
                IERC20Upgradeable(token).safeApprove(address(BALANCER_VAULT), 0);
                IERC20Upgradeable(token).safeApprove(address(BALANCER_VAULT), amount);
                console.log("depositTo3rdPool asset:%s,amount:%d", token, amount);
            }
        }

        // uint256[] memory maxAmountsIn = new uint256[](poolAssets.length);
        // maxAmountsIn[exitTokenIndex] = _amounts[0];
        IBalancerVault.JoinPoolRequest memory joinRequest = IBalancerVault.JoinPoolRequest({
        assets : poolAssets,
        maxAmountsIn : _amounts,
        userData : abi.encode(JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, _amounts, 0),
        fromInternalBalance : false
        });
//        console.log(
//            "assets.length:%d,maxAmountsIn.length:%d",
//            joinRequest.assets.length,
//            joinRequest.maxAmountsIn.length
//        );
        BALANCER_VAULT.joinPool(poolId, address(this), address(this), joinRequest);

        address poolGauge = getPoolGauge();
        address poolLpTokenCopy = poolLpToken;
        IERC20Upgradeable(poolLpTokenCopy).safeApprove(poolGauge, 0);
        IERC20Upgradeable(poolLpTokenCopy).safeApprove(poolGauge, balanceOfToken(poolLpTokenCopy));
        IStakingLiquidityGauge(poolGauge).deposit(balanceOfToken(poolLpTokenCopy));
        _updateDeposited3rdAssets();
    }

    //balancerHelper.queryExit is NOT a view function,so we need to record the value when deposit assets changed
    function _updateDeposited3rdAssets() internal {
        uint256 balanceOfLp = IStakingLiquidityGauge(getPoolGauge()).balanceOf(address(this));
        if (balanceOfLp == 0) {
            _deposited3rdAssets = 0;
            return;
        }
        console.log("btpAmountOut=%d", balanceOfLp);
        address payable recipient = payable(address(this));
        uint256[] memory minAmountsOut = new uint256[](poolAssets.length);
        IBalancerVault.ExitPoolRequest memory exitRequest = IBalancerVault.ExitPoolRequest({
        assets : poolAssets,
        minAmountsOut : minAmountsOut,
        userData : abi.encode(
                ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
                balanceOfLp,
                exitTokenIndex
            ),
        toInternalBalance : false
        });

        //query how much underlying token will received when exitPool
        (uint256 bptIn, uint256[] memory amountsOut) = BALANCER_HELPER.queryExit(
            poolId,
            address(this),
            recipient,
            exitRequest
        );
        console.log("bptIn:%d", bptIn);
        _deposited3rdAssets = amountsOut[exitTokenIndex];
        console.log("_deposited3rdAssets:%d", _deposited3rdAssets);
    }

    function withdrawFrom3rdPool(uint256 _withdrawShares, uint256 _totalShares) internal override {
        IStakingLiquidityGauge gauge = IStakingLiquidityGauge(getPoolGauge());
        uint256 _lpAmount = (gauge.balanceOf(address(this)) * _withdrawShares) / _totalShares;
        if (_lpAmount > 0) {
            gauge.withdraw(_lpAmount);
            address payable recipient = payable(address(this));
            uint256[] memory minAmountsOut = new uint256[](poolAssets.length);
            IBalancerVault.ExitPoolRequest memory exitRequest = IBalancerVault.ExitPoolRequest({
            assets : poolAssets,
            minAmountsOut : minAmountsOut,
            userData : abi.encode(
                    ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
                    _lpAmount,
                    exitTokenIndex
                ),
            toInternalBalance : false
            });
            BALANCER_VAULT.exitPool(poolId, address(this), recipient, exitRequest);

            console.log("underlying balance:%d", balanceOfToken(wants[0]));
            _updateDeposited3rdAssets();
        }
    }

}

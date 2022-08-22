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

abstract contract Balancer4UBaseStrategy is BaseClaimableStrategy {
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

    address public constant BAL = 0x9a71012B13CA4d3D0Cdc72A177DF3ef03b0E76A3;
    IBalancerVault public constant BALANCER_VAULT =
        IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IBalancerHelper public constant BALANCER_HELPER =
        IBalancerHelper(0x94905e703fEAd7f0fD0eEe355D267eE909784e6d);

    uint256 public exitTokenIndex;
    //measured by underlying token
    uint256 public deposited3rdAssets;
    bytes32 public poolId;
    address public poolLpToken;
    // return token that withdraw from 3rdpool
    address private exitToken;
    //pool extra reward _tokens beside BAL
    address[] public extraRewardTokens;
    IAsset[] public poolAssets;

    function initialize(
        address _vault,
        address _harvester,
        string memory _name,
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

        super._initialize(_vault, _harvester, _name, uint16(ProtocolEnum.Balancer), _wants);

        (address[] memory _tokens, , ) = BALANCER_VAULT.getPoolTokens(_poolId);
        poolAssets = new IAsset[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            poolAssets[i] = IAsset(_tokens[i]);
            if (_tokens[i] == _exitToken) {
                exitTokenIndex = i;
            }
        }

        isWantRatioIgnorable = true;
    }

    function getPoolGauge() public pure virtual returns (address);

    function getWantsInfo()
        external
        view
        override
        returns (address[] memory _assets, uint256[] memory _ratios)
    {
        (_assets, _ratios, ) = BALANCER_VAULT.getPoolTokens(poolId);
    }

    function getOutputsInfo() external view virtual override returns (OutputInfo[] memory _outputsInfo) {
        _outputsInfo = new OutputInfo[](5);
        OutputInfo memory _info0 = _outputsInfo[0];
        _info0.outputCode = 0;
        _info0.outputTokens = wants;

        OutputInfo memory _info1 = _outputsInfo[1];
        _info1.outputCode = 1;
        _info1.outputTokens = new address[](1);
        _info1.outputTokens[0] = wants[0];

        OutputInfo memory _info2 = _outputsInfo[2];
        _info2.outputCode = 2;
        _info2.outputTokens = new address[](1);
        _info2.outputTokens[0] = wants[1];

        OutputInfo memory _info3 = _outputsInfo[3];
        _info3.outputCode = 3;
        _info3.outputTokens = new address[](1);
        _info3.outputTokens[0] = wants[2];

        OutputInfo memory _info4 = _outputsInfo[4];
        _info4.outputCode = 4;
        _info4.outputTokens = new address[](1);
        _info4.outputTokens[0] = wants[3];
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
        (, _amounts, ) = BALANCER_VAULT.getPoolTokens(poolId);
        _tokens = wants;

        uint256 _lpBalance = IERC20Upgradeable(getPoolGauge()).balanceOf(address(this));
        uint256 _lpTotalSupply = IERC20Upgradeable(poolLpToken).totalSupply();
        for (uint256 i = 0; i < _tokens.length; i++) {
            _amounts[i] = (_amounts[i] * _lpBalance) / _lpTotalSupply + balanceOfToken(_tokens[i]);
        }
    }

    function get3rdPoolAssets() external view override returns (uint256) {
        uint256 _totalAssets;
        (address[] memory _tokens, uint256[] memory _balances, ) = BALANCER_VAULT.getPoolTokens(poolId);
        for (uint8 i = 0; i < _tokens.length; i++) {
            _totalAssets += queryTokenValue(_tokens[i], _balances[i]);
        }
        return _totalAssets;
    }

    function claimRewards()
        internal
        override
        returns (address[] memory _rewardsTokens, uint256[] memory _claimAmounts)
    {
        IStakingLiquidityGauge(getPoolGauge()).claim_rewards();
        console.log("--------balanceOfToken(BAL):%d", balanceOfToken(BAL));
        address[] memory _extraRewardTokensCopy = extraRewardTokens;
        _rewardsTokens = new address[](_extraRewardTokensCopy.length + 1);
        _rewardsTokens[0] = BAL;
        for (uint256 i = 0; i < _extraRewardTokensCopy.length; i++) {
            _rewardsTokens[i + 1] = _extraRewardTokensCopy[i];
        }
        _claimAmounts = new uint256[](_rewardsTokens.length);
        for (uint256 i = 0; i < _claimAmounts.length; i++) {
            _claimAmounts[i] = balanceOfToken(_rewardsTokens[i]);
            console.log("_claimAmount:%d", _claimAmounts[i]);
        }
    }

    function depositTo3rdPool(address[] memory _assets, uint256[] memory _amounts) internal override {
        for (uint256 i = 0; i < _assets.length; i++) {
            uint256 _amount = _amounts[i];
            if (_amount > 0) {
                address _token = _assets[i];
                IERC20Upgradeable(_token).safeApprove(address(BALANCER_VAULT), 0);
                IERC20Upgradeable(_token).safeApprove(address(BALANCER_VAULT), _amount);
                console.log("depositTo3rdPool asset:%s,_amount:%d", _token, _amount);
            }
        }

        IBalancerVault.JoinPoolRequest memory _joinRequest = IBalancerVault.JoinPoolRequest({
            assets: poolAssets,
            maxAmountsIn: _amounts,
            userData: abi.encode(JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, _amounts, 0),
            fromInternalBalance: false
        });
        BALANCER_VAULT.joinPool(poolId, address(this), address(this), _joinRequest);

        address _poolGauge = getPoolGauge();
        address _poolLpTokenCopy = poolLpToken;
        uint256 _lpAmount = balanceOfToken(_poolLpTokenCopy);
        IERC20Upgradeable(_poolLpTokenCopy).safeApprove(_poolGauge, 0);
        IERC20Upgradeable(_poolLpTokenCopy).safeApprove(_poolGauge, _lpAmount);
        IStakingLiquidityGauge(_poolGauge).deposit(_lpAmount);
    }

    function withdrawFrom3rdPool(
        uint256 _withdrawShares,
        uint256 _totalShares,
        uint256 _outputCode
    ) internal override {
        IStakingLiquidityGauge _gauge = IStakingLiquidityGauge(getPoolGauge());
        uint256 _lpAmount = (_gauge.balanceOf(address(this)) * _withdrawShares) / _totalShares;
        _gauge.withdraw(_lpAmount);
        address payable _recipient = payable(address(this));
        uint256[] memory _minAmountsOut = new uint256[](poolAssets.length);
        IBalancerVault.ExitPoolRequest memory _exitRequest;
        if (_outputCode > 0 && _outputCode < 5) {
            _exitRequest = IBalancerVault.ExitPoolRequest({
                assets: poolAssets,
                minAmountsOut: _minAmountsOut,
                userData: abi.encode(ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, _lpAmount, _outputCode - 1),
                toInternalBalance: false
            });
        } else {
            _exitRequest = IBalancerVault.ExitPoolRequest({
                assets: poolAssets,
                minAmountsOut: _minAmountsOut,
                userData: abi.encode(ExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, _lpAmount),
                toInternalBalance: false
            });
        }
        BALANCER_VAULT.exitPool(poolId, address(this), _recipient, _exitRequest);
    }
}

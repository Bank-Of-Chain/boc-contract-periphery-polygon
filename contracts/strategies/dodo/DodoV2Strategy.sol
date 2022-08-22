// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "hardhat/console.sol";

import "boc-contract-core/contracts/strategy/BaseClaimableStrategy.sol";

import "../../enums/ProtocolEnum.sol";
import "../../external/dodo/DodoVaultV1.sol";
import "../../external/dodo/DodoStakePoolV2.sol";
import "../../utils/actions/DodoPoolV2ActionsMixin.sol";

contract DodoV2Strategy is BaseClaimableStrategy, DodoPoolV2ActionsMixin {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public lpTokenPool;
    address public baseLpToken;
    address public quoteLpToken;

    function initialize(
        address _vault,
        address _harvester,
        string memory _name,
        address _lpTokenPool,
        address _baseLpToken,
        address _quoteLpToken,
        address _baseStakePool,
        address _quoteStakePool
    ) external initializer{
        lpTokenPool = _lpTokenPool;
        baseLpToken = _baseLpToken;
        quoteLpToken = _quoteLpToken;
        address[] memory _wants = new address[](2);
        _wants[0] = DodoVaultV1(_lpTokenPool)._BASE_TOKEN_();
        _wants[1] = DodoVaultV1(_lpTokenPool)._QUOTE_TOKEN_();
        super.__initStakePool(_baseStakePool,_quoteStakePool);
        super._initialize(_vault, _harvester, _name, uint16(ProtocolEnum.Dodo), _wants);
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
        (uint256 _baseExpectedTarget, uint256 _quoteExpectedTarget) = DodoVaultV1(lpTokenPool)
            .getExpectedTarget();
        _ratios = new uint256[](_assets.length);
        _ratios[0] = _baseExpectedTarget;
        _ratios[1] = _quoteExpectedTarget;
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
        _amounts = valueOfLpTokens();
        address _lpTokenPool = lpTokenPool;
        uint256 _basePenalty = DodoVaultV1(_lpTokenPool).getWithdrawBasePenalty(_amounts[0]);
        uint256 _quotePenalty = DodoVaultV1(_lpTokenPool).getWithdrawQuotePenalty(_amounts[1]);
        _amounts[0] -= _basePenalty;
        _amounts[1] -= _quotePenalty;
        _amounts[0] += balanceOfToken(_tokens[0]);
        _amounts[1] += balanceOfToken(_tokens[1]);
    }

    function balanceOfLpTokens() private view returns (uint256[] memory) {
        uint256[] memory _lpTokenAmounts = new uint256[](2);
        _lpTokenAmounts[0] = balanceOfBaseLpToken();
        _lpTokenAmounts[1] = balanceOfQuoteLpToken();
        return _lpTokenAmounts;
    }

    function valueOfLpTokens() private view returns (uint256[] memory) {
        uint256[] memory _lpTokenAmounts = balanceOfLpTokens();
        uint256[] memory _amounts = new uint256[](2);
        address _lpTokenPool = lpTokenPool;
        _amounts[0] =
            (_lpTokenAmounts[0] * DodoVaultV1(_lpTokenPool)._TARGET_BASE_TOKEN_AMOUNT_()) /
            DodoVaultV1(_lpTokenPool).getTotalBaseCapital();
        _amounts[1] =
            (_lpTokenAmounts[1] * DodoVaultV1(_lpTokenPool)._TARGET_QUOTE_TOKEN_AMOUNT_()) /
            DodoVaultV1(_lpTokenPool).getTotalQuoteCapital();
        return _amounts;
    }

    function get3rdPoolAssets() external view override returns (uint256) {
        address[] memory _wants = wants;
        address _lpTokenPool = lpTokenPool;
        uint256 _targetPoolTotalAssets;

        uint256 _baseTokenAmount = DodoVaultV1(_lpTokenPool)._TARGET_BASE_TOKEN_AMOUNT_();
        if (_baseTokenAmount > 0) {
            _targetPoolTotalAssets += queryTokenValue(_wants[0], _baseTokenAmount);
        }

        uint256 _quoteTokenAmount = DodoVaultV1(_lpTokenPool)._TARGET_QUOTE_TOKEN_AMOUNT_();
        if (_quoteTokenAmount > 0) {
            _targetPoolTotalAssets += queryTokenValue(_wants[1], _quoteTokenAmount);
        }

        return _targetPoolTotalAssets;
    }

    function getPendingRewards()
        internal
        view
        returns (address[] memory _rewardsTokens, uint256[] memory _pendingAmounts)
    {
        _rewardsTokens = new address[](2);
        _rewardsTokens[0] = DODO;
        _rewardsTokens[1] = WMATIC;
        _pendingAmounts = new uint256[](2);
        _pendingAmounts[0] = getPendingReward(DODO);
        _pendingAmounts[1] = getPendingReward(WMATIC);
    }

    function claimRewards()
        internal
        override
        returns (address[] memory _rewardTokens, uint256[] memory _claimAmounts)
    {
        (_rewardTokens, _claimAmounts) = getPendingRewards();
        address _baseStakePool = baseStakePool;
        address _quoteStakePool = quoteStakePool;
        if (_claimAmounts[0] > 0) {
            __claimRewards(_baseStakePool, 0);
            __claimRewards(_quoteStakePool, 0);
        }
        if (_claimAmounts[1] > 0) {
            __claimRewards(_baseStakePool, 1);
            __claimRewards(_quoteStakePool, 1);
        }
    }

    function depositTo3rdPool(address[] memory _assets, uint256[] memory _amounts) internal override {
        require(
            _assets.length == wants.length && _assets[0] == wants[0] && _assets[1] == wants[1],
            "need two token."
        );
        uint8 _rStatus = DodoVaultV1(lpTokenPool)._R_STATUS_();
        // Deposit fewer coins first, so that you will get rewards
        if (_rStatus == 2) {
            _depositQuoteToken(_assets[1], _amounts[1]);
            _depositBaseToken(_assets[0], _amounts[0]);
        } else {
            _depositBaseToken(_assets[0], _amounts[0]);
            _depositQuoteToken(_assets[1], _amounts[1]);
        }
    }

    function _depositBaseToken(address _asset, uint256 _amount) internal {
        if (_amount > 0) {
            address _lpTokenPool = lpTokenPool;
            IERC20Upgradeable(_asset).safeApprove(_lpTokenPool, 0);
            IERC20Upgradeable(_asset).safeApprove(_lpTokenPool, _amount);
            DodoVaultV1(_lpTokenPool).depositBase(_amount);
            address _baseLpToken = baseLpToken;
            uint256 _baseLiquidity = balanceOfToken(_baseLpToken);
            address _baseStakePool = baseStakePool;
            IERC20Upgradeable(_baseLpToken).safeApprove(_baseStakePool, 0);
            IERC20Upgradeable(_baseLpToken).safeApprove(_baseStakePool, _baseLiquidity);
            DodoStakePoolV2(_baseStakePool).deposit(_baseLiquidity);
        }
    }

    function _depositQuoteToken(address _asset, uint256 _amount) internal {
        if (_amount > 0) {
            address _lpTokenPool = lpTokenPool;
            IERC20Upgradeable(_asset).safeApprove(_lpTokenPool, 0);
            IERC20Upgradeable(_asset).safeApprove(_lpTokenPool, _amount);
            DodoVaultV1(_lpTokenPool).depositQuote(_amount);
            address _quoteLpToken = quoteLpToken;
            uint256 _quoteLiquidity = balanceOfToken(_quoteLpToken);
            address _quoteStakePool = quoteStakePool;
            IERC20Upgradeable(_quoteLpToken).safeApprove(_quoteStakePool, 0);
            IERC20Upgradeable(_quoteLpToken).safeApprove(_quoteStakePool, _quoteLiquidity);
            DodoStakePoolV2(_quoteStakePool).deposit(_quoteLiquidity);
        }
    }

    function withdrawFrom3rdPool(
        uint256 _withdrawShares,
        uint256 _totalShares,
        uint256 _outputCode
    ) internal override {
        address _lpTokenPool = lpTokenPool;
        uint256 _baseWithdrawAmount = (balanceOfBaseLpToken() * _withdrawShares) / _totalShares;
        uint256 _quoteWithdrawAmount = (balanceOfQuoteLpToken() * _withdrawShares) / _totalShares;
        (uint256 _baseExpectedTarget, uint256 _quoteExpectedTarget) = DodoVaultV1(_lpTokenPool)
            .getExpectedTarget();
        uint256 _totalBaseCapital = DodoVaultV1(_lpTokenPool).getTotalBaseCapital();
        uint256 _totalQuoteCapital = DodoVaultV1(_lpTokenPool).getTotalQuoteCapital();
        uint8 _rStatus = DodoVaultV1(_lpTokenPool)._R_STATUS_();
        address _baseStakePool = baseStakePool;
        address _quoteStakePool = quoteStakePool;

        if (_rStatus == 2) {
            if (_baseWithdrawAmount > 0) {
                __withdrawLpToken(_baseStakePool, _baseWithdrawAmount);
                DodoVaultV1(_lpTokenPool).withdrawBase(
                    (_baseWithdrawAmount * _baseExpectedTarget) / _totalBaseCapital
                );
            }
            if (_quoteWithdrawAmount > 0) {
                __withdrawLpToken(_quoteStakePool, _quoteWithdrawAmount);
                DodoVaultV1(_lpTokenPool).withdrawQuote(
                    (_quoteWithdrawAmount * _quoteExpectedTarget) / _totalQuoteCapital
                );
            }
        } else {
            if (_quoteWithdrawAmount > 0) {
                __withdrawLpToken(_quoteStakePool, _quoteWithdrawAmount);
                DodoVaultV1(_lpTokenPool).withdrawQuote(
                    (_quoteWithdrawAmount * _quoteExpectedTarget) / _totalQuoteCapital
                );
            }
            if (_baseWithdrawAmount > 0) {
                __withdrawLpToken(_baseStakePool, _baseWithdrawAmount);
                DodoVaultV1(_lpTokenPool).withdrawBase(
                    (_baseWithdrawAmount * _baseExpectedTarget) / _totalBaseCapital
                );
            }
        }
    }
}

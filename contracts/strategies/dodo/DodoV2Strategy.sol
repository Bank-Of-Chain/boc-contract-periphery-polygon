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
        (uint256 baseExpectedTarget, uint256 quoteExpectedTarget) = DodoVaultV1(lpTokenPool)
            .getExpectedTarget();
        _ratios = new uint256[](_assets.length);
        _ratios[0] = baseExpectedTarget;
        _ratios[1] = quoteExpectedTarget;
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
        _tokens = wants;
        _amounts = valueOfLpTokens();
        address _lpTokenPool = lpTokenPool;
        uint256 basePenalty = DodoVaultV1(_lpTokenPool).getWithdrawBasePenalty(_amounts[0]);
        uint256 quotePenalty = DodoVaultV1(_lpTokenPool).getWithdrawQuotePenalty(_amounts[1]);
        _amounts[0] -= basePenalty;
        _amounts[1] -= quotePenalty;
        _amounts[0] += balanceOfToken(_tokens[0]);
        _amounts[1] += balanceOfToken(_tokens[1]);
    }

    function balanceOfLpTokens() private view returns (uint256[] memory) {
        uint256[] memory lpTokenAmounts = new uint256[](2);
        lpTokenAmounts[0] = balanceOfBaseLpToken();
        lpTokenAmounts[1] = balanceOfQuoteLpToken();
        return lpTokenAmounts;
    }

    function valueOfLpTokens() private view returns (uint256[] memory) {
        uint256[] memory lpTokenAmounts = balanceOfLpTokens();
        uint256[] memory amounts = new uint256[](2);
        address _lpTokenPool = lpTokenPool;
        amounts[0] =
            (lpTokenAmounts[0] * DodoVaultV1(_lpTokenPool)._TARGET_BASE_TOKEN_AMOUNT_()) /
            DodoVaultV1(_lpTokenPool).getTotalBaseCapital();
        amounts[1] =
            (lpTokenAmounts[1] * DodoVaultV1(_lpTokenPool)._TARGET_QUOTE_TOKEN_AMOUNT_()) /
            DodoVaultV1(_lpTokenPool).getTotalQuoteCapital();
        return amounts;
    }

    function get3rdPoolAssets() external view override returns (uint256) {
        address[] memory _wants = wants;
        address _lpTokenPool = lpTokenPool;
        uint256 targetPoolTotalAssets;

        uint256 baseTokenAmount = DodoVaultV1(_lpTokenPool)._TARGET_BASE_TOKEN_AMOUNT_();
        if (baseTokenAmount > 0) {
            targetPoolTotalAssets += queryTokenValue(_wants[0], baseTokenAmount);
        }

        uint256 quoteTokenAmount = DodoVaultV1(_lpTokenPool)._TARGET_QUOTE_TOKEN_AMOUNT_();
        if (quoteTokenAmount > 0) {
            targetPoolTotalAssets += queryTokenValue(_wants[1], quoteTokenAmount);
        }

        return targetPoolTotalAssets;
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
        uint8 rStatus = DodoVaultV1(lpTokenPool)._R_STATUS_();
        // Deposit fewer coins first, so that you will get rewards
        if (rStatus == 2) {
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
            uint256 baseLiquidity = balanceOfToken(_baseLpToken);
            address _baseStakePool = baseStakePool;
            IERC20Upgradeable(_baseLpToken).safeApprove(_baseStakePool, 0);
            IERC20Upgradeable(_baseLpToken).safeApprove(_baseStakePool, baseLiquidity);
            DodoStakePoolV2(_baseStakePool).deposit(baseLiquidity);
        }
    }

    function _depositQuoteToken(address _asset, uint256 _amount) internal {
        if (_amount > 0) {
            address _lpTokenPool = lpTokenPool;
            IERC20Upgradeable(_asset).safeApprove(_lpTokenPool, 0);
            IERC20Upgradeable(_asset).safeApprove(_lpTokenPool, _amount);
            DodoVaultV1(_lpTokenPool).depositQuote(_amount);
            address _quoteLpToken = quoteLpToken;
            uint256 quoteLiquidity = balanceOfToken(_quoteLpToken);
            address _quoteStakePool = quoteStakePool;
            IERC20Upgradeable(_quoteLpToken).safeApprove(_quoteStakePool, 0);
            IERC20Upgradeable(_quoteLpToken).safeApprove(_quoteStakePool, quoteLiquidity);
            DodoStakePoolV2(_quoteStakePool).deposit(quoteLiquidity);
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
        (uint256 baseExpectedTarget, uint256 quoteExpectedTarget) = DodoVaultV1(_lpTokenPool)
            .getExpectedTarget();
        uint256 totalBaseCapital = DodoVaultV1(_lpTokenPool).getTotalBaseCapital();
        uint256 totalQuoteCapital = DodoVaultV1(_lpTokenPool).getTotalQuoteCapital();
        uint8 rStatus = DodoVaultV1(_lpTokenPool)._R_STATUS_();
        address _baseStakePool = baseStakePool;
        address _quoteStakePool = quoteStakePool;

        if (rStatus == 2) {
            if (_baseWithdrawAmount > 0) {
                __withdrawLpToken(_baseStakePool, _baseWithdrawAmount);
                DodoVaultV1(_lpTokenPool).withdrawBase(
                    (_baseWithdrawAmount * baseExpectedTarget) / totalBaseCapital
                );
            }
            if (_quoteWithdrawAmount > 0) {
                __withdrawLpToken(_quoteStakePool, _quoteWithdrawAmount);
                DodoVaultV1(_lpTokenPool).withdrawQuote(
                    (_quoteWithdrawAmount * quoteExpectedTarget) / totalQuoteCapital
                );
            }
        } else {
            if (_quoteWithdrawAmount > 0) {
                __withdrawLpToken(_quoteStakePool, _quoteWithdrawAmount);
                DodoVaultV1(_lpTokenPool).withdrawQuote(
                    (_quoteWithdrawAmount * quoteExpectedTarget) / totalQuoteCapital
                );
            }
            if (_baseWithdrawAmount > 0) {
                __withdrawLpToken(_baseStakePool, _baseWithdrawAmount);
                DodoVaultV1(_lpTokenPool).withdrawBase(
                    (_baseWithdrawAmount * baseExpectedTarget) / totalBaseCapital
                );
            }
        }
    }
}

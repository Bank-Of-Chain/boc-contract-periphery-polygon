// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "boc-contract-core/contracts/strategy/BaseClaimableStrategy.sol";
import "./../../external/synapse/IMetaSwap.sol";
import "./../../external/synapse/IMiniChefV2.sol";
import "./../../enums/ProtocolEnum.sol";
import "hardhat/console.sol";

abstract contract SynapseFreeInSingleOutStrategy is BaseClaimableStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    //underlying token index in swap pool
    uint256 internal tokenIndex;
    //swap pool index in MiniChef
    uint256 internal poolId;
    address internal exitToken;
    address internal lpToken;
    //swap pool to add/remove liquidity
    IMetaSwap internal swapPool;
    IMiniChefV2 internal constant miniChef =
        IMiniChefV2(0x7875Af1a6878bdA1C129a4e2356A3fD040418Be5);
    //SYN
    address internal constant rewardToken = 0xf8F9efC0db77d8881500bb06FF5D6ABc3070E695;

    function initialize(
        address _vault,
        address _harvester,
        uint256 _poolId,
        address _swapPool,
        address[] memory _wants,
        address _exitToken,
        uint8 _tokenIndex
    ) internal {
        exitToken = _exitToken;
        tokenIndex = _tokenIndex;
        poolId = _poolId;
        swapPool = IMetaSwap(_swapPool);
        // address[] memory _wants = new address[](1);
        // _wants[0] = underlyingToken;
        wants = _wants;
        (, , , , , , lpToken) = swapPool.swapStorage();
        super._initialize(_vault, _harvester, uint16(ProtocolEnum.Synapse), _wants);

        isWantRatioIgnorable = true;
    }

    function getWantsInfo()
        external
        view
        override
        returns (address[] memory _assets, uint256[] memory _ratios)
    {
        _assets = wants;
        _ratios = new uint256[](wants.length);
        for (uint8 i = 0; i < wants.length; i++) {
            _ratios[i] = swapPool.getTokenBalance(i);
        }
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
        _tokens = new address[](1);
        _tokens[0] = exitToken;

        _amounts = new uint256[](1);
        _amounts[0] = balanceOfToken(exitToken) + estimateDepositAsset();
    }

    function estimateDepositAsset() public view returns (uint256) {
        (uint256 lpAmount, ) = miniChef.userInfo(poolId, address(this));
        return (lpAmount * getValueOfLp()) / decimalUnitOfToken(lpToken);
    }

    //  Calculate the amount of underlying token available to withdraw when withdrawing via only single token
    function getValueOfLp() public view returns (uint256) {
        return
            swapPool.calculateRemoveLiquidityOneToken(
                decimalUnitOfToken(lpToken),
                uint8(tokenIndex)
            );
    }

    function get3rdPoolAssets() external view override returns (uint256) {
        // 3rd pool total assets by underlying token
        uint256 poolTotalAssets = (IERC20Upgradeable(lpToken).totalSupply() * getValueOfLp()) /
            decimalUnitOfToken(lpToken);
        return queryTokenValue(exitToken, poolTotalAssets);
    }

    function claimRewards()
        internal
        override
        returns (address[] memory _rewardsTokens, uint256[] memory _claimAmounts)
    {
        miniChef.harvest(poolId, address(this));

        _rewardsTokens = new address[](1);
        _rewardsTokens[0] = rewardToken;

        _claimAmounts = new uint256[](1);
        _claimAmounts[0] = balanceOfToken(rewardToken);
    }

    function depositTo3rdPool(address[] memory _assets, uint256[] memory _amounts)
        internal
        override
    {
        //add underlying token liquidity to swap pool,and get lp token from swap pool
        for (uint256 i = 0; i < _assets.length; i++) {
            uint256 amount = _amounts[i];
            if (amount > 0) {
                address token = address(_assets[i]);
                IERC20Upgradeable(token).safeApprove(address(swapPool), 0);
                IERC20Upgradeable(token).safeApprove(address(swapPool), amount);
                console.log("depositTo3rdPool asset:%s,amount:%d", token, amount);
            }
        }
        // uint256[] memory underlyingTokenAmountIn = new uint256[](4);
        // underlyingTokenAmountIn[tokenIndex] = _amounts[0];
        //underlyingTokenAmountIn[3] = _amounts[0];
        swapPool.addLiquidity(_amounts, 0, block.timestamp);

        //stack lp token to MiniChef to earn SYN reward token
        uint256 lpAmount = balanceOfToken(lpToken);
        IERC20Upgradeable(lpToken).safeApprove(address(miniChef), 0);
        IERC20Upgradeable(lpToken).safeApprove(address(miniChef), lpAmount);
        miniChef.deposit(poolId, lpAmount, address(this));
    }


    function withdrawFrom3rdPool(uint256 _withdrawShares, uint256 _totalShares) internal override {
        //release the stake of lp token
        (uint256 lpAmountStakeInChef, ) = miniChef.userInfo(poolId, address(this));
        uint256 lpAmountToWithdraw = (_withdrawShares * lpAmountStakeInChef) / _totalShares;
        miniChef.withdraw(poolId, lpAmountToWithdraw, address(this));

        //remove liquidity from swap pool
        uint256 actualLpTokenAmount = balanceOfToken(lpToken);
        if (actualLpTokenAmount > 0) {
            IERC20Upgradeable(lpToken).safeApprove(address(swapPool), 0);
            IERC20Upgradeable(lpToken).safeApprove(address(swapPool), actualLpTokenAmount);
            swapPool.removeLiquidityOneToken(
                actualLpTokenAmount,
                uint8(tokenIndex),
                0,
                block.timestamp
            );
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "boc-contract-core/contracts/strategy/BaseClaimableStrategy.sol";
import "./../../external/synapse/IMetaSwap.sol";
import "./../../external/synapse/IMiniChefV2.sol";
import "./../../enums/ProtocolEnum.sol";
import "hardhat/console.sol";

contract Synapse4UStrategy is BaseClaimableStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    //underlying token index in swap pool
    uint8 internal constant tokenIndex = 3;
    //swap pool index in MiniChef
    uint256 internal constant poolId = 1;
    address internal constant exitToken = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    //swapPool.swapStorage() https://polygonscan.com/address/0x85fCD7Dd0a1e1A9FCD5FD886ED522dE8221C3EE5#readContract
    address internal constant lpToken = address(0x7479e1Bc2F2473f9e78c89B4210eb6d55d33b645);
    //SYN
    address internal constant rewardToken = 0xf8F9efC0db77d8881500bb06FF5D6ABc3070E695;
    //swap pool to add/remove liquidity
    IMetaSwap internal constant swapPool = IMetaSwap(0x85fCD7Dd0a1e1A9FCD5FD886ED522dE8221C3EE5);
    IMiniChefV2 internal constant miniChef =
        IMiniChefV2(0x7875Af1a6878bdA1C129a4e2356A3fD040418Be5);

    function initialize(address _vault, address _harvester) public initializer {
        // 3rdPool support 4 assets,but only use 3.
        address[] memory _wants = new address[](3);
        _wants[0] = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        _wants[1] = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        _wants[2] = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

        //        exitToken = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
        //        tokenIndex = 3;
        //        poolId = 1;
        //        swapPool = IMetaSwap(0x85fCD7Dd0a1e1A9FCD5FD886ED522dE8221C3EE5);
        //        (, , , , , , lpToken) = swapPool.swapStorage();
        super._initialize(_vault, _harvester, uint16(ProtocolEnum.Synapse), _wants);

        isWantRatioIgnorable = true;
    }

    function getVersion() external pure virtual override returns (string memory) {
        return "1.0.1";
    }

    function name() external pure virtual override returns (string memory) {
        return "Synapse4UStrategy";
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
            uint8 index = swapPool.getTokenIndex(wants[i]);
            _ratios[i] = swapPool.getTokenBalance(index);
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
        return swapPool.calculateRemoveLiquidityOneToken(decimalUnitOfToken(lpToken), tokenIndex);
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
        uint256[] memory fullAmounts = new uint256[](4);
        for (uint256 i = 0; i < _assets.length; i++) {
            uint256 amount = _amounts[i];
            if (amount > 0) {
                address token = address(_assets[i]);
                IERC20Upgradeable(token).safeApprove(address(swapPool), 0);
                IERC20Upgradeable(token).safeApprove(address(swapPool), amount);
                console.log("depositTo3rdPool asset:%s,amount:%d", token, amount);

                uint8 index = swapPool.getTokenIndex(token);
                fullAmounts[index] = amount;
            }
        }

        swapPool.addLiquidity(fullAmounts, 0, block.timestamp);

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
            swapPool.removeLiquidityOneToken(actualLpTokenAmount, tokenIndex, 0, block.timestamp);
        }
    }
}

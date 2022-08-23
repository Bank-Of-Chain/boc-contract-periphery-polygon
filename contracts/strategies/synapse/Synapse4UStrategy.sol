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

    //underlying token _index in swap pool
    uint8 internal constant TOKEN_INDEX = 1;
    //swap pool _index in MiniChef
    uint256 internal constant POOL_ID = 1;
    address internal constant EXIT_TOKEN = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    //SWAP_POOL.swapStorage() https://polygonscan.com/address/0x85fCD7Dd0a1e1A9FCD5FD886ED522dE8221C3EE5#readContract
    address internal constant LP_TOKEN = 0x7479e1Bc2F2473f9e78c89B4210eb6d55d33b645;
    //SYN
    address internal constant REWARD_TOKEN = 0xf8F9efC0db77d8881500bb06FF5D6ABc3070E695;
    //swap pool to add/remove liquidity
    IMetaSwap internal constant SWAP_POOL = IMetaSwap(0x85fCD7Dd0a1e1A9FCD5FD886ED522dE8221C3EE5);
    IMiniChefV2 internal constant MINICHEF = IMiniChefV2(0x7875Af1a6878bdA1C129a4e2356A3fD040418Be5);

    function initialize(
        address _vault,
        address _harvester,
        string memory _name
    ) public initializer {
        // 3rdPool support 4 assets,but only use 3.
        address[] memory _wants = new address[](3);
        _wants[0] = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        _wants[1] = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
        _wants[2] = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

        super._initialize(_vault, _harvester, _name, uint16(ProtocolEnum.Synapse), _wants);

        isWantRatioIgnorable = true;
    }

    function getVersion() external pure virtual override returns (string memory) {
        return "1.0.1";
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
            uint8 _index = SWAP_POOL.getTokenIndex(wants[i]);
            _ratios[i] = SWAP_POOL.getTokenBalance(_index);
        }
    }

    function getOutputsInfo() external view virtual override returns (OutputInfo[] memory _outputsInfo) {
        _outputsInfo = new OutputInfo[](3);
        OutputInfo memory _info0 = _outputsInfo[0];
        _info0.outputCode = 0;
        _info0.outputTokens = new address[](1);
        _info0.outputTokens[0] = wants[0];

        OutputInfo memory _info1 = _outputsInfo[1];
        _info1.outputCode = 1;
        _info1.outputTokens = new address[](1);
        _info1.outputTokens[0] = wants[1];

        OutputInfo memory _info2 = _outputsInfo[2];
        _info2.outputCode = 2;
        _info2.outputTokens = new address[](1);
        _info2.outputTokens[0] = wants[2];
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
        _tokens = new address[](1);
        _tokens[0] = EXIT_TOKEN;

        _amounts = new uint256[](1);
        _amounts[0] = balanceOfToken(EXIT_TOKEN) + estimateDepositAsset();
    }

    function estimateDepositAsset() public view returns (uint256) {
        (uint256 _lpAmount, ) = MINICHEF.userInfo(POOL_ID, address(this));
        return (_lpAmount * getValueOfLp()) / decimalUnitOfToken(LP_TOKEN);
    }

    //  Calculate the _amount of underlying token available to withdraw when withdrawing via only single token
    function getValueOfLp() public view returns (uint256) {
        return SWAP_POOL.calculateRemoveLiquidityOneToken(decimalUnitOfToken(LP_TOKEN), TOKEN_INDEX);
    }

    function get3rdPoolAssets() external view override returns (uint256) {
        // 3rd pool total assets by underlying token
        uint256 _poolTotalAssets = (IERC20Upgradeable(LP_TOKEN).totalSupply() * getValueOfLp()) /
            decimalUnitOfToken(LP_TOKEN);
        return queryTokenValue(EXIT_TOKEN, _poolTotalAssets);
    }

    function claimRewards()
        internal
        override
        returns (address[] memory _rewardsTokens, uint256[] memory _claimAmounts)
    {
        MINICHEF.harvest(POOL_ID, address(this));

        _rewardsTokens = new address[](1);
        _rewardsTokens[0] = REWARD_TOKEN;

        _claimAmounts = new uint256[](1);
        _claimAmounts[0] = balanceOfToken(REWARD_TOKEN);
    }

    function depositTo3rdPool(address[] memory _assets, uint256[] memory _amounts) internal override {
        // harvest reward token before deposit 
        harvest();
        //add underlying token liquidity to swap pool,and get lp token from swap pool
        uint256[] memory _fullAmounts = new uint256[](4);
        for (uint256 i = 0; i < _assets.length; i++) {
            uint256 _amount = _amounts[i];
            if (_amount > 0) {
                address _token = address(_assets[i]);
                IERC20Upgradeable(_token).safeApprove(address(SWAP_POOL), 0);
                IERC20Upgradeable(_token).safeApprove(address(SWAP_POOL), _amount);
                console.log("depositTo3rdPool asset:%s,_amount:%d", _token, _amount);

                uint8 _index = SWAP_POOL.getTokenIndex(_token);
                _fullAmounts[_index] = _amount;
            }
        }

        SWAP_POOL.addLiquidity(_fullAmounts, 0, block.timestamp);

        //stack lp token to MiniChef to earn SYN reward token
        uint256 _lpAmount = balanceOfToken(LP_TOKEN);
        IERC20Upgradeable(LP_TOKEN).safeApprove(address(MINICHEF), 0);
        IERC20Upgradeable(LP_TOKEN).safeApprove(address(MINICHEF), _lpAmount);
        MINICHEF.deposit(POOL_ID, _lpAmount, address(this));
    }

    function withdrawFrom3rdPool(
        uint256 _withdrawShares,
        uint256 _totalShares,
        uint256 _outputCode
    ) internal override {
        //release the stake of lp token
        (uint256 _lpAmountStakeInChef, ) = MINICHEF.userInfo(POOL_ID, address(this));
        uint256 _lpAmountToWithdraw = (_withdrawShares * _lpAmountStakeInChef) / _totalShares;
        MINICHEF.withdraw(POOL_ID, _lpAmountToWithdraw, address(this));

        uint8 _outputIndex = 1;
        if (_outputCode == 0) {
            _outputIndex = 1;
        } else if (_outputCode == 1) {
            _outputIndex = 2;
        } else if (_outputCode == 2) {
            _outputIndex = 3;
        }
        //remove liquidity from swap pool
        uint256 _actualLpTokenAmount = balanceOfToken(LP_TOKEN);
        IERC20Upgradeable(LP_TOKEN).safeApprove(address(SWAP_POOL), 0);
        IERC20Upgradeable(LP_TOKEN).safeApprove(address(SWAP_POOL), _actualLpTokenAmount);
        SWAP_POOL.removeLiquidityOneToken(_actualLpTokenAmount, _outputIndex, 0, block.timestamp);
    }

    /// @notice Strategy repay the funds to vault
    /// @param _repayShares Numerator
    /// @param _totalShares Denominator
    function repay(uint256 _repayShares, uint256 _totalShares,uint256 _outputCode)
        public
        virtual
        override
        onlyVault
        returns (address[] memory _assets, uint256[] memory _amounts)
    {
        // first harvest, then withdraw
        harvest();
        
        return BaseStrategy.repay(_repayShares, _totalShares,_outputCode);
    }
}

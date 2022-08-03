// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "hardhat/console.sol";

import "boc-contract-core/contracts/strategy/BaseClaimableStrategy.sol";

import "./../../enums/ProtocolEnum.sol";
import "./../../external/aave/IAToken.sol";
import "./../../external/aave/ILendingPool.sol";
import "./../../external/aave/IAaveIncentivesController.sol";

abstract contract AaveBaseStrategy is BaseClaimableStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address internal aToken;
    ILendingPool public lendingPool;
    IAaveIncentivesController public incentivesController;

    function _initialize(
        address _vault,
        address _harvester,
        address _underlyingToken,
        address _aToken,
        address _lendingPool,
        address _incentivesController
    ) internal {
        require(_underlyingToken != address(0), "underlyingToken cannot be 0.");
        require(_aToken != address(0), "aToken cannot be 0.");
        require(_lendingPool != address(0), "lendingPool cannot be 0.");
        require(_incentivesController != address(0), "incentivesController cannot be 0.");

        address[] memory _wants = new address[](1);
        _wants[0] = _underlyingToken;
        super._initialize(_vault, _harvester, uint16(ProtocolEnum.Aave), _wants);

        aToken = _aToken;
        lendingPool = ILendingPool(_lendingPool);
        incentivesController = IAaveIncentivesController(_incentivesController);
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
        _ratios[0] = decimalUnitOfToken(_assets[0]);
    }

    function getOutputsInfo()
        external
        view
        virtual
        override
        returns (OutputInfo[] memory outputsInfo)
    {
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
        _amounts = new uint256[](1);
        _amounts[0] = balanceOfToken(aToken) + balanceOfToken(_tokens[0]);
    }

    function balanceOfLpToken() private view returns (uint256 lpAmount) {
        lpAmount = balanceOfToken(aToken);
    }

    function get3rdPoolAssets() external view override returns (uint256) {
        // address[] memory _wants = wants;
        uint256 aTokenTotalSupply = IAToken(aToken).totalSupply();
        return aTokenTotalSupply != 0 ? queryTokenValue(wants[0], aTokenTotalSupply) : 0;
    }

    function _getAssets() private view returns (address[] memory _assets) {
        _assets = new address[](1);
        _assets[0] = aToken;
    }

    function claimRewards()
        internal
        override
        returns (address[] memory _rewardTokens, uint256[] memory _claimAmounts)
    {
        address[] memory _assets = _getAssets();
        _rewardTokens = new address[](1);
        _rewardTokens[0] = incentivesController.REWARD_TOKEN();
        _claimAmounts = new uint256[](1);
        _claimAmounts[0] = incentivesController.getRewardsBalance(_assets, address(this));

        if (_claimAmounts[0] > 0) {
            incentivesController.claimRewards(_assets, _claimAmounts[0], address(this));
        }
    }

    function depositTo3rdPool(address[] memory _assets, uint256[] memory _amounts)
        internal
        override
    {
        require(_assets.length == 1 && _assets[0] == wants[0], "just need one token.");
        if (_amounts[0] > 0) {
            IERC20Upgradeable(_assets[0]).safeApprove(address(lendingPool), 0);
            IERC20Upgradeable(_assets[0]).safeApprove(address(lendingPool), _amounts[0]);
            lendingPool.deposit(_assets[0], _amounts[0], address(this), 0);
        }
    }

    function withdrawFrom3rdPool(uint256 _withdrawShares, uint256 _totalShares,uint256 _outputCode) internal override {
        uint256 _lpAmount = (balanceOfLpToken() * _withdrawShares) / _totalShares;
        if (_lpAmount > 0) {
            lendingPool.withdraw(wants[0], _lpAmount, address(this));
        }
    }

}

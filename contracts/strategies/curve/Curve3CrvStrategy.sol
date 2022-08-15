// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "hardhat/console.sol";

import "boc-contract-core/contracts/strategy/BaseClaimableStrategy.sol";

import "./../../external/curve/ICurveStableSwap3Crv.sol";
import "./../../external/curve/ICurveGauge.sol";
import "./../../external/curve/IChildGaugeFactory.sol";

import "./../../enums/ProtocolEnum.sol";

contract Curve3CrvStrategy is Initializable, BaseClaimableStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    address internal constant DAI_TOKEN = address(0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063);
    address internal constant USDT_TOKEN = address(0xc2132D05D31c914a87C6611C10748AEb04B58e8F);
    address internal constant USDC_TOKEN = address(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);

    address private constant LP_TOKEN_POOL = address(0x445FE580eF8d70FF569aB36e80c647af338db351);
    address private constant LP_TOKEN = address(0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171);
    address private constant GAUGE_FACTORY = address(0xabC000d88f23Bb45525E447528DBF656A9D55bf5);
    address internal constant gauge = address(0x20759F567BB3EcDB55c817c9a1d13076aB215EdC);

    address[] internal rewardTokens;

    function initialize(
        address _vault,
        address _harvester,
        string memory _name
    ) external initializer {
        address[] memory _wants = new address[](3);
        _wants[0] = DAI_TOKEN;
        _wants[1] = USDC_TOKEN;
        _wants[2] = USDT_TOKEN;

        super._initialize(_vault, _harvester, _name, uint16(ProtocolEnum.Curve), _wants);

        rewardTokens = new address[](2);
        // wmatic
        rewardTokens[0] = address(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
        // crv
        rewardTokens[1] = address(0x172370d5Cd63279eFa6d502DAB29171933a610AF);
        isWantRatioIgnorable = true;
    }

    /**
     * @dev Returns version information
     */
    function getVersion() external pure override returns (string memory) {
        return "1.0.1";
    }

    /**
     * @dev Returns the ratio of wants and wants
     */
    function getWantsInfo()
        public
        view
        override
        returns (address[] memory _assets, uint256[] memory _ratios)
    {
        _assets = wants;
        _ratios = new uint256[](_assets.length);
        for (uint256 i = 0; i < _assets.length; i++) {
            _ratios[i] = ICurveStableSwap3Crv(LP_TOKEN_POOL).balances(i);
        }
    }

    function getOutputsInfo() external view virtual override returns (OutputInfo[] memory outputsInfo) {
        outputsInfo = new OutputInfo[](4);
        OutputInfo memory info0 = outputsInfo[0];
        info0.outputCode = 0;
        info0.outputTokens = wants;

        OutputInfo memory info1 = outputsInfo[1];
        info1.outputCode = 1;
        info1.outputTokens = new address[](1);
        info1.outputTokens[0] = wants[0];

        OutputInfo memory info2 = outputsInfo[2];
        info2.outputCode = 2;
        info2.outputTokens = new address[](1);
        info2.outputTokens[0] = wants[1];

        OutputInfo memory info3 = outputsInfo[3];
        info3.outputCode = 3;
        info3.outputTokens = new address[](1);
        info3.outputTokens[0] = wants[2];
    }

    /**
     * @dev Returns the number of stablecoins held by the policy (both in third party pools and on hand)
     */
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
        _amounts = new uint256[](_tokens.length);
        // our 3CRV amount is equal to our gauge lp token amount
        uint256 lpAmount = balanceOfLpToken();
        uint256 totalSupply = IERC20Upgradeable(LP_TOKEN).totalSupply();
        ICurveStableSwap3Crv pool = ICurveStableSwap3Crv(LP_TOKEN_POOL);
        for (uint256 i = 0; i < _tokens.length; i++) {
            _amounts[i] = balanceOfToken(_tokens[i]) + (pool.balances(i) * lpAmount) / totalSupply;
        }
    }

    function balanceOfLpToken() public view returns (uint256) {
        return balanceOfToken(gauge);
    }

    function get3rdPoolAssets() external view override returns (uint256 targetPoolTotalAssets) {
        uint256 dTokenTotalSupply = (ICurveStableSwap3Crv(LP_TOKEN_POOL).get_virtual_price() *
            (IERC20Upgradeable(LP_TOKEN).totalSupply())) / (1e18);
        if (dTokenTotalSupply > 0) {
            targetPoolTotalAssets += queryTokenValue(DAI_TOKEN, dTokenTotalSupply);
        }
    }

    function claimRewards()
        internal
        override
        returns (address[] memory _rewardTokens, uint256[] memory _claimAmounts)
    {
        _rewardTokens = rewardTokens;
        IChildGaugeFactory(GAUGE_FACTORY).mint(gauge);
        _claimAmounts = new uint256[](_rewardTokens.length);
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            _claimAmounts[i] = balanceOfToken(_rewardTokens[i]);
            console.log("_claimAmount:%d", _claimAmounts[i]);
        }
    }

    /**
     * @dev deposit money to the third party pools
     */
    function depositTo3rdPool(address[] memory _assets, uint256[] memory _amounts) internal override {
        // approve
        for (uint256 i = 0; i < _assets.length; i++) {
            IERC20Upgradeable(_assets[i]).safeApprove(LP_TOKEN_POOL, 0);
            IERC20Upgradeable(_assets[i]).safeApprove(LP_TOKEN_POOL, _amounts[i]);
        }
        // add liquidity
        ICurveStableSwap3Crv(LP_TOKEN_POOL).add_liquidity(
            [_amounts[0], _amounts[1], _amounts[2]],
            0,
            true
        );
        // stake
        uint256 liquidity = balanceOfToken(LP_TOKEN);
        if (liquidity > 0) {
            IERC20Upgradeable(LP_TOKEN).safeApprove(gauge, 0);
            IERC20Upgradeable(LP_TOKEN).safeApprove(gauge, liquidity);
            ICurveGauge(gauge).deposit(liquidity);
        }
    }

    /**
     * @dev take money from the third party pools
     */
    function withdrawFrom3rdPool(
        uint256 _withdrawShares,
        uint256 _totalShares,
        uint256 _outputCode
    ) internal override {
        uint256 _lpAmount = (balanceOfLpToken() * _withdrawShares) / _totalShares;

        ICurveGauge(gauge).withdraw(_lpAmount);
        if (_outputCode > 0 && _outputCode < 4) {
            int128 index;
            if (_outputCode == 1) {
                index = 0;
            } else if (_outputCode == 2) {
                index = 1;
            } else if (_outputCode == 3) {
                index = 2;
            }
            ICurveStableSwap3Crv(LP_TOKEN_POOL).remove_liquidity_one_coin(_lpAmount, index, 0, true);
        } else {
            // withdraw multi coins
            uint256[3] memory minAmounts;
            ICurveStableSwap3Crv(LP_TOKEN_POOL).remove_liquidity(_lpAmount, minAmounts, true);
        }
    }
}

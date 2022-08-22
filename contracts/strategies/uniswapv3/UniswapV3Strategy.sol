// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import "@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol";
import "boc-contract-core/contracts/strategy/BaseClaimableStrategy.sol";
import "./../../external/uniswapv3/INonfungiblePositionManager.sol";
import "./../../external/uniswapv3/libraries/LiquidityAmounts.sol";
import "../../utils/actions/UniswapV3LiquidityActionsMixin.sol";
import "./../../enums/ProtocolEnum.sol";
import "hardhat/console.sol";

contract UniswapV3Strategy is BaseClaimableStrategy, UniswapV3LiquidityActionsMixin {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event UniV3SetBaseThreshold(int24 _baseThreshold);
    event UniV3SetLimitThreshold(int24 _limitThreshold);
    event UniV3SetPeriod(uint256 _period);
    event UniV3SetMinTickMove(int24 _minTickMove);
    event UniV3SetMaxTwapDeviation(int24 _maxTwapDeviation);
    event UniV3SetTwapDuration(uint32 _twapDuration);

    int24 public baseThreshold;
    int24 public limitThreshold;
    int24 public minTickMove;
    int24 public maxTwapDeviation;
    int24 public lastTick;
    int24 public tickSpacing;
    uint256 public period;
    uint256 public lastTimestamp;
    uint32 public twapDuration;

    struct MintInfo {
        uint256 tokenId;
        int24 tickLower;
        int24 tickUpper;
    }

    MintInfo public baseMintInfo;
    MintInfo public limitMintInfo;

    function initialize(
        address _vault,
        address _harvester,
        string memory _name,
        address _pool,
        int24 _baseThreshold,
        int24 _limitThreshold,
        uint256 _period,
        int24 _minTickMove,
        int24 _maxTwapDeviation,
        uint32 _twapDuration,
        int24 _tickSpacing
    ) external initializer {
        _initializeUniswapV3Liquidity(_pool);
        address[] memory _wants = new address[](2);
        _wants[0] = token0;
        _wants[1] = token1;
        super._initialize(_vault, _harvester, _name, uint16(ProtocolEnum.UniswapV3), _wants);
        baseThreshold = _baseThreshold;
        limitThreshold = _limitThreshold;
        period = _period;
        minTickMove = _minTickMove;
        maxTwapDeviation = _maxTwapDeviation;
        twapDuration = _twapDuration;
        tickSpacing = _tickSpacing;
    }

    function getVersion() external pure override returns (string memory) {
        return "1.0.0";
    }

    function getWantsInfo()
        public
        view
        override
        returns (address[] memory _assets, uint256[] memory _ratios)
    {
        _assets = wants;
        int24 _tickLower = baseMintInfo.tickLower;
        int24 _tickUpper = baseMintInfo.tickUpper;
        (, int24 _tick, , , , , ) = pool.slot0();
        if (baseMintInfo.tokenId == 0 || shouldRebalance(_tick)) {
            (, , _tickLower, _tickUpper) = getSpecifiedRangesOfTick(_tick);
        }

        (uint256 _amount0, uint256 _amount1) = getAmountsForLiquidity(
            _tickLower,
            _tickUpper,
            pool.liquidity()
        );
        _ratios = new uint256[](2);
        _ratios[0] = _amount0;
        _ratios[1] = _amount1;
    }

    function getOutputsInfo() external view virtual override returns (OutputInfo[] memory _outputsInfo) {
        _outputsInfo = new OutputInfo[](1);
        OutputInfo memory _info0 = _outputsInfo[0];
        _info0.outputCode = 0;
        _info0.outputTokens = wants;
    }

    function getSpecifiedRangesOfTick(int24 _tick)
        internal
        view
        returns (
            int24 _tickFloor,
            int24 _tickCeil,
            int24 _tickLower,
            int24 _tickUpper
        )
    {
        _tickFloor = _floor(_tick);
        _tickCeil = _tickFloor + tickSpacing;
        _tickLower = _tickFloor - baseThreshold;
        _tickUpper = _tickCeil + baseThreshold;
    }

    function getAmountsForLiquidity(
        int24 _tickLower,
        int24 _tickUpper,
        uint128 _liquidity
    ) internal view returns (uint256, uint256) {
        (uint160 _sqrtPriceX96, , , , , , ) = pool.slot0();
        (uint256 _amount0, uint256 _amount1) = LiquidityAmounts.getAmountsForLiquidity(
            _sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(_tickLower),
            TickMath.getSqrtRatioAtTick(_tickUpper),
            _liquidity
        );
        return (_amount0, _amount1);
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
        _amounts = new uint256[](2);
        _amounts[0] = balanceOfToken(token0);
        _amounts[1] = balanceOfToken(token1);
        (uint256 _amount0, uint256 _amount1) = balanceOfPoolWants(baseMintInfo);
        _amounts[0] += _amount0;
        _amounts[1] += _amount1;
        (_amount0, _amount1) = balanceOfPoolWants(limitMintInfo);
        _amounts[0] += _amount0;
        _amounts[1] += _amount1;
    }

    function balanceOfPoolWants(MintInfo memory _mintInfo) internal view returns (uint256, uint256) {
        if (_mintInfo.tokenId == 0) return (0, 0);
        return
            getAmountsForLiquidity(
                _mintInfo.tickLower,
                _mintInfo.tickUpper,
                balanceOfLpToken(_mintInfo.tokenId)
            );
    }

    function get3rdPoolAssets() external view override returns (uint256 _totalAssets) {
        address _pool = IUniswapV3Factory(NONFUNGIBLE_POSITION_MANAGER.factory()).getPool(
            token0,
            token1,
            fee
        );
        _totalAssets = queryTokenValue(token0, IERC20Minimal(token0).balanceOf(_pool));
        _totalAssets += queryTokenValue(token1, IERC20Minimal(token1).balanceOf(_pool));
    }

    function claimRewards()
        internal
        override
        returns (address[] memory _rewardTokens, uint256[] memory _claimAmounts)
    {
        if (baseMintInfo.tokenId > 0) {
            __collectAll(baseMintInfo.tokenId);
        }

        if (limitMintInfo.tokenId > 0) {
            __collectAll(limitMintInfo.tokenId);
        }
    }

    function depositTo3rdPool(address[] memory _assets, uint256[] memory _amounts) internal override {
        (, int24 _tick, , , , , ) = pool.slot0();
        if (baseMintInfo.tokenId == 0) {
            (, , int24 _tickLower, int24 _tickUpper) = getSpecifiedRangesOfTick(_tick);
            mintNewPosition(_tickLower, _tickUpper, balanceOfToken(token0), balanceOfToken(token1), true);
        } else {
            if (shouldRebalance(_tick)) {
                rebalance(_tick);
            } else {
                //add liquidity
                INonfungiblePositionManager.IncreaseLiquidityParams
                    memory _params = INonfungiblePositionManager.IncreaseLiquidityParams({
                        tokenId: baseMintInfo.tokenId,
                        amount0Desired: balanceOfToken(token0),
                        amount1Desired: balanceOfToken(token1),
                        amount0Min: 0,
                        amount1Min: 0,
                        deadline: block.timestamp
                    });
                __addLiquidity(_params);
            }
        }
    }

    function withdrawFrom3rdPool(
        uint256 _withdrawShares,
        uint256 _totalShares,
        uint256 _outputCode
    ) internal override {
        withdraw(baseMintInfo.tokenId, _withdrawShares, _totalShares);
        withdraw(limitMintInfo.tokenId, _withdrawShares, _totalShares);
    }

    function withdraw(
        uint256 _tokenId,
        uint256 _withdrawShares,
        uint256 _totalShares
    ) internal {
        uint128 _withdrawLiquidity = uint128(
            (balanceOfLpToken(_tokenId) * _withdrawShares) / _totalShares
        );
        if (_withdrawLiquidity > 0) {
            removeLiquidity(_tokenId, _withdrawLiquidity);
        }
    }

    function removeLiquidity(uint256 _tokenId, uint128 _liquidity) internal {
        // remove liquidity
        INonfungiblePositionManager.DecreaseLiquidityParams memory _params = INonfungiblePositionManager
            .DecreaseLiquidityParams({
                tokenId: _tokenId,
                liquidity: _liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });
        __removeLiquidity(_params);
    }

    function balanceOfLpToken(uint256 _tokenId) public view returns (uint128) {
        if (_tokenId == 0) return 0;
        return __getLiquidityForNFT(_tokenId);
    }

    function rebalanceByKeeper() external isKeeper {
        (, int24 _tick, , , , , ) = pool.slot0();
        require(shouldRebalance(_tick), "cannot rebalance");
        rebalance(_tick);
    }

    function rebalance(int24 _tick) internal {
        // Withdraw all current liquidity
        uint128 _baseLiquidity = balanceOfLpToken(baseMintInfo.tokenId);
        if (_baseLiquidity > 0) {
            removeLiquidity(baseMintInfo.tokenId, _baseLiquidity);
            __collectAll(baseMintInfo.tokenId);
        }

        uint128 _limitLiquidity = balanceOfLpToken(limitMintInfo.tokenId);
        if (_limitLiquidity > 0) {
            removeLiquidity(limitMintInfo.tokenId, _limitLiquidity);
            __collectAll(limitMintInfo.tokenId);
        }

        // Mint new base and limit position
        (int24 _tickFloor, int24 _tickCeil, int24 _tickLower, int24 _tickUpper) = getSpecifiedRangesOfTick(
            _tick
        );
        uint256 _balance0 = balanceOfToken(token0);
        uint256 _balance1 = balanceOfToken(token1);
        (uint256 _tokenId, uint128 _liquidity, uint256 _amount0, uint256 _amount1) = mintNewPosition(
            _tickLower,
            _tickUpper,
            _balance0,
            _balance1,
            true
        );

        _balance0 = balanceOfToken(token0);
        _balance1 = balanceOfToken(token1);
        if (_balance0 > 0 || _balance1 > 0) {
            int24 _bidLower = _tickFloor - limitThreshold;
            int24 _askUpper = _tickCeil + limitThreshold;
            // Place bid or ask order on Uniswap depending on which token is left
            if (
                getLiquidityForAmounts(_tickFloor - limitThreshold, _tickFloor, _balance0, _balance1) >
                getLiquidityForAmounts(_tickCeil, _tickCeil + limitThreshold, _balance0, _balance1)
            ) {
                mintNewPosition(_tickFloor - limitThreshold, _tickFloor, _balance0, _balance1, false);
            } else {
                mintNewPosition(_tickCeil, _tickCeil + limitThreshold, _balance0, _balance1, false);
            }
        }
        lastTimestamp = block.timestamp;
        lastTick = _tick;
    }

    function shouldRebalance(int24 _tick) public view returns (bool) {
        // check enough time has passed
        if (block.timestamp < lastTimestamp + period) {
            return false;
        }

        // check price has moved enough
        if ((_tick > lastTick ? _tick - lastTick : lastTick - _tick) < minTickMove) {
            return false;
        }

        // check price near _twap
        int24 _twap = getTwap();
        int24 _twapDeviation = _tick > _twap ? _tick - _twap : _twap - _tick;
        if (_twapDeviation > maxTwapDeviation) {
            return false;
        }

        // check price not too close to boundary
        int24 _maxThreshold = baseThreshold > limitThreshold ? baseThreshold : limitThreshold;
        if (
            _tick < TickMath.MIN_TICK + _maxThreshold + tickSpacing ||
            _tick > TickMath.MAX_TICK - _maxThreshold - tickSpacing
        ) {
            return false;
        }

        return true;
    }

    function getLiquidityForAmounts(
        int24 _tickLower,
        int24 _tickUpper,
        uint256 _amount0,
        uint256 _amount1
    ) internal view returns (uint128) {
        (uint160 _sqrtPriceX96, , , , , , ) = pool.slot0();
        return
            LiquidityAmounts.getLiquidityForAmounts(
                _sqrtPriceX96,
                TickMath.getSqrtRatioAtTick(_tickLower),
                TickMath.getSqrtRatioAtTick(_tickUpper),
                _amount0,
                _amount1
            );
    }

    // Fetches time-weighted average price in ticks from Uniswap pool.
    function getTwap() public view returns (int24) {
        uint32[] memory _secondsAgo = new uint32[](2);
        _secondsAgo[0] = twapDuration;
        _secondsAgo[1] = 0;

        (int56[] memory _tickCumulatives, ) = pool.observe(_secondsAgo);
        return int24((_tickCumulatives[1] - _tickCumulatives[0]) / int32(twapDuration));
    }

    // Rounds _tick down towards negative infinity so that it's a multiple of `tickSpacing`.
    function _floor(int24 _tick) internal view returns (int24) {
        // _compressed=-27633, _tick=-276330, tickSpacing=10
        int24 _compressed = _tick / tickSpacing;
        if (_tick < 0 && _tick % tickSpacing != 0) _compressed--;
        return _compressed * tickSpacing;
    }

    function mintNewPosition(
        int24 _tickLower,
        int24 _tickUpper,
        uint256 _amount0Desired,
        uint256 _amount1Desired,
        bool _base
    )
        internal
        returns (
            uint256 _tokenId,
            uint128 _liquidity,
            uint256 _amount0,
            uint256 _amount1
        )
    {
        INonfungiblePositionManager.MintParams memory _params = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: _tickLower,
            tickUpper: _tickUpper,
            amount0Desired: _amount0Desired,
            amount1Desired: _amount1Desired,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        });
        (_tokenId, _liquidity, _amount0, _amount1) = __mint(_params);
        if (_base) {
            baseMintInfo = MintInfo({tokenId: _tokenId, tickLower: _tickLower, tickUpper: _tickUpper});
        } else {
            limitMintInfo = MintInfo({tokenId: _tokenId, tickLower: _tickLower, tickUpper: _tickUpper});
        }
    }

    function _checkThreshold(int24 _threshold) internal view {
        require(
            _threshold > 0 && _threshold <= TickMath.MAX_TICK && _threshold % tickSpacing == 0,
            "threshold validate error"
        );
    }

    function setBaseThreshold(int24 _baseThreshold) external onlyGovOrDelegate {
        _checkThreshold(_baseThreshold);
        baseThreshold = _baseThreshold;
        emit UniV3SetBaseThreshold(_baseThreshold);
    }

    function setLimitThreshold(int24 _limitThreshold) external onlyGovOrDelegate {
        _checkThreshold(_limitThreshold);
        limitThreshold = _limitThreshold;
        emit UniV3SetLimitThreshold(_limitThreshold);
    }

    function setPeriod(uint256 _period) external onlyGovOrDelegate {
        period = _period;
        emit UniV3SetPeriod(_period);
    }

    function setMinTickMove(int24 _minTickMove) external onlyGovOrDelegate {
        require(_minTickMove >= 0, "minTickMove must be >= 0");
        minTickMove = _minTickMove;
        emit UniV3SetMinTickMove(_minTickMove);
    }

    function setMaxTwapDeviation(int24 _maxTwapDeviation) external onlyGovOrDelegate {
        require(_maxTwapDeviation >= 0, "maxTwapDeviation must be >= 0");
        maxTwapDeviation = _maxTwapDeviation;
        emit UniV3SetMaxTwapDeviation(_maxTwapDeviation);
    }

    function setTwapDuration(uint32 _twapDuration) external onlyGovOrDelegate {
        require(_twapDuration > 0, "twapDuration must be > 0");
        twapDuration = _twapDuration;
        emit UniV3SetTwapDuration(_twapDuration);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import '@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-core/contracts/libraries/SqrtPriceMath.sol';
import "boc-contract-core/contracts/access-control/AccessControlMixin.sol";
import "./../external/uniswap/IUniswapV3.sol";
import './../external/uniswapv3/INonfungiblePositionManager.sol';
import './../external/uniswapv3/libraries/LiquidityAmounts.sol';
import './../enums/ProtocolEnum.sol';
import 'hardhat/console.sol';
import "../utils/actions/AaveLendActionMixin.sol";
import "../utils/actions/UniswapV3LiquidityActionsMixin.sol";
import "./UniswapV3RiskOnHelper.sol";
import "../../library/RiskOnConstant.sol";
import "./IUniswapV3RiskOnVault.sol";

/// @title UniswapV3RiskOnVault
/// @author Bank of Chain Protocol Inc
abstract contract UniswapV3RiskOnVault is IUniswapV3RiskOnVault, UniswapV3LiquidityActionsMixin, AaveLendActionMixin, AccessControlMixin, Initializable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMath for uint256;

    /// @notice  emergency shutdown
    bool public override emergencyShutdown;

    /// @notice  net market making amount
    uint256 public override netMarketMakingAmount;

    address internal owner;
    address public wantToken;
    int24 internal baseThreshold;
    int24 internal limitThreshold;
    int24 internal minTickMove;
    int24 internal maxTwapDeviation;
    int24 internal lastTick;
    int24 internal tickSpacing;
    uint256 internal period;
    uint256 internal lastTimestamp;
    uint32 internal twapDuration;
    MintInfo internal baseMintInfo;
    MintInfo internal limitMintInfo;
    UniswapV3RiskOnHelper internal uniswapV3RiskOnHelper;

    /// @notice Initialize this contract
    /// @param _owner The owner
    /// @param _wantToken The want token
    /// @param _pool The uniswap V3 pool
    /// @param _interestRateMode The interest rate mode
    /// @param _uniswapV3RiskOnHelper The uniswap v3 helper
    /// @param _baseThreshold The new base threshold
    /// @param _limitThreshold The new limit threshold
    /// @param _period The new period
    /// @param _minTickMove The minium tick to move
    /// @param _maxTwapDeviation The max TWAP deviation
    /// @param _twapDuration The max TWAP duration
    /// @param _tickSpacing The tick spacing
    function initialize(
        address _owner,
        address _wantToken,
        address _pool,
        uint256 _interestRateMode,
        address _uniswapV3RiskOnHelper,
        int24 _baseThreshold,
        int24 _limitThreshold,
        uint256 _period,
        int24 _minTickMove,
        int24 _maxTwapDeviation,
        uint32 _twapDuration,
        int24 _tickSpacing
    ) internal {
        super._initializeUniswapV3Liquidity(_pool);
        wantToken = _wantToken;
        super.__initLendConfigation(_interestRateMode, wantToken, wantToken == token0 ? token1 : token0);
        owner = _owner;
        baseThreshold = _baseThreshold;
        limitThreshold = _limitThreshold;
        period = _period;
        minTickMove = _minTickMove;
        maxTwapDeviation = _maxTwapDeviation;
        twapDuration = _twapDuration;
        tickSpacing = _tickSpacing;
        uniswapV3RiskOnHelper = UniswapV3RiskOnHelper(_uniswapV3RiskOnHelper);
    }

    /// @notice Return the version of strategy
    function getVersion() external pure override returns (string memory) {
        return "1.0.0";
    }

    /// @notice Gets the statuses about uniswap V3
    /// @return _owner The owner
    /// @return _wantToken The want token
    /// @return _baseThreshold The new base threshold
    /// @return _limitThreshold The new limit threshold
    /// @return _minTickMove The minium tick to move
    /// @return _maxTwapDeviation The max TWAP deviation
    /// @return _lastTick The last tick
    /// @return _tickSpacing The number of tickSpacing
    /// @return _period The new period
    /// @return _lastTimestamp The timestamp of last action
    /// @return _twapDuration The max TWAP duration
    function getStatus() public view override returns (address _owner, address _wantToken, int24 _baseThreshold, int24 _limitThreshold, int24 _minTickMove, int24 _maxTwapDeviation, int24 _lastTick, int24 _tickSpacing, uint256 _period, uint256 _lastTimestamp, uint32 _twapDuration) {
        return (owner, wantToken, baseThreshold, limitThreshold, minTickMove, maxTwapDeviation, lastTick, tickSpacing, period, lastTimestamp, twapDuration);
    }

    /// @notice Gets the info of LP V3 NFT minted
    function getMintInfo() public view override returns (uint256 _baseTokenId, int24 _baseTickUpper, int24 _baseTickLower, uint256 _limitTokenId, int24 _limitTickUpper, int24 _limitTickLower) {
        return (baseMintInfo.tokenId, baseMintInfo.tickUpper, baseMintInfo.tickLower, limitMintInfo.tokenId, limitMintInfo.tickUpper, limitMintInfo.tickLower);
    }

    /// @notice Total assets
    function estimatedTotalAssets() external view override returns (uint256 _totalAssets) {
        uint256 amount0 = balanceOfToken(token0);
        uint256 amount1 = balanceOfToken(token1);
        _totalAssets = depositTo3rdPoolTotalAssets();
        if (wantToken == token0) {
            _totalAssets += (amount0 + uniswapV3RiskOnHelper.getTotalCollateralTokenAmount(address(this), wantToken) + uniswapV3RiskOnHelper.calcCanonicalAssetValue(token1, amount1, token0) - uniswapV3RiskOnHelper.calcCanonicalAssetValue(token1, uniswapV3RiskOnHelper.getCurrentBorrow(borrowToken, interestRateMode, address(this)), token0));
        } else {
            _totalAssets += (amount1 + uniswapV3RiskOnHelper.getTotalCollateralTokenAmount(address(this), wantToken) + uniswapV3RiskOnHelper.calcCanonicalAssetValue(token0, amount0, token1) - uniswapV3RiskOnHelper.calcCanonicalAssetValue(token0, uniswapV3RiskOnHelper.getCurrentBorrow(borrowToken, interestRateMode, address(this)), token1));
        }
    }

    /// @notice Deposit to 3rd pool total assets
    function depositTo3rdPoolTotalAssets() public view returns (uint256 _totalAssets) {
        (uint256 _amount0, uint256 _amount1) = balanceOfPoolWants(baseMintInfo);
        uint256 amount0 = _amount0;
        uint256 amount1 = _amount1;
        (_amount0, _amount1) = balanceOfPoolWants(limitMintInfo);
        amount0 += _amount0;
        amount1 += _amount1;
        if (wantToken == token0) {
            _totalAssets = amount0 + uniswapV3RiskOnHelper.calcCanonicalAssetValue(token1, amount1, token0);
        } else {
            _totalAssets = amount1 + uniswapV3RiskOnHelper.calcCanonicalAssetValue(token0, amount0, token1);
        }
    }

    /// @notice Gets the two tokens' balances of LP V3 NFT
    /// @param _mintInfo  The info of LP V3 NFT
    /// @return The amount of token0
    /// @return The amount of token1
    function balanceOfPoolWants(MintInfo memory _mintInfo) internal view returns (uint256, uint256) {
        if (_mintInfo.tokenId == 0) return (0, 0);
        (uint160 _sqrtPriceX96, , , , , ,) = pool.slot0();
        return LiquidityAmounts.getAmountsForLiquidity(_sqrtPriceX96, TickMath.getSqrtRatioAtTick(_mintInfo.tickLower), TickMath.getSqrtRatioAtTick(_mintInfo.tickUpper), balanceOfLpToken(_mintInfo.tokenId));
    }

    /// @notice Harvests the Strategy
    /// @return  _rewardsTokens The reward tokens list
    /// @return _claimAmounts The claim amounts list
    function harvest() public override returns (address[] memory _rewardsTokens, uint256[] memory _claimAmounts) {
        _rewardsTokens = new address[](2);
        _rewardsTokens[0] = token0;
        _rewardsTokens[1] = token1;
        _claimAmounts = new uint256[](2);
        uint256 _amount0;
        uint256 _amount1;
        if (baseMintInfo.tokenId > 0) {
            (_amount0, _amount1) = __collectAll(baseMintInfo.tokenId);
            _claimAmounts[0] += _amount0;
            _claimAmounts[1] += _amount1;
        }

        if (limitMintInfo.tokenId > 0) {
            (_amount0, _amount1) = __collectAll(limitMintInfo.tokenId);
            _claimAmounts[0] += _amount0;
            _claimAmounts[1] += _amount1;
        }
        emit StrategyReported(_rewardsTokens, _claimAmounts);
    }

    function lend(uint256 _amount) external isOwner whenNotEmergency nonReentrant override {
        IERC20Upgradeable(wantToken).safeTransferFrom(msg.sender, address(this), _amount);
        __addCollateral(_amount.mul(2).div(3));
        __borrow(uniswapV3RiskOnHelper.calcCanonicalAssetValue(wantToken, _amount.div(3), borrowToken));
        (, int24 _tick,,,,,) = pool.slot0();
        if (baseMintInfo.tokenId == 0) {
            depositTo3rdPool(_tick);
        } else {
            if (shouldRebalance(_tick)) {
                rebalance(_tick);
            } else {
                // addLiquidityTo3rdPool
                uint256 _balance0 = balanceOfToken(token0);
                uint256 _balance1 = balanceOfToken(token1);
                if (_balance0 > 0 && _balance1 > 0) {
                    //add liquidity
                    nonfungiblePositionManager.increaseLiquidity(INonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId : baseMintInfo.tokenId,
                    amount0Desired : _balance0,
                    amount1Desired : _balance1,
                    amount0Min : 0,
                    amount1Min : 0,
                    deadline : block.timestamp
                    }));
                    _balance0 = balanceOfToken(token0);
                    _balance1 = balanceOfToken(token1);
                }
                if (_balance0 > 0 && _balance1 > 0) {
                    //add liquidity
                    nonfungiblePositionManager.increaseLiquidity(INonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId : limitMintInfo.tokenId,
                    amount0Desired : _balance0,
                    amount1Desired : _balance1,
                    amount0Min : 0,
                    amount1Min : 0,
                    deadline : block.timestamp
                    }));
                }
            }
        }
        netMarketMakingAmount += _amount;
        emit LendToStrategy(_amount);
    }

    function redeem(uint256 _redeemShares, uint256 _totalShares) external isOwner override returns (uint256 _redeemBalance) {
        _redeemBalance = redeemToVault(_redeemShares, _totalShares);
        if (_redeemBalance > netMarketMakingAmount) {
            netMarketMakingAmount = 0;
        } else {
            netMarketMakingAmount -= _redeemBalance;
        }
        IERC20Upgradeable(wantToken).safeTransfer(msg.sender, _redeemBalance);
        emit Redeem(_redeemBalance);
    }

    function redeemToVaultByKeeper(uint256 _redeemShares, uint256 _totalShares) external override returns (uint256 _redeemBalance) {
        _redeemBalance = redeemToVault(_redeemShares, _totalShares);
        emit RedeemToVault(_redeemBalance);
    }

    function redeemToVault(uint256 _redeemShares, uint256 _totalShares) internal whenNotEmergency nonReentrant returns (uint256 _redeemBalance) {
        uint256 currentBorrow = uniswapV3RiskOnHelper.getCurrentBorrow(borrowToken, interestRateMode, address(this));
        (uint256 _totalCollateral, , , , ,) = uniswapV3RiskOnHelper.borrowInfo(address(this));
        address aCollateralToken = uniswapV3RiskOnHelper.getAToken(wantToken);
        if (_redeemShares == _totalShares) {
            harvest();
            withdraw(baseMintInfo.tokenId, _redeemShares, _totalShares);
            withdraw(limitMintInfo.tokenId, _redeemShares, _totalShares);
            delete baseMintInfo;
            delete limitMintInfo;
            uint256 borrowTokenBalance = balanceOfToken(borrowToken);
            if (currentBorrow > borrowTokenBalance) {
                IERC20Upgradeable(wantToken).safeApprove(RiskOnConstant.UNISWAP_V3_ROUTER, 0);
                IERC20Upgradeable(wantToken).safeApprove(RiskOnConstant.UNISWAP_V3_ROUTER, balanceOfToken(wantToken));
                IUniswapV3(RiskOnConstant.UNISWAP_V3_ROUTER).exactOutputSingle(IUniswapV3.ExactOutputSingleParams(wantToken, borrowToken, fee, address(this), block.timestamp, currentBorrow - borrowTokenBalance, type(uint256).max, 0));
            }
            __repay(currentBorrow);
            __removeCollateral(aCollateralToken, IERC20(aCollateralToken).balanceOf(address(this)));
        } else {
            uint256 beforeWantTokenBalance = balanceOfToken(wantToken);
            uint256 beforeBorrowTokenBalance = balanceOfToken(borrowToken);
            withdraw(baseMintInfo.tokenId, _redeemShares, _totalShares);
            withdraw(limitMintInfo.tokenId, _redeemShares, _totalShares);
            //            uint256 redeemVaultWantTokenBalance = beforeWantTokenBalance * _redeemShares / _totalShares;
            //            uint256 redeemVaultBorrowTokenBalance = beforeBorrowTokenBalance * _redeemShares / _totalShares;
            //            uint256 redeemWantTokenBalance = afterWantTokenBalance - beforeWantTokenBalance;
            uint256 redeemBorrowTokenBalance = balanceOfToken(borrowToken) - beforeBorrowTokenBalance;
            uint256 redeemCurrentBorrow = currentBorrow * _redeemShares / _totalShares;
            if (redeemCurrentBorrow > redeemBorrowTokenBalance) {
                IERC20Upgradeable(wantToken).safeApprove(RiskOnConstant.UNISWAP_V3_ROUTER, 0);
                IERC20Upgradeable(wantToken).safeApprove(RiskOnConstant.UNISWAP_V3_ROUTER, balanceOfToken(wantToken));
                IUniswapV3(RiskOnConstant.UNISWAP_V3_ROUTER).exactOutputSingle(IUniswapV3.ExactOutputSingleParams(wantToken, borrowToken, fee, address(this), block.timestamp, redeemCurrentBorrow - redeemBorrowTokenBalance, type(uint256).max, 0));
            }
            __repay(redeemCurrentBorrow);
            __removeCollateral(aCollateralToken, IERC20(aCollateralToken).balanceOf(address(this)) * _redeemShares / _totalShares);
        }
        uint256 borrowTokenBalance = balanceOfToken(borrowToken);
        if (borrowTokenBalance > 0) {
            IERC20Upgradeable(borrowToken).safeApprove(RiskOnConstant.UNISWAP_V3_ROUTER, 0);
            IERC20Upgradeable(borrowToken).safeApprove(RiskOnConstant.UNISWAP_V3_ROUTER, borrowTokenBalance);
            IUniswapV3(RiskOnConstant.UNISWAP_V3_ROUTER).exactInputSingle(IUniswapV3.ExactInputSingleParams(borrowToken, wantToken, fee, address(this), block.timestamp, borrowTokenBalance, 0, 0));
        }
        _redeemBalance = balanceOfToken(wantToken);
    }

    /// @notice Remove partial liquidity of `_tokenId`
    /// @param _tokenId One tokenId to remove liquidity
    /// @param _redeemShares The amount of shares to withdraw
    /// @param _totalShares The total amount of shares owned by this strategy
    function withdraw(uint256 _tokenId, uint256 _redeemShares, uint256 _totalShares) internal {
        uint128 _withdrawLiquidity = uint128(balanceOfLpToken(_tokenId) * _redeemShares / _totalShares);
        if (_withdrawLiquidity <= 0) return;
        if (_redeemShares == _totalShares) {
            __purge(_tokenId, type(uint128).max, 0, 0);
        } else {
            // remove liquidity
            (uint256 _amount0, uint256 _amount1) = nonfungiblePositionManager.decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams({
            tokenId : _tokenId,
            liquidity : _withdrawLiquidity,
            amount0Min : 0,
            amount1Min : 0,
            deadline : block.timestamp
            }));
            if (_amount0 > 0 || _amount1 > 0) {
                __collect(_tokenId, uint128(_amount0), uint128(_amount1));
            }
        }
    }

    function borrowRebalance() external whenNotEmergency nonReentrant override {
        (uint256 _totalCollateral, uint256 _totalDebt, , , ,) = uniswapV3RiskOnHelper.borrowInfo(address(this));

        if (_totalDebt.mul(10000).div(_totalCollateral) >= 7500) {
            uint256 repayAmount = uniswapV3RiskOnHelper.calcCanonicalAssetValue(wantToken, (_totalDebt - _totalDebt.mul(5000).div(_totalDebt.mul(10000).div(_totalCollateral))), borrowToken);
            burnAll();
            //            console.log('borrowRebalance balanceOfToken(token0):%d, balanceOfToken(token1):%d, repayAmount:%d', balanceOfToken(token0), balanceOfToken(token1), repayAmount);
            if (balanceOfToken(borrowToken) < repayAmount) {
                IERC20Upgradeable(wantToken).safeApprove(RiskOnConstant.UNISWAP_V3_ROUTER, 0);
                IERC20Upgradeable(wantToken).safeApprove(RiskOnConstant.UNISWAP_V3_ROUTER, balanceOfToken(wantToken));
                IUniswapV3(RiskOnConstant.UNISWAP_V3_ROUTER).exactOutputSingle(IUniswapV3.ExactOutputSingleParams(wantToken, borrowToken, 500, address(this), block.timestamp, repayAmount - balanceOfToken(borrowToken), type(uint256).max, 0));
                //                console.log('borrowRebalance balanceOfToken(token0):%d, balanceOfToken(token1):%d, else', balanceOfToken(token0), balanceOfToken(token1));
            }
            __repay(repayAmount);
        }
        if (_totalDebt.mul(10000).div(_totalCollateral) <= 3750) {
            //            console.log('borrowRebalance priceOracleGetter.getAssetPrice:%d', (newTotalDebt - _totalDebt).mul(1e6).div(priceOracleGetter.getAssetPrice(token0)));
            //            console.log('borrowRebalance priceOracleGetter.getAssetPrice:%d', priceOracleConsumer.valueInTargetToken(token1, (newTotalDebt - _totalDebt), token0));
            __borrow(uniswapV3RiskOnHelper.calcCanonicalAssetValue(wantToken, (_totalDebt.mul(5000).div(_totalDebt.mul(10000).div(_totalCollateral)) - _totalDebt), borrowToken));
        }
        //        (_totalCollateral, _totalDebt, _availableBorrowsETH, _currentLiquidationThreshold, _ltv, _healthFactor) = borrowInfo();
        //        console.log('----------------%d,%d', _totalCollateral, _totalDebt);
        //        console.log('----------------%d,%d', _availableBorrowsETH, _currentLiquidationThreshold);
        //        console.log('----------------%d,%d', _ltv, _healthFactor);
        //        console.log('----------------%d', getCurrentBorrow());
        (, int24 _tick,,,,,) = pool.slot0();
        rebalance(_tick);
    }

    function burnAll() internal {
        harvest();
        // Withdraw all current liquidity
        uint128 _baseLiquidity = balanceOfLpToken(baseMintInfo.tokenId);
        if (_baseLiquidity > 0) {
            __purge(baseMintInfo.tokenId, type(uint128).max, 0, 0);
            delete baseMintInfo;
        }

        uint128 _limitLiquidity = balanceOfLpToken(limitMintInfo.tokenId);
        if (_limitLiquidity > 0) {
            __purge(limitMintInfo.tokenId, type(uint128).max, 0, 0);
            delete limitMintInfo;
        }
    }

    /// @notice Rebalance the position of this strategy
    /// Requirements: only keeper can call
    function rebalanceByKeeper() external whenNotEmergency nonReentrant override {
        (, int24 _tick,,,,,) = pool.slot0();
        require(shouldRebalance(_tick), "NR");
        rebalance(_tick);
    }

    /// @notice Rebalance the position of this strategy
    /// @param _tick The new tick to invest
    function rebalance(int24 _tick) internal {
        harvest();
        // Withdraw all current liquidity
        uint128 _baseLiquidity = balanceOfLpToken(baseMintInfo.tokenId);
        if (_baseLiquidity > 0) {
            __purge(baseMintInfo.tokenId, type(uint128).max, 0, 0);
            delete baseMintInfo;
        }

        uint128 _limitLiquidity = balanceOfLpToken(limitMintInfo.tokenId);
        if (_limitLiquidity > 0) {
            __purge(limitMintInfo.tokenId, type(uint128).max, 0, 0);
            delete limitMintInfo;
        }

        if (_baseLiquidity <= 0 && _limitLiquidity <= 0) return;

        depositTo3rdPool(_tick);
    }

    /// @notice Gets the total liquidity of `_tokenId` NFT position.
    /// @param _tokenId One tokenId
    /// @return The total liquidity of `_tokenId` NFT position
    function balanceOfLpToken(uint256 _tokenId) internal view returns (uint128) {
        if (_tokenId == 0) return 0;
        return __getLiquidityForNFT(_tokenId);
    }

    /// @notice Check if rebalancing is possible
    /// @param _tick The tick to check
    /// @return Returns 'true' if it should rebalance, otherwise return 'false'
    function shouldRebalance(int24 _tick) public view override returns (bool) {
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
        if (_tick < TickMath.MIN_TICK + _maxThreshold + tickSpacing || _tick > TickMath.MAX_TICK - _maxThreshold - tickSpacing) {
            return false;
        }

        (, , int24 _tickLower, int24 _tickUpper) = uniswapV3RiskOnHelper.getSpecifiedRangesOfTick(_tick, tickSpacing, baseThreshold);
        if (baseMintInfo.tokenId != 0 && _tickLower == baseMintInfo.tickLower && _tickUpper == baseMintInfo.tickUpper) {
            return false;
        }

        return true;
    }

    /// @notice Fetches time-weighted average price in ticks from Uniswap pool.
    function getTwap() public view returns (int24) {
        uint32[] memory _secondsAgo = new uint32[](2);
        _secondsAgo[0] = twapDuration;
        _secondsAgo[1] = 0;

        (int56[] memory _tickCumulatives,) = pool.observe(_secondsAgo);
        return int24((_tickCumulatives[1] - _tickCumulatives[0]) / int32(twapDuration));
    }

    function depositTo3rdPool(int24 _tick) internal {
        // Mint new base and limit position
        (int24 _tickFloor, int24 _tickCeil, int24 _tickLower, int24 _tickUpper) = uniswapV3RiskOnHelper.getSpecifiedRangesOfTick(_tick, tickSpacing, baseThreshold);
        uint256 _balance0 = balanceOfToken(token0);
        uint256 _balance1 = balanceOfToken(token1);
        if (_balance0 > 0 && _balance1 > 0) {
            mintNewPosition(_tickLower, _tickUpper, _balance0, _balance1, true);
            _balance0 = balanceOfToken(token0);
            _balance1 = balanceOfToken(token1);
        }

        if (_balance0 > 0 || _balance1 > 0) {
            // Place bid or ask order on Uniswap depending on which token is left
            if (getLiquidityForAmounts(_tickFloor - limitThreshold, _tickFloor, _balance0, _balance1) > getLiquidityForAmounts(_tickCeil, _tickCeil + limitThreshold, _balance0, _balance1)) {
                mintNewPosition(_tickFloor - limitThreshold, _tickFloor, _balance0, _balance1, false);
            } else {
                mintNewPosition(_tickCeil, _tickCeil + limitThreshold, _balance0, _balance1, false);
            }
        }
        lastTimestamp = block.timestamp;
        lastTick = _tick;
    }

    /// @notice Gets the liquidity for the two amounts
    /// @param _tickLower  The specified lower tick
    /// @param _tickUpper  The specified upper tick
    /// @param _amount0 The amount of token0
    /// @param _amount1 The amount of token1
    /// @return The liquidity being valued
    function getLiquidityForAmounts(int24 _tickLower, int24 _tickUpper, uint256 _amount0, uint256 _amount1) internal view returns (uint128) {
        (uint160 _sqrtPriceX96, , , , , ,) = pool.slot0();
        return LiquidityAmounts.getLiquidityForAmounts(_sqrtPriceX96, TickMath.getSqrtRatioAtTick(_tickLower), TickMath.getSqrtRatioAtTick(_tickUpper), _amount0, _amount1);
    }

    /// @notice Mints a new uniswap V3 position, receiving an nft as a receipt
    /// @param _tickLower The lower tick of the new position in which to add liquidity
    /// @param _tickUpper The upper tick of the new position in which to add liquidity
    /// @param _amount0Desired The amount of token0 desired to invest
    /// @param _amount1Desired The amount of token1 desired to invest
    /// @param _base The boolean flag to start base mint,
    ///     'true' to base mint,'false' to limit mint
    /// @return _tokenId The ID of the token that represents the minted position
    /// @return _liquidity The amount of liquidity for this new position minted
    /// @return _amount0 The amount of token0 that was paid to mint the given amount of liquidity
    /// @return _amount1 The amount of token1 that was paid to mint the given amount of liquidity
    function mintNewPosition(
        int24 _tickLower,
        int24 _tickUpper,
        uint256 _amount0Desired,
        uint256 _amount1Desired,
        bool _base
    ) internal returns (
        uint256 _tokenId,
        uint128 _liquidity,
        uint256 _amount0,
        uint256 _amount1
    )
    {
        (_tokenId, _liquidity, _amount0, _amount1) = __mint(INonfungiblePositionManager.MintParams({
        token0 : token0,
        token1 : token1,
        fee : fee,
        tickLower : _tickLower,
        tickUpper : _tickUpper,
        amount0Desired : _amount0Desired,
        amount1Desired : _amount1Desired,
        amount0Min : 0,
        amount1Min : 0,
        recipient : address(this),
        deadline : block.timestamp
        }));
        if (_base) {
            baseMintInfo = MintInfo({tokenId : _tokenId, tickLower : _tickLower, tickUpper : _tickUpper});
        } else {
            limitMintInfo = MintInfo({tokenId : _tokenId, tickLower : _tickLower, tickUpper : _tickUpper});
        }
    }

    /// @notice Return the token's balance Of this contract
    function balanceOfToken(address _tokenAddress) internal view returns (uint256) {
        return IERC20Upgradeable(_tokenAddress).balanceOf(address(this));
    }

    /// @dev Shutdown the vault when an emergency occurs, cannot mint/burn.
    /// Requirements: only vault manager can call
    function setEmergencyShutdown(bool _active) external isVaultManager override {
        emergencyShutdown = _active;
        emit SetEmergencyShutdown(_active);
    }

    modifier isOwner() {
        require(msg.sender == owner, "NO");
        _;
    }

    modifier whenNotEmergency() {
        require(!emergencyShutdown, "ES");
        _;
    }

    /// @notice Sets `baseThreshold` state variable
    /// Requirements: only vault manager  can call
    function setBaseThreshold(int24 _baseThreshold) external isVaultManager override {
        _checkThreshold(_baseThreshold);
        baseThreshold = _baseThreshold;
        emit UniV3UpdateConfig();
    }

    /// @notice Sets `limitThreshold` state variable
    /// Requirements: only vault manager  can call
    function setLimitThreshold(int24 _limitThreshold) external isVaultManager override {
        _checkThreshold(_limitThreshold);
        limitThreshold = _limitThreshold;
        emit UniV3UpdateConfig();
    }

    /// @notice Check the Validity of `_threshold`
    function _checkThreshold(int24 _threshold) internal view {
        require(_threshold > 0 && _threshold <= TickMath.MAX_TICK && _threshold % tickSpacing == 0, "TE");
    }

    /// @notice Sets `period` state variable
    /// Requirements: only vault manager  can call
    function setPeriod(uint256 _period) external isVaultManager override {
        period = _period;
        emit UniV3UpdateConfig();
    }

    /// @notice Sets `minTickMove` state variable
    /// Requirements: only vault manager  can call
    function setMinTickMove(int24 _minTickMove) external isVaultManager override {
        require(_minTickMove >= 0, "MINE");
        minTickMove = _minTickMove;
        emit UniV3UpdateConfig();
    }

    /// @notice Sets `maxTwapDeviation` state variable
    /// Requirements: only vault manager  can call
    function setMaxTwapDeviation(int24 _maxTwapDeviation) external isVaultManager override {
        require(_maxTwapDeviation >= 0, "MAXE");
        maxTwapDeviation = _maxTwapDeviation;
        emit UniV3UpdateConfig();
    }

    /// @notice Sets `twapDuration` state variable
    /// Requirements: only vault manager  can call
    function setTwapDuration(uint32 _twapDuration) external isVaultManager override {
        require(_twapDuration > 0, "TWAPE");
        twapDuration = _twapDuration;
        emit UniV3UpdateConfig();
    }
}

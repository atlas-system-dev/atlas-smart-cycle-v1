// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./libraries/TickMath.sol";
import "./libraries/LiquidityAmounts.sol";

import "./interfaces/IPancakeV3Factory.sol";
import "./interfaces/IPancakeV3Pool.sol";
import "./interfaces/INonfungiblePositionManager.sol";

contract PositionHandler {
    using SafeERC20 for *;

    IPancakeV3Factory constant factory = IPancakeV3Factory(0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865);
    INonfungiblePositionManager constant nfpm = INonfungiblePositionManager(0x46A15B0b27311cedF172AB29E4f4766fbE7F4364);
    IERC20Metadata immutable token;
    IPancakeV3Pool immutable pool;
    uint256 immutable tokenDecimals;
    bool immutable tokenIsToken0;

    uint256 public tokenId;

    constructor(
        address token_,
        uint256 tokenId_
    ) {
        require(tokenId_ != 0, "Invalid token id");

        token = IERC20Metadata(token_);
        tokenDecimals = token.decimals();
        tokenId = tokenId_;

        (,, address token0, address token1, uint24 fee,,,,,,,) = nfpm.positions(tokenId_);
        require(token_ == token0 || token_ == token1, "Wrong token");
        tokenIsToken0 = token_ == token0;

        pool = IPancakeV3Pool(factory.getPool(token0, token1, fee));
        _checkPositionSide(tokenId_);
    }

    function _changeTokenId(uint256 tokenId_) internal {
        require(tokenId_ != 0, "Invalid token id");

        (,, address token0, address token1, uint24 fee,,,,,,,) = nfpm.positions(tokenId_);
        address pool_ = factory.getPool(token0, token1, fee);
        require(pool_ == address(pool), "Wrong position");

        _checkPositionSide(tokenId_);

        tokenId = tokenId_;
    }

    function _depositPool(uint256 amount, uint256 tokenId_) internal returns (uint256 amountOut) {
        _checkPositionSide(tokenId_);

        token.safeTransferFrom(msg.sender, address(this), amount);
        token.approve(address(nfpm), amount);

        INonfungiblePositionManager.IncreaseLiquidityParams memory params
            = INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId_,
                amount0Desired: tokenIsToken0 ? amount : 0,
                amount1Desired: !tokenIsToken0 ? amount : 0,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        (, uint256 amount0, uint256 amount1) = nfpm.increaseLiquidity(params);

        amountOut = tokenIsToken0 ? amount0 : amount1;

        /* solcov ignore next */
        if (amountOut < amount) {
            token.safeTransfer(msg.sender, amount - amountOut);
        }
    }

    function _withdrawPool(uint256 amount, uint256 tokenId_) internal returns (uint256 amountOut) {
        _checkPositionSide(tokenId_);

        uint128 liquidity = _getLiquidityForAmount(amount, tokenId_);

        INonfungiblePositionManager.DecreaseLiquidityParams memory paramsDecrease 
            = INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId_,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });

        nfpm.decreaseLiquidity(paramsDecrease);

        INonfungiblePositionManager.CollectParams memory paramsCollect =
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId_,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (uint256 amount0, uint256 amount1) = nfpm.collect(paramsCollect);

        amountOut = tokenIsToken0 ? amount0 : amount1;
    }

    function _getLiquidityForAmount(uint256 amount, uint256 tokenId_) internal view returns (uint128 liquidity) {
        (,,,,, int24 tickLower, int24 tickUpper,,,,,) = nfpm.positions(tokenId_);
        uint160 sqrtA = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtB = TickMath.getSqrtRatioAtTick(tickUpper);
        
        liquidity = tokenIsToken0
            ? LiquidityAmounts.getLiquidityForAmount0(sqrtA, sqrtB, amount)
            : LiquidityAmounts.getLiquidityForAmount1(sqrtA, sqrtB, amount);

        require(liquidity > 0, "Amount too small");

        liquidity += 1;
    }

    function _checkPositionSide(uint256 tokenId_) internal view {
        (,,,,, int24 tickLower, int24 tickUpper,,,,,) = nfpm.positions(tokenId_);

        (, int24 tick,,,,,) = pool.slot0();

        if (tokenIsToken0) {
            require(tick < tickLower, "Wrong side");
        } else {
            require(tick >= tickUpper, "Wrong side");
        }
    }
}
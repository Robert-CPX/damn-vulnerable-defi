// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ClimberVault.sol";

contract NewClimberVault is ClimberVault {

  function withdrawAll(address tokenAddress) external onlyOwner {
    IERC20 token = IERC20(tokenAddress);
    require(token.transfer(msg.sender, token.balanceOf(address(this))), "Transfer failed");
  }
}


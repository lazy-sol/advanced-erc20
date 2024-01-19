// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../token/AdvancedERC20.sol";

// Token extension to simplify Compound-like voting delegation testing
contract AdvCompMock is AdvancedERC20 {
	constructor(
		string memory _name,
		string memory _symbol,
		address _initialHolder,
		uint256 _initialSupply,
		uint256 _features
	) AdvancedERC20(
		msg.sender,
		_name,
		_symbol,
		_initialHolder,
		_initialSupply,
		_features
	) {}

	// replaces 3 transactions in CompTest to be put into single block with a single transaction
	function __delegate_transfer_transfer(address a1, address a2, uint256 val) public {
		delegate(a1);      // transaction 1
		transfer(a2, val); // transaction 2
		transfer(a2, val); // transaction 3
	}

	// taken from CompHarness.sol, used in CompScenarioTest
	function generateCheckpoints(uint count, uint offset) external {
		for (uint i = 1 + offset; i <= count + offset; i++) {
			votingPowerHistory[msg.sender].push(KV(uint64(i), uint192(i)));
		}
	}
}

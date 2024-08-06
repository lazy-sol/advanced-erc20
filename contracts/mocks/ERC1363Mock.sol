// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../interfaces/ERC1363Spec.sol";
import "./Forwarder.sol";

/// @dev Mock for ERC1363Receiver/ERC1363Spender interfaces
contract LightweightERC1363Mock is ERC1363Receiver, ERC1363Spender, Forwarder {
	// an event to be fired in `onTransferReceived`
	event OnTransferReceived(address indexed operator, address indexed from, uint256 value, bytes data);
	// an event to be fired in `onApprovalReceived`
	event OnApprovalReceived(address indexed owner, uint256 value, bytes data);

	/// @inheritdoc ERC1363Receiver
	function onTransferReceived(address operator, address from, uint256 value, bytes memory data) public override returns (bytes4) {
		// emit an event
		emit OnTransferReceived(operator, from, value, data);

		// always return "success"
		return ERC1363Receiver(this).onTransferReceived.selector;
	}

	/// @inheritdoc ERC1363Spender
	function onApprovalReceived(address owner, uint256 value, bytes memory data) external override returns (bytes4) {
		// emit an event
		emit OnApprovalReceived(owner, value, data);

		// always return "success"
		return ERC1363Spender(this).onApprovalReceived.selector;
	}
}

/// @dev Mock for ERC1363Receiver/ERC1363Spender interfaces
contract ConfigurableERC1363Mock is ERC1363Receiver, ERC1363Spender, Forwarder {
	bytes4 private retVal;
	string private errMsg;

	// an event to be fired in `onTransferReceived`
	event OnTransferReceived(address indexed operator, address indexed from, uint256 value, bytes data);
	// an event to be fired in `onApprovalReceived`
	event OnApprovalReceived(address indexed owner, uint256 value, bytes data);

	function setRetVal(bytes4 _retVal) public {
		retVal = _retVal;
	}

	function setErrMsg(string calldata _errMsg) public {
		errMsg = _errMsg;
	}

	/// @inheritdoc ERC1363Receiver
	function onTransferReceived(address operator, address from, uint256 value, bytes memory data) public override returns (bytes4) {
		if(bytes(errMsg).length > 0) {
			revert(errMsg);
		}

		// emit an event
		emit OnTransferReceived(operator, from, value, data);

		// return "success" or custom code
		return retVal == bytes4(0)? ERC1363Receiver(this).onTransferReceived.selector: retVal;
	}

	/// @inheritdoc ERC1363Spender
	function onApprovalReceived(address owner, uint256 value, bytes memory data) external override returns (bytes4) {
		if(bytes(errMsg).length > 0) {
			revert(errMsg);
		}

		// emit an event
		emit OnApprovalReceived(owner, value, data);

		// return "success" or custom code
		return retVal == bytes4(0)? ERC1363Spender(this).onApprovalReceived.selector: retVal;
	}
}

// mock contract required for vittominacori's ERC1363.behaviour
contract ERC1363ReceiverMock is ERC1363Receiver {
	bytes4 private immutable _retval;
	bool private immutable _reverts;

	event Received(
		address operator,
		address sender,
		uint256 amount,
		bytes data,
		uint256 gas
	);

	constructor(bytes4 retval, bool reverts) {
		_retval = retval;
		_reverts = reverts;
	}

	function onTransferReceived(address operator, address sender, uint256 amount, bytes memory data) public override returns (bytes4) {
		require(!_reverts, "ERC1363ReceiverMock: throwing");
		emit Received(operator, sender, amount, data, gasleft());
		return _retval;
	}
}

// mock contract required for vittominacori's ERC1363.behaviour
contract ERC1363SpenderMock is ERC1363Spender {
	bytes4 private immutable _retval;
	bool private immutable _reverts;

	event Approved(
		address sender,
		uint256 amount,
		bytes data,
		uint256 gas
	);

	constructor(bytes4 retval, bool reverts) {
		_retval = retval;
		_reverts = reverts;
	}

	function onApprovalReceived(address sender, uint256 amount, bytes memory data) public override returns (bytes4) {
		require(!_reverts, "ERC1363SpenderMock: throwing");
		emit Approved(sender, amount, data, gasleft());
		return _retval;
	}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@lazy-sol/access-control-upgradeable/contracts/UpgradeableAccessControl.sol";

/**
 * @title Generic Factory, a.k.a Generic Smart Contract Deployer
 *
 * @notice A helper stand-alone contract allowing to "clone" anything
 *
 * @dev The deployment is done via EIP-1167 Minimal Proxy Contract
 *      See https://eips.ethereum.org/EIPS/eip-1167
 *
 * @author Basil Gorin
 */
contract GenericFactoryV1 is UpgradeableAccessControl {
	/**
	 * @dev Fired in clone()
	 *
	 * @param by an address which made the deployment (clone), msg.sender
	 * @param proxyAddress deployed EIP-1167 clone (proxy) address,
	 *      this is the main `clone()` function output
	 * @param implAddress impl address used for cloning
	 * @param data optional data bytes passed to the proxy for initialization;
	 *      can be empty, in which case this means proxy wasn't initialized
	 * @param returnData when data field is used, contains the response from low-level
	 *      proxy initialization call; can be empty
	 */
	event ProxyDeployed(
		address indexed by,
		address proxyAddress,
		address indexed implAddress,
		bytes data,
		bytes returnData
	);

	/**
	 * @dev "Constructor replacement" for a smart contract with a delayed initialization (post-deployment initialization)
	 */
	function postConstruct() public initializer {
		// initialize the RBAC module
		_postConstruct(msg.sender, 0);
	}

	/**
	 * @notice Clones the specified contract and optionally initializes it immediately
	 *
	 * @dev Technically this deploys a tiny EIP 1167 proxy pointing to the impl address specified
	 *      and optionally initializes it immediately, making the deployment safe and ready for use
	 *
	 * @dev Throws on proxy initialization failure
	 *
	 * @param _implAddress contract implementation address to clone
	 * @param _data optional bytes data to execute the low-level call on cloned instance for initialization
	 */
	function clone(address _implAddress, bytes calldata _data) public returns(address proxyAddress, bytes memory returnData) {
		// "clone" the impl (deploy a proxy)
		proxyAddress = __clone(_implAddress);

		// if initialization data is specified
		if(_data.length > 0) {
			// allocate the variable to store low-level call status
			bool success;
			// initialize the proxy by invoking the low-level call
			(success, returnData) = proxyAddress.call(_data);
			// we require the call to be successful
			require(success, "proxy initialization failed");
		}

		// emit an event
		emit ProxyDeployed(msg.sender, proxyAddress, _implAddress, _data, returnData);

		// explicitly return the results
		return (proxyAddress, returnData);
	}

	/**
	 * @dev EIP-1167: Minimal Proxy Contract implementation copied from OpenZeppelin Clones
	 *
	 * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
	 *      This function uses the create opcode, which should never revert.
	 */
	function __clone(address implementation) private returns (address instance) {
		/// @solidity memory-safe-assembly
		assembly {
			// Cleans the upper 96 bits of the `implementation` word, then packs the first 3 bytes
			// of the `implementation` address with the bytecode before the address.
			mstore(0x00, or(shr(0xe8, shl(0x60, implementation)), 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000))
			// Packs the remaining 17 bytes of `implementation` with the bytecode after the address.
			mstore(0x20, or(shl(0x78, implementation), 0x5af43d82803e903d91602b57fd5bf3))
			instance := create(0, 0x09, 0x37)
		}
		require(instance != address(0), "ERC1167: create failed");
	}
}

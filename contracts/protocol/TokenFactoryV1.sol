// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../token/AdvancedERC20.sol";

import "@lazy-sol/access-control-upgradeable/contracts/UpgradeableAccessControl.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * @title Token Deployer
 *
 * @notice A helper stand-alone contract allowing to "clone" an ERC20 Token
 *
 * @dev The deployment is done via EIP-1167 Minimal Proxy Contract
 *      See https://eips.ethereum.org/EIPS/eip-1167
 *
 * @author Basil Gorin
 */
contract TokenFactoryV1 is UpgradeableAccessControl {
	/**
	 * @notice An address of already deployed ERC20 token used as an implementation
	 *
	 * @dev The deployed minimalistic proxy always points to this implementation
	 */
	address public erc20ImplAddress;

	/**
	 * @dev Fired in deployERC20
	 *
	 * @param proxyAddress deployed EIP-1167 clone (proxy) address
	 * @param implAddress ERC20 impl address, always the same
	 * @param name token name to set
	 * @param symbol token symbol to set
	 * @param initialHolder owner of the initial token supply
	 * @param initialSupply initial token supply
	 */
	event ERC20ProxyDeployed(
		address proxyAddress,
		address indexed implAddress,
		string name,
		string symbol,
		address indexed initialHolder,
		uint256 initialSupply
	);

	/**
	 * @dev Deploys a ERC20Deployer instance bound to an already deployed
	 *      ERC20 token instance implementation to be used to create EIP-1167 "clones"
	 *
	 * @param _erc20ImplAddress ERC20 token instance to bind to
	 */
	function postConstruct(address _erc20ImplAddress) public initializer {
		// verify the address is set
		require(_erc20ImplAddress != address(0), "zero address");

		// set the address
		erc20ImplAddress = _erc20ImplAddress;

		// initialize the RBAC module
		_postConstruct(msg.sender, 0);
	}

	/**
	 * @notice "Deploys" ERC20 token with the specified name, symbol, initial total supply
	 *
	 * @dev Technically this deploys a tiny proxy pointing to the token impl address `erc20ImplAddress`
	 *      and initialized it immediately, making the deployment safe and ready for use
	 *
	 * @param _initialHolder owner of the initial token supply
	 * @param _initialSupply initial token supply
	 * @param _name token name to set
	 * @param _symbol token symbol to set
	 */
	function deployERC20(
		string memory _name,
		string memory _symbol,
		address _initialHolder,
		uint256 _initialSupply
	) public {
		// delegate to `deployERC20`
		deployERC20(erc20ImplAddress, _name, _symbol, _initialHolder, _initialSupply);
	}

	/**
	 * @notice "Deploys" ERC20 token with the specified name, symbol, initial total supply
	 *
	 * @dev Technically this deploys a tiny proxy pointing to the token impl address `erc20ImplAddress`
	 *      and initialized it immediately, making the deployment safe and ready for use
	 *
	 * @param _erc20ImplAddress AdvancedERC20 impl address to use
	 * @param _initialHolder owner of the initial token supply
	 * @param _initialSupply initial token supply
	 * @param _name token name to set
	 * @param _symbol token symbol to set
	 */
	function deployERC20(
		address _erc20ImplAddress,
		string memory _name,
		string memory _symbol,
		address _initialHolder,
		uint256 _initialSupply
	) public {
		// "clone" the impl (deploy a proxy)
		address _proxyAddress = Clones.clone(_erc20ImplAddress);

		// initialize a proxy by invoking the postConstruct
		// factory moves the ownership on the token to the tx executor
		// setup token features to all (0xFFFF)
		AdvancedERC20(_proxyAddress).postConstruct(msg.sender, _name, _symbol, _initialHolder, _initialSupply, 0xFFFF);

		// emit an event
		emit ERC20ProxyDeployed(
			_proxyAddress,
			_erc20ImplAddress,
			_name,
			_symbol,
			_initialHolder,
			_initialSupply
		);
	}
}

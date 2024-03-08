// Zeppelin helper constants
const {
	ZERO_ADDRESS,
	ZERO_BYTES32,
	MAX_UINT256,
} = require("@lazy-sol/zeppelin-test-helpers/src/constants");

// ERC20 deployment routines in use
const {
	advanced_erc20_deploy_restricted,
} = require("../../advanced_erc20/include/deployment_routines");

/**
 * Deploys token factory capable of deploying AdvancedERC20
 * @param a0 smart contract owner, super admin
 * @param erc20_impl_address ERC20 implementation address to use, optional
 * @returns TokenFactory(AdvancedERC20)
 */
async function deploy_token_factory(a0, erc20_impl_address) {
	// deploy ERC20 implementation if required
	if(!erc20_impl_address) {
		// token name, symbol, supply are not important
		({address: erc20_impl_address} = await advanced_erc20_deploy_restricted(
			a0,
			ZERO_ADDRESS,
			0,
			"implementation contract, not for use",
			"N/A",
			ZERO_ADDRESS,
		));
	}

	// deploy factory implementation contract
	const TokenFactory = artifacts.require("TokenFactoryV1");
	const instance = await TokenFactory.new({from: a0});

	// deploy ERC1967 proxy, immediately initializing it
	const Proxy = artifacts.require("./ERC1967Proxy");
	const init_data = instance.contract.methods.postConstruct(erc20_impl_address).encodeABI();
	const proxy = await Proxy.new(instance.address, init_data, {from: a0});

	// return the results
	return {factory: await TokenFactory.at(proxy.address), erc20_impl_address};
}

// export public deployment API
module.exports = {
	deploy_token_factory,
};

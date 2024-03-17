// Zeppelin helper constants
const {
	ZERO_ADDRESS,
	ZERO_BYTES32,
	MAX_UINT256,
} = require("@lazy-sol/zeppelin-test-helpers/src/constants");

// ERC20 deployment routines in use
const {
	NAME,
	SYMBOL,
	TOTAL_SUPPLY: S0,
	advanced_erc20_deploy_detached,
} = require("../../advanced_erc20/include/deployment_routines");

// RBAC features and roles
const {FEATURE_ALL} = require("../../../scripts/include/features_roles");

/**
 * Deploys generic factory capable of cloning any smart contract
 * @param a0 smart contract owner, super admin
 * @returns GenericFactory instance
 */
async function deploy_generic_factory(a0) {
	// deploy factory implementation contract
	const GenericFactory = artifacts.require("GenericFactoryV1");
	const instance = await GenericFactory.new({from: a0});

	// deploy ERC1967 proxy, and immediately initializing it
	const Proxy = artifacts.require("./ERC1967Proxy");
	const init_data = instance.contract.methods.postConstruct().encodeABI();
	const proxy = await Proxy.new(instance.address, init_data, {from: a0});

	// return the factory instance
	return await GenericFactory.at(proxy.address);
}

/**
 * Deploys TinyERC721 contract with some meaningless name and symbol, the deployed
 * contract to be used for cloning via the Generic Factory
 * @param a0 smart contract deployed
 * @returns TinyERC721 instance
 */
async function deploy_advanced_erc20_implementation_contract(a0) {
	// deploy implementation and return
	return await advanced_erc20_deploy_detached(a0, ZERO_ADDRESS, 0, "impl contract, not for use", "N/A");
}

/**
 * Clones the AdvancedERC20 implementation contract via the GenericFactory
 *
 * @param factory GenericFactory instance to use
 * @param impl AdvancedERC20 implementation contract to clone
 * @param a0 clone contract owner to set
 * @param H0 initial token supply owner
 * @param relayer cloning transaction executor
 * @returns AdvancedERC20 clone (EIP-1167 Minimal Proxy)
 */
async function generic_factory_clone(factory, impl, a0, H0 = a0, relayer = a0) {
	const init_data = impl.contract.methods.postConstruct(a0, NAME, SYMBOL, H0, S0, FEATURE_ALL).encodeABI();
	const receipt = await factory.clone(impl.address, init_data, {from: relayer});
	const proxyAddress = receipt.logs.find(log => log.event === "ProxyDeployed").args.proxyAddress;
	const instance = await impl.constructor.at(proxyAddress);

	return {receipt, instance, init_data};
}

// export public deployment API
module.exports = {
	NAME,
	SYMBOL,
	deploy_generic_factory,
	deploy_advanced_erc20_implementation_contract,
	generic_factory_clone,
};

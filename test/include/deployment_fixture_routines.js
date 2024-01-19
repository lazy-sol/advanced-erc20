// we use hardhat deployment to work with fixtures
// see https://github.com/wighawag/hardhat-deploy#creating-fixtures
const {deployments} = require('hardhat');

/**
 * Gets ERC20 token with all the features enabled
 *
 * @returns ERC20 instance
 */
async function get_erc20_deployment() {
	// make sure fixtures were deployed, this can be also done via --deploy-fixture test flag
	// see https://github.com/wighawag/hardhat-deploy#creating-fixtures
	await deployments.fixture();

	// get deployed contract address
	const {address} = await deployments.get("AdvancedERC20_Impl");

	// connect to the contract instance and return it
	const Contract = artifacts.require("./ERC20Mock");
	return await Contract.at(address);
}

/**
 * Gets Upgradeable ERC20 token with all the features enabled
 *
 * @returns Upgradeable ERC20 instance (ERC1967 Proxy)
 */
async function get_erc20_upgradeable_deployment() {
	// make sure fixtures were deployed, this can be also done via --deploy-fixture test flag
	// see https://github.com/wighawag/hardhat-deploy#creating-fixtures
	await deployments.fixture();

	// get deployed contract address
	const {address} = await deployments.get("ERC20_Proxy");

	// connect to the contract instance and return it
	const Contract = artifacts.require("./UpgradeableERC20Mock");
	return await Contract.at(address);
}

// export public deployment API
module.exports = {
	get_erc20_deployment,
	get_erc20_upgradeable_deployment,
};

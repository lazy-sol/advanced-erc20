// Zeppelin test helpers constants
const {
	ZERO_ADDRESS,
	ZERO_BYTES32,
	MAX_UINT256,
} = require("@openzeppelin/test-helpers").constants;

// ERC20 constants
const {
	NAME,
	SYMBOL,
	TOTAL_SUPPLY: S0,
} = require("./erc20_constants");

// RBAC token features and roles
const {FEATURE_ALL} = require("../../../scripts/include/features_roles");

/**
 * Deploys AdvancedERC20 token with all the features enabled
 *
 * @param a0 smart contract owner, super admin
 * @param H0 initial token holder address, optional
 * @param s0 initial token supply, optional
 * @param name ERC20 token name, optional
 * @param symbol ERC20 token symbol, optional
 * @returns AdvancedERC20 instance
 */
async function advanced_erc20_deploy(a0, H0 = a0, s0 = S0, name = NAME, symbol = SYMBOL) {
	// smart contracts required
	const AdvancedERC20 = artifacts.require("./AdvancedERC20");

	// deploy and return the reference to the instance
	return await AdvancedERC20.new(a0, name, symbol, H0, s0, FEATURE_ALL, {from: a0});
}

/**
 * Deploys AdvancedERC20 token with no features enabled
 *
 * @param a0 smart contract owner, super admin
 * @param H0 initial token holder address, optional
 * @param s0 initial token supply, optional
 * @param name ERC20 token name, optional
 * @param symbol ERC20 token symbol, optional
 * @returns AdvancedERC20 instance
 */
async function advanced_erc20_deploy_restricted(a0, H0 = a0, s0 = S0, name = NAME, symbol = SYMBOL) {
	// smart contracts required
	const AdvancedERC20 = artifacts.require("./AdvancedERC20");

	// deploy and return the reference to the instance
	return await AdvancedERC20.new(a0, name, symbol, H0, s0, 0, {from: a0});
}

/**
 * Deploys AdvancedERC20 token with no owner
 *
 * @param a0 smart contract deployer
 * @param H0 initial token holder address, optional
 * @param s0 initial token supply, optional
 * @param name ERC20 token name, optional
 * @param symbol ERC20 token symbol, optional
 * @returns AdvancedERC20 instance
 */
async function advanced_erc20_deploy_detached(a0, H0 = a0, s0 = S0, name = NAME, symbol = SYMBOL) {
	// smart contracts required
	const AdvancedERC20 = artifacts.require("./AdvancedERC20");

	// deploy and return the reference to the instance
	return await AdvancedERC20.new(ZERO_ADDRESS, name, symbol, H0, s0, 0, {from: a0});
}

/**
 * Deploys AdvancedERC20 token Comp mock with all the features enabled
 *
 * @param a0 smart contract owner, super admin
 * @param H0 initial token holder address
 * @param s0 initial token supply
 * @param name ERC20 token name
 * @param symbol ERC20 token symbol
 * @returns AdvancedERC20 instance
 */
async function advanced_erc20_deploy_comp_mock(a0, H0 = a0, s0 = S0, name = NAME, symbol = SYMBOL) {
	// smart contracts required
	const AdvCompMock = artifacts.require("./AdvCompMock");

	// deploy token Comp mock and return
	return await AdvCompMock.new(name, symbol, H0, s0, FEATURE_ALL, {from: a0});
}

/**
 * Deploys ERC1363 acceptor, which can accept ERC1363 transfers/approvals
 *
 * @param a0 smart contract owner, super admin
 * @returns ERC1363Receiver/ERC1363Spender instance
 */
async function erc1363_deploy_acceptor(a0) {
	// smart contracts required
	const ERC1363Mock = artifacts.require("./ERC1363Mock");

	// deploy ERC1363 mock and return
	return await ERC1363Mock.new({from: a0});
}

// export public deployment API
module.exports = {
	advanced_erc20_deploy,
	advanced_erc20_deploy_restricted,
	advanced_erc20_deploy_detached,
	// advanced_erc20_deploy_via_factory,
	// advanced_erc20_deploy_restricted_via_factory,
	advanced_erc20_deploy_comp_mock,
	erc1363_deploy_acceptor,
	// deploy_token_factory,
};

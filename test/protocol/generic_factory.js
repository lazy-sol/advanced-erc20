// GenericFactory: EIP-1167 Minimal Proxy clonning tests

// Zeppelin test helpers
const {
	BN,
	constants,
	expectEvent,
	expectRevert,
} = require("@lazy-sol/zeppelin-test-helpers");
const {
	assert,
	expect,
} = require("chai");
const {
	ZERO_ADDRESS,
	ZERO_BYTES32,
	MAX_UINT256,
} = constants;

// RBAC token features and roles
const {
	FULL_PRIVILEGES_MASK,
	FEATURE_ALL,
} = require("../../scripts/include/features_roles");

// deployment routines in use
const {
	NAME,
	SYMBOL,
	deploy_generic_factory,
	deploy_advanced_erc20_implementation_contract,
	generic_factory_clone,
} = require("./include/deployment_routines");

// run GenericFactory tests
contract("Generic Factory", function(accounts) {
	// extract accounts to be used:
	// A0 – special default zero account accounts[0] used by Truffle, reserved
	// a0 – deployment account having all the permissions, reserved
	// H0 – initial token holder account
	// a1, a2,... – working accounts to perform tests on
	const [A0, a0, H0, a1, a2] = accounts;

	describe("when factory is already deployed", function() {
		let factory, erc20_impl;
		beforeEach(async function() {
			factory = await deploy_generic_factory(a0);
			erc20_impl = await deploy_advanced_erc20_implementation_contract(a0);
		});

		describe("it deploys ERC20 (proxy) successfully", function() {
			const relayer = a1;
			const owner = a2;

			let receipt, token, init_data;
			beforeEach(async function() {
				({receipt, instance: token, init_data} = await generic_factory_clone(factory, erc20_impl, owner, H0, relayer));
			});
			it("ProxyDeployed event is emitted", async function() {
				expectEvent(receipt, "ProxyDeployed", {
					by: relayer,
					proxyAddress: token.address,
					implAddress: erc20_impl.address,
					data: init_data,
					returnData: null,
				});
			});
			describe("admin access to the deployed ERC20 (proxy) is granted to the requested owner", function() {
				it("factory has zero 0x00 permissions on the deployed ERC20 (proxy)", async function() {
					expect(await token.getRole(factory.address)).to.be.bignumber.that.equals("0");
				});
				it("factory owner has zero 0x00 permissions on the deployed ERC20 (proxy)", async function() {
					expect(await token.getRole(a0)).to.be.bignumber.that.equals("0");
				});
				it("deployer (relayer) has zero 0x00 permissions on the deployed ERC20 (proxy)", async function() {
					expect(await token.getRole(relayer)).to.be.bignumber.that.equals("0");
				});
				it("owner has full 0xFF...FF permissions on the deployed ERC20 (proxy)", async function() {
					expect(await token.getRole(owner)).to.be.bignumber.that.equals(FULL_PRIVILEGES_MASK);
				});
			});
			it("deployed ERC721 (proxy) has all main features 0xFFFF enabled", async function() {
				expect(await token.features()).to.be.bignumber.that.equals("" + FEATURE_ALL);
			});
			it("postConstruct cannot be executed on the deployed ERC20 (proxy)", async function() {
				await expectRevert(token.postConstruct(a0, NAME, SYMBOL, H0, 0, 0), "already initialized");
			});
		});
	});
});

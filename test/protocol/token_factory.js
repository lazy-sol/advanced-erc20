// TokenFactory: ERC20 deployment tests

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

// token constants
const {
	NAME,
	SYMBOL,
	TOTAL_SUPPLY: S0,
} = require("../advanced_erc20/include/erc20_constants");

// deployment routines in use
const {
	deploy_token_factory,
} = require("./include/deployment_routines");

// run TokenFactory tests
contract("Token Factory", function(accounts) {
	// extract accounts to be used:
	// A0 – special default zero account accounts[0] used by Truffle, reserved
	// a0 – deployment account having all the permissions, reserved
	// H0 – initial token holder account
	// a1, a2,... – working accounts to perform tests on
	const [A0, a0, H0, a1, a2] = accounts;

	describe("factory deployment", function() {
		it("fails if no ERC20 implementation is specified (zero address)", async function() {
			await expectRevert(deploy_token_factory(a0, ZERO_ADDRESS), "zero address");
		});
		describe("succeeds otherwise", function() {
			let factory;
			beforeEach(async function() {
				({factory} = await deploy_token_factory(a0, a1));
			});
			it("ERC20 implementation address gets set correctly", async function() {
				expect(await factory.erc20ImplAddress()).to.equal(a1);
			});
			it("postConstruct cannot be executed (for a second time)", async function() {
				await expectRevert(factory.postConstruct(a1, {from: a0}), "Initializable: contract is already initialized");
			});
		});
	});
	describe("when factory is already deployed", function() {
		let factory, erc20_impl_address;
		beforeEach(async function() {
			({factory, erc20_impl_address} = await deploy_token_factory(a0));
		});

		describe("it deploys ERC20 (proxy) successfully", function() {
			let receipt, token;
			beforeEach(async function() {
				receipt = await factory.methods["deployERC20(string,string,address,uint256)"](NAME, SYMBOL, H0, S0, {from: a1});

				const proxyAddress = receipt.logs.find(log => log.event === "ERC20ProxyDeployed").args.proxyAddress;
				const AdvancedERC20 = artifacts.require("AdvancedERC20");
				token = await AdvancedERC20.at(proxyAddress);
			});
			it("ERC20ProxyDeployed event is emitted", async function() {
				expectEvent(receipt, "ERC20ProxyDeployed", {
					// proxyAddress: cannot be predicted, this is function output
					implAddress: erc20_impl_address,
					name: NAME,
					symbol: SYMBOL,
					initialHolder: H0,
					initialSupply: "" + S0,
				});
			});
			describe("admin access to the deployed ERC20 (proxy) is granted to the deployer (user)", function() {
				it("factory has zero 0x00 permissions on the deployed ERC20 (proxy)", async function() {
					expect(await token.getRole(factory.address)).to.be.bignumber.that.equals("0");
				});
				it("factory owner has zero 0x00 permissions on the deployed ERC20 (proxy)", async function() {
					expect(await token.getRole(a0)).to.be.bignumber.that.equals("0");
				});
				it("deployer (user) has full 0xFF...FF permissions on the deployed ERC20 (proxy)", async function() {
					expect(await token.getRole(a1)).to.be.bignumber.that.equals(FULL_PRIVILEGES_MASK);
				});
			});
			it("deployed ERC20 (proxy) has all main features 0xFFFF enabled", async function() {
				expect(await token.features()).to.be.bignumber.that.equals("" + FEATURE_ALL);
			});
			it("postConstruct cannot be executed on the deployed ERC20 (proxy)", async function() {
				await expectRevert(token.postConstruct(a0, NAME, SYMBOL, H0, S0, 0), "already initialized");
			});
		});
	});
});

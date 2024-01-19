// ERC20: Deployment Tests

// Zeppelin test helpers
const {
	BN,
	constants,
	expectEvent,
	expectRevert,
} = require("@openzeppelin/test-helpers");
const {
	assert,
	expect,
} = require("chai");
const {
	ZERO_ADDRESS,
	ZERO_BYTES32,
	MAX_UINT256,
} = constants;

// token constants
const {
	NAME,
	SYMBOL,
	TOTAL_SUPPLY: S0,
} = require("./include/erc20_constants");

// EIP712 helpers
const {eip712_cancel} = require("./include/eip712");
// deployment routines in use
const {
	advanced_erc20_deploy_detached,
} = require("./include/deployment_routines");

// event helper functions in use
const {
	expectEventInTransaction
} = require("../include/event_helper");

// run ERC20 deployment tests
contract("ERC20: Deployment tests", function(accounts) {
	// extract accounts to be used:
	// A0 – special default zero account accounts[0] used by Truffle, reserved
	// a0 – deployment account having all the permissions, reserved
	// H0 – initial token holder account
	const [A0, a0, H0, a1] = accounts;

	// define test suite
	function test_suite(suite_name, deployment_fn) {
		describe(suite_name, function() {
			// define token
			let token;

			function deploys(a0) {
				it("deployment account doesn't get ownership (has zero permissions)", async function()  {
					expect(await token.getRole(a0)).to.be.bignumber.that.equals("0");
				});
				it("zero account doesn't get ownership (has zero permissions)", async function()  {
					expect(await token.getRole(ZERO_ADDRESS)).to.be.bignumber.that.equals("0");
				});
				it("contract gets initialized properly", async function() {
					expect(await token.getInitializedVersion()).to.be.bignumber.that.equals("1");
				});
			}

			describe("when deployment arguments are correct", function() {
				describe("when H0 is not a deployment account a0", function() {
					beforeEach(async function() {
						token = await deployment_fn(a0, H0, S0, NAME, SYMBOL);
					});
					it("H0 doesn't have any permissions", async function() {
						expect(await token.getRole(H0)).to.be.a.bignumber.that.equals('0');
					});

					deploys(a0, H0, S0, NAME, SYMBOL);
				});
				describe("when S0 is zero", function() {
					const S0 = 0;

					beforeEach(async function() {
						token = await deployment_fn(a0, H0, S0, NAME, SYMBOL);
					});

					deploys(a0, H0, S0, NAME, SYMBOL);
				});
			});
		});
	}

	// run test suite
	test_suite("AdvancedERC20", advanced_erc20_deploy_detached);
});

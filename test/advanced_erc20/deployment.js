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

// deployment routines in use
const {
	advanced_erc20_deploy_restricted,
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

			function deploys(a0, H0, S0, NAME, SYMBOL) {
				S0 = new BN(S0);
				it("contract owner gets set correctly", async function()  {
					expect(await token.getRole(a0)).to.be.bignumber.that.equals(MAX_UINT256);
				});
				it("contract gets initialized properly", async function() {
					expect(await token.getInitializedVersion()).to.be.bignumber.that.equals("1");
				});
				it("token name gets set correctly", async function() {
					expect(await token.name()).to.equal(NAME);
				});
				it("token symbol gets set correctly", async function() {
					expect(await token.symbol()).to.equal(SYMBOL);
				});
				it("initial token supply is S0", async function() {
					expect(await token.totalSupply(), "incorrect S0").to.be.a.bignumber.that.equals(S0);
				});
				it("H0 gets the entire initial balance B0 = S0", async function() {
					expect(await token.balanceOf(H0), "B0 ≠ S0").to.be.a.bignumber.that.equals(S0);
				});
				it("H0 doesn't have a delegate", async function() {
					expect(await token.votingDelegates(H0)).to.equal(ZERO_ADDRESS);
				});
				it("initial H0 voting power is zero", async function() {
					expect(await token.votingPowerOf(H0)).to.be.a.bignumber.that.equals('0');
				});
				it("votingPowerHistoryOf(H0) is empty", async function() {
					expect(await token.votingPowerHistoryOf(H0)).to.be.an('array').that.is.empty;
				});
				it("postConstruct cannot be executed on the deployed token", async function() {
					await expectRevert(token.postConstruct(a0, NAME, SYMBOL, H0, S0, 0), "already initialized");
				});
				if(S0.gt(new BN(0))) {
					it("entireSupplyHistory has single element", async function() {
						expect((await token.entireSupplyHistory()).length).to.equal(1);
					});
					it("totalSupplyHistoryLength is one", async function() {
						expect(await token.totalSupplyHistoryLength()).to.be.bignumber.that.equals('1');
					});
					it("emits Minted event", async function() {
						await expectEvent.inConstruction(token, "Minted", {
							by: a0,
							to: H0,
							value: S0
						});
					});
					it("emits improved Transfer event (arXiv:1907.00903)", async function() {
						await expectEventInTransaction(token.transactionHash, "Transfer", [{
							type: "address",
							name: "by",
							indexed: true,
							value: a0,
						}, {
							type: "address",
							name: "from",
							indexed: true,
							value: ZERO_ADDRESS,
						}, {
							type: "address",
							name: "to",
							indexed: true,
							value: H0,
						}, {
							type: "uint256",
							name: "value",
							value: S0,
						}]);
					});
					it("emits ERC20 Transfer event", async function() {
						await expectEventInTransaction(token.transactionHash, "Transfer", [{
							type: "address",
							name: "from",
							indexed: true,
							value: ZERO_ADDRESS,
						}, {
							type: "address",
							name: "to",
							indexed: true,
							value: H0,
						}, {
							type: "uint256",
							name: "value",
							value: S0,
						}]);
					});
				}
				else {
					it("entireSupplyHistory is empty", async function() {
						expect((await token.entireSupplyHistory()).length).to.equal(0);
					});
					it("totalSupplyHistoryLength is zero", async function() {
						expect(await token.totalSupplyHistoryLength()).to.be.bignumber.that.equals('0');
					});
				}
			}

			describe("when deployment arguments are incorrect", function() {
				it("reverts when initial holder H0 is not set (zero) but initial supply is set (not zero)", async function() {
					// noinspection UnnecessaryLocalVariableJS
					const H0 = ZERO_ADDRESS;
					await expectRevert(deployment_fn(a0, H0, S0, NAME, SYMBOL), "_initialHolder not set (zero address)");
				});
				it("reverts when token name is not set (empty string)", async function() {
					// noinspection UnnecessaryLocalVariableJS
					const NAME = "";
					await expectRevert(deployment_fn(a0, H0, S0, NAME, SYMBOL), "token name is not set");
				});
				it("reverts when token symbol is not set (empty string)", async function() {
					// noinspection UnnecessaryLocalVariableJS
					const SYMBOL = "";
					await expectRevert(deployment_fn(a0, H0, S0, NAME, SYMBOL), "token symbol is not set");
				});
			});
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
				describe("when H0 is a0", function() {
					const a0 = H0;

					beforeEach(async function() {
						token = await deployment_fn(a0, H0, S0, NAME, SYMBOL);
					});
					it("H0 preservers full permissions bitmask", async function() {
						expect(await token.getRole(H0)).to.be.a.bignumber.that.equals(MAX_UINT256);
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
	test_suite("AdvancedERC20", advanced_erc20_deploy_restricted);
});

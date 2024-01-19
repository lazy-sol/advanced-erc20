// OpenZeppelin ERC20 Tests Runner
// See https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/test/token/ERC20/

// token constants
// token constants
const {
	NAME,
	SYMBOL,
	DECIMALS,
	TOTAL_SUPPLY: S0,
} = require("./include/erc20_constants");

// RBAC token features and roles
const {
	ROLE_TOKEN_CREATOR,
	ROLE_TOKEN_DESTROYER,
} = require("../../scripts/include/features_roles");

// Zeppelin unit tests – delivered as behaviours
// basic ERC20 behaviours
const {
	shouldBehaveLikeERC20,
	shouldBehaveLikeERC20Transfer, // TODO: use it to verify ERC1363 transfers
	shouldBehaveLikeERC20Approve,  // TODO: use it to verify ERC1363 approvals
} = require("./include/zeppelin/ERC20.behavior");
// extended ERC20 behaviours
const {
	shouldHaveBasicProps,
	shouldHaveAtomicApprove,
	shouldHaveMint,
	shouldHaveBurn,
} = require("./include/zeppelin/ERC20.behavior.ext");

// deployment routines in use
const {
	advanced_erc20_deploy,
} = require("./include/deployment_routines");

// run OpenZeppelin ERC20 tests
contract("ERC20: OpenZeppelin ERC20 Tests", function(accounts) {
	// extract accounts to be used:
	// A0 – special default zero account accounts[0] used by Truffle, reserved
	// a0 – deployment account having all the permissions, reserved
	// H0 – initial token holder account
	// a1, a2,... – working accounts to perform tests on
	const [A0, a0, H0, a1, a2] = accounts;

	// define test suite
	function test_suite(suite_name, deployment_fn, S0, name, symbol, decimals) {
		describe(suite_name, function() {
			// deploy token
			let token;
			beforeEach(async function() {
				token = await deployment_fn.call(this, a0, H0, S0, name, symbol, decimals);
			});

			function run_zeppelin_erc20_tests(S0, H0, a1, a2) {
				// Zeppelin global setup
				beforeEach(async function() {
					// Zeppelin uses this.token shortcut to access token instance
					this.token = token;
				});

				describe("ERC20 shouldBehaveLikeERC20", function() {
					// Zeppelin setup for ERC20 transfers: not required, full set of features already on deployment
					shouldBehaveLikeERC20("", S0, H0, a1, a2);
				});
				describe("ERC20 shouldHaveMint (ext)", function() {
					// Zeppelin setup for token minting
					beforeEach(async function() {
						// Zeppelin uses default zero account A0 (accounts[0]) to mint tokens,
						// grant this address a permission to mint
						await token.updateRole(A0, ROLE_TOKEN_CREATOR, {from: a0});
					});
					shouldHaveMint("", S0, H0, a1);
				});
				describe("ERC20 shouldHaveBurn (ext)", function() {
					// Zeppelin setup for token burning
					beforeEach(async function() {
						// Zeppelin uses default zero account A0 (accounts[0]) to burn tokens,
						// grant this address a permission to burn
						await token.updateRole(A0, ROLE_TOKEN_DESTROYER, {from: a0});
					});
					shouldHaveBurn("", S0, H0);
				});
				describe("ERC20 shouldHaveBasicProps (ext)", function() {
					shouldHaveBasicProps(name, symbol, decimals);
				});
				describe("ERC20 shouldHaveApprove (ext)", function() {
					shouldHaveAtomicApprove("", S0, H0, a1);
				});
			}

			describe("without voting delegation involved", function() {
				run_zeppelin_erc20_tests(S0, H0, a1, a2);
			});
			describe("with voting delegation involved", function() {
				// Zeppelin setup for case with delegation involved
				beforeEach(async function() {
					// delegate voting powers of accounts to themselves
					await token.delegate(H0, {from: H0});
					await token.delegate(a1, {from: a1});
					await token.delegate(a2, {from: a2});
				});
				run_zeppelin_erc20_tests(S0, H0, a1, a2);
			});
		});
	}

	// run test suite
	test_suite("AdvancedERC20", advanced_erc20_deploy, S0, NAME, SYMBOL, DECIMALS);
});

// OpenZeppelin Voting Tests Runner
// See https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/test/token/ERC20/

// token constants
const {
	CONTRACT_NAME,
	SYMBOL,
	TOTAL_SUPPLY: S0,
} = require("./include/erc20_constants");

// RBAC token features and roles
const {
	ROLE_TOKEN_CREATOR,
	ROLE_TOKEN_DESTROYER,
} = require("../../scripts/include/features_roles");

// Zeppelin unit tests – delivered as behaviours
// voting behaviour as in ERC20Votes.test.js
const {shouldBehaveLikeVoting} = require("./include/zeppelin/Voting.behavior");

// deployment routines in use
const {
	advanced_erc20_deploy,
} = require("./include/deployment_routines");

// run OpenZeppelin voting delegation tests
contract("OpenZeppelin Voting Delegation Tests", function(accounts) {
	// extract accounts to be used:
	// A0 – special default zero account accounts[0] used by Truffle, reserved
	// a0 – deployment account having all the permissions, reserved
	// H0 – initial token holder account
	// a1, a2,... – working accounts to perform tests on
	const [A0, a0, H0, a1, a2] = accounts;

	// define test suite
	function test_suite(suite_name, deployment_fn, eip712_name) {
		describe(suite_name, function() {
			// deploy token
			let token;
			beforeEach(async function() {
				token = await deployment_fn.call(this, a0, H0);
			});

			{
				// Zeppelin global setup
				beforeEach(async function() {
					// Zeppelin uses this.token shortcut to access token instance
					this.token = token;

					// Zeppelin voting delegation test suite expects initial supply to be zero,
					// it is going to mint total supply tokens itself with A0
					await token.updateRole(A0, ROLE_TOKEN_CREATOR | ROLE_TOKEN_DESTROYER, {from: a0});

					// burn all the tokens: Zeppelin is going to mint them itself
					await token.burn(H0, S0, {from: H0});
				});

				// initialize holder as a1, recipient as a2, ... and so on
				const [ holder, recipient, holderDelegatee, other1, other2 ] = accounts.slice(4);
				// function parameters' names are as in the original Voting tests
				shouldBehaveLikeVoting(eip712_name, SYMBOL, S0, holder, recipient, holderDelegatee, other1, other2);
			}
		});
	}

	// run test suite
	test_suite("AdvancedERC20", advanced_erc20_deploy, CONTRACT_NAME);
});

// Compound-like Voting Delegation Tests Runner
// See https://github.com/compound-finance/compound-protocol/blob/master/tests/Governance/
// Note: CompScenarioTest.js not in scope

// token constants
const {
	NAME,
	CONTRACT_NAME,
	SYMBOL,
	TOTAL_SUPPLY: S0,
} = require("./include/erc20_constants");

// Compound unit tests – delivered as behaviours
const {shouldBehaveLikeComp} = require("./include/comp/Comp.behavior");

// deployment routines in use
const {
	advanced_erc20_deploy_comp_mock,
} = require("./include/deployment_routines");

// run Compound-like voting delegation tests
contract("ERC20: Compound-like Voting Delegation Tests", function(accounts) {
	// extract accounts to be used:
	// A0 – special default zero account accounts[0] used by Truffle, reserved
	// a0 – deployment account having all the permissions, reserved
	// H0 – initial token holder account
	// a1, a2,... – working accounts to perform tests on
	const [A0, a0, H0, a1, a2, a3, a4, a5] = accounts;

	function voting_comp_suite(suite_name, deployment_fn, eip712_name) {
		describe(suite_name, function() {
			let token;
			beforeEach(async function() {
				token = await deployment_fn(a0, H0);
			});
		
			{
				// create empty account with known private key
				const w = web3.eth.accounts.create();
		
				// Compound global setup
				beforeEach(async function() {
					// Compound-like uses this.comp shortcut to access token instance
					this.comp = token;
				});
		
				// execute Compound tests, passing accounts as Compound expects
				shouldBehaveLikeComp(NAME, eip712_name, SYMBOL, S0, H0, w.address, a2, a3, w.privateKey);
			}
		});
	}

	voting_comp_suite("AdvancedERC20", advanced_erc20_deploy_comp_mock, CONTRACT_NAME);
});

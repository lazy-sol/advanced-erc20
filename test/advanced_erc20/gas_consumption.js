// ERC20: Gas Consumption Tests (non-functional requirements' compliance)

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

// BN constants and utilities, block utils
const {
	random_bn,
	extract_gas,
} = require("@lazy-sol/a-missing-gem");

// token constants
const {
	CONTRACT_NAME,
	TOTAL_SUPPLY: S0,
} = require("./include/erc20_constants");

// EIP712 helpers
const {
	eip712_delegate,
	eip712_permit,
	eip712_transfer,
	eip712_receive,
} = require("./include/eip712");

// RBAC token features and roles
const {ROLE_TOKEN_CREATOR} = require("../../scripts/include/features_roles");

// deployment routines in use
const {
	advanced_erc20_deploy,
	erc1363_deploy_acceptor,
} = require("./include/deployment_routines");
const {
	deploy_generic_factory,
	generic_factory_clone,
} = require("../protocol/include/deployment_routines");

// run gas consumption tests (non-functional requirements' compliance)
contract("AdvancedERC20: Gas Consumption (Non-functional Requirements) tests", function(accounts) {
	// extract accounts to be used:
	// A0 – special default zero account accounts[0] used by Truffle, reserved
	// a0 – deployment account having all the permissions, reserved
	// H0 – initial token holder account
	// a1, a2,... – working accounts to perform tests on
	const [A0, a0, H0, a1, a2] = accounts;

	let token;
	beforeEach(async function() {
		token = await advanced_erc20_deploy(a0, H0);
	});

	describe("Non-functional Requirements compliance", function() {
		// expiration, deadlines, validity defaults
		const expiry = 10e9;
		const deadline = 10e9;
		const validBefore = 10e9;
		const validAfter = 10e3;
		// create empty account with known private key
		const w = web3.eth.accounts.create();
		// builds EIP712 domain
		async function eip712_domain() {
			// Chain ID opcode hardcoded at 1 in Ganache-cli, but not in Hardhat
			// See: https://github.com/trufflesuite/ganache/issues/1643
			//      https://github.com/trufflesuite/ganache-core/issues/515
			const chainId = await web3.eth.net.getId();
			// build the domain
			return {name: CONTRACT_NAME, chainId, verifyingContract: token.address};
		}

		describe("Gas Consumption", function() {
			const by = a1;
			const from = H0;
			const to = a2;
			let value; // using randomized value for every test
			beforeEach(async function() {
				value = random_bn(1, S0.divn(2));
			});

			// delegate with auth is used in many places and therefore is extracted here
			async function delegate_with_auth(delegate, nonce) {
				const {v, r, s} = await eip712_delegate(token.address,  delegate, nonce, expiry, w.privateKey);
				return await token.delegateWithAuthorization(delegate, nonce, expiry, v, r, s, {from: by});
			}

			let receipt;
			function consumes_no_more_than(gas) {
				// tests marked with @skip-on-coverage will are removed from solidity-coverage,
				// see yield-solcover.js, see https://github.com/sc-forks/solidity-coverage/blob/master/docs/advanced.md
				it(`consumes no more than ${gas} gas  [ @skip-on-coverage ]`, async function() {
					const gasUsed = extract_gas(receipt);
					expect(gasUsed).to.be.lte(gas);
					if(gas - gasUsed > 41) {
						console.log("only %o gas was used while expected up to %o", gasUsed, gas);
					}
				});
			}
			function gas_usage_transfers(g1, g2, g3, g4, g5, g6, g7, g8) {
				describe("direct transfer", function() {
					beforeEach(async function() {
						receipt = await token.transfer(to, value, {from});
					});
					consumes_no_more_than(g1);
				});
				describe("transfer on behalf", function() {
					beforeEach(async function() {
						await token.approve(by, value.muln(2), {from});
						receipt = await token.transferFrom(from, to, value, {from: by});
					});
					consumes_no_more_than(g2);
				});
				describe("transfer on behalf with unlimited allowance", function() {
					beforeEach(async function() {
						await token.approve(by, MAX_UINT256, {from});
						receipt = await token.transferFrom(from, to, value, {from: by});
					});
					consumes_no_more_than(g3);
				});
				describe("ERC-1363 transfer and call", function() {
					beforeEach(async function() {
						const acceptor = await erc1363_deploy_acceptor(a0);
						receipt = await (token.methods["transferAndCall(address,uint256)"](acceptor.address, value, {from}));
					});
					consumes_no_more_than(g4);
				});
				describe("ERC-1363 transfer from and call", function() {
					beforeEach(async function() {
						const acceptor = await erc1363_deploy_acceptor(a0);
						await token.approve(by, value.muln(2), {from});
						receipt = await (token.methods["transferFromAndCall(address,address,uint256)"](from, acceptor.address, value, {from: by}));
					});
					consumes_no_more_than(g5);
				});
				describe("ERC-1363 transfer from and call with unlimited allowance", function() {
					beforeEach(async function() {
						const acceptor = await erc1363_deploy_acceptor(a0);
						await token.approve(by, MAX_UINT256, {from});
						receipt = await (token.methods["transferFromAndCall(address,address,uint256)"](from, acceptor.address, value, {from: by}));
					});
					consumes_no_more_than(g6);
				});
				describe("EIP-3009 transfer with auth", function() {
					let nonce = ZERO_BYTES32;
					beforeEach(async function() {
						await token.transfer(w.address, value, {from});
						if(await token.votingDelegates(from) !== ZERO_ADDRESS) {
							await delegate_with_auth(w.address, ZERO_BYTES32);
							nonce = ZERO_BYTES32.slice(0, -1).concat('1');
						}
						const {v, r, s} = await eip712_transfer(token.address, w.address, to, value, validAfter, validBefore, nonce, w.privateKey);
						receipt = await token.transferWithAuthorization(w.address, to, value, validAfter, validBefore, nonce, v, r, s, {from: by});
					});
					consumes_no_more_than(g7);
				});
				describe("EIP-3009 receive with auth", function() {
					let nonce = ZERO_BYTES32;
					beforeEach(async function() {
						await token.transfer(w.address, value, {from});
						if(await token.votingDelegates(from) !== ZERO_ADDRESS) {
							await delegate_with_auth(w.address, ZERO_BYTES32);
							nonce = ZERO_BYTES32.slice(0, -1).concat('1');
						}
						const {v, r, s} = await eip712_receive(token.address, w.address, to, value, validAfter, validBefore, nonce, w.privateKey);
						receipt = await token.receiveWithAuthorization(w.address, to, value, validAfter, validBefore, nonce, v, r, s, {from: to});
					});
					consumes_no_more_than(g8);
				});
			}
			function gas_usage_mint_burn(g0, g1, g2, g3) {
				describe("mint", function() {
					beforeEach(async function() {
						await token.updateRole(by, ROLE_TOKEN_CREATOR, {from: a0});
						receipt = await token.mint(to, value, {from: by});
					});
					consumes_no_more_than(g0);
				});
				describe("burn", function() {
					beforeEach(async function() {
						receipt = await token.burn(from, value, {from});
					});
					consumes_no_more_than(g1);
				});
				describe("burn on behalf", function() {
					beforeEach(async function() {
						await token.approve(by, value.muln(2), {from});
						receipt = await token.burn(from, value, {from: by});
					});
					consumes_no_more_than(g2);
				});
				describe("burn on behalf with unlimited allowance", function() {
					beforeEach(async function() {
						await token.approve(by, MAX_UINT256, {from});
						receipt = await token.burn(from, value, {from: by});
					});
					consumes_no_more_than(g3);
				});
			}
			function gas_usage_deployment(g1, g2) {
				describe("deployment", function() {
					beforeEach(async function() {
						const txHash = token.transactionHash;
						receipt = {receipt: await web3.eth.getTransactionReceipt(txHash)};
					});
					consumes_no_more_than(g1);
				});
				describe("deployment via EIP-1167 cloning", function() {
					beforeEach(async function() {
						const factory = await deploy_generic_factory();
						({receipt} = await generic_factory_clone(factory, token, a0));
					});
					consumes_no_more_than(g2);
				});
			}
			function gas_usage_approvals(g1, g2, g3, g4, g5) {
				describe("approve", function() {
					beforeEach(async function() {
						receipt = await token.approve(by, value, {from});
					});
					consumes_no_more_than(g1);
				});
				describe("atomic approve (increase)", function() {
					beforeEach(async function() {
						receipt = await token.increaseAllowance(by, value, {from});
					});
					consumes_no_more_than(g2);
				});
				describe("atomic approve (decrease)", function() {
					beforeEach(async function() {
						await token.increaseAllowance(by, value.muln(2), {from});
						receipt = await token.decreaseAllowance(by, value, {from});
					});
					consumes_no_more_than(g3);
				});
				describe("ERC-1363 approve and call", function() {
					beforeEach(async function() {
						const acceptor = await erc1363_deploy_acceptor(a0);
						receipt = await (token.methods["approveAndCall(address,uint256)"](acceptor.address, value, {from}));
					});
					consumes_no_more_than(g4);
				});
				describe("EIP-2612 permit", function() {
					const owner = w.address;
					const spender = by;
					const nonce = 0;
					beforeEach(async function() {
						const {v, r, s} = await eip712_permit(token.address, owner, spender, value, nonce, deadline, w.privateKey);
						receipt = await token.permit(owner, spender, value, deadline, v, r, s, {from: by});
					});
					consumes_no_more_than(g5);
				});
			}
			function gas_usage_delegation(g1, g2) {
				describe("delegate", function() {
					beforeEach(async function() {
						receipt = await token.delegate(to, {from: by});
					});
					consumes_no_more_than(g1);
				});
				describe("delegate on behalf (with authorization)", function() {
					beforeEach(async function() {
						const b = await token.balanceOf(by);
						if(!b.isZero()) {
							await token.transfer(w.address, b.divn(2), {from: by});
						}
						let nonce = ZERO_BYTES32;
						if(await token.votingDelegates(by) !== ZERO_ADDRESS) {
							await delegate_with_auth(w.address, nonce);
							nonce = ZERO_BYTES32.slice(0, -1).concat('1');
						}
						receipt = await delegate_with_auth(to, nonce);
					});
					consumes_no_more_than(g2);
				});
			}

			function gas_usage_suite() {
				gas_usage_deployment(3734266, 297018);
				// approve, increase, decrease, 1363 approve, 2612 permit 
				gas_usage_approvals(48508, 48864, 31774, 57400, 79390);
				describe("when delegation is not involved", function() {
					// 20: transfer, on behalf, inf.allowance; 1363: transfer, on behalf, inf.allowance; 3009: transfer, receive
					gas_usage_transfers(61619, 71614, 64450, 68764, 78730, 71569, 87649, 87688);
					// mint, burn, burn on behalf, burn inf.allowance
					gas_usage_mint_burn(91431, 76634, 86126, 79006);
				});
				describe("when first address is a delegate", function() {
					beforeEach(async function() {
						await token.delegate(from, {from});
					});
					// 20: transfer, on behalf, inf.allowance; 1363: transfer, on behalf, inf.allowance; 3009: transfer, receive
					gas_usage_transfers(94757, 104749, 97588, 101899, 111865, 104704, 120796, 120835);
					// mint, burn, burn on behalf, burn inf.allowance
					gas_usage_mint_burn(91431, 109772, 119264, 112144);
				});
				describe("when second address is a delegate", function() {
					beforeEach(async function() {
						await token.delegate(to, {from: to});
					});
					// 20: transfer, on behalf, inf.allowance; 1363: transfer, on behalf, inf.allowance; 3009: transfer, receive
					gas_usage_transfers(108865, 118857, 111696, 68764, 78730, 71569, 134892, 134931);
					// mint, burn, burn on behalf, burn inf.allowance
					gas_usage_mint_burn(138689, 76634, 86126, 79006);
				});
				describe("when delegation is fully involved", function() {
					beforeEach(async function() {
						await token.delegate(from, {from});
						await token.delegate(to, {from: to});
					});
					// 20: transfer, on behalf, inf.allowance; 1363: transfer, on behalf, inf.allowance; 3009: transfer, receive
					gas_usage_transfers(141927, 151919, 144758, 101899, 111865, 104704, 167967, 168006);
					// mint, burn, burn on behalf, burn inf.allowance
					gas_usage_mint_burn(138689, 109772, 119264, 112144);
				});
				describe("when there is nothing on the balances", function() {
					gas_usage_delegation(50629, 80871);
				});
				describe("when one of the balances is non-zero", function() {
					beforeEach(async function() {
						await token.transfer(by, value.muln(2), {from});
					});
					gas_usage_delegation(97873, 128100);
				});
				describe("when both balances are non-zero", function() {
					beforeEach(async function() {
						await token.transfer(by, value.muln(2), {from});
						await token.delegate(by, {from: by});
					});
					gas_usage_delegation(113835, 144074);
				});
			}

			gas_usage_suite();
		});
	});
});

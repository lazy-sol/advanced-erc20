// Advanced ERC20: Token Summary Tests

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

// BN constants and utilities
const {
	random_bn,
	TWO256,
} = require("../../scripts/include/bn_utils");

// RBAC token features and roles
const {
	not,
	FEATURE_OWN_BURNS,
	FEATURE_BURNS_ON_BEHALF,
	FEATURE_DELEGATIONS,
	ROLE_TOKEN_CREATOR,
	ROLE_TOKEN_DESTROYER,
} = require("../../scripts/include/features_roles");

// EIP712 helpers
const {
	eip712_cancel,
} = require("./include/eip712");

// deployment routines in use
const {
	advanced_erc20_deploy,
} = require("./include/deployment_routines");

// interfaceId check support
const {
	shouldSupportInterfaces,
} = require("../include/SupportsInterface.behavior");
const {expectEventInTransaction} = require("../include/event_helper");

// run very basic token tests
contract("AdvancedERC20: Token Summary", function(accounts) {
	// extract accounts to be used:
	// A0 – special default zero account accounts[0] used by Truffle, reserved
	// a0 – deployment account having all the permissions, reserved
	// H0 – initial token holder account
	// a1, a2,... – working accounts to perform tests on
	const [A0, a0, H0, a1, a2] = accounts;

	// define test suite
	function test_suite(contract_name, deployment_fn) {
		describe(contract_name, function() {
			// decimals: 18
			const DECIMALS = 18;
			const DM = new BN(10).muln(DECIMALS);
			// total supply: 120 billion
			const S0 = new BN(120).mul(new BN(10).pow(new BN(9 + DECIMALS)));

			// deploy token
			let token;
			beforeEach(async function() {
				token = await deployment_fn.call(this, a0, H0, S0);
			});

			const by = a1;
			const to = H0;
			const from = H0;
			const value = random_bn(new BN(1_500_000_000).mul(DM), new BN(1_500_000_000).mul(DM));

			describe("Mintable during deployment: new tokens may get created during deployment", function() {
				function behaves_like_mint(by, to, value) {
					let receipt;
					beforeEach(async function() {
						receipt = await token.mint(to, value, {from: by});
					});
					it("total supply increases", async function() {
						expect(await token.totalSupply()).to.be.a.bignumber.that.equals(S0.add(value));
					});
					it("holder balance increases", async function() {
						expect(await token.balanceOf(to)).to.be.a.bignumber.that.equals(S0.add(value));
					});
					it("emits Minted event", async function() {
						expectEvent(receipt, "Minted", {by, to, value})
					});
					it("emits improved Transfer event (arXiv:1907.00903)", async function() {
						expectEvent(receipt, "Transfer", {by, from: ZERO_ADDRESS, to, value})
					});
					it("emits ERC20 Transfer event", async function() {
						expectEvent(receipt, "Transfer", {from: ZERO_ADDRESS, to, value})
					});
				}

				describe("by TOKEN_CREATOR", function() {
					beforeEach(async function() {
						await token.updateRole(by, ROLE_TOKEN_CREATOR, {from: a0});
					});
					describe("tokens get created", function() {
						behaves_like_mint(by, to, value);
					});
				});
				it("not when TOKEN_CREATOR permission is missing", async function() {
					await expectRevert(token.mint(to, value, {from: by}), "access denied");
				});
			});
			describe("Not mintable after deployment: new tokens cannot be created after deployment", function() {
				beforeEach(async function() {
					await token.updateRole(by, not(ROLE_TOKEN_CREATOR), {from: a0});
				});
				it("minting by the deployer reverts", async function() {
					await expectRevert(token.mint(to, value, {from: by}), "access denied");
				});
			});
			describe("Burnable: existing tokens may get destroyed", function() {
				function behaves_like_burn(by, from, value) {
					let receipt;
					beforeEach(async function() {
						receipt = await token.burn(from, value, {from: by});
					});
					it("total supply decreases", async function() {
						expect(await token.totalSupply()).to.be.a.bignumber.that.equals(S0.sub(value));
					});
					it("holder balance decreases", async function() {
						expect(await token.balanceOf(from)).to.be.a.bignumber.that.equals(S0.sub(value));
					});
					it("emits Burnt event", async function() {
						expectEvent(receipt, "Burnt", {by, from, value})
					});
					it("emits improved Transfer event (arXiv:1907.00903)", async function() {
						expectEvent(receipt, "Transfer", {by, from, to: ZERO_ADDRESS, value})
					});
					it("emits ERC20 Transfer event", async function() {
						expectEvent(receipt, "Transfer", {from, to: ZERO_ADDRESS, value})
					});
				}

				describe("by TOKEN_DESTROYER", function() {
					beforeEach(async function() {
						await token.updateRole(by, ROLE_TOKEN_DESTROYER, {from: a0});
					});
					behaves_like_burn(by, from, value);
				});
				describe("by tokens owner", function() {
					beforeEach(async function() {
						await token.updateRole(from, 0, {from: a0});
					});
					describe("when OWN_BURNS is enabled", function() {
						beforeEach(async function() {
							await token.updateFeatures(FEATURE_OWN_BURNS, {from: a0});
						});
						behaves_like_burn(from, from, value);
					});
					it("not when OWN_BURNS is disabled", async function() {
						await token.updateFeatures(not(FEATURE_OWN_BURNS), {from: a0});
						await expectRevert(token.burn(from, value, {from: from}), "burns are disabled");
					});
				});
				describe("on behalf of tokens owner", function() {
					beforeEach(async function() {
						await token.updateRole(from, 0, {from: a0});
					});
					describe("when BURNS_ON_BEHALF is enabled", function() {
						beforeEach(async function() {
							await token.updateFeatures(FEATURE_BURNS_ON_BEHALF, {from: a0});
						});
						describe("when token owner approved operation", function() {
							beforeEach(async function() {
								await token.approve(by, value, {from: from});
							});
							behaves_like_burn(by, from, value);
						});
						it("not when token owner didn't approve operation", async function() {
							await expectRevert(token.burn(from, value, {from: by}), "burn amount exceeds allowance");
						});
					});
					it("not when BURNS_ON_BEHALF is disabled", async function() {
						await token.updateFeatures(not(FEATURE_BURNS_ON_BEHALF), {from: a0});
						await expectRevert(token.burn(from, value, {from: by}), "burns on behalf are disabled");
					});
				});
			});
			describe("Token holders should be able participate in governance protocol(s) and vote with their tokens", function() {
				describe("when delegations are enabled", function() {
					beforeEach(async function() {
						await token.updateFeatures(FEATURE_DELEGATIONS, {from: a0});
					});
					describe("when token holder address delegates to itself", function() {
						let receipt;
						beforeEach(async function() {
							receipt = await token.delegate(H0, {from: H0});
						});
						it("it becomes a delegate of itself", async function() {
							expect(await token.votingDelegates(H0)).to.equal(H0);
						});
						it("it receives voting power equal to the token balance", async function() {
							expect(await token.votingPowerOf(H0)).to.be.bignumber.that.equals(S0);
						});
						it("VotingPowerChanged event is emitted", async function() {
							expectEvent(receipt, "VotingPowerChanged", {by: H0, target: H0, fromVal: new BN(0), toVal: S0})
						});
						it("DelegateChanged event is emitted", async function() {
							expectEvent(receipt, "DelegateChanged", {source: H0, from: ZERO_ADDRESS, to: H0})
						});
					});
				});
				describe("otherwise", function() {
					beforeEach(async function() {
						await token.updateFeatures(not(FEATURE_DELEGATIONS), {from: a0});
					});
					it("delegation reverts", async function() {
						await expectRevert(token.delegate(H0, {from: H0}), "delegations are disabled");
					})
				});
			});

			// missing interfaceId support checks
			shouldSupportInterfaces(["ERC165", "ERC20", "ERC1363", "EIP2612", "EIP3009"], () => token);

			// missing Zeppelin increaseAllowance integer overflow check
			describe("increaseAllowance integer overflow check", function() {
				const delegator = a1;
				const delegate = a2;
				const value = TWO256.divn(2);
				beforeEach(async function() {
					await token.approve(delegate, value, {from: delegator});
				})
				it("increaseAllowance fails when overflows with a readable error message", async function() {
					await expectRevert(
						token.increaseAllowance(delegate, value, {from: delegator}),
						"zero value approval increase or arithmetic overflow"
					);
				});
			});

			// several tests to improve coverage
			it("coverage: decreaseAllowance(0) fails", async function() {
				await expectRevert(token.decreaseAllowance(a1, 0, {from: H0}), "zero value approval decrease");
			});
			it("coverage: signature from the different account is not accepted", async function() {
				const w = web3.eth.accounts.create();
				const {v, r, s} = await eip712_cancel(token.address, H0, ZERO_BYTES32, w.privateKey);
				await expectRevert(token.cancelAuthorization(H0, ZERO_BYTES32, v, r, s, {from: H0}), "invalid signature");
			});
			it("coverage: signature with invalid 'v' is not accepted", async function() {
				const w = web3.eth.accounts.create();
				const {v, r, s} = await eip712_cancel(token.address, w.address, ZERO_BYTES32, w.privateKey);
				await expectRevert(token.cancelAuthorization(w.address, ZERO_BYTES32, 26, r, s, {from: H0}), "invalid signature");
			});
			it("coverage: invalid signature is not accepted", async function() {
				const w = web3.eth.accounts.create();
				const {v, r, s} = await eip712_cancel(token.address, w.address, ZERO_BYTES32, w.privateKey);
				await expectRevert(token.cancelAuthorization(w.address, ZERO_BYTES32, v, r, ZERO_BYTES32, {from: H0}), "invalid signature");
			});

			{
				const value = new BN(1);
				const by = a1;

				// according to the Ethereum ERC20 token standard, it is possible to transfer
				// tokens to oneself using the transfer or transferFrom functions.
				// In both cases, the transfer will succeed as long as the sender has a sufficient balance of tokens.
				it("self transfer fails if balance is not enough", async function() {
					await expectRevert(token.transfer(H0, S0.addn(1), {from: H0}), "transfer amount exceeds balance");
				});
				it("self transfer on behalf fails if allowance is not enough", async function() {
					await expectRevert(token.transferFrom(H0, H0, value, {from: by}), "transfer amount exceeds allowance");
				});
				describe("self transfer succeeds if balance is enough", function() {
					let receipt;
					beforeEach(async function() {
						receipt = await token.transfer(H0, value, {from: H0});
					});
					it("emits improved Transfer event (arXiv:1907.00903)", async function() {
						await expectEventInTransaction(receipt.tx, "Transfer", [{
							type: "address",
							name: "by",
							indexed: true,
							value: H0,
						}, {
							type: "address",
							name: "from",
							indexed: true,
							value: H0,
						}, {
							type: "address",
							name: "to",
							indexed: true,
							value: H0,
						}, {
							type: "uint256",
							name: "value",
							value: value,
						}]);
					});
					it("emits ERC20 Transfer event", async function() {
						await expectEventInTransaction(receipt.tx, "Transfer", [{
							type: "address",
							name: "from",
							indexed: true,
							value: H0,
						}, {
							type: "address",
							name: "to",
							indexed: true,
							value: H0,
						}, {
							type: "uint256",
							name: "value",
							value: value,
						}]);
					});
					it("sender/receiver balance doesn't change", async function() {
						expect(await token.balanceOf(H0)).to.be.bignumber.that.equals(S0);
					});
				});
				describe("self transfer on behalf succeeds if balance and allowance are enough", function() {
					let receipt;
					beforeEach(async function() {
						await token.approve(by, S0, {from: H0});
						receipt = await token.transferFrom(H0, H0, value, {from: by});
					});
					it("emits improved Transfer event (arXiv:1907.00903)", async function() {
						await expectEventInTransaction(receipt.tx, "Transfer", [{
							type: "address",
							name: "by",
							indexed: true,
							value: by,
						}, {
							type: "address",
							name: "from",
							indexed: true,
							value: H0,
						}, {
							type: "address",
							name: "to",
							indexed: true,
							value: H0,
						}, {
							type: "uint256",
							name: "value",
							value: value,
						}]);
					});
					it("emits ERC20 Transfer event", async function() {
						await expectEventInTransaction(receipt.tx, "Transfer", [{
							type: "address",
							name: "from",
							indexed: true,
							value: H0,
						}, {
							type: "address",
							name: "to",
							indexed: true,
							value: H0,
						}, {
							type: "uint256",
							name: "value",
							value: value,
						}]);
					});
					it("sender/receiver balance doesn't change", async function() {
						expect(await token.balanceOf(H0)).to.be.bignumber.that.equals(S0);
					});
				});
			}

			{
				const to = a1;
				const by = a2;

				// according to ERC-20 Token Standard, https://eips.ethereum.org/EIPS/eip-20
				// "Transfers of 0 values MUST be treated as normal transfers and fire the Transfer event."
				describe("zero value transfer succeeds", function() {
					let receipt;
					beforeEach(async function() {
						receipt = await token.transfer(to, 0, {from: H0});
					});
					it("emits improved Transfer event (arXiv:1907.00903)", async function() {
						await expectEventInTransaction(receipt.tx, "Transfer", [{
							type: "address",
							name: "by",
							indexed: true,
							value: H0,
						}, {
							type: "address",
							name: "from",
							indexed: true,
							value: H0,
						}, {
							type: "address",
							name: "to",
							indexed: true,
							value: to,
						}, {
							type: "uint256",
							name: "value",
							value: "0",
						}]);
					});
					it("emits ERC20 Transfer event", async function() {
						await expectEventInTransaction(receipt.tx, "Transfer", [{
							type: "address",
							name: "from",
							indexed: true,
							value: H0,
						}, {
							type: "address",
							name: "to",
							indexed: true,
							value: to,
						}, {
							type: "uint256",
							name: "value",
							value: "0",
						}]);
					});
					it("sender balance doesn't change", async function() {
						expect(await token.balanceOf(H0)).to.be.bignumber.that.equals(S0);
					});
					it("receiver balance doesn't change", async function() {
						expect(await token.balanceOf(to)).to.be.bignumber.that.equals("0");
					});
				});
				describe("zero value transfer on behalf succeeds", function() {
					let receipt;
					beforeEach(async function() {
						receipt = await token.transferFrom(H0, to, 0, {from: by});
					});
					it("emits improved Transfer event (arXiv:1907.00903)", async function() {
						await expectEventInTransaction(receipt.tx, "Transfer", [{
							type: "address",
							name: "by",
							indexed: true,
							value: by,
						}, {
							type: "address",
							name: "from",
							indexed: true,
							value: H0,
						}, {
							type: "address",
							name: "to",
							indexed: true,
							value: to,
						}, {
							type: "uint256",
							name: "value",
							value: "0",
						}]);
					});
					it("emits ERC20 Transfer event", async function() {
						await expectEventInTransaction(receipt.tx, "Transfer", [{
							type: "address",
							name: "from",
							indexed: true,
							value: H0,
						}, {
							type: "address",
							name: "to",
							indexed: true,
							value: to,
						}, {
							type: "uint256",
							name: "value",
							value: "0",
						}]);
					});
					it("sender balance doesn't change", async function() {
						expect(await token.balanceOf(H0)).to.be.bignumber.that.equals(S0);
					});
					it("receiver balance doesn't change", async function() {
						expect(await token.balanceOf(to)).to.be.bignumber.that.equals("0");
					});
				});
			}
		});
	}

	// run test suite
	test_suite("AdvancedERC20", advanced_erc20_deploy);
});

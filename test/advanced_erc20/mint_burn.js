// ERC20: Mint/Burn Tests
// note: mint capabilities are disabled after token deployment into mainnet

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

// token constants
const {TOTAL_SUPPLY: S0} = require("./include/erc20_constants");

// RBAC token features and roles
const {
	FEATURE_OWN_BURNS,
	FEATURE_BURNS_ON_BEHALF,
	ROLE_TOKEN_CREATOR,
	ROLE_TOKEN_DESTROYER,
} = require("../../scripts/include/features_roles");

// deployment routines in use
const {
	advanced_erc20_deploy_restricted,
	erc1363_deploy_mock,
} = require("./include/deployment_routines");

// run in-depth mint/burn tests
contract("AdvancedRC20: Mint/Burn", function(accounts) {
	// extract accounts to be used:
	// A0 – special default zero account accounts[0] used by Truffle, reserved
	// a0 – deployment account having all the permissions, reserved
	// H0 – initial token holder account
	// a1, a2,... – working accounts to perform tests on
	const [A0, a0, H0, a1, a2] = accounts;

	// define test suite
	function test_suite(suite_name, deployment_fn) {
		describe(suite_name, function() {
			// deploy token
			let token;
			beforeEach(async function() {
				token = await deployment_fn.call(this, a0, H0, S0);
			});

			const by = a1;
			const from = H0;
			const value = S0;
			describe("Minting", function() {
				let to, mint;
				function behaves_like_mint() {
					it("fails if the recipient is zero address", async function() {
						await expectRevert(mint(ZERO_ADDRESS, value, {from: by}), "zero address");
					});
					it("fails if amount is too big and causes total supply overflow – mint reverts", async function() {
						await expectRevert(mint(to, MAX_UINT256, {from: by}), "zero value or arithmetic overflow");
					});
					it("fails if amount is zero – mint reverts", async function() {
						await expectRevert(mint(to, 0, {from: by}), "zero value or arithmetic overflow");
					});
					it("fails if amount is too big to fit into uint192 – mint reverts", async function() {
						await expectRevert(mint(to, new BN(2).pow(new BN(192)), {from: by}), "total supply overflow (uint192)");
					});
					describe("succeeds otherwise (when recipient and amount are valid)", function() {
						let receipt;
						beforeEach(async function() {
							receipt = await mint(to, value, {from: by});
						});
						it("total supply increases", async function() {
							expect(await token.totalSupply()).to.be.a.bignumber.that.equals(S0.add(value));
						});
						it("recipient balance increases", async function() {
							expect(await token.balanceOf(to)).to.be.a.bignumber.that.equals(value);
						});
						it('emits "Minted" event', async function() {
							expectEvent(receipt, "Minted", {by, to, value});
						});
						it('emits improved "Transfer" event (arXiv:1907.00903)', async function() {
							expectEvent(receipt, "Transfer", {by, from: ZERO_ADDRESS, to, value});
						});
						it('emits ERC20 "Transfer" event', async function() {
							expectEvent(receipt, "Transfer", {from: ZERO_ADDRESS, to, value});
						});
					});
				}

				describe("unsafe minting: mint()", function() {
					beforeEach(async function() {
						to = a2;
						mint = token.mint;
					});

					describe("when performed by TOKEN_CREATOR", function() {
						beforeEach(async function() {
							await token.updateRole(by, ROLE_TOKEN_CREATOR, {from: a0});
						});
						behaves_like_mint();
					});
					it("when performed not by TOKEN_CREATOR – mint reverts", async function() {
						await expectRevert(mint(to, value, {from: by}), "access denied");
					});
				});
				describe("safe minting: safeMint()", function() {
					let acceptor;
					beforeEach(async function() {
						acceptor = await erc1363_deploy_mock(a0);
					});

					function behaves_like_safe_mint(data = null) {
						it("fails if the recipient doesn't implement ERC1363Receiver", async function() {
							await expectRevert(mint(token.address, value, {from: by}), "selector was not recognized");
						});
						it("fails if the recipient fails the transaction (throws)", async function() {
							await acceptor.setErrMsg("super_err_code_618", {from: a0});
							await expectRevert(mint(to, value, {from: by}), "super_err_code_618");
						});
						it("fails if the recipient rejects the transaction", async function() {
							await acceptor.setRetVal("0x123", {from: a0});
							await expectRevert(mint(to, value, {from: by}), "invalid onTransferReceived response");
						});
						describe("succeeds otherwise (when recipient and amount are valid)", function() {
							let receipt;
							beforeEach(async function() {
								receipt = await mint(to, value, {from: by});
							});
							it('emits "OnTransferReceived" event on the ERC1363Receiver', async function() {
								await expectEvent.inTransaction(receipt.tx, acceptor, "OnTransferReceived", {
									operator: by,
									from: ZERO_ADDRESS,
									value,
									data,
								});
							});
						});
					}

					describe("without payload", function() {
						const data = web3.utils.utf8ToHex("");
						beforeEach(async function() {
							const fn = token.methods["safeMint(address,uint256,bytes)"];
							mint = async(to, value, opts) => await fn(to, value, data, opts);
						});
						describe("when performed by TOKEN_CREATOR", function() {
							beforeEach(async function() {
								await token.updateRole(by, ROLE_TOKEN_CREATOR, {from: a0});
							});
							describe("when the recipient is EOA", function() {
								behaves_like_mint();
							});
							describe("when the recipient is a smart contract", function() {
								beforeEach(async function() {
									({address: to} = acceptor);
								});
								behaves_like_mint();
								behaves_like_safe_mint();
							});
						});
						it("when performed not by TOKEN_CREATOR – mint reverts", async function() {
							await expectRevert(mint(to, value, {from: by}), "access denied");
						});
					});
					describe("with the payload", function() {
						const data = web3.utils.utf8ToHex("Hello, World!");
						beforeEach(async function() {
							const fn = token.methods["safeMint(address,uint256,bytes)"];
							mint = async(to, value, opts) => await fn(to, value, data, opts);
						});
						describe("when performed by TOKEN_CREATOR", function() {
							beforeEach(async function() {
								await token.updateRole(by, ROLE_TOKEN_CREATOR, {from: a0});
							});
							describe("when the recipient is EOA", function() {
								behaves_like_mint();
							});
							describe("when the recipient is a smart contract", function() {
								beforeEach(async function() {
									({address: to} = acceptor);
								});
								behaves_like_mint();
								behaves_like_safe_mint(data);
							});
						});
						it("when performed not by TOKEN_CREATOR – mint reverts", async function() {
							await expectRevert(mint(to, value, {from: by}), "access denied");
						});
					});
				});
				describe("ERC1363 minting: mintAndCall()", function() {
					let acceptor;
					beforeEach(async function() {
						acceptor = await erc1363_deploy_mock(a0);
						({address: to} = acceptor);
					});

					function behaves_like_1363mint(data = null) {
						const to_eoa = a2;
						it("fails if the recipient is EOA – mint reverts", async function() {
							await expectRevert(mint(to_eoa, value, {from: by}), "EOA recipient");
						});
						it("fails if the recipient doesn't implement ERC1363Receiver", async function() {
							await expectRevert(mint(token.address, value, {from: by}), "selector was not recognized");
						});
						it("fails if the recipient fails the transaction (throws)", async function() {
							await acceptor.setErrMsg("super_err_code_618", {from: a0});
							await expectRevert(mint(to, value, {from: by}), "super_err_code_618");
						});
						it("fails if the recipient rejects the transaction", async function() {
							await acceptor.setRetVal("0x123", {from: a0});
							await expectRevert(mint(to, value, {from: by}), "invalid onTransferReceived response");
						});
						describe("succeeds otherwise (when recipient and amount are valid)", function() {
							let receipt;
							beforeEach(async function() {
								receipt = await mint(to, value, {from: by});
							});
							it('emits "OnTransferReceived" event on the ERC1363Receiver', async function() {
								await expectEvent.inTransaction(receipt.tx, acceptor, "OnTransferReceived", {
									operator: by,
									from: ZERO_ADDRESS,
									value,
									data,
								});
							});
						});
					}

					describe("without payload", function() {
						beforeEach(async function() {
							mint = token.methods["mintAndCall(address,uint256)"];
						});
						describe("when performed by TOKEN_CREATOR", function() {
							beforeEach(async function() {
								await token.updateRole(by, ROLE_TOKEN_CREATOR, {from: a0});
							});
							behaves_like_mint();
							behaves_like_1363mint();
						});
						it("when performed not by TOKEN_CREATOR – mint reverts", async function() {
							await expectRevert(mint(to, value, {from: by}), "access denied");
						});
					});
					describe("with the payload", function() {
						const data = web3.utils.utf8ToHex("Hello, World!");
						beforeEach(async function() {
							const fn = token.methods["mintAndCall(address,uint256,bytes)"];
							mint = async(to, value, opts) => await fn(to, value, data, opts);
						});
						describe("when performed by TOKEN_CREATOR", function() {
							beforeEach(async function() {
								await token.updateRole(by, ROLE_TOKEN_CREATOR, {from: a0});
							});
							behaves_like_mint();
							behaves_like_1363mint(data);
						});
						it("when performed not by TOKEN_CREATOR – mint reverts", async function() {
							await expectRevert(mint(to, value, {from: by}), "access denied");
						});
					});
				});
			});
			describe("Burning", function() {
				function burn_reverts(by, from, value, msg) {
					beforeEach(async function() {
						await token.mint(from, value, {from: a0});
					});
					it("burn reverts", async function() {
						await expectRevert(token.burn(from, value, {from: by}), msg);
					});
				}
				function execute_burn_scenarios(by, from, value) {
					function behaves_like_burn(by, from, value) {
						let s1, b1, receipt;
						beforeEach(async function() {
							s1 = await token.totalSupply();
							b1 = await token.balanceOf(from);
							receipt = await token.burn(from, value, {from: by});
						});
						it("total supply decreases", async function() {
							expect(await token.totalSupply()).to.be.a.bignumber.that.equals(s1.sub(value));
						});
						it("supplier balance decreases", async function() {
							expect(await token.balanceOf(from)).to.be.a.bignumber.that.equals(b1.sub(value));
						});
						it('emits "Burnt" event', async function() {
							expectEvent(receipt,"Burnt", {by, from, value});
						});
						it('emits improved "Transfer" event (arXiv:1907.00903)', async function() {
							expectEvent(receipt,"Transfer", {by, from, to: ZERO_ADDRESS, value});
						});
						it('emits ERC20 "Transfer" event', async function() {
							expectEvent(receipt,"Transfer", {from, to: ZERO_ADDRESS, value});
						});
					}

					it("when the amount is zero – burn reverts", async function () {
						await expectRevert(token.burn(H0, 0, {from: a0}), "zero value burn");
					});
					it("when supplier address is zero address – burn reverts", async function() {
						await expectRevert(token.burn(ZERO_ADDRESS, value, {from: a0}), "burn from the zero address");
					});
					it("when supplier doesn't have enough tokens – burn reverts", async function() {
						await expectRevert(token.burn(H0, S0.addn(1), {from: a0}), "burn amount exceeds balance");
					});
					describe("when amount and supplier address are correct", function() {
						behaves_like_burn(by, from, value);
					});
				}

				describe("when performed by TOKEN_DESTROYER", function() {
					beforeEach(async function() {
						await token.updateRole(by, ROLE_TOKEN_DESTROYER, {from: a0});
					});
					execute_burn_scenarios(by, from, value);
				});
				describe("when performed not by TOKEN_DESTROYER", function() {
					describe("when burning own tokens", function() {
						const by = from;
						describe("when OWN_BURNS is enabled", function() {
							beforeEach(async function() {
								await token.updateFeatures(FEATURE_OWN_BURNS, {from: a0});
							});
							execute_burn_scenarios(by, from, value);
						});
						describe("when OWN_BURNS is not enabled", function() {
							burn_reverts(by, from, value, "burns are disabled");
						});
					});
					describe("when burning tokens on behalf", function() {
						beforeEach(async function() {
							await token.approve(by, value.muln(2), {from: from});
						});
						describe("when BURNS_ON_BEHALF is enabled", function() {
							beforeEach(async function() {
								await token.updateFeatures(FEATURE_BURNS_ON_BEHALF, {from: a0});
							});
							execute_burn_scenarios(by, from, value);
						});
						describe("when BURNS_ON_BEHALF is not enabled", function() {
							burn_reverts(by, from, value, "burns on behalf are disabled");
						});
					});
					describe("otherwise (unauthorized burn)",  function() {
						beforeEach(async function() {
							await token.updateFeatures(FEATURE_BURNS_ON_BEHALF, {from: a0});
						});
						burn_reverts(by, from, value, "burn amount exceeds allowance");
					});
				});
			});

		});
	}

	// run test suite
	test_suite("AdvancedERC20", advanced_erc20_deploy_restricted);
});

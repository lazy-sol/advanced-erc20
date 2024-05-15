// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../interfaces/ERC1363Spec.sol";
import "../interfaces/EIP2612.sol";
import "../interfaces/EIP3009.sol";
import "../lib/ECDSA.sol";

import "@lazy-sol/access-control-upgradeable/contracts/InitializableAccessControl.sol";

/**
 * @title Advanced ERC20
 *
 * @notice Feature rich lightweight ERC20 implementation which is not built on top of OpenZeppelin ERC20 implementation.
 *      It uses some other OpenZeppelin code:
 *         - low level functions to work with ECDSA signatures (recover)
 *         - low level functions to work contract addresses (isContract)
 *         - OZ UUPS proxy and smart contracts upgradeability code
 *
 * @notice Token Summary:
 *      - Symbol: configurable (set on deployment)
 *      - Name: configurable (set on deployment)
 *      - Decimals: 18
 *      - Initial/maximum total supply: configurable (set on deployment)
 *      - Initial supply holder (initial holder) address: configurable (set on deployment)
 *      - Mintability: configurable (initially enabled, but possible to revoke forever)
 *      - Burnability: configurable (initially enabled, but possible to revoke forever)
 *      - DAO Support: supports voting delegation
 *
 * @notice Features Summary:
 *      - Supports atomic allowance modification, resolves well-known ERC20 issue with approve (arXiv:1907.00903)
 *      - Voting delegation and delegation on behalf via EIP-712 (like in Compound CMP token) - gives the token
 *        powerful governance capabilities by allowing holders to form voting groups by electing delegates
 *      - Unlimited approval feature (like in 0x ZRX token) - saves gas for transfers on behalf
 *        by eliminating the need to update “unlimited” allowance value
 *      - ERC-1363 Payable Token - ERC721-like callback execution mechanism for transfers,
 *        transfers on behalf and approvals; allows creation of smart contracts capable of executing callbacks
 *        in response to transfer or approval in a single transaction
 *      - EIP-2612: permit - 712-signed approvals - improves user experience by allowing to use a token
 *        without having an ETH to pay gas fees
 *      - EIP-3009: Transfer With Authorization - improves user experience by allowing to use a token
 *        without having an ETH to pay gas fees
 *
 * @notice This smart contract can be used as is, but also can be inherited and used as a template.
 *
 * @dev Even though smart contract has mint() function which is used to mint initial token supply,
 *      the function is disabled forever after smart contract deployment by revoking `TOKEN_CREATOR`
 *      permission from the deployer account
 *
 * @dev Token balances and total supply are effectively 192 bits long, meaning that maximum
 *      possible total supply smart contract is able to track is 2^192 (close to 10^40 tokens)
 *
 * @dev Smart contract doesn't use safe math. All arithmetic operations are overflow/underflow safe.
 *      Additionally, Solidity 0.8.7 enforces overflow/underflow safety.
 *
 * @dev Multiple Withdrawal Attack on ERC20 Tokens (arXiv:1907.00903) - resolved
 *      Related events and functions are marked with "arXiv:1907.00903" tag:
 *        - event Transfer(address indexed by, address indexed from, address indexed to, uint256 value)
 *        - event Approve(address indexed owner, address indexed spender, uint256 oldValue, uint256 value)
 *        - function increaseAllowance(address spender, uint256 value) public returns (bool)
 *        - function decreaseAllowance(address spender, uint256 value) public returns (bool)
 *      See: https://arxiv.org/abs/1907.00903v1
 *           https://ieeexplore.ieee.org/document/8802438
 *      See: https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
 *
 * @dev Reviewed
 *      ERC-20   - according to https://eips.ethereum.org/EIPS/eip-20
 *      ERC-1363 - according to https://eips.ethereum.org/EIPS/eip-1363
 *      EIP-2612 - according to https://eips.ethereum.org/EIPS/eip-2612
 *      EIP-3009 - according to https://eips.ethereum.org/EIPS/eip-3009
 *
 * @dev ERC20: contract has passed
 *      - OpenZeppelin ERC20 tests
 *        https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/test/token/ERC20/ERC20.behavior.js
 *        https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/test/token/ERC20/ERC20.test.js
 *      - Ref ERC1363 tests
 *        https://github.com/vittominacori/erc1363-payable-token/blob/master/test/token/ERC1363/ERC1363.behaviour.js
 *      - OpenZeppelin EIP2612 tests
 *        https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/test/token/ERC20/extensions/draft-ERC20Permit.test.js
 *      - Coinbase EIP3009 tests
 *        https://github.com/CoinbaseStablecoin/eip-3009/blob/master/test/EIP3009.test.ts
 *      - Compound voting delegation tests
 *        https://github.com/compound-finance/compound-protocol/blob/master/tests/Governance/CompTest.js
 *        https://github.com/compound-finance/compound-protocol/blob/master/tests/Utils/EIP712.js
 *      - OpenZeppelin voting delegation tests
 *        https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/test/token/ERC20/extensions/ERC20Votes.test.js
 *      See adopted copies of all the tests in the project test folder
 *
 * @dev Compound-like voting delegation functions', public getters', and events' names
 *      were changed for better code readability (Advanced ERC20 Name <- Comp/Zeppelin name):
 *      - votingDelegates           <- delegates
 *      - votingPowerHistory        <- checkpoints
 *      - votingPowerHistoryLength  <- numCheckpoints
 *      - totalSupplyHistory        <- _totalSupplyCheckpoints (private)
 *      - usedNonces                <- nonces (note: nonces are random instead of sequential)
 *      - DelegateChanged (unchanged)
 *      - VotingPowerChanged        <- DelegateVotesChanged
 *      - votingPowerOf             <- getCurrentVotes
 *      - votingPowerAt             <- getPriorVotes
 *      - totalSupplyAt             <- getPriorTotalSupply
 *      - delegate (unchanged)
 *      - delegateWithAuthorization <- delegateBySig
 * @dev Compound-like voting delegation improved to allow the use of random nonces like in EIP-3009,
 *      instead of sequential; same `usedNonces` EIP-3009 mapping is used to track nonces
 *
 * @dev Reference implementations "used":
 *      - Atomic allowance:    https://github.com/OpenZeppelin/openzeppelin-contracts
 *      - Unlimited allowance: https://github.com/0xProject/protocol
 *      - Voting delegation:   https://github.com/compound-finance/compound-protocol
 *                             https://github.com/OpenZeppelin/openzeppelin-contracts
 *      - ERC-1363:            https://github.com/vittominacori/erc1363-payable-token
 *      - EIP-2612:            https://github.com/Uniswap/uniswap-v2-core
 *      - EIP-3009:            https://github.com/centrehq/centre-tokens
 *                             https://github.com/CoinbaseStablecoin/eip-3009
 *      - Meta transactions:   https://github.com/0xProject/protocol
 *
 * @dev The code is based on Artificial Liquid Intelligence Token (ALI) developed by Alethea team
 * @dev Includes resolutions for ALI ERC20 Audit by Miguel Palhas, https://hackmd.io/@naps62/alierc20-audit
 *
 * @author Basil Gorin
 */
contract AdvancedERC20 is ERC1363, MintableBurnableERC20, EIP2612, EIP3009, InitializableAccessControl {
	/**
	 * @notice Name of the token
	 *
	 * @notice ERC20 name of the token (long name)
	 *
	 * @dev ERC20 `function name() public view returns (string)`
	 *
	 * @dev Field is declared public: getter name() is created when compiled,
	 *      it returns the name of the token.
	 */
	string public name;

	/**
	 * @notice Symbol of the token
	 *
	 * @notice ERC20 symbol of that token (short name)
	 *
	 * @dev ERC20 `function symbol() public view returns (string)`
	 *
	 * @dev Field is declared public: getter symbol() is created when compiled,
	 *      it returns the symbol of the token
	 */
	string public symbol;

	/**
	 * @notice Decimals of the token: 18
	 *
	 * @dev ERC20 `function decimals() public view returns (uint8)`
	 *
	 * @dev Field is declared public: getter decimals() is created when compiled,
	 *      it returns the number of decimals used to get its user representation.
	 *      For example, if `decimals` equals `6`, a balance of `1,500,000` tokens should
	 *      be displayed to a user as `1,5` (`1,500,000 / 10 ** 6`).
	 *
	 * @dev NOTE: This information is only used for _display_ purposes: it in
	 *      no way affects any of the arithmetic of the contract, including balanceOf() and transfer().
	 */
	uint8 public constant decimals = 18;

	/**
	 * @notice Total supply of the token: initially 10,000,000,000,
	 *      with the potential to decline over time as some tokens may get burnt but not minted
	 *
	 * @dev ERC20 `function totalSupply() public view returns (uint256)`
	 *
	 * @dev Field is declared public: getter totalSupply() is created when compiled,
	 *      it returns the amount of tokens in existence.
	 */
	uint256 public override totalSupply; // is set to 10 billion * 10^18 in the constructor

	/**
	 * @dev A record of all the token balances
	 * @dev This mapping keeps record of all token owners:
	 *      owner => balance
	 */
	mapping(address => uint256) private tokenBalances;

	/**
	 * @notice A record of each account's voting delegate
	 *
	 * @dev Auxiliary data structure used to sum up an account's voting power
	 *
	 * @dev This mapping keeps record of all voting power delegations:
	 *      voting delegator (token owner) => voting delegate
	 */
	mapping(address => address) public votingDelegates;

	/**
	 * @notice Auxiliary structure to store key-value pair, used to store:
	 *      - voting power record (key: block.timestamp, value: voting power)
	 *      - total supply record (key: block.timestamp, value: total supply)
	 * @notice A voting power record binds voting power of a delegate to a particular
	 *      block when the voting power delegation change happened
	 *         k: block.number when delegation has changed; starting from
	 *            that block voting power value is in effect
	 *         v: cumulative voting power a delegate has obtained starting
	 *            from the block stored in blockNumber
	 * @notice Total supply record binds total token supply to a particular
	 *      block when total supply change happened (due to mint/burn operations)
	 */
	struct KV {
		/*
		 * @dev key, a block number
		 */
		uint64 k;

		/*
		 * @dev value, token balance or voting power
		 */
		uint192 v;
	}

	/**
	 * @notice A record of each account's voting power historical data
	 *
	 * @dev Primarily data structure to store voting power for each account.
	 *      Voting power sums up from the account's token balance and delegated
	 *      balances.
	 *
	 * @dev Stores current value and entire history of its changes.
	 *      The changes are stored as an array of checkpoints (key-value pairs).
	 *      Checkpoint is an auxiliary data structure containing voting
	 *      power (number of votes) and block number when the checkpoint is saved
	 *
	 * @dev Maps voting delegate => voting power record
	 */
	mapping(address => KV[]) public votingPowerHistory;

	/**
	 * @notice A record of total token supply historical data
	 *
	 * @dev Primarily data structure to store total token supply.
	 *
	 * @dev Stores current value and entire history of its changes.
	 *      The changes are stored as an array of checkpoints (key-value pairs).
	 *      Checkpoint is an auxiliary data structure containing total
	 *      token supply and block number when the checkpoint is saved
	 */
	KV[] public totalSupplyHistory;

	/**
	 * @dev A record of nonces for signing/validating signatures in EIP-2612 `permit`
	 *
	 * @dev Note: EIP2612 doesn't imply a possibility for nonce randomization like in EIP-3009
	 *
	 * @dev Maps delegate address => delegate nonce
	 */
	mapping(address => uint256) public override nonces;

	/**
	 * @dev A record of used nonces for EIP-3009 transactions
	 *
	 * @dev A record of used nonces for signing/validating signatures
	 *      in `delegateWithAuthorization` for every delegate
	 *
	 * @dev Maps authorizer address => nonce => true/false (used unused)
	 */
	mapping(address => mapping(bytes32 => bool)) private usedNonces;

	/**
	 * @notice A record of all the allowances to spend tokens on behalf
	 * @dev Maps token owner address to an address approved to spend
	 *      some tokens on behalf, maps approved address to that amount
	 * @dev owner => spender => value
	 */
	mapping(address => mapping(address => uint256)) private transferAllowances;

	/**
	 * @notice Enables ERC20 transfers of the tokens
	 *      (transfer by the token owner himself)
	 * @dev Feature FEATURE_TRANSFERS must be enabled in order for
	 *      `transfer()` function to succeed
	 */
	uint32 public constant FEATURE_TRANSFERS = 0x0000_0001;

	/**
	 * @notice Enables ERC20 transfers on behalf
	 *      (transfer by someone else on behalf of token owner)
	 * @dev Feature FEATURE_TRANSFERS_ON_BEHALF must be enabled in order for
	 *      `transferFrom()` function to succeed
	 * @dev Token owner must call `approve()` first to authorize
	 *      the transfer on behalf
	 */
	uint32 public constant FEATURE_TRANSFERS_ON_BEHALF = 0x0000_0002;

	/**
	 * @dev Defines if the default behavior of `transfer` and `transferFrom`
	 *      checks if the receiver smart contract supports ERC20 tokens
	 * @dev When feature FEATURE_UNSAFE_TRANSFERS is enabled the transfers do not
	 *      check if the receiver smart contract supports ERC20 tokens,
	 *      i.e. `transfer` and `transferFrom` behave like `unsafeTransferFrom`
	 * @dev When feature FEATURE_UNSAFE_TRANSFERS is disabled (default) the transfers
	 *      check if the receiver smart contract supports ERC20 tokens,
	 *      i.e. `transfer` and `transferFrom` behave like `transferFromAndCall`
	 */
	uint32 public constant FEATURE_UNSAFE_TRANSFERS = 0x0000_0004;

	/**
	 * @notice Enables token owners to burn their own tokens
	 *
	 * @dev Feature FEATURE_OWN_BURNS must be enabled in order for
	 *      `burn()` function to succeed when called by token owner
	 */
	uint32 public constant FEATURE_OWN_BURNS = 0x0000_0008;

	/**
	 * @notice Enables approved operators to burn tokens on behalf of their owners
	 *
	 * @dev Feature FEATURE_BURNS_ON_BEHALF must be enabled in order for
	 *      `burn()` function to succeed when called by approved operator
	 */
	uint32 public constant FEATURE_BURNS_ON_BEHALF = 0x0000_0010;

	/**
	 * @notice Enables delegators to elect delegates
	 * @dev Feature FEATURE_DELEGATIONS must be enabled in order for
	 *      `delegate()` function to succeed
	 */
	uint32 public constant FEATURE_DELEGATIONS = 0x0000_0020;

	/**
	 * @notice Enables delegators to elect delegates on behalf
	 *      (via an EIP712 signature)
	 * @dev Feature FEATURE_DELEGATIONS_ON_BEHALF must be enabled in order for
	 *      `delegateWithAuthorization()` function to succeed
	 */
	uint32 public constant FEATURE_DELEGATIONS_ON_BEHALF = 0x0000_0040;

	/**
	 * @notice Enables ERC-1363 transfers with callback
	 * @dev Feature FEATURE_ERC1363_TRANSFERS must be enabled in order for
	 *      ERC-1363 `transferFromAndCall` functions to succeed
	 */
	uint32 public constant FEATURE_ERC1363_TRANSFERS = 0x0000_0080;

	/**
	 * @notice Enables ERC-1363 approvals with callback
	 * @dev Feature FEATURE_ERC1363_APPROVALS must be enabled in order for
	 *      ERC-1363 `approveAndCall` functions to succeed
	 */
	uint32 public constant FEATURE_ERC1363_APPROVALS = 0x0000_0100;

	/**
	 * @notice Enables approvals on behalf (EIP2612 permits
	 *      via an EIP712 signature)
	 * @dev Feature FEATURE_EIP2612_PERMITS must be enabled in order for
	 *      `permit()` function to succeed
	 */
	uint32 public constant FEATURE_EIP2612_PERMITS = 0x0000_0200;

	/**
	 * @notice Enables meta transfers on behalf (EIP3009 transfers
	 *      via an EIP712 signature)
	 * @dev Feature FEATURE_EIP3009_TRANSFERS must be enabled in order for
	 *      `transferWithAuthorization()` function to succeed
	 */
	uint32 public constant FEATURE_EIP3009_TRANSFERS = 0x0000_0400;

	/**
	 * @notice Enables meta transfers on behalf (EIP3009 transfers
	 *      via an EIP712 signature)
	 * @dev Feature FEATURE_EIP3009_RECEPTIONS must be enabled in order for
	 *      `receiveWithAuthorization()` function to succeed
	 */
	uint32 public constant FEATURE_EIP3009_RECEPTIONS = 0x0000_0800;

	/**
	 * @notice Token creator is responsible for creating (minting)
	 *      tokens to an arbitrary address
	 * @dev Role ROLE_TOKEN_CREATOR allows minting tokens
	 *      (calling `mint` function)
	 */
	uint32 public constant ROLE_TOKEN_CREATOR = 0x0001_0000;

	/**
	 * @notice Token destroyer is responsible for destroying (burning)
	 *      tokens owned by an arbitrary address
	 * @dev Role ROLE_TOKEN_DESTROYER allows burning tokens
	 *      (calling `burn` function)
	 */
	uint32 public constant ROLE_TOKEN_DESTROYER = 0x0002_0000;

	/**
	 * @notice ERC20 receivers are allowed to receive tokens without ERC20 safety checks,
	 *      which may be useful to simplify tokens transfers into "legacy" smart contracts
	 * @dev When `FEATURE_UNSAFE_TRANSFERS` is not enabled addresses having
	 *      `ROLE_ERC20_RECEIVER` permission are allowed to receive tokens
	 *      via `transfer` and `transferFrom` functions in the same way they
	 *      would via `unsafeTransferFrom` function
	 * @dev When `FEATURE_UNSAFE_TRANSFERS` is enabled `ROLE_ERC20_RECEIVER` permission
	 *      doesn't affect the transfer behaviour since
	 *      `transfer` and `transferFrom` behave like `unsafeTransferFrom` for any receiver
	 * @dev ROLE_ERC20_RECEIVER is a shortening for ROLE_UNSAFE_ERC20_RECEIVER
	 */
	uint32 public constant ROLE_ERC20_RECEIVER = 0x0004_0000;

	/**
	 * @notice ERC20 senders are allowed to send tokens without ERC20 safety checks,
	 *      which may be useful to simplify tokens transfers into "legacy" smart contracts
	 * @dev When `FEATURE_UNSAFE_TRANSFERS` is not enabled senders having
	 *      `ROLE_ERC20_SENDER` permission are allowed to send tokens
	 *      via `transfer` and `transferFrom` functions in the same way they
	 *      would via `unsafeTransferFrom` function
	 * @dev When `FEATURE_UNSAFE_TRANSFERS` is enabled `ROLE_ERC20_SENDER` permission
	 *      doesn't affect the transfer behaviour since
	 *      `transfer` and `transferFrom` behave like `unsafeTransferFrom` for any receiver
	 * @dev ROLE_ERC20_SENDER is a shortening for ROLE_UNSAFE_ERC20_SENDER
	 */
	uint32 public constant ROLE_ERC20_SENDER = 0x0008_0000;

	/**
	 * @notice EIP-712 contract's domain typeHash,
	 *      see https://eips.ethereum.org/EIPS/eip-712#rationale-for-typehash
	 *
	 * @dev Note: we do not include version into the domain typehash/separator,
	 *      it is implied version is concatenated to the name field, like "AdvancedERC20v1"
	 */
	// keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)")
	bytes32 public constant DOMAIN_TYPEHASH = 0x8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a866;

	/**
	 * @notice EIP-712 contract domain separator,
	 *      see https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator
	 *      note: we specify contract version in its name
	 */
	function DOMAIN_SEPARATOR() public view override returns(bytes32) {
		// build the EIP-712 contract domain separator, see https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator
		// note: we specify contract version in its name
		return keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes("AdvancedERC20v1")), block.chainid, address(this)));
	}

	/**
	 * @notice EIP-712 delegation struct typeHash,
	 *      see https://eips.ethereum.org/EIPS/eip-712#rationale-for-typehash
	 */
	// keccak256("Delegation(address delegate,uint256 nonce,uint256 expiry)")
	bytes32 public constant DELEGATION_TYPEHASH = 0xff41620983935eb4d4a3c7384a066ca8c1d10cef9a5eca9eb97ca735cd14a755;

	/**
	 * @notice EIP-712 permit (EIP-2612) struct typeHash,
	 *      see https://eips.ethereum.org/EIPS/eip-712#rationale-for-typehash
	 */
	// keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
	bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

	/**
	 * @notice EIP-712 TransferWithAuthorization (EIP-3009) struct typeHash,
	 *      see https://eips.ethereum.org/EIPS/eip-712#rationale-for-typehash
	 */
	// keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
	bytes32 public constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH = 0x7c7c6cdb67a18743f49ec6fa9b35f50d52ed05cbed4cc592e13b44501c1a2267;

	/**
	 * @notice EIP-712 ReceiveWithAuthorization (EIP-3009) struct typeHash,
	 *      see https://eips.ethereum.org/EIPS/eip-712#rationale-for-typehash
	 */
	// keccak256("ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
	bytes32 public constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH = 0xd099cc98ef71107a616c4f0f941f04c322d8e254fe26b3c6668db87aae413de8;

	/**
	 * @notice EIP-712 CancelAuthorization (EIP-3009) struct typeHash,
	 *      see https://eips.ethereum.org/EIPS/eip-712#rationale-for-typehash
	 */
	// keccak256("CancelAuthorization(address authorizer,bytes32 nonce)")
	bytes32 public constant CANCEL_AUTHORIZATION_TYPEHASH = 0x158b0a9edf7a828aad02f63cd515c68ef2f50ba807396f6d12842833a1597429;

	/**
	 * @dev Fired in mint() function
	 *
	 * @param by an address which minted some tokens (transaction sender)
	 * @param to an address the tokens were minted to
	 * @param value an amount of tokens minted
	 */
	event Minted(address indexed by, address indexed to, uint256 value);

	/**
	 * @dev Fired in burn() function
	 *
	 * @param by an address which burned some tokens (transaction sender)
	 * @param from an address the tokens were burnt from
	 * @param value an amount of tokens burnt
	 */
	event Burnt(address indexed by, address indexed from, uint256 value);

	/**
	 * @dev Resolution for the Multiple Withdrawal Attack on ERC20 Tokens (arXiv:1907.00903)
	 *
	 * @dev Similar to ERC20 Transfer event, but also logs an address which executed transfer
	 *
	 * @dev Fired in transfer(), transferFrom() and some other (non-ERC20) functions
	 *
	 * @param by an address which performed the transfer
	 * @param from an address tokens were consumed from
	 * @param to an address tokens were sent to
	 * @param value number of tokens transferred
	 */
	event Transfer(address indexed by, address indexed from, address indexed to, uint256 value);

	/**
	 * @dev Resolution for the Multiple Withdrawal Attack on ERC20 Tokens (arXiv:1907.00903)
	 *
	 * @dev Similar to ERC20 Approve event, but also logs old approval value
	 *
	 * @dev Fired in approve(), increaseAllowance(), decreaseAllowance() functions,
	 *      may get fired in transfer functions
	 *
	 * @param owner an address which granted a permission to transfer
	 *      tokens on its behalf
	 * @param spender an address which received a permission to transfer
	 *      tokens on behalf of the owner `owner`
	 * @param oldValue previously granted amount of tokens to transfer on behalf
	 * @param value new granted amount of tokens to transfer on behalf
	 */
	event Approval(address indexed owner, address indexed spender, uint256 oldValue, uint256 value);

	/**
	 * @dev Notifies that a key-value pair in `votingDelegates` mapping has changed,
	 *      i.e. a delegator address has changed its delegate address
	 *
	 * @param source delegator address, a token owner, effectively transaction sender (`by`)
	 * @param from old delegate, an address which delegate right is revoked
	 * @param to new delegate, an address which received the voting power
	 */
	event DelegateChanged(address indexed source, address indexed from, address indexed to);

	/**
	 * @dev Notifies that a key-value pair in `votingPowerHistory` mapping has changed,
	 *      i.e. a delegate's voting power has changed.
	 *
	 * @param by an address which executed delegate, mint, burn, or transfer operation
	 *      which had led to delegate voting power change
	 * @param target delegate whose voting power has changed
	 * @param fromVal previous number of votes delegate had
	 * @param toVal new number of votes delegate has
	 */
	event VotingPowerChanged(address indexed by, address indexed target, uint256 fromVal, uint256 toVal);

	/**
	 * @dev Deploys the token smart contract,
	 *      assigns initial token supply to the address specified
	 *
	 * @param contractOwner smart contract owner (has minting/burning and all other permissions)
	 * @param _name token name to set
	 * @param _symbol token symbol to set
	 * @param initialHolder owner of the initial token supply
	 * @param initialSupply initial token supply
	 * @param initialFeatures RBAC features enabled initially
	 */
	constructor(
		address contractOwner,
		string memory _name,
		string memory _symbol,
		address initialHolder,
		uint256 initialSupply,
		uint256 initialFeatures
	) {
		// delegate to the same `postConstruct` function which would be used
		// by all the proxies to be deployed and to be pointing to this impl
		postConstruct(contractOwner, _name, _symbol, initialHolder, initialSupply, initialFeatures);
	}

	/**
	 * @dev "Constructor replacement" for a smart contract with a delayed initialization (post-deployment initialization)
	 *
	 * @param contractOwner smart contract owner (has minting/burning and all other permissions)
	 * @param _name token name to set
	 * @param _symbol token symbol to set
	 * @param initialHolder owner of the initial token supply
	 * @param initialSupply initial token supply value
	 * @param initialFeatures RBAC features enabled initially
	 */
	function postConstruct(
		address contractOwner,
		string memory _name,
		string memory _symbol,
		address initialHolder,
		uint256 initialSupply,
		uint256 initialFeatures
	) public initializer {
		// verify name and symbol are set
		require(bytes(_name).length > 0, "token name is not set");
		require(bytes(_symbol).length > 0, "token symbol is not set");

		// assign token name and symbol
		name = _name;
		symbol = _symbol;

		// verify initial holder address non-zero (is set) if there is an initial supply to mint
		require(initialSupply == 0 || initialHolder != address(0), "_initialHolder not set (zero address)");

		// if there is an initial supply to mint
		if(initialSupply != 0) {
			// mint the initial supply
			__mint(initialHolder, initialSupply);
		}

		// if initial contract owner or features are specified
		if(contractOwner != address(0) || initialFeatures != 0) {
			// initialize the RBAC module
			_postConstruct(contractOwner, initialFeatures);
		}
	}

	/**
	 * @inheritdoc ERC165
	 */
	function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
		// reconstruct from current interface(s) and super interface(s) (if any)
		return interfaceId == type(ERC165).interfaceId
		    || interfaceId == type(ERC20).interfaceId
		    || interfaceId == type(ERC1363).interfaceId
		    || interfaceId == type(EIP2612).interfaceId
		    || interfaceId == type(EIP3009).interfaceId;
	}

	// ===== Start: ERC-1363 functions =====

	/**
	 * @notice Transfers some tokens and then executes `onTransferReceived` callback on the receiver
	 *
	 * @inheritdoc ERC1363
	 *
	 * @dev Called by token owner (an address which has a
	 *      positive token balance tracked by this smart contract)
	 * @dev Throws on any error like
	 *      * insufficient token balance or
	 *      * incorrect `to` address:
	 *          * zero address or
	 *          * same as `from` address (self transfer)
	 *          * EOA or smart contract which doesn't support ERC1363Receiver interface
	 * @dev Returns true on success, throws otherwise
	 *
	 * @param to an address to transfer tokens to,
	 *      must be a smart contract, implementing ERC1363Receiver
	 * @param value amount of tokens to be transferred, zero
	 *      value is allowed
	 * @return true unless throwing
	 */
	function transferAndCall(address to, uint256 value) public override returns (bool) {
		// delegate to `transferFromAndCall` passing `msg.sender` as `from`
		return transferFromAndCall(msg.sender, to, value);
	}

	/**
	 * @notice Transfers some tokens and then executes `onTransferReceived` callback on the receiver
	 *
	 * @inheritdoc ERC1363
	 *
	 * @dev Called by token owner (an address which has a
	 *      positive token balance tracked by this smart contract)
	 * @dev Throws on any error like
	 *      * insufficient token balance or
	 *      * incorrect `to` address:
	 *          * zero address or
	 *          * same as `from` address (self transfer)
	 *          * EOA or smart contract which doesn't support ERC1363Receiver interface
	 * @dev Returns true on success, throws otherwise
	 *
	 * @param to an address to transfer tokens to,
	 *      must be a smart contract, implementing ERC1363Receiver
	 * @param value amount of tokens to be transferred, zero
	 *      value is allowed
	 * @param data [optional] additional data with no specified format,
	 *      sent in onTransferReceived call to `to`
	 * @return true unless throwing
	 */
	function transferAndCall(address to, uint256 value, bytes memory data) public override returns (bool) {
		// delegate to `transferFromAndCall` passing `msg.sender` as `from`
		return transferFromAndCall(msg.sender, to, value, data);
	}

	/**
	 * @notice Transfers some tokens on behalf of address `from' (token owner)
	 *      to some other address `to` and then executes `onTransferReceived` callback on the receiver
	 *
	 * @inheritdoc ERC1363
	 *
	 * @dev Called by token owner on his own or approved address,
	 *      an address approved earlier by token owner to
	 *      transfer some amount of tokens on its behalf
	 * @dev Throws on any error like
	 *      * insufficient token balance or
	 *      * incorrect `to` address:
	 *          * zero address or
	 *          * same as `from` address (self transfer)
	 *          * EOA or smart contract which doesn't support ERC1363Receiver interface
	 * @dev Returns true on success, throws otherwise
	 *
	 * @param from token owner which approved caller (transaction sender)
	 *      to transfer `value` of tokens on its behalf
	 * @param to an address to transfer tokens to,
	 *      must be a smart contract, implementing ERC1363Receiver
	 * @param value amount of tokens to be transferred, zero
	 *      value is allowed
	 * @return true unless throwing
	 */
	function transferFromAndCall(address from, address to, uint256 value) public override returns (bool) {
		// delegate to `transferFromAndCall` passing empty data param
		return transferFromAndCall(from, to, value, "");
	}

	/**
	 * @notice Transfers some tokens on behalf of address `from' (token owner)
	 *      to some other address `to` and then executes a `onTransferReceived` callback on the receiver
	 *
	 * @inheritdoc ERC1363
	 *
	 * @dev Called by token owner on his own or approved address,
	 *      an address approved earlier by token owner to
	 *      transfer some amount of tokens on its behalf
	 * @dev Throws on any error like
	 *      * insufficient token balance or
	 *      * incorrect `to` address:
	 *          * zero address or
	 *          * same as `from` address (self transfer)
	 *          * EOA or smart contract which doesn't support ERC1363Receiver interface
	 * @dev Returns true on success, throws otherwise
	 *
	 * @param from token owner which approved caller (transaction sender)
	 *      to transfer `value` of tokens on its behalf
	 * @param to an address to transfer tokens to,
	 *      must be a smart contract, implementing ERC1363Receiver
	 * @param value amount of tokens to be transferred, zero
	 *      value is allowed
	 * @param data [optional] additional data with no specified format,
	 *      sent in onTransferReceived call to `to`
	 * @return true unless throwing
	 */
	function transferFromAndCall(address from, address to, uint256 value, bytes memory data) public override returns (bool) {
		// ensure ERC-1363 transfers are enabled
		require(isFeatureEnabled(FEATURE_ERC1363_TRANSFERS), "ERC1363 transfers are disabled");

		// first delegate call to `unsafeTransferFrom` to perform the unsafe token(s) transfer
		unsafeTransferFrom(from, to, value);

		// after the successful transfer - check if receiver supports
		// ERC1363Receiver and execute a callback handler `onTransferReceived`,
		// reverting whole transaction on any error
		_notifyTransferred(from, to, value, data, false);

		// function throws on any error, so if we're here - it means operation successful, just return true
		return true;
	}

	/**
	 * @notice Approves address called `spender` to transfer some amount
	 *      of tokens on behalf of the owner, then executes a `onApprovalReceived` callback on `spender`
	 *
	 * @inheritdoc ERC1363
	 *
	 * @dev Caller must not necessarily own any tokens to grant the permission
	 *
	 * @dev Throws if `spender` is an EOA or a smart contract which doesn't support ERC1363Spender interface
	 *
	 * @param spender an address approved by the caller (token owner)
	 *      to spend some tokens on its behalf
	 * @param value an amount of tokens spender `spender` is allowed to
	 *      transfer on behalf of the token owner
	 * @return true unless throwing
	 */
	function approveAndCall(address spender, uint256 value) public override returns (bool) {
		// delegate to `approveAndCall` passing empty data
		return approveAndCall(spender, value, "");
	}

	/**
	 * @notice Approves address called `spender` to transfer some amount
	 *      of tokens on behalf of the owner, then executes a callback on `spender`
	 *
	 * @inheritdoc ERC1363
	 *
	 * @dev Caller must not necessarily own any tokens to grant the permission
	 *
	 * @param spender an address approved by the caller (token owner)
	 *      to spend some tokens on its behalf
	 * @param value an amount of tokens spender `spender` is allowed to
	 *      transfer on behalf of the token owner
	 * @param data [optional] additional data with no specified format,
	 *      sent in onApprovalReceived call to `spender`
	 * @return true unless throwing
	 */
	function approveAndCall(address spender, uint256 value, bytes memory data) public override returns (bool) {
		// ensure ERC-1363 approvals are enabled
		require(isFeatureEnabled(FEATURE_ERC1363_APPROVALS), "ERC1363 approvals are disabled");

		// execute regular ERC20 approve - delegate to `approve`
		approve(spender, value);

		// after the successful approve - check if receiver supports
		// ERC1363Spender and execute a callback handler `onApprovalReceived`,
		// reverting whole transaction on any error
		_notifyApproved(spender, value, data);

		// function throws on any error, so if we're here - it means operation successful, just return true
		return true;
	}

	/**
	 * @dev Auxiliary function to invoke `onTransferReceived` on a target address
	 *      The call is not executed if the target address is not a contract; in such
	 *      a case function throws if `allowEoa` is set to false, succeeds if it's true
	 *
	 * @dev Throws on any error; returns silently on success
	 *
	 * @param from representing the previous owner of the given token value
	 * @param to target address that will receive the tokens
	 * @param value the amount mount of tokens to be transferred
	 * @param data [optional] data to send along with the call
	 * @param allowEoa indicates if function should fail if `to` is an EOA
	 */
	function _notifyTransferred(address from, address to, uint256 value, bytes memory data, bool allowEoa) private {
		// if recipient `to` is EOA
		if(to.code.length == 0) { // !AddressUtils.isContract(_to)
			// ensure EOA recipient is allowed
			require(allowEoa, "EOA recipient");

			// exit if successful
			return;
		}

		// otherwise - if `to` is a contract - execute onTransferReceived
		bytes4 response = ERC1363Receiver(to).onTransferReceived(msg.sender, from, value, data);

		// expected response is ERC1363Receiver(_to).onTransferReceived.selector
		// bytes4(keccak256("onTransferReceived(address,address,uint256,bytes)"))
		require(response == ERC1363Receiver(to).onTransferReceived.selector, "invalid onTransferReceived response");
	}

	/**
	 * @dev Auxiliary function to invoke `onApprovalReceived` on a target address
	 *      The call is not executed if the target address is not a contract; in such
	 *      a case function throws if `allowEoa` is set to false, succeeds if it's true
	 *
	 * @dev Throws on any error; returns silently on success
	 *
	 * @param spender the address which will spend the funds
	 * @param value the amount of tokens to be spent
	 * @param data [optional] data to send along with the call
	 */
	function _notifyApproved(address spender, uint256 value, bytes memory data) private {
		// ensure recipient is not EOA
		require(spender.code.length > 0, "EOA spender"); // AddressUtils.isContract(_spender)

		// otherwise - if `to` is a contract - execute onApprovalReceived
		bytes4 response = ERC1363Spender(spender).onApprovalReceived(msg.sender, value, data);

		// expected response is ERC1363Spender(_to).onApprovalReceived.selector
		// bytes4(keccak256("onApprovalReceived(address,uint256,bytes)"))
		require(response == ERC1363Spender(spender).onApprovalReceived.selector, "invalid onApprovalReceived response");
	}
	// ===== End: ERC-1363 functions =====

	// ===== Start: ERC20 functions =====

	/**
	 * @notice Gets the balance of a particular address
	 *
	 * @inheritdoc ERC20
	 *
	 * @param owner the address to query the the balance for
	 * @return balance an amount of tokens owned by the address specified
	 */
	function balanceOf(address owner) public view override returns (uint256 balance) {
		// read the balance and return
		return tokenBalances[owner];
	}

	/**
	 * @notice Transfers some tokens to an external address or a smart contract
	 *
	 * @inheritdoc ERC20
	 *
	 * @dev Called by token owner (an address which has a
	 *      positive token balance tracked by this smart contract)
	 * @dev Throws on any error like
	 *      * insufficient token balance or
	 *      * incorrect `to` address:
	 *          * zero address or
	 *          * self address or
	 *          * smart contract which doesn't support ERC20
	 *
	 * @param to an address to transfer tokens to,
	 *      must be either an external address or a smart contract,
	 *      compliant with the ERC20 standard
	 * @param value amount of tokens to be transferred, zero
	 *      value is allowed
	 * @return success true on success, throws otherwise
	 */
	function transfer(address to, uint256 value) public override returns (bool success) {
		// just delegate call to `transferFrom`,
		// `FEATURE_TRANSFERS` is verified inside it
		return transferFrom(msg.sender, to, value);
	}

	/**
	 * @notice Transfers some tokens on behalf of address `from' (token owner)
	 *      to some other address `to`
	 *
	 * @inheritdoc ERC20
	 *
	 * @dev Called by token owner on his own or approved address,
	 *      an address approved earlier by token owner to
	 *      transfer some amount of tokens on its behalf
	 * @dev Throws on any error like
	 *      * insufficient token balance or
	 *      * incorrect `to` address:
	 *          * zero address or
	 *          * same as `from` address (self transfer)
	 *          * smart contract which doesn't support ERC20
	 *
	 * @param from token owner which approved caller (transaction sender)
	 *      to transfer `value` of tokens on its behalf
	 * @param to an address to transfer tokens to,
	 *      must be either an external address or a smart contract,
	 *      compliant with the ERC20 standard
	 * @param value amount of tokens to be transferred, zero
	 *      value is allowed
	 * @return success true on success, throws otherwise
	 */
	function transferFrom(address from, address to, uint256 value) public override returns (bool success) {
		// depending on `FEATURE_UNSAFE_TRANSFERS` we execute either safe (default)
		// or unsafe transfer
		// if `FEATURE_UNSAFE_TRANSFERS` is enabled
		// or receiver has `ROLE_ERC20_RECEIVER` permission
		// or sender has `ROLE_ERC20_SENDER` permission
		if(isFeatureEnabled(FEATURE_UNSAFE_TRANSFERS)
			|| isOperatorInRole(to, ROLE_ERC20_RECEIVER)
			|| isSenderInRole(ROLE_ERC20_SENDER)) {
			// we execute unsafe transfer - delegate call to `unsafeTransferFrom`,
			// `FEATURE_TRANSFERS` is verified inside it
			unsafeTransferFrom(from, to, value);
		}
		// otherwise - if `FEATURE_UNSAFE_TRANSFERS` is disabled
		// and receiver doesn't have `ROLE_ERC20_RECEIVER` permission
		else {
			// we execute safe transfer - delegate call to `safeTransferFrom`, passing empty `data`,
			// `FEATURE_TRANSFERS` is verified inside it
			safeTransferFrom(from, to, value, "");
		}

		// both `unsafeTransferFrom` and `safeTransferFrom` throw on any error, so
		// if we're here - it means operation successful,
		// just return true
		return true;
	}

	/**
	 * @notice Transfers some tokens on behalf of address `from' (token owner)
	 *      to some other address `to` and then executes `onTransferReceived` callback
	 *      on the receiver if it is a smart contract (not an EOA)
	 *
	 * @dev Called by token owner on his own or approved address,
	 *      an address approved earlier by token owner to
	 *      transfer some amount of tokens on its behalf
	 * @dev Throws on any error like
	 *      * insufficient token balance or
	 *      * incorrect `to` address:
	 *          * zero address or
	 *          * same as `from` address (self transfer)
	 *          * smart contract which doesn't support ERC1363Receiver interface
	 * @dev Returns true on success, throws otherwise
	 *
	 * @param from token owner which approved caller (transaction sender)
	 *      to transfer `value` of tokens on its behalf
	 * @param to an address to transfer tokens to,
	 *      must be either an external address or a smart contract,
	 *      implementing ERC1363Receiver
	 * @param value amount of tokens to be transferred, zero
	 *      value is allowed
	 * @param data [optional] additional data with no specified format,
	 *      sent in onTransferReceived call to `to` in case if its a smart contract
	 * @return true unless throwing
	 */
	function safeTransferFrom(address from, address to, uint256 value, bytes memory data) public returns (bool) {
		// first delegate call to `unsafeTransferFrom` to perform the unsafe token(s) transfer
		unsafeTransferFrom(from, to, value);

		// after the successful transfer - check if receiver supports
		// ERC1363Receiver and execute a callback handler `onTransferReceived`,
		// reverting whole transaction on any error
		_notifyTransferred(from, to, value, data, true);

		// function throws on any error, so if we're here - it means operation successful, just return true
		return true;
	}

	/**
	 * @notice Transfers some tokens on behalf of address `from' (token owner)
	 *      to some other address `to`
	 *
	 * @dev In contrast to `transferFromAndCall` doesn't check recipient
	 *      smart contract to support ERC20 tokens (ERC1363Receiver)
	 * @dev Designed to be used by developers when the receiver is known
	 *      to support ERC20 tokens but doesn't implement ERC1363Receiver interface
	 * @dev Called by token owner on his own or approved address,
	 *      an address approved earlier by token owner to
	 *      transfer some amount of tokens on its behalf
	 * @dev Throws on any error like
	 *      * insufficient token balance or
	 *      * incorrect `to` address:
	 *          * zero address or
	 *          * same as `from` address (self transfer)
	 * @dev Returns silently on success, throws otherwise
	 *
	 * @param from token sender, token owner which approved caller (transaction sender)
	 *      to transfer `value` of tokens on its behalf
	 * @param to token receiver, an address to transfer tokens to
	 * @param value amount of tokens to be transferred, zero
	 *      value is allowed
	 */
	function unsafeTransferFrom(address from, address to, uint256 value) public {
		// make an internal transferFrom - delegate to `__transferFrom`
		__transferFrom(msg.sender, from, to, value);
	}

	/**
	 * @dev Powers the meta transactions for `unsafeTransferFrom` - EIP-3009 `transferWithAuthorization`
	 *      and `receiveWithAuthorization`
	 *
	 * @dev See `unsafeTransferFrom` and `transferFrom` soldoc for details
	 *
	 * @param by an address executing the transfer, it can be token owner itself,
	 *      or an operator previously approved with `approve()`
	 * @param from token sender, token owner which approved caller (transaction sender)
	 *      to transfer `value` of tokens on its behalf
	 * @param to token receiver, an address to transfer tokens to
	 * @param value amount of tokens to be transferred, zero
	 *      value is allowed
	 */
	function __transferFrom(address by, address from, address to, uint256 value) private {
		// if `from` is equal to sender, require transfers feature to be enabled
		// otherwise require transfers on behalf feature to be enabled
		require(from == by && isFeatureEnabled(FEATURE_TRANSFERS)
		     || from != by && isFeatureEnabled(FEATURE_TRANSFERS_ON_BEHALF),
		        from == by ? "transfers are disabled": "transfers on behalf are disabled");

		// non-zero source address check - Zeppelin
		// obviously, zero source address is a client mistake
		// it's not part of ERC20 standard but it's reasonable to fail fast
		// since for zero value transfer transaction succeeds otherwise
		require(from != address(0), "transfer from the zero address");

		// non-zero recipient address check
		require(to != address(0), "transfer to the zero address");

		// according to the Ethereum ERC20 token standard, it is possible to transfer
		// tokens to oneself using the transfer or transferFrom functions.
		// In both cases, the transfer will succeed as long as the sender has a sufficient balance of tokens.
		// require(_from != _to, "sender and recipient are the same (_from = _to)");

		// sending tokens to the token smart contract itself is a client mistake
		require(to != address(this), "invalid recipient (transfer to the token smart contract itself)");

		// according to ERC-20 Token Standard, https://eips.ethereum.org/EIPS/eip-20
		// "Transfers of 0 values MUST be treated as normal transfers and fire the Transfer event."
		if(value == 0) {
			// emit an improved transfer event (arXiv:1907.00903)
			emit Transfer(by, from, to, value);

			// emit an ERC20 transfer event
			emit Transfer(from, to, value);

			// don't forget to return - we're done
			return;
		}

		// no need to make arithmetic overflow check on the `value` - by design of mint()

		// in case of transfer on behalf
		if(from != by) {
			// read allowance value - the amount of tokens allowed to transfer - into the stack
			uint256 _allowance = transferAllowances[from][by];

			// verify sender has an allowance to transfer amount of tokens requested
			require(_allowance >= value, "transfer amount exceeds allowance");

			// we treat max uint256 allowance value as an "unlimited" and
			// do not decrease allowance when it is set to "unlimited" value
			if(_allowance < type(uint256).max) {
				// update allowance value on the stack
				_allowance -= value;

				// update the allowance value in storage
				transferAllowances[from][by] = _allowance;

				// emit an improved atomic approve event
				emit Approval(from, by, _allowance + value, _allowance);

				// emit an ERC20 approval event to reflect the decrease
				emit Approval(from, by, _allowance);
			}
		}

		// verify sender has enough tokens to transfer on behalf
		require(tokenBalances[from] >= value, "transfer amount exceeds balance");

		// perform the transfer:
		// decrease token owner (sender) balance
		tokenBalances[from] -= value;

		// increase `to` address (receiver) balance
		tokenBalances[to] += value;

		// move voting power associated with the tokens transferred
		__moveVotingPower(by, votingDelegates[from], votingDelegates[to], value);

		// emit an improved transfer event (arXiv:1907.00903)
		emit Transfer(by, from, to, value);

		// emit an ERC20 transfer event
		emit Transfer(from, to, value);
	}

	/**
	 * @notice Approves address called `spender` to transfer some amount
	 *      of tokens on behalf of the owner (transaction sender)
	 *
	 * @inheritdoc ERC20
	 *
	 * @dev Transaction sender must not necessarily own any tokens to grant the permission
	 *
	 * @param spender an address approved by the caller (token owner)
	 *      to spend some tokens on its behalf
	 * @param value an amount of tokens spender `spender` is allowed to
	 *      transfer on behalf of the token owner
	 * @return success true on success, throws otherwise
	 */
	function approve(address spender, uint256 value) public override returns (bool success) {
		// make an internal approve - delegate to `__approve`
		__approve(msg.sender, spender, value);

		// operation successful, return true
		return true;
	}

	/**
	 * @dev Powers the meta transaction for `approve` - EIP-2612 `permit`
	 *
	 * @dev Approves address called `spender` to transfer some amount
	 *      of tokens on behalf of the `owner`
	 *
	 * @dev `owner` must not necessarily own any tokens to grant the permission
	 * @dev Throws if `spender` is a zero address
	 *
	 * @param owner owner of the tokens to set approval on behalf of
	 * @param spender an address approved by the token owner
	 *      to spend some tokens on its behalf
	 * @param value an amount of tokens spender `spender` is allowed to
	 *      transfer on behalf of the token owner
	 */
	function __approve(address owner, address spender, uint256 value) private {
		// non-zero spender address check - Zeppelin
		// obviously, zero spender address is a client mistake
		// it's not part of ERC20 standard but it's reasonable to fail fast
		require(spender != address(0), "approve to the zero address");

		// read old approval value to emmit an improved event (arXiv:1907.00903)
		uint256 oldValue = transferAllowances[owner][spender];

		// perform an operation: write value requested into the storage
		transferAllowances[owner][spender] = value;

		// emit an improved atomic approve event (arXiv:1907.00903)
		emit Approval(owner, spender, oldValue, value);

		// emit an ERC20 approval event
		emit Approval(owner, spender, value);
	}

	/**
	 * @notice Returns the amount which spender is still allowed to withdraw from owner.
	 *
	 * @inheritdoc ERC20
	 *
	 * @dev A function to check an amount of tokens owner approved
	 *      to transfer on its behalf by some other address called "spender"
	 *
	 * @param owner an address which approves transferring some tokens on its behalf
	 * @param spender an address approved to transfer some tokens on behalf
	 * @return remaining an amount of tokens approved address `spender` can transfer on behalf
	 *      of token owner `owner`
	 */
	function allowance(address owner, address spender) public view override returns (uint256 remaining) {
		// read the value from storage and return
		return transferAllowances[owner][spender];
	}

	// ===== End: ERC20 functions =====

	// ===== Start: Resolution for the Multiple Withdrawal Attack on ERC20 Tokens (arXiv:1907.00903) =====

	/**
	 * @notice Increases the allowance granted to `spender` by the transaction sender
	 *
	 * @dev Resolution for the Multiple Withdrawal Attack on ERC20 Tokens (arXiv:1907.00903)
	 *
	 * @dev Throws if value to increase by is zero or too big and causes arithmetic overflow
	 *
	 * @param spender an address approved by the caller (token owner)
	 *      to spend some tokens on its behalf
	 * @param value an amount of tokens to increase by
	 * @return true unless throwing
	 */
	function increaseAllowance(address spender, uint256 value) public returns (bool) {
		// read current allowance value
		uint256 currentVal = transferAllowances[msg.sender][spender];

		// non-zero value and arithmetic overflow check on the allowance
		unchecked {
			// put operation into unchecked block to display user-friendly overflow error message for Solidity 0.8+
			require(currentVal + value > currentVal, "zero value approval increase or arithmetic overflow");
		}

		// delegate call to `approve` with the new value
		return approve(spender, currentVal + value);
	}

	/**
	 * @notice Decreases the allowance granted to `spender` by the caller.
	 *
	 * @dev Resolution for the Multiple Withdrawal Attack on ERC20 Tokens (arXiv:1907.00903)
	 *
	 * @dev Throws if value to decrease by is zero or is greater than currently allowed value
	 *
	 * @param spender an address approved by the caller (token owner)
	 *      to spend some tokens on its behalf
	 * @param value an amount of tokens to decrease by
	 * @return true unless throwing
	 */
	function decreaseAllowance(address spender, uint256 value) public returns (bool) {
		// read current allowance value
		uint256 currentVal = transferAllowances[msg.sender][spender];

		// non-zero value check on the allowance
		require(value > 0, "zero value approval decrease");

		// verify allowance decrease doesn't underflow
		require(currentVal >= value, "ERC20: decreased allowance below zero");

		// delegate call to `approve` with the new value
		return approve(spender, currentVal - value);
	}

	// ===== End: Resolution for the Multiple Withdrawal Attack on ERC20 Tokens (arXiv:1907.00903) =====

	// ===== Start: Minting/burning extension =====

	/**
	 * @dev Mints (creates) some tokens to address specified
	 * @dev The value specified is treated as is without taking
	 *      into account what `decimals` value is
	 *
	 * @dev Requires executor to have `ROLE_TOKEN_CREATOR` permission
	 *
	 * @dev Throws on overflow, if totalSupply + value doesn't fit into uint192
	 *
	 * @param to an address to mint tokens to
	 * @param value an amount of tokens to mint (create)
	 * @return success true on success, throws otherwise
	 */
	function mint(address to, uint256 value) public override virtual returns(bool success) {
		// check if caller has sufficient permissions to mint tokens
		require(isSenderInRole(ROLE_TOKEN_CREATOR), "access denied");

		// delegate call to unsafe `__mint`
		__mint(to, value);

		// always return true
		return true;
	}

	/**
	 * @dev Mints (creates) some tokens to address specified
	 * @dev The value specified is treated as is without taking
	 *      into account what `decimals` value is
	 *
	 * @dev Unsafe: doesn't verify the executor (msg.sender) permissions,
	 *      must be kept private at all times
	 *
	 * @dev Throws on overflow, if totalSupply + value doesn't fit into uint256
	 *
	 * @param to an address to mint tokens to
	 * @param value an amount of tokens to mint (create)
	 */
	function __mint(address to, uint256 value) private {
		// non-zero recipient address check
		require(to != address(0), "zero address");

		// non-zero value and arithmetic overflow check on the total supply
		// this check automatically secures arithmetic overflow on the individual balance
		unchecked {
			// put operation into unchecked block to display user-friendly overflow error message for Solidity 0.8+
			require(totalSupply + value > totalSupply, "zero value or arithmetic overflow");
		}

		// uint192 overflow check (required by voting delegation)
		require(totalSupply + value <= type(uint192).max, "total supply overflow (uint192)");

		// perform mint:
		// increase total amount of tokens value
		totalSupply += value;

		// increase `to` address balance
		tokenBalances[to] += value;

		// update total token supply history
		__updateHistory(totalSupplyHistory, add, value);

		// create voting power associated with the tokens minted
		__moveVotingPower(msg.sender, address(0), votingDelegates[to], value);

		// fire a minted event
		emit Minted(msg.sender, to, value);

		// emit an improved transfer event (arXiv:1907.00903)
		emit Transfer(msg.sender, address(0), to, value);

		// fire ERC20 compliant transfer event
		emit Transfer(address(0), to, value);
	}

	/**
	 * @dev Burns (destroys) some tokens from the address specified
	 *
	 * @dev The value specified is treated as is without taking
	 *      into account what `decimals` value is
	 *
	 * @dev Requires executor to have `ROLE_TOKEN_DESTROYER` permission
	 *      or FEATURE_OWN_BURNS/FEATURE_BURNS_ON_BEHALF features to be enabled
	 *
	 * @dev Can be disabled by the contract creator forever by disabling
	 *      FEATURE_OWN_BURNS/FEATURE_BURNS_ON_BEHALF features and then revoking
	 *      its own roles to burn tokens and to enable burning features
	 *
	 * @param from an address to burn some tokens from
	 * @param value an amount of tokens to burn (destroy)
	 * @return success true on success, throws otherwise
	 */
	function burn(address from, uint256 value) public override virtual returns(bool success) {
		// check if caller has sufficient permissions to burn tokens
		// and if not - check for possibility to burn own tokens or to burn on behalf
		if(!isSenderInRole(ROLE_TOKEN_DESTROYER)) {
			// if `from` is equal to sender, require own burns feature to be enabled
			// otherwise require burns on behalf feature to be enabled
			require(from == msg.sender && isFeatureEnabled(FEATURE_OWN_BURNS)
			     || from != msg.sender && isFeatureEnabled(FEATURE_BURNS_ON_BEHALF),
			        from == msg.sender? "burns are disabled": "burns on behalf are disabled");

			// in case of burn on behalf
			if(from != msg.sender) {
				// read allowance value - the amount of tokens allowed to be burnt - into the stack
				uint256 _allowance = transferAllowances[from][msg.sender];

				// verify sender has an allowance to burn amount of tokens requested
				require(_allowance >= value, "burn amount exceeds allowance");

				// we treat max uint256 allowance value as an "unlimited" and
				// do not decrease allowance when it is set to "unlimited" value
				if(_allowance < type(uint256).max) {
					// update allowance value on the stack
					_allowance -= value;

					// update the allowance value in storage
					transferAllowances[from][msg.sender] = _allowance;

					// emit an improved atomic approve event (arXiv:1907.00903)
					emit Approval(msg.sender, from, _allowance + value, _allowance);

					// emit an ERC20 approval event to reflect the decrease
					emit Approval(from, msg.sender, _allowance);
				}
			}
		}

		// at this point we know that either sender is ROLE_TOKEN_DESTROYER or
		// we burn own tokens or on behalf (in latest case we already checked and updated allowances)
		// we have left to execute balance checks and burning logic itself

		// non-zero burn value check
		require(value != 0, "zero value burn");

		// non-zero source address check - Zeppelin
		require(from != address(0), "burn from the zero address");

		// verify `from` address has enough tokens to destroy
		// (basically this is a arithmetic overflow check)
		require(tokenBalances[from] >= value, "burn amount exceeds balance");

		// perform burn:
		// decrease `from` address balance
		tokenBalances[from] -= value;

		// decrease total amount of tokens value
		totalSupply -= value;

		// update total token supply history
		__updateHistory(totalSupplyHistory, sub, value);

		// destroy voting power associated with the tokens burnt
		__moveVotingPower(msg.sender, votingDelegates[from], address(0), value);

		// fire a burnt event
		emit Burnt(msg.sender, from, value);

		// emit an improved transfer event (arXiv:1907.00903)
		emit Transfer(msg.sender, from, address(0), value);

		// fire ERC20 compliant transfer event
		emit Transfer(from, address(0), value);

		// always return true
		return true;
	}

	// ===== End: Minting/burning extension =====

	// ===== Start: EIP-2612 functions =====

	/**
	 * @inheritdoc EIP2612
	 *
	 * @dev Executes approve(spender, value) on behalf of the owner who EIP-712
	 *      signed the transaction, i.e. as if transaction sender is the EIP712 signer
	 *
	 * @dev Sets the `value` as the allowance of `spender` over `owner` tokens,
	 *      given `owner` EIP-712 signed approval
	 *
	 * @dev Inherits the Multiple Withdrawal Attack on ERC20 Tokens (arXiv:1907.00903)
	 *      vulnerability in the same way as ERC20 `approve`, use standard ERC20 workaround
	 *      if this might become an issue:
	 *      https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/edit
	 *
	 * @dev Emits `Approval` event(s) in the same way as `approve` does
	 *
	 * @dev Requires:
	 *     - `spender` to be non-zero address
	 *     - `exp` to be a timestamp in the future
	 *     - `v`, `r` and `s` to be a valid `secp256k1` signature from `owner`
	 *        over the EIP712-formatted function arguments.
	 *     - the signature to use `owner` current nonce (see `nonces`).
	 *
	 * @dev For more information on the signature format, see the
	 *      https://eips.ethereum.org/EIPS/eip-2612#specification
	 *
	 * @param owner owner of the tokens to set approval on behalf of,
	 *      an address which signed the EIP-712 message
	 * @param spender an address approved by the token owner
	 *      to spend some tokens on its behalf
	 * @param value an amount of tokens spender `spender` is allowed to
	 *      transfer on behalf of the token owner
	 * @param exp signature expiration time (unix timestamp)
	 * @param v the recovery byte of the signature
	 * @param r half of the ECDSA signature pair
	 * @param s half of the ECDSA signature pair
	 */
	function permit(address owner, address spender, uint256 value, uint256 exp, uint8 v, bytes32 r, bytes32 s) public override {
		// verify permits are enabled
		require(isFeatureEnabled(FEATURE_EIP2612_PERMITS), "EIP2612 permits are disabled");

		// derive signer of the EIP712 Permit message, and
		// update the nonce for that particular signer to avoid replay attack!!! --------->>> ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
		address signer = __deriveSigner(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, exp), v, r, s);

		// perform message integrity and security validations
		require(signer == owner, "invalid signature");
		require(block.timestamp < exp, "signature expired");

		// delegate call to `__approve` - execute the logic required
		__approve(owner, spender, value);
	}

	// ===== End: EIP-2612 functions =====

	// ===== Start: EIP-3009 functions =====

	/**
	 * @inheritdoc EIP3009
	 *
	 * @notice Checks if specified nonce was already used
	 *
	 * @dev Nonces are expected to be client-side randomly generated 32-byte values
	 *      unique to the authorizer's address
	 *
	 * @dev Alias for usedNonces(authorizer, nonce)
	 *
	 * @param authorizer an address to check nonce for
	 * @param nonce a nonce to check
	 * @return true if the nonce was used, false otherwise
	 */
	function authorizationState(address authorizer, bytes32 nonce) public override view returns (bool) {
		// simply return the value from the mapping
		return usedNonces[authorizer][nonce];
	}

	/**
	 * @inheritdoc EIP3009
	 *
	 * @notice Execute a transfer with a signed authorization
	 *
	 * @param from token sender and transaction authorizer
	 * @param to token receiver
	 * @param value amount to be transferred
	 * @param validAfter signature valid after time (unix timestamp)
	 * @param validBefore signature valid before time (unix timestamp)
	 * @param nonce unique random nonce
	 * @param v the recovery byte of the signature
	 * @param r half of the ECDSA signature pair
	 * @param s half of the ECDSA signature pair
	 */
	function transferWithAuthorization(
		address from,
		address to,
		uint256 value,
		uint256 validAfter,
		uint256 validBefore,
		bytes32 nonce,
		uint8 v,
		bytes32 r,
		bytes32 s
	) public override {
		// ensure EIP-3009 transfers are enabled
		require(isFeatureEnabled(FEATURE_EIP3009_TRANSFERS), "EIP3009 transfers are disabled");

		// derive signer of the EIP712 TransferWithAuthorization message
		address signer = __deriveSigner(abi.encode(TRANSFER_WITH_AUTHORIZATION_TYPEHASH, from, to, value, validAfter, validBefore, nonce), v, r, s);

		// perform message integrity and security validations
		require(signer == from, "invalid signature");
		require(block.timestamp > validAfter, "signature not yet valid");
		require(block.timestamp < validBefore, "signature expired");

		// use the nonce supplied (verify, mark as used, emit event)
		__useNonce(from, nonce, false);

		// delegate call to `__transferFrom` - execute the logic required
		__transferFrom(signer, from, to, value);
	}

	/**
	 * @inheritdoc EIP3009
	 *
	 * @notice Receive a transfer with a signed authorization from the payer
	 *
	 * @dev This has an additional check to ensure that the payee's address
	 *      matches the caller of this function to prevent front-running attacks.
	 *
	 * @param from token sender and transaction authorizer
	 * @param to token receiver
	 * @param value amount to be transferred
	 * @param validAfter signature valid after time (unix timestamp)
	 * @param validBefore signature valid before time (unix timestamp)
	 * @param nonce unique random nonce
	 * @param v the recovery byte of the signature
	 * @param r half of the ECDSA signature pair
	 * @param s half of the ECDSA signature pair
	 */
	function receiveWithAuthorization(
		address from,
		address to,
		uint256 value,
		uint256 validAfter,
		uint256 validBefore,
		bytes32 nonce,
		uint8 v,
		bytes32 r,
		bytes32 s
	) public override {
		// verify EIP3009 receptions are enabled
		require(isFeatureEnabled(FEATURE_EIP3009_RECEPTIONS), "EIP3009 receptions are disabled");

		// derive signer of the EIP712 ReceiveWithAuthorization message
		address signer = __deriveSigner(abi.encode(RECEIVE_WITH_AUTHORIZATION_TYPEHASH, from, to, value, validAfter, validBefore, nonce), v, r, s);

		// perform message integrity and security validations
		require(signer == from, "invalid signature");
		require(block.timestamp > validAfter, "signature not yet valid");
		require(block.timestamp < validBefore, "signature expired");
		require(to == msg.sender, "access denied");

		// use the nonce supplied (verify, mark as used, emit event)
		__useNonce(from, nonce, false);

		// delegate call to `__transferFrom` - execute the logic required
		__transferFrom(signer, from, to, value);
	}

	/**
	 * @inheritdoc EIP3009
	 *
	 * @notice Attempt to cancel an authorization
	 *
	 * @param authorizer transaction authorizer
	 * @param nonce unique random nonce to cancel (mark as used)
	 * @param v the recovery byte of the signature
	 * @param r half of the ECDSA signature pair
	 * @param s half of the ECDSA signature pair
	 */
	function cancelAuthorization(
		address authorizer,
		bytes32 nonce,
		uint8 v,
		bytes32 r,
		bytes32 s
	) public override {
		// derive signer of the EIP712 ReceiveWithAuthorization message
		address signer = __deriveSigner(abi.encode(CANCEL_AUTHORIZATION_TYPEHASH, authorizer, nonce), v, r, s);

		// perform message integrity and security validations
		require(signer == authorizer, "invalid signature");

		// cancel the nonce supplied (verify, mark as used, emit event)
		__useNonce(authorizer, nonce, true);
	}

	/**
	 * @dev Auxiliary function to verify structured EIP712 message signature and derive its signer
	 *
	 * @param abiEncodedTypehash abi.encode of the message typehash together with all its parameters
	 * @param v the recovery byte of the signature
	 * @param r half of the ECDSA signature pair
	 * @param s half of the ECDSA signature pair
	 */
	function __deriveSigner(bytes memory abiEncodedTypehash, uint8 v, bytes32 r, bytes32 s) private view returns(address) {
		// build the EIP-712 hashStruct of the message
		bytes32 hashStruct = keccak256(abiEncodedTypehash);

		// calculate the EIP-712 digest "\x19\x01" ‖ domainSeparator ‖ hashStruct(message)
		bytes32 digest = keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), hashStruct));

		// recover the address which signed the message with v, r, s
		address signer = ECDSA.recover(digest, v, r, s);

		// according to EIP3009 spec, zero address must be rejected when using ecrecover
		// this check already happened inside `ECDSA.recover`

		// return the signer address derived from the signature
		return signer;
	}

	/**
	 * @dev Auxiliary function to use/cancel the nonce supplied for a given authorizer:
	 *      1. Verifies the nonce was not used before
	 *      2. Marks the nonce as used
	 *      3. Emits an event that the nonce was used/cancelled
	 *
	 * @dev Set `cancellation` to false (default) to use nonce,
	 *      set `cancellation` to true to cancel nonce
	 *
	 * @dev It is expected that the nonce supplied is a randomly
	 *      generated uint256 generated by the client
	 *
	 * @param authorizer an address to use/cancel nonce for
	 * @param nonce random nonce to use
	 * @param cancellation true to emit `AuthorizationCancelled`, false to emit `AuthorizationUsed` event
	 */
	function __useNonce(address authorizer, bytes32 nonce, bool cancellation) private {
		// verify nonce was not used before
		require(!usedNonces[authorizer][nonce], "invalid nonce");

		// update the nonce state to "used" for that particular signer to avoid replay attack
		usedNonces[authorizer][nonce] = true;

		// depending on the usage type (use/cancel)
		if(cancellation) {
			// emit an event regarding the nonce cancelled
			emit AuthorizationCanceled(authorizer, nonce);
		}
		else {
			// emit an event regarding the nonce used
			emit AuthorizationUsed(authorizer, nonce);
		}
	}

	// ===== End: EIP-3009 functions =====

	// ===== Start: DAO Support (Compound-like voting delegation) =====

	/**
	 * @notice Gets current voting power of the account `holder`
	 *
	 * @param holder the address of account to get voting power of
	 * @return current cumulative voting power of the account,
	 *      sum of token balances of all its voting delegators
	 */
	function votingPowerOf(address holder) public view returns (uint256) {
		// get a link to an array of voting power history records for an address specified
		KV[] storage history = votingPowerHistory[holder];

		// lookup the history and return latest element
		return history.length == 0? 0: history[history.length - 1].v;
	}

	/**
	 * @notice Gets past voting power of the account `holder` at some block `blockNum`
	 *
	 * @dev Throws if `blockNum` is not in the past (not the finalized block)
	 *
	 * @param holder the address of account to get voting power of
	 * @param blockNum block number to get the voting power at
	 * @return past cumulative voting power of the account,
	 *      sum of token balances of all its voting delegators at block number `blockNum`
	 */
	function votingPowerAt(address holder, uint256 blockNum) public view returns (uint256) {
		// make sure block number is in the past (the finalized block)
		require(blockNum < block.number, "block not yet mined"); // Compound msg not yet determined

		// `votingPowerHistory[holder]` is an array ordered by `blockNumber`, ascending;
		// apply binary search on `votingPowerHistory[_of]` to find such an entry number `i`, that
		// `votingPowerHistory[holder][i].k ≤ blockNum`, but in the same time
		// `votingPowerHistory[holder][i + 1].k > blockNum`
		// return the result - voting power found at index `i`
		return __binaryLookup(votingPowerHistory[holder], blockNum);
	}

	/**
	 * @dev Reads an entire voting power history array for the delegate specified
	 *
	 * @param holder delegate to query voting power history for
	 * @return voting power history array for the delegate of interest
	 */
	function votingPowerHistoryOf(address holder) public view returns(KV[] memory) {
		// return an entire array as memory
		return votingPowerHistory[holder];
	}

	/**
	 * @dev Returns length of the voting power history array for the delegate specified;
	 *      useful since reading an entire array just to get its length is expensive (gas cost)
	 *
	 * @param holder delegate to query voting power history length for
	 * @return voting power history array length for the delegate of interest
	 */
	function votingPowerHistoryLength(address holder) public view returns(uint256) {
		// read array length and return
		return votingPowerHistory[holder].length;
	}

	/**
	 * @notice Gets past total token supply value at some block `blockNum`
	 *
	 * @dev Throws if `blockNum` is not in the past (not the finalized block)
	 *
	 * @param blockNum block number to get the total token supply at
	 * @return past total token supply at block number `blockNum`
	 */
	function totalSupplyAt(uint256 blockNum) public view returns(uint256) {
		// make sure block number is in the past (the finalized block)
		require(blockNum < block.number, "block not yet mined");

		// `totalSupplyHistory` is an array ordered by `k`, ascending;
		// apply binary search on `totalSupplyHistory` to find such an entry number `i`, that
		// `totalSupplyHistory[i].k ≤ blockNum`, but in the same time
		// `totalSupplyHistory[i + 1].k > blockNum`
		// return the result - value `totalSupplyHistory[i].v` found at index `i`
		return __binaryLookup(totalSupplyHistory, blockNum);
	}

	/**
	 * @dev Reads an entire total token supply history array
	 *
	 * @return total token supply history array, a key-value pair array,
	 *      where key is a block number and value is total token supply at that block
	 */
	function entireSupplyHistory() public view returns(KV[] memory) {
		// return an entire array as memory
		return totalSupplyHistory;
	}

	/**
	 * @dev Returns length of the total token supply history array;
	 *      useful since reading an entire array just to get its length is expensive (gas cost)
	 *
	 * @return total token supply history array
	 */
	function totalSupplyHistoryLength() public view returns(uint256) {
		// read array length and return
		return totalSupplyHistory.length;
	}

	/**
	 * @notice Delegates voting power of the delegator `msg.sender` to the delegate `to`
	 *
	 * @dev Accepts zero value address to delegate voting power to, effectively
	 *      removing the delegate in that case
	 *
	 * @param to address to delegate voting power to
	 */
	function delegate(address to) public {
		// verify delegations are enabled
		require(isFeatureEnabled(FEATURE_DELEGATIONS), "delegations are disabled");
		// delegate call to `__delegate`
		__delegate(msg.sender, to);
	}

	/**
	 * @dev Powers the meta transaction for `delegate` - `delegateWithAuthorization`
	 *
	 * @dev Auxiliary function to delegate delegator's `from` voting power to the delegate `to`
	 * @dev Writes to `votingDelegates` and `votingPowerHistory` mappings
	 *
	 * @param from delegator who delegates his voting power
	 * @param to delegate who receives the voting power
	 */
	function __delegate(address from, address to) private {
		// read current delegate to be replaced by a new one
		address fromDelegate = votingDelegates[from];

		// read current voting power (it is equal to token balance)
		uint256 value = tokenBalances[from];

		// reassign voting delegate to `to`
		votingDelegates[from] = to;

		// update voting power for `fromDelegate` and `to`
		__moveVotingPower(from, fromDelegate, to, value);

		// emit an event
		emit DelegateChanged(from, fromDelegate, to);
	}

	/**
	 * @notice Delegates voting power of the delegator (represented by its signature) to the delegate `to`
	 *
	 * @dev Accepts zero value address to delegate voting power to, effectively
	 *      removing the delegate in that case
	 *
	 * @dev Compliant with EIP-712: Ethereum typed structured data hashing and signing,
	 *      see https://eips.ethereum.org/EIPS/eip-712
	 *
	 * @param to address to delegate voting power to
	 * @param nonce nonce used to construct the signature, and used to validate it;
	 *      nonce is increased by one after successful signature validation and vote delegation
	 * @param exp signature expiration time
	 * @param v the recovery byte of the signature
	 * @param r half of the ECDSA signature pair
	 * @param s half of the ECDSA signature pair
	 */
	function delegateWithAuthorization(address to, bytes32 nonce, uint256 exp, uint8 v, bytes32 r, bytes32 s) public {
		// verify delegations on behalf are enabled
		require(isFeatureEnabled(FEATURE_DELEGATIONS_ON_BEHALF), "delegations on behalf are disabled");

		// derive signer of the EIP712 Delegation message
		address signer = __deriveSigner(abi.encode(DELEGATION_TYPEHASH, to, nonce, exp), v, r, s);

		// perform message integrity and security validations
		require(block.timestamp < exp, "signature expired"); // Compound msg

		// use the nonce supplied (verify, mark as used, emit event)
		__useNonce(signer, nonce, false);

		// delegate call to `__delegate` - execute the logic required
		__delegate(signer, to);
	}

	/**
	 * @dev Auxiliary function to move voting power `value`
	 *      from delegate `from` to the delegate `to`
	 *
	 * @dev Doesn't have any effect if `from == to`, or if `value == 0`
	 *
	 * @param by an address which executed delegate, mint, burn, or transfer operation
	 *      which had led to delegate voting power change
	 * @param from delegate to move voting power from
	 * @param to delegate to move voting power to
	 * @param value voting power to move from `from` to `to`
	 */
	function __moveVotingPower(address by, address from, address to, uint256 value) private {
		// if there is no move (`from == to`) or there is nothing to move (`value == 0`)
		if(from == to || value == 0) {
			// return silently with no action
			return;
		}

		// if source address is not zero - decrease its voting power
		if(from != address(0)) {
			// get a link to an array of voting power history records for an address specified
			KV[] storage h = votingPowerHistory[from];

			// update source voting power: decrease by `value`
			(uint256 fromVal, uint256 toVal) = __updateHistory(h, sub, value);

			// emit an event
			emit VotingPowerChanged(by, from, fromVal, toVal);
		}

		// if destination address is not zero - increase its voting power
		if(to != address(0)) {
			// get a link to an array of voting power history records for an address specified
			KV[] storage h = votingPowerHistory[to];

			// update destination voting power: increase by `value`
			(uint256 fromVal, uint256 toVal) = __updateHistory(h, add, value);

			// emit an event
			emit VotingPowerChanged(by, to, fromVal, toVal);
		}
	}

	/**
	 * @dev Auxiliary function to append key-value pair to an array,
	 *      sets the key to the current block number and
	 *      value as derived
	 *
	 * @param h array of key-value pairs to append to
	 * @param op a function (add/subtract) to apply
	 * @param delta the value for a key-value pair to add/subtract
	 */
	function __updateHistory(
		KV[] storage h,
		function(uint256,uint256) pure returns(uint256) op,
		uint256 delta
	) private returns(uint256 fromVal, uint256 toVal) {
		// init the old value - value of the last pair of the array
		fromVal = h.length == 0? 0: h[h.length - 1].v;
		// init the new value - result of the operation on the old value
		toVal = op(fromVal, delta);

		// if there is an existing voting power value stored for current block
		if(h.length != 0 && h[h.length - 1].k == block.number) {
			// update voting power which is already stored in the current block
			h[h.length - 1].v = uint192(toVal);
		}
		// otherwise - if there is no value stored for current block
		else {
			// add new element into array representing the value for current block
			h.push(KV(uint64(block.number), uint192(toVal)));
		}
	}

	/**
	 * @dev Auxiliary function to lookup for a value in a sorted by key (ascending)
	 *      array of key-value pairs
	 *
	 * @dev This function finds a key-value pair element in an array with the closest key
	 *      to the key of interest (not exceeding that key) and returns the value
	 *      of the key-value pair element found
	 *
	 * @dev An array to search in is a KV[] key-value pair array ordered by key `k`,
	 *      it is sorted in ascending order (`k` increases as array index increases)
	 *
	 * @dev Returns zero for an empty array input regardless of the key input
	 *
	 * @param h an array of key-value pair elements to search in
	 * @param k key of interest to look the value for
	 * @return the value of the key-value pair of the key-value pair element with the closest
	 *      key to the key of interest (not exceeding that key)
	 */
	function __binaryLookup(KV[] storage h, uint256 k) private view returns(uint256) {
		// if an array is empty, there is nothing to lookup in
		if(h.length == 0) {
			// by documented agreement, fall back to a zero result
			return 0;
		}

		// check last key-value pair key:
		// if the key is smaller than the key of interest
		if(h[h.length - 1].k <= k) {
			// we're done - return the value from the last element
			return h[h.length - 1].v;
		}

		// check first voting power history record block number:
		// if history was never updated before the block of interest
		if(h[0].k > k) {
			// we're done - voting power at the block num of interest was zero
			return 0;
		}

		// left bound of the search interval, originally start of the array
		uint256 i = 0;

		// right bound of the search interval, originally end of the array
		uint256 j = h.length - 1;

		// the iteration process narrows down the bounds by
		// splitting the interval in a half oce per each iteration
		while(j > i) {
			// get an index in the middle of the interval [i, j]
			uint256 m = j - (j - i) / 2;

			// read an element to compare it with the value of interest
			KV memory kv = h[m];

			// if we've got a strict equal - we're lucky and done
			if(kv.k == k) {
				// just return the result - pair value at index `k`
				return kv.v;
			}
			// if the value of interest is larger - move left bound to the middle
			else if(kv.k < k) {
				// move left bound `i` to the middle position `k`
				i = m;
			}
			// otherwise, when the value of interest is smaller - move right bound to the middle
			else {
				// move right bound `j` to the middle position `k - 1`:
				// element at position `k` is greater and cannot be the result
				j = m - 1;
			}
		}

		// reaching that point means no exact match found
		// since we're interested in the element which is not larger than the
		// element of interest, we return the lower bound `i`
		return h[i].v;
	}

	/**
	 * @dev Adds a + b
	 *      Function is used as a parameter for other functions
	 *
	 * @param a addition term 1
	 * @param b addition term 2
	 * @return a + b
	 */
	function add(uint256 a, uint256 b) private pure returns(uint256) {
		// add `a` to `b` and return
		return a + b;
	}

	/**
	 * @dev Subtracts a - b
	 *      Function is used as a parameter for other functions
	 *
	 * @dev Requires a ≥ b
	 *
	 * @param a subtraction term 1
	 * @param b subtraction term 2, b ≤ a
	 * @return a - b
	 */
	function sub(uint256 a, uint256 b) private pure returns(uint256) {
		// subtract `b` from `a` and return
		return a - b;
	}

	// ===== End: DAO Support (Compound-like voting delegation) =====
}

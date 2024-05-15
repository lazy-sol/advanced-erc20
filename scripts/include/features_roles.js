// copy and export all the features and roles constants from different contracts

// export what is available already in the RBAC module
const {
	ROLE_ACCESS_MANAGER,
	ROLE_UPGRADE_MANAGER,
	FULL_PRIVILEGES_MASK,
	or,
	not,
} = require("@lazy-sol/access-control-upgradeable");

// All 16 features enabled
const FEATURE_ALL = 0x0000_FFFF;

// All 16 features disabled
const FEATURE_NONE = 0x0000_0000;

// Start: ===== ERC20/ERC721 =====

/**
 * [ERC20/ERC721] Enables ERC20/ERC721 transfers of the tokens
 *      (transfer by the token owner himself)
 */
const FEATURE_TRANSFERS = 0x0000_0001;

/**
 * [ERC20/ERC721] Enables ERC20/ERC721 transfers on behalf
 *      (transfer by someone else on behalf of token owner)
 */
const FEATURE_TRANSFERS_ON_BEHALF = 0x0000_0002;

/**
 * [ERC20] Defines if the default behavior of `transfer` and `transferFrom`
 *      checks if the receiver smart contract supports ERC20 tokens
 */
const FEATURE_UNSAFE_TRANSFERS = 0x0000_0004;

/**
 * [ERC20/ERC721] Enables token owners to burn their own tokens
 */
const FEATURE_OWN_BURNS = 0x0000_0008;

/**
 * [ERC20/ERC721] Enables approved operators to burn tokens on behalf of their owners
 */
const FEATURE_BURNS_ON_BEHALF = 0x0000_0010;

/**
 * [ERC20] Enables delegators to elect delegates
 */
const FEATURE_DELEGATIONS = 0x0000_0020;

/**
 * [ERC20] Enables delegators to elect delegates on behalf
 *      (via an EIP712 signature)
 */
const FEATURE_DELEGATIONS_ON_BEHALF = 0x0000_0040;

/**
 * [ERC20] Enables ERC-1363 transfers with callback
 */
const FEATURE_ERC1363_TRANSFERS = 0x0000_0080;

/**
 * [ERC20] Enables ERC-1363 approvals with callback
 */
const FEATURE_ERC1363_APPROVALS = 0x0000_0100;

/**
 * [ERC20] Enables approvals on behalf (EIP2612 permits
 *      via an EIP712 signature)
 */
const FEATURE_EIP2612_PERMITS = 0x0000_0200;

/**
 * [ERC20] Enables meta transfers on behalf (EIP3009 transfers
 *      via an EIP712 signature)
 */
const FEATURE_EIP3009_TRANSFERS = 0x0000_0400;

/**
 * [ERC20] Enables meta transfers on behalf (EIP3009 transfers
 *      via an EIP712 signature)
 */
const FEATURE_EIP3009_RECEPTIONS = 0x0000_0800;

// [ERC721] Enables approvals on behalf (permits via an EIP712 signature)
const FEATURE_PERMITS = 0x0000_0200;

// [ERC721] Enables operator approvals on behalf (permits for all via an EIP712 signature)
const FEATURE_OPERATOR_PERMITS = 0x0000_0400;

/**
 * [ERC20/ERC721] Token creator is responsible for creating (minting)
 *      tokens to an arbitrary address
 */
const ROLE_TOKEN_CREATOR = 0x0001_0000;

/**
 * [ERC20/ERC721] Token destroyer is responsible for destroying (burning)
 *      tokens owned by an arbitrary address
 */
const ROLE_TOKEN_DESTROYER = 0x0002_0000;

/**
 * [ERC20] ERC20 receivers are allowed to receive tokens without ERC20 safety checks,
 *      which may be useful to simplify tokens transfers into "legacy" smart contracts
 */
const ROLE_ERC20_RECEIVER = 0x0004_0000;

/**
 * [ERC20] ERC20 senders are allowed to send tokens without ERC20 safety checks,
 *      which may be useful to simplify tokens transfers into "legacy" smart contracts
 */
const ROLE_ERC20_SENDER = 0x0008_0000;

// [ERC721] URI manager is responsible for managing base URI part of the token URI ERC721Metadata interface
const ROLE_URI_MANAGER = 0x0010_0000;

// End: ===== ERC20/ERC721 =====

// export public module API
module.exports = {
	ROLE_ACCESS_MANAGER,
	ROLE_UPGRADE_MANAGER,
	FULL_PRIVILEGES_MASK,
	or,
	not,
	FEATURE_ALL,
	FEATURE_NONE,
	FEATURE_TRANSFERS,
	FEATURE_TRANSFERS_ON_BEHALF,
	FEATURE_UNSAFE_TRANSFERS,
	FEATURE_OWN_BURNS,
	FEATURE_BURNS_ON_BEHALF,
	FEATURE_DELEGATIONS,
	FEATURE_DELEGATIONS_ON_BEHALF,
	FEATURE_ERC1363_TRANSFERS,
	FEATURE_ERC1363_APPROVALS,
	FEATURE_EIP2612_PERMITS,
	FEATURE_EIP3009_TRANSFERS,
	FEATURE_EIP3009_RECEPTIONS,
	FEATURE_PERMITS,
	FEATURE_OPERATOR_PERMITS,
	ROLE_TOKEN_CREATOR,
	ROLE_TOKEN_DESTROYER,
	ROLE_ERC20_RECEIVER,
	ROLE_ERC20_SENDER,
	ROLE_URI_MANAGER,
};

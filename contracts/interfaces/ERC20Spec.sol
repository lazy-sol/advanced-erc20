// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @title EIP-20: ERC-20 Token Standard
 *
 * @notice The ERC-20 (Ethereum Request for Comments 20), proposed by Fabian Vogelsteller in November 2015,
 *      is a Token Standard that implements an API for tokens within Smart Contracts.
 *
 * @notice It provides functionalities like to transfer tokens from one account to another,
 *      to get the current token balance of an account and also the total supply of the token available on the network.
 *      Besides these it also has some other functionalities like to approve that an amount of
 *      token from an account can be spent by a third party account.
 *
 * @notice If a Smart Contract implements the following methods and events it can be called an ERC-20 Token
 *      Contract and, once deployed, it will be responsible to keep track of the created tokens on Ethereum.
 *
 * @notice See https://ethereum.org/en/developers/docs/standards/tokens/erc-20/
 * @notice See https://eips.ethereum.org/EIPS/eip-20
 */
interface ERC20 {
	/**
	 * @dev Fired in transfer(), transferFrom() to indicate that token transfer happened
	 *
	 * @param from an address tokens were consumed from
	 * @param to an address tokens were sent to
	 * @param value number of tokens transferred
	 */
	event Transfer(address indexed from, address indexed to, uint256 value);

	/**
	 * @dev Fired in approve() to indicate an approval event happened
	 *
	 * @param owner an address which granted a permission to transfer
	 *      tokens on its behalf
	 * @param spender an address which received a permission to transfer
	 *      tokens on behalf of the owner `owner`
	 * @param value amount of tokens granted to transfer on behalf
	 */
	event Approval(address indexed owner, address indexed spender, uint256 value);

	/**
	 * @return name of the token (ex.: USD Coin)
	 */
	// OPTIONAL - This method can be used to improve usability,
	// but interfaces and other contracts MUST NOT expect these values to be present.
	// function name() external view returns (string memory);

	/**
	 * @return symbol of the token (ex.: USDC)
	 */
	// OPTIONAL - This method can be used to improve usability,
	// but interfaces and other contracts MUST NOT expect these values to be present.
	// function symbol() external view returns (string memory);

	/**
	 * @dev Returns the number of decimals used to get its user representation.
	 *      For example, if `decimals` equals `2`, a balance of `505` tokens should
	 *      be displayed to a user as `5,05` (`505 / 10 ** 2`).
	 *
	 * @dev Tokens usually opt for a value of 18, imitating the relationship between
	 *      Ether and Wei. This is the value {ERC20} uses, unless this function is
	 *      overridden;
	 *
	 * @dev NOTE: This information is only used for _display_ purposes: it in
	 *      no way affects any of the arithmetic of the contract, including
	 *      {IERC20-balanceOf} and {IERC20-transfer}.
	 *
	 * @return token decimals
	 */
	// OPTIONAL - This method can be used to improve usability,
	// but interfaces and other contracts MUST NOT expect these values to be present.
	// function decimals() external view returns (uint8);

	/**
	 * @return the amount of tokens in existence
	 */
	function totalSupply() external view returns (uint256);

	/**
	 * @notice Gets the balance of a particular address
	 *
	 * @param owner the address to query the the balance for
	 * @return balance an amount of tokens owned by the address specified
	 */
	function balanceOf(address owner) external view returns (uint256 balance);

	/**
	 * @notice Transfers some tokens to an external address or a smart contract
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
	 * @param value amount of tokens to be transferred,, zero
	 *      value is allowed
	 * @return success true on success, throws otherwise
	 */
	function transfer(address to, uint256 value) external returns (bool success);

	/**
	 * @notice Transfers some tokens on behalf of address `from' (token owner)
	 *      to some other address `to`
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
	 * @param value amount of tokens to be transferred,, zero
	 *      value is allowed
	 * @return success true on success, throws otherwise
	 */
	function transferFrom(address from, address to, uint256 value) external returns (bool success);

	/**
	 * @notice Approves address called `spender` to transfer some amount
	 *      of tokens on behalf of the owner (transaction sender)
	 *
	 * @dev Transaction sender must not necessarily own any tokens to grant the permission
	 *
	 * @param spender an address approved by the caller (token owner)
	 *      to spend some tokens on its behalf
	 * @param value an amount of tokens spender `spender` is allowed to
	 *      transfer on behalf of the token owner
	 * @return success true on success, throws otherwise
	 */
	function approve(address spender, uint256 value) external returns (bool success);

	/**
	 * @notice Returns the amount which `spender` is still allowed to withdraw from `owner`.
	 *
	 * @dev A function to check an amount of tokens owner approved
	 *      to transfer on its behalf by some other address called "spender"
	 *
	 * @param owner an address which approves transferring some tokens on its behalf
	 * @param spender an address approved to transfer some tokens on behalf
	 * @return remaining an amount of tokens approved address `spender` can transfer on behalf
	 *      of token owner `owner`
	 */
	function allowance(address owner, address spender) external view returns (uint256 remaining);
}

/**
 * @title Mintable/burnable ERC20 Extension
 *
 * @notice Adds mint/burn functions to the ERC20 interface;
 *      these functions are usually present in ERC20 implementations;
 *      they become a must for the bridged tokens since the bridge usually
 *      needs to have a way to mint tokens deposited from L1 to L2
 *      and to burn tokens to be withdrawn from L2 to L1
 */
interface MintableBurnableERC20 is ERC20 {
	/**
	 * @dev Mints (creates) some tokens to address specified
	 * @dev The value specified is treated as is without taking
	 *      into account what `decimals` value is
	 *
	 * @param to an address to mint tokens to
	 * @param value an amount of tokens to mint (create)
	 * @return success true on success, false otherwise
	 */
	function mint(address to, uint256 value) external returns (bool success);

	/**
	 * @dev Burns (destroys) some tokens from the address specified
	 *
	 * @dev The value specified is treated as is without taking
	 *      into account what `decimals` value is
	 *
	 * @param from an address to burn some tokens from
	 * @param value an amount of tokens to burn (destroy)
	 * @return success true on success, false otherwise
	 */
	function burn(address from, uint256 value) external returns (bool success);
}

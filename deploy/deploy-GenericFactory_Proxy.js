// deploy: npx hardhat deploy --network sepolia --tags GenericFactory_Proxy
// verify: npx hardhat etherscan-verify --network sepolia --api-key $ETHERSCAN_KEY

// script is built for hardhat-deploy plugin:
// A Hardhat Plugin For Replicable Deployments And Easy Testing
// https://www.npmjs.com/package/hardhat-deploy

// deployment utils (contract state printers)
const {
	print_amt,
	print_contract_details,
} = require("@lazy-sol/a-missing-gem");

// to be picked up and executed by hardhat-deploy plugin
module.exports = async function({deployments, getChainId, getNamedAccounts, getUnnamedAccounts}) {
	// print some useful info on the account we're using for the deployment
	const chainId = await getChainId();
	const accounts = await web3.eth.getAccounts();
	// do not use the default account for tests
	const A0 = network.name === "hardhat"? accounts[1]: accounts[0];
	const nonce = await web3.eth.getTransactionCount(A0);
	const balance = await web3.eth.getBalance(A0);

	// print initial debug information
	console.log("script: %o", require("path").basename(__filename));
	console.log("network %o %o", chainId, network.name);
	console.log("accounts: %o, service account %o, nonce: %o, balance: %o ETH", accounts.length, A0, nonce, print_amt(balance));

	// GenericFactory ERC1967Proxy
	{
		// get the deployment details
		const v1_deployment = await deployments.get("GenericFactoryV1");
		const v1_contract = new web3.eth.Contract(v1_deployment.abi, v1_deployment.address);

		// print v1 deployment details
		await print_contract_details(A0, v1_deployment.abi, v1_deployment.address);

		// prepare proxy initialization call bytes
		const proxy_init_data = v1_contract.methods.postConstruct().encodeABI();

		// deploy ERC1967 proxy
		await deployments.deploy("GenericFactory_Proxy", {
			// address (or private key) that will perform the transaction.
			// you can use `getNamedAccounts` to retrieve the address you want by name.
			from: A0,
			contract: "ERC1967Proxy",
			// the list of argument for the constructor (or the upgrade function in case of proxy)
			args: [v1_deployment.address, proxy_init_data],
			// if set it to true, will not attempt to deploy even if the contract deployed under the same name is different
			skipIfAlreadyDeployed: true,
			// if true, it will log the result of the deployment (tx hash, address and gas used)
			log: true,
		});

		// get proxy deployment details
		const proxy_deployment = await deployments.get("GenericFactory_Proxy");
		const proxy_contract = new web3.eth.Contract(v1_deployment.abi, proxy_deployment.address);

		// print proxy deployment details
		await print_contract_details(A0, v1_deployment.abi, proxy_deployment.address);
	}
};

// Tags represent what the deployment script acts on. In general, it will be a single string value,
// the name of the contract it deploys or modifies.
// Then if another deploy script has such tag as a dependency, then when the latter deploy script has a specific tag
// and that tag is requested, the dependency will be executed first.
// https://www.npmjs.com/package/hardhat-deploy#deploy-scripts-tags-and-dependencies
module.exports.tags = ["GenericFactory_Proxy", "deploy", "v1_0"];
module.exports.dependencies = ["GenericFactoryV1"];

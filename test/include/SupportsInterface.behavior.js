// Auxiliary behavior for ERC165 Interface ID tests, imported from vittominacori
// Source: https://github.com/vittominacori/erc1363-payable-token/blob/master/test/introspection/SupportsInterface.behavior.js

const { makeInterfaceId } = require('@lazy-sol/zeppelin-test-helpers');

const { expect } = require('chai');

const INTERFACES = {
  ERC165: [
    'supportsInterface(bytes4)',
  ],
  ERC20: [
    'totalSupply()',
    'balanceOf(address)',
    'transfer(address,uint256)',
    'transferFrom(address,address,uint256)',
    'approve(address,uint256)',
    'allowance(address,address)',
  ],
  ERC721: [
    'balanceOf(address)',
    'ownerOf(uint256)',
    'safeTransferFrom(address,address,uint256,bytes)',
    'safeTransferFrom(address,address,uint256)',
    'transferFrom(address,address,uint256)',
    'approve(address,uint256)',
    'setApprovalForAll(address,bool)',
    'getApproved(uint256)',
    'isApprovedForAll(address,address)',
  ],
  ERC1363: [
    'transferAndCall(address,uint256)',
    'transferAndCall(address,uint256,bytes)',
    'transferFromAndCall(address,address,uint256)',
    'transferFromAndCall(address,address,uint256,bytes)',
    'approveAndCall(address,uint256)',
    'approveAndCall(address,uint256,bytes)',
  ],
  ERC1363Receiver: [
    'onTransferReceived(address,address,uint256,bytes)',
  ],
  ERC1363Spender: [
    'onApprovalReceived(address,uint256,bytes)',
  ],
  EIP2612: [
    'DOMAIN_SEPARATOR()',
    'nonces(address)',
    'permit(address,address,uint256,uint256,uint8,bytes32,bytes32)',
  ],
  EIP3009: [
    'authorizationState(address,bytes32)',
    'transferWithAuthorization(address,address,uint256,uint256,uint256,bytes32,uint8,bytes32,bytes32)',
    'receiveWithAuthorization(address,address,uint256,uint256,uint256,bytes32,uint8,bytes32,bytes32)',
    'cancelAuthorization(address,bytes32,uint8,bytes32,bytes32)',
  ],
};

const INTERFACE_IDS = {};
const FN_SIGNATURES = {};
for (const k of Object.getOwnPropertyNames(INTERFACES)) {
  INTERFACE_IDS[k] = makeInterfaceId.ERC165(INTERFACES[k]);
  for (const fnName of INTERFACES[k]) {
    // the interface id of a single function is equivalent to its function signature
    FN_SIGNATURES[fnName] = makeInterfaceId.ERC165([fnName]);
  }
}

function shouldSupportInterfaces (interfaces = [], contractInstanceFn = () => undefined) {
  describe('Contract interface', function () {
    beforeEach(function () {
      this.contractUnderTest = contractInstanceFn() || this.mock || this.token || this.holder;
    });

    for (const k of interfaces) {
      const interfaceId = INTERFACE_IDS[k];
      describe(k, function () {
        describe('ERC165\'s supportsInterface(bytes4)', function () {
          it('uses less than 30k gas [skip-on-coverage]', async function () {
            expect(await this.contractUnderTest.supportsInterface.estimateGas(interfaceId)).to.be.lte(30000);
          });

          it(`claims support ${k}: ${interfaceId}`, async function () {
            expect(await this.contractUnderTest.supportsInterface(interfaceId)).to.equal(true);
          });
        });

        for (const fnName of INTERFACES[k]) {
          const fnSig = FN_SIGNATURES[fnName];
          describe(fnName, function () {
            it('has to be implemented', function () {
              expect(this.contractUnderTest.abi.filter(fn => fn.signature === fnSig).length).to.equal(1);
            });
          });
        }
      });
    }
  });
}

module.exports = {
  INTERFACE_IDS,
  shouldSupportInterfaces,
};

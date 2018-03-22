const CDPOpener = artifacts.require("./CDPOpener.sol");
const TestExchange = artifacts.require("./TestExchange.sol");

module.exports = function(deployer) {
  deployer.deploy(CDPOpener);
  //deployer.deploy(TestExchange);
};

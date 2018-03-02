const CDPOpener = artifacts.require("./CDPOpener.sol");

module.exports = function(deployer) {
  deployer.deploy(CDPOpener);
};

const CDPLeverage = artifacts.require("./CDPLeverage.sol");

module.exports = function(deployer) {
  deployer.deploy(CDPLeverage);
};

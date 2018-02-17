var Ethleverage = artifacts.require("./Ethleverage.sol");

const kovanSai = 0x95878488a599e1d821C0fF2Bc079b9e7F96d95bE;
const kovanTub = 0xa6bfc88aa5a5981a958f9bcb885fcb3db0bf941e;


module.exports = function(deployer, network, accounts) {

    if (network == "kovan") {
      deployer.deploy(Ethleverage, kovanTub, kovanSai);
    }
    else
    {
      deployer.deploy()
    }

};

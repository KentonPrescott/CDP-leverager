var Ethleverage = artifacts.require("./Ethleverage.sol");

const kovanSai = 0xC4375B7De8af5a38a93548eb8453a498222C4fF2;
const kovanTub = 0xa71937147b55Deb8a530C7229C442Fd3F31b7db2;
const kovanWeth = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
const kovanPeth = 0xf4d791139cE033Ad35DB2B2201435fAd668B1b64;
const kovanMKR = 0xAaF64BFCC32d0F15873a02163e7E500671a4ffcD;

const wethContract = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
const pethContract = 0xf53AD2c6851052A81B42133467480961B2321C09;
const liqRatio = 150; //possibly 1.6 to account for governance fee
//need to add more here

module.exports = function(deployer, network, accounts) {

    if (network == "kovan") {
      deployer.deploy(Ethleverage, liqRatio);
    }
    else {
    }

};

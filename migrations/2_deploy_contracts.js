var Ethleverage = artifacts.require("./Ethleverage.sol");

const kovanSai = 0x95878488a599e1d821C0fF2Bc079b9e7F96d95bE;
const kovanTub = 0xa6bfc88aa5a5981a958f9bcb885fcb3db0bf941e;
const kovanWeth = 0xd0a1e359811322d97991e03f863a0c30c2cf029c;
const kovanPeth = 0x1508d42373235103081bd4d223379469f686bc55;
const kovanMKR = 0xaaf64bfcc32d0f15873a02163e7e500671a4ffcd;

const wethContract = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
const pethContract = 0xf53AD2c6851052A81B42133467480961B2321C09;
const LiquidationRatio = 1.5; //possibly 1.6 to account for governance fee
//need to add more here

module.exports = function(deployer, network, accounts) {

    if (network == "kovan") {
      deployer.deploy(Ethleverage, kovanTub, kovanSai, kovanWeth, kovanPeth, kovanMKR, LiquidationRatio);
    }
    else {
      deployer.deploy(Ethleverage, kovanTub, kovanSai);
    }

};

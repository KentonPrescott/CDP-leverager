pragma solidity ^0.4.18;

import "./IOracle.sol";

contract MakerPriceOracle {

  address public bossMan;
  address public OracleAddress;

  modifier onlyBossman() {
    require(msg.sender == bossMan);
    _;
  }

  function MakerPriceOracle() public {
    bossMan = msg.sender;

    // mainnetOracleAddress: 0x729D19f657BD0614b4985Cf1D82531c67569197B;
    // kovanOracleAddress:  0xA944bd4b25C9F186A846fd5668941AA3d3B8425F;
    OracleAddress = 0xA944bd4b25C9F186A846fd5668941AA3d3B8425F;
  }

  function setOracleAddress(address _newAddress) onlyBossman public {
    require(_newAddress != address(0));
    OracleAddress = _newAddress;
  }

  function getPrice() public returns (uint) {
    return uint(IOracle(OracleAddress).read());
  }

}

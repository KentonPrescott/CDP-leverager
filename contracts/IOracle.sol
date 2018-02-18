pragma solidity ^0.4.18;

contract IOracle {
  function read() constant returns (bytes32);
}

pragma solidity ^0.4.16;

interface IMKRContract {
  function approve(address guy, uint wad) public /*stoppable*/ returns (bool);
}

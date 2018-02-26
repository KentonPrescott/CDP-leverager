pragma solidity ^0.4.16;

interface IwethContract {
  function approve(address guy, uint wad) public returns (bool);

  function deposit() public payable;

  function() payable public ;
}

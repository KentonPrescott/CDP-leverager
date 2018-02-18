pragma solidity ^0.4.18;

contract ICDPContract {
  // Commenting out the stoppable for now, but I think we'll need
  // to inherit some more stuff. Not sure if this'll break stuff.
  function approve(address guy) public /*stoppable*/ returns (bool) {}

  function open() public /*note*/ returns (bytes32 cup) {}

  function join (uint wad) public note {}

  function lock(bytes32 cup, uint wad) public note {}

  function draw(bytes32 cup, uint wad) public note {}


}

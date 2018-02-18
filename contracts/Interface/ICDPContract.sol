pragma solidity ^0.4.18;

// File found here:
// https://github.com/makerdao/sai/blob/master/src/tub.sol

contract ICDPContract {
  // Commenting out the stoppable for now, but I think we'll need
  // to inherit some more stuff. Not sure if this'll break stuff.
  function approve(address guy) public /*stoppable*/ returns (bool);

  function open() public /*note*/ returns (bytes32 cup);

  function join (uint wad) public /*note*/;

  function lock(bytes32 cup, uint wad) public /*note*/;

  function draw(bytes32 cup, uint wad) public /*note*/;

  function wipe(bytes32 cup, uint wad) public /*note*/;

  function free(bytes32 cup, uint wad) public /*note*/;

  function exit(uint wad) public /*note*/;

  function wipe(bytes32 cup, uint wad) public  /*note*/;

  function shut(bytes32 cup) public /*note*/;

}

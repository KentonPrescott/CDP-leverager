pragma solidity ^0.4.18;

contract IDaiContract {
  // Commenting out the stoppable for now, but I think we'll need
  // to inherit some more stuff. Not sure if this'll break stuff.
  function approve(address guy, uint wad) public /*stoppable*/ returns (bool){}

}

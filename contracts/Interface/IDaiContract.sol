pragma solidity ^0.4.16;

// File found here:
// https://github.com/makerdao/sai/blob/4b0c94b8ef2d8e0951dd0a0eee7c0fce5f5dbb49/src/weth9.sol
contract IDaiContract {
  function approve(address guy, uint wad) public returns (bool);
}

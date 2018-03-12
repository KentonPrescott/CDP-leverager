pragma solidity ^0.4.18;

// File found here:
// https://github.com/makerdao/sai/blob/4b0c94b8ef2d8e0951dd0a0eee7c0fce5f5dbb49/src/weth9.sol
interface IMoneyMaker {

  function buyAllEthWithDai() external returns (uint256);

  function sellAllEthForDai() external returns (uint256);

}

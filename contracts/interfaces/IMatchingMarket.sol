pragma solidity ^0.4.22;

import "./DSToken.sol";

interface IMatchingMarket {

  function buyAllAmount(DSToken buy_gem, uint buy_amt, DSToken pay_gem, uint max_fill_amount) external;

  function sellAllAmount(DSToken pay_gem, uint pay_amt, DSToken buy_gem, uint min_fill_amount) external;

  function getPayAmount(DSToken pay_gem, DSToken buy_gem, uint buy_amt) external constant returns (uint fill_amt);

  function getBuyAmount(DSToken buy_gem, DSToken pay_gem, uint pay_amt) external constant returns (uint fill_amt);

  function getBestOffer(DSToken sell_gem, DSToken buy_gem) external constant returns (uint);

  function getOffer(uint id) external constant returns (uint, DSToken, uint, DSToken);
}

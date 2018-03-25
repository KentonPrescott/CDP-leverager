pragma solidity ^0.4.16;

import "./DSToken.sol";

interface IMatchingMarket {

  function buyAllAmount(DSToken buy_gem, uint buy_amt, DSToken pay_gem, uint max_fill_amount) public;

  function sellAllAmount(DSToken pay_gem, uint pay_amt, DSToken buy_gem, uint min_fill_amount) public;
}

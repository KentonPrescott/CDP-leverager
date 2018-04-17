pragma solidity ^0.4.16;

import "./DSToken.sol";

interface IMatchingMarket {

  function buyAllAmount(DSToken buy_gem, uint buy_amt, DSToken pay_gem, uint max_fill_amount) public;

  function sellAllAmount(DSToken pay_gem, uint pay_amt, DSToken buy_gem, uint min_fill_amount) public;

  function getPayAmount(DSToken pay_gem, DSToken buy_gem, uint buy_amt) public constant returns (uint fill_amt);

  function getBuyAmount(DSToken buy_gem, DSToken pay_gem, uint pay_amt) public constant returns (uint fill_amt);

  function getBestOffer(DSToken sell_gem, DSToken buy_gem) public constant returns (uint);

  function getOffer(uint id) public constant returns (uint, DSToken, uint, DSToken);
}

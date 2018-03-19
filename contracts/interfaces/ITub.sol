pragma solidity ^0.4.16;

import "./ERC20.sol";
import "./DSValue.sol";
import "./ILiquidator.sol";

interface ITub {
    function sai() public view returns (ERC20);
    function skr() public view returns (ERC20);
    function gem() public view returns (ERC20);
    function pip() public view returns (DSValue);
    function tap() public view returns (ILiquidator);

    function open() public returns (bytes32 cup);
    function give(bytes32 cup, address guy) public;

    function gap() public view returns (uint);
    function per() public view returns (uint);

    function ask(uint wad) public view returns (uint);
    function bid(uint wad) public view returns (uint);

    function join(uint wad) public;
    function lock(bytes32 cup, uint wad) public;
    function free(bytes32 cup, uint wad) public;
    function draw(bytes32 cup, uint wad) public;
    function cage(uint fit_, uint jam) public;
}

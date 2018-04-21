pragma solidity ^0.4.16;

import "./ERC20.sol";
import "./DSValue.sol";
import "./DSToken.sol";
import "./ILiquidator.sol";

interface ITub {
    function sai() public view returns (DSToken);
    function skr() public view returns (DSToken);
    function gem() public view returns (DSToken);
    function pip() public view returns (DSValue);
    function pep() public view returns (DSValue);
    function gov() public view returns (DSToken);
    function fee() public view returns (uint256);
    function tax() public view returns (uint256);
    function axe() public view returns (uint256);

    function ink(bytes32 cup) public view returns (uint);
    function rap(bytes32 cup) public returns (uint);
    function tab(bytes32 cup) public returns (uint);
    function chi() public returns (uint);

    function open() public returns (bytes32 cup);
    function give(bytes32 cup, address guy) public;

    function gap() public view returns (uint);
    function per() public view returns (uint);

    function ask(uint wad) public view returns (uint);
    function bid(uint wad) public view returns (uint);

    function join(uint wad) public;
    function exit(uint wad) public;
    function lock(bytes32 cup, uint wad) public;
    function free(bytes32 cup, uint wad) public;
    function draw(bytes32 cup, uint wad) public;
    function wipe(bytes32 cup, uint wad) public;
    function cage(uint fit_, uint jam) public;
    function shut(bytes32 cup) public;
}

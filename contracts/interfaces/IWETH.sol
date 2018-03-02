pragma solidity ^0.4.16;

interface IWETH {
    function deposit() public payable;
    function withdraw(uint wad) public;
}

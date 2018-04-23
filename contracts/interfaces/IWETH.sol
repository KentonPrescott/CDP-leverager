pragma solidity ^0.4.19;

interface IWETH {
    function deposit() external payable;
    function withdraw(uint wad) external;
}

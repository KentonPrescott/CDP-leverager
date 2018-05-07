pragma solidity ^0.4.22;

interface IWETH {
    function deposit() external payable;
    function withdraw(uint wad) external;
}

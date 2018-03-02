pragma solidity ^0.4.16;

interface DSValue {
    function peek() public view returns (bytes32, bool);
    function read() public view returns (bytes32);
}

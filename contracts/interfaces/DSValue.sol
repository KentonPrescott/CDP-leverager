pragma solidity ^0.4.19;

interface DSValue {
    function peek() external view returns (bytes32, bool);
    function read() external view returns (bytes32);
}

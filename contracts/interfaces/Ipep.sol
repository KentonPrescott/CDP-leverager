pragma solidity ^0.4.16;

interface Ipep {
    function peek() public view returns (bytes32, bool);
}

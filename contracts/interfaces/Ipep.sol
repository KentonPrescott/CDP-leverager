pragma solidity ^0.4.19;

interface Ipep {
    function peek() external view returns (bytes32, bool);
}

pragma solidity ^0.4.22;

// https://github.com/dapphub/ds-value/blob/master/src/value.sol

interface DSValue {
    function peek() external view returns (bytes32, bool);
    function read() external view returns (bytes32);
}

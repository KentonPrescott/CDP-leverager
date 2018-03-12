pragma solidity ^0.4.16;

import "./IERC20.sol";

interface IBancorConverter {
    function quickConvert(IERC20[] _path, uint256 _amount, uint256 _minReturn) public returns (uint256);
}

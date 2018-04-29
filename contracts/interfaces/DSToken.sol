pragma solidity ^0.4.22;

// https://github.com/dapphub/ds-token/blob/master/src/token.sol

interface DSToken {
    function push(address dst, uint wad) external;
    function pull(address src, uint wad) external;

    //from ERC20
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

pragma solidity ^0.4.22;

import "./DSValue.sol";
import "./DSToken.sol";

// https://github.com/makerdao/sai/blob/master/src/tub.sol

interface ITub {
    function sai() external view returns (DSToken);
    function skr() external view returns (DSToken);
    function gem() external view returns (DSToken);
    function pip() external view returns (DSValue);
    function pep() external view returns (DSValue);
    function gov() external view returns (DSToken);
    function fee() external view returns (uint256);
    function tax() external view returns (uint256);
    function axe() external view returns (uint256);
    function mat() external view returns (uint256);

    function ink(bytes32 cup) external view returns (uint);
    function rap(bytes32 cup) external returns (uint);
    function tab(bytes32 cup) external returns (uint);
    function chi() external returns (uint);

    function open() external returns (bytes32 cup);
    function give(bytes32 cup, address guy) external;

    function gap() external view returns (uint);
    function per() external view returns (uint);

    function ask(uint wad) external view returns (uint);
    function bid(uint wad) external view returns (uint);

    function join(uint wad) external;
    function exit(uint wad) external;
    function lock(bytes32 cup, uint wad) external;
    function free(bytes32 cup, uint wad) external;
    function draw(bytes32 cup, uint wad) external;
    function wipe(bytes32 cup, uint wad) external;
    function cage(uint fit_, uint jam) external;
    function shut(bytes32 cup) external;
}

pragma solidity ^0.4.16;

import "./interfaces/ITub.sol";
import "./interfaces/ERC20.sol";
import "./interfaces/DSValue.sol";
import "./interfaces/DSToken.sol";
import "./DSMath.sol";

contract TestExchange is DSMath {
    ITub public tub;
    DSToken public peth;
    DSToken public dai;


    function TestExchange() public {
      address _tub = 0xa71937147b55Deb8a530C7229C442Fd3F31b7db2;
      tub = ITub(_tub);
      peth = tub.skr();
      dai = tub.sai();
      peth.approve(tub, 100000000000000000000000);
    }

    function() payable public {}

    function apprRequest() public {
      peth.approve(msg.sender, 100000000000000000000000);
      dai.approve(msg.sender, 100000000000000000000000);
    }

    function buyPeth(uint256 _dai, uint256 _currPrice) public payable {
      uint256 pethAmount = wdiv(_dai, _currPrice);

      peth.push(msg.sender, pethAmount);
      dai.pull(msg.sender, _dai);
    }

    function buyDai(uint256 _peth, uint256 _currPrice) public payable {
      uint256 daiAmount = wmul(_peth, _currPrice);  // _currPrice in wad, _peth in wad

      peth.pull(msg.sender, _peth); //To-Do: needs to be in wad
      dai.push(msg.sender, daiAmount); //To-Do: needs to be in wad
    }

    // for testing purposes
    function kill() public {
      selfdestruct(msg.sender);
    }
}

pragma solidity ^0.4.16;

import "./interfaces/ITub.sol";
import "./interfaces/ERC20.sol";
import "./interfaces/DSValue.sol";
import "./interfaces/IWETH.sol";
import "./DSMath.sol";

contract CDPOpener is DSMath {
    ITub public tub;
    ERC20 public weth;
    ERC20 public peth;
    ERC20 public dai;
    DSValue public pip;
    uint256 public makerLR;

    event OpenPosition(address owner, uint256 ethAmount, uint256 daiAmount, uint256 pethAmount);

    function CDPOpener() public {
      // this should be passed into constructor but that never seems to work ¯\_(ツ)_/¯
      address _tub = 0xa71937147b55Deb8a530C7229C442Fd3F31b7db2;
      tub = ITub(_tub);
      weth = tub.gem();
      peth = tub.skr();
      dai = tub.sai();
      pip = tub.pip();
      makerLR = 151;
      // we approve 100,000 weth/ peth
      weth.approve(tub, 100000000000000000000000);
      peth.approve(tub, 100000000000000000000000);
    }

    /* openPosition will:
       1. Get the market price of eth from maker's oracle
       2. Calculate the collateralization ratio needed to achieve the inputted price floor
       3. Wrap the sent eth
       4. Pool the wrapped eth
       5. Calculate the dai we need to draw out using the collatRatio
       6. Open a CDP
       7. Lock up all of our created peth
       8. Draw the amount dai calculated above
       9. Give the dai to the caller of this function
       10. Give the CDP to the caller of this function
       NOTE 406376 gas used in this functino in my first test
     */
    function openPosition(uint256 _priceFloor) payable public returns (bytes32 cdpId) {

        // 1000000000000000000 WAD = 1 normal unit (eg 1 dollar or 1 eth)

        uint256 currPrice = uint256(pip.read()); // In WAD

        // ensure that the price floor is less than the current price of eth
        require(_priceFloor < currPrice);

        // calculate collateralization ratio from price floor
        uint256 collatRatio = wdiv(wmul(currPrice, makerLR), wmul(_priceFloor, 100));

        IWETH(weth).deposit.value(msg.value)();      // wrap eth in weth token

        // calculate how much peth we need to enter with
        uint256 inverseAsk = rdiv(msg.value, wmul(tub.gap(), tub.per())) - 1;

        tub.join(inverseAsk);                      // convert weth to peth
        uint256 pethAmount = peth.balanceOf(this); // get the amt peth we created

        // calculate dai we need to draw in order to create the collat ratio we want
        uint256 daiAmount = wdiv(wmul(currPrice, inverseAsk), collatRatio);

        cdpId = tub.open();                        // create cdp in tub
        tub.lock(cdpId, pethAmount);               // lock peth into cdp
        tub.draw(cdpId, daiAmount);                // create dai from cdp

        dai.transfer(msg.sender, daiAmount);         // transfer dai to owner
        tub.give(cdpId, msg.sender);                 // transfer cdp to owner

        OpenPosition(msg.sender, msg.value, daiAmount, pethAmount);
    }
}

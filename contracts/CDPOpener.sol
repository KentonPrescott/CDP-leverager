pragma solidity ^0.4.16;

import "./interfaces/ITub.sol";
import "./interfaces/ERC20.sol";
import "./interfaces/DSValue.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IMatchingMarket.sol";
import "./DSMath.sol";

contract CDPOpener is DSMath {
    ITub public tub;
    DSToken public weth;
    DSToken public peth;
    DSToken public dai;
    DSValue public pip;
    uint256 public makerLR;
    uint256 public layers;
    ILiquidator public tap;
    IMatchingMarket public dex;

    struct Investor {
        uint layers;          // Number of CDP layers
        uint principal;       // Principal contribution in Eth
        uint256 collatRatio;     // Collaterazation ratio
        bytes32 cdpID;        // Array of cdpID
        uint daiAmountFinal;  // Amount of Dai that an investor has after leveraging
        uint ethAmountFinal;  // Resulting amount of ETH that an investor gets after liquidating
      }

    mapping (address => Investor) public investors;
    address[] public investorAddresses;


    event OpenPosition(address owner, uint256 ethAmount, uint256 daiAmount, uint256 pethAmount);

    function CDPOpener() public {
      // this should be passed into constructor but that never seems to work ¯\_(ツ)_/¯
      address _tub = 0xa71937147b55Deb8a530C7229C442Fd3F31b7db2;
      address _oasisDex = 0x8cf1Cab422A0b6b554077A361f8419cDf122a9F9;
      tub = ITub(_tub);
      weth = tub.gem();
      peth = tub.skr();
      dai = tub.sai();
      pip = tub.pip();
      tap = tub.tap();
      dex = IMatchingMarket(_oasisDex);

      makerLR = 151;
      layers = 3;

      // we approve tub, tap, and dex to access weth, peth, and dai contracts
      weth.approve(tub, 100000000000000000000000);
      weth.approve(dex, 100000000000000000000000);
      peth.approve(tub, 100000000000000000000000);
      peth.approve(tap, 100000000000000000000000);
      dai.approve(tap, 100000000000000000000000);
      dai.approve(dex, 100000000000000000000000);
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
       9. Exchange dai for peth
       10. Repeat steps 7-9 for # of (layers-1) prescribed
       11. Lock up all of our created peth
       12. Draw the amount dai
       13. Give the dai to the caller of this function
       14. Give the CDP to the caller of this function
       NOTE 406376 gas used in this functino in my first test
     */
    function openPosition(uint256 _priceFloor) payable public {

        // 1000000000000000000 WAD = 1 normal unit (eg 1 dollar or 1 eth)

        uint256 currPrice = uint256(pip.read()); // In WAD

        // ensure that the price floor is less than the current price of eth
        require(_priceFloor < currPrice);

        // calculate collateralization ratio from price floor
        uint256 collatRatio = wdiv(wmul(currPrice, makerLR), wmul(_priceFloor, 100));

        //Add information about investor to database
        Investor memory sender;
        investorAddresses.push(msg.sender);
        sender.layers = layers;
        sender.principal = msg.value;
        sender.collatRatio = collatRatio;

        IWETH(weth).deposit.value(msg.value)();       // wrap eth in weth token

        // calculate how much peth we need to enter with
        uint256 inverseAsk = rdiv(msg.value, wmul(tub.gap(), tub.per())) - 1;

        tub.join(inverseAsk);                        // convert weth to peth
        uint256 pethAmount = peth.balanceOf(this);   // get the amt peth we created

        // calculate dai we need to draw in order to create the collat ratio we want
        uint256 daiAmount = wdiv(wmul(currPrice, inverseAsk), collatRatio);

        sender.cdpID = tub.open();                // create cdp in tub
        tub.lock(sender.cdpID, pethAmount);                 // lock peth into cdp
        tub.draw(sender.cdpID, daiAmount);                  // create dai from cdp

        uint256 wethAmount;                          // initialize weth variable before loop
        //trade dai for peth and reinvest into cdp for # of layers
        for (uint256 i = 0; i < layers; i++) {

          //tap.bust(wdiv(daiAmount,currPrice));       // Liquidator: convert dai to peth by buying peth from forced cdps
          wethAmount = wdiv(daiAmount,currPrice);    // calculate how much weth to get at market rate
          dex.buyAllAmount(weth, wethAmount, dai, daiAmount); //OasisDEX: buy as much weth as possible.

          inverseAsk = rdiv(wethAmount, wmul(tub.gap(), tub.per())) - 1;  // look at declaration
          tub.join(inverseAsk);            // convert all weth to peth

          pethAmount = peth.balanceOf(this);         // retrieve peth balance
          tub.lock(sender.cdpID, pethAmount);               // lock peth balance into cdp

          daiAmount = wdiv(wmul(currPrice, inverseAsk), collatRatio);     // look at declaration
          tub.draw(sender.cdpID, daiAmount);                // create dai from cdp
        }

        dai.transfer(msg.sender, daiAmount);         // transfer dai to owner
        tub.give(sender.cdpID, msg.sender);                 // transfer cdp to owner

        sender.daiAmountFinal = daiAmount;           //record how much dai is required to back out position

        investors[msg.sender] = sender;

        OpenPosition(msg.sender, msg.value, daiAmount, pethAmount);
    }


    // Returns the variables contained in the Investor struct for a given address
   function getInvestorS(address _addr) public constant
     returns (
       uint _layers,
       uint principal,
       uint collatRatio,
       bytes32 cdpID,
       uint daiAmountFinal,
       uint ethAmountFinal
     )
   {
     Investor storage investor;
     investor = investors[_addr];
     return (investor.layers, investor.principal, investor.collatRatio, investor.cdpID, investor.daiAmountFinal, investor.ethAmountFinal);
   }

    //NOTE: TESTING PURPOSES ONLY
    function kill() public {
        selfdestruct(msg.sender);
    }
}

pragma solidity ^0.4.19;

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
    DSToken public gov;
    DSValue public pip;
    DSValue public pep;
    uint256 public makerLR;
    uint256 public layers;
    uint256 public fee;
    uint256 public tax;
    uint256 public axe;
    ILiquidator public tap;
    IMatchingMarket public dex;
    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;


    struct Investor {
        uint256 layers;          // Number of CDP layers. According to github schematic
        uint256 principal;       // Principal contribution in Eth
        uint256 collatRatio;     // Collaterazation ratio
        bytes32 cdpID;           // Array of cdpID
        uint256 purchPrice;      // currPrice at time of purchase
        uint256 daiAmountFinal;  // Amount of Dai that an investor has after leveraging
        uint256 ethAmountFinal;  // Resulting amount of ETH that an investor gets after liquidating
        uint256 totalDebt;       // total amount of debt (dai)
        uint256 priceFloor;      // price floor
        uint256 index;           // index of investor
    }

    mapping (address => Investor) public investors;
    address[] public investorAddresses;

    modifier onlyInvestor {
      require(investorAddresses.length != 0);
      require(investorAddresses[investors[msg.sender].index] == msg.sender);
      _;
    }


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
      pep = tub.pep();
      tap = tub.tap();
      gov = tub.gov();
      fee = tub.fee(); // MKR fee in RAY; To-Do: need to capture fee on time of leverage/liquidate
      tax = rpow(tub.tax(),31536000); // Stability fee in RAY. Maxed out at 5%
      axe = tub.axe(); // Liquidation penalty in RAY
      dex = IMatchingMarket(_oasisDex);

      makerLR = 150; // changed from 151 to 150 to help with liquidation logic
      layers = 3;

      // we approve tub, tap, and dex to access weth, peth, and dai contracts
      weth.approve(tub, 100000000000000000000000);
      weth.approve(dex, 100000000000000000000000);
      peth.approve(tub, 100000000000000000000000);
      peth.approve(tap, 100000000000000000000000);
      dai.approve(tub, 100000000000000000000000);
      dai.approve(tap, 100000000000000000000000);
      dai.approve(dex, 100000000000000000000000);
      gov.approve(tub, 100000000000000000000000);
      gov.approve(dex, 100000000000000000000000);
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
        // 5000000000000000 = 0.5%

        uint256 currPrice = uint256(pip.read()); // DAI/WETH In WAD
        uint256 currPriceMKR = uint256(pep.read()); // DAI/MKR in WAD

        // ensure that the price floor is less than the current price of eth
        require(_priceFloor < currPrice);

        // calculate collateralization ratio from price floor
        uint256 collatRatio = wdiv(wmul(currPrice, makerLR), wmul(_priceFloor, 100));

        //Add information about investor to database
        Investor memory sender;
        sender.index = investorAddresses.push(msg.sender) - 1;
        sender.layers = layers;
        sender.collatRatio = collatRatio;

        //this gets the best offer and minimizes chances of round off error when wiping dai.
        // TODO - elaborate on the following edge case: if delta is negative, || currPrice - purchPrice || is proportionate to chances of failure..
        // Actually, if currPrice is at all lower that purchPrice, then it may fail.
        // Failure sympton, it tries to wipe more dai than perscribed in a specific level
        uint256 wethAmt;
        uint256 daiAmt;
        (wethAmt, , daiAmt, ) = dex.getOffer(dex.getBestOffer(weth, dai));
        sender.purchPrice = wdiv(daiAmt,wethAmt);
        sender.priceFloor = _priceFloor;
        sender.principal = msg.value;


        IWETH(weth).deposit.value(msg.value)();       // wrap eth in weth token

        /* uint256 summation = 0; // used to find (Total debt - principal). doesn't take into account MKR fees..
        for (uint256 n = 1; n < sender.layers+1; n++) {
            summation = add(summation,wdiv(sender.principal,ray2wad(rpow(wad2ray(sender.collatRatio),n))));
        }

        uint256 mkrAmount = wdiv(wmul(wmul(summation,currPrice),ray2wad(fee)),currPriceMKR); // ((Total debt - principal) * govern fee) / (USD/MKR price)
        //uint256 mkrAmount = 340400000000000; // need to fix so about equation is correct and variable; note that sender.principal is assigned below this line
        uint256 wethAmount = wmul(mkrAmount,wdiv(currPriceMKR,currPrice));

        dex.buyAllAmount(gov, mkrAmount, weth, wethAmount); //OasisDEX: buy mkr with weth

        //reassign the principal = minus fees used to purchase mkr; this contract will accrue small amounts of MKR with usage
        sender.principal = sub(msg.value, wethAmount); */

        uint256 wethAmount;  // TODO: erase when mkr buy works

        // calculate how much peth we need to enter with
        uint256 inverseAsk = rdiv(sender.principal, wmul(tub.gap(), tub.per())) - 1;

        tub.join(inverseAsk);                        // convert weth to peth
        uint256 pethAmount = peth.balanceOf(this);   // get the amt peth we created

        // calculate dai we need to draw in order to create the collat ratio we want
        uint256 daiAmount = wdiv(wmul(currPrice, inverseAsk), collatRatio);

        sender.cdpID = tub.open();                // create cdp in tub
        tub.lock(sender.cdpID, pethAmount);                 // lock peth into cdp
        tub.draw(sender.cdpID, daiAmount);                  // create dai from cdp
        sender.totalDebt = add(sender.totalDebt,daiAmount);

        //trade dai for peth and reinvest into cdp for # of layers
        for (uint256 i = 0; i < sender.layers-1; i++) {

          //tap.bust(wdiv(daiAmount,currPrice));       // Liquidator: convert dai to peth by buying peth from forced cdps
          wethAmount = dex.getBuyAmount(weth, dai, daiAmount);    // calculate how much weth to get at market rate
          dex.buyAllAmount(weth, wethAmount, dai, wmul(daiAmount,1020000000000000000)); //OasisDEX: buy as much weth as possible.

          inverseAsk = rdiv(wethAmount, wmul(tub.gap(), tub.per())) - 1;  // look at declaration
          tub.join(inverseAsk);            // convert all weth to peth

          pethAmount = peth.balanceOf(this);         // retrieve peth balance
          tub.lock(sender.cdpID, pethAmount);               // lock peth balance into cdp

          daiAmount = wdiv(wmul(currPrice, inverseAsk), collatRatio);     // look at declaration
          tub.draw(sender.cdpID, daiAmount);                // create dai from cdp
          sender.totalDebt = add(sender.totalDebt,daiAmount);

        }
        //dai.transfer(msg.sender, daiAmount);                // transfer dai to owner
        //tub.give(sender.cdpID, msg.sender);                 // transfer cdp to owner
        sender.daiAmountFinal = daiAmount;           //record how much dai is required to back out position

        investors[msg.sender] = sender;

        OpenPosition(msg.sender, msg.value, daiAmount, pethAmount);
    }

    function liquidate() onlyInvestor public {

        uint256 currPrice = uint256(pip.read()); // DAI/WETH In WAD

        Investor memory sender = investors[msg.sender];

        uint256 releasedPeth;
        uint256 inverseAsk;
        uint256 payout;
        uint256 wethAmount;
        uint256 daiAmount = sender.daiAmountFinal;

        if (sender.priceFloor > currPrice) {
            //*** CDP is auto-liquidated                              ***//
            //*** Convert to WETH and send back to investor = 1 + 2   ***//
            //*** 1. Unlocked PETH in CDP                             ***//
            //*** 2. Outstanding DAI from final layer                 ***//

            releasedPeth = ray2wad(tub.ink(sender.cdpID)); // get unlocked PETH; convert from RAY to WAD
            tub.free(sender.cdpID, releasedPeth); //release the remaining peth
            tub.exit(releasedPeth);  //convert PETH to WETH

            wethAmount = wdiv(sender.daiAmountFinal,currPrice);
            dex.buyAllAmount(weth, wethAmount, dai, sender.daiAmountFinal);

            payout = add(releasedPeth,wethAmount); // weth from cdp + weth from remaining dai

        } else {

            // back out of the last layer of CDP onion
            tub.wipe(sender.cdpID, daiAmount);           //wipe off some debt by paying back some of the Dai Amount
            releasedPeth = wdiv(wmul(daiAmount,sender.collatRatio),sender.purchPrice);  // release the initial ammount of PETH

            tub.free(sender.cdpID, releasedPeth);  //release peth to this account
            tub.exit(releasedPeth);                //convert PETH to WETH

            if (sender.purchPrice > currPrice) { // TODO: consider if currPrice should actually be market rate of OasisDex
                //*** USD/ETH price deppreciated                                     ***//
                //*** Back out of CDP onion by using more WETH to pay off the debt.  ***//
                //*** Takes one extra layer to erase debt and empty PETH from cdp.   ***//

                uint remainingDebt = 0;
                uint256 extraPeth = 0;
                for (uint i = sender.layers; i > 0; i--) {
                     daiAmount = dex.getBuyAmount(dai, weth, releasedPeth);    // calculate how much dai you need to get Weth at market rate

                     if (i == 1) {
                         remainingDebt = ray2wad(rdiv(tub.tab(sender.cdpID),tub.chi()));  //converted to WAD
                         extraPeth = sub(releasedPeth,wdiv(remainingDebt,currPrice));     //calculate extra peth that is not used up in final wipe call
                         releasedPeth = wdiv(remainingDebt,currPrice);
                     }

                     dex.buyAllAmount(dai, daiAmount, weth, wmul(releasedPeth,1020000000000000000)); //OasisDEX: buy dai with weth

                     tub.wipe(sender.cdpID, daiAmount); //wipe off some of the the debt by paying back some of the Dai amount;

                     releasedPeth = wdiv(wmul(daiAmount,sender.collatRatio),sender.purchPrice);  // calculate amount of peth that can be freed based off initial purchPrice
                     // inverseAsk = rdiv(msg.value, wmul(tub.gap(), tub.per())) - 1;

                     tub.free(sender.cdpID, releasedPeth); //release peth to this account
                     tub.exit(releasedPeth);  //convert PETH to WETH
                }

                payout = add(releasedPeth,extraPeth);

            } else {
                //*** USD/ETH price appreciated                                              ***//
                //*** Back out of CDP onion by using less WETH to pay off the debt.          ***//
                //*** Send cumulative amount of extra weth left over each layer unwrapping   ***//
                uint256 intermediary;
                for (uint n = sender.layers-1; n > 0; n--) {
                     //calculate the amount of Dai necessary to unlock the amount of peth you need to keep the collat ratio
                     intermediary = ray2wad(rpow(wad2ray(sender.collatRatio),n));
                     daiAmount = wmul(wdiv(sender.principal,intermediary),sender.purchPrice);
                     wethAmount = dex.getPayAmount(weth,dai,daiAmount); // how much weth you need to buy necessary dai at the market rate

                     dex.buyAllAmount(dai, daiAmount, weth, wmul(wethAmount,1020000000000000000)); //OasisDEX: buy dai with weth
                     sender.ethAmountFinal = add(sender.ethAmountFinal,sub(releasedPeth,wethAmount)); //save the extra amount of peth

                     tub.wipe(sender.cdpID, daiAmount); //wipe off some of the the debt by paying back some of the Dai amount;

                     releasedPeth = wdiv(wmul(daiAmount,sender.collatRatio),sender.purchPrice);  // calculate amount of peth that can be freed based off initial purchPrice
                     // inverseAsk = rdiv(msg.value, wmul(tub.gap(), tub.per())) - 1;

                     //free about 1% less peth. this accounts for difference in OasisDex market buy price and Maker price feed
                     tub.free(sender.cdpID, wmul(releasedPeth,99000000000000000)); //release peth to this account
                     tub.exit(releasedPeth);  //convert PETH to WETH
                }

                payout = add(releasedPeth,sender.ethAmountFinal);

            }
        }

        IWETH(weth).withdraw(payout); //convert WETH to ETH
        tub.shut(sender.cdpID); //close down the cpds

        msg.sender.transfer(payout); //Send final ethAmount back to investor
        deleteEntity(msg.sender); //delete the sender information

    }

    // deletes investor's information from array and moves last index into place of deletion
    function deleteEntity(address entityAddress) internal returns (bool success) {
        uint rowToDelete = investors[entityAddress].index;
        address keyToMove = investorAddresses[investorAddresses.length-1];
        investorAddresses[rowToDelete] = keyToMove;
        investors[keyToMove].index = rowToDelete;
        investorAddresses.length--;
        return true;
    }

    // Returns the variables contained in the Investor struct for a given address
   function getInvestorS(address _addr) public constant
     returns (
       uint _layers,
       uint principal,
       uint collatRatio,
       bytes32 cdpID,
       uint256 purchPrice,
       uint daiAmountFinal,
       uint ethAmountFinal,
       uint256 totalDebt,
       uint256 priceFloor,
       uint256 index)
   {
     Investor memory investor = investors[_addr];
     return (investor.layers, investor.principal, investor.collatRatio, investor.cdpID, investor.purchPrice, investor.daiAmountFinal, investor.ethAmountFinal, investor.totalDebt, investor.priceFloor, investor.index);
   }

   function wad2ray(uint256 _wad) public returns (uint256) {
      return wmul(_wad,RAY);
   }

   function ray2wad(uint256 _ray) public returns (uint256) {
      return rmul(_ray,WAD);
   }

   //NOTE: TESTING PURPOSES ONLY
   function kill() public {
       selfdestruct(msg.sender);
   }
}

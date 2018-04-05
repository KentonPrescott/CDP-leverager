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
    DSToken public gov;
    DSValue public pip;
    DSValue public pep;
    uint256 public makerLR;
    uint256 public layers;
    uint256 public fee;
    ILiquidator public tap;
    IMatchingMarket public dex;

    struct Investor {
        uint256 layers;          // Number of CDP layers. According to github schematic
        uint256 principal;       // Principal contribution in Eth
        uint256 collatRatio;     // Collaterazation ratio
        bytes32 cdpID;           // Array of cdpID
        uint256 purchPrice;      // currPrice at time of purchase
        uint256 daiAmountFinal;  // Amount of Dai that an investor has after leveraging
        uint256 ethAmountFinal;  // Resulting amount of ETH that an investor gets after liquidating
        uint256 totalDebt;       //total amount of debt (dai)
    }

    mapping (address => Investor) public investors;
    address[] public investorAddresses;

    modifier onlyInvestor {
      require(investors[msg.sender].principal != 0);
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
      fee = tub.fee();
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
        investorAddresses.push(msg.sender);
        sender.layers = layers;
        sender.principal = msg.value;
        sender.collatRatio = collatRatio;
        sender.purchPrice = currPrice;

        IWETH(weth).deposit.value(msg.value)();       // wrap eth in weth token
        // calculating mkrAmount was troublesome uint256 mkrAmount = wdiv(wmul(wmul(add(wdiv(sender.principal,2),add(wdiv(sender.principal,4),wdiv(sender.principal,8))),currPrice),fee),currPriceMKR);
        uint256 mkrAmount = 340400000000000;
        uint256 wethAmount = wmul(mkrAmount,wdiv(currPriceMKR,currPrice));

        dex.buyAllAmount(gov, mkrAmount, weth, wethAmount); //OasisDEX: buy mkr with weth

        // calculate how much peth we need to enter with
        uint256 inverseAsk = rdiv(sub(msg.value, wethAmount), wmul(tub.gap(), tub.per())) - 1;

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
          wethAmount = wdiv(daiAmount,currPrice);    // calculate how much weth to get at market rate
          dex.buyAllAmount(weth, wethAmount, dai, daiAmount); //OasisDEX: buy as much weth as possible.

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

        uint256 currPrice = uint256(pip.read()); // In WAD

        Investor memory sender;
        sender = investors[msg.sender];

        uint256 releasedPeth;
        uint256 inverseAsk;
        uint256 payout;
        uint256 wethAmount;
        uint256 daiAmount = sender.daiAmountFinal;

        tub.wipe(sender.cdpID, daiAmount);           //wipe off some debt by paying back some of the Dai Amount
        releasedPeth = wdiv(wmul(daiAmount,sender.collatRatio),sender.purchPrice);  // release the initial ammount of PETH
        // inverseAsk = rdiv(msg.value, wmul(tub.gap(), tub.per())) - 1;

        tub.free(sender.cdpID, releasedPeth);  //release peth to this account
        tub.exit(releasedPeth);                //convert PETH to WETH

        // what you would do if your position appreciated
        for (uint i = sender.layers-1; i > 0; i--) {
             daiAmount = wmul(wdiv(sender.principal,(sender.collatRatio**i)),sender.purchPrice); //calculate the amount of Dai necessary to unlock the amount of peth you need to keep the collat ratio
             wethAmount = wdiv(daiAmount,currPrice); // how much weth you need to buy necessary dai

             dex.sellAllAmount(weth, wethAmount, dai, daiAmount); //OasisDEX: buy dai with weth
             sender.ethAmountFinal = add(sender.ethAmountFinal,sub(releasedPeth,wethAmount)); //save the extra amount of peth

             tub.wipe(sender.cdpID, daiAmount); //wipe off some of the the debt by paying back some of the Dai amount

             releasedPeth = wdiv(wmul(daiAmount,sender.collatRatio),sender.purchPrice);  // calculate amount of peth that can be freed based off initial purchPrice
             // inverseAsk = rdiv(msg.value, wmul(tub.gap(), tub.per())) - 1;

             tub.free(sender.cdpID, releasedPeth); //release peth to this account
             tub.exit(releasedPeth);  //convert PETH to WETH
        }

        payout = add(releasedPeth,sender.ethAmountFinal);

        IWETH(weth).withdraw(payout); //convert WETH to ETH
        tub.shut(sender.cdpID); //close down the cpds

        msg.sender.transfer(payout); //Send final ethAmount back to investor

        delete investors[msg.sender]; //delete the sender information 
        //TODO add delete function 

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
       uint256 totalDebt)
   {
     Investor storage investor;
     investor = investors[_addr];
     return (investor.layers, investor.principal, investor.collatRatio, investor.cdpID, investor.purchPrice, investor.daiAmountFinal, investor.ethAmountFinal, investor.totalDebt);
   }

    //NOTE: TESTING PURPOSES ONLY
    function kill() public {
        selfdestruct(msg.sender);
    }
}

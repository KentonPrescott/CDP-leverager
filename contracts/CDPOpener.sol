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
    uint256 public fee;
    uint256 public axe;
    IMatchingMarket public dex;
    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    struct Investor {
        uint256 layers;          // Number of CDP layers. According to github schematic
        uint256 principal;       // WAD - Principal contribution in Eth
        uint256 collatRatio;     // WAD - Collaterazation ratio
        bytes32 cdpID;           // Array of cdpID
        uint256 purchPrice;      // WAD; currPrice at time of purchase
        uint256 daiAmountFinal;  // WAD - Amount of Dai that an investor has after leveraging
        uint256 totalDebt;       // WAD - Total amount of debt (dai)
        uint256 priceFloor;      // WAD - Price floor
        uint256 index;           // index of investor
    }

    mapping (address => Investor) public investors;
    address[] public investorAddresses;

    modifier onlyInvestor {
      require(investorAddresses.length != 0, "Investor Array is empty");
      require(investorAddresses[investors[msg.sender].index] == msg.sender, "Investor has not opened a position yet");
      _;
    }

    event OpenPosition(address owner, uint256 principalEth, uint256 purchPrice, uint256 layers);
    event ClosePosition(address owner, uint256 sellPrice);

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
      gov = tub.gov();
      fee = tub.fee(); // MKR fee in RAY; To-Do: need to capture fee on time of leverage/liquidate
      //tax = rpow(tub.tax(),31536000); // Stability fee in RAY. Maxed out at 5%, but can be changed
      axe = tub.axe(); // Liquidation penalty in RAY
      dex = IMatchingMarket(_oasisDex);

      makerLR = ray2wad(tub.mat());

      // we approve tub, tap, and dex to access weth, peth, and dai contracts
      weth.approve(tub, 100000000000000000000000);
      weth.approve(dex, 100000000000000000000000);
      peth.approve(tub, 100000000000000000000000);
      dai.approve(tub, 100000000000000000000000);
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
    function leverage(uint256 _priceFloor, uint256 _layers) payable public {

        // 1000000000000000000 WAD = 1 normal unit (eg 1 dollar or 1 eth)
        // 5000000000000000 = 0.5%

        uint256 currPriceEth = uint256(pip.read());                                   // DAI/WETH In WAD
        uint256 currPricePeth = wmul(currPriceEth,wdiv(weth2peth(1*WAD),(1*WAD)));    // DAI/PETH In WAD

        // ensure that the price floor is less than the current price of eth
        require(_priceFloor < currPriceEth, "Price floor should not be less than the Dai/Eth price feed.");
        require(0 < msg.value, "Ether is required to open a position.");
        require(investors[msg.sender].principal == 0, "Previous position must be liquidated before opening a new one");

        // calculate collateralization ratio from price floor
        uint256 collatRatio = wdiv(wmul(currPriceEth, makerLR),_priceFloor);

        //find exchange rate for weth/Dai
        uint256 wethAmt;
        uint256 daiAmt;
        (wethAmt, , daiAmt, ) = dex.getOffer(dex.getBestOffer(weth, dai));


        //Add information about investor to database
        Investor memory sender;
        sender.index = investorAddresses.push(msg.sender) - 1;
        sender.layers = _layers;
        sender.collatRatio = collatRatio;
        sender.purchPrice = wdiv(daiAmt,wethAmt);
        sender.priceFloor = _priceFloor;
        sender.principal = msg.value;


        IWETH(weth).deposit.value(msg.value)();                              // wrap eth in weth token

        uint256 pethAmount = weth2peth(sender.principal);
        tub.join(pethAmount);                                                // convert weth to peth

        // calculate dai we need to draw in order to create the collat ratio we want
        uint256 daiAmount = wdiv(wmul(currPricePeth, pethAmount), collatRatio);
        uint256 wethAmount;

        sender.cdpID = tub.open();                                           // create cdp in tub
        tub.lock(sender.cdpID, pethAmount);                                  // lock peth into cdp
        tub.draw(sender.cdpID, daiAmount);                                   // create dai from cdp

        //trade dai for peth and reinvest into cdp for # of layers
        for (uint256 i = 0; i < sender.layers-1; i++) {
          wethAmount = marketBuy(weth, dai, daiAmount);

          pethAmount = weth2peth(wethAmount);

          tub.join(pethAmount);                                              // convert all weth to peth

          tub.lock(sender.cdpID, pethAmount);                                // lock peth balance into cdp

          daiAmount = wdiv(wmul(currPricePeth, pethAmount), collatRatio);    // look at declaration

          tub.draw(sender.cdpID, daiAmount);                                 // create dai from cdp


        }
        sender.daiAmountFinal = daiAmount;                                   // record how much dai is required to back out position
        sender.totalDebt = wdiv(tub.tab(sender.cdpID),ray2wad(tub.chi()));

        investors[msg.sender] = sender;

        OpenPosition(msg.sender, msg.value, sender.purchPrice, _layers);
    }

    function liquidate() payable onlyInvestor public {

        uint256 currPriceEth = uint256(pip.read());                          // DAI/WETH In WAD

        Investor memory sender = investors[msg.sender];

        uint256 releasedPeth;
        uint256 remainingPeth = tub.ink(sender.cdpID);                       // retrieve value of unlocked peth
        uint256 payout;
        uint256 wethAmount;
        uint256 daiAmount = sender.daiAmountFinal;


        if (tub.tab(sender.cdpID) == 0) {
            //*** CDP is auto-liquidated                              ***//
            //*** Convert to WETH and send back to investor = 1 + 2   ***//
            //*** 1. Unlocked PETH in CDP                             ***//
            //*** 2. Outstanding DAI from final layer                 ***//

            releaseWeth(sender.cdpID, remainingPeth);                        // release peth and convert to weth
            wethAmount = marketBuy(weth, dai, sender.daiAmountFinal);        // buy weth with remaining dai

            payout = add(remainingPeth,wethAmount);                          // weth from cdp + weth from remaining dai

        } else {

            require(0 < msg.value, "Ether is required to liqudiate.");
            //*** USD/ETH price deppreciated OR appreciated

            uint256 remainingDebt = sender.totalDebt;                        // WAD
            uint256 remainingDai;
            uint256 excessWeth;

            IWETH(weth).deposit.value(msg.value)();

            uint256 mkrFee;
            uint256 wethFee;
            (mkrFee, wethFee) = govFee(sender.cdpID, remainingDebt);

            require(wethFee<=msg.value, "Not enough ether provided for fees");      // verify that correct amount of weth is sent
            dex.buyAllAmount(gov, mkrFee, weth, wethFee);                           // OasisDEX: convert the remainingDai to weth
            excessWeth = sub(msg.value,wethFee);

            // back out of the last layer of CDP onion
            remainingDebt = wipeDebt(sender.cdpID, daiAmount, remainingDebt);       // wipe some dai and decrease remaining debt

            releasedPeth = wdiv(wmul(daiAmount,makerLR),sender.purchPrice);
            releaseWeth(sender.cdpID, releasedPeth);                                // release the initial ammount of PETH, convert to WETH
            remainingPeth -= releasedPeth;

            while (remainingDebt > 0) {
                 daiAmount = marketBuy(dai, weth, releasedPeth);

                 if (daiAmount > remainingDebt) {
                   remainingDai = sub(daiAmount,remainingDebt);                     // calculate left over dai
                   daiAmount = remainingDebt;
                 }

                 remainingDebt = wipeDebt(sender.cdpID, daiAmount, remainingDebt);  // wipe some dai and decrease remaining debt

                 releasedPeth = wdiv(wmul(daiAmount,makerLR),sender.priceFloor);    // calculate the max amount of peth that can be released

                 if (sub(remainingPeth,releasedPeth) < 5000000000000000) {
                    if (remainingDebt == 0) {
                        releasedPeth = remainingPeth;
                    } else {
                        releasedPeth = sub(remainingPeth,5100000000000000);
                        releaseWeth(sender.cdpID, releasedPeth);
                        break;
                    }
                 }
                 releaseWeth(sender.cdpID, releasedPeth);                    // release peth and convert to weth
                 remainingPeth -= releasedPeth;
            }

            uint256 finalPeth;
            if (sender.layers < 4) {
                finalPeth = tub.ink(sender.cdpID);                           // find remaining locked peth
                releaseWeth(sender.cdpID, finalPeth);                        // release remaining peth and convert to weth
            } else {
                finalPeth = 0;
            }


            wethAmount = marketBuy(weth, dai, remainingDai);                 // convert left over dai to weth

            payout = add(add(add(releasedPeth,wethAmount),finalPeth),excessWeth);


        }

        IWETH(weth).withdraw(payout);                                        // convert WETH to ETH
        tub.give(sender.cdpID, msg.sender);                                  // transfer cdp to owner

        msg.sender.transfer(payout);                                         // Send final ethAmount back to investor

        deleteEntity(msg.sender);                                            // delete the sender information

        ClosePosition(msg.sender, currPriceEth);                             // Note, current price may be off by as much as 2%

    }

    function marketBuy(DSToken _to, DSToken _from, uint256 _fromAmount) internal returns (uint256 toAmount) {
        toAmount = dex.getBuyAmount(_to, _from, _fromAmount);                // calculate how much of _to to get at market and with _fromAmount
        dex.buyAllAmount(_to, toAmount, _from, _fromAmount);                 // OasisDEX market buy
    }

    function releaseWeth(bytes32 _cdpID, uint256 _peth) internal {
        tub.free(_cdpID, _peth);                                             // empty all unlocked peth to this account
        tub.exit(_peth);                                                     // convert PETH to WETH
    }

    function wipeDebt(bytes32 _cdpID, uint256 _daiAmount, uint256 _remainingDebt) internal returns (uint256 remainingDebt) {
        tub.wipe(_cdpID, _daiAmount);                                        // wipe off some of the the debt by paying back some of the Dai amount
        remainingDebt = sub(_remainingDebt,_daiAmount);                                        // deduct from previous debt
    }

    function govFee(bytes32 _cdpID, uint256 _remainingDebt) internal returns (uint256 mkrFee, uint256 wethFee) {
        bytes32 val;
        (val, ) = pep.peek();                                                // maker price feed

        uint256 rate = rdiv(tub.rap(_cdpID), tub.tab(_cdpID));
        mkrFee = wdiv(rmul(_remainingDebt,rate),uint(val));
        wethFee = dex.getPayAmount(weth, gov, mkrFee);
    }

    function weth2peth(uint256 _wethAmount) public returns (uint pethAmount) {
        pethAmount = rdiv(_wethAmount, wmul(tub.gap(), tub.per())) - 1;       // WAD
    }


    // deletes investor's information from array and moves last index into place of deletion
    // does not delete with one investor
    function deleteEntity(address entityAddress) internal returns (bool success) {
        uint rowToDelete = investors[entityAddress].index;
        address keyToMove = investorAddresses[investorAddresses.length-1];
        investors[entityAddress].principal = 0;
        investorAddresses[rowToDelete] = keyToMove;
        investors[keyToMove].index = rowToDelete;
        investorAddresses.length--;
        return true;
    }


    // Returns the variables contained in the Investor struct for a given address
   function getInvestor(address _addr) public constant
     returns (
       uint _layers,
       uint principal,
       uint collatRatio,
       bytes32 cdpID,
       uint256 purchPrice,
       uint daiAmountFinal,
       uint256 totalDebt,
       uint256 priceFloor,
       uint256 index)
   {
     Investor memory investor = investors[_addr];
     return (investor.layers, investor.principal, investor.collatRatio, investor.cdpID, investor.purchPrice, investor.daiAmountFinal, investor.totalDebt, investor.priceFloor, investor.index);
   }

   function wad2ray(uint256 _wad) public returns (uint256) {
      return wmul(_wad,RAY);
   }

   function ray2wad(uint256 _ray) public returns (uint256) {
      return rmul(_ray,WAD);
   }

   function() payable public {}

   //NOTE: TESTING PURPOSES ONLY
   function kill() public {
       selfdestruct(msg.sender);
   }
}

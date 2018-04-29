pragma solidity ^0.4.22;

import "./interfaces/ITub.sol";
import "./interfaces/DSValue.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IMatchingMarket.sol";
import "./DSMath.sol";


/**
* CDP-Leverage is a tool to streamline the process of reinvesting in one CDP,
* allowing you to increase your USD/ETH leverage up to 3x.
*
* Please use caution, as the tool is still under development.
* More information on the tool, visit: https://github.com/KentonPrescott/CDP-leverager
* More information on Single Collateral Dai, visit: https://github.com/makerdao/sai
*/
contract CDPLeverage is DSMath {

    // Constants and modules set at contract inception
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

    // This Struct tracks position information for a specific investor address
    struct Investor {
        uint256 layers;          // Number of CDP layers. According to github schematic
        uint256 principalETH;       // WAD - principalETH contribution in Eth
        uint256 collatRatio;     // WAD - Collaterazation ratio
        bytes32 cdpID;           // cdpID
        uint256 daiAmountFinal;  // WAD - Amount of Dai that an investor has after leveraging
        uint256 drawnDai;        // WAD - Total amount of DAI drawn
        uint256 priceFloor;      // WAD - Price floor in ETH
        uint256 index;           // index of investor
        uint256 purchPrice;      // WAD; currPrice at time of purchase
    }
    mapping (address => Investor) public investors;
    address[] public investorAddresses;


    // Modifiers
    modifier onlyInvestor {
        require(investorAddresses.length != 0, "Investor Array is empty");
        require(investorAddresses[investors[msg.sender].index] == msg.sender, "Investor has not opened a position yet");
        _;
    }


    // Events
    event OpenPosition(address owner, uint256 principalETH, uint256 purchPrice, uint256 layers);
    event ClosePosition(address owner, uint256 sellPrice);


    /**
    * @dev Constructor function
    * Collects module information from the tub and matchingMarket (OasisDex)contracts
    */
    constructor()
        public
    {
        address _tub = 0xa71937147b55Deb8a530C7229C442Fd3F31b7db2;         //Kovan
        address _oasisDex = 0x8cf1Cab422A0b6b554077A361f8419cDf122a9F9;    //Kovan
        tub = ITub(_tub);
        weth = tub.gem();
        peth = tub.skr();
        dai = tub.sai();
        pip = tub.pip();
        pep = tub.pep();
        gov = tub.gov();
        fee = tub.fee();
        axe = tub.axe();
        dex = IMatchingMarket(_oasisDex);

        makerLR = ray2wad(tub.mat());

        // we approve tub, tap, and dex to access weth, peth, and dai contracts
        weth.approve(tub, uint(-1));
        weth.approve(dex, uint(-1));
        peth.approve(tub, uint(-1));
        dai.approve(tub, uint(-1));
        dai.approve(dex, uint(-1));
        gov.approve(tub, uint(-1));
        gov.approve(dex, uint(-1));
    }


    // Fallback function
    function() payable public {}


    /**
    * @dev Leverage - Creates a leveraged long USD/ETH position
    * principalETH (message value) of sender is used to:
    * 1. Open CDP
    * 2. Lock PETH into a CDP
    * 3. Draw DAI and trade for WETH on OasisDEX
    * 4. Convert WETH to PETH
    * 5. Repeat steps 2 - 4 for # of (layers-1) prescribed
    * 6. Holds CDP ownership and remaining DAI
    * @param _priceFloorETH - position liquidated if USD/ETH price drops below this point
    * @param _layers - # of layers used to leverage
    */
    function leverage(uint256 _priceFloorETH, uint256 _layers)
        payable
        public
    {
        uint256 currPriceEth = uint256(pip.read());                                   // DAI/WETH In WAD
        uint256 currPricePeth = wmul(currPriceEth,wdiv(weth2peth(1*WAD),(1*WAD)));    // DAI/PETH In WAD

        // ensure that the price floor is less than the current price of eth
        require(_priceFloorETH < currPriceEth, "Price floor should not be less than the Dai/Eth price feed.");
        require(0 < msg.value, "Ether is required to open a position.");
        require(investors[msg.sender].principalETH == 0, "Previous position must be liquidated before opening a new one");

        // calculate collateralization ratio from price floor
        uint256 collatRatio = wdiv(wmul(currPriceEth, makerLR),_priceFloorETH);

        //Add information about investor to database
        Investor memory sender;
        sender.index = investorAddresses.push(msg.sender) - 1;
        sender.principalETH = msg.value;
        sender.layers = _layers;
        sender.collatRatio = collatRatio;
        sender.priceFloor = _priceFloorETH;
        sender.purchPrice = estimatePurchPrice(
            sender.principalETH,
            sender.collatRatio,
            sender.layers
        );

        uint256 wethAmount;
        uint256 pethAmount;
        uint256 daiAmount;

        IWETH(weth).deposit.value(msg.value)();
        sender.cdpID = tub.open();

        (daiAmount, pethAmount) = joinLockDraw(
            sender.cdpID,
            sender.principalETH,
            currPricePeth,
            sender.collatRatio
        );

        //trade DAI for PETH and reinvest into CDP for # of layers
        for (uint256 i = 0; i < sender.layers - 1; i++) {
            wethAmount = marketBuy(weth, dai, daiAmount);
            (daiAmount, pethAmount) = joinLockDraw(
                sender.cdpID,
                wethAmount,
                currPricePeth,
                sender.collatRatio
            );

        }

        sender.daiAmountFinal = daiAmount;
        sender.drawnDai = wdiv(tub.tab(sender.cdpID),ray2wad(tub.chi()));

        investors[msg.sender] = sender;

        emit OpenPosition(msg.sender, msg.value, sender.purchPrice, _layers);
    }


    /**
    * @dev Liquidate - Liquidates the sender's position and returns ETH
    * Possible outcomes:
    * 1. USD/ETH drops below sender's price floor
    * 2. USD/ETH appreciates relative to sender's purchase price
    * 3. USD/ETH deppreciates relative to sender's purchase price
    * Sender must send ETH with function call to cover the governance and stability fee with use of the Maker platform
    * Any excess ETH will be returned with the closing of the position
    */
    function liquidate()
        payable
        onlyInvestor
        public
    {
        uint256 currPriceEth = uint256(pip.read());                          // DAI/WETH In WAD

        Investor memory sender = investors[msg.sender];

        uint256 releasedPeth;
        uint256 remainingPeth = tub.ink(sender.cdpID);                       // retrieve value of collatoral in CDP
        uint256 payout;
        uint256 wethAmount;
        uint256 daiAmount = sender.daiAmountFinal;

        // checks if CDP debt is 0
        if (tub.tab(sender.cdpID) == 0) {
            //*** CDP is auto-liquidated
            //*** Convert to WETH and send back to investor = 1 + 2
            //*** 1. Remaining PETH in debt-free CDP
            //*** 2. Outstanding DAI from final layer

            releaseWeth(sender.cdpID, remainingPeth);
            wethAmount = marketBuy(weth, dai, sender.daiAmountFinal);
            payout = add(remainingPeth,wethAmount);

        } else {

            //*** USD/ETH price deppreciated OR appreciated

            require(0 < msg.value, "Ether is required to liqudiate.");

            uint256 remainingDebt = sender.drawnDai;
            uint256 excessDai;
            uint256 excessWeth;

            // Pay for governance fee
            uint256 wethFee = payFee(sender.cdpID, remainingDebt);
            excessWeth = sub(msg.value,wethFee);

            // wipe last layer of cdp
            remainingDebt = wipeDebt(sender.cdpID, daiAmount, remainingDebt);
            releasedPeth = wdiv(wmul(daiAmount,makerLR),sender.purchPrice);
            releaseWeth(sender.cdpID, releasedPeth);
            remainingPeth -= releasedPeth;

            // empty remaining debt or reach dust pan condition (CDP peth = 0.0051), whichever comes first
            while (remainingDebt > 0) {
                (releasedPeth, remainingPeth, remainingDebt, excessDai) = unravelCDP(
                    releasedPeth,
                    remainingPeth,
                    remainingDebt,
                    sender.cdpID,
                    sender.priceFloor
                );
            }
            finalPeth = releaseFinalPeth(
                sender,cdpID,
                remainingDebt,
                remainingPeth
            );


            // convert left over dai to weth
            wethAmount = marketBuy(weth, dai, excessDai);

            payout = add(add(add(releasedPeth,wethAmount),finalPeth),excessWeth);
        }

        // convert WETH to ETH
        IWETH(weth).withdraw(payout);

        // give cdp to owner
        // if dustpan condition hit, cdp will have 0.0051 peth left
        tub.give(sender.cdpID, msg.sender);

        msg.sender.transfer(payout);

        // delete the sender pointer from investorAddresses array
        deleteEntity(msg.sender);

        emit ClosePosition(msg.sender, currPriceEth);

    }


    /**
    * @dev Transfers CDP ownership to investor
    */
    function transferCDPOwnership()
        onlyInvestor
        public
    {
        tub.give(investors[msg.sender].cdpID,msg.sender);
        investors[msg.sender].principalETH = 0;
    }

    /**
    * @dev Add funds to an existing CDP to increase its collateralization ratio
    */
    function addFunds()
        onlyInvestor
        payable
        public
    {
        require(0 < msg.value, "Funds need to be sent with transaction");

        Investor memory sender = investors[msg.sender];
        uint256 currPriceEth = uint256(pip.read());
        uint256 currPricePeth = wmul(currPriceEth,wdiv(weth2peth(1*WAD),(1*WAD)));

        IWETH(weth).deposit.value(msg.value)();
        uint256 pethAmount = weth2peth(msg.value);
        tub.join(pethAmount);
        tub.lock(sender.cdpID, pethAmount);

        uint256 totalPeth = tub.ink(sender.cdpID);

        sender.principalETH += msg.value;
        sender.collatRatio = wdiv(wmul(totalPeth,currPricePeth),sender.drawnDai);
        sender.priceFloor = wdiv(wmul(currPriceEth,makerLR),sender.collatRatio);

        investors[msg.sender] = sender;


    }


    /**
    * @dev Returns amount of PETH for a given amount of WETH at exchange rate
    * @param _wethAmount - literal
    */
    function weth2peth(uint256 _wethAmount)
        view
        public
        returns (uint pethAmount)
    {
        pethAmount = rdiv(_wethAmount, wmul(tub.gap(), tub.per())) - 1;      // WAD
    }


    /**
    * @dev Updates the state varuabkes that reflect Maker's risk parameters
    */
    function updateVars()
        public
        returns (bool success)
    {
        weth = tub.gem();
        peth = tub.skr();
        dai = tub.sai();
        pip = tub.pip();
        pep = tub.pep();
        gov = tub.gov();
        fee = tub.fee();
        axe = tub.axe();
        makerLR = ray2wad(tub.mat());

        return true;
    }


    /**
    * @dev Returns the average USD/ETH price on OasisDex
    * @param _principalETH - initial investment
    * @param _CR - Collateralization ratio
    * @param _layers - reinvestment layers
    */
    function estimatePurchPrice(uint256 _principalETH, uint256 _CR, uint256 _layers)
        view
        internal
        returns (uint256 purchPrice)
    {
        uint256 totalWethBought = 0;
        for (uint256 n = 1; n < _layers; n++) {
           totalWethBought = add(totalWethBought,wdiv(_principalETH,wpow(_CR,n)));
        }

        uint256 daiAmount = dex.getPayAmount(dai, weth, totalWethBought);
        purchPrice = wdiv(daiAmount,totalWethBought);
    }


    function joinLockDraw(
        bytes32 _cdpID,
        uint256 _wethAmount,
        uint256 _currPricePeth,
        uint256 _collatRatio)
        internal
        returns (uint256 daiAmount, uint256 pethAmount)
    {
        pethAmount = weth2peth(_wethAmount);
        tub.join(pethAmount);
        tub.lock(_cdpID, pethAmount);

        daiAmount = wdiv(wmul(_currPricePeth, pethAmount), _collatRatio);
        tub.draw(_cdpID, daiAmount);
    }

    /**
    * @dev Executes a market buy order and returns the amount of asset recieved
    * @param _buying - token buying
    * @param _selling - token selling
    * @param _sellingAmount - amount of token selling
    */
    function marketBuy(DSToken _buying, DSToken _selling, uint256 _sellingAmount)
        internal
        returns (uint256 buyingAmount)
    {
        buyingAmount = dex.getBuyAmount(_buying, _selling, _sellingAmount);                // calculate how much of _buying to get at market and with _sellingAmount
        dex.buyAllAmount(_buying, buyingAmount, _selling, _sellingAmount);                 // OasisDEX market buy
    }

    function unravelCDP(
        uint256 _releasedPeth,
        uint256 _remainingPeth,
        uint256 _remainingDebt,
        bytes32 _cdpID,
        uint256 _priceFloorETH)
        internal
        returns (
            uint256 releasedPeth,
            uint256 remainingPeth,
            uint256 remainingDebt,
            uint256 excessDai)
    {
        uint256 daiAmount = marketBuy(dai, weth, _releasedPeth);

        (daiAmount, excessDai) = zeroDebtCondition(
            daiAmount,
            _remainingDebt
        );

        remainingDebt = wipeDebt(_cdpID, daiAmount, _remainingDebt);
        releasedPeth = wdiv(wmul(daiAmount,makerLR),weth2peth(_priceFloorETH);

        (releasedPeth, remainingPeth) = dustPanCondition(
            releasedPeth,
            _remainingPeth,
            remainingDebt,
            _cdpID
        );

        releaseWeth(sender.cdpID, releasedPeth);
        remainingPeth -= releasedPeth;

    }

    function zeroDebtCondition(uint256 _daiAmount, uint256 _remainingDebt)
        internal
        returns (uint256 daiAmount, uint256 excessDai)
    {
        if (_daiAmount > _remainingDebt) {
            excessDai = sub(_daiAmount,_remainingDebt);
            daiAmount = _remainingDebt;
        }
    }


    function dustPanCondition(
        uint256 _releasedPeth,
        uint256 _remainingPeth,
        uint256 _remainingDebt,
        bytes32 _cdpID)
        internal
        returns (uint256 releasedPeth, uint256 remainingPeth)
    {

        // dust pan condition, where remainingPeth cannot be below 0.005 peth
        if (sub(_remainingPeth,_releasedPeth) < 5000000000000000) {
            if (_remainingDebt == 0) {
                releasedPeth = _remainingPeth;
            } else {
                releasedPeth = sub(_remainingPeth,5000000010000000);
                releaseWeth(_cdpID, releasedPeth);
                remainingPeth = 5000000010000000;
                break;
            }
        } else {
            releasedPeth = _releasedPeth;
            remainingPeth = _remainingPeth;
        }


    }


    /**
    * @dev Free's locked CDP collateral (PETH) and converts it to WETH
    * @param _cdpID - verbatim
    * @param _peth - amount of peth
    */
    function releaseFinalPeth(
        bytes32 _cdpID,
        uint256 _remainingDebt,
        uint256 _remainingPeth)
        internal
        returns (uint256 finalPeth)
    {
        if (_remainingDebt == 0 && _remainingPeth != 0) {
            finalPeth = tub.ink(_cdpID);
            releaseWeth(_cdpID, finalPeth);
        } else {
            finalPeth = 0;
        }
    }


    /**
    * @dev Free's locked CDP collateral (PETH) and converts it to WETH
    * @param _cdpID - verbatim
    * @param _peth - amount of peth
    */
    function releaseWeth(bytes32 _cdpID, uint256 _peth)
        internal
    {
        tub.free(_cdpID, _peth);                                             // empty all unlocked peth to this account
        tub.exit(_peth);                                                     // convert PETH to WETH
    }


    /**
    * @dev Decreases CDP debt by wiping DAI and returns the remaining debt
    * @param _cdpID - verbatim
    * @param _daiAmount - verbatim
    * @param _remainingDebt - in DAI
    */
    function wipeDebt(bytes32 _cdpID, uint256 _daiAmount, uint256 _remainingDebt)
        internal
        returns (uint256 remainingDebt)
    {
        tub.wipe(_cdpID, _daiAmount);                                        // wipe off some of the the debt by paying back some of the Dai amount
        remainingDebt = sub(_remainingDebt,_daiAmount);                      // deduct from previous debt
    }


    /**
    * @dev Calculates the governance and stability fee (in DAI) in terms of weth and mkr at the given market rate
    * @param _cdpID - verbatim
    * @param _remainingDebt - in DAI
    */
    function payFee(bytes32 _cdpID, uint256 _remainingDebt)
        internal
        returns (uint256 wethFee)
    {
        IWETH(weth).deposit.value(msg.value)();
        uint256 mkrUSDPrice = uint256(pep.read());                           // maker price feed

        uint256 rate = rdiv(tub.rap(_cdpID), tub.tab(_cdpID));
        uint256 mkrFee = wmul(1100000000000000000,wdiv(rmul(_remainingDebt,rate),mkrUSDPrice));
        wethFee = dex.getPayAmount(weth, gov, mkrFee);

        require(wethFee <= msg.value, "Not enough ether provided for fees");
        dex.buyAllAmount(gov, mkrFee, weth, wethFee);
    }


    /**
    * @dev Deletes investor's information from array and moves last index into place of deletion
    * May not delete with one investor
    * @param _entityAddress - verbatim
    */
    function deleteEntity(address _entityAddress)
        internal
        returns (bool success)
    {
        uint rowToDelete = investors[_entityAddress].index;
        address keyToMove = investorAddresses[investorAddresses.length-1];
        investors[_entityAddress].principalETH = 0;
        investorAddresses[rowToDelete] = keyToMove;
        investors[keyToMove].index = rowToDelete;
        investorAddresses.length--;
        return true;
    }


    /**
    * @dev WAD to RAY conversion
    * @param _wad - 10**18
    */
    function wad2ray(uint256 _wad)
        pure
        internal
        returns (uint256)
    {
        return wmul(_wad,RAY);
    }


    /**
    * @dev RAY to WAD conversion
    * @param _ray - 10**27
    */
    function ray2wad(uint256 _ray)
        pure
        internal
        returns (uint256)
    {
        return rmul(_ray,WAD);
    }


   //NOTE: TESTING PURPOSES ONLY
    function kill()
        public
    {
        selfdestruct(msg.sender);
    }


}

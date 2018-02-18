pragma solidity ^0.4.16;

import "./SafeMath.sol";
import "./Interface/ICDPContract.sol";
import "./Interface/IDaiContract.sol";
import "./Interface/IwethContract.sol";
import "./Interface/IpethContract.sol";
import "./Interface/IMKRContract.sol";


//To-Do: be sure to complete the ETH_Address authorization
contract Ethleverage {
  using SafeMath for uint;

  //events
  event LogCDPAddressChanged(address oldAddress, address newAddress);
  event LogDaiAddressChanged(address oldAddress, address newAddress);

  //Variables
  struct Investor {
    uint layers;        // number of layers down
    uint prinContr;     // principle contribution in Eth
    uint CR;            // collatorization ratio
    bytes32 cdps;     //array of CDPs (only one!)
    uint daiAmountFinal;  //amount of Dai that an investor has after leveraging
    uint ethAmountFinal; //resulting amount of ETH that an investor gets after liquidating
  }

  mapping (address => Investor) public investors;
  address[] public investorAddresses;

  address public owner;

  address public CDPContract;
  address public DaiContract;
  address public wethContract;
  address public pethContract;
  address public MKRContract;

  uint public makerLR;
  uint public ethCap = 10000;
  uint public layers = 3;


  //Modifiers
  modifier onlyOwner {
    require(msg.sender == owner);
      _;
  }

  modifier onlyInvestor {
    require(investors[msg.sender].prinContr != 0);
    _;
  }

  //Functions
  function Ethleverage(
    address _CDPaddr,
    address _Daiaddr,
    address _wethaddr,
    address _pethaddr,
    address _mkrContract,
    uint _liquidationRatio
  ) public {
    owner = msg.sender;
    CDPContract = _CDPaddr;
    DaiContract = _Daiaddr;
    wethContract = _wethaddr;
    pethContract = _pethaddr;
    MKRContract = _mkrContract;
    makerLR = _liquidationRatio;

    ICDPContract(CDPContract).approve(address(this));

    IwethContract(wethContract).approve(CDPContract, ethCap);
    IpethContract(pethContract).approve(CDPContract, ethCap);
    IDaiContract(DaiContract).approve(CDPContract, ethCap);
    IMKRContract(MKRContract).approve(CDPContract, ethCap);

    IwethContract(wethContract).approve(address(this), ethCap);
    IpethContract(pethContract).approve(address(this), ethCap);


  }


  // for email contract reference: https://github.com/makerdao/sai/blob/master/src/tub.sol
  // for workflow reference: https://docs.google.com/document/d/1_7pvv49dYJHIlMkaEqBgLOz77F-dt_BImKWRS2ZtFcE/mobilebasic

  /* Workflow
  1. Convert ETH into WETH,
  2. Convert WETH into PETH,
  3. Open CDP
  4. Deposit PETH into CDP,
  5. Withdraw DAI,
  6. Purchase WETH with DAI via decentralized exchange
  7. Convert WETH into PETH
  */

  function leverage(uint256 _ethMarketPrice, uint256 _priceFloor) payable public returns (bool sufficient) {
    //TO-DO: w/ price floor or leverage ratio, determine the number of layers and LR
    uint256  calcCR = (_ethMarketPrice.mul(makerLR)).div(_priceFloor);


    Investor memory sender;
    sender = investors[msg.sender];
    investorAddresses.push(msg.sender);

    sender.layers = layers;
    sender.prinContr = msg.value;
    sender.CR = calcCR;

    uint recycledPeth;
    recycledPeth = sender.prinContr;

    // Step 3. Open CDPContract
    bytes32 CDPInfo = ICDPContract(CDPContract).open();
    sender.cdps = CDPInfo;

    // 1. convert eth into WETH
    //just in case the MakeGuy was wrong: wethContract.transfer(recycledPeth);
    IwethContract(wethContract).transfer(recycledPeth);
    uint DaiAmount = _priceFloor.div(makerLR);

    for (uint i = 0; i < sender.layers; i++) {
        // 2a. Convert WETH into PETH
        ICDPContract(CDPContract).join(recycledPeth);
        //just in case the MakeGuy was wrong: pethContract.approve(address(this), recycledPeth);

         // 4. deposit PETH into CDP
        ICDPContract(CDPContract).lock(sender.cdps, recycledPeth);

         // 5. withdraw DAI
        ICDPContract(CDPContract).draw(sender.cdps, DaiAmount); // may need to use liquidation ratio in this!

        //6. trade DAI for weth
        //OasisMarket.sellAllAmount(DaiContract, DaiAmount, WethContract, min_fill_amount)
        //recycledPeth = wethReceived

        //Assign the last DaiAmount recieved in the loop
        sender.daiAmountFinal = DaiAmount;

        DaiAmount = (recycledPeth.mul(_ethMarketPrice)).div(sender.CR);

      }

    return true;
   }


   function liquidate() onlyInvestor public returns (bool sufficient) {

     Investor memory sender;
     sender = investors[msg.sender];
		 uint DaiAmount;
		 uint releasedPeth;

     //assign the final dai amount to the amount of dai that must be iterated
     DaiAmount = sender.daiAmountFinal;

     //1. wipe off some of the the debt by paying back some of the Dai amount
     ICDPContract(CDPContract).wipe(sender.cdps, DaiAmount);


     for (uint i = 0; i < sender.layers; i++) {

       //2. free up some of the collatoral (PETH) because some of the debt has been wiped
       releasedPeth = DaiAmount.mul(sender.CR);
       ICDPContract(CDPContract).free(sender.cdps, releasedPeth);

       //3. convert PETH to WETH
       ICDPContract(CDPContract).exit(releasedPeth);

       //4. trade some ethereum for DAI
       //DaiAmount = OasisMarket.buyAllAmount(ERC20 buy_gem, uint buy_amt, ERC20 pay_gem, uint max_fill_amount)


       //5. wipe off some of the the debt by paying back some of the Dai amount
       ICDPContract(CDPContract).wipe(sender.cdps, DaiAmount);
     }

     //6. take out the remaining peth
     releasedPeth = DaiAmount.mul(sender.CR);
     ICDPContract(CDPContract).free(sender.cdps, releasedPeth);

     //convert PETH to WETH
     ICDPContract(CDPContract).exit(releasedPeth);

     //convert WETH to ETH

     //close down the cpds
     ICDPContract(CDPContract).shut(sender.cdps);

     //calculate the final eth amount that is recieved from the last wipe off
     sender.ethAmountFinal = (sender.CR).mul(DaiAmount);

     //Send final ethAmount back to investor
     msg.sender.transfer(sender.ethAmountFinal);
		
     //delete the sender information
		 delete investors[msg.sender];

     return true;
   }

   // Returns the variables contained in the Investor struct for a given address
  function getInvestor(address _addr) constant public
    returns (
      uint _layers,
      uint prinContr,
      uint CR,
      bytes32 cdps,
      uint daiAmountFinal,
      uint ethAmountFinal
    )
  {
    Investor storage investor = investors[_addr];
    return (investor.layers, investor.prinContr, investor.CR, investor.cdps, investor.daiAmountFinal, investor.ethAmountFinal);
  }

    // Update the address of the makerDAO CDP contract
   function setCdpContract(address _addr) onlyOwner public returns (bool success) {
    require(_addr != address(0));
    address old = CDPContract;
    CDPContract = _addr;
    LogCDPAddressChanged(old, _addr);
    return true;
   }

   function setDaiContract(address _addr) onlyOwner public returns (bool success) {
     require(_addr != address(0));
     address old = DaiContract;
     DaiContract = _addr;
     LogDaiAddressChanged(old, _addr);
     return true;
    }
}

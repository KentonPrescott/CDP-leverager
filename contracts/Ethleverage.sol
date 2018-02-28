pragma solidity ^0.4.16;

import "./SafeMath.sol";
import "./Interface/ICDPContract.sol";
import "./Interface/IDaiContract.sol";
import "./Interface/IwethContract.sol";
import "./Interface/IpethContract.sol";
import "./Interface/IMKRContract.sol";
import "./Interface/IMoneyMaker.sol";
import "./Interface/ILiquidator.sol";


//To-Do: be sure to complete the ETH_Address authorization
contract Ethleverage {
  using SafeMath for uint;

  // Events
  event CDPOpened(bytes32 ID);
  event PethLocked(bytes32 ID, uint recycledPeth);
  event DaiToPeth(uint recycledPeth);

  event LogCDPAddressChanged(address oldAddress, address newAddress);
  event LogDaiAddressChanged(address oldAddress, address newAddress);

  // Variables
  struct Investor {
    uint layers;          // Number of CDP layers
    uint principal;       // Principal contribution in Eth
    uint collatRatio;     // Collaterazation ratio
    bytes32 cdpID;        // Array of cdpID (only one!)
    uint daiAmountFinal;  // Amount of Dai that an investor has after leveraging
    uint ethAmountFinal;  // Resulting amount of ETH that an investor gets after liquidating
  }

  mapping (address => Investor) public investors;
  address[] public investorAddresses;

  address public owner;

  address public CDPContract;
  address public DaiContract;
  address public wethContract;
  address public pethContract;
  address public MKRContract;
	address public moneyMakerKovan = 0xd87856163f409777df41DDFBF37A66369E028FA9;
  address public liquidKovan =  0xc936749D2D0139174EE0271bD28325074fdBC654; //https://github.com/makerdao/sai/blob/4b0c94b8ef2d8e0951dd0a0eee7c0fce5f5dbb49/src/tap.sol
  address public unknownContract = 0xc936749D2D0139174EE0271bD28325074fdBC654; //https://kovan.etherscan.io/address/0xc936749d2d0139174ee0271bd28325074fdbc654

  uint public makerLR;
  uint public ethCap = 10000;
  uint public layers = 3;


  //Modifiers
  modifier onlyOwner {
    require(msg.sender == owner);
      _;
  }

  modifier onlyInvestor {
    require(investors[msg.sender].principal != 0);
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
  }

	function initialize() public {
      //for some reason the variables ARE initialized in the constructor function, but an error is thrown without reassigning them here.
      owner = msg.sender;
      moneyMakerKovan = 0xd87856163f409777df41DDFBF37A66369E028FA9;
      liquidKovan =  0xc936749D2D0139174EE0271bD28325074fdBC654; //https://github.com/makerdao/sai/blob/4b0c94b8ef2d8e0951dd0a0eee7c0fce5f5dbb49/src/tap.sol
      unknownContract = 0xc936749D2D0139174EE0271bD28325074fdBC654; //https://kovan.etherscan.io/address/0xc936749d2d0139174ee0271bd28325074fdbc654
      makerLR = 151;
      ethCap = 10000;
      layers = 3;
      DaiContract = 0xC4375B7De8af5a38a93548eb8453a498222C4fF2;
      CDPContract = 0xa71937147b55Deb8a530C7229C442Fd3F31b7db2;
      wethContract = 0xd0A1E359811322d97991E03f863a0C30C2cF029C;
      pethContract = 0xf4d791139cE033Ad35DB2B2201435fAd668B1b64;
      MKRContract = 0xAaF64BFCC32d0F15873a02163e7E500671a4ffcD;

    
			IwethContract(wethContract).approve(CDPContract, ethCap);
      IwethContract(wethContract).approve(unknownContract, ethCap);
			IpethContract(pethContract).approve(CDPContract, ethCap);
      IpethContract(pethContract).approve(unknownContract, ethCap);
			IDaiContract(DaiContract).approve(CDPContract, ethCap);
      IDaiContract(DaiContract).approve(unknownContract, ethCap);
			IMKRContract(MKRContract).approve(CDPContract, ethCap);
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
    uint256  calcCR = (_ethMarketPrice.mul(makerLR)).div(_priceFloor.mul(100));

    //investor assignments
    Investor memory sender;
    sender = investors[msg.sender];
    investorAddresses.push(msg.sender);
    sender.layers = layers;
    sender.principal = msg.value;
    sender.collatRatio = calcCR;

    //external calls
    ICDPContract tub = ICDPContract(CDPContract);
    IwethContract weth = IwethContract(wethContract);

    uint recycledPeth;
    recycledPeth = sender.principal;

    // Step 3. Open CDPContract
    bytes32 CDPInfo = tub.open();
    sender.cdpID = CDPInfo;
    CDPOpened(CDPInfo); //event

    // 1. convert eth into WETH
    //just in case the MakeGuy was wrong: wethContract.transfer(recycledPeth);
    weth.deposit.value(recycledPeth)();
    uint DaiAmount = (_priceFloor.div(makerLR)).mul(100);

    for (uint i = 0; i < sender.layers; i++) {
        // 2a. Convert WETH into PETH
        tub.join(recycledPeth);

         // 4. deposit PETH into CDP
        tub.lock(sender.cdpID, recycledPeth);
        PethLocked(CDPInfo, recycledPeth); //event

         // 5. withdraw DAI
        tub.draw(sender.cdpID, DaiAmount); // may need to use liquidation ratio in this!

        //6. buy weth, sell dai
				//recycledPeth = IMoneyMaker(moneyMakerKovan).buyAllEthWithDai().div(1e18); //on mainNet
        ILiquidator(liquidKovan).bust(DaiAmount); //for Kovan use only (NOTE: will not work if Total Liquidity Available is 0)
        recycledPeth = DaiAmount.div(_ethMarketPrice);
        DaiToPeth(recycledPeth); //event

        //Assign the last DaiAmount recieved in the loop
        sender.daiAmountFinal = DaiAmount;

        DaiAmount = (recycledPeth.mul(_ethMarketPrice)).div(sender.collatRatio);
      }

    return true;
   }

   function transferOwnership(address _destination) onlyInvestor public returns (bool success) {
     ICDPContract(CDPContract).give(investors[msg.sender].cdpID, _destination);
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
     ICDPContract(CDPContract).wipe(sender.cdpID, DaiAmount);


     for (uint i = 0; i < sender.layers; i++) {

       //2. free up some of the collatoral (PETH) because some of the debt has been wiped
       releasedPeth = DaiAmount.mul(sender.collatRatio);
       ICDPContract(CDPContract).free(sender.cdpID, releasedPeth);

       //3. convert PETH to WETH
       ICDPContract(CDPContract).exit(releasedPeth);

       //4. trade some ethereum for DAI
       DaiAmount = IMoneyMaker(moneyMakerKovan).sellAllEthForDai();

       //5. wipe off some of the the debt by paying back some of the Dai amount
       ICDPContract(CDPContract).wipe(sender.cdpID, DaiAmount);
     }

     //6. take out the remaining peth
     releasedPeth = DaiAmount.mul(sender.collatRatio);
     ICDPContract(CDPContract).free(sender.cdpID, releasedPeth);

     //convert PETH to WETH
     ICDPContract(CDPContract).exit(releasedPeth);

     //convert WETH to ETH

     //close down the cpds
     ICDPContract(CDPContract).shut(sender.cdpID);

     //calculate the final eth amount that is recieved from the last wipe off
     sender.ethAmountFinal = (sender.collatRatio).mul(DaiAmount);

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
      uint principal,
      uint collatRatio,
      bytes32 cdpID,
      uint daiAmountFinal,
      uint ethAmountFinal
    )
  {
    Investor storage investor = investors[_addr];
    return (investor.layers, investor.principal, investor.collatRatio, investor.cdpID, investor.daiAmountFinal, investor.ethAmountFinal);
  }

  // For testing purposes only!!!
  function getVariables() constant public
    returns (address, address, address, address, address, address, address, address, address, uint, uint, uint)
    {
      return (
        owner,
        CDPContract,
        DaiContract,
        wethContract,
        pethContract,
        MKRContract,
        moneyMakerKovan,
        liquidKovan,
        unknownContract,
        makerLR,
        ethCap,
        layers);
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

    //TO-DO: TESTING PURPOSES ONLY
    function kill() public {
        selfdestruct(0xf0E90739550992Fcf37fe4DCB0b47708ca0ff609);
    }
}

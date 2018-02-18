pragma solidity ^0.4.18;

import "./ICDPContract.sol";
import "./IDaiContract.sol";
import "./IwethContract.sol";
import "./IpethContract.sol";
import "./IMKRContract.sol";
import "./SafeMath.sol";


//To-Do: be sure to complete the ETH_Address authorization
contract Ethleverage {
	using SafeMath for uint;

	//events
	event LogCDPAddressChanged(address oldAddress, address newAddress);
	event LogDaiAddressChanged(address oldAddress, address newAddress);

	//Variables
	struct Investor {
		uint layers;				// number of layers down
		uint prinContr;			// principle contribution in Eth
		uint CR; 						// collatorization ratio
		bytes32[] CDPs;			//array of CDPs
	}

	mapping (address => Investor) public investors;
	address[] public investorAddresses;

	address public CDPContract;
	address public DaiContract;
	address public wethContract;
	address public pethContract;
	address public MKRContract;
	address public owner;
	uint public makerLR;
	uint public ethCap = 10000;


	//Modifiers
	modifier onlyOwner {
		require(msg.sender == owner);
			_;
	}

	//Functions
	function Ethleverage(address _CDPaddr, address _Daiaddr, address _wethaddr, address _pethaddr address _mkrContract, uint _liquidationRatio) public {
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
	function leverage(uint _ethMarketPrice, uint _priceFloor) payable public returns (bool sufficient) {
		//TO-DO: w/ price floor or leverage ratio, determine the number of layers and LR
		uint calcCR = (_ethMarketPrice.mul(makerLR)).div(_priceFloor);
		uint layers = 4;


		Investor memory sender;
		sender = investors[msg.sender];
		investorAddresses.push(msg.sender);

		sender.layers = layers;
		sender.prinContr = msg.value;
		sender.CR = calcCR;

		uint recycledPeth;
		recycledPeth = sender.prinContr;

		// 1. convert eth into WETH
		//just in case the MakeGuy was wrong: wethContract.transfer(recycledPeth);
		IwethContract(wethContract).send(recycledPeth);
		uint DaiAmount = _priceFloor.div(makerLR);

		for (uint i = 0; i < layers; i++) {
				// 2a. Convert WETH into PETH
				ICDPContract(CDPContract).join(recycledPeth);
				//just in case the MakeGuy was wrong: pethContract.approve(address(this), recycledPeth);

				// Step 3. Open CDPContract and put CDP info to array
				bytes32 CDPInfo = ICDPContract(CDPContract).open();
				sender.cdps[i] = CDPInfo;

				 // 4. deposit PETH into CDP
				ICDPContract(CDPContract).lock(sender.cdps[i], recycledPeth);

				 // 5. withdraw DAI
				ICDPContract(CDPContract).draw(sender.cdps[i], DaiAmount); // may need to use liquidation ratio in this!

				//6. trade DAI for weth
				//OasisMarket.sellAllAmount(DaiContract, DaiAmount, WethContract, min_fill_amount)

				//To-Do: Dia 7.
				//recycledPeth = wethReceived
				DaiAmount = (recycledPeth.mul(_ethMarketPrice)).div(sender.CR);

			}

		return true;
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

pragma solidity ^0.4.18;

//To-Do: be sure to complete the ETH_Address authorization
contract Ethleverage {

	//events
	event LogCDPAddressChanged(address oldAddress, address newAddress);

	//Variables
	struct Investor {
		uint layers;				// number of layers down
		uint prinContr;			// principle contribution in Eth
		uint LR; 						// liquidation ratio
		bytes32[] cdps;			//array of CDPs
	}

	mapping (address => Investor) public investors;
	address[] public investorAddresses;
	address public CDPContract;
	address public DaiContract
	address public owner;
	uint public eth2Wei = 1e18;


	//Modifiers
	modifier onlyOwner {
		require(msg.sender == owner);
			_;
	}

	//Functions
	function Ethleverage(address _CDPaddr, address _Daiaddr) public {
		owner = msg.sender;
		CDPContract = _CDPaddr;
		DaiContract = _Daiaddr;
	}

	function leverage(uint _pricefloorORLeverage) payable public returns (bool sufficient) {
		//TO-DO: w/ price floor or leverage ratio, determine the number of layers and LR


		Investor memory sender = investors[msg.sender];
		investorAddresses.push(sender);
		sender.layers = 1; //production = calcLayers; test = 1

		sender.prinContr = msg.value;
		sender.LR = calcLR;

		recycledEth = sender.prinContr;
		// for email contract reference: https://github.com/makerdao/sai/blob/master/src/tub.sol
		for (uint i = 0; i < calcLayers; i++) {
					// take out a CDPContract
					sender.cdps.push(CDPContract.open());
					CDPContract.lock(sender.cdps[i], recycledEth*eth2Wei); //TO-DO: need to check the amount of wad sent!
					// TO-DO: still need to transfer ownership
					CDPContract.draw(sender.cdps[i], recycledEth*eth2Wei);

					success = DaiContract.transfer()
					//recycledEth =

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




}

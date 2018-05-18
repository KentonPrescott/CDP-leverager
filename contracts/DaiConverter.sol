pragma solidity ^0.4.18;

import "./interfaces/IERC20.sol";
import "./interfaces/IBancorConverter.sol";

contract DaiConverter {
  IERC20 public dai;
  IERC20 public bancorToken;
  IERC20 public bancorErc20Eth;
  IERC20 public bancorDaiSmartTokenRelay;
  IERC20[] public daiToEthConversionPath;
  IBancorConverter public bancorConverter;


  function DaiConverter() public {
    dai = IERC20(0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359);
    bancorDaiSmartTokenRelay = IERC20(0xee01b3AB5F6728adc137Be101d99c678938E6E72);
    bancorToken = IERC20(0x1F573D6Fb3F13d689FF844B4cE37794d79a7FF1C);
    bancorErc20Eth = IERC20(0xc0829421C1d260BD3cB3E0F06cfE2D52db2cE315);
    bancorConverter = IBancorConverter(0x578f3c8454F316293DBd31D8C7806050F3B3E2D8);
    daiToEthConversionPath = [
        dai,
        bancorDaiSmartTokenRelay,
        bancorDaiSmartTokenRelay,
        bancorDaiSmartTokenRelay,
        bancorToken,
        bancorToken,
        bancorErc20Eth
    ];
    // we approve 100,000,000 dai for quick convert
    dai.approve(bancorConverter, 100000000000000000000000000);
  }

  // fallback function so that we can accept the eth coming in from bancor
  function() public payable { }

  /*
    _amountDai -> dai in WAD
    _minReturn -> eth in WAD
    1000000000000000000 WAD = 1 ETH or Dai
    NOTE: We must give this contract dai approval before calling this function
    NOTE: w/o the call to transfer, this method used 422852 gas
  */
  function sellDaiForEth(uint256 _amountDai, uint256 _minReturn) public returns (uint256) {

      // convert dai to eth
      uint256 resultingEth = bancorConverter.quickConvert(daiToEthConversionPath, _amountDai, _minReturn);

      address caller = msg.sender;
      // send the eth back to the caller
      caller.transfer(resultingEth);
  }
}

pragma solidity ^0.4.16;

interface IMaker {
    function sai() public view returns (ERC20);
    function skr() public view returns (ERC20);
    function gem() public view returns (ERC20);
    function pip() public view returns (DSValue);

    function open() public returns (bytes32 cup);
    function give(bytes32 cup, address guy) public;

    function gap() public view returns (uint);
    function per() public view returns (uint);

    function ask(uint wad) public view returns (uint);
    function bid(uint wad) public view returns (uint);

    function join(uint wad) public;
    function lock(bytes32 cup, uint wad) public;
    function free(bytes32 cup, uint wad) public;
    function draw(bytes32 cup, uint wad) public;
    function cage(uint fit_, uint jam) public;
}

interface ERC20 {
    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    function allowance(address owner, address spender) public view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public returns (bool);
    function approve(address spender, uint256 value) public returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface DSValue {
    function peek() public view returns (bytes32, bool);
    function read() public view returns (bytes32);
}

interface IWETH {
    function deposit() public payable;
    function withdraw(uint wad) public;
}

interface ILiquidator {
  function bust(uint wad) public;
}

contract DSMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }
    function max(uint x, uint y) internal pure returns (uint z) {
        return x >= y ? x : y;
    }
    function imin(int x, int y) internal pure returns (int z) {
        return x <= y ? x : y;
    }
    function imax(int x, int y) internal pure returns (int z) {
        return x >= y ? x : y;
    }

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }
    function wdiv(uint x, uint y) public pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
    function rdiv(uint x, uint y) public pure returns (uint z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    // This famous algorithm is called "exponentiation by squaring"
    // and calculates x^n with x as fixed-point and n as regular unsigned.
    //
    // It's O(log n), instead of O(n) for naive repeated multiplication.
    //
    // These facts are why it works:
    //
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
    //
    function rpow(uint x, uint n) internal pure returns (uint z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }
}

contract Ethleverage is DSMath {
    IMaker public tub;
    ERC20 public weth;
    ERC20 public peth;
    ERC20 public dai;
    address public tap;
    DSValue public pip;
    uint256 public currPrice;
    uint256 public inverseAsk;
    uint256 public pethAmount;
    uint256 public collatRatio;
    uint256 public makerLR;
    uint256 public daiAmount;
    ILiquidator public liquidator;

    event MakeDai(address caller, uint256 ethAmount, uint256 daiAmount, uint256 pethAmount);

    function Ethleverage() public {
      address _tub = 0xa71937147b55Deb8a530C7229C442Fd3F31b7db2;
      tub = IMaker(_tub);
      weth = tub.gem();
      peth = tub.skr();
      dai = tub.sai();
      pip = tub.pip();
      /* tap = tub.tap(); */
      /* liquidator = ILiquidator(tap); */
      makerLR = 151;
      weth.approve(tub, 10000000000000000000000);
      peth.approve(tub, 10000000000000000000000);
      /* CR = wdiv(wmul(currPrice, makerLR), wmul(500000000000000000000, 100)); */
    }


    function openPosition(uint256 _priceFloor) payable public returns (bytes32 cdpId) {
        // 1000000000000000000 WAD = 1 normal unit (eg $ or eth)
        currPrice = uint256(pip.read()); // In WAD
        collatRatio = wdiv(wmul(currPrice, makerLR), wmul(_priceFloor, 100));


        IWETH(weth).deposit.value(msg.value)();      // wrap eth in weth token
        // 10 dai in wei units 10000000000000000000

        // calculate how much peth we need to enter with
        inverseAsk = rdiv(msg.value, wmul(tub.gap(), tub.per())) - 1;
        // calculate dai we need to draw to create the collat ratio that corresponds to the given price floor
        daiAmount = wdiv(wmul(currPrice, inverseAsk), collatRatio);

        tub.join(inverseAsk);                      // convert weth to peth
        pethAmount = peth.balanceOf(this);

        cdpId = tub.open();                        // create cdp in tub
        tub.lock(cdpId, pethAmount);               // lock peth into cdp
        tub.draw(cdpId, daiAmount);                // create dai from cdp

        /* liquidator.bust(daiAmount); */

        dai.transfer(msg.sender, daiAmount);           // transfer dai to owner
        tub.give(cdpId, msg.sender);                 // transfer cdp to owner

        MakeDai(msg.sender, msg.value, daiAmount, pethAmount);
    }
}

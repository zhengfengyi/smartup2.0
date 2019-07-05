pragma solidity >=0.4.21 <0.6.0;


import "./SafeMath.sol";
import "./Ownable.sol";
import "./ERC20.sol";
import "./CT.sol";
//import "./ExchangeStore.sol";


interface storeInterface {
    function tokenBalance(address ctAddress, address owner)external returns(uint256);
    function addTokenBalance(address token, address owner, uint256 amount)external;
    function subTokenBalance(address token, address owner, uint256 amount)external;
    function transferToken(address token, address to, uint256 amount)external;

}

interface CtMarket {
    function finishFirstPeriod()external;
}

contract ExchangeImpl is Ownable{
    using SafeMath for uint256;
    address public exchangeStore;
    address public exchangeProxy;
    address public sutAddress;
    uint256 constant DECIMALS = 10 ** 18;

    storeInterface store;


    constructor(address _store, address _impl, address _owner)public Ownable(_owner){
        exchangeStore = _store;
        exchangeProxy = exchangeProxy;
        store = storeInterface(_store);

    }

    modifier onlyProxy{
        require(msg.sender == exchangeProxy);
        _;
    }

    function _depositSut(uint256 sutAmount)public onlyProxy{
        store.addTokenBalance(sutAddress, msg.sender, sutAmount);
    }

    function _firstBuyCt(address _ctAddress, address _buyer, uint256 ctAmount)public onlyProxy{
        //require(!CT(_ctAddress).dissolved());
        require(CT(_ctAddress).isInFirstPeriod());
        require(store.tokenBalance(_ctAddress,address(store)) >= ctAmount);

        uint256 paySut = CT(_ctAddress).rate().mul(ctAmount).div(DECIMALS);
        require(store.tokenBalance(sutAddress,_buyer) >= paySut);
        
        store.addTokenBalance(_ctAddress, _buyer, ctAmount);
        store.subTokenBalance(_ctAddress, address(store), ctAmount);

        store.addTokenBalance(sutAddress, address(store), paySut);
        store.subTokenBalance(sutAddress, _buyer, paySut);

        if (store.tokenBalance(sutAddress,address(store)) == 0) {
            CtMarket(_ctAddress).finishFirstPeriod();
        }

    }

    function _exchangCt()


}
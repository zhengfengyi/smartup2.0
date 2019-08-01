pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";
import "./IterableSet.sol";
import "./CTstore.sol";

contract CTimpl is Ownable {
    using IterableSet for IterableSet.AddressSet;

    IterableSet.AddressSet private cts;
    address public sutImpl;
    address public exStore;
    address public sutStore;


    constructor (address _sutImpl, address _owner, address _exStore, address _sutStore)public Ownable(_owner){
        sutImpl = _sutImpl;
        exStore = _exStore;
        sutStore = _sutStore;
    }

    modifier onlySutImpl(){
        require(msg.sender == sutImpl);
        _;
    }

    modifier onlyExchange(){
        require(msg.sender == exStore);
        _;
    }

    function setImpl(address _sutImpl)public onlyOwner {
        sutImpl = _sutImpl;
    }

    function setExchange(address _exchange)public onlyOwner{
        exStore = _exchange;
    }


    function newCtMarket(address owner, address creator, string calldata _name, string calldata _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 _closingTime)external onlySutImpl returns(address ctAddress){

        CTstore ct = new CTstore(owner, creator, address(this), sutStore, exStore, _name,_symbol,_supply,_rate, _lastRate, _closingTime);

        ctAddress = address(ct);
    }


    function addCt(address _ctAddress)public onlySutImpl {
        cts.add(_ctAddress);
    }

    function setCtStoreImpl(address ctAddress, address impl)public onlyOwner {
        CTstore ctstore = CTstore(ctAddress);

        ctstore.setImpl(impl);

    }

    function changeAllctImpl(address impl)public onlyOwner {
        address[] memory ctMarkets = cts.list();

        for(uint256 i = 0; i < ctMarkets.length; i++){
            CTstore(ctMarkets[i]).setImpl(impl);
        }
    }

    function buyct(address _ctAddress, address _holder)public onlyExchange {
        CTstore ct = CTstore(_ctAddress);
        ct.addHolder(_holder);
        ct.addMember(_holder);
    }

    function removeCtHolder(address _ctAddress, address _holder)public onlyExchange{
        CTstore(_ctAddress).removeHolder(_holder);
    }

    function finishFirstPeriod(address _ctAddress)public onlyExchange{
        CTstore(_ctAddress).setFirstPeriod(false);
    }

    function trunDissolved(address _ctAddress)public onlySutImpl {
        CTstore(_ctAddress).setDissvoled(true);
    }


    

}
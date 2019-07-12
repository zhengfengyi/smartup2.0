pragma solidity >=0.4.21 <0.6.0;

import "./CT.sol";


contract CreateCtMarket is Ownable{
    address public implAddress;
    //address public calcSutAddress;
    address public exStore;
    address public storeAddress;
 

    constructor(address _store, address _implAddress, address _exStore)public Ownable(msg.sender) {
        storeAddress = _store;
        implAddress = _implAddress;
        exStore = _exStore;
    }

    modifier onlyImpl(){
        require(msg.sender == implAddress);
        _;
    }

    function setImplAddress(address _implAddress)public onlyOwner{
        implAddress = _implAddress;    
    }

    // function setCalcSut(address _calcsut)public onlyOwner{
    //     calcSutAddress = _calcsut;
    // }
    
    function setSutStore(address _exStore)public onlyOwner{
        exStore = _exStore;
    }


    function newCtMarket(address owner, address creator, string calldata _name, string calldata _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate)external onlyImpl returns(address ctAddress){

        CT ct = new CT(owner, creator, storeAddress, address(this), exStore, _name,_symbol,_supply,_rate, _lastRate);

        ctAddress = address(ct);
    }

    // function dissolve(address ctAddress)external onlyImpl returns(bool success){
    //     success = CT(ctAddress).dissolve();
    // }

    function trunDissolved(address ctAddress)external onlyImpl{
        CT(ctAddress).setDissolved();
    }

    function finishCtFirstPeriod(address ctAddress)external onlyImpl{
        CT(ctAddress).finishFirstPeriod();
    }

    function addHolder(address ctAddress, address holder)external onlyImpl{
        CT(ctAddress)._addHolder(holder);
    }

 function removeHolder(address ctAddress, address holder)external onlyImpl{
        CT(ctAddress)._removeHolder(holder);
    }


}
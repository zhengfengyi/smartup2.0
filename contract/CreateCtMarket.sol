pragma solidity >=0.4.21 <0.6.0;

import "./CT.sol";

interface ExSetAllowed {
    function setAllowed(address allowed, bool _isAllowed)external;
}

contract CreateCtMarket is Ownable{
    address public implAddress;
    //address public calcSutAddress;
    address public exStore;
    address public storeAddress;
    address public exImpl;

    constructor(address _store, address _implAddress, address _exStore, address _exImpl)public Ownable(msg.sender) {
        storeAddress = _store;
        implAddress = _implAddress;
        exStore = _exStore;
        exImpl = _exImpl;
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
    
    // function setSutStore(address _store)public onlyOwner{
    //     storeAddress = _store;
    // }


    function newCtMarket(address owner, address creator)external onlyImpl returns(address ctAddress){

        CT ct = new CT(owner, creator, storeAddress, exStore, exImpl, address(this));

        ctAddress = address(ct);

        ExSetAllowed(exStore).setAllowed(ctAddress, true);
    }

    function dissolve(address ctAddress)external onlyImpl returns(bool success){
        success = CT(ctAddress).dissolve();
    }

    function trunDissolved(address ctAddress)external onlyImpl{
        CT(ctAddress).setDissolved();
    }


}
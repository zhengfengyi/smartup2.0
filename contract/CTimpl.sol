pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";
import "./CTstore.sol";

contract CTimpl is Ownable {
    using IterableSet for IterableSet.AddressSet;

    IterableSet.AddressSet private cts;
    address public sutImpl;
    address public exStore;
    address public sutStore;
    address public proAddress;


    constructor (address _owner, address _sutStore, address _proposal)public Ownable(_owner){
        sutStore = _sutStore;
        proAddress = _proposal;
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

    function setProposal(address _proposal) public onlyOwner {
        proAddress = _proposal;
    }

    function newCtMarket(address creator, string calldata _name, string calldata _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 _closingTime)external onlySutImpl returns(address ctAddress){

        CTstore ct = new CTstore(creator, address(this), sutStore, exStore, _name, _symbol, _supply, _rate, _lastRate, _closingTime, proAddress);

        ctAddress = address(ct);
    }


    function addCt(address _ctAddress)public onlySutImpl {
        cts.add(_ctAddress);
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

    function addAdmin(address _ctAddress, address _buyer) public onlyExchange {
        CTstore(_ctAddress)._addAdmin(_buyer);
        
    }

    function deleteAdmin(address _ctAddress, address _seller) public onlyExchange {
        CTstore(_ctAddress)._deleteAdmin(_seller);
    }

    function trunDissolved(address _ctAddress)public onlySutImpl {
        CTstore(_ctAddress).setDissvoled(true);
    }

    function setUpgradeMarket(address _ctAddress, address _newAddress) public onlyExchange {
        CTstore(_ctAddress).startMigration(_newAddress);
    }

    function setCtMigrateFrom(address _ctAddress, address _from) public onlyExchange {
        CTstore(_ctAddress).setMigrateFrom(_from);

    }

}
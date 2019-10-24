pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";
import "./CTstore.sol";

contract CTimpl is Ownable {
    using IterableSet for IterableSet.AddressSet;

    IterableSet.AddressSet private cts;
    address public sutImpl;
    address public exchange;
    address public coinStore;
    address public sutStore;
    address public proAddress;
    address public marketOperation;   


    constructor (address _owner, address _sutStore, address _exchange, address _proposal, address _opration)public Ownable(_owner){
        sutStore = _sutStore;
        proAddress = _proposal;
        marketOperation = _opration;
        exchange = _exchange;
    }

    modifier onlySutImpl(){
        require(msg.sender == sutImpl);
        _;
    }

    modifier onlyExchange(){
        require(msg.sender == exchange);
        _;
    }

    function setImpl(address _sutImpl)public onlyOwner {
        sutImpl = _sutImpl;
    }

    function setCoinStore(address _coinstore)public onlyOwner{
        coinStore = _coinstore;
    }

    function setProposal(address _proposal) public onlyOwner {
        proAddress = _proposal;
    }

    function setOpration(address _opration) public onlyOwner {
        marketOperation = _opration;
    }

    function newCtMarket(address creator, string calldata _name, string calldata _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 _closingTime)external onlySutImpl returns(address ctAddress){

        CTstore ct = new CTstore(creator, address(this), sutStore, exchange, _name, _symbol, _supply, _rate, _lastRate, _closingTime,proAddress);

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

    function trunDissolvedByNotSellOut(address _ctAddress) public onlySutImpl {
        CTstore(_ctAddress).notSellOutDissvoled();
    }

    function setUpgradeMarket(address _ctAddress, address _newAddress) public  {
        require(msg.sender == marketOperation);
        CTstore(_ctAddress).startMigration(_newAddress);
    }

    function setCtMigrateFrom(address _ctAddress, address _from) public {
        require(msg.sender == marketOperation);
        CTstore(_ctAddress).setMigrateFrom(_from);

    }

    function requestRecycleRate(address _ctAddress, address applicant, uint256 rate, uint256 concludeFee) external {
        require(msg.sender == marketOperation);
        CTstore(_ctAddress).requestRecycleChange(applicant,rate,concludeFee);

    }

    function voteForRecycle(address _ctAddress, address _voter) external {
        require(msg.sender == marketOperation);

        CTstore(_ctAddress).voteForRecycleRate(_voter);

    }

    function concludeRecycle(address ctAddress) external returns(uint8 result,uint256 amountSut) {
        require(msg.sender == marketOperation);

        (result,amountSut) = CTstore(ctAddress).conclusionRecycle();
    }

}
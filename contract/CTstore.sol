pragma solidity >=0.4.21 <0.6.0;


import "./ISmartUp.sol";
import "./IGradeable.sol";
import "./Ownable.sol";
import "./IterableSet.sol";
import "./ISmartIdeaToken.sol";
import "./SafeMath.sol";

contract CTstore is Ownable{
    using IterableSet for IterableSet.AddressSet;
    using SafeMath for uint256;

    enum Vote {
        Abstain, Aye, Nay
    }

    uint8 public MINIMUM_BALLOTS = 1; 

    uint256 public JUROR_COUNT = 3;

    //uint256 constant ONE_CT = 10 ** 18;

    //uint256 constant MINEXCHANGE_CT = 10 ** 16;

    //uint256 public PAYOUT_VOTING_PERIOD = 3 minutes;

    ISmartIdeaToken public SUT = ISmartIdeaToken(0x7ECF880a6Ba7D17eBBC155118AF4461A15b4E8F7);
    IGradeable public NTT = IGradeable(0x3440a45b847b14F2e25908c827db36Dee748B0ae);


    uint8 public decimals = 18;

    string public name;
    string public symbol;
    

    address public exchange;
    address public creator;
    address public exStore;
    address public ctImpl;
    
    bool public dissolved;
    bool public isRecycleOpen = true;
    bool public isInFirstPeriod;
    
    uint256 public totalSupply;
    uint256 public exchangeRate;
    uint256 public recycleRate;
    uint256 public createTime;
    uint256 public closingTime;

    IterableSet.AddressSet private jurors; 
    IterableSet.AddressSet private tokenHolders;

    uint8[] private jurorsVote;

    ISmartUp private smartup; 


    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address from, address to, uint256 amount);
    event Approve(address _owner, address _spender, uint256 _amount);

    event SetImpl(address _newImplAddress);


    constructor(address _owner, address _creator, address _ctImpl, address _smartupStore, address _exchange, string memory _name, string memory _symbol, uint256 _totalSupply, uint256 _exchangeRate, uint256 _recycleRate, uint256 _closingTime)public Ownable(_owner){
        creator = _creator;
        ctImpl = _ctImpl;
        exchange = _exchange;
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
        exchangeRate = _exchangeRate;
        recycleRate = _recycleRate;
        smartup = ISmartUp(_smartupStore);
        createTime = now;
        closingTime = _closingTime;
        isInFirstPeriod = true;
        balanceOf[_exchange] = _totalSupply;
    }

    modifier onlyImpl(){
        require(msg.sender == ctImpl);
        _;
    }
    
    // set Config
    // function setMinBallots(uint8 _ballots)public onlyOwner {
    //     MINIMUM_BALLOTS = _ballots;
    // }

    // function setJurorCount(uint256 _count)public onlyOwner{
    //     JUROR_COUNT = _count;
    // }

    // function setPayoutPeriod(uint256 _time)public onlyOwner{
    //     PAYOUT_VOTING_PERIOD = _time * 60;
    // }

    // function setSut(address _sut)public onlyOwner{
    //     SUT = ISmartIdeaToken(_sut);
    // }

    // function setNtt(address _ntt)public onlyOwner{
    //     NTT = IGradeable(_ntt);
    // }

    function setImpl(address _impl) public onlyImpl{
        ctImpl = _impl;
        emit SetImpl(_impl);
    }
/**********************************************************************************

*                                                                                *

* ERC20                                                           *

*                                                                                *

**********************************************************************************/
    function transfer(address to, uint256 amount) public returns (bool) {
       require(msg.sender == exchange || to == exchange);
       require(amount > 0);

       balanceOf[msg.sender] = balanceOf[msg.sender].sub(amount);
       balanceOf[to] = balanceOf[to].add(amount);

       emit Transfer(msg.sender,to,amount);

       return true;
    } 

    function approve(address spender, uint256 value) public  returns (bool) {
        require(msg.sender == exchange || spender == exchange);
        require(value > 0);

        allowance[msg.sender][spender] = value;

        emit Approve(msg.sender, spender, value);

        return true;
    }

    function transferFrom(address from, address spender, uint256 value) public returns (bool success) {
        require(from == exchange || spender == exchange);
        require(allowance[from][spender] >= value);
        require(value > 0);

        balanceOf[from] = balanceOf[from].sub(value);
        allowance[from][spender] = allowance[from][spender].sub(value);
        balanceOf[spender] = balanceOf[spender].add(value);

        emit Transfer(from, spender, value);

        return true;
    }


/**********************************************************************************

*                                                                                *

* bool value setting                                                               *

*                                                                                *

**********************************************************************************/
    function setDissvoled(bool _dissolve)public onlyImpl {
        dissolved = _dissolve;
    }

    function setRecycleOpen(bool _open)public onlyImpl {
        isRecycleOpen = _open;
    }

    function setFirstPeriod(bool _isFirstPeriod)public onlyImpl {
        isInFirstPeriod = _isFirstPeriod;
    }


/**********************************************************************************

*                                                                                *

* jurors operation                                                                *

*                                                                                *

**********************************************************************************/
    function addJurors(address _jurors)public onlyImpl {
        jurors.add(_jurors);
    }

    function removeJurors(address _jurors)public onlyImpl {
        jurors.remove(_jurors);
    }
    
    function listJurors()public view onlyImpl returns(address[] memory) {
        return jurors.list();
    }

    function destroyJurors()public onlyImpl {
        jurors.destroy();
    }

    function containsJurors(address _jurors)public onlyImpl view returns(bool){
        return jurors.contains(_jurors);
    }

    function positionJurors(address _jurors)public onlyImpl view returns(uint256){
        return jurors.position(_jurors);
    }

    function sizeJurors()public onlyImpl view returns(uint256){
        return jurors.size();
    }

/**********************************************************************************

*                                                                                *

* tokenHolders operation                                                         *

*                                                                                *

**********************************************************************************/
    function addHolder(address _holder)public onlyImpl {
        tokenHolders.add(_holder);
    }

    function removeHolder(address _holder)public onlyImpl {
        tokenHolders.remove(_holder);
    }
    
    function listHolder()public view onlyImpl returns(address[] memory) {
        return tokenHolders.list();
    }

    function destroyHolder()public onlyImpl {
        tokenHolders.destroy();
    }

    function containsHolder(address _holder)public onlyImpl view returns(bool){
        return tokenHolders.contains(_holder);
    }

    function positionHolder(address _holder)public onlyImpl view returns(uint256){
        return tokenHolders.position(_holder);
    }

    function sizeHolder()public onlyImpl view returns(uint256){
        return tokenHolders.size();
    }

/**********************************************************************************

*                                                                                *

* jurorsVote operation                                                         *

*                                                                                *

**********************************************************************************/
    function pushVote(uint8 yeah)public onlyImpl {
        jurorsVote.push(yeah);
    }

    function destroyVote()public onlyImpl {
        delete jurorsVote;
    }

    function listJurorsVote()public onlyImpl view returns(uint8[] memory) {
        return jurorsVote;
    }

/**********************************************************************************

*                                                                                *

* smartUp addMember                                                              *

*                                                                                *

**********************************************************************************/
    function addMember(address _member)public onlyImpl {
        smartup.addMember(_member);
    }


    
}
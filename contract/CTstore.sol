pragma solidity >=0.4.21 <0.6.0;


interface ERC20Interface {
    // METHODS

    // NOTE:
    //   public getter functions are not currently recognised as an
    //   implementation of the matching abstract function by the compiler.

    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md#name
    function name() external view returns (string memory);

    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md#symbol
    function symbol() external view returns (string memory);

    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md#totalsupply
    function decimals() external view returns (uint8);

    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md#totalsupply
    function totalSupply() external view returns (uint256);

    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md#balanceof
    function balanceOf(address _owner) external view returns (uint256 balance);

    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md#transfer
    function transfer(address _to, uint256 _value) external returns (bool success);

    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md#transferfrom
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);

    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md#approve
    function approve(address _spender, uint256 _value) external returns (bool success);

    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md#allowance
    function allowance(address _owner, address _spender) external view returns (uint256 remaining);

    // EVENTS
    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md#transfer-1
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    // https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md#approval
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}


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

    ISmartIdeaToken public SUT = ISmartIdeaToken(0xF1899c6eB6940021C1aE4E9C3a8e29EE93704b03);
    IGradeable public NTT = IGradeable(0x846cE03199A759A183ccCB35146124Cd3F120548);


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

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

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
    function transfer(address to, uint256 amount) public returns (bool success) {
       require(msg.sender == exchange || to == exchange);
       require(amount > 0);

       balanceOf[msg.sender] = balanceOf[msg.sender].sub(amount);
       balanceOf[to] = balanceOf[to].add(amount);

       emit Transfer(msg.sender,to,amount);

       return true;
    } 

    function approve(address spender, uint256 value) public returns (bool success) {
        require(msg.sender == exchange || spender == exchange);

        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    function increaseApproval(address _spender,uint256 _addedValue)public returns (bool) {
        require(balanceOf[msg.sender] >= allowance[msg.sender][_spender].add(_addedValue));

        allowance[msg.sender][_spender] = allowance[msg.sender][_spender].add(_addedValue);

        emit Approval(msg.sender, _spender, allowance[msg.sender][_spender]);
        return true;
    }

    function decreaseApproval(address _spender,uint256 _subtractedValue)public returns(bool){
        uint256 oldValue = allowance[msg.sender][_spender];
        if(_subtractedValue >= oldValue){
            allowance[msg.sender][_spender] = 0;
        }else{
            allowance[msg.sender][_spender] = allowance[msg.sender][_spender].sub(_subtractedValue);
        }

        emit Approval(msg.sender,_spender,allowance[msg.sender][_spender]);

        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool success) {
        require(from == exchange || to == exchange);
        require(balanceOf[from] >= value);
        require(allowance[from][msg.sender] >= value);
        require(to != address(0));

        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);

        allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);


        emit Transfer(from, to, value);

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
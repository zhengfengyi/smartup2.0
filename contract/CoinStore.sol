pragma solidity >=0.4.21 <0.6.0;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./ReentrancyGuard.sol";
import "./IterableSet.sol";


interface Token {
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function transfer(address to, uint tokens) external;
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

interface SutStore {
    function creator(address ctAddress)external view returns(address);
}

contract CoinStore is Ownable, ReentrancyGuard{
    using IterableSet for IterableSet.AddressSet;
    using SafeMath for uint256;

    address public marketOperation;
    address public exchange;
    bool public stopFlag;
    SutStore sutStore;

    mapping (address => mapping(address => uint256)) private tokenBalance;

    mapping (address => IterableSet.AddressSet) private isAllowed;

    event Deposit(address _token, address _owner, uint256 _amount, uint256 _total);
    event Withdraw(address _token, address _owner, uint256 _amount, uint256 _remain);
    event InternalTransfer(address _token, address _from, address _to, uint256 _value);


    constructor (address _owner, address _sutStore, address _exchange, address _marketOpration)public Ownable(_owner){
        sutStore = SutStore(_sutStore);
        exchange = _exchange;
        marketOperation = _marketOpration;
    } 

    function ()external payable{

    }

    modifier onlyAllowedAddress(address _from) {
        require(isAllowed[_from].contains(msg.sender));
        _;
    }

    modifier onlyStart() {
        require(!stopFlag);
        _;
    }

    function setMarketOperation(address _marketOpration) public onlyOwner {
        require(_marketOpration != address(0));
        
        marketOperation = _marketOpration; 
    }

    function stop() public onlyOwner {
        require(!stopFlag);

        stopFlag = true;
    }

    function reStart() public onlyOwner {
        require(stopFlag);

        stopFlag = false;
    }

    function setAlloweds(address[] memory _setAddress) public  {
        require(_setAddress.length > 0);

        for(uint256 i = 0; i < _setAddress.length; i++) {
            isAllowed[msg.sender].add(_setAddress[i]);
        }
    }

    function cancelAllowed(address[] memory _allowedAddress) public  {
        require(_allowedAddress.length > 0);

        for(uint256 i = 0; i < _allowedAddress.length; i++) {
            isAllowed[msg.sender].remove(_allowedAddress[i]);
        }

    }

    function listMyAllowed() public view returns(address[] memory) {
        return isAllowed[msg.sender].list();
    }

    function receiveApproval(address _owner, uint256 approvedAmount, address token, bytes calldata extraData) external onlyStart {
        require(msg.sender == token);
        require(approvedAmount > 0);
        
        extraData;

        depositeToken(token, _owner, approvedAmount);
    }


    function depositERC20(address _token, uint256 _amount) public onlyStart {
        require(_token != address(0));
        require(Token(_token).transferFrom(msg.sender,address(this),_amount));

        tokenBalance[_token][msg.sender] = tokenBalance[_token][msg.sender].add(_amount);

        emit Deposit(_token, msg.sender, _amount, tokenBalance[_token][msg.sender]);
    }

    function depositeToken(address _token, address _owner, uint256 _amount)private{
        require(Token(_token).transferFrom(_owner,address(this),_amount));

        tokenBalance[_token][_owner] = tokenBalance[_token][_owner].add(_amount);

        emit Deposit(_token, _owner, _amount, tokenBalance[_token][_owner]);
    }

    function depositEther()public payable onlyStart{
        require(msg.value > 0);

        tokenBalance[address(0)][msg.sender] = tokenBalance[address(0)][msg.sender].add(msg.value);

        emit Deposit(address(0), msg.sender, msg.value, tokenBalance[address(0)][msg.sender]);
    }


    function withdraw(address _token, uint256 _amount) public nonReentrant {
        require(tokenBalance[_token][msg.sender] >= _amount);

        require(_amount > 0);

        tokenBalance[_token][msg.sender] = tokenBalance[_token][msg.sender].sub(_amount);

        if (_token == address(0)){
            msg.sender.transfer(_amount);
        }else{
            Token(_token).transfer(msg.sender, _amount);
        }

        emit Withdraw(_token, msg.sender, _amount, tokenBalance[_token][msg.sender]);
    }

    function internalTransferFrom(address _token, address _from, address _to, uint256 _value) public onlyAllowedAddress(_from) onlyStart{
        require(tokenBalance[_token][_from] >= _value);
        require(_to != address(0));
        require(_value > 0);

        tokenBalance[_token][_from] = tokenBalance[_token][_from].sub(_value);
        tokenBalance[_token][_to] = tokenBalance[_token][_to].add(_value);

        emit InternalTransfer(_token, _from, _to, _value);
    }


    function internalTransfer(address _token, address _to, uint256 _value) public {
        require(sutStore.creator(_token) == address(0));
        require(tokenBalance[_token][msg.sender] >= _value);
        require(_to != address(0));
        require(_value > 0);

        tokenBalance[_token][msg.sender] = tokenBalance[_token][msg.sender].sub(_value);
        tokenBalance[_token][_to] = tokenBalance[_token][_to].add(_value);

        emit InternalTransfer(_token, msg.sender, _to, _value);

    }

    function balanceOf(address _token, address _owner) public view returns(uint256) {
        return tokenBalance[_token][_owner];
    }

    function setMarketCreatedBalance(address _market, uint256 _value) public onlyStart{
        require(msg.sender == marketOperation);
        
        tokenBalance[_market][_market] = _value;
    }
    

    //can transfer market token ex SUT ETH
    function marketInternalTransfer(address _token, address _from, address _to, uint256 _value) public onlyStart {
        require(msg.sender == exchange || msg.sender == marketOperation);
        require(sutStore.creator(_from) != address(0));
        //require(_token == _from);

        tokenBalance[_token][_from] = tokenBalance[_token][_from].sub(_value);
        tokenBalance[_token][_to] = tokenBalance[_token][_to].add(_value);

        emit InternalTransfer(_token, _from, _to, _value);
    }

    function destory()public onlyOwner {
        selfdestruct(msg.sender);
    }

}


pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./Tokeninterface.sol";
import "./ExchangeConfig.sol";
import "./Ecrecovery.sol";

interface ctStore {
    function isInFirstPeriod()external view returns(bool);
    function exchangeRate()external pure returns(uint256); 
    function recycleRate()external pure returns(uint256);
    function dissolved()external pure returns(bool);
    function isRecycleOpen()external pure returns(bool);

 }


contract Exchange is Ownable, ExchangeConfig, Ecrecovery{
    using SafeMath for uint256;

    //address public createctStore;
    
    mapping (address => mapping(address => uint256)) public tokenBalance;
    mapping (address => bool)private isAllowed;
    mapping(bytes32 => bool) public expireHash;
    //mapping(address => bool) public otherERC20Exist;

    
    event Deposit(address _token, address _owner, uint256 _amount, uint256 _total);
    event Withdraw(address _token, address _owner, uint256 _amount, uint256 _remain);
    event BalanceChange(address _owner, uint256 _sutRemain, uint256 _ethRemain);
    event AdminWithdarw(address _withdrawer, address _token, address _owner, uint256 _value, uint256 _fee, uint256 _remain);
    event FirstPeriodBuyCt(address _ctAddress, address buyer, uint256 _amount, uint256 _costSut, uint256 fee);
    event SellCt(address _ctAddress, address _seller, uint256 _amount, uint256 acquireSut);



    constructor(address _sut, address _fee, address _sutProxy, address _ctImpl)public Ownable(msg.sender) ExchangeConfig(_sut,_fee, _sutProxy,_ctImpl){
        
    }
    
    function ()external payable{

    }

    function receiveApproval(address sutOwner, uint256 approvedSutAmount, address token, bytes calldata extraData) external{
        require(msg.sender == address(SUT));
        require(token == address(SUT));
        require(approvedSutAmount >= MIN_VALUE);

        depositSut(sutOwner, approvedSutAmount, token);

    }

    function depositERC20(address _token, uint256 _amount) public {
        require(_token != address(0));
        require(Token(_token).transferFrom(msg.sender,address(this),_amount));

        tokenBalance[_token][msg.sender] = tokenBalance[_token][msg.sender].add(_amount);

        emit Deposit(_token, msg.sender, _amount, tokenBalance[_token][_owner]);
    }
    
    function depositSut(address _owner, uint256 _amount, address _token)private{
        require(SUT.transferFrom(_owner,address(this),_amount));

        tokenBalance[_token][_owner] = tokenBalance[_token][_owner].add(_amount);

        emit Deposit(_token, _owner, _amount, tokenBalance[_token][_owner]);
    }

    function depositEther()public payable{
        require(msg.value >= MIN_VALUE);

        tokenBalance[address(0)][msg.sender] = tokenBalance[address(0)][msg.sender].add(msg.value);

        emit Deposit(address(0), msg.sender, msg.value, tokenBalance[address(0)][msg.sender]);
    }

 
    function withdraw(address _token, uint256 _amount)public{
        require(tokenBalance[_token][msg.sender] >= _amount);

        require(_amount >= MIN_VALUE);

        tokenBalance[_token][msg.sender] = tokenBalance[_token][msg.sender].sub(_amount);

        if (_token == address(0)){
            msg.sender.transfer(_amount);
        }else{
            Token(_token).transfer(msg.sender, _amount);
        }

        emit Withdraw(_token, msg.sender, _amount, tokenBalance[_token][msg.sender]);
    }
    

    //admin withdarw
    function adminWithdraw(address _token, uint256 _amount, address payable _owner, uint256 feeWithdraw, bytes32 _hash, bytes memory sign)public onlyAdmin{
        require( _amount >= MIN_VALUE && tokenBalance[_token][_owner] >= _amount);
        

        //check sign
        bytes32 signHash = keccak256(abi.encodePacked(_token, _amount, _owner, feeWithdraw, _hash));

        address _beneficiary = ecrecovery(signHash, sign);

        require(_beneficiary == _owner);
        require(!expireHash[signHash]);
        
        //sub balance
        tokenBalance[_token][_owner] = tokenBalance[_token][_owner].sub(_amount);

        //fee
        tokenBalance[address(0)][_owner] = tokenBalance[address(0)][_owner].sub(feeWithdraw);
        tokenBalance[address(0)][feeAccount] = tokenBalance[address(0)][feeAccount].add(feeWithdraw);

        //transfer
        if(_token == address(0)){
            _owner.transfer(_amount);
        }else{
            Token(_token).transfer(_owner, _amount);
        }

        expireHash[signHash] = true;

        emit AdminWithdarw(msg.sender, _token, _owner, _amount, feeWithdraw, tokenBalance[_token][_owner]);
    }


    function balanceOf(address _token, address _owner)public view returns (uint256 _amount) {
        return tokenBalance[_token][_owner];   
    }


    function createCtMarket(address marketCreator, uint256 initialDeposit, string memory _name, string memory _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 fee, uint256 _closingTime, bytes memory signature) public onlyAdmin {
        require(tokenBalance[address(0)][marketCreator] >= fee);
        //check sign
        bytes32 signHash = keccak256(abi.encodePacked(marketCreator, initialDeposit, _name, _symbol, _supply,_rate,_lastRate,fee,_closingTime));

        address _creator = ecrecovery(signHash, signature);

        require(_creator == marketCreator);
        require(!expireHash[signHash]);

        //fee
        tokenBalance[address(0)][_creator] = tokenBalance[address(0)][_creator].sub(fee);
        tokenBalance[address(0)][feeAccount] = tokenBalance[address(0)][feeAccount].add(fee);


        address _tokenAddress = sutProxy.createMarket(marketCreator,initialDeposit,_name,_symbol,_supply,_rate,_lastRate,_closingTime);
        
        tokenBalance[address(SUT)][_creator] = tokenBalance[address(SUT)][_creator].sub(initialDeposit);
        tokenBalance[(address(SUT))][_tokenAddress] = tokenBalance[(address(SUT))][_tokenAddress].add(initialDeposit);
        tokenBalance[_tokenAddress][_tokenAddress] = _supply;

        expireHash[signHash] = true;

        emit BalanceChange(marketCreator,tokenBalance[address(SUT)][_creator],tokenBalance[address(0)][_creator]);

        
   }


   function buyCt(address _tokenAddress, uint256 _amount, address _buyer, uint256 fee, bytes32 _hash, bytes memory signature)public onlyAdmin{

       bytes32 signHash = keccak256(abi.encodePacked(_tokenAddress, _amount, _buyer, fee, _hash));

       address buyer = ecrecovery(signHash, signature);

       require(buyer == _buyer);
       require(!expireHash[signHash]);
       


       require(_amount >= MIN_VALUE);
       ctStore market = ctStore(_tokenAddress);
       require(market.isInFirstPeriod() == true && market.dissolved() == false);
       require(tokenBalance[_tokenAddress][_tokenAddress] >= _amount);

       uint256 costSut = _amount.mul(market.exchangeRate()).div(DECIMALS_RATE);
       require(tokenBalance[address(SUT)][buyer] >= costSut);

       tokenBalance[_tokenAddress][_tokenAddress] = tokenBalance[_tokenAddress][_tokenAddress].sub(_amount);
       tokenBalance[_tokenAddress][buyer] = tokenBalance[_tokenAddress][buyer].add(_amount);

       tokenBalance[address(SUT)][_tokenAddress] = tokenBalance[address(SUT)][_tokenAddress].add(costSut);
       tokenBalance[address(SUT)][buyer] = tokenBalance[address(SUT)][buyer].sub(costSut);

       tokenBalance[address(0)][buyer] = tokenBalance[address(0)][buyer].sub(fee);
       tokenBalance[address(0)][feeAccount] = tokenBalance[address(0)][feeAccount].add(fee);
       
       ctImpl.buyct(_tokenAddress, _buyer);

       if (tokenBalance[_tokenAddress][_tokenAddress] == 0) {
           ctImpl.finishFirstPeriod(_tokenAddress);
       }

       expireHash[signHash] = true;
       
       emit FirstPeriodBuyCt(_tokenAddress, buyer, _amount, costSut, fee);

   }

   function sellCt(address _tokenAddress, uint256 _amount)public{
       require(_amount >= MIN_VALUE);
       ctStore market = ctStore(_tokenAddress);

       require(market.isRecycleOpen());

       uint256 acquireSut = _amount.mul(market.recycleRate()).div(DECIMALS_RATE);

       tokenBalance[_tokenAddress][_tokenAddress] = tokenBalance[_tokenAddress][_tokenAddress].add(_amount);
       tokenBalance[_tokenAddress][msg.sender] = tokenBalance[_tokenAddress][msg.sender].sub(_amount);

       tokenBalance[address(SUT)][_tokenAddress] = tokenBalance[address(SUT)][_tokenAddress].sub(acquireSut);
       tokenBalance[address(SUT)][msg.sender] = tokenBalance[address(SUT)][msg.sender].add(acquireSut);

       if(tokenBalance[_tokenAddress][msg.sender] == 0){
           ctImpl.removeCtHolder(_tokenAddress, msg.sender);
       }

       emit SellCt(_tokenAddress,msg.sender,_amount,acquireSut);

   }

}
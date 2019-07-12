pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./Tokeninterface.sol";
import "./ExchangeConfig.sol";
import "./Ecrecovery.sol";

interface ctMarket {
    function isInFirstPeriod()external view returns(bool);
    function rate()external pure returns(uint256); 
    function lastRate()external pure returns(uint256);
    function dissolved()external pure returns(bool);
    function isOver()external pure returns(bool);

 }

contract Exchange is Ownable, ExchangeConfig, Ecrecovery{
    using SafeMath for uint256;

    //address public createCtMarket;

    mapping (address => mapping(address => uint256)) public tokenBalance;
    mapping (address => bool)private isAllowed;

    
    event Deposit(address _token, address _owner, uint256 _amount, uint256 _total);
    event Withdraw(address _token, address _owner, uint256 _amount, uint256 _remain);
    event BalanceChange(address _owner, uint256 _sutRemain, uint256 _ethRemain);
    event AdminWithdarw(address _withdrawer, address _token, address _owner, uint256 _value, uint256 _fee, uint256 _remain);
    event FirstPeriodBuyCt(address _ctAddress, address buyer, uint256 _amount, uint256 _costSut);
    event SellCt(address _ctAddress, address _seller, uint256 _amount, uint256 acquireSut);

    // event InternalTokenTransfer(address _token, address _from, address _to, uint256 _amount);
    // event SetTokenBalance(address _token, address _owner, uint256 _amount);
    // event AddTokenBalance(address _token, address _owner, uint256 _amount, uint256 _total);
    // event SubTokenBalance(address _token, address _owner, uint256 _amount, uint256 _remain);


    constructor(address _sut, address _fee, address _storeAddress, address _sutProxy)public Ownable(msg.sender) ExchangeConfig(_sut,_fee,_storeAddress, _sutProxy){
        
    }
    
    function ()external payable{

    }

    function receiveApproval(address sutOwner, uint256 approvedSutAmount, address token, bytes calldata extraData) external{
        require(msg.sender == address(SUT));
        require(token == address(SUT));
        require(approvedSutAmount >= MIN_VALUE);

        depositSut(sutOwner, approvedSutAmount, token);

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
        require(_token == address(0) || _token == address(SUT));
        require(_amount >= MIN_VALUE);

        tokenBalance[_token][msg.sender] = tokenBalance[_token][msg.sender].sub(_amount);

        if (_token == address(0)){
            msg.sender.transfer(_amount);
        }else{
            SUT.transfer(msg.sender, _amount);
        }

        emit Withdraw(_token, msg.sender, _amount, tokenBalance[_token][msg.sender]);
    }
    

    //admin withdarw
    function adminWithdraw(address _token, uint256 _amount, address payable _owner, uint256 nonce, uint256 feeWithdraw, bytes memory sign)public onlyAdmin{
        require(_token == address(0) || _token == address(SUT));
        require( _amount >= MIN_VALUE && tokenBalance[_token][_owner] >= _amount);
        

        //check sign
        bytes32 signHash = keccak256(abi.encodePacked(_token, _amount, _owner, nonce, feeWithdraw));

        address _beneficiary = ecrecovery(signHash, sign);

        require(_beneficiary == _owner);
        
        //sub balance
        tokenBalance[_token][_owner] = tokenBalance[_token][_owner].sub(_amount);

        //fee
        tokenBalance[address(0)][_owner] = tokenBalance[address(0)][_owner].sub(feeWithdraw);
        tokenBalance[address(0)][feeAccount] = tokenBalance[address(0)][feeAccount].add(feeWithdraw);

        //transfer
        if(_token == address(0)){
            msg.sender.transfer(_amount);
        }else{
            SUT.transfer(msg.sender, _amount);
        }

        emit AdminWithdarw(msg.sender, _token, _owner, _amount, feeWithdraw, tokenBalance[_token][_owner]);
    }


    function balanceOf(address _token, address _owner)public view returns (uint256 _amount) {
        return tokenBalance[_token][_owner]; 
   
    }


    // function setTokenBalance(address _token, _owner, uint256 _amount)public{
    //     require(msg.sender == createCtMarket);

    //     tokenBalance[_token][_owner] = _amount; 

    //     emit SetTokenBalance(_token, _owner, _amount);   
    // }

    // //
    // function setAllowed(address _ctAddress, bool _isAllowed)public onlyCreateCtMarket{
    //     require(_ctAddress != address(0));
    //     isAllowed[_ctAddress] = _isAllowed;
    // }


    // function internalTokenTransfer(address _token, address _from, address _to, uint256 _amount)public {
    //     require(sutStore.creator(_token) != address(0) || _token == address(SUT));
    //     require(tokenBalance[_token][from] >= _amount);
    //     require(msg.sender == sutImpl);

    //     tokenBalance[_token][_from] = tokenBalance[_token][_from].sub(_amount);
    //     tokenBalance[_token][_to] = tokenBalance[_token][_to].add(_amount);

    //     emit InternalTokenTransfer(_token, _from, _to, _amount);    
    // }


    // function addTokenBalance(address _token, address _owner, uint256 _amount)public {
    //     require (sutStore.creator(_token) != address(0));
    //     require(_owner != address(0));
    //     require(_amount != 0);

    //     tokenBalance[_token][_owner] = tokenBalance[_token][_owner].add(_amount);
    //     emit AddTokenBalance(_token, _owner, _amount, tokenBalance[_token][_owner]);
    // }

    // function subTokenBalance(address _token, address _owner, uint256 _amount)public {
    //     require (sutStore.creator(_token) != address(0));
    //     require(_owner != address(0));
    //     require(_amount != 0);

    //     tokenBalance[_token][_owner] = tokenBalance[_token][_owner].sub(_amount);

    //     emit SubTokenBalance(_token, _owner, _amount, tokenBalance[_token][_owner]);
    // }

    function createCtMarket(address marketCreator, uint256 initialDeposit, string memory _name, string memory _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 fee, bytes memory signature) public onlyAdmin {
        require(tokenBalance[address(0)][marketCreator] >= fee);
        //check sign
        bytes32 signHash = keccak256(abi.encodePacked(marketCreator, initialDeposit, _name, _symbol, _supply,_rate,_lastRate,fee));

        address _creator = ecrecovery(signHash, signature);

        require(_creator == marketCreator);

        //fee
        tokenBalance[address(0)][marketCreator] = tokenBalance[address(0)][marketCreator].sub(fee);
        tokenBalance[address(0)][feeAccount] = tokenBalance[address(0)][feeAccount].add(fee);

        address _tokenAddress = sutProxy.createMarket(marketCreator,initialDeposit,_name,_symbol,_supply,_rate,_lastRate);
        
        tokenBalance[address(SUT)][marketCreator] = tokenBalance[address(SUT)][marketCreator].sub(fee);
        tokenBalance[_tokenAddress][_tokenAddress] = _supply;

        emit BalanceChange(marketCreator,tokenBalance[address(SUT)][marketCreator],tokenBalance[address(0)][marketCreator]);

        
   }


   function buyCt(address _tokenAddress, uint256 _amount)public {
       require(_amount >= DECIMALS_RATE);
       ctMarket market = ctMarket(_tokenAddress);
       require(market.isInFirstPeriod() == true && market.dissolved() == false);
       require(tokenBalance[_tokenAddress][_tokenAddress] >= _amount);
       uint256 costSut = _amount.div(DECIMALS_RATE).mul(market.rate());
       require(tokenBalance[address(SUT)][msg.sender] >= costSut);

       tokenBalance[_tokenAddress][_tokenAddress] = tokenBalance[_tokenAddress][_tokenAddress].sub(_amount\);
       tokenBalance[_tokenAddress][msg.sender] = tokenBalance[_tokenAddress][msg.sender].add(_amount);

       tokenBalance[address(SUT)][_tokenAddress] = tokenBalance[address(SUT)][_tokenAddress].add(costSut);
       tokenBalance[address(SUT)][msg.sender] = tokenBalance[address(SUT)][msg.sender].sub(costSut);
       
       sutProxy.addHolder(_tokenAddress, msg.sender);

       if (tokenBalance[_tokenAddress][_tokenAddress] == 0) {
           sutProxy.finishCtFirstPeriod(_tokenAddress);
       }
       
       emit FirstPeriodBuyCt(_tokenAddress, msg.sender, _amount, costSut);

   }

   function sellCt(address _tokenAddress, uint256 _amount)public{
       require(_amount >= DECIMALS_RATE);
       ctMarket market = ctMarket(_tokenAddress);

       require(market.isOver());

       uint256 acquireSut = _amount.div(DECIMALS_RATE).mul(market.lastRate());

       tokenBalance[_tokenAddress][_tokenAddress] = tokenBalance[_tokenAddress][_tokenAddress].add(_amount);
       tokenBalance[_tokenAddress][msg.sender] = tokenBalance[_tokenAddress][msg.sender].sub(_amount);

       tokenBalance[address(SUT)][_tokenAddress] = tokenBalance[address(SUT)][_tokenAddress].sub(acquireSut);
       tokenBalance[address(SUT)][msg.sender] = tokenBalance[address(SUT)][msg.sender].add(acquireSut);

       if(tokenBalance[_tokenAddress][msg.sender] == 0){
           sutProxy.removeHolder(_tokenAddress, msg.sender);
       }

       emit SellCt(_tokenAddress,msg.sender,_amount,acquireSut);

   }




}
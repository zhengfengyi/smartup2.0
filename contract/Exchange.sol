pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./Tokeninterface.sol";
import "./ExchangeConfig.sol";
import "./Ecrecovery.sol";



contract Exchange is Ownable, ExchangeConfig, Ecrecovery{
    using SafeMath for uint256;

    mapping (address => mapping(address => uint256)) public tokenBalance;

    event Deposit(address _token, address _owner, uint256 _amount, uint256 _total);
    event Withdraw(address _token, address _owner, uint256 _amount, uint256 _remain);
    event AdminWithdarw(address _withdrawer, address _token, address _owner, uint256 _value, uint256 _fee, uint256 _remain);


    constructor(address _sutAddress, address _fee)public Ownable(msg.sender) ExchangeConfig(_sutAddress, _fee){

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

        address beneficiary = ecrecovery(signHash, sign);

        require(beneficiary == _owner);
        
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

}
pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";
import "./ERC20.sol";
import "./ExchangeImpl.sol";


interface Token {
    //bytes32 public standard;
    string public name;
    string public symbol;
    uint256 public totalSupply;
    uint8 public decimals;
    //bool public allowTransactions;
    mapping (address => uint256) public balanceOf;
    mapping (address => mapping (address => uint256)) public allowance;
    function transfer(address _to, uint256 _value) public returns (bool success);
    function approveAndCall(address _spender, uint256 _value, bytes calldata _extraData) external returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
}

interface tokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes calldata _extraData) external;
}

contract ExchangeProxy is Ownable{

    address public SUT;
    address public feeAccount;
    uint256 public MINDEPOSITSUT = 10 ** 18;
    uint256 public MINDEPOSITEETH = 10 ** 15;
    address public exchangeStore;
    address public exchangeImpl;
    address constant SmartUpToken = address();

    ExchangeImpl impl;

        function receiveApproval(address _from, uint256 _value, address _token, bytes calldata _extraData) external {
        require(msg.sender == address(SUT));

        require(_token == address(SUT));

        require(_value >= MINDEPOSITSUT);

        depositSut(_token, _from, _value);
    }


    function depositSut(address _token, address _owner, uint256 _amount) private {
        require(Token(SUT).transferFrom(_owner, address(this), _amount));

        tokenBalance[SUT][_owner] = tokenBalance[SUT][_owner].add(_amount);
       

        emit Deposit(_token, _owner, _amount);
    }

    function depositEther()public payable{
        tokenBalance[address(0)][msg.sender] = tokenBalance[address(0)][msg.sender].add(msg.value);
        

        emit Deposit(address(0), msg.sender, msg.value);
    }

    function adminWitherdarw(address _token, uint256 _amount, address payable _owner, uint256 nonce, uint256 feeWithdraw, bytes memory sign)public payable onlyAdmin returns(bool success){

    }


    function adminWithdraw(address token, uint256 amount, address payable user, uint256 nonce, uint8 v, bytes32 r, bytes32 s, uint256 feeWithdrawal)public payable onlyAdmin returns (bool success) {
    bytes32 hash = keccak256(this, token, amount, user, nonce);
    if (withdrawn[hash]) revert();
    withdrawn[hash] = true;
    if (ecrecover(keccak256("\x19Ethereum Signed Message:\n32", hash), v, r, s) != user) revert();
    if (feeWithdrawal > 50 finney) feeWithdrawal = 50 finney;
    if (tokens[token][user] < amount) revert();
    tokens[token][user] = safeSub(tokens[token][user], amount);
    tokens[token][feeAccount] = safeAdd(tokens[token][feeAccount], safeMul(feeWithdrawal, amount) / 1 ether);
    uint256 amount1 = amount;
    amount1 = safeMul((1 ether - feeWithdrawal), amount) / 1 ether;
    if (token == address(0)) {
      if (!user.transfer(amount1)) revert();
    } else {
      if (!Token(token).transfer(user, amount1)) revert();
    }
    lastActiveTransaction[user] = block.number;
    Withdraw(token, user, amount1, tokens[token][user]);
  }


    constructor(address _store, address _impl, address _owner)public Ownable(_owner){
        exchangeStore = _store;
        impl = ExchangeImpl(_impl);
    }

    function ()external payable{
        revert();
    }

    function depositSut(uint256 sutAmount)public {
        require(sutAmount > 0);
        require(ERC20(SmartUpToken).transferFrom(msg.sender,exchangeStore,sutAmount));

        impl._depositSut(sutAmount);     
    }

    function firstBuyCt(address ctAddress, uint256 ctAmount)public {
        impl._firstBuyCt(ctAddress, msg.sender, ctAmount);
    }

    function exchangCt(address ctAddress, address _buyer, address _seller, uint256 _price, uint256 CtAmount) public onlyCoo{
        impl._exchangCt(ctAddress, _buyer, _seller, _price, ctAmount);
    }

    function withdrawSut(uint256 sutAmount)public{

    }

    function dissvoledExSut(address ctAddress)public{

    }

    function voteforCtproposal(address ctAddress)public{

    }


}
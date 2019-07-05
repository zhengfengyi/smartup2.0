pragma solidity >=0.4.21 <0.6.0;

interface Token {
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function transfer(address to, uint tokens) external returns (bool success);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    //event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract ExchangeConfig {
    uint256 constant MIN_VALUE = 10 ** 15;
    address public feeAccount;
    Token SUT;

    constructor (address _sut, address _fee)public{
        SUT = Token(_sut);
        feeAccount = _fee;
    }
}
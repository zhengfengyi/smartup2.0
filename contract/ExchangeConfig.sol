pragma solidity >=0.4.21 <0.6.0;

interface Token {
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function transfer(address to, uint tokens) external returns (bool success);
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

// interface SutStoreInterface {
//     function creator(address ctAddress)external view returns(address);
// }


interface SutProxy {
    function createMarket(address marketCreator, uint256 initialDeposit, string calldata _name, string calldata _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 _closingTime) external returns(address _ctAddress);
}

interface CtImpl {
    function buyct(address _ctAddress, address _holder)external;
    function finishFirstPeriod(address _ctAddress)external;
    function removeCtHolder(address _ctAddress, address _holder)external;
}

contract ExchangeConfig {
    uint256 constant MIN_VALUE = 10 ** 15;
    uint256 constant DECIMALS_RATE = 10 ** 18;
    address public feeAccount;
    SutProxy sutProxy;
    Token SUT;
    //SutStoreInterface sutStore;
    CtImpl ctImpl;

    constructor (address _sut, address _fee, address _sutProxy, address _ctImpl)public{
        SUT = Token(_sut);
        feeAccount = _fee;
        //sutStore = SutStoreInterface(_storeAddress);
        sutProxy = SutProxy(_sutProxy);
        ctImpl = CtImpl(_ctImpl);
    }

}
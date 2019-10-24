pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";
import "./IGradeable.sol";
import "./ISutStoreForProxy.sol";
import "./ISutImpl.sol";

contract SutProxyConfig is Ownable {
    
    IGradeable public NTT;

    ISutImpl SutImpl;

    ISutStoreForProxy sutStore;

    address public marketOpration;

    event SetSutStoreAddress(address _sutStoreAddress);

    constructor(address _nttAddress, address _sutStoreAddress, address _owner) Ownable (_owner)public{
        NTT = IGradeable(_nttAddress);
        sutStore = ISutStoreForProxy(_sutStoreAddress);
    }

    uint256 public MINIMUM_FLAGGING_DEPOSIT = 100 * (10 ** 18);
    uint256 public MINIMUM_APPEAL_DEPOSIT = 100 * (10 ** 18);
    uint256 public FLAGGING_DEPOSIT_REQUIRED = 2500 * (10 ** 18);
    uint256 public APPEALING_DEPOSIT_REQUIRED = 2500 * (10 ** 18);
    uint256 public CREATE_MARKET_DEPOSIT_REQUIRED = 2500 * (10 ** 18);
    
    string constant CREATE_MARKET_NTT_KEY = "create_market";

    modifier onlyMarketOpration() {
        require(msg.sender == marketOpration);
        _;
    }
    
    modifier onlyImpl() {
        require(msg.sender == address(SutImpl));
        _;
    }

    //set proxy config
    function setFlaggingDeposite(uint256 minFlaggingDeposite)public onlyOwner {
        MINIMUM_FLAGGING_DEPOSIT = minFlaggingDeposite;
    }

    function setFlaggingDepositeRequired(uint256 flaggingDepositeRequired)public onlyOwner {
        APPEALING_DEPOSIT_REQUIRED = flaggingDepositeRequired;
    }

    function setAppealDeposit(uint256 appealDeposit)public onlyOwner {
        APPEALING_DEPOSIT_REQUIRED = appealDeposit;
    }

    function setMarketCreatDeposit(uint256 marketCreatedDeposit)public onlyOwner {
        CREATE_MARKET_DEPOSIT_REQUIRED = marketCreatedDeposit;
    }

    function setMarketOpration(address _marketOpration) public onlyOwner {
        marketOpration = _marketOpration;
    }

    //setSutStoreAddress
    // function setSutStoreAddress(address _storeAddress)public onlyOwner {
    //     sutStore = IsutForProxy(_storeAddress);
    //     emit SetSutStoreAddress(_storeAddress);
    // }

    function setNTTAddress(address _nttAddress)public onlyOwner{
        NTT = IGradeable(_nttAddress);
    }
    
    // function setSUTAddress(address _sutTokenAddress)public onlyOwner{
    //     SUT = ISmartIdeaToken(_sutTokenAddress);
    // }

    // function setExchangeAddress(address _exchange)public onlyOwner{
    //     exchange = Exchange(_exchange);
    // }

    function setSutImplAddress(address _sutImpl) public onlyOwner {
        SutImpl = ISutImpl(_sutImpl);
    }
}
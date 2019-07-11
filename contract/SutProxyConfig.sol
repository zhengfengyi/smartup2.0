pragma solidity >=0.4.21 <0.6.0;

import "./IGradeable.sol";
import "./ISmartIdeaToken.sol";
import "./SutImplUpgradeable.sol";

interface Exchange {

    function balanceOf(address _token, address _owner)external view returns (uint256 _amount);
    
}


contract SutProxyConfig is Ownable, SutImplUpgradeable{
    
    IGradeable public NTT;

    ISmartIdeaToken public SUT;

    address public sutStoreAddress;

    Exchange exchange;

    event SetSutStoreAddress(address _sutStoreAddress);

    constructor(address _nttAddress, address _sutAddress, address _sutTokenAddress, address _owner)public SutImplUpgradeable(_owner){
        NTT = IGradeable(_nttAddress);
        SUT = ISmartIdeaToken(_sutAddress);
        sutStoreAddress = _sutTokenAddress;
    }


    uint8 constant CREATE_MARKET_ACTION = 1;
    uint8 constant FLAG_MARKET_ACTION = 2;
    uint8 constant APPEAL_MARKET_ACTION = 3;


    uint256 public MINIMUM_FLAGGING_DEPOSIT = 100 * (10 ** 18);
    uint256 public FLAGGING_DEPOSIT_REQUIRED = 2500 * (10 ** 18);
    uint256 public APPEALING_DEPOSIT_REQUIRED = 2500 * (10 ** 18);
    uint256 public CREATE_MARKET_DEPOSIT_REQUIRED = 2500 * (10 ** 18);
    
    string constant CREATE_MARKET_NTT_KEY = "create_market";

    //set proxy config
    function setFlaggingDeposite(uint256 minFlaggingDeposite)public onlyAdmin {
        MINIMUM_FLAGGING_DEPOSIT = minFlaggingDeposite;
    }

    function setFlaggingDepositeRequired(uint256 flaggingDepositeRequired)public onlyAdmin {
        APPEALING_DEPOSIT_REQUIRED = flaggingDepositeRequired;
    }

    function setAppealDeposit(uint256 appealDeposit)public onlyAdmin {
        APPEALING_DEPOSIT_REQUIRED = appealDeposit;
    }

    function setMarketCreatDeposit(uint256 marketCreatedDeposit)public onlyAdmin {
        CREATE_MARKET_DEPOSIT_REQUIRED = marketCreatedDeposit;
    }

    //setSutStoreAddress
    function setSutStoreAddress(address _storeAddress)public onlyOwner {
        sutStoreAddress = _storeAddress;
        emit SetSutStoreAddress(_storeAddress);
    }

    function setNTTAddress(address _nttAddress)public onlyOwner{
        NTT = IGradeable(_nttAddress);
    }
    
    function setSUTAddress(address _sutTokenAddress)public onlyOwner{
        SUT = ISmartIdeaToken(_sutTokenAddress);
    }

    function setExchangeAddress(address _exchange)public onlyOwner{
        exchange = Exchange(_exchange);
    }
}
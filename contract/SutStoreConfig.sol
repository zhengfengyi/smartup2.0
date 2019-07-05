pragma solidity >=0.4.21 <0.6.0;

import "./ISmartIdeaToken.sol";

import "./Ownable.sol";

contract SutStoreConfig is Ownable{
    enum Vote {
        Abstain, Aye, Nay
    } 

    ISmartIdeaToken public SUT; 

    address public implAddress;

    //set Store Config
    uint8 constant CREATE_MARKET_ACTION = 1;
    uint8 constant FLAG_MARKET_ACTION = 2;
    uint8 constant APPEAL_MARKET_ACTION = 3;
 
    uint8 public MINIMUM_BALLOTS = 1;
    uint256 public JUROR_COUNT = 3;

    uint256 public PROTECTION_PERIOD = 90 seconds;
    uint256 public VOTING_PERIOD = 3 minutes;
    uint256 public FLAGGING_PERIOD = 3 minutes;
    uint256 public APPEALING_PERIOD = 3 minutes;
    
    uint256 public MINIMUM_FLAGGING_DEPOSIT = 100 * (10 ** 18);
    uint256 public FLAGGING_DEPOSIT_REQUIRED = 2500 * (10 ** 18);
    uint256 public APPEALING_DEPOSIT_REQUIRED = 2500 * (10 ** 18);
    uint256 public CREATE_MARKET_DEPOSIT_REQUIRED = 2500 * (10 ** 18);

    constructor(address _sutAddress, address _owner, address _impl)public Ownable(_owner) {
        SUT = ISmartIdeaToken(_sutAddress);
        implAddress = _impl;
    }

    modifier onlyImpl(){
        require(msg.sender == implAddress);
        _;
    }

    //set Store Config
    function setMinBallots(uint8 _minBallots)public onlyCoo{
        MINIMUM_BALLOTS = _minBallots;
    }

    function setJurorCount(uint256 _jurorCount)public onlyCoo{
        JUROR_COUNT = _jurorCount;
    }

    function setProtectionPeriod(uint256 _period)public onlyCoo{
        PROTECTION_PERIOD = _period * 60;
    }

    function setVotingPeriod(uint256 _period)public onlyCoo{
        VOTING_PERIOD = _period * 60;
    }

    function setFlaggingPeriod(uint256 _period)public onlyCoo{
        FLAGGING_PERIOD = _period * 60;
    }

    function setAppleingPeriod(uint256 _period)public onlyCoo{
        APPEALING_PERIOD = _period * 60;
    }
    
    function setImplAddress(address _impl)public onlyOwner{
        implAddress = _impl;
    }

}
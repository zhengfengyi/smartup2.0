pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";

import "./ICoinStore.sol";

contract SutStoreConfig is Ownable{
    enum Vote {
        Abstain, Aye, Nay
    } 

    address public SUT; 

    address public implAddress;
 
    uint8 public MINIMUM_BALLOTS = 1;
    uint256 public JUROR_COUNT = 3;

    uint256 public PROTECTION_PERIOD = 90 seconds;
    uint256 public VOTING_PERIOD = 3 minutes;
    uint256 public FLAGGING_PERIOD = 3 minutes;
    uint256 public APPEALING_PERIOD = 3 minutes;

    uint256 public FLAGGING_DEPOSIT_REQUIRED = 2500 * (10 ** 18);
    uint256 public APPEALING_DEPOSIT_REQUIRED = 2500 * (10 ** 18);
    uint256 public CREATE_MARKET_DEPOSIT_REQUIRED = 2500 * (10 ** 18);

    ICoinStore coinStore;

    constructor(address _sutAddress, address _owner, address icoinStore)public Ownable(_owner) {
        SUT = _sutAddress;

        coinStore = ICoinStore(icoinStore);
    }

    modifier onlyImpl(){
        require(msg.sender == implAddress);
        _;
    }

    //set Store Config
    function setMinBallots(uint8 _minBallots)public onlyOwner{
        MINIMUM_BALLOTS = _minBallots;
    }

    function setJurorCount(uint256 _jurorCount)public onlyOwner{
        JUROR_COUNT = _jurorCount;
    }

    function setProtectionPeriod(uint256 _period)public onlyOwner{
        PROTECTION_PERIOD = _period * 60;
    }

    function setVotingPeriod(uint256 _period)public onlyOwner{
        VOTING_PERIOD = _period * 60;
    }

    function setFlaggingPeriod(uint256 _period)public onlyOwner{
        FLAGGING_PERIOD = _period * 60;
    }

    function setAppleingPeriod(uint256 _period)public onlyOwner{
        APPEALING_PERIOD = _period * 60;
    }
    
    function setImplAddress(address _impl)public onlyOwner{
        implAddress = _impl;
    }

    function setCoinStore(address _coinStore) public onlyOwner{
        coinStore = ICoinStore(_coinStore);
    }

}
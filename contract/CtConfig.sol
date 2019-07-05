pragma solidity >=0.4.21 <0.6.0;

import "./ISmartIdeaToken.sol";
import "./IGradeable.sol";
import "./Ownable.sol";


contract CtConfig is Ownable{

    enum Vote {
        Abstain, Aye, Nay
    }

    uint8 public MINIMUM_BALLOTS = 1; 

    ISmartIdeaToken public SUT = ISmartIdeaToken();
    IGradeable public NTT = IGradeable();


    uint256 public JUROR_COUNT = 3;

    uint256 constant ONE_CT = 10 ** 18;

    uint256 constant MINEXCHANGE_CT = 10 ** 16;

    uint256 public PAYOUT_VOTING_PERIOD = 3 minutes;

    function setMinBallots(uint8 _ballots)public onlyOwner {
        MINIMUM_BALLOTS = _ballots;
    }

    function setJurorCount(uint256 _count)public onlyOwner{
        JUROR_COUNT = _count;
    }

    function setPayoutPeriod(uint256 _time)public onlyOwner{
        PAYOUT_VOTING_PERIOD = _time * 60;
    }

    function setSut(address _sut)public onlyOwner{
        SUT = ISmartIdeaToken(_sut);
    }

    function setNtt(address _ntt)public onlyOwner{
        NTT = IGradeable(_ntt);
    }


}
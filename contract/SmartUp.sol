pragma solidity >=0.4.21 <0.6.0;



import "./RateCalc.sol";

import "./IterableSet.sol";

import "./GlobalConfig.sol";

import "./PlatformConfig.sol";

import "./ISmartUp.sol";

import "./CT.sol";

import "./TokenRecipient.sol";

/**

 * @title SmartUp platform contract

 */

contract SmartUp is Ownable, ISmartUp, tokenRecipient, PlatformConfig, GlobalConfig{

    using IterableSet for IterableSet.AddressSet;

    using SafeMath for uint256;

    // project name and address mapping

    address[] public markets;

    IterableSet.AddressSet private _members;

    enum State {

        Active, Voting, PendingDissolve, Dissolved

    }

    struct MarketData {

        address creator;

        State state;

        IterableSet.AddressSet flaggers;

        uint256[] flaggersDeposit;

        IterableSet.AddressSet jurors;

        Vote[] jurorVotes;

        uint8 appealRound;

        uint8 ballots;

        uint256 flaggerDeposit;

        // uint256 totalAppealSut;

        uint256 initialDeposit;

        uint256 appealingDeposit;

        uint256 lastFlaggingConcludedAt;

        uint256 flaggingStartedAt;

        uint256 votingStartedAt;

        uint256 appealingPeriodStart;

    }

    mapping(address => MarketData) private _marketData;

    event Flagging(address _projectAddress, address _flagger, uint256 _deposit, uint256 _totalDeposit);

    event MarketCreated(address marketAddress, address marketCreator, uint256 initialDeposit);

    event AppealMarket(address _ctAddress, address _appealer, uint256 _depositAmount);

    event CloseFlagging(address _ctAddress, address _closer);

    event MakeVote (address _ctAddress, address _voter, uint8 _appealRound,  bool _details);


    modifier onlyExistingMarket() {

        require(_marketData[msg.sender].creator != address(0));

        _;

    }


    constructor() public Ownable(msg.sender){


    }

    // we're not supposed to accept ETH?

    function() payable external {

        revert();

    }


    function _createMarket(address marketCreator, uint256 initialDeposit) private {

        require(initialDeposit == CREATE_MARKET_DEPOSIT_REQUIRED);

        require(NTT.isAllow(marketCreator, CREATE_MARKET_NTT_KEY), "Not enough NTT");

        //CT ct = new CT(owner(), marketCreator);

        CT ct = new CT(owner(), marketCreator);

        address ctAddress = address(ct);

        _marketData[ctAddress].creator = marketCreator;

        _marketData[ctAddress].state = State.Active;

        _marketData[ctAddress].initialDeposit = initialDeposit;

        // so that nextFlaggableDate() return now

        _marketData[ctAddress].lastFlaggingConcludedAt = now.sub(PROTECTION_PERIOD);

        require(SUT.transferFrom(marketCreator, address(this), initialDeposit), "SUT transfer unsuccessful");

        markets.push(ctAddress);

        emit MarketCreated(ctAddress, marketCreator, initialDeposit);

    }


    function receiveApproval(address sutOwner, uint256 approvedSutAmount, address token, bytes calldata extraData) external {

        require(msg.sender == address(SUT));

        require(token == address(SUT));

        (uint8 action, address ctAddress) = _unpack(_bytesToUint256(extraData, 0));

        if (action == CREATE_MARKET_ACTION) {

            _createMarket(sutOwner, approvedSutAmount);

        } else if (action == FLAG_MARKET_ACTION) {

            _flag(ctAddress, sutOwner, approvedSutAmount);

        } else if (action == APPEAL_MARKET_ACTION) {

            _appeal(ctAddress, sutOwner, approvedSutAmount);

        } else {

            // unexpected action value

            revert();

        }

    }


    // Utility function to convert bytes type to uint256. Noone but this contract can call this function.

    function _bytesToUint256(bytes memory input, uint offset) internal pure returns (uint256 output) {

        assembly {output := mload(add(add(input, 32), offset))}

    }


    function _unpack(uint256 data) internal pure returns (uint8 action, address ctAddress) {

        action = uint8(data);

        //uint160 _ctAddress = uint160(data >> 8);

        ctAddress = address(uint160(data >> 8));

        // amount = uint88(data >> 168);

    }


    /**********************************************************************************

     *                                                                                *

     * flag session                                                                   *

     *                                                                                *

     **********************************************************************************/

    function _flag(address ctAddress, address flagger, uint256 depositAmount) private {

        MarketData storage marketData = _getMarketData(ctAddress);

        require(_members.contains(flagger));

        require(depositAmount >= MINIMUM_FLAGGING_DEPOSIT);

        require(marketData.state == State.Active);

        require(now - marketData.lastFlaggingConcludedAt > PROTECTION_PERIOD);

        // attempt to make SUT transfer to this contract

        require(SUT.transferFrom(flagger, address(this), depositAmount));

        // first flagger

        if (marketData.flaggingStartedAt == 0) {

            marketData.flaggingStartedAt = now;

        } else {

            require(now - marketData.flaggingStartedAt <= FLAGGING_PERIOD);

        }

        if (marketData.flaggers.contains(flagger)) {

            uint256 pos = marketData.flaggers.position(flagger);

            marketData.flaggersDeposit[pos - 1] = marketData.flaggersDeposit[pos - 1].add(depositAmount);

        } else {

            marketData.flaggers.add(flagger);

            marketData.flaggersDeposit.push(depositAmount);

        }

        marketData.flaggerDeposit = marketData.flaggerDeposit.add(depositAmount);

        emit Flagging(ctAddress, flagger, depositAmount, marketData.flaggerDeposit);

        if (marketData.flaggerDeposit >= FLAGGING_DEPOSIT_REQUIRED) {

            _drawJurors(marketData, flagger);

        } 

    }

    /**

     * @dev 当flag的人数不够，时间到了之后调用closeFlagging返回flagger的押金

     *

     */

    function closeFlagging(address ctAddress) external { //external ????

        MarketData storage marketData = _getMarketData(ctAddress);

        require(marketData.state == State.Active);

        require(marketData.flaggingStartedAt > 0 && now - marketData.flaggingStartedAt > FLAGGING_PERIOD);

        require(marketData.flaggerDeposit > 0);

        _refundFlaggerDeposit(marketData);

        _clearFlagger(marketData);

        emit CloseFlagging(ctAddress, msg.sender);

    }


    function _drawJurors(MarketData storage marketData, address seeder) private {

        require(marketData.appealRound < 3);

        require(_members.size() - marketData.jurors.size() >= JUROR_COUNT, "Not enough remaining members to choose from");

        uint256 seed = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), seeder)));

        while (marketData.jurors.size() < (marketData.appealRound + 1) * JUROR_COUNT) {

            uint256 index = seed % _members.size();

            // make sure the member is neither a juror nor a flagger

            address nextJuror = _members.at(index);

            while (marketData.jurors.contains(nextJuror) || marketData.flaggers.contains(nextJuror)) {

                nextJuror = _members.at(++index % _members.size());

            }

            marketData.jurors.add(nextJuror);

            marketData.jurorVotes.push(Vote.Abstain);

            seed = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), seeder, index)));

        }

        ++marketData.appealRound;

        marketData.state = State.Voting;

        marketData.votingStartedAt = now;

        // emit Voting(_appealRound, _jurors, _lastFlaggedAt);

    }


    function vote(address ctAddress, bool dissolve) external {

        MarketData storage marketData = _getMarketData(ctAddress);

        require(marketData.state == State.Voting);

        require(now - marketData.votingStartedAt <= VOTING_PERIOD);



        // make sure it's the juror for current round

        uint256 pos = marketData.jurors.position(msg.sender);

        require(pos > (marketData.appealRound - 1) * JUROR_COUNT && pos <= marketData.appealRound * JUROR_COUNT);



        if (marketData.jurorVotes[pos - 1] == Vote.Abstain) {

            ++marketData.ballots;

        }

        // should have been initialized
        marketData.jurorVotes[pos - 1] = dissolve ? Vote.Aye : Vote.Nay;

        emit MakeVote (ctAddress, msg.sender, marketData.appealRound, dissolve);

    }


    function conclude(address ctAddress) external {

        MarketData storage marketData = _getMarketData(ctAddress);

        require(marketData.state == State.Voting);

        require(marketData.ballots == JUROR_COUNT || now - marketData.votingStartedAt > VOTING_PERIOD, "Voting still in process");

        uint8 aye = 0;

        uint8 nay = 0;

        for (uint256 i = (marketData.appealRound - 1) * JUROR_COUNT; i < marketData.appealRound * JUROR_COUNT; ++i) {

            if (marketData.jurorVotes[i] == Vote.Aye) {

                ++aye;

            } else if (marketData.jurorVotes[i] == Vote.Nay) {

                ++nay;

            }

        }

        // first round of voting

        if (marketData.appealRound == 1) {

            // @dev 投票成功，等待appeal的结果

            if (marketData.ballots >= MINIMUM_BALLOTS && aye > nay) {

                marketData.state = State.PendingDissolve;

                marketData.appealingPeriodStart = now;

            } else {

                if (marketData.ballots < MINIMUM_BALLOTS) {

                    // @dev 不够人投票，等同于flag没发生

                    _refundFlaggerDeposit(marketData);

                } else {

                    // @dev 平手或者反对者更多，flagger的抵押被瓜分

                    _dispenseDeposit(marketData, Vote.Nay, marketData.flaggerDeposit);

                }

                marketData.state = State.Active;

                _clearFlagger(marketData);

                _reset(marketData);

            }

        } else if (marketData.appealRound == 2) {

            if (marketData.ballots < MINIMUM_BALLOTS) {

                // @dev 不够人投票，等同于appeal没发生

                _refundAppealerDeposit(marketData, APPEALING_DEPOSIT_REQUIRED);

                marketData.state = State.PendingDissolve;

                marketData.appealingPeriodStart = now;

            } else if (aye <= nay) {

                // @dev 平手或者反对者更多，flagger的抵押被瓜分

                _dispenseDeposit(marketData, Vote.Nay, marketData.flaggerDeposit);

                _refundAppealerDeposit(marketData, marketData.appealingDeposit);

                marketData.appealingDeposit = 0;

                marketData.state = State.Active;

                _clearFlagger(marketData);

                _reset(marketData);

            } else {

                marketData.state = State.PendingDissolve;

                marketData.appealingPeriodStart = now;

            }

        } else if (marketData.appealRound == 3) {

            if (marketData.ballots < MINIMUM_BALLOTS) {

                _refundAppealerDeposit(marketData, APPEALING_DEPOSIT_REQUIRED);

                _dissolve(marketData, ctAddress);

            } else if (aye <= nay) {

                // @dev 平手或者反对者更多，flagger的抵押被瓜分

                _dispenseDeposit(marketData, Vote.Nay, marketData.flaggerDeposit);

                _refundAppealerDeposit(marketData, marketData.appealingDeposit);

                marketData.appealingDeposit = 0;

                marketData.state = State.Active;

                _clearFlagger(marketData);

                _reset(marketData);

            } else {

                _dissolve(marketData, ctAddress);

            }

        } else {

            revert();

        }

    }


    function _dispenseDeposit(MarketData storage marketData, Vote winningVote, uint256 amountToDispense) private {

        // dispenseDeposit

        uint256 count;

        for (uint256 i = 0; i < marketData.jurorVotes.length; ++i) {

            if (marketData.jurorVotes[i] == winningVote) {

                ++count;

            }

        }

        uint256 amount = amountToDispense.div(count);

        for (uint256 i = 0; i < marketData.jurorVotes.length; ++i) {

            if (marketData.jurorVotes[i] == winningVote) {

                SUT.transfer(marketData.jurors.at(i), amount);

            }

        }    

    }


    function _refundAppealerDeposit(MarketData storage marketData, uint256 amount) private {

        require(marketData.appealingDeposit >= amount);

        SUT.transfer(marketData.creator, amount);

        marketData.appealingDeposit = marketData.appealingDeposit.sub(amount);

    }


    function _refundFlaggerDeposit(MarketData storage marketData) private {

        for (uint256 i = 0; i < marketData.flaggers.size(); ++i) {

            SUT.transfer(marketData.flaggers.at(i), marketData.flaggersDeposit[i]);

        }

    }


    function _clearFlagger(MarketData storage marketData) private {

        marketData.flaggers.destroy();

        delete marketData.flaggersDeposit;

        marketData.ballots = 0;

        marketData.flaggerDeposit = 0;

        marketData.flaggingStartedAt = 0;

        marketData.lastFlaggingConcludedAt = now;

    }


    function _reset(MarketData storage marketData) private {

        marketData.jurors.destroy();

        delete marketData.jurorVotes;

        marketData.appealRound = 0;

        marketData.appealingPeriodStart = 0;

    }


    /**

     * @dev to be called if no appeal 

     *

     */

    function dissolve(address ctAddress) external {

        MarketData storage marketData = _getMarketData(ctAddress);

        require(marketData.state == State.PendingDissolve);

        require(now - marketData.appealingPeriodStart > APPEALING_PERIOD);

        _dissolve(marketData, ctAddress);

    }


    function _dissolve(MarketData storage marketData, address ctAddress) private {

        _refundFlaggerDeposit(marketData);

        _dispenseDeposit(marketData, Vote.Aye, marketData.initialDeposit.add(marketData.appealingDeposit));

        marketData.appealingDeposit = 0;

        marketData.initialDeposit = 0;

        marketData.state = State.Dissolved;

        CT(ctAddress).dissolve();

    }


    function _appeal(address ctAddress, address appealer, uint256 depositAmount) private {

        MarketData storage marketData = _getMarketData(ctAddress);

        require(appealer == marketData.creator);

        require(depositAmount == APPEALING_DEPOSIT_REQUIRED);

        require(SUT.transferFrom(appealer, address(this), depositAmount), "SUT transfer unsuccessful");

        require(marketData.state == State.PendingDissolve);

        _drawJurors(marketData, appealer);

        marketData.ballots = 0;

        marketData.appealingDeposit = marketData.appealingDeposit.add(depositAmount);

        emit AppealMarket( ctAddress,  appealer,  depositAmount);

    }


    function _getMarketData(address ctAddress) private view returns (MarketData storage) {

        require(_marketData[ctAddress].creator != address(0));

        return _marketData[ctAddress];

    }


    function creator(address ctAddress) external view returns (address) {

        return _getMarketData(ctAddress).creator;

    }


    function state(address ctAddress) external view returns (State) {

        return _getMarketData(ctAddress).state;

    }


    function flaggerSize(address ctAddress) external view returns (uint256) {

        return _getMarketData(ctAddress).flaggers.size();

    }


    function flaggerList(address ctAddress) external view returns (address[] memory) {

        return _getMarketData(ctAddress).flaggers.list();

    }


    function flaggerDeposits(address ctAddress) external view returns (uint256[] memory) {

        return _getMarketData(ctAddress).flaggersDeposit;

    }


    function jurorSize(address ctAddress) external view returns (uint256) {

        return _getMarketData(ctAddress).jurors.size();

    }


    function jurorList(address ctAddress) external view returns (address[] memory) {

        return _getMarketData(ctAddress).jurors.list();

    }


    function jurorVotes(address ctAddress) external view returns (Vote[] memory) {

        return _getMarketData(ctAddress).jurorVotes;

    }


    function totalFlaggerDeposit(address ctAddress) external view returns (uint256) {

        return _getMarketData(ctAddress).flaggerDeposit;

    }


    function totalCreatorDeposit(address ctAddress) external view returns (uint256) {

        MarketData storage marketData = _getMarketData(ctAddress);

        return marketData.initialDeposit.add(marketData.appealingDeposit);

    }


    function nextFlaggableDate(address ctAddress) external view returns (uint256) {

        return _getMarketData(ctAddress).lastFlaggingConcludedAt.add(PROTECTION_PERIOD);

    }


    function flaggingPeriod(address ctAddress) external view returns (uint256 start, uint256 end) {

        start = _getMarketData(ctAddress).flaggingStartedAt;

        end = start == 0 ? 0 : start.add(FLAGGING_PERIOD);

    }


    function votingPeriod(address ctAddress) external view returns (uint256 start, uint256 end) {

        start = _getMarketData(ctAddress).votingStartedAt;

        end = start == 0 ? 0 : start.add(VOTING_PERIOD);

    }


    function appealingPeriod(address ctAddress) external view returns (uint256 start, uint256 end) {

        start = _getMarketData(ctAddress).appealingPeriodStart;

        end = start == 0 ? 0 : start.add(APPEALING_PERIOD);

    }


    function appealRound(address ctAddress) external view returns (uint8) {

        return _getMarketData(ctAddress).appealRound;

    }


    function ballots(address ctAddress) external view returns (uint8) {

        return _getMarketData(ctAddress).ballots;

    }


    function marketSize() external view returns (uint256) {

        return markets.length;

    }


    function addMember(address member) public onlyExistingMarket returns (uint256) {

        return _members.add(member);

    }

}


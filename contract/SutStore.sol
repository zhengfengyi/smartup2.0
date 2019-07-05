pragma solidity >=0.4.21 <0.6.0;


import "./IterableSet.sol";

import "./SafeMath.sol";

import "./SutStoreConfig.sol";

/**

 * @title SmartUp platform contract

 */

contract SutStore is SutStoreConfig {

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

    modifier onlyExistingMarket() {

        require(_marketData[msg.sender].creator != address(0));

        _;

    }

    constructor(address _sutTokenAddress, address _owner, address _impl)public SutStoreConfig(_sutTokenAddress,_owner,_impl){

    }


    // we're not supposed to accept ETH?
    function() payable external {

        revert();

    }


    //Set Ctmarket creator
    function setCtMarketCreator(address ctAddress, address _creator)public onlyImpl{
        require(ctAddress != address(0));
        require(_creator != address(0));
        _marketData[ctAddress].creator = _creator;
    }


    // change MarketState
    function activeCtMarket(address ctAddress) public onlyImpl  {       
        _marketData[ctAddress].state = State.Active;
    }

    function isCtMarketActive(address ctAddress)public view returns (bool isActive){
        return _marketData[ctAddress].state == State.Active;
    }

    function votingCtMarket(address ctAddress)public onlyImpl {
        _marketData[ctAddress].state = State.Voting;
    }

    function pendindDissolveCtMarket(address ctAddress)public onlyImpl  {
        _marketData[ctAddress].state = State.PendingDissolve;
    }

    function dissolvedCtMarket(address ctAddress)public onlyImpl  {
        _marketData[ctAddress].state = State.Dissolved;
    }
 
    //set Ctmarket initDposite
    function setInitDeposit(address ctAddress, uint256 deposit)public onlyImpl  {
        _marketData[ctAddress].initialDeposit = deposit;
    }

    //SetCtflaggersDeposit
    function pushCtFlaggersDeposit(address ctAddress, uint256 deposit)public onlyImpl {
        _marketData[ctAddress].flaggersDeposit.push(deposit);
    }

    function setCtFlaggersDeposit(address ctAddress, uint256 position, uint256 deposit)public onlyImpl  {
        _marketData[ctAddress].flaggersDeposit[position] = deposit;
    }

    function clearCtFlaggersDeposit(address ctAddress)public onlyImpl {
        delete _marketData[ctAddress].flaggersDeposit;
    }

    //addflaggers
    function addFlaggers(address ctAddress, address flagger)public onlyImpl  {
        require(flagger != address(0));

        _marketData[ctAddress].flaggers.add(flagger);
    }

    function clearFlagger(address ctAddress)public onlyImpl{

       _marketData[ctAddress].flaggers.destroy();

    }


    //set Ct lastFlaggingConcludedAt
    function setLastFlaggingConclude(address ctAddress, uint256 time)public onlyImpl  {
        _marketData[ctAddress].lastFlaggingConcludedAt = time;
    }

    //push market
    function pushCtMarket(address ctAddress)public onlyImpl  {
        markets.push(ctAddress);
    }

    //pantform have this address?
    function checkAddress(address sutplayer)public view returns(bool) {
        return _members.contains(sutplayer);
    }

    function ableFlagCtMarket(address ctAddress)public view returns(bool) {
        return now.sub(_marketData[ctAddress].lastFlaggingConcludedAt) > PROTECTION_PERIOD;
    }
    


    /**********************************************************************************

     *                                                                                *

     * flag session                                                                   *

     *                                                                                *

     **********************************************************************************/
    
    function flaggingNotStarted(address ctAddress)public view returns(bool){
        return _marketData[ctAddress].flaggingStartedAt == 0;
    }

    function setFlaggingStartedTime(address ctAddress, uint256 time)public onlyImpl  {
        _marketData[ctAddress].flaggingStartedAt = time;
    }

    function isInFlagging(address ctAddress, uint256 time)public view returns(bool) {
        return time.sub(_marketData[ctAddress].flaggingStartedAt) <= FLAGGING_PERIOD;
    }

    function isAlreadyHaveFlager(address ctAddress, address flagger) public view returns(bool) {
        return _marketData[ctAddress].flaggers.contains(flagger);
    }

    function flagerPostion(address ctAddress, address flagger)public view returns(uint256) {
        return _marketData[ctAddress].flaggers.position(flagger);
    }

    function addFlaggersDeposit(address ctAddress, uint256 pos, uint256 depositAmount)public onlyImpl {
        _marketData[ctAddress].flaggersDeposit[pos - 1] = _marketData[ctAddress].flaggersDeposit[pos - 1].add(depositAmount);
    }

    function addFlager(address ctAddress, address flager)public onlyImpl {
         _marketData[ctAddress].flaggers.add(flager);
    }

    function pushFlagerDeposit(address ctAddress, uint256 deposit)public onlyImpl {
        require(deposit >= MINIMUM_FLAGGING_DEPOSIT);
        _marketData[ctAddress].flaggersDeposit.push(deposit);
    }
    
    function addFlaggerDeposit(address ctAddress, uint256 depositAmount)public onlyImpl  {
        _marketData[ctAddress].flaggerDeposit = _marketData[ctAddress].flaggerDeposit.add(depositAmount);
    }
    function FlaggerDepositIsOk(address ctAddress)public view returns(bool){
        return _marketData[ctAddress].flaggerDeposit >= FLAGGING_DEPOSIT_REQUIRED;
    }

  
    /**

     * @dev 当flag的人数不够，时间到了之后调用closeFlagging返回flagger的押金

     *

     */

    function isFlaggingStart(address ctAddress)public view returns(bool){
        return _marketData[ctAddress].flaggingStartedAt > 0;
    }

    function isInFlaggingPeriod(address ctAddress)public view returns(bool){
        return _marketData[ctAddress].flaggingStartedAt > 0 && now - _marketData[ctAddress].flaggingStartedAt < FLAGGING_PERIOD;
    }

    function isFlaggerDepositHave(address ctAddress)public view returns(bool) {
        return _marketData[ctAddress].flaggerDeposit > 0;
    }

    //refundFlaggerDeposit
    function refundFlaggerDeposit(address ctAddress)public onlyImpl {
        MarketData storage marketData = _getMarketData(ctAddress);
        for (uint256 i = 0; i < marketData.flaggers.size(); ++i) {

        SUT.transfer(marketData.flaggers.at(i), marketData.flaggersDeposit[i]);

        }
    }

    function deletFlaggerDeposit(address ctAddress)public onlyImpl {
        MarketData storage marketData = _getMarketData(ctAddress);
        delete marketData.flaggersDeposit;
    }

    function clearBallots(address ctAddress)public onlyImpl {
        _marketData[ctAddress].ballots = 0;
    }

    function clearFlaggerDeposit(address ctAddress)public onlyImpl {
        _marketData[ctAddress].flaggerDeposit = 0;
    }

    function setFlaggingStartedAt(address ctAddress, uint256 _time)public onlyImpl {
        _marketData[ctAddress].flaggingStartedAt = _time;
    }

    function setLastFlaggingConcluded(address ctAddress,uint256 _time)public onlyImpl {
        _marketData[ctAddress].lastFlaggingConcludedAt = _time;
    }

    function setVotingStartedAt(address ctAddress, uint256 _time)public onlyImpl {
         _marketData[ctAddress].votingStartedAt = _time;
    }

    function _drawJurors(address ctAddress, address seeder)public onlyImpl {
        MarketData storage marketData = _getMarketData(ctAddress);

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

    }


    function addMarketAppealRound(address ctAddress)public onlyImpl{
        _marketData[ctAddress].appealRound++;
    }


    //for voting function
    function isMarketStateVoting(address ctAddress)public view returns(bool){
        return _marketData[ctAddress].state == State.Voting;
    }


    function isInVotingPeriod(address ctAddress)public view returns(bool) {
        return now.sub(_marketData[ctAddress].votingStartedAt) <= VOTING_PERIOD;
    }


    function _vote(address ctAddress, address voter, bool dissolve)public onlyImpl returns(uint8 _appealRound){

        MarketData storage marketData = _getMarketData(ctAddress);


        // make sure it's the juror for current round
        uint256 pos = marketData.jurors.position(voter);

        require(pos > (marketData.appealRound - 1) * JUROR_COUNT && pos <= marketData.appealRound * JUROR_COUNT);


        if (marketData.jurorVotes[pos - 1] == Vote.Abstain) {

            ++marketData.ballots;

        }

        // should have been initialized
        marketData.jurorVotes[pos - 1] = dissolve ? Vote.Aye : Vote.Nay;

        _appealRound = marketData.appealRound;
    }


    //for appeal function
    function isMarketPenddingDissolve(address ctAddress)public view returns(bool){
        return _marketData[ctAddress].state == State.PendingDissolve;
    }

    function resetMarketBallots(address ctAddress)public onlyImpl{
        _marketData[ctAddress].ballots = 0;
    }

    function addAppealDeposit(address ctAddress, uint256 _deposit)public onlyImpl{
        _marketData[ctAddress].appealingDeposit += _deposit;
    }



    //for conclude function
    function isBallotsFinish(address ctAddress)public view returns(bool){
        return  _marketData[ctAddress].ballots == JUROR_COUNT;
    }


    function countVote(address ctAddress)public onlyImpl view returns(uint8 _aye, uint8 _nay){
        MarketData storage marketData = _getMarketData(ctAddress);

        for (uint256 i = (marketData.appealRound - 1) * JUROR_COUNT; i < marketData.appealRound * JUROR_COUNT; ++i) {

            if (marketData.jurorVotes[i] == Vote.Aye) {

                ++_aye;

            } else if (marketData.jurorVotes[i] == Vote.Nay) {

                ++_nay;

            }

        }
    }


    function getMarketAppealRound(address ctAddress)public view returns(uint8 _round){
        return _marketData[ctAddress].appealRound;
    }

    function isGthMinballots(address ctAddress)public view returns (bool){
        return _marketData[ctAddress].ballots >= MINIMUM_BALLOTS;
    }

    function setAppealStart(address ctAddress, uint256 _time)public onlyImpl{
        _marketData[ctAddress].appealingPeriodStart = _time;
    }

    function getFlaggerDeposit(address ctAddress)public view returns (uint256 _dispense){
        _dispense = _marketData[ctAddress].flaggerDeposit;
    }

    
    function dispenseDeposit(address ctAddress, uint256 amountToDispense, bool _ayeWin)public onlyImpl{
          MarketData storage marketData = _getMarketData(ctAddress);
        // dispenseDeposit

        uint256 count;
        Vote winningVote;

        if (_ayeWin == false) {
            winningVote = Vote.Nay;

        }else {
            winningVote = Vote.Aye;
        }

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

    function destroyJurors(address ctAddress)public onlyImpl{
        _marketData[ctAddress].jurors.destroy();
    }

    function deleteJurorVoters(address ctAddress)public onlyImpl{
        delete  _marketData[ctAddress].jurorVotes;
    }

    function resetAppealRound(address ctAddress)public onlyImpl{
        _marketData[ctAddress].appealRound = 0;
    }

    function getAppealerDeposit(address ctAddress)public view returns(uint256){
        return _marketData[ctAddress].appealingDeposit;
    }

    function resetAppealerDeposit(address ctAddress)public onlyImpl{
        _marketData[ctAddress].appealingDeposit = 0;
    }


    function refundDefaultAppealerDeposit(address ctAddress) public onlyImpl {

        require(_marketData[ctAddress].appealingDeposit >= APPEALING_DEPOSIT_REQUIRED);

        SUT.transfer(_marketData[ctAddress].creator, APPEALING_DEPOSIT_REQUIRED);

        _marketData[ctAddress].appealingDeposit = _marketData[ctAddress].appealingDeposit.sub(APPEALING_DEPOSIT_REQUIRED);

    }

    function refundAllAppealerDeposit(address ctAddress)public onlyImpl{
        
        uint256 _deposit = _marketData[ctAddress].appealingDeposit;

        SUT.transfer(_marketData[ctAddress].creator, _deposit);

        _marketData[ctAddress].appealingDeposit = 0;
    }

    function getInitalDeposit(address ctAddress)public view returns(uint256){
        return _marketData[ctAddress].initialDeposit;
    }







    function _getMarketData(address ctAddress) private view returns (MarketData storage) {

        require(_marketData[ctAddress].creator != address(0));

        return _marketData[ctAddress];

    }


    //other function for view
    function creator(address ctAddress)public view returns(address){
        return _marketData[ctAddress].creator;
    }

    function state(address ctAddress) external view returns (uint8) {
        if (_marketData[ctAddress].state == State.Active) {
            return uint8(0);
        }else if(_marketData[ctAddress].state == State.Voting){
            return uint8(1);
        }else if(_marketData[ctAddress].state == State.PendingDissolve){
            return uint8(2);
        }else{
            return uint8(3);
        }
    }


    function flaggerSize(address ctAddress) external view returns (uint256) {

        return _marketData[ctAddress].flaggers.size();

    }


    function flaggerList(address ctAddress) external view returns (address[] memory) {

        return _marketData[ctAddress].flaggers.list();

    }


    function flaggerDeposits(address ctAddress) external view returns (uint256[] memory) {

        return _marketData[ctAddress].flaggersDeposit;

    }


    function jurorSize(address ctAddress) external view returns (uint256) {

        return _marketData[ctAddress].jurors.size();

    }


    function jurorList(address ctAddress) external view returns (address[] memory) {

        return _marketData[ctAddress].jurors.list();

    }


    function jurorVotes(address ctAddress) external view returns (Vote[] memory) {

        return _getMarketData(ctAddress).jurorVotes;

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

        return _marketData[ctAddress].appealRound;

    }


    function ballots(address ctAddress) external view returns (uint8) {

        return _marketData[ctAddress].ballots;

    }

    function marketSize() external view returns (uint256) {

        return markets.length;

    }

    function addMember(address member) public onlyExistingMarket returns (uint256) {

        return _members.add(member);

    }

}


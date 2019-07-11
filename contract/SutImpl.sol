pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";

import "./CtMiddleware.sol";

import "./SutProxy.sol";

import "./SutStore.sol";


/**

 * @title SmartUp platform contract

 */


 interface CtMarket {
    function isInFirstPeriod()external view returns(bool);
    function rate()external returns(uint256); 
    function lastRate()external returns(uint256);

 }


contract SutImpl is Ownable{

    SutProxy public sutProxy;

    SutStore public sutStore;

    CtMiddleware public ctMiddleware;

    modifier onlyProxy() {
        require(msg.sender == address(sutProxy));
        _;
    }

    modifier onlySutStore() {
        require(msg.sender == address(sutStore));

        _;

    }

    constructor(address payable _sutPorxy, address payable _sutStore, address _ctMiddleware) public Ownable(msg.sender){

        sutProxy = SutProxy(_sutPorxy);

        sutStore = SutStore(_sutStore);

        ctMiddleware = CtMiddleware(_ctMiddleware);
    }
    


    // we're not supposed to accept ETH?

    function() payable external {

        revert();

    }

    
    function _newCtMarket(address marketCreator, uint256 initialDeposit, string calldata _name, string calldata _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate) external onlyProxy returns(address){
        
        address ctAddress = ctMiddleware.newCtMarket(owner(),marketCreator,_name,_symbol,_supply,_rate, _lastRate);

        sutStore.setCtMarketCreator(ctAddress,marketCreator);
        sutStore.activeCtMarket(ctAddress);
        sutStore.setInitDeposit(ctAddress,initialDeposit);
        sutStore.setLastFlaggingConclude(ctAddress, now);
        sutStore.pushCtMarket(ctAddress);
        
        sutProxy.emitMarketCreated(ctAddress, marketCreator, initialDeposit);

        return ctAddress;
    }


    /**********************************************************************************

     *                                                                                *

     * first period buy                                                                   *

     *                                                                                *

     **********************************************************************************/
    function _addHolder(address _ctAddress, address _holder)public onlyProxy{
        ctMiddleware.addHolder(_ctAddress, _holder);
    }

    function _removeHolder(address _ctAddress, address _holder)public onlyProxy{
        ctMiddleware.removeHolder(_ctAddress, _holder);
    }
    
    function _finishCtFirstPeriod(address _ctAddress)public onlyProxy{
        ctMiddleware.finishCtFirstPeriod(_ctAddress);
    }
    


    /**********************************************************************************

     *                                                                                *

     * flag session                                                                   *

     *                                                                                *

     **********************************************************************************/

    function _flagMarket(address ctAddress, address flagger, uint256 depositAmount) public onlyProxy {
        require(sutStore.checkAddress(flagger));       
        require(sutStore.isCtMarketActive(ctAddress));
        require(sutStore.ableFlagCtMarket(ctAddress));

        if (sutStore.flaggingNotStarted(ctAddress)) {
            sutStore.setFlaggingStartedTime(ctAddress,now);
        }else {
            require(sutStore.isInFlagging(ctAddress,now));
        }

        if(sutStore.isAlreadyHaveFlager(ctAddress,flagger)) {
            uint256 pos = sutStore.flagerPostion(ctAddress,flagger);
            sutStore.addFlaggersDeposit(ctAddress,pos,depositAmount);
        }else{
            sutStore.addFlager(ctAddress,flagger);
            sutStore.pushFlagerDeposit(ctAddress,depositAmount);
        }

        sutStore.addFlaggerDeposit(ctAddress,depositAmount);
        
        if (sutStore.FlaggerDepositIsOk(ctAddress)) {
            sutStore._drawJurors(ctAddress,flagger);
            sutStore.addMarketAppealRound(ctAddress);
            sutStore.votingCtMarket(ctAddress);
            sutStore.setVotingStartedAt(ctAddress,now);
        }
        
        uint256 totoalDeposit = sutStore.getFlaggerDeposit(ctAddress);
        
        //uint256 totoalDeposit = depositAmount;

        sutProxy.emitFlagging(ctAddress, flagger, depositAmount, totoalDeposit);

    }

    /**

     * @dev 当flag的人数不够，时间到了之后调用closeFlagging返回flagger的押金

     *

     */

    function _closeFlagging(address ctAddress, address sutplayer)public onlyProxy{
        require(sutStore.isCtMarketActive(ctAddress));
        require(!sutStore.isInFlaggingPeriod(ctAddress));
        require(sutStore.isFlaggerDepositHave(ctAddress));
        
        sutStore.refundFlaggerDeposit(ctAddress);
        sutStore.clearFlagger(ctAddress);
        sutStore.clearCtFlaggersDeposit(ctAddress);
        sutStore.clearBallots(ctAddress);
        sutStore.clearFlaggerDeposit(ctAddress);
        sutStore.setFlaggingStartedAt(ctAddress,0);
        sutStore.setLastFlaggingConcluded(ctAddress,now);
        
        sutProxy.emitCloseFlagging(ctAddress, sutplayer);
    }


    function _vote(address ctAddress, address voter, bool dissolve)public onlyProxy{
        require(sutStore.isMarketStateVoting(ctAddress));
        require(sutStore.isInVotingPeriod(ctAddress));

        uint8 round = sutStore._vote(ctAddress, voter,dissolve);

        sutProxy.emitMaketVote(ctAddress,voter,round,dissolve);
    }


    /**

     * @dev to be called if no appeal 

     *

     */

    //appeal market
    function _applealMarket(address ctAddress, address appealer, uint256 depositAmount)public onlyProxy {
        require(sutStore.creator(ctAddress) == appealer);
        require(sutStore.isMarketPenddingDissolve(ctAddress));

        sutStore._drawJurors(ctAddress,appealer);
        sutStore.addMarketAppealRound(ctAddress);
        sutStore.votingCtMarket(ctAddress);
        sutStore.setVotingStartedAt(ctAddress,now);

        sutStore.resetMarketBallots(ctAddress);
        sutStore.addAppealDeposit(ctAddress,depositAmount);

        sutProxy.emitAppealMarket(ctAddress,appealer,depositAmount);
    }



    //conclude
    function _concludeMarket(address ctAddress)public onlyProxy {
        require(sutStore.isMarketStateVoting(ctAddress));
        require(sutStore.isBallotsFinish(ctAddress) || !sutStore.isInVotingPeriod(ctAddress));

        (uint8 aye, uint8 nay) = sutStore.countVote(ctAddress);

        uint8 round = sutStore.getMarketAppealRound(ctAddress);
        
        // first round of voting
        if (round == 1){

            // @dev 投票成功，等待appeal的结果
            if (sutStore.isGthMinballots(ctAddress) && aye > nay) {
                sutStore.pendindDissolveCtMarket(ctAddress);
                sutStore.setAppealStart(ctAddress,now);

            }else{
                if (!sutStore.isGthMinballots(ctAddress)){
                    // @dev 不够人投票，等同于flag没发生
                    sutStore.refundFlaggerDeposit(ctAddress);
                }else{

                     // @dev 平手或者反对者更多，flagger的抵押被瓜分
                    uint256 _dispense = sutStore.getFlaggerDeposit(ctAddress);
                    sutStore.dispenseDeposit(ctAddress, _dispense,false);
                }

                sutStore.activeCtMarket(ctAddress);
                sutStore.clearFlagger(ctAddress);
                sutStore.clearCtFlaggersDeposit(ctAddress);
                sutStore.clearBallots(ctAddress);
                sutStore.clearFlaggerDeposit(ctAddress);
                sutStore.setFlaggingStartedAt(ctAddress,0);
                sutStore.setLastFlaggingConcluded(ctAddress,now);
                sutStore.destroyJurors(ctAddress);
                sutStore.deleteJurorVoters(ctAddress);
                sutStore.resetAppealRound(ctAddress);
                sutStore.setAppealStart(ctAddress,0);
            }


        }else if(round == 2){
            if (!sutStore.isGthMinballots(ctAddress)){

                sutStore.refundDefaultAppealerDeposit(ctAddress);
                sutStore.pendindDissolveCtMarket(ctAddress);
                sutStore.setAppealStart(ctAddress,now);

            }else if(aye <= nay){
                uint256 _dispense = sutStore.getFlaggerDeposit(ctAddress);
                sutStore.dispenseDeposit(ctAddress, _dispense, false);
                sutStore.refundDefaultAppealerDeposit(ctAddress);
                sutStore.resetAppealerDeposit(ctAddress);
                sutStore.activeCtMarket(ctAddress);

                sutStore.clearFlagger(ctAddress);
                sutStore.clearCtFlaggersDeposit(ctAddress);
                sutStore.clearBallots(ctAddress);
                sutStore.clearFlaggerDeposit(ctAddress);
                sutStore.setFlaggingStartedAt(ctAddress,0);
                sutStore.setLastFlaggingConcluded(ctAddress,now);
                sutStore.destroyJurors(ctAddress);
                sutStore.deleteJurorVoters(ctAddress);
                sutStore.resetAppealRound(ctAddress);
                sutStore.setAppealStart(ctAddress,0);

            }else{
                sutStore.pendindDissolveCtMarket(ctAddress);
                sutStore.setAppealStart(ctAddress,now);

            }
        }else if (round == 3){
            if (!sutStore.isGthMinballots(ctAddress)){

                sutStore.refundDefaultAppealerDeposit(ctAddress);

                sutStore.refundFlaggerDeposit(ctAddress);

                uint256 _dispense = sutStore.getInitalDeposit(ctAddress);
                _dispense += sutStore.getAppealerDeposit(ctAddress);

                sutStore.dispenseDeposit(ctAddress,_dispense,true);

                sutStore.resetAppealerDeposit(ctAddress);

                sutStore.setInitDeposit(ctAddress,0);

                sutStore.dissolvedCtMarket(ctAddress);

                //TODO
                ctMiddleware.trunDissolved(ctAddress);
            }else if (aye <= nay){
                uint256 _dispense = sutStore.getFlaggerDeposit(ctAddress);
                sutStore.dispenseDeposit(ctAddress, _dispense, false);

                sutStore.refundAllAppealerDeposit(ctAddress);
                sutStore.resetAppealerDeposit(ctAddress);
                sutStore.activeCtMarket(ctAddress);

                sutStore.clearFlagger(ctAddress);
                sutStore.clearCtFlaggersDeposit(ctAddress);
                sutStore.clearBallots(ctAddress);
                sutStore.clearFlaggerDeposit(ctAddress);
                sutStore.setFlaggingStartedAt(ctAddress,0);
                sutStore.setLastFlaggingConcluded(ctAddress,now);
                sutStore.destroyJurors(ctAddress);
                sutStore.deleteJurorVoters(ctAddress);
                sutStore.resetAppealRound(ctAddress);
                sutStore.setAppealStart(ctAddress,0);
            }else{

                sutStore.refundFlaggerDeposit(ctAddress);

                uint256 _dispense = sutStore.totalCreatorDeposit(ctAddress);
                               
                sutStore.dispenseDeposit(ctAddress,_dispense,true);

                sutStore.resetAppealerDeposit(ctAddress);

                sutStore.setInitDeposit(ctAddress,0);

                sutStore.dissolvedCtMarket(ctAddress);

                //TODO
                ctMiddleware.trunDissolved(ctAddress);

            }
        }else {

            revert();

        }

        
    }

    function _prepareDissovle(address _ctAddress)public onlyProxy{
        require(sutStore.state(_ctAddress) == 2);

        (uint256 _start, uint256 _end) = sutStore.appealingPeriod(_ctAddress);

        require(_start != 0 && now > _end);

        ctMiddleware.trunDissolved(_ctAddress);

    }

    function _dissolve(address _ctAddress)public onlyProxy{
        require(sutStore.state(_ctAddress) == 3);

        ctMiddleware.dissolve(_ctAddress);

        sutProxy.emitDissolvedCtMarket(_ctAddress);

    }


    //other function for view 
    function _creator(address ctAddress)public view returns(address){
        return sutStore.creator(ctAddress);
    }

    function _state(address ctAddress)public view returns(uint8){
        return sutStore.state(ctAddress);
    }

    function _flaggerSize(address ctAddress)public view returns(uint256){
        return sutStore.flaggerSize(ctAddress);
    }

    function _flaggerList(address ctAddress)public view returns(address[] memory) {
        return sutStore.flaggerList(ctAddress);
    }
    

    function _flaggerDeposits(address ctAddress)public view returns(uint256[] memory) {
        return sutStore.flaggerDeposits(ctAddress);
    }

    function _jurorSize(address ctAddress)public view returns(uint256) {
        return sutStore.jurorSize(ctAddress);
    }

    
    function _jurorList(address ctAddress)public view returns(address[] memory) {
        return sutStore.jurorList(ctAddress);
    }

    function _totalFlaggerDeposit(address ctAddress)public view returns(uint256){
        return sutStore.getFlaggerDeposit(ctAddress);
    }

    function _totalCreatorDeposit(address ctAddress)public view returns(uint256){
        return sutStore.totalCreatorDeposit(ctAddress);
    }


    function _nextFlaggableDate(address ctAddress)public view returns(uint256){
        return sutStore.nextFlaggableDate(ctAddress);
    }

    function _flaggingPeriod(address ctAddress)public view returns(uint256 start, uint256 end){
        (start, end) = sutStore.flaggingPeriod(ctAddress);
    }
 
    function _votingPeriod(address ctAddress)public view returns(uint256 start, uint256 end){
        (start, end) = sutStore.votingPeriod(ctAddress);
    }

    function _appealingPeriod(address ctAddress)public view returns(uint256 start, uint256 end){
        (start, end) = sutStore.appealingPeriod(ctAddress);
    }

    function _appealRound(address ctAddress)public view returns(uint8){
        return sutStore.appealRound(ctAddress);
    }

    function _ballots(address ctAddress)public view returns(uint8){
        return sutStore.ballots(ctAddress);
    }

    function _marketSize()public view returns(uint256){
        return sutStore.marketSize();
    }

 
}


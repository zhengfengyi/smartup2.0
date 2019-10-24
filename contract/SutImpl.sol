pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";

import "./CtMiddleware.sol";

import "./ISutStoreInterface.sol";

import "./ISutProxy.sol";


/**

 * @title SmartUp platform contract

 */


contract SutImpl is Ownable{

    ISutStore  sutStore;
    ISutProxy  sutProxy;
    CtMiddleware  ctMiddleware;

    constructor(address  _sutPorxy, address  _sutStore, address _ctMiddleware) public Ownable(msg.sender){

        sutProxy = ISutProxy(_sutPorxy);

        sutStore = ISutStore(_sutStore);

        ctMiddleware = CtMiddleware(_ctMiddleware);
    }

    modifier onlyProxy() {
        require(msg.sender == address(sutProxy));
        _;
    }
    

    function setCtMiddleware(address _middleware)public onlyOwner {
        require(_middleware != address(0));

        ctMiddleware = CtMiddleware(_middleware);
    }

    
    function _newCtMarket(address marketCreator, uint256 initialDeposit, string calldata _name, string calldata _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 _closingTime, uint256 cfee, uint256 dfee) external onlyProxy returns(address){
        
        address ctAddress = ctMiddleware.newCtMarket(marketCreator,_name,_symbol,_supply,_rate, _lastRate,_closingTime);

        setNewCtMarket(ctAddress,marketCreator,initialDeposit,cfee,dfee);

        return ctAddress;
    }

    function setNewCtMarket(address ctAddress, address marketCreator, uint256 initialDeposit, uint256 cfee, uint256 dfee) private {
        
        sutStore.setCtMarketCreator(ctAddress,marketCreator);
        
        sutStore.activeCtMarket(ctAddress);

        sutStore.setExchangeAvailable(ctAddress, true);

        sutStore.setInitDeposit(ctAddress,initialDeposit);

        sutStore.setLastFlaggingConclude(ctAddress, now);

        sutStore.pushCtMarket(ctAddress);

        sutStore.setcConclusionFee(ctAddress,cfee);

        sutStore.setDissolveFee(ctAddress,dfee);
        
        sutProxy.emitMarketCreated(ctAddress, marketCreator, initialDeposit);
    }
    
    
    
    /**********************************************************************************

     *                                                                                *

     * flag session                                                                   *

     *                                                                                *

     **********************************************************************************/

    function _flagMarket(address ctAddress, address flagger, uint256 depositAmount, uint256 fee) public onlyProxy {
        require(sutStore.checkAddress(flagger));
        require(sutStore.isCtMarketActive(ctAddress));
        require(sutStore.ableFlagCtMarket(ctAddress));

        if (sutStore.flaggingNotStarted(ctAddress)) {

            sutStore.setFlaggingStartedTime(ctAddress,now);
            sutStore.setfConclusionFee(ctAddress,fee);

        }else {
            require(sutStore.isInFlagging(ctAddress,now));
        }

        if(sutStore.isAlreadyHaveFlager(ctAddress,flagger)) {
            uint256 pos = sutStore.flagerPostion(ctAddress,flagger);
            sutStore.addFlaggersDeposit(ctAddress,pos,depositAmount);
        }else{
            sutStore.addFlaggers(ctAddress,flagger);
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

        uint256 fee = sutStore.getfConclusionFee(ctAddress);

        sutStore.refundFee(ctAddress,sutplayer,fee);

        sutStore.setfConclusionFee(ctAddress,0);

        sutStore.clearFlagger(ctAddress);

        sutStore.clearCtFlaggersDeposit(ctAddress);

        sutStore.clearFlaggerDeposit(ctAddress);

        sutStore.setFlaggingStartedAt(ctAddress,0);

        sutStore.setLastFlaggingConcluded(ctAddress,now);
        
        sutProxy.emitCloseFlagging(ctAddress, sutplayer);
    }

    function _closeAppealing(address ctAddress, address closer) public onlyProxy {
        
        (uint256 start, uint256 end) = _appealingPeriod(ctAddress);
        require(start != end && now > end);
        require(!sutStore.appealDepositIsOk(ctAddress));

        sutStore.refundAllAppealerDeposit(ctAddress);

        uint256 fee = sutStore.getcConclusionFee(ctAddress);
        sutStore.refundFee(ctAddress,closer,fee);

        sutStore.setcConclusionFee(ctAddress,0);

        sutStore.clearAppealers(ctAddress);

        sutStore.clearAppealersDeposit(ctAddress);

        if (sutStore.getMarketAppealRound(ctAddress) == 2) {
            sutStore.setAppealStart(ctAddress,now);
            sutStore.pendindDissolveCtMarket(ctAddress);
        }else if(sutStore.getMarketAppealRound(ctAddress) == 3) {
            uint256 fFee = sutStore.getfConclusionFee(ctAddress);
            
            sutStore.refundFee(ctAddress,firstFlager(ctAddress),fFee);

            sutStore.setfConclusionFee(ctAddress,0);
            
            sutStore.refundFlaggerDeposit(ctAddress);
            sutStore.dissolvedCtMarket(ctAddress);
            
            //TODO
            ctMiddleware.trunDissolved(ctAddress);


        }else{
            revert();
        }
    }


    function _vote(address ctAddress, address voter, bool dissolve)public onlyProxy{

        require(sutStore.isMarketStateVoting(ctAddress));

        require(sutStore.isInVotingPeriod(ctAddress));

        uint8 round = sutStore.vote(ctAddress, voter,dissolve);

        sutProxy.emitMaketVote(ctAddress,voter,round,dissolve);
    }


    /**

     * @dev to be called if no appeal 

     *

     */

    //appeal market

    function _appealerSize(address ctAddress) public view onlyProxy returns(uint256) {
        return sutStore.getAppealersSize(ctAddress);
    }

    function _applealMarket(address ctAddress, address appealer, uint256 cfee, uint256 depositAmount)public onlyProxy {
        require(sutStore.isMarketPenddingDissolve(ctAddress));

        (uint256 start, uint256 end) = sutStore.appealingPeriod(ctAddress);
        require(now > start && now <= end);

        if(cfee > 0) {
            sutStore.setcConclusionFee(ctAddress,cfee);
        }

        if (sutStore.isAlreadyHaveAppealer(ctAddress, appealer)) {
            uint256 pos = sutStore.appealerPostion(ctAddress,appealer);

            sutStore.addAppealersDeposit(ctAddress,pos,depositAmount);
        }else{
            sutStore.addAppealers(ctAddress,appealer);
            sutStore.pushAppealersDeposit(ctAddress,depositAmount);
        }

        sutStore.addAppealerDeposit(ctAddress,depositAmount);

        if( sutStore.appealDepositIsOk(ctAddress)) {

            sutStore._drawJurors(ctAddress,appealer);
            sutStore.addMarketAppealRound(ctAddress);
            sutStore.votingCtMarket(ctAddress);
            sutStore.setVotingStartedAt(ctAddress,now);
            sutStore.resetMarketBallots(ctAddress);

            sutProxy.emitAppealMarket(ctAddress,appealer,depositAmount);
        }

    }


    //sutStore.refundAllAppealerDeposit(ctAddress);
    //conclude
    function _concludeMarket(address ctAddress,address concluder)public onlyProxy {
        require(sutStore.isMarketStateVoting(ctAddress));
        require(sutStore.isBallotsFinish(ctAddress) || !sutStore.isInVotingPeriod(ctAddress));

        (uint8 aye, uint8 nay) = sutStore.countVote(ctAddress);

        uint8 round = sutStore.getMarketAppealRound(ctAddress);

        uint256 ffee = sutStore.getfConclusionFee(ctAddress);
        uint256 cfee = sutStore.getcConclusionFee(ctAddress);
        uint256 flagerDeposit = sutStore.getFlaggerDeposit(ctAddress);
        uint256 appealDeposit = sutStore.getAppealerDeposit(ctAddress);
        
        // first round of voting
        if (round == 1){

            // @dev 投票成功，等待appeal的结果
            if (sutStore.isGthMinballots(ctAddress)) {

                if(aye > nay){
                sutStore.setExchangeAvailable(ctAddress, false);

                sutStore.refundFee(ctAddress,concluder,cfee);

                flagSuccess(ctAddress);

                sutStore.dispenseDeposit(ctAddress,sutStore.getInitalDeposit(ctAddress),true);
                
                sutStore.setInitDeposit(ctAddress,0);

                }else{
                sutStore.refundFee(ctAddress,concluder,ffee);
                sutStore.setfConclusionFee(ctAddress,0);

                sutStore.dispenseDeposit(ctAddress, flagerDeposit,false);

                flagFailed(ctAddress);
                }
            }else{
                sutStore.refundFee(ctAddress,concluder,ffee);
                sutStore.setfConclusionFee(ctAddress,0);
               
                    // @dev 不够人投票，等同于flag没发生
                    if(sutStore.ballots(ctAddress) == 0){
                        sutStore.refundFlaggerDeposit(ctAddress);
                    }else{
                        sutStore.dispens(ctAddress,flagerDeposit);
                    }
                

                flagFailed(ctAddress);
            }


        }else if(round == 2){

            if(sutStore.isGthMinballots(ctAddress)){
                if(aye <= nay){

                    sutStore.dispenseDeposit(ctAddress, flagerDeposit, false);
                    sutStore.refundAllAppealerDeposit(ctAddress);

                    flagFailed(ctAddress);
                    sutStore.refundFee(ctAddress,concluder,ffee);
                    sutStore.setfConclusionFee(ctAddress,0);
                    sutStore.setExchangeAvailable(ctAddress, true);

                }else{

                    sutStore.dispenseDeposit(ctAddress, appealDeposit, true);
                    sutStore.refundFee(ctAddress,concluder,ffee);
                    flagSuccess(ctAddress);

                }
            }else{

                if(sutStore.ballots(ctAddress) == 0){
                    sutStore.refundAllAppealerDeposit(ctAddress);
                }else{
                    sutStore.dispens(ctAddress,appealDeposit);
                }
                
                sutStore.refundFee(ctAddress,concluder,ffee);
                flagSuccess(ctAddress);

            }

            clearAppeals(ctAddress);
        }else if (round == 3){

            if(sutStore.isGthMinballots(ctAddress)){
                if(aye <= nay){
                    sutStore.dispenseDeposit(ctAddress, flagerDeposit, false); 

                    sutStore.refundAllAppealerDeposit(ctAddress);

                    flagFailed(ctAddress);

                    sutStore.setExchangeAvailable(ctAddress, true);

                    sutStore.refundFee(ctAddress,concluder,ffee);
                    sutStore.setfConclusionFee(ctAddress,0);
                    sutStore.refundFee(ctAddress,firstApperler(ctAddress),cfee);
                    sutStore.setcConclusionFee(ctAddress,0);
                   
                }else{
                    sutStore.refundFlaggerDeposit(ctAddress);

                    sutStore.dispenseDeposit(ctAddress,appealDeposit,true); 

                    sutStore.dissolvedCtMarket(ctAddress);

                    sutStore.refundFee(ctAddress,concluder,cfee);

                    sutStore.setcConclusionFee(ctAddress,0);

                    sutStore.refundFee(ctAddress,firstFlager(ctAddress),ffee);

                    sutStore.setfConclusionFee(ctAddress,0);

                    //TODO
                    ctMiddleware.trunDissolved(ctAddress);
                }

            }else{
                if(sutStore.ballots(ctAddress) == 0) {
                    sutStore.refundAllAppealerDeposit(ctAddress);
                }else {
                    sutStore.dispens(ctAddress,appealDeposit);
                }

                sutStore.refundFlaggerDeposit(ctAddress);

                sutStore.dissolvedCtMarket(ctAddress);

                sutStore.refundFee(ctAddress,concluder,cfee);
                sutStore.setcConclusionFee(ctAddress,0);

                sutStore.refundFee(ctAddress,firstFlager(ctAddress),ffee);

                //TODO
                ctMiddleware.trunDissolved(ctAddress);
            }

            clearAppeals(ctAddress);
        }else {

            revert();

        } 
    }
    

    function flagFailed(address ctAddress) private {

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

    function flagSuccess(address ctAddress) private {
        sutStore.pendindDissolveCtMarket(ctAddress);
        sutStore.setAppealStart(ctAddress,now);
        sutStore.setcConclusionFee(ctAddress,0);

    }


    function clearAppeals(address ctAddress) private {
            sutStore.clearAppealers(ctAddress);
            sutStore.clearAppealersDeposit(ctAddress);
            sutStore.resetAppealerDeposit(ctAddress);
    }


    function _prepareDissovle(address ctAddress, address doner)public onlyProxy{
        require(sutStore.state(ctAddress) == 2);

        (uint256 _start, uint256 _end) = sutStore.appealingPeriod(ctAddress);

        require(_start != 0 && now > _end);

        uint256 fee = sutStore.getDissolveFee(ctAddress);

        uint256 ffee = sutStore.getfConclusionFee(ctAddress);

        sutStore.refundFee(ctAddress,doner,fee);

        sutStore.refundFee(ctAddress,firstFlager(ctAddress),ffee);

        sutStore.refundFlaggerDeposit(ctAddress);

        sutStore.clearFlagger(ctAddress);
        sutStore.clearCtFlaggersDeposit(ctAddress);
        sutStore.clearBallots(ctAddress);
        sutStore.clearFlaggerDeposit(ctAddress);
        sutStore.setDissolveFee(ctAddress,0);
        sutStore.setfConclusionFee(ctAddress,0);
        ctMiddleware.trunDissolved(ctAddress);

    }

    function notSellOutDissovle(address ctAddress, address doner) public onlyProxy {
        uint256 fee = sutStore.getDissolveFee(ctAddress);
        uint256 cfee = sutStore.getcConclusionFee(ctAddress);

        sutStore.refundFee(ctAddress,doner,fee);
        sutStore.refundFee(ctAddress,_creator(ctAddress),cfee);
        sutStore.setDissolveFee(ctAddress,0);
        sutStore.setcConclusionFee(ctAddress,0);

        ctMiddleware.trunDissolvedByNotSellOut(ctAddress);
    }

    function _upgradeMarket(address ctAddress)external onlyProxy{
        uint256 cfee = sutStore.getcConclusionFee(ctAddress);
        uint256 fee = sutStore.getDissolveFee(ctAddress);
        sutStore.refundFee(ctAddress,_creator(ctAddress),cfee + fee);

        sutStore.setDissolveFee(ctAddress,0);
        sutStore.setcConclusionFee(ctAddress,0);
    }

    // //other function for view 
    function _creator(address ctAddress)public view returns(address){
        return sutStore.creator(ctAddress);
    }

    function firstFlager(address ctAddress) public view returns(address) {
        return sutStore.flaggerList(ctAddress)[0];
    }

    function firstApperler(address ctAddress) public view returns(address) {
        return sutStore.appealerList(ctAddress)[0];
    }
    

    function _appealingPeriod(address ctAddress)public view returns(uint256 start, uint256 end){
        (start, end) = sutStore.appealingPeriod(ctAddress);
    }
 
}
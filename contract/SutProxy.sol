pragma solidity >=0.4.21 <0.6.0;


import "./SutProxyConfig.sol";




/**

 * @title SmartUp platform contract

 */


contract SutProxy is SutProxyConfig{

    enum State {

        Active, Voting, PendingDissolve, Dissolved

    }

    
    event Flagging(address _projectAddress, address _flagger, uint256 _deposit, uint256 _totalDeposit);

    event MarketCreated(address marketAddress, address marketCreator, uint256 initialDeposit);

    event BuyCt(address _ctAddress, address _buyer, uint256 _amount, uint256 _costSut);

    event AppealMarket(address _ctAddress, address _appealer, uint256 _depositAmount);

    event CloseFlagging(address _ctAddress, address _closer);

    event MakeVote (address _ctAddress, address _voter, uint8 _appealRound,  bool _details);

    event DissolvedCtMarket(address _ctAddress);
    
    constructor(address _nttAddress, address _sutStoreAddress, address _owner)public SutProxyConfig(_nttAddress,_sutStoreAddress,_owner){

    }


    /**********************************************************************************

     *                                                                                *

     * createMarket session                                                                   *

     *                                                                                *

     **********************************************************************************/
    
    function createMarket(address marketCreator, uint256 initialDeposit, string calldata _name, string calldata _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 _closingTime, uint256 cfee, uint256 dfee) external onlyMarketOpration returns(address _ctAddress){

        require(initialDeposit == CREATE_MARKET_DEPOSIT_REQUIRED);

        require(NTT.isAllow(marketCreator, CREATE_MARKET_NTT_KEY), "Not enough NTT");
        
        require(_rate > 0 && _lastRate > 0 && _rate > _lastRate);

        _ctAddress = SutImpl._newCtMarket(marketCreator,initialDeposit,_name,_symbol,_supply,_rate, _lastRate,_closingTime, cfee, dfee);

    }

    function emitMarketCreated(address _ctAddress, address _marketCreator, uint256 _initialDeposit) external onlyImpl {

       emit MarketCreated(_ctAddress, _marketCreator, _initialDeposit);

    }

    /**********************************************************************************

     *                                                                                *

     * flag session                                                                   *

     *                                                                                *

     **********************************************************************************/
    function flag(address ctAddress, address flagger, uint256 depositAmount, uint256 fFee) external onlyMarketOpration {

        require(depositAmount >= MINIMUM_FLAGGING_DEPOSIT);


        SutImpl._flagMarket(ctAddress,flagger,depositAmount,fFee);
    }

    function emitFlagging(address _projectAddress, address _flagger, uint256 _deposit, uint256 _totalDeposit)external onlyImpl{

        emit Flagging(_projectAddress, _flagger, _deposit, _totalDeposit);
    }

    function closeFlagging(address ctAddress, address closer) public onlyMarketOpration{
        SutImpl._closeFlagging(ctAddress,closer);
    }

    function emitCloseFlagging(address _ctAddress, address _closer)public onlyImpl {
        emit CloseFlagging(_ctAddress, _closer);
    }

    /**********************************************************************************

     *                                                                                *

     * appeal session                                                                   *

     *                                                                                *

     **********************************************************************************/

    function appeal(address ctAddress, address appealer, uint256 cfee, uint256 depositAmount) external onlyMarketOpration {

        require(depositAmount >= MINIMUM_APPEAL_DEPOSIT);

        SutImpl._applealMarket(ctAddress, appealer,cfee, depositAmount);
    }

    function closeAppealing(address ctAddress, address closer) external onlyMarketOpration{
        SutImpl._closeAppealing(ctAddress, closer);
    }

    function emitAppealMarket(address ctAddress, address appealer, uint256 depositAmount) external onlyImpl {
        emit AppealMarket( ctAddress,  appealer,  depositAmount);
 
    }

    function ctNotSellOutDissovle(address ctAddress, address doer) external onlyMarketOpration {

        SutImpl.notSellOutDissovle(ctAddress,doer);
    }

    /**

     * @dev 当flag的人数不够，时间到了之后调用closeFlagging返回flagger的押金

     *

     */

    


    //vote
    function vote(address ctAddress, address voter, bool dissolve) external onlyMarketOpration {
        
        SutImpl._vote(ctAddress, voter, dissolve);
    }

    function emitMaketVote(address ctAddress, address voter, uint8 appealRound, bool dissolve)public onlyImpl{
        emit  MakeVote (ctAddress, voter, appealRound, dissolve);
    }


    //conclude
    function conclude(address ctAddress, address concluder) external onlyMarketOpration {
        SutImpl._concludeMarket(ctAddress,concluder);
    }

    function prepareDissolve(address ctAddress, address doer) external onlyMarketOpration{

        SutImpl._prepareDissovle(ctAddress, doer);
    }

    function upgradeMarket(address ctAddress)external onlyMarketOpration{
        SutImpl._upgradeMarket(ctAddress);
    }

    // function dissolved(address ctAddress)external {
    //     sutStore._dissolve(ctAddress);
    // }


    function emitDissolvedCtMarket(address ctAddress)public onlyImpl{

        emit DissolvedCtMarket(ctAddress);

    }


    //other function for view 
    function creator(address ctAddress) external view returns (address) {

        return sutStore.creator(ctAddress);

    }


    function getState(address ctAddress) external view returns (uint8) {

        return sutStore.state(ctAddress);

    }


    function flaggerSize(address ctAddress) external view returns (uint256) {

        return sutStore.flaggerSize(ctAddress);
    }


    function flaggerList(address ctAddress) external view returns (address[] memory) {

        return sutStore.flaggerList(ctAddress);

    }

    function flaggerDeposits(address ctAddress) external view returns (uint256[] memory) {

        return sutStore.flaggerDeposits(ctAddress);

    }

    function appealerSize(address ctAddress) public view returns (uint256) {
        return sutStore.appealerSize(ctAddress);
    }

    function appealerList(address ctAddress) public view returns (address[] memory) {
        return sutStore.appealerList(ctAddress);
    }

    function appealersDeposit(address ctAddress) public view returns (uint256[] memory) {
        return sutStore.appealersDeposit(ctAddress);
    }

    function appealerTotalDeposit(address ctAddress) public view returns (uint256) {
        return sutStore.appealerTotalDeposit(ctAddress);
    }


    function jurorSize(address ctAddress) external view returns (uint256) {

        return sutStore.jurorSize(ctAddress);

    }

    function jurorList(address ctAddress) external view returns (address[] memory) {

        return sutStore.jurorList(ctAddress);

    }


    function totalFlaggerDeposit(address ctAddress) external view returns (uint256) {
        
        return sutStore.getFlaggerDeposit(ctAddress);

    }

    function totalCreatorDeposit(address ctAddress) external view returns (uint256) {

        return sutStore.getInitalDeposit(ctAddress);

    }

    function nextFlaggableDate(address ctAddress) external view returns (uint256) {

        return sutStore.nextFlaggableDate(ctAddress);

    }

    function flaggingPeriod(address ctAddress) external view returns (uint256 start, uint256 end) {
        (start,end) = sutStore.flaggingPeriod(ctAddress);
    }


    function votingPeriod(address ctAddress) external view returns (uint256 start, uint256 end) {
        (start,end) = sutStore.votingPeriod(ctAddress);
    }


    function appealingPeriod(address ctAddress) external view returns (uint256 start, uint256 end) {
        (start,end) = sutStore.appealingPeriod(ctAddress);
    }


    function appealRound(address ctAddress) external view returns (uint8) {

        return sutStore.appealRound(ctAddress);

    }


    function ballots(address ctAddress) external view returns (uint8) {

        return sutStore.ballots(ctAddress);

    }

    function marketSize() external view returns (uint256) {

        return sutStore.marketSize();

    }

}


pragma solidity >=0.4.21 <0.6.0;


import "./SutProxyConfig.sol";

import "./TokenRecipient.sol";



/**

 * @title SmartUp platform contract

 */

contract SutProxy is tokenRecipient,SutProxyConfig{

    enum State {

        Active, Voting, PendingDissolve, Dissolved

    }

    // project name and address mapping
    event Flagging(address _projectAddress, address _flagger, uint256 _deposit, uint256 _totalDeposit);

    event MarketCreated(address marketAddress, address marketCreator, uint256 initialDeposit);

    event AppealMarket(address _ctAddress, address _appealer, uint256 _depositAmount);

    event CloseFlagging(address _ctAddress, address _closer);

    event MakeVote (address _ctAddress, address _voter, uint8 _appealRound,  bool _details);

    event DissolvedCtMarket(address _ctAddress);

    // we're not supposed to accept ETH?

    function() payable external {

        revert();

    }
    
    constructor(address _nttAddress, address _sutAddress, address _sutStoreAddress, address _owner)public SutProxyConfig(_nttAddress,_sutAddress,_sutStoreAddress,_owner){

    }

    function receiveApproval(address sutOwner, uint256 approvedSutAmount, address token, bytes calldata extraData) external {

        require(msg.sender == address(SUT));

        require(token == address(SUT));

        (uint8 action, address ctAddress) = _unpack(_bytesToUint256(extraData, 0));

        if (action == CREATE_MARKET_ACTION) {

            createMarket(sutOwner, approvedSutAmount);

        } else if (action == FLAG_MARKET_ACTION) {

           flag(ctAddress, sutOwner, approvedSutAmount);

        } else if (action == APPEAL_MARKET_ACTION) {

           appeal(ctAddress, sutOwner, approvedSutAmount);

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

     * createMarket session                                                                   *

     *                                                                                *

     **********************************************************************************/
    
    function createMarket(address marketCreator, uint256 initialDeposit) private {

        require(initialDeposit == CREATE_MARKET_DEPOSIT_REQUIRED);

        require(NTT.isAllow(marketCreator, CREATE_MARKET_NTT_KEY), "Not enough NTT");

        require(SUT.transferFrom(marketCreator, sutStoreAddress, initialDeposit), "SUT transfer unsuccessful");

        sutImpl._newCtMarket(marketCreator,initialDeposit);

    }

    function emitMarketCreated(address _ctAddress, address _marketCreator, uint256 _initialDeposit) public onlyImpl {

       emit MarketCreated(_ctAddress,_marketCreator,_initialDeposit);

    }

    /**********************************************************************************

     *                                                                                *

     * flag session                                                                   *

     *                                                                                *

     **********************************************************************************/

    function flag(address ctAddress, address flagger, uint256 depositAmount) private {
        // attempt to make SUT transfer to this contract
        require(depositAmount >= MINIMUM_FLAGGING_DEPOSIT);
        require(SUT.transferFrom(flagger, sutStoreAddress, depositAmount));

        sutImpl._flagMarket(ctAddress,flagger,depositAmount);
    }

    function emitFlagging(address _projectAddress, address _flagger, uint256 _deposit, uint256 _totalDeposit)public onlyImpl{

        emit Flagging(_projectAddress, _flagger, _deposit, _totalDeposit);
    }

    /**********************************************************************************

     *                                                                                *

     * appeal session                                                                   *

     *                                                                                *

     **********************************************************************************/
    function appeal(address ctAddress, address appealer, uint256 depositAmount) private {
        require(depositAmount >= APPEALING_DEPOSIT_REQUIRED);
        require(SUT.transferFrom(appealer, sutStoreAddress, depositAmount), "SUT transfer unsuccessful");

        sutImpl._applealMarket(ctAddress, appealer, depositAmount);
    }

    function emitAppealMarket(address ctAddress, address appealer, uint256 depositAmount) public onlyImpl {
        emit AppealMarket( ctAddress,  appealer,  depositAmount);
 
    }

    /**

     * @dev 当flag的人数不够，时间到了之后调用closeFlagging返回flagger的押金

     *

     */
    function closeFlagging(address ctAddress)public{
        sutImpl._closeFlagging(ctAddress,msg.sender);
    }

    function emitCloseFlagging(address _ctAddress, address _closer)public onlyImpl {
        emit CloseFlagging(_ctAddress, _closer);
    }
    


    //vote
    function vote(address ctAddress, bool dissolve) external {
        sutImpl._vote(ctAddress, msg.sender, dissolve);
    }

    function emitMaketVote(address ctAddress, address voter, uint8 appealRound, bool dissolve)public onlyImpl{
        emit  MakeVote (ctAddress, voter, appealRound, dissolve);
    }


    //conclude
    function conclude(address ctAddress) external {
         sutImpl._concludeMarket(ctAddress);
    }

    function prepareDissolve(address ctAddress) external {
        sutImpl._prepareDissovle(ctAddress);
    }

    function dissolved(address ctAddress)external {
        sutImpl._dissolve(ctAddress);
    }


    function emitDissolvedCtMarket(address ctAddress)public onlyImpl{

        emit DissolvedCtMarket(ctAddress);

    }


    



    //other function for view 
    function creator(address ctAddress) external view returns (address) {

        return sutImpl._creator(ctAddress);

    }


    function state(address ctAddress) external view returns (uint8) {

        return sutImpl._state(ctAddress);

    }


    function flaggerSize(address ctAddress) external view returns (uint256) {

        return sutImpl._flaggerSize(ctAddress);
    }


    function flaggerList(address ctAddress) external view returns (address[] memory) {

        return sutImpl._flaggerList(ctAddress);

    }


    function flaggerDeposits(address ctAddress) external view returns (uint256[] memory) {

        return sutImpl._flaggerDeposits(ctAddress);

    }


    function jurorSize(address ctAddress) external view returns (uint256) {

        return sutImpl._jurorSize(ctAddress);

    }

    function jurorList(address ctAddress) external view returns (address[] memory) {

        return sutImpl._jurorList(ctAddress);

    }


    function totalFlaggerDeposit(address ctAddress) external view returns (uint256) {

        return sutImpl._totalFlaggerDeposit(ctAddress);

    }


    function totalCreatorDeposit(address ctAddress) external view returns (uint256) {

        return sutImpl._totalCreatorDeposit(ctAddress);

    }


    function nextFlaggableDate(address ctAddress) external view returns (uint256) {

        return sutImpl._nextFlaggableDate(ctAddress);

    }


    function flaggingPeriod(address ctAddress) external view returns (uint256 start, uint256 end) {
        (start,end) = sutImpl._flaggingPeriod(ctAddress);
    }


    function votingPeriod(address ctAddress) external view returns (uint256 start, uint256 end) {
        (start,end) = sutImpl._votingPeriod(ctAddress);
    }


    function appealingPeriod(address ctAddress) external view returns (uint256 start, uint256 end) {
        (start,end) = sutImpl._appealingPeriod(ctAddress);
    }


    function appealRound(address ctAddress) external view returns (uint8) {

        return sutImpl._appealRound(ctAddress);

    }


    function ballots(address ctAddress) external view returns (uint8) {

        return sutImpl._ballots(ctAddress);

    }


    function marketSize() external view returns (uint256) {

        return sutImpl._marketSize();

    }

}


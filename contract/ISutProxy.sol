pragma solidity >=0.4.21 <0.6.0;

interface ISutProxy {
    function emitMarketCreated(address _ctAddress, address _marketCreator, uint256 _initialDeposit) external;
    function emitFlagging(address _projectAddress, address _flagger, uint256 _deposit, uint256 _totalDeposit) external;
    function emitCloseFlagging(address _ctAddress, address _closer) external;
    function emitMaketVote(address ctAddress, address voter, uint8 appealRound, bool dissolve) external;
    function emitAppealMarket(address ctAddress, address appealer, uint256 depositAmount) external;
    
}
pragma solidity >=0.4.21 <0.6.0;

interface ISutImpl {
    
    function _newCtMarket(address marketCreator, uint256 initialDeposit, string calldata _name, string calldata _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 _closingTime, uint256 cfee, uint256 dfee) external returns(address);
    function _flagMarket(address ctAddress, address flagger, uint256 depositAmount, uint256 fee) external;
    function _applealMarket(address ctAddress, address appealer, uint256 cfee, uint256 depositAmount) external;
    function _closeAppealing(address ctAddress, address closer) external;
    function _closeFlagging(address ctAddress, address sutplayer) external;
    function _vote(address ctAddress, address voter, bool dissolve) external;
    function _concludeMarket(address ctAddress,address concluder) external;
    function _prepareDissovle(address _ctAddress, address doer) external;
    function notSellOutDissovle(address _ctAddress, address doer) external;
    function _upgradeMarket(address _ctAddress)external;

}
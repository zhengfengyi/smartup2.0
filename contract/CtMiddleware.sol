pragma solidity >=0.4.21 <0.6.0;

interface CtMiddleware {
    function newCtMarket(address owner, address creator, string calldata _name, string calldata _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate)external returns(address);
    function dissolve(address _ctAddress)external returns(bool);
    function trunDissolved(address _ctAddress)external;
    function finishCtFirstPeriod(address _ctAddress)external;
    function addHolder(address _ctAddress, address _holder)external;
    function removeHolder(address _ctAddress, address _holder)external;
}
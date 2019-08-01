pragma solidity >=0.4.21 <0.6.0;

interface CtMiddleware {
    function newCtMarket(address owner, address creator, string calldata _name, string calldata _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate,uint256 _closingTime)external returns(address);
    function trunDissolved(address _ctAddress)external;
}
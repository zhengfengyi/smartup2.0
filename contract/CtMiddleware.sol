pragma solidity >=0.4.21 <0.6.0;

interface CtMiddleware {
    function newCtMarket(address owner, address creator)external returns(address);
    function dissolve(address _ctAddress)external returns(bool);
    function trunDissolved(address _ctAddress)external;
}
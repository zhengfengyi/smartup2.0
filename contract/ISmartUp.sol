pragma solidity >=0.4.21 <0.6.0;


/**
 * @title SmartUp platform interface
 */
interface ISmartUp {

    function addMember(address member) external returns(uint256);
}
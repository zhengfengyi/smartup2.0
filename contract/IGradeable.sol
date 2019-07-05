pragma solidity >=0.4.21 <0.6.0;


/**
 * @title IGradeable
 */
interface IGradeable {
    
    function isAllow(address user, string calldata action) external view returns (bool);

    function raiseCredit(address user, uint256 score) external;

    function lowerCredit(address user, uint256 score) external;
}
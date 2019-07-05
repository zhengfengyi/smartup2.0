pragma solidity >=0.4.21 <0.6.0;

/**
 * @title Migration target
 * @dev Implement this interface to make migration target
 */
interface MigrationTarget {
    function migrateFrom(address from, uint256 amount) external;
}
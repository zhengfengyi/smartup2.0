pragma solidity >=0.4.21 <0.6.0;

import './MigrationTarget.sol';
import "./ERC20.sol";
import "./IterableSet.sol";


/**
 * @title MigratableToken
 * @dev Migration support for ERC20 token
 */
contract MigratableToken is ERC20 {
    
    using IterableSet for IterableSet.AddressSet;

    // Target contract
    address public migrationTarget;
    address public migrationFrom;
    uint256 public totalMigrated;

    IterableSet.AddressSet internal _tokenHolders;

    // Migrate event
    event Migrate(address indexed from, address indexed to, uint256 value);
    event StartMigration();
    event StopMigration();
    event SetMigrationFrom(address _from);

    /**
     * @dev modifier to allow actions only when the migration is started
     */
    modifier whenMigrationUnstarted() {
        require(migrationTarget == address(0));
        _;
    }

    /**
     * @dev modifier to allow actions only when the migration is not started
     */
    modifier whenMigrating() {
        require(migrationTarget != address(0) && totalMigrated < _tokenHolders.size());
        _;
    }

    /**
     * @dev called by the owner to start migration, triggers stopped state
     * @param target The address of the MigrationTarget contract
     * 
     * TODO: maybe we should add logic to make sure target is correct, like checking whether it's a contract
     * 
     */
    function startMigration(address target) onlyOwner whenMigrationUnstarted external {
        require(target != address(0));
        require(target != address(this));

        migrationTarget = target;
        // make sure token holders list won't be updated during migration
        _tokenHolders.freeze();
        emit StartMigration();
    }

    /**
     * @notice Migrate tokens to the new token contract.
     */
    function migrate(uint256 batchSize) whenMigrating external {

        uint256 lastPos = totalMigrated.add(batchSize) < _tokenHolders.size() ? totalMigrated.add(batchSize) : _tokenHolders.size();

        for (uint256 i = totalMigrated; i < lastPos; ++i) {
            address tokenHolder = _tokenHolders.at(i);
            // ignore empty balance
            if (balanceOf(tokenHolder) > 0) {
                uint256 amount = balanceOf(tokenHolder);
                // finalizeMigration may or may not clear the balance of the token holder 
               //finalizeMigration(tokenHolder, amount);

                totalMigrated = i.add(1);
                MigrationTarget(migrationTarget).migrateFrom(tokenHolder, amount);

                emit Migrate(tokenHolder, migrationTarget, amount);
            }
        }
    }


    //function finalizeMigration(address tokenHolder, uint256 migratedAmount) internal;

    function setMigrationFrom(address _from)onlyOwner whenMigrationUnstarted external {
        require(_from != address(0));
        migrationFrom = _from;

        emit SetMigrationFrom(_from);
    }

    /**
     * @dev called by the owner to stop migration, returns to normal state
     */
    function finishMigration() onlyOwner whenMigrating external {
        require(totalMigrated == _tokenHolders.size());

        _tokenHolders.unfreeze();
        emit StopMigration();
    }
   
    function totalHolders() external view returns(uint256) {
        return _tokenHolders.size();
    }
}

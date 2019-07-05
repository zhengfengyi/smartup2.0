pragma solidity >=0.4.21 <0.6.0;

import "./SutImpl.sol";
import "./Ownable.sol";

/** @title  A contract to inherit upgradeable token implementations.
  *
  * @notice  A contract that provides re-usable code for upgradeable
  * token implementations. It itself inherits from `CustodianUpgradable`
  * as the upgrade process is controlled by the custodian.
  *
  * @dev  This contract is intended to be inherited by any contract
  * requiring a reference to the active token implementation, either
  * to delegate calls to it, or authorize calls from it. This contract
  * provides the mechanism for that implementation to be be replaced,
  * which constitutes an implementation upgrade.
  *
  * @author Gemini Trust Company, LLC
  */
contract SutImplUpgradeable is Ownable{
     // MEMBERS
    // @dev  The reference to the active token implementation.
    SutImpl public sutImpl;

    // CONSTRUCTOR
    constructor (address _owner) Ownable(_owner) public {
        sutImpl = SutImpl(0x0);
    }

    // MODIFIERS
    modifier onlyImpl {
        require(msg.sender == address(sutImpl));
        _;
    }

 
    function setImplAddress(address payable implAddress) public onlyOwner {
        sutImpl = SutImpl(implAddress);

        emit ImplChanged(msg.sender, address(sutImpl));
    }


    /// @dev  Emitted by successful `requestImplChange` calls.
    event ImplChanged(address changer, address implAddress);
   
}

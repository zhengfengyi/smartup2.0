pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";
import "./IterableSet.sol";

contract Admin is Ownable {
    using IterableSet for IterableSet.AddressSet;

    IterableSet.AddressSet private admin;

    event SetAdmin(address _admin, bool _become);

    constructor (address _owner) public Ownable(_owner) {

    }

    function onlyAdmin(address _admin) public view returns(bool) {
        return admin.contains(_admin);
    }

    function setAdmin(address _admin) public onlyOwner {
        require(!admin.contains(_admin));

        admin.add(_admin);

        emit SetAdmin(_admin, true);
    }

    function cancelAdmin(address _admin) public onlyOwner {
        require(admin.contains(_admin));
        
        admin.remove(_admin);
        emit SetAdmin(_admin, false);
    }

    function adminList() public view returns(address[] memory) {
        return admin.list();
    }

    function adminSize() public view returns(uint256) {
        return admin.size();
    }
}
pragma solidity >=0.4.21 <0.6.0;

/**
 * @title IterableSet
 * @dev library for membership management
 */
library IterableSet {

    struct AddressSet {
        bool freezed;
        address[] addresses;
        mapping(address => uint256) positions;
    }


    function contains(AddressSet storage addrSet, address entry) internal view returns (bool) {
        return addrSet.positions[entry] != 0;
    }


    function position(AddressSet storage addrSet, address entry) internal view returns (uint256) {
        return addrSet.positions[entry];
    }

    function add(AddressSet storage addrSet, address entry) internal returns (uint256) {
        require(!addrSet.freezed);
        if (addrSet.positions[entry] == 0) {
            addrSet.positions[entry] = addrSet.addresses.push(entry);
        }

        return addrSet.positions[entry];
    }


    function remove(AddressSet storage addrSet, address entry) internal returns (uint256) {
        require(!addrSet.freezed);

        uint256 curPos = addrSet.positions[entry];
        if (curPos != 0) {
            // exchange current entry with the last one in the array and then remove the last one
            // skip if there's only one entry in the set
            if (addrSet.addresses.length > 1) {
                address lastAddress = addrSet.addresses[addrSet.addresses.length - 1];
                addrSet.addresses[curPos - 1] = lastAddress;
                addrSet.positions[lastAddress] = curPos;
            }

            // clean up storage
            addrSet.addresses.length--;
            delete addrSet.positions[entry];
        }

        return curPos;
    }


    function at(AddressSet storage addrSet, uint256 index) internal view returns (address) {
        require(index < addrSet.addresses.length);
        return addrSet.addresses[index];
    }


    function size(AddressSet storage addrSet) internal view returns (uint256) {
        return addrSet.addresses.length;
    }


    function list(AddressSet storage addrSet) internal view returns (address[] memory){
        return addrSet.addresses;
    }


    function freeze(AddressSet storage addrSet) internal {
        require(!addrSet.freezed);
        addrSet.freezed = true;
    }


    function unfreeze(AddressSet storage addrSet) internal {
        require(addrSet.freezed);
        addrSet.freezed = false;
    }


    function destroy(AddressSet storage addrSet) internal {
        for (uint i = 0; i < addrSet.addresses.length; ++i) {
            delete addrSet.positions[addrSet.addresses[i]];
        }

        delete addrSet.addresses;
    }
}
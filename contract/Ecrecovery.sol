pragma solidity >=0.4.21 <0.6.0;

contract Ecrecovery {
    function ecrecovery(bytes32 hash, bytes memory sig) public pure returns (address) {
    bytes32 r;
    bytes32 s;
    uint8 v;

    if (sig.length != 65) {
      return address(0);
    }

    assembly {
      r := mload(add(sig, 32))
      s := mload(add(sig, 64))
      v := and(mload(add(sig, 65)), 255)
    }

    // https://github.com/ethereum/go-ethereum/issues/2053
    if (v < 27) {
      v += 27;
    }

    if (v != 27 && v != 28) {
      return address(0);
    }

    /* prefix might be needed for geth only
     * https://github.com/ethereum/go-ethereum/issues/3731
     */
     bytes memory prefix = "\x19Ethereum Signed Message:\n32";
     bytes32 hashCode = keccak256(abi.encodePacked(prefix, hash));

    return ecrecover(hashCode, v, r, s);
  }

  function ecverify(bytes32 hash, bytes memory sig, address signer) public pure returns (bool) {
    return signer == ecrecovery(hash, sig);
  }

  function ecverifyRSV(bytes32 hash, uint8 v, bytes32 r, bytes32 s)public pure returns (address) {
     bytes memory prefix = "\x19Ethereum Signed Message:\n32";
     bytes32 hashCode = keccak256(abi.encodePacked(prefix, hash));

     return ecrecover(hashCode, v, r, s);
  }
}
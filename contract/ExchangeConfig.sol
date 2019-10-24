pragma solidity >=0.4.21 <0.6.0;

import "./ICoinStore.sol";
import "./IAdmin.sol";
import "./Ownable.sol";


interface CtImpl {
    function buyct(address _ctAddress, address _holder)external;
    function finishFirstPeriod(address _ctAddress)external;
    function removeCtHolder(address _ctAddress, address _holder)external;
    function addAdmin(address _ctAddress, address _buyer) external;
    function deleteAdmin(address _ctAddress, address seller) external;
}

// interface SutStore {
//     function creator(address ctAddress)external view returns(address);
// }

interface Proposal {
   function recivedSut(address _token, address _marketAddress, uint256 amount) external; 
}


contract ExchangeConfig is Ownable {
    // uint256 constant MIN_VALUE = 10 ** 15;
    uint256 constant DECIMALS_RATE = 10 ** 18;

    address public feeAccount;
    // address public sutStore;
    address SUT;
    
    ICoinStore coinStore;
    IAdmin admin;
    CtImpl ctImpl;
    Proposal proposal;


    constructor (address _sut, address _fee, address _ctImpl, address _proposal, address _owner, address _coinStore, address _admin)public Ownable(_owner){
        SUT = _sut;
        feeAccount = _fee;
        // sutStore = _sutStore;
        ctImpl = CtImpl(_ctImpl);
        coinStore = ICoinStore(_coinStore);
        admin = IAdmin(_admin);
        proposal = Proposal(_proposal);
    }

    function setCtImpl(address _ctImpl) public onlyOwner {
        ctImpl = CtImpl(_ctImpl);
    }

    function setPropsoal(address _proposal) public onlyOwner {
        proposal = Proposal(_proposal);
    }

    function setCoinStore(address _coinStore) public onlyOwner {
        coinStore = ICoinStore(_coinStore);
    }
}
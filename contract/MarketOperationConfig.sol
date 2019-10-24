pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";
import "./ICoinStore.sol";
import "./IAdmin.sol";
// import "./IProposal.sol";

interface SutProxy {
    function createMarket(address marketCreator, uint256 initialDeposit, string calldata _name, string calldata _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 _closingTime, uint256 cfee, uint256 dfee) external returns(address _ctAddress);
    function flaggerSize(address ctAddress) external view returns (uint256);
    function flag(address ctAddress, address flagger, uint256 depositAmount, uint256 fFee) external;
    function vote(address ctAddress, address voter, bool dissolve) external;
    function closeFlagging(address ctAddress, address closer)external;
    function conclude(address ctAddress, address concluder) external;
    function appeal(address ctAddress, address appealer,uint256 cfee, uint256 depositAmount) external;
    function appealerSize(address ctAddress) external view returns(uint256);
    function closeAppealing(address ctAddress, address closer) external;
    function prepareDissolve(address ctAddress, address doer) external;
    function ctNotSellOutDissovle(address ctAddress, address doer) external;
    
}

interface CtImpl {
    function buyct(address _ctAddress, address _holder)external;
    function finishFirstPeriod(address _ctAddress)external;
    function removeCtHolder(address _ctAddress, address _holder)external;
    function addAdmin(address _ctAddress, address _buyer) external;
    function deleteAdmin(address _ctAddress, address seller) external;
    function setUpgradeMarket(address _ctAddress, address _newAddress)external;
    function setCtMigrateFrom(address _ctAddress, address _from)external;
    function requestRecycleRate(address _ctAddress, address applicant, uint256 rate, uint256 concludeFee) external;
    function voteForRecycle(address _ctAddress, address _voter) external;
    function concludeRecycle(address ctAddress, address concluder) external returns(uint8 result,uint256 amountSut);
}

interface SutStore {
     function creator(address ctAddress)external view returns(address);
}

interface Proposal {
    function recivedSut(address token, address _marketAddress, uint256 amount) external; 
    function withdrawToMarket(address token, address _marketAddress, uint256 amount) external;
}

contract MarketOperationConfig is Ownable {
    
    address public SUT;
    address public feeAccount;
    address public sutStore;

    SutProxy sutProxy;

    CtImpl ctImpl;

    ICoinStore coinStore;
    Proposal proposal;
    IAdmin admin;

    constructor (address _sut, address _sutStore, address _fee, address _sutProxy, address _owner, address _admin)public Ownable(_owner){
        SUT = _sut;
        feeAccount = _fee;
        sutStore = _sutStore;
        sutProxy = SutProxy(_sutProxy);
        admin = IAdmin(_admin);
    }

    function setProposal(address _proposal) public onlyOwner {
        proposal = Proposal(_proposal);
    }

    function setCtImpl(address _ctImpl) public onlyOwner {
        ctImpl = CtImpl(_ctImpl);
    }

    function setCoinStore(address _coinStore) public onlyOwner {
        coinStore = ICoinStore(_coinStore);
    }

}
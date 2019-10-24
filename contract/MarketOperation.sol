pragma solidity >=0.4.21 <0.6.0;

import "./SafeMath.sol";
import "./MarketOperationConfig.sol";
import "./Ecrecovery.sol";
import "./Address.sol";


interface ctStore {

    function isInFirstPeriod() external view returns(bool);
    function exchangeRate() external pure returns(uint256); 
    function recycleRate() external pure returns(uint256);
    function dissolved() external pure returns(bool);
    function isRecycleOpen() external pure returns(bool);
    function isAdmin(address _admin) external pure returns(bool);
    function adminSize() external pure returns(uint256);
    function totalSupply() external pure returns(uint256);
    function creator() external pure returns(address);
    function migrationTarget() external pure returns(address);
    function migrationFrom() external pure returns(address);
    function containsHolder(address _holder) external pure returns(bool);
    function closingTime() external pure returns(uint256);
    function notSelloutDissolved() external pure returns(bool);
    function recycleFee() external pure returns(uint256);

 }

contract MarketOperation is MarketOperationConfig, Ecrecovery{
    using SafeMath for uint256;
    using Address for address;

    mapping(bytes32 => bool) public expireHash;

    constructor(address _sut, address _fee, address _sutStore, address _sutProxy, address _admin)public MarketOperationConfig(_sut,_sutStore, _fee, _sutProxy, msg.sender, _admin){
        
    }
    
    //create CT market
    function createCtMarket(address marketCreator, uint256 initialDeposit, string memory _name, string memory _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 fee, uint256 _closingTime, uint256 cFee, uint256 dFee, bytes memory signature) public {
        require(admin.onlyAdmin(msg.sender));

        require(coinStore.balanceOf(address(0), marketCreator) >= fee.add(cFee).add(dFee));

        require(coinStore.balanceOf(SUT, marketCreator) >= initialDeposit);
        //check sign
        bytes32 signHash = keccak256(abi.encodePacked(marketCreator, initialDeposit, _name, _symbol, _supply,_rate,_lastRate,fee,_closingTime,cFee,dFee));

        require(ecrecovery(signHash, signature) == marketCreator);

        require(!expireHash[signHash]);

        marketCreate(marketCreator,initialDeposit,_name,_symbol,_supply,_rate,_lastRate,fee,_closingTime,cFee,dFee);

        

     //    address _tokenAddress = sutProxy.createMarket(marketCreator,initialDeposit,_name,_symbol,_supply,_rate,_lastRate,_closingTime,cFee,dFee);

     //    coinStore.internalTransferFrom(address(0), marketCreator, feeAccount, fee);
        
     //    coinStore.internalTransferFrom(SUT, marketCreator, sutStore, initialDeposit);

     //    coinStore.internalTransferFrom(address(0), marketCreator, sutStore, cFee.add(dFee));

     //    coinStore.setMarketCreatedBalance(_tokenAddress, _supply);

        expireHash[signHash] = true;
   }

   function marketCreate(address marketCreator, uint256 initialDeposit, string memory _name, string memory _symbol,uint256 _supply,uint256 _rate,uint256 _lastRate,uint256 fee,uint256 _closingTime,uint256 cFee, uint256 dFee) private {
       
        address _tokenAddress = sutProxy.createMarket(marketCreator,initialDeposit,_name,_symbol,_supply,_rate,_lastRate,_closingTime,cFee,dFee);

        coinStore.internalTransferFrom(address(0), marketCreator, feeAccount, fee);
        
        coinStore.internalTransferFrom(SUT, marketCreator, sutStore, initialDeposit);

        coinStore.internalTransferFrom(address(0), marketCreator, sutStore, cFee.add(dFee));

        coinStore.setMarketCreatedBalance(_tokenAddress, _supply);
   }

   //flag Ct market
   function flagCtMarket(address ctAddress, address flager, uint256 flagDeposit, uint256 ffee, uint256 tFee, uint256 timeStamp, bytes memory sign) public {
        require(admin.onlyAdmin(msg.sender));
        require(!ctStore(ctAddress).isInFirstPeriod());

        bytes32 signHash = keccak256(abi.encodePacked(ctAddress, flager, flagDeposit, ffee,tFee,timeStamp));

        require(ecrecovery(signHash, sign) == flager);

        require(!expireHash[signHash]);

        if (sutProxy.flaggerSize(ctAddress) == 0) {
             require (ffee > 0);
             coinStore.internalTransferFrom(address(0), flager, sutStore, ffee);
        }else {
             require(ffee == 0);
        }

        coinStore.internalTransferFrom(SUT, flager, sutStore, flagDeposit);
        //address ctAddress, address flagger, uint256 depositAmount, uint256 fFee

        sutProxy.flag(ctAddress, flager, flagDeposit, ffee);

        coinStore.internalTransferFrom(address(0), flager, feeAccount, tFee);

        expireHash[signHash] = true;
   }
   

   //vote for flag
   function voteForFlag(address ctAddress, address voter, bool dissolve, uint256 fee, uint256 timeStamp, bytes memory sign) public {

        require(admin.onlyAdmin(msg.sender));

        bytes32 signHash = keccak256(abi.encodePacked(ctAddress, voter, dissolve, fee, timeStamp));

        require(ecrecovery(signHash, sign) == voter);

        require(!expireHash[signHash]);

        sutProxy.vote(ctAddress, voter, dissolve);

        coinStore.internalTransferFrom(address(0),voter,feeAccount,fee);

        expireHash[signHash] = true;

   }

   //close flag
   function closeFlag(address ctAddress, address closer, uint256 fee, uint256 timeStamp, bytes memory sign) public {
        require(admin.onlyAdmin(msg.sender));

        bytes32 signHash = keccak256(abi.encodePacked(ctAddress, closer, fee, timeStamp));

        require(ecrecovery(signHash, sign) == closer);

        require(!expireHash[signHash]);

        sutProxy.closeFlagging(ctAddress, closer);

        coinStore.internalTransferFrom(address(0),closer,feeAccount,fee);

        expireHash[signHash] = true;

   }


   // concludeVote
   function concludeVote(address ctAddress, address concluder, uint256 fee, uint256 timeStamp, bytes memory sign) public {
        require(admin.onlyAdmin(msg.sender));

        bytes32 signHash = keccak256(abi.encodePacked(ctAddress, concluder, fee, timeStamp));

        require(ecrecovery(signHash, sign) == concluder);

        require(!expireHash[signHash]);

        sutProxy.conclude(ctAddress, concluder);

        coinStore.internalTransferFrom(address(0),concluder,feeAccount,fee);

        expireHash[signHash] = true;
   }

   function appealMarket(address ctAddress, address appealer, uint256 appealDeposite, uint256 cfee, uint256 fee, uint256 timeStamp, bytes memory sign) public {
        require(admin.onlyAdmin(msg.sender));

        require(ctStore(ctAddress).containsHolder(appealer));

        bytes32 signHash = keccak256(abi.encodePacked(ctAddress, appealer,cfee, fee, timeStamp));

        require(ecrecovery(signHash, sign) == appealer);

        require(!expireHash[signHash]);

        if (sutProxy.appealerSize(ctAddress) == 0) {
             require(cfee > 0);
             coinStore.internalTransferFrom(address(0), appealer, sutStore, cfee);
        }else{
             require(cfee == 0);
        }

        sutProxy.appeal(ctAddress, appealer,cfee,appealDeposite);

        coinStore.internalTransferFrom(SUT,appealer,sutStore,appealDeposite);

        coinStore.internalTransferFrom(address(0),appealer,feeAccount,fee);

        expireHash[signHash] = true;
   }

   function closeAppeal(address ctAddress, address closer, uint256 fee, uint256 timeStamp, bytes memory sign) public {
        require(admin.onlyAdmin(msg.sender));

        bytes32 signHash = keccak256(abi.encodePacked(ctAddress, closer, fee, timeStamp));

        require(ecrecovery(signHash, sign) == closer);

        require(!expireHash[signHash]);

        sutProxy.closeAppealing(ctAddress, closer);

        coinStore.internalTransferFrom(address(0),closer,feeAccount,fee);

        expireHash[signHash] = true;
   }

   function noAppealerDissovle(address ctAddress, address doer, uint256 fee, uint256 timeStamp, bytes memory sign) public {
        require(admin.onlyAdmin(msg.sender));

        bytes32 signHash = keccak256(abi.encodePacked(ctAddress, doer, fee, timeStamp));

        require(ecrecovery(signHash, sign) == doer);

        require(!expireHash[signHash]);

        sutProxy.prepareDissolve(ctAddress, doer);

        coinStore.internalTransferFrom(address(0),doer,feeAccount,fee);

        expireHash[signHash] = true;

   }

   function notSellOutDissovle(address ctAddress, address doer, uint256 fee, uint256 timeStamp, bytes memory sign) public {
        require(admin.onlyAdmin(msg.sender));

        require(ctStore(ctAddress).isInFirstPeriod());
        require(!ctStore(ctAddress).dissolved());
        require(now > ctStore(ctAddress).closingTime() && coinStore.balanceOf(ctAddress,ctAddress) > 0);
        
        bytes32 signHash = keccak256(abi.encodePacked(ctAddress, doer, fee, timeStamp));

        require(ecrecovery(signHash, sign) == doer);

        require(!expireHash[signHash]);

        sutProxy.ctNotSellOutDissovle(ctAddress,doer);

        expireHash[signHash] = true;
   }


   function ctNotSellOutBackSut(address ctAddress, address seller, uint256 fee, uint256 timeStamp, bytes memory sign) public {
        require(admin.onlyAdmin(msg.sender));

        require(ctStore(ctAddress).notSelloutDissolved() && ctStore(ctAddress).dissolved());

        bytes32 signHash = keccak256(abi.encodePacked(ctAddress, seller, fee, timeStamp));

        require(ecrecovery(signHash, sign) == seller);

        require(!expireHash[signHash]);

        uint256 amoutCt = coinStore.balanceOf(ctAddress,seller);

        uint256 aquireSut = amoutCt.mul(ctStore(ctAddress).exchangeRate()).div(10 ** 18);

        coinStore.marketInternalTransfer(SUT,ctAddress,seller,aquireSut);

        coinStore.internalTransferFrom(ctAddress,seller,ctAddress,amoutCt);

   }

   //change requestRecycleChange
   function changeRecycleRate(address marketAddress, address applicant, uint256 rate, uint256 fee, uint256 concludeFee,uint256 timeStamp, bytes memory sign) public {
        require(admin.onlyAdmin(msg.sender));

        bytes32 applicantHash = keccak256(abi.encodePacked(marketAddress,applicant,rate,fee,concludeFee,timeStamp));

        require(ecrecovery(applicantHash, sign) == applicant);

        require(!expireHash[applicantHash]);

        ctImpl.requestRecycleRate(marketAddress,applicant,rate,concludeFee);

        coinStore.internalTransferFrom(address(0),applicant,feeAccount,fee);
        coinStore.internalTransferFrom(address(0),applicant,marketAddress,concludeFee);

        expireHash[applicantHash] = true;
   }

   function voteForRecycleRate(address marketAddress, address voter, uint256 fee, uint256 timeStamp, bytes memory sign) public {
        require(admin.onlyAdmin(msg.sender));

        bytes32 voterHash = keccak256(abi.encodePacked(marketAddress,voter,fee, timeStamp));

        require(ecrecovery(voterHash, sign) == voter);

        require(!expireHash[voterHash]);

        ctImpl.voteForRecycle(marketAddress, voter);

        coinStore.internalTransferFrom(address(0),voter,feeAccount,fee);

        expireHash[voterHash] = true;

   }

   function conclusionRecycle(address marketAddress, address concluder, uint256 fee, uint256 timeStamp, bytes memory sign) public {
        require(admin.onlyAdmin(msg.sender));

        bytes32 voterHash = keccak256(abi.encodePacked(marketAddress,concluder,fee, timeStamp));

        require(ecrecovery(voterHash, sign) == concluder);

        require(!expireHash[voterHash]);

        (uint8 result, uint256 transferSut) = ctImpl.concludeRecycle(marketAddress, concluder);

        if(result == uint8(1)) {
             coinStore.marketInternalTransfer(SUT,marketAddress,address(proposal),transferSut);

             proposal.recivedSut(SUT,marketAddress,transferSut);
          }else if(result == uint8(2)){
               // coinStore.marketInternalTransfer(SUT,propsoal,marketAddress,)
               proposal.withdrawToMarket(SUT,marketAddress,transferSut);
               
          }

        coinStore.internalTransferFrom(address(0),concluder,feeAccount,fee);

        uint256 concludeFee = ctStore(marketAddress).recycleFee();

        coinStore.marketInternalTransfer(address(0),marketAddress, concluder,concludeFee);

        expireHash[voterHash] = true;
   }
   

   //upgrade Issue
   function upgradeMarket(address marketAddress, address upgraderAddress, address upgrader, uint256 fee, uint256 timeStamp,bytes memory upgraderSign) public {
        
        require(admin.onlyAdmin(msg.sender));

        require(ctStore(marketAddress).migrationTarget() == address(0));

        bytes32 upgraderHash = keccak256(abi.encodePacked(marketAddress,upgraderAddress,upgrader, fee,timeStamp));

        require(ecrecovery(upgraderHash, upgraderSign) == upgrader);
        require(!expireHash[upgraderHash]);
        
        coinStore.internalTransferFrom(address(0), upgrader, feeAccount, fee);

        ctImpl.setUpgradeMarket(marketAddress, upgraderAddress);

        expireHash[upgraderHash] = true;

   }

   function setMigrateFrom(address marketAddress, address migrateFrom, address upgrader, uint256 fee, uint256 timeStamp, bytes memory upgraderSign) public {
        require(admin.onlyAdmin(msg.sender));

        require(ctStore(marketAddress).migrationFrom() == address(0));

        bytes32 upgraderHash = keccak256(abi.encodePacked(marketAddress,migrateFrom,upgrader,timeStamp,fee));

        require(ecrecovery(upgraderHash, upgraderSign) == upgrader);
        require(!expireHash[upgraderHash]);

        coinStore.internalTransferFrom(address(0), upgrader, feeAccount, fee);

        ctImpl.setCtMigrateFrom(marketAddress, migrateFrom);

        expireHash[upgraderHash] = true;
     }
   
}
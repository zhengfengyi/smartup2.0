pragma solidity >=0.4.21 <0.6.0;

import "./SafeMath.sol";
import "./IterableSet.sol";
import "./Ownable.sol";
import "./ICoinStore.sol";
import "./Ecrecovery.sol";
import "./IAdmin.sol";


interface Token {
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) external view returns (uint balance);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function transfer(address to, uint tokens) external;
    function approve(address spender, uint tokens) external returns (bool success);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}



interface CtStore {
    function isInFirstPeriod()external view returns(bool);
    function exchangeRate()external pure returns(uint256); 
    function recycleRate()external pure returns(uint256);
    function dissolved()external pure returns(bool);
    function isRecycleOpen()external pure returns(bool);
    function containsHolder(address _holder)external view returns(bool);
    function isAdmin(address _admin)external view returns(bool);
    function adminSize() external view returns (uint256);
    function totalSupply() external view returns(uint256);
    function reRecycleRate() external pure returns(uint256);
    function migrationTarget() external pure returns(address);
    function totalMigrated() external pure returns(uint256);
    function sizeHolder()external pure returns(uint256);

 }


interface ISutStore {
    function creator(address ctAddress)external view returns(address);
}


contract CtProposal is Ownable, Ecrecovery{

    using IterableSet for IterableSet.AddressSet;
    using SafeMath for uint256;

    struct Proposal {
        bool active;
        address market;
        address creator;
        uint8 stage;
        uint8 milestone;
        uint256[] reward;
        uint256[] deadline;
        address[] rewardCoin;
        address[] beneficiary;
        uint256[] vote;
        uint256 fee;
        mapping(uint8 => address[]) votedetails;
    }

    uint8 public ADMIN_NUMBER_KEY = 2;
    uint256 public proposalCount = 1;
    uint256 ONE_MILESTONE_FEE = 0.01 ether;

    address public SUT;
    address public feeAccount;
    address public exchange;
    address public marketOpration;
    
    bool public stopFlag;
    
    mapping(address => IterableSet.AddressSet) marketRecived;
    mapping(address => mapping(address => uint256)) public marketTokenBalance;
    mapping(address => mapping(address => mapping(address => uint256))) public donateInfo;
    mapping(uint256 => Proposal) private proposals;
    mapping(address => mapping(uint256 => mapping(uint8 => bool)))private isVote;
    mapping(address => mapping(address => uint256)) public marketCurrentReward;
    mapping(address => mapping(address => bool)) public isWithdraw;
    mapping(bytes32 => bool) public expireHash;

    ISutStore sutStore;
    ICoinStore coinStore;
    IAdmin admin;
   
    event RecivedDonate(address marketAddress, address donator, address tokenAddress, uint256 value);
    event NewProposal(uint256 _proposalCount, address _marketAddress, address _creator);
    event ModifierProposal(uint256 _proposalId);
    event TransferProposal(uint256 _proposalId, address _rawOwner, address _newOwner);
    event VoteForPropsoal(address _vote, uint256 _proposalId, uint8 _stage);
    

    constructor (address _sutStore, address _owner, address _sutToken, address _feeAccount, address _admin, address _exchange, address _opration) public Ownable(_owner){
        sutStore = ISutStore(_sutStore);
        SUT = _sutToken;
        feeAccount = _feeAccount;
        admin = IAdmin(_admin);
        exchange = _exchange;
        marketOpration = _opration;
    }

    modifier onlyStart() {
        require(stopFlag == false);
        _;
    }
    

    function setStop() public onlyOwner {
        require(stopFlag == false);
        stopFlag = true;
    }

    function reStart() public onlyOwner {
        require(stopFlag == true);
        stopFlag = false;
    }

    function setCoinStore(address _coinStore) public onlyOwner {
        coinStore = ICoinStore(_coinStore);
    }

/**********************************************************************************

*                                                                                *

* accept ETH And ERC20                                                            *

*                                                                                *

**********************************************************************************/
function donateCoinToProposal(address _token, address _donator, address _marketAddress, uint256 _value, uint256 _fee, uint256 timeStamp, bytes memory sign) public {
    require(admin.onlyAdmin(msg.sender));
    
    bytes32 signHash = keccak256(abi.encodePacked(_token, _donator, _marketAddress, _value, _fee,timeStamp)); 

    require(ecrecovery(signHash, sign) == _donator);

    require(!expireHash[signHash]);

    require(!CtStore(_marketAddress).dissolved());
    require(sutStore.creator(_marketAddress) != address(0));
    require(CtStore(_marketAddress).migrationTarget() == address(0));

    if(marketTokenBalance[_marketAddress][address(0)] == 0){
        marketRecived[_marketAddress].add(address(0));
    }

    coinStore.internalTransferFrom(_token, _donator, address(this), _value);
    coinStore.internalTransferFrom(address(0), _donator, feeAccount, _fee);

    marketTokenBalance[_marketAddress][address(0)] = marketTokenBalance[_marketAddress][address(0)].add(_value);
    donateInfo[_donator][_marketAddress][address(0)] = donateInfo[_donator][_marketAddress][address(0)].add(_value);

    expireHash[signHash] = true;

    emit RecivedDonate(_marketAddress,_donator, address(0), _value);
}

   function recivedSut(address sut, address _marketAddress, uint256 amount) public {
       require(msg.sender == exchange);

       marketTokenBalance[_marketAddress][sut] = marketTokenBalance[_marketAddress][sut].add(amount);
       
       marketRecived[_marketAddress].add(sut);
   }

   function withdrawToMarket(address token, address marketAddress, uint256 amount) public {
       require(msg.sender == marketOpration);

       coinStore.internalTransfer(token,marketAddress,amount);
   }

/**********************************************************************************

*                                                                                *

* Proposal   operation                                                    *

*   struct Proposal {
        bool active;
        address market;
        address creator;
        uint8 stage;
        uint8 milestone;
        uint256[] reward;
        uint256[] deadline;
        address[] rewardCoin;
        address payable[] beneficiary;
        uint256[] vote;
        mapping(uint8 => address[]) votedetails;
    }                                                     *

**********************************************************************************/
   function newProposal(uint8 _milestone, address _creator, address _marketAddress, uint256[] memory _reward, uint256[] memory _deadline, address[] memory _rewardCoin, address[] memory _beneficiary, uint256 fee, uint256 proposalFee, uint256 timeStamp, bytes memory sign)public onlyStart{
       require(admin.onlyAdmin(msg.sender));

       bytes32 signHash = keccak256(abi.encodePacked(_milestone, _creator, _marketAddress, fee, proposalFee,timeStamp)); 

       require(ecrecovery(signHash, sign) == _creator);

       require(!expireHash[signHash]);
       
       require(sutStore.creator(_marketAddress) != address(0));
       require(CtStore(_marketAddress).containsHolder(_creator));
       require(!CtStore(_marketAddress).dissolved());
       require(CtStore(_marketAddress).migrationTarget() == address(0));
       require(proposalFee >= ONE_MILESTONE_FEE * _milestone);
       
       require(_milestone == _reward.length);
       require(_milestone == _deadline.length);
       require(_milestone == _rewardCoin.length);
       require(_milestone == _beneficiary.length);

       checkProposal(_marketAddress, _rewardCoin, _reward);

       uint256[] memory _vote = new uint256[](_milestone);

       proposals[proposalCount] = Proposal(true, _marketAddress, _creator, 0, _milestone, _reward, _deadline, _rewardCoin, _beneficiary, _vote, proposalFee);

       proposalCount = proposalCount.add(1);

       coinStore.internalTransferFrom(address(0), _creator, feeAccount, fee);
       coinStore.internalTransferFrom(address(0),_creator,address(this),proposalFee);

       expireHash[signHash] = true;
       
       emit NewProposal(proposalCount.sub(1), _marketAddress, _creator);
       
   }

   function checkProposal(address _marketAddress, address[] memory _rewardCoin, uint256[] memory _reward) internal {

        for(uint256 i = 0; i < _rewardCoin.length; i++) {

           require(marketTokenBalance[_marketAddress][_rewardCoin[i]] != 0);

           uint256 afterCoinReward = marketCurrentReward[_marketAddress][_rewardCoin[i]].add(_reward[i]);

           marketCurrentReward[_marketAddress][_rewardCoin[i]] = marketCurrentReward[_marketAddress][_rewardCoin[i]].add(_reward[i]);

           require(afterCoinReward <= marketTokenBalance[_marketAddress][_rewardCoin[i]]);

           if (_rewardCoin[i] == SUT && CtStore(_marketAddress).reRecycleRate() > CtStore(_marketAddress).recycleRate()) {              

               uint256 preSut = CtStore(_marketAddress).totalSupply().mul(CtStore(_marketAddress).reRecycleRate().sub(CtStore(_marketAddress).recycleRate())).div(10 ** 18);

               require(afterCoinReward.add(preSut) <= marketTokenBalance[_marketAddress][_rewardCoin[i]]);
               
               
           }


       }
   }

   function transferProposal(uint256 _proposalId, address rawCreator, address newCreator, uint256 fee, bytes memory sign) public onlyStart {
       require(admin.onlyAdmin(msg.sender));

       bytes32 signHash = keccak256(abi.encodePacked(_proposalId, rawCreator, newCreator, fee)); 

       require(ecrecovery(signHash, sign) == rawCreator);

       require(!expireHash[signHash]);

       require(rawCreator == proposals[_proposalId].creator);
       
       require(CtStore(proposals[_proposalId].market).migrationTarget() == address(0));

       proposals[_proposalId].creator = newCreator;

       coinStore.internalTransferFrom(address(0), rawCreator, feeAccount, fee);

       expireHash[signHash] = true;

       emit TransferProposal(_proposalId,rawCreator, newCreator);
   }

   function getPropsoalStatus(uint256 _proposalId) public view returns(bool) {
       return proposals[_proposalId].active;
   } 

   function getProposalMarket(uint256 _proposalId) public view returns(address) {
       return proposals[_proposalId].market;
   }
   
   function getProposalCreator(uint256 _proposalId) public view returns(address) {
       return  proposals[_proposalId].creator;
   }

   function getProposalStage(uint256 _proposalId) public  view returns(uint8) {
       return  proposals[_proposalId].stage;
   }

   function getProposalMilestone(uint256 _proposalId) public  view returns(uint8) {
       return  proposals[_proposalId].milestone;
   }

   function getProposalReward(uint256 _proposalId) public view returns(uint256[] memory) {
       return  proposals[_proposalId].reward;
   }

   function getProposalDeadline(uint256 _proposalId) public view returns(uint256[] memory) {
       return  proposals[_proposalId].deadline;
   }

   function getProposalRewardCoin(uint256 _proposalId) public view returns(address[] memory) {
       return  proposals[_proposalId].rewardCoin;
   }

   function getProposalBeneficiary(uint256 _proposalId) public view returns(address[] memory) {
       return  proposals[_proposalId].beneficiary;
   }

   function getProposalVote(uint256 _proposalId, uint8 _stage) public view returns(uint256) {
       return proposals[_proposalId].vote[_stage];
   }

   function getProposalDetaials(uint256 _proposalId, uint8 _stage) public view returns(address[] memory) {
       return proposals[_proposalId].votedetails[_stage];
   }

   function getProposalFee(uint256 _proposalId) public view returns(uint256) {
       return proposals[_proposalId].fee;
   }

   function isVoteForProposal(address _voter, uint256 _proposalId, uint8 _milestone) public view returns(bool) {
       return isVote[_voter][_proposalId][_milestone];
   }
   

   function modifyProposal(uint256 _proposalId, address _creator, uint256[] memory _reward, uint256[] memory _deadline, address[] memory _rewardCoin, address[] memory _beneficiary, uint256 fee, bytes memory sign) public onlyStart{
       require(admin.onlyAdmin(msg.sender));

       bytes32 signHash = keccak256(abi.encodePacked(_proposalId, _creator, fee)); 

       require(!expireHash[signHash]);

       require(ecrecovery(signHash, sign) == _creator);

       require(_creator == proposals[_proposalId].creator);

       require(proposals[_proposalId].active);
       
       require(CtStore(proposals[_proposalId].market).migrationTarget() == address(0));

       

       address _marketAddress = proposals[_proposalId].market;

       changeNewProposal(_proposalId,_marketAddress,_creator,_reward,_deadline,_rewardCoin,_beneficiary);

    //    require(!CtStore(_marketAddress).dissolved());

    //    uint8 nowStage = proposals[_proposalId].stage;

    //    uint8 _milestone = proposals[_proposalId].milestone;

    //    checkModProposal(_proposalId,_marketAddress, _reward,_deadline, _rewardCoin,_beneficiary, nowStage, _milestone);

    //    Proposal memory s = proposals[_proposalId];

    //    uint256[] memory newVote = new uint256[](_milestone);

    //    for(uint8 i = 0; i <= nowStage; i++) {

    //        _reward[i] = s.reward[i];

    //        _deadline[i] = s.deadline[i];

    //        _rewardCoin[i] = s.rewardCoin[i];

    //        _beneficiary[i] = s.beneficiary[i];

    //        newVote = s.vote;

    //    }
       

    // //   Proposal memory np = Proposal(true, _marketAddress, _creator, nowStage, _milestone, _reward, _deadline, _rewardCoin, _beneficiary, newVote, proposals[_proposalId].fee);

    // // //   proposals[_proposalId] = np;

      coinStore.internalTransferFrom(address(0), _creator, feeAccount, fee);

      expireHash[signHash] = true;

       emit ModifierProposal(_proposalId);

    }
    
    
    function changeNewProposal(uint256 _proposalId, address _marketAddress, address _creator, uint256[] memory _reward, uint256[] memory _deadline, address[] memory _rewardCoin,address[] memory _beneficiary) private {
         require(!CtStore(_marketAddress).dissolved());

         Proposal memory s = proposals[_proposalId];

         uint8 nowStage = s.stage;

         uint8 milestone = s.milestone;

         uint256 _fee = s.fee;

         checkModProposal(_proposalId,_marketAddress, _reward,_deadline, _rewardCoin,_beneficiary, nowStage, milestone);

         uint256[] memory newVote = new uint256[](milestone);
           
        for(uint8 i = 0; i <= nowStage; i++) {

            _reward[i] = s.reward[i];

            _deadline[i] = s.deadline[i];

            _rewardCoin[i] = s.rewardCoin[i];

            _beneficiary[i] = s.beneficiary[i];

            newVote = s.vote;

        }

        Proposal memory np = Proposal(true, _marketAddress, _creator, nowStage, milestone, _reward, _deadline, _rewardCoin, _beneficiary, newVote, _fee);

        proposals[_proposalId] = np;

    }

    function checkModProposal(uint256 _proposalId, address _marketAddress, uint256[] memory _reward, uint256[] memory _deadline, address[] memory _rewardCoin, address[] memory  _beneficiary, uint8 nextStage, uint8 _milestone) internal {

       require(_milestone >= nextStage);
       require(_milestone == _reward.length);
       require(_milestone == _deadline.length);
       require(_milestone == _rewardCoin.length);
       require(_milestone == _beneficiary.length);
       

       //checkCoin
       address[] memory mrewardCoin = proposals[_proposalId].rewardCoin;

       uint256[] memory mreward = proposals[_proposalId].reward;

        for(uint256 i = nextStage; i < mrewardCoin.length; i++) {
           require(marketTokenBalance[_marketAddress][_rewardCoin[i]] != 0);

           marketCurrentReward[_marketAddress][_rewardCoin[i]] = marketCurrentReward[_marketAddress][_rewardCoin[i]].add(_reward[i]);
           marketCurrentReward[_marketAddress][mrewardCoin[i]] = marketCurrentReward[_marketAddress][mrewardCoin[i]].sub(mreward[i]);

           require(marketCurrentReward[_marketAddress][_rewardCoin[i]] <= marketTokenBalance[_marketAddress][_rewardCoin[i]]);
       }

   }

   function vote(uint256 _proposalId, address voter, uint256 fee, uint256 timeStamp, bytes memory sign)public onlyStart {
       require(admin.onlyAdmin(msg.sender));
       
       bytes32 signHash = keccak256(abi.encodePacked(_proposalId, voter, fee,timeStamp)); 

       require(!expireHash[signHash]);

       require(ecrecovery(signHash, sign) == voter);

       require(proposals[_proposalId].active);
       
       address marketAddress = proposals[_proposalId].market;
       require(CtStore(marketAddress).migrationTarget() == address(0));
       require(!CtStore(marketAddress).dissolved());

       uint8 nowStage = proposals[_proposalId].stage;

       if (nowStage == 0) {
           require (CtStore(marketAddress).isAdmin(voter) || proposals[_proposalId].votedetails[0].length > CtStore(marketAddress).adminSize().div(2));
           require (CtStore(marketAddress).containsHolder(voter));

       }else {
           require(CtStore(marketAddress).containsHolder(voter));
       }

       require(block.timestamp < proposals[_proposalId].deadline[nowStage]);

       require(!isVote[voter][_proposalId][nowStage]);

       uint256 voterBalance = coinStore.balanceOf(marketAddress, voter).add(Token(marketAddress).balanceOf(voter));

       proposals[_proposalId].vote[nowStage] = proposals[_proposalId].vote[nowStage].add(voterBalance);

       proposals[_proposalId].votedetails[nowStage].push(voter);

       isVote[voter][_proposalId][nowStage] = true;

       coinStore.internalTransferFrom(address(0), voter, feeAccount, fee);

       expireHash[signHash] = true;

       emit VoteForPropsoal(voter, _proposalId, nowStage);
   }

   function conclusionVote(uint256 _proposalId, address concluder, uint256 fee, uint256 timeStamp, bytes memory sign) public onlyStart {

       require(admin.onlyAdmin(msg.sender));
       
       bytes32 signHash = keccak256(abi.encodePacked(_proposalId, concluder, fee,timeStamp)); 

       require(!expireHash[signHash]);

       require(ecrecovery(signHash, sign) == concluder);

       require(proposals[_proposalId].active);

       address marketAddress = proposals[_proposalId].market;

       require(CtStore(marketAddress).migrationTarget() == address(0));

       uint8 nowStage = proposals[_proposalId].stage;

       require(block.timestamp > proposals[_proposalId].deadline[nowStage]);

       address token = proposals[_proposalId].rewardCoin[nowStage];

       if (nowStage == 0) {
           uint256 adminVote = proposals[_proposalId].votedetails[nowStage].length;

           if(adminVote > CtStore(marketAddress).adminSize().div(uint256(2))) {

               if(proposals[_proposalId].vote[nowStage] > CtStore(marketAddress).totalSupply().div(uint256(2))){

                  coinStore.internalTransfer(token,proposals[_proposalId].beneficiary[nowStage],proposals[_proposalId].reward[nowStage]);
              
            //    if(token == address(0)) {
            //        coinStore.internalTransfer(address(0),address(this),proposals[_proposalId].beneficiary[nowStage],proposals[_proposalId].reward[nowStage]);
            //        proposals[_proposalId].beneficiary[nowStage].transfer(proposals[_proposalId].reward[nowStage]);
            //    }else {
            //        Token(token).transfer(proposals[_proposalId].beneficiary[nowStage], proposals[_proposalId].reward[nowStage]);
            //    }

               marketTokenBalance[marketAddress][token] = marketTokenBalance[marketAddress][token].sub(proposals[_proposalId].reward[nowStage]);
               marketCurrentReward[marketAddress][token] = marketCurrentReward[marketAddress][token].sub(proposals[_proposalId].reward[nowStage]);

               proposals[_proposalId].stage += 1;
               
               }else{
                    proposalFailed(_proposalId, nowStage);
               }

           }else{
               proposalFailed(_proposalId, nowStage);
           }

       }else {
           uint256 _vote = proposals[_proposalId].vote[nowStage];

           if (_vote > CtStore(marketAddress).totalSupply().div(uint256(2))) {

               coinStore.internalTransfer(address(0),proposals[_proposalId].beneficiary[nowStage],proposals[_proposalId].reward[nowStage]);
            //    if(token == address(0)) {
            //        proposals[_proposalId].beneficiary[nowStage].transfer(proposals[_proposalId].reward[nowStage]);
            //    }else {
            //        Token(token).transfer(proposals[_proposalId].beneficiary[nowStage], proposals[_proposalId].reward[nowStage]);
            //    }

               marketTokenBalance[marketAddress][token] = marketTokenBalance[marketAddress][token].sub(proposals[_proposalId].reward[nowStage]);
               marketCurrentReward[marketAddress][token] = marketCurrentReward[marketAddress][token].sub(proposals[_proposalId].reward[nowStage]);

               proposals[_proposalId].stage += 1;
           }else{
               proposalFailed(_proposalId, nowStage);
           }
       }

       coinStore.internalTransferFrom(address(0),concluder,feeAccount,fee);

       coinStore.internalTransfer(address(0),concluder,ONE_MILESTONE_FEE);

       expireHash[signHash] = true;
   }

   function proposalFailed(uint256 _proposalId, uint8 _stage) private {
       proposals[_proposalId].active = false;

       uint8 remainMilestone = proposals[_proposalId].milestone - (_stage + 1);
       address _creator = proposals[_proposalId].creator;
       
       address _market = proposals[_proposalId].market;
       uint256[] memory _reward = proposals[_proposalId].reward;
       address[] memory _rewardCoin = proposals[_proposalId].rewardCoin;

       for(uint256 i = uint256(_stage); i < _reward.length; i++) {
           marketCurrentReward[_market][_rewardCoin[i]] = marketCurrentReward[_market][_rewardCoin[i]].sub(_reward[i]);
       }

       coinStore.internalTransfer(address(0),_creator, ONE_MILESTONE_FEE * remainMilestone);
   }


   function withDraw(address _marketAddress, address drawer, uint256 fee, uint256 timeStamp, bytes memory sign) public {
       require(admin.onlyAdmin(msg.sender));
       
       bytes32 signHash = keccak256(abi.encodePacked(_marketAddress, drawer, fee,timeStamp)); 

       require(!expireHash[signHash]);

       require(ecrecovery(signHash, sign) == drawer);

       require(CtStore(_marketAddress).containsHolder(drawer));
       require(CtStore(_marketAddress).dissolved());
       require(!isWithdraw[drawer][_marketAddress]);

       address[] memory tokens = marketRecived[_marketAddress].list();

       for (uint256 i = 0; i < tokens.length; i++) {
           uint256 value = marketTokenBalance[_marketAddress][tokens[i]].mul(coinStore.balanceOf(_marketAddress,drawer)).div(Token(_marketAddress).totalSupply());
           
           coinStore.internalTransfer(tokens[i], drawer, value);
        
       }

       isWithdraw[drawer][_marketAddress] = true;
       expireHash[signHash] = true;
   }

//    function withdrawForRecyRate(uint256 value) public {
//        require(sutStore.creator(msg.sender) != address(0));
//        require(marketTokenBalance[msg.sender][SUT] >= value);
//        require(CtStore(msg.sender).migrationTarget() == address(0));
       
//        coinStore.internalTransfer(SUT, address(this), msg.sender, value);
//        marketTokenBalance[msg.sender][SUT] = marketTokenBalance[msg.sender][SUT].sub(value);
//    }

//    function recycleTransfer(uint256 withdrawSut, address draw) public {
//        require(sutStore.creator(msg.sender) != address(0));
//        require(CtStore(msg.sender).migrationTarget() == address(0));
       
//        marketTokenBalance[msg.sender][SUT] = marketTokenBalance[msg.sender][SUT].add(value);
//    }

   function upgradeMarketExchange(address rawAddress, address newAddress, address upgrader, uint256 fee, uint256 timeStamp, bytes memory sign) public {
       require(CtStore(rawAddress).totalMigrated() == CtStore(rawAddress).sizeHolder());
       require(newAddress == CtStore(rawAddress).migrationTarget());

       require(admin.onlyAdmin(msg.sender));
       
       bytes32 signHash = keccak256(abi.encodePacked(rawAddress, newAddress, upgrader,fee,timeStamp)); 

       require(!expireHash[signHash]);

       require(ecrecovery(signHash, sign) == upgrader);

       address[] memory tokens = marketRecived[rawAddress].list();

       for (uint256 i = 0; i < tokens.length; i++) {
           marketTokenBalance[newAddress][tokens[i]] = marketTokenBalance[rawAddress][tokens[i]];
           marketTokenBalance[rawAddress][tokens[i]] = 0;
       }

       coinStore.internalTransferFrom(address(0),upgrader,feeAccount,fee);
   }

}

//proposal
//3
//
//["100000000000000000000","100000000000000000000","100000000000000000000"]
//["1568184617","1568185617","1568186617"]
//["0xF1899c6eB6940021C1aE4E9C3a8e29EE93704b03","0xF1899c6eB6940021C1aE4E9C3a8e29EE93704b03","0xF1899c6eB6940021C1aE4E9C3a8e29EE93704b03"]
//["0xc50fe093a29a69359c888ea7a4e5c6aa9b82d23b","0xc50fe093a29a69359c888ea7a4e5c6aa9b82d23b","0xc50fe093a29a69359c888ea7a4e5c6aa9b82d23b"]
// modify recycleRate

// migration


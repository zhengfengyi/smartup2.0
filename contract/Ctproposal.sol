pragma solidity >=0.4.21 <0.6.0;

import "./SafeMath.sol";
import "./IterableSet.sol";
import "./Ownable.sol";


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

interface Exchange {
    function balanceOf(address marketAddress, address owner)external view returns(uint256);
}

contract CtProposal is Ownable{

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
        address payable[] beneficiary;
        uint256[] vote;
        mapping(uint8 => address[]) votedetails;
    }

    uint256 public proposalCount = 0;
    address public SUT;
    
    bool public stopFlag;
    
    mapping(address => IterableSet.AddressSet) marketRecived;
    mapping(address => mapping(address => uint256)) public marketTokenBalance;
    mapping(address => mapping(address => mapping(address => uint256))) public donateInfo;
    mapping(uint256 => Proposal) private proposals;
    mapping(address => mapping(uint256 => mapping(uint8 => bool)))private isVote;
    mapping(address => mapping(address => uint256)) public marketCurrentReward;
    mapping(address => mapping(address => bool)) public isWithdraw;

    ISutStore sutStore;
    Exchange  ex;
   
    event RecivedDonate(address marketAddress, address donator, address tokenAddress, uint256 value);
    event NewProposal(uint256 _proposalCount, address _marketAddress, address _creator);
    

    constructor (address _sutStore, address _owner, address _sutToken) public Ownable(_owner){
        sutStore = ISutStore(_sutStore);
        SUT = _sutToken;
    }

    function ()external payable{

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

    function setExchange(address _exchange) public onlyOwner {
        ex = Exchange(_exchange);
    }

/**********************************************************************************

*                                                                                *

* accept ETH And ERC20                                                            *

*                                                                                *

**********************************************************************************/
function receiveApproval(address _owner, uint256 approvedAmount, address token, bytes calldata extraData) external{
    require(_owner != address(0));
    require(approvedAmount > 0);
    require(token !=  address(0));

    address market = bytesToAddress(extraData);

    require(!CtStore(market).dissolved());
    require(sutStore.creator(market) != address(0));
    require(CtStore(market).migrationTarget() == address(0));

    require(Token(token).transferFrom(_owner, address(this), approvedAmount));


    marketTokenBalance[market][token] = marketTokenBalance[market][token].add(approvedAmount);
    donateInfo[market][market][market] = donateInfo[market][market][market].add(approvedAmount);

}

function bytesToAddress(bytes memory bys) internal pure returns (address addr) {
    assembly {
      addr := mload(add(bys,20))
    } 
}

function toBytes(address a) internal pure returns (bytes memory b){
    assembly {
        let m := mload(0x40)
        a := and(a, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
        mstore(0x40, add(m, 52))
        b := m
    }
}


function donateETH(address marketAddress)public onlyStart payable{
    require(msg.value > 0);
    
    require(!CtStore(marketAddress).dissolved());
    require(sutStore.creator(marketAddress) != address(0));
    require(CtStore(marketAddress).migrationTarget() == address(0));

    if(marketTokenBalance[marketAddress][address(0)] == 0){
        marketRecived[marketAddress].add(address(0));
    }

    marketTokenBalance[marketAddress][address(0)] = marketTokenBalance[marketAddress][address(0)].add(msg.value);
    donateInfo[msg.sender][marketAddress][address(0)] = donateInfo[msg.sender][marketAddress][address(0)].add(msg.value);

    emit RecivedDonate(marketAddress, msg.sender, address(0), msg.value);
}

function donateERC20(address donator, address marketAddress, address erc20Address, uint256 value) public onlyStart{
    require(value > 0);
    require(!CtStore(marketAddress).dissolved());
    require(sutStore.creator(marketAddress) != address(0));
    require(CtStore(marketAddress).migrationTarget() == address(0));


    if (marketTokenBalance[marketAddress][erc20Address] == 0) {
        marketRecived[marketAddress].add(marketAddress);
    }

    require(Token(erc20Address).transferFrom(donator,address(this),value));

    marketTokenBalance[marketAddress][erc20Address] = marketTokenBalance[marketAddress][erc20Address].add(value);
    donateInfo[donator][marketAddress][erc20Address] = donateInfo[donator][marketAddress][erc20Address].add(value);

    emit RecivedDonate(marketAddress, donator, erc20Address, value);
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
   function newProposal(uint8 _milestone, address _marketAddress, uint256[] memory _reward, uint256[] memory _deadline, address[] memory _rewardCoin, address payable[] memory _beneficiary)public  onlyStart{
       require(sutStore.creator(_marketAddress) != address(0));
       require(CtStore(_marketAddress).containsHolder(msg.sender));
       require(!CtStore(_marketAddress).dissolved());
       require(CtStore(_marketAddress).migrationTarget() == address(0));
       
       require(_milestone == _reward.length);
       require(_milestone == _deadline.length);
       require(_milestone == _rewardCoin.length);
       require(_milestone == _beneficiary.length);

       checkProposal(_marketAddress, _rewardCoin, _reward);

       uint256[] memory _vote = new uint256[](_milestone);

       proposals[proposalCount] = Proposal(true, _marketAddress, msg.sender, 0, _milestone, _reward, _deadline, _rewardCoin, _beneficiary, _vote);

       proposalCount = proposalCount.add(1);
       
       emit NewProposal(proposalCount.sub(1), _marketAddress, msg.sender);
       
   }

   function checkProposal(address _marketAddress, address[] memory _rewardCoin, uint256[] memory _reward) internal {
        for(uint256 i = 0; i < _rewardCoin.length; i++) {

           require(marketTokenBalance[_marketAddress][_rewardCoin[i]] != 0);

           uint256 afterCoinReward = marketCurrentReward[_marketAddress][_rewardCoin[i]].add(_reward[i]);

           marketCurrentReward[_marketAddress][_rewardCoin[i]] = marketCurrentReward[_marketAddress][_rewardCoin[i]].add(_reward[i]);

           require(afterCoinReward <= marketTokenBalance[_marketAddress][_rewardCoin[i]]);

           if (_rewardCoin[i] == SUT) {
               if (CtStore(_marketAddress).reRecycleRate() > CtStore(_marketAddress).recycleRate()){

               uint256 preSut = CtStore(_marketAddress).totalSupply().mul(CtStore(_marketAddress).reRecycleRate().sub(CtStore(_marketAddress).recycleRate())).div(10 ** 18);

               require(afterCoinReward.add(preSut) <= marketTokenBalance[_marketAddress][_rewardCoin[i]]);
               }
               
           }


       }
   }

   function transferProposal(uint256 _proposalId, address newCreator) public onlyStart{
       require(msg.sender == proposals[_proposalId].creator);
       
       require(CtStore(proposals[_proposalId].market).migrationTarget() == address(0));

       proposals[_proposalId].creator = newCreator;

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

   function getProposalBeneficiary(uint256 _proposalId) public  view returns(address payable[] memory) {
       return  proposals[_proposalId].beneficiary;
   }

   function getProposalVote(uint256 _proposalId, uint8 _stage) public view returns(uint256) {
       return proposals[_proposalId].vote[_stage];
   }

   function getProposalDetaials(uint256 _proposalId, uint8 _stage) public view returns(address[] memory) {
       return proposals[_proposalId].votedetails[_stage];
   }

   function isVoteForProposal(address _voter, uint256 _proposalId, uint8 _milestone) public view returns(bool) {
       return isVote[_voter][_proposalId][_milestone];
   }
   

   function modifyProposal(uint256 _proposalId, uint8 _milestone, uint256[] memory _reward, uint256[] memory _deadline, address[] memory _rewardCoin, address payable[] memory _beneficiary) public onlyStart{
       require(msg.sender == proposals[_proposalId].creator);
       require(proposals[_proposalId].active);
       require(CtStore(proposals[_proposalId].market).migrationTarget() == address(0));

       address _marketAddress = proposals[_proposalId].market;

       require(!CtStore(_marketAddress).dissolved());

       checkModProposal(_proposalId, _marketAddress, _milestone, _reward,_deadline, _rewardCoin, _beneficiary);

       uint8 nowStage = proposals[_proposalId].stage;

       Proposal memory s = proposals[_proposalId];

       uint256[] memory newVote = new uint256[](_milestone);

       for(uint8 i = 0; i <= nowStage; i++) {

           _reward[i] = s.reward[i];

           _deadline[i] = s.deadline[i];

           _rewardCoin[i] = s.rewardCoin[i];

           _beneficiary[i] = s.beneficiary[i];

           newVote = s.vote;

       }

       Proposal memory np = Proposal(true, _marketAddress, msg.sender, nowStage, _milestone, _reward, _deadline, _rewardCoin, _beneficiary, newVote);

       proposals[_proposalId] = np;
    }

    function checkModProposal(uint256 _proposalId, address _marketAddress, uint8 _milestone, uint256[] memory _reward, uint256[] memory _deadline, address[] memory _rewardCoin, address payable[] memory  _beneficiary) internal {
       uint8 nextStage =  proposals[_proposalId].stage + 1;

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

   function vote(uint256 _proposalId)public onlyStart {
       require(proposals[_proposalId].active);
       
       address marketAddress = proposals[_proposalId].market;
       require(CtStore(marketAddress).migrationTarget() == address(0));
       require(!CtStore(marketAddress).dissolved());

       uint8 nowStage = proposals[_proposalId].stage;

       if (nowStage == 0) {
           require (CtStore(marketAddress).isAdmin(msg.sender) || proposals[_proposalId].votedetails[0].length > CtStore(marketAddress).adminSize().div(2));
           require (CtStore(marketAddress).containsHolder(msg.sender));

       }else {
           require(CtStore(marketAddress).containsHolder(msg.sender));
       }

       require(block.timestamp < proposals[_proposalId].deadline[nowStage]);

       require(!isVote[msg.sender][_proposalId][nowStage]);

       uint256 voterBalance = ex.balanceOf(marketAddress, msg.sender).add(Token(marketAddress).balanceOf(msg.sender));

       proposals[_proposalId].vote[nowStage] = proposals[_proposalId].vote[nowStage].add(voterBalance);

       proposals[_proposalId].votedetails[nowStage].push(msg.sender);

       isVote[msg.sender][_proposalId][nowStage] = true;
   }

   function conclusionVote(uint256 _proposalId) public onlyStart {
       require(proposals[_proposalId].active);

       address marketAddress = proposals[_proposalId].market;

       require(CtStore(marketAddress).migrationTarget() == address(0));

       uint8 nowStage = proposals[_proposalId].stage;

       require(block.timestamp > proposals[_proposalId].deadline[nowStage]);

       address token = proposals[_proposalId].rewardCoin[nowStage];

       if (nowStage == 0) {
           uint256 adminVote = proposals[_proposalId].votedetails[nowStage].length;

           if(adminVote > CtStore(marketAddress).adminSize().div(2)) {

               if(proposals[_proposalId].vote[nowStage] > CtStore(marketAddress).totalSupply().div(2)){
              
               if(token == address(0)) {
                   proposals[_proposalId].beneficiary[nowStage].transfer(proposals[_proposalId].reward[nowStage]);
               }else {
                   Token(token).transfer(proposals[_proposalId].beneficiary[nowStage], proposals[_proposalId].reward[nowStage]);
               }

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

           if (_vote > CtStore(marketAddress).totalSupply().div(2)) {
               if(token == address(0)) {
                   proposals[_proposalId].beneficiary[nowStage].transfer(proposals[_proposalId].reward[nowStage]);
               }else {
                   Token(token).transfer(proposals[_proposalId].beneficiary[nowStage], proposals[_proposalId].reward[nowStage]);
               }

               marketTokenBalance[marketAddress][token] = marketTokenBalance[marketAddress][token].sub(proposals[_proposalId].reward[nowStage]);
               marketCurrentReward[marketAddress][token] = marketCurrentReward[marketAddress][token].sub(proposals[_proposalId].reward[nowStage]);

               proposals[_proposalId].stage += 1;
           }else{
               proposalFailed(_proposalId, nowStage);
           }
       }
   }

   function proposalFailed(uint256 _proposalId, uint8 _stage) private {
       proposals[_proposalId].active = false;
       
       address _market = proposals[_proposalId].market;
       uint256[] memory _reward = proposals[_proposalId].reward;
       address[] memory _rewardCoin = proposals[_proposalId].rewardCoin;

       for(uint256 i = uint256(_stage); i < _reward.length; i++) {
           marketCurrentReward[_market][_rewardCoin[i]] = marketCurrentReward[_market][_rewardCoin[i]].sub(_reward[i]);
       }
   }


   function withDraw(address _marketAddress) public {
       require(CtStore(_marketAddress).containsHolder(msg.sender));
       require(CtStore(_marketAddress).dissolved());
       require(!isWithdraw[msg.sender][_marketAddress]);

       address[] memory tokens = marketRecived[_marketAddress].list();

       for (uint256 i = 0; i < tokens.length; i++) {
           uint256 value = marketTokenBalance[_marketAddress][tokens[i]].mul(ex.balanceOf(_marketAddress, msg.sender)).div(Token(_marketAddress).totalSupply());
           if(tokens[i] == address(0)) {

               msg.sender.transfer(value);

           }else {
               Token(tokens[i]).transfer(msg.sender,value);
           }
       }

       isWithdraw[msg.sender][_marketAddress] = true;
   }

   function withdrawForRecyRate(uint256 value) public {
       require(sutStore.creator(msg.sender) != address(0));
       require(marketTokenBalance[msg.sender][SUT] >= value);
       require(CtStore(msg.sender).migrationTarget() == address(0));

       Token(address(SUT)).transfer(msg.sender, value);
   }

   function upgradeMarketExchange(address rawAddress, address newAddress)public {
       require(CtStore(rawAddress).totalMigrated() == CtStore(rawAddress).sizeHolder());
       require(newAddress == CtStore(rawAddress).migrationTarget());

       address[] memory tokens = marketRecived[rawAddress].list();

       for (uint256 i = 0; i < tokens.length; i++) {
           marketTokenBalance[newAddress][tokens[i]] = marketTokenBalance[rawAddress][tokens[i]];
           marketTokenBalance[rawAddress][tokens[i]] = 0;
       }
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


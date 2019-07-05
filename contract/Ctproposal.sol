pragma solidity >=0.4.21 <0.6.0;

import './IERC20.sol';
import './SafeMath.sol';

contract CtProposal {
    using SafeMath for uint256;

    uint256 constant MINEXCHANGE_CT = 10 ** 16;

    struct Proposal {
        address  ctAddress;

        uint256  validTime; //validity 3 days;

        uint256[] score;     //choice vote count;

        address[] voters;

        address   origin; 

    }
    
    mapping(bytes32 => Proposal)  proposalId;

    mapping(address => mapping(bytes32 => uint256))  perProposalVoterCt;

    mapping(bytes32 => bool) public isVoterWithdraw;

    mapping(address => bytes32[]) public ctProposal;
    

    event NewProposal(address _ctAddress, address _proposer, bytes32 _proId);
    
    event NewVoter(address _ctAddress, uint8 _choice, uint256 _ct, address _voter, bytes32 _proId);

    event WithDraw(address _ctAddress, address _drawer, uint256 _totoal, bytes32 _proId);

    

    function propose(address ctAddress, uint8 choiceNum, uint8 validTime) external returns (bytes32 _proId) {

        require(IERC20(ctAddress).balanceOf(msg.sender) != 0);

        require( 2 <= choiceNum  && choiceNum <= 5, "proposal must in 2 - 5!");

        require(validTime == 3 || validTime == 5 || validTime == 7);

        _proId = _propose(ctAddress, choiceNum, validTime);

    }

    function _propose(address _ctAddress, uint8 _choiceNum, uint8 _validTime) private returns (bytes32 _proposalId) {
        uint256 time;

        if (_validTime == 7) {
            //time = 7 days;
            time = 7 minutes;
        }else if(_validTime == 3) {
            //time = 3 days;
            time = 3 minutes;
        }else{
            //time = 5 days;
            time = 5 minutes;
        }

        _proposalId = keccak256(abi.encodePacked(blockhash(block.number - 1), msg.sender, now));

        uint256[] memory _score = new uint256[](uint256(_choiceNum));

        address[] memory _voters = new address[](uint256(0));

        Proposal memory newProposal = Proposal(_ctAddress, now + time, _score, _voters, msg.sender);

        proposalId[_proposalId] = newProposal;

        ctProposal[_ctAddress].push(_proposalId); 

        emit NewProposal(address(this), msg.sender, _proposalId);

    }

    function voteForProposal(address ctAddress, uint8 mychoice, uint256 ctAmount, bytes32 _proposalId) external {
        require(ctAmount >= MINEXCHANGE_CT && ctAmount % MINEXCHANGE_CT == 0);

        require(now <= proposalId[_proposalId].validTime, "more than voting period!");

        require(IERC20(ctAddress).allowance(msg.sender, address(this)) > ctAmount, "not enough ct!");

        require(1 <= mychoice && mychoice <= proposalId[_proposalId].score.length);

        IERC20(ctAddress).transferFrom(msg.sender,address(this),ctAmount);

        if (perProposalVoterCt[msg.sender][_proposalId] == 0) {

             proposalId[_proposalId].voters.push(msg.sender);

             perProposalVoterCt[msg.sender][_proposalId] = ctAmount;

        }else {
             perProposalVoterCt[msg.sender][_proposalId] = perProposalVoterCt[msg.sender][_proposalId].add(ctAmount);
        }

        // if(voterInfo[msg.sender][_proposalId].length == 0) {
        //     // when this voter never vote for this propose
        //     uint256[] memory myInfo = new uint256[](proposalId[_proposalId].score.length);
           
        //     voterInfo[msg.sender][_proposalId] = myInfo;

        //     voterInfo[msg.sender][_proposalId][mychoice - 1] = ctAmount;
            
        //     proposalId[_proposalId].voters.push(msg.sender);

        //     perProposalVoterCt[msg.sender][_proposalId] = ctAmount;

        // }else if(voterInfo[msg.sender][_proposalId][mychoice - 1] == 0){
        //     //when this voter never vote for this choice of this propose
        //     voterInfo[msg.sender][_proposalId][mychoice - 1] = ctAmount;

        //     perProposalVoterCt[msg.sender][_proposalId] = perProposalVoterCt[msg.sender][_proposalId].add(ctAmount);

        // }else{
        //    // when this voter have already vote for this choice of this propose
        //     voterInfo[msg.sender][_proposalId][mychoice - 1] = voterInfo[msg.sender][_proposalId][mychoice - 1].add(ctAmount);
        //     perProposalVoterCt[msg.sender][_proposalId] = perProposalVoterCt[msg.sender][_proposalId].add(ctAmount);
        // }

        // add the vote for this choice;
        proposalId[_proposalId].score[mychoice - 1] = proposalId[_proposalId].score[mychoice - 1].add(ctAmount);

        emit NewVoter(address(this), mychoice, ctAmount, msg.sender, _proposalId);

    }

    function withdrawProposalCt(bytes32 _proposalId)external{
        //this proprose is exist
        require(proposalId[_proposalId].validTime != 0);
        // time is up
        require(now > proposalId[_proposalId].validTime, "proposal still in voting now!");
        // not withdraw yet
        require(isVoterWithdraw[_proposalId] == false, "you are alreday withdraw!");
        //count the withdraw ct
        uint256 total = 0;

        for(uint256 i = 0; i < proposalId[_proposalId].voters.length; i++ ){

        uint256 myCt = perProposalVoterCt[proposalId[_proposalId].voters[i]][_proposalId];

        delete perProposalVoterCt[proposalId[_proposalId].voters[i]][_proposalId];

        //_balances[proposalId[_proposalId].voters[i]] = _balances[proposalId[_proposalId].voters[i]].add(myCt);

        //_balances[address(this)] = _balances[address(this)].sub(myCt);

        IERC20(proposalId[_proposalId].ctAddress).transfer(proposalId[_proposalId].voters[i], myCt);

        total = total.add(myCt);     

        }

        isVoterWithdraw[_proposalId] = true;

        emit WithDraw(address(this), msg.sender, total, _proposalId);      

    }

    function getCtAddress(bytes32 _proposalId)external view returns(address _ctAddress){

        _ctAddress = proposalId[_proposalId].ctAddress;
        
    }

    function getValidTime(bytes32 _proposalId)external view returns(uint256 _validTime){
        _validTime = proposalId[_proposalId].validTime;
    }

    function getScore(bytes32 _proposalId)external view returns(uint256[] memory voteDetails){
        voteDetails = proposalId[_proposalId].score;
    }

    function getVoters(bytes32 _proposalId)external view returns(address[] memory _voters){
        _voters = proposalId[_proposalId].voters;
    }

    function getOrigin(bytes32 _proposalId)external view returns(address _origin) {
        _origin = proposalId[_proposalId].origin;
    }
}
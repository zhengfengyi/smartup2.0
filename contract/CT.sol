pragma solidity >=0.4.21 <0.6.0;



import "./ERC20.sol";

import "./ISmartUp.sol";

import "./CtConfig.sol";

import "./IterableSet.sol";


/**

 * @title CT

 */

interface ExStoreInterface {
    function addTokenBalance(address token, address owner, uint256 amount)external;
}

interface CtSetSut {
    function migrateSetSut(uint256 setTradeSut, uint256 setPaidSut, uint256 supplyAmount) external;
}


contract CT is ERC20, CtConfig{

    IterableSet.AddressSet private _jurors; 

    address public creator;

    address public ctMiddleware;

    address public exImpl;

    address public exStore;

    bool public isInnit;

    bool public isInFirstPeriod;

    uint256 public rate;

    uint8 public lastPercent;






    uint8[] private _jurorsVote;



    ISmartUp private _smartup; 

    uint8 public ballots; 

    uint256 public proposedPayoutAmount;

    // totalTraderSut = balanceOf(this) - totalPaidSut

    uint256 public totalTraderSut; 

    uint256 public totalPaidSut;

    uint256 private votingStart;

    bool public payoutNotRequested;

    bool public dissolved;

    modifier whenTrading() {

        require(payoutNotRequested && !dissolved);

        _;

    }

    event InnitCtmarket(address _ctAddress, address _initer, uint256 _supply, uint256 _rate, uint8 _lastPercent);

    event BuyCt(address _ctAddress, address _buyer, uint256 _setSut, uint256 _costSut, uint256 _ct);

    event SellCt(address _ctAddress, address _sell, uint256 _sut, uint256 _ct);

    event ProposePayout(address _ctAddress, address _proposer, uint256 _amount);

    event JurorVote(address _ctAddress, address _juror, bool _approve);

    event DissolveMarket(address _ctAddress,  uint256 _sutAmount);

    event CtConclude(address _ctAddress, uint256 _sutAmount, bool _success);

    event MigrationTransferSut(address _migrateTarget, uint256 _balance);

    event MigrationSetSut(address _migrationFrom, uint256 _setTradeSut, uint256 _setPaidSut,uint256 _supplyAmount);

    constructor(address owner, address marketCreator, address _storeAddress, address _ctMiddleware, address _exStore, address _exImpl) public Pausable(owner, false) {

        creator = marketCreator;

        payoutNotRequested = true;

        isInFirstPeriod = true;

        exImpl = _exImpl;

        exStore = _exStore;

        _smartup = ISmartUp(_storeAddress);

        ctMiddleware = _ctMiddleware;

    }


    function initCtMarket(string memory _name, string memory _symbol, uint256 _supply, uint256 _rate, uint8 _lastPercent)public{
        require(isInnit == false);
        require(msg.sender == creator);

        name = _name;
        symbol = _symbol;
        _totalSupply = _supply;
        rate = _rate;
        lastPercent = _lastPercent;

        _balances[exStore] = _supply;

        ExStoreInterface(exStore).addTokenBalance(address(this), exStore, _supply);

        emit InnitCtmarket(address(this), msg.sender, _supply, _rate, _lastPercent);
    }


    function finishFirstPeriod()external{
        require(msg.sender == exImpl);

        isInFirstPeriod = false;
    }


    function setDissolved()external{
        require(msg.sender == ctMiddleware);

        dissolved = true;
    }

    
    function receiveApproval(address sutOwner, uint256 approvedSutAmount, address token, bytes calldata extraData) external {

        require(msg.sender == address(SUT));

        require(token == address(SUT));

        buy(sutOwner, approvedSutAmount, bytesToUint256(extraData, 0));

    }


    // Utility function to convert bytes type to uint256. Noone but this contract can call this function.
    function bytesToUint256(bytes memory input, uint offset) internal pure returns (uint256 output) {

        assembly {output := mload(add(add(input, 32), offset))}

    }


    function finalizeMigration(address tokenHolder, uint256 migratedAmount) internal pure {

        tokenHolder;

        migratedAmount;

    }

    /**********************************************************************************

     *                                                                                *

     * payout session                                                                 *

     *                                                                                *

     **********************************************************************************/

    function proposePayout(uint256 amount) external {

        require(msg.sender == creator);

        require(payoutNotRequested);

        // make sure the market has enough sut to withdraw

        require(amount <= totalTraderSut.sub(totalPaidSut));

        require(amount <= SUT.balanceOf(address(this)));

        drawJurors(msg.sender);

        proposedPayoutAmount = amount;

        votingStart = now;

        payoutNotRequested = false;

        emit ProposePayout(address(this), msg.sender, amount);

    }


    function votingPeriod() external view returns (uint256 start, uint256 end) {

        if (votingStart == 0) {

            start = 0;

            end = 0;

        } else {

            start = votingStart;

            end = votingStart.add(PAYOUT_VOTING_PERIOD);

        }

    }


    function drawJurors(address seeder) private {

        require(_tokenHolders.size() >= JUROR_COUNT, "Not enough remaining members to choose from");

        uint256 seed = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), seeder)));

        while (_jurors.size() < JUROR_COUNT) {

            uint256 index = seed % _tokenHolders.size();

            // make sure the member is neither a juror nor a flagger

            address holder = _tokenHolders.at(index);

            while (_jurors.contains(holder)) {

                holder = _tokenHolders.at(++index % _tokenHolders.size());

            }

            _jurors.add(holder);

            _jurorsVote.push(0);

            seed = uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), seeder, index)));

        }
        // state = State.Voting;

    }


    function jurors() external view returns (address[] memory) {

        return _jurors.list();

    }

    function jurorVotes() external view returns (uint8[] memory) {

        return _jurorsVote;

    }


    function vote(bool approve) external {

        require(now - votingStart <= PAYOUT_VOTING_PERIOD);

        uint256 pos = _jurors.position(msg.sender);

        require(pos != 0);

        if (_jurorsVote[pos - 1] == 0) {

            ++ballots;

        }

        // should have been initialized

        _jurorsVote[pos - 1] = approve ? 1 : 2;

        emit JurorVote(address(this), msg.sender, approve);

    }


    function conclude() external {

        require(ballots == JUROR_COUNT || now - votingStart > PAYOUT_VOTING_PERIOD, "Voting still in process");

        uint256 aye = 0;

        uint256 nay = 0;

        for (uint256 i = 0; i < JUROR_COUNT; ++i) {

            if (_jurorsVote[i] == 2) {

                nay = nay.add(_balances[_jurors.at(i)]);

            } else if (_jurorsVote[i] == 1) {

                aye = aye.add(_balances[_jurors.at(i)]);

            }

        }

        if (aye > nay) {

            SUT.transfer(creator, proposedPayoutAmount);

            totalPaidSut = totalPaidSut.add(proposedPayoutAmount);

            emit CtConclude(address(this), proposedPayoutAmount, true);

        }else{
            emit CtConclude(address(this), proposedPayoutAmount, false);
        }

        // cleanup once concluded
        ballots = 0;

        proposedPayoutAmount = 0;

        _jurors.destroy();

        delete _jurorsVote;

        votingStart = 0;

        payoutNotRequested = true;
       
    }


    function dissolve() external returns(bool) {

        require(msg.sender == ctMiddleware);

        require(dissolved == true);

        // refund token _tokenHolders, TODO: split into multiple steps

        uint256 sutBalance = SUT.balanceOf(address(this));

        if (sutBalance > 0 && _totalSupply > 0) {

            for (uint256 i = 0; i < _tokenHolders.size(); ++i) {

                uint256 refundAmount = sutBalance.mul(_balances[_tokenHolders.at(i)]).div(_totalSupply);

                _balances[_tokenHolders.at(i)] = 0;

                SUT.transfer(_tokenHolders.at(i), refundAmount);

                NTT.lowerCredit(_tokenHolders.at(i), LOWERSCORE);

            }

        }

        _totalSupply = 0;

        emit DissolveMarket(address(this),  sutBalance);

        return true;

    }


    /**********************************************************************************

     *                                                                                *

     * trading session                                                                *

     *                                                                                *

     **********************************************************************************/

    function buy(address buyer, uint256 approvedSutAmount, uint256 ctAmount) private whenTrading {

        require(ctAmount >= MINEXCHANGE_CT && ctAmount % MINEXCHANGE_CT == 0);

        uint256 i = _totalSupply.add(ONE_CT);
        uint256 j = i.add(ctAmount);

        uint256 tradedSut = uint256(rateCalcSut.calcSut(i,j));

        require(approvedSutAmount >= tradedSut);

        require(SUT.transferFrom(buyer, address(this), tradedSut));

        _totalSupply = _totalSupply.add(ctAmount);

        _balances[buyer] = _balances[buyer].add(ctAmount);

        totalTraderSut = totalTraderSut.add(tradedSut);

        _tokenHolders.add(buyer);

        _smartup.addMember(buyer);

        emit BuyCt(address(this), buyer, approvedSutAmount, tradedSut, ctAmount);

    }

    function sell(uint256 ctAmount) public {

        _sell(msg.sender, ctAmount);
         
    }

    function _sell(address seller, uint256 ctAmount) private whenTrading {

        require(ctAmount >= MINEXCHANGE_CT && ctAmount % MINEXCHANGE_CT == 0);

        require(_totalSupply >= ctAmount);

        require(_balances[seller] >= ctAmount);
        

        uint256 j = _totalSupply.add(ONE_CT);

        uint256 i = j.sub(ctAmount);

        uint256 tradedSut = uint256(rateCalcSut.calcSut(i,j));
        
        uint256 exchangeSut = tradedSut.mul(SUT.balanceOf(address(this))).div(totalTraderSut);

        if (exchangeSut > SUT.balanceOf(address(this))) {
            SUT.transfer(seller, SUT.balanceOf(address(this)));
        }else{
            SUT.transfer(seller, exchangeSut);
        }

        _totalSupply = _totalSupply.sub(ctAmount);

        _balances[seller] = _balances[seller].sub(ctAmount);
        
        totalTraderSut = totalTraderSut.sub(tradedSut);
        
        if (_balances[seller] == 0) {

            _tokenHolders.remove(seller);

        }

        emit SellCt(address(this), seller, tradedSut, ctAmount);

    }


    function bidQuote(uint256 ctAmount) public view returns (uint256) {

        require(ctAmount >= MINEXCHANGE_CT && ctAmount % MINEXCHANGE_CT == 0);

        uint256 i = _totalSupply.add(ONE_CT);

        uint256 j = i.add(ctAmount);

        return uint256(rateCalcSut.calcSut(i,j));

    }

    function askQuote(uint256 ctAmount) public view returns (uint256) {

        require(ctAmount >= MINEXCHANGE_CT && ctAmount % MINEXCHANGE_CT == 0);

        require(_totalSupply >= ctAmount);

        uint256 j = _totalSupply.add(ONE_CT);

        uint256 i = j.sub(ctAmount);

        return uint256(rateCalcSut.calcSut(i,j)).mul(SUT.balanceOf(address(this))).div(totalTraderSut);

    }

    //migration from
    function migrateFrom(address from, uint256 amount) external {
        require(msg.sender == migrationFrom);

        _balances[from] = amount;

        _tokenHolders.add(from);
        
        _smartup.addMember(from);

    }

    function migrateTransferSut()external whenMigrating onlyOwner {
        uint256 sutAmount = SUT.balanceOf(address(this));

        require(migrationTarget != address(0));

        SUT.transfer(migrationTarget, sutAmount);

        CtSetSut(migrationTarget).migrateSetSut(totalTraderSut, totalPaidSut, _totalSupply);

        emit MigrationTransferSut(migrationTarget,sutAmount);
    }

    function migrateSetSut(uint256 _setTradeSut, uint256 _setPaidSut, uint256 _supplyAmount)external{
        require(msg.sender == migrationFrom);

        totalTraderSut = _setTradeSut;

        totalPaidSut = _setPaidSut;

        _totalSupply = _supplyAmount;

        emit MigrationSetSut(migrationFrom, _setTradeSut, _setPaidSut, _supplyAmount);
    }

}
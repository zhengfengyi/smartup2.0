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

    using IterableSet for IterableSet.AddressSet;
    
    string public name;
    string public symbol;
   
    IterableSet.AddressSet private _jurors; 

    IterableSet.AddressSet private _tokenHolders;

    address public creator;

    address public ctMiddleware;

    address public exImpl;

    address public exStore;

    bool public isInFirstPeriod;

    bool public isOver = true;

    uint256 public rate;

    uint256 public lastRate;

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

    event BuyCt(address _ctAddress, address _buyer, uint256 _setSut, uint256 _costSut, uint256 _ct);

    event SellCt(address _ctAddress, address _sell, uint256 _sut, uint256 _ct);

    event ProposePayout(address _ctAddress, address _proposer, uint256 _amount);

    event JurorVote(address _ctAddress, address _juror, bool _approve);

    event DissolveMarket(address _ctAddress,  uint256 _sutAmount);

    event CtConclude(address _ctAddress, uint256 _sutAmount, bool _success);

    event MigrationTransferSut(address _migrateTarget, uint256 _balance);

    event MigrationSetSut(address _migrationFrom, uint256 _setTradeSut, uint256 _setPaidSut,uint256 _supplyAmount);

    constructor(address owner, address marketCreator, address _storeAddress, address _ctMiddleware, address _exStore, string memory _name, string memory _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate) public Pausable(owner, false) {

        creator = marketCreator;

        payoutNotRequested = true;

        isInFirstPeriod = true;

        _smartup = ISmartUp(_storeAddress);

        ctMiddleware = _ctMiddleware;

        name = _name;

        symbol = _symbol;

        _totalSupply = _supply;

        rate = _rate;

        lastRate = _lastRate;

        _balances[_exStore] = _supply;

    }


    function finishFirstPeriod()external{
        require(msg.sender == ctMiddleware);

        isInFirstPeriod = false;
    }

    function _addHolder(address _holder)external{
        require(msg.sender == ctMiddleware);

        _tokenHolders.add(_holder);

        _smartup.addMember(_holder);
    }

    function _removeHolder(address _holder)external {
        require(msg.sender == ctMiddleware);

        _tokenHolders.remove(_holder);
    }


    function setDissolved()external{
        require(msg.sender == ctMiddleware);

        dissolved = true;
    }


    /**********************************************************************************

     *                                                                                *

     * First Period Buy Ct session                                                                 *

     *                                                                                *

     **********************************************************************************/
    
    /**********************************************************************************

     *                                                                                *

     * payout session                                                                 *

     *                                                                                *

     **********************************************************************************/














}
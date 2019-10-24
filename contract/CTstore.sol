pragma solidity >=0.4.21 <0.6.0;

import "./ISmartUp.sol";
import "./IterableSet.sol";
import "./SafeMath.sol";


interface GetToken {
    function ctWithdrawSutToPro(uint256 _value)external;
    function balanceOf(address _token, address _owner)external view returns(uint256);
}

interface MigrationTarget {
    function migrateFrom(address from, uint256 amount) external;
}

interface Proposal {
    function marketTokenBalance(address _market, address _token) external view returns(uint256);
    function marketCurrentReward(address _market, address _token) external view returns(uint256);
    function withdrawForRecyRate(uint256 amountSut) external;
    function recycleTransfer(uint256 withdrawSut) external;
}



contract CTstore {
    using IterableSet for IterableSet.AddressSet;
    using SafeMath for uint256;

    uint8 public decimals = 18;

    string public name;
    string public symbol;
    
    // address public SUT = ;
    address public coinStore;
    address public creator;
    address public ctImpl;
    address public proposal;
    //0x6095d57bF5cAeA98d6A099BDE5B42704053f8E3b
    address public SUT = address(0xF1899c6eB6940021C1aE4E9C3a8e29EE93704b03);
    //address public SUT = address(0xAB5c5aC1ecCd8b27De3FB95aD679653D43821a52);

    // Target contract
    address public migrationTarget = address(0);
    address public migrationFrom = address(0);
    uint256 public totalMigrated;

    
    bool public dissolved;
    bool public isRecycleOpen = true;
    bool public isInFirstPeriod;
    bool public notSelloutDissolved;
    
    uint8 public upgradeState; //normal, prepareUpgrade, upGradeing, finishedUpgrade;

    // bool public isWithdraw;
    
    uint256 public totalSupply;
    uint256 public exchangeRate;
    uint256 public recycleRate;
    uint256 public createTime;
    uint256 public closingTime;
    uint256 constant DECIMALS_RATE = 10 ** 18;

    uint256 public reRecycleRate;
    uint256 public recycleStart;
    uint256 public recyclePeriod = 10 minutes;
    uint256 public recycleFee;

    IterableSet.AddressSet private tokenHolders;
    // IterableSet.AddressSet private recivedToken;
    IterableSet.AddressSet private admin;
    IterableSet.AddressSet private adminVote;

    ISmartUp private smartup;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => mapping(address => uint256)) public honorDonation;

    
    
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event StartMigration(address _target);
    event WithdrawToken(address _token, uint256 _value);


    constructor(address _creator, address _ctImpl, address _smartupStore, address _coinstore, string memory _name, string memory _symbol, uint256 _totalSupply, uint256 _exchangeRate, uint256 _recycleRate, uint256 _closingTime, address _proposal)public {
        creator = _creator;
        ctImpl = _ctImpl;
        coinStore = _coinstore;
        name = _name;
        symbol = _symbol;
        totalSupply = _totalSupply;
        exchangeRate = _exchangeRate;
        recycleRate = _recycleRate;
        smartup = ISmartUp(_smartupStore);
        createTime = now;
        closingTime = _closingTime;
        balanceOf[_coinstore] = _totalSupply;

        if (_totalSupply != 0) {
            isInFirstPeriod = true;
        }

        admin.add(_creator);
        proposal = _proposal;
        
    }

    modifier onlyImpl(){
        require(msg.sender == ctImpl);
        _;
    }

/**********************************************************************************

*                                                                                *

* upgrade,  recycle, creator
  newMarket, setMigrratefFrom, setMigration, migragtion;                                                      *

*                                                                                *

**********************************************************************************/   
    modifier whenMigrationUnstarted() {
        require(migrationTarget == address(0));
        _;
    }

    /**
     * @dev modifier to allow actions only when the migration is not started
     */
    modifier whenMigrating() {
        require(migrationTarget != address(0) && totalMigrated < tokenHolders.size());
        _;
    }

    /**
     * @dev called by the owner to start migration, triggers stopped state
     * @param target The address of the MigrationTarget contract
     * 
     * TODO: maybe we should add logic to make sure target is correct, like checking whether it's a contract
     * 
     */


    function startMigration(address target) external whenMigrationUnstarted onlyImpl{
        require(target != address(0));
        require(target != address(this));

        migrationTarget = target;
        // make sure token holders list won't be updated during migration
        tokenHolders.freeze();
        
        
        emit StartMigration(target);
    }

    function migrate() whenMigrating external {
        require(tokenHolders.contains(msg.sender));

        uint256 amount = balanceOf[msg.sender].add(GetToken(coinStore).balanceOf(address(this),msg.sender));

         MigrationTarget(migrationTarget).migrateFrom(msg.sender, amount);

         tokenHolders.remove(msg.sender);
    }
  
    function setMigrateFrom(address _from) external onlyImpl{
        require(_from != address(0) && _from != address(this));
        require(totalSupply == 0 && isInFirstPeriod == false);
        migrationFrom = _from;
    }

    function migrateFrom(address _holder, uint256 value) external {
        require(msg.sender == migrationFrom);

        balanceOf[_holder] = value;

        totalSupply = totalSupply.add(value);
    }

    function finishMigration() whenMigrating external {
        require(totalMigrated == tokenHolders.size());

        tokenHolders.unfreeze();
    }

/**********************************************************************************

*                                                                                *

* admin   operation                                                            *

*                                                                                *

**********************************************************************************/
    function _addAdmin(address _newAdmin) public onlyImpl{
        admin.add(_newAdmin);
    }

    function _deleteAdmin(address _admin) public onlyImpl{
        admin.remove(_admin);
    }

    function isAdmin(address _admin) public view returns (bool){
        return admin.contains(_admin);
    }

    function adminList() public view returns (address[] memory) {
        return admin.list();
    }

    function adminSize() public view returns (uint256) {
        return admin.size();
    }

/**********************************************************************************

*                                                                                *

* ERC20                                                           *

*                                                                                *

**********************************************************************************/
    function transfer(address to, uint256 amount) public whenMigrationUnstarted returns (bool success) {
      require(msg.sender == coinStore || to == coinStore);
      require(amount > 0);

      balanceOf[msg.sender] = balanceOf[msg.sender].sub(amount);
      balanceOf[to] = balanceOf[to].add(amount);

      emit Transfer(msg.sender,to,amount);

      return true;
    } 

    function approve(address spender, uint256 value) public whenMigrationUnstarted returns (bool success) {
        require(msg.sender == coinStore || spender == coinStore);

        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);

        return true;
    }

    function transferFrom(address from, address to, uint256 value) public whenMigrationUnstarted returns (bool success) {
        require(from == coinStore || to == coinStore);
        require(balanceOf[from] >= value);
        require(allowance[from][msg.sender] >= value);
        require(to != address(0));

        balanceOf[from] = balanceOf[from].sub(value);
        balanceOf[to] = balanceOf[to].add(value);

        allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);

        emit Transfer(from, to, value);

        return true;
    }

/**********************************************************************************

*                                                                                *

* bool value setting                                                               *

*                                                                                *

**********************************************************************************/
    function setDissvoled(bool _dissolve)public onlyImpl {
        dissolved = _dissolve;
    }

    function setRecycleOpen(bool _open)public onlyImpl {
        isRecycleOpen = _open;
    }

    function setFirstPeriod(bool _isFirstPeriod)public onlyImpl {
        isInFirstPeriod = _isFirstPeriod;
    }
/**********************************************************************************

*                                                                                *

* tokenHolders operation                                                         *

*                                                                                *

**********************************************************************************/
    function addHolder(address _holder)public onlyImpl {
        tokenHolders.add(_holder);
    }

    function removeHolder(address _holder)public onlyImpl {
        tokenHolders.remove(_holder);
    }
    
    function listHolder()public view  returns(address[] memory) {
        return tokenHolders.list();
    }

    function destroyHolder()public onlyImpl {
        tokenHolders.destroy();
    }

    function containsHolder(address _holder)public view returns(bool){
        return tokenHolders.contains(_holder);
    }

    function positionHolder(address _holder)public view returns(uint256){
        return tokenHolders.position(_holder);
    }

    function sizeHolder()public view returns(uint256){
        return tokenHolders.size();
    }
/**********************************************************************************

*                                                                                *

* smartUp addMember                                                              *

*                                                                                *

**********************************************************************************/
    function addMember(address _member)public onlyImpl {
        smartup.addMember(_member);
    }

/**********************************************************************************

*                                                                                *

* smartUp addMember                                                              *

*                                                                                *

**********************************************************************************/

    function notSellOutDissvoled() public onlyImpl {
        dissolved = true;
        notSelloutDissolved = true;
    }


    // function fisrstPeriodTransfer(address to, uint256 amount) public {
    //     require(msg.sender == exchange);

    //     coinStore.internalTransfer(address(this),to,amount);
    // }


    // function withdrawSut() public {
    //    require(!isInFirstPeriod);
    //    require(!isWithdraw);

    //    uint256 amount = totalSupply.mul(exchangeRate).div(10 ** 18) - totalSupply.mul(recycleRate).div(10 ** 18);

    //    GetToken(exchange).withdraw(address(SUT), amount);

    //    ERC20Interface(SUT).approve(proposal, amount);

    //    emit WithdrawToken(SUT, amount);
    // }

/**********************************************************************************

*                                                                                 *

* change recyclePrice                                                             *

*                                                                                *

**********************************************************************************/
   function requestRecycleChange(address applicant, uint256 _recycle, uint256 fee) external onlyImpl {
       require(isAdmin(applicant));       
       require(!dissolved);
       require(migrationTarget == address(0));
       require(reRecycleRate == 0);
       require(_recycle != recycleRate);
       

       uint256 maxRecycleRate = getMaxRecycleRate();

       require(_recycle > 0 && _recycle < maxRecycleRate);
       
       recycleStart = now;
       reRecycleRate = _recycle;
       adminVote.add(applicant);
       recycleFee = fee;

   }

   function getMaxRecycleRate() public view returns(uint256) {
        uint256 amountSut = GetToken(coinStore).balanceOf(SUT,address(this)).add(Proposal(proposal).marketTokenBalance(address(this),SUT).sub(Proposal(proposal).marketCurrentReward(address(this),SUT)));
        
        uint256 maxRecycleRate = amountSut.mul(10 ** 18).div(totalSupply);

        return maxRecycleRate;

   }

   function voteForRecycleRate(address voter) external onlyImpl{
       require(isAdmin(voter));
       require(!adminVote.contains(voter));
       require(now.sub(recycleStart) < recyclePeriod);

       adminVote.add(voter);
   }

   function conclusionRecycle() public returns(uint8,uint256)  {
      require(reRecycleRate != 0);
      
      require(now.sub(recycleStart) > recyclePeriod || adminVote.size() > adminSize().div(uint256(2)));

      if(adminVote.size() > adminSize().div(uint256(2))) {
        if (reRecycleRate > recycleRate) {
          uint256 transferSut = totalSupply.mul(reRecycleRate.sub(recycleRate)).div(DECIMALS_RATE);

          finishRecycle();

        //   Proposal(proposal).withdrawForRecyRate(transferSut);
          return(uint8(1),transferSut);

      }else {

          uint256 withdrawSut = totalSupply.mul(recycleRate.sub(reRecycleRate)).div(DECIMALS_RATE);

          finishRecycle();

          return(uint8(2), withdrawSut);
      }


      }else {
          finishRecycle();
          return(uint8(0),0);
      }



    }

    function finishRecycle() private {

       adminVote.destroy();

       recycleRate = reRecycleRate;

       reRecycleRate = 0;

       recycleStart = 0;

       recycleFee = 0;

    }


}


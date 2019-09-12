pragma solidity >=0.4.21 <0.6.0;


import "./SafeMath.sol";
import "./ExchangeConfig.sol";
import "./Ecrecovery.sol";
import "./Address.sol";

interface ctStore {
    
    function isInFirstPeriod()external view returns(bool);
    function exchangeRate()external pure returns(uint256); 
    function recycleRate()external pure returns(uint256);
    function dissolved()external pure returns(bool);
    function isRecycleOpen()external pure returns(bool);
    function isAdmin(address _admin) external pure returns(bool);
    function adminSize() external pure returns(uint256);
    function totalSupply() external pure returns(uint256);
    function creator() external pure returns(address);
    function migrationTarget() external pure returns(address);
    function migrationFrom()external pure returns(address);
 }

interface ISmartIdeaToken {
    function approveAndCall(address spender, uint256 value, bytes calldata extraData) external returns (bool);
}

contract Exchange is ExchangeConfig, Ecrecovery{
    using SafeMath for uint256;
    using Address for address;
    
    mapping (address => mapping(address => uint256)) public tokenBalance;
    mapping (address => bool)private isAllowed;
    mapping(bytes32 => bool) public expireHash;
    mapping(bytes32 => uint256) public orderFills;

    
    event Deposit(address _token, address _owner, uint256 _amount, uint256 _total);
    event Withdraw(address _token, address _owner, uint256 _amount, uint256 _remain);
    event BalanceChange(address _owner, uint256 _sutRemain, uint256 _ethRemain);
    event AdminWithdarw(address _withdrawer, address _token, address _owner, uint256 _value, uint256 _fee, uint256 _remain);
    event FirstPeriodBuyCt(address _ctAddress, address buyer, uint256 _amount, uint256 _costSut, uint256 fee);
    event SellCt(address _ctAddress, address _seller, uint256 _amount, uint256 acquireSut);
    event Trade(address _sourceAddress, address _targetAddress, address _taker, address _maker, uint256 _targetAmount, uint256 _sourceAmount);
    //event TotalTrade(address _sourceAddress, address _targetAddress, address _taker, uint256 _amount, uint256 _price, uint256 _fee, uint256 _tranValue, uint256 _tranSource);



    constructor(address _sut, address _fee, address _sutStore, address _sutProxy, address _ctImpl, address _proposal)public ExchangeConfig(_sut,_sutStore, _fee, _sutProxy,_ctImpl,_proposal, msg.sender){
        
    }
    
    function ()external payable{

    }

    function receiveApproval(address sutOwner, uint256 approvedSutAmount, address token, bytes calldata extraData) external{
        require(msg.sender == address(SUT));
        require(token == address(SUT));
        require(approvedSutAmount >= MIN_VALUE);

        address toAddress = bytesToAddress(extraData);

        if (sutOwner.isContract() && toAddress != address(0)) {
            depositSut(toAddress, approvedSutAmount, token);
        }else{
            depositSut(sutOwner, approvedSutAmount, token);
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

    function bytesToAddress(bytes memory bys) internal pure returns (address addr) {
    assembly {
      addr := mload(add(bys,20))
    } 
   }


    function depositERC20(address _token, uint256 _amount) public {
        require(_token != address(0));
        require(Token(_token).transferFrom(msg.sender,address(this),_amount));

        tokenBalance[_token][msg.sender] = tokenBalance[_token][msg.sender].add(_amount);

        emit Deposit(_token, msg.sender, _amount, tokenBalance[_token][_owner]);
    }
    
    function depositSut(address _owner, uint256 _amount, address _token)private{
        require(SUT.transferFrom(_owner,address(this),_amount));

        tokenBalance[_token][_owner] = tokenBalance[_token][_owner].add(_amount);

        emit Deposit(_token, _owner, _amount, tokenBalance[_token][_owner]);
    }

    function depositEther()public payable{
        require(msg.value >= MIN_VALUE);

        tokenBalance[address(0)][msg.sender] = tokenBalance[address(0)][msg.sender].add(msg.value);

        emit Deposit(address(0), msg.sender, msg.value, tokenBalance[address(0)][msg.sender]);
    }

 
    function withdraw(address _token, uint256 _amount)public{
        require(tokenBalance[_token][msg.sender] >= _amount);

        require(_amount >= MIN_VALUE);

        tokenBalance[_token][msg.sender] = tokenBalance[_token][msg.sender].sub(_amount);

        if (_token == address(0)){
            msg.sender.transfer(_amount);
        }else{
            Token(_token).transfer(msg.sender, _amount);
        }

        emit Withdraw(_token, msg.sender, _amount, tokenBalance[_token][msg.sender]);
    }

    // //internal transfer
    // function internalTransfer(address _to, address _token, uint256 _value) public {
    //     require(_to != address(0));
    //     require(_token != add)
    // }
    

    //admin withdarw
    function adminWithdraw(address _token, uint256 _amount, address payable _owner, uint256 feeWithdraw, bytes32 _hash, bytes memory sign)public onlyAdmin{
        require( _amount >= MIN_VALUE && tokenBalance[_token][_owner] >= _amount);
        

        //check sign
        bytes32 signHash = keccak256(abi.encodePacked(_token, _amount, _owner, feeWithdraw, _hash));

        address _beneficiary = ecrecovery(signHash, sign);

        require(_beneficiary == _owner);
        require(!expireHash[signHash]);
        
        //sub balance
        tokenBalance[_token][_owner] = tokenBalance[_token][_owner].sub(_amount);

        //fee
        tokenBalance[address(0)][_owner] = tokenBalance[address(0)][_owner].sub(feeWithdraw);
        tokenBalance[address(0)][feeAccount] = tokenBalance[address(0)][feeAccount].add(feeWithdraw);

        //transfer
        if(_token == address(0)){
            _owner.transfer(_amount);
        }else{
            Token(_token).transfer(_owner, _amount);
        }

        expireHash[signHash] = true;

        emit AdminWithdarw(msg.sender, _token, _owner, _amount, feeWithdraw, tokenBalance[_token][_owner]);
    }

    function ctWithdrawSutToPro(uint256 _value) external {
        require(tokenBalance[address(SUT)][msg.sender] >= _value);
        require(SutStore(sutStore).creator(msg.sender) != address(0));

        Token(address(SUT)).transfer(msg.sender, _value);
        
        tokenBalance[address(SUT)][msg.sender] = tokenBalance[address(SUT)][msg.sender].sub(_value);
    }


    function balanceOf(address _token, address _owner)public view returns (uint256 _amount) {
        return tokenBalance[_token][_owner];
    }


    function createCtMarket(address marketCreator, uint256 initialDeposit, string memory _name, string memory _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 fee, uint256 _closingTime, bytes memory signature) public onlyAdmin {
        require(tokenBalance[address(0)][marketCreator] >= fee);
        //check sign
        bytes32 signHash = keccak256(abi.encodePacked(marketCreator, initialDeposit, _name, _symbol, _supply,_rate,_lastRate,fee,_closingTime));

        address _creator = ecrecovery(signHash, signature);

        require(_creator == marketCreator);
        require(!expireHash[signHash]);

        //fee
        tokenBalance[address(0)][_creator] = tokenBalance[address(0)][_creator].sub(fee);
        tokenBalance[address(0)][feeAccount] = tokenBalance[address(0)][feeAccount].add(fee);


        address _tokenAddress = sutProxy.createMarket(marketCreator,initialDeposit,_name,_symbol,_supply,_rate,_lastRate,_closingTime);
        
        SUT.transfer(sutStore, initialDeposit);
        
        tokenBalance[address(SUT)][_creator] = tokenBalance[address(SUT)][_creator].sub(initialDeposit);

        //tokenBalance[(address(SUT))][_tokenAddress] = tokenBalance[(address(SUT))][_tokenAddress].add(initialDeposit);
        tokenBalance[_tokenAddress][_tokenAddress] = _supply;

        expireHash[signHash] = true;

        emit BalanceChange(marketCreator,tokenBalance[address(SUT)][_creator],tokenBalance[address(0)][_creator]);
   }


   function buyCt(address _tokenAddress, uint256 _amount, address _buyer, uint256 fee, bytes32 _hash, bytes memory signature)public onlyAdmin{

       bytes32 signHash = keccak256(abi.encodePacked(_tokenAddress, _amount, _buyer, fee, _hash)); 

       require(ecrecovery(signHash, signature) == _buyer);
       
       require(!expireHash[signHash]);
       
       require(_amount >= MIN_VALUE);
       ctStore market = ctStore(_tokenAddress);
       require(market.isInFirstPeriod() && !market.dissolved());
       require(tokenBalance[_tokenAddress][_tokenAddress] >= _amount);

       uint256 costSut = _amount.mul(market.exchangeRate()).div(DECIMALS_RATE);
       require(tokenBalance[address(SUT)][_buyer] >= costSut);

       tokenBalance[_tokenAddress][_tokenAddress] = tokenBalance[_tokenAddress][_tokenAddress].sub(_amount);
       tokenBalance[_tokenAddress][_buyer] = tokenBalance[_tokenAddress][_buyer].add(_amount);

       tokenBalance[address(SUT)][_tokenAddress] = tokenBalance[address(SUT)][_tokenAddress].add(costSut);
       tokenBalance[address(SUT)][_buyer] = tokenBalance[address(SUT)][_buyer].sub(costSut);

       tokenBalance[address(0)][_buyer] = tokenBalance[address(0)][_buyer].sub(fee);
       tokenBalance[address(0)][feeAccount] = tokenBalance[address(0)][feeAccount].add(fee);
       
       ctImpl.buyct(_tokenAddress, _buyer);
       
       marketAdminCheck(_tokenAddress, _buyer);

       if (tokenBalance[_tokenAddress][_tokenAddress] == 0) {
           
           ctImpl.finishFirstPeriod(_tokenAddress);

           uint256 toProposal = tokenBalance[address(SUT)][_tokenAddress].mul(market.exchangeRate().sub(market.recycleRate())).div(DECIMALS_RATE);

           require(ISmartIdeaToken(address(SUT)).approveAndCall(proposal, toProposal,toBytes(_tokenAddress)));
           
           tokenBalance[address(SUT)][_tokenAddress] = tokenBalance[address(SUT)][_tokenAddress].sub(toProposal);
       }

       expireHash[signHash] = true;
       
       emit FirstPeriodBuyCt(_tokenAddress, _buyer, _amount, costSut, fee);

   }
   


   function marketAdminCheck(address _ctAddress, address trader) internal {
       ctStore ct = ctStore(_ctAddress);

       if (tokenBalance[_ctAddress][trader] >= ct.totalSupply().div(10) && !ct.isAdmin(trader) && ct.adminSize() < 5 && trader != ct.creator()) {
           ctImpl.addAdmin(_ctAddress, trader);
       }else if(ct.isAdmin(trader) && ct.adminSize() >= 0 && tokenBalance[_ctAddress][trader] < ct.totalSupply().div(10) && trader != ct.creator()) {
           ctImpl.deleteAdmin(_ctAddress, trader);
       }

   }

   function sellCt(address _tokenAddress, uint256 _amount)public{
       require(_amount >= MIN_VALUE);
       ctStore market = ctStore(_tokenAddress);
       
       require(market.migrationTarget() == address(0));
       require(market.isRecycleOpen());

       uint256 acquireSut = _amount.mul(market.recycleRate()).div(DECIMALS_RATE);

       tokenBalance[_tokenAddress][_tokenAddress] = tokenBalance[_tokenAddress][_tokenAddress].add(_amount);
       tokenBalance[_tokenAddress][msg.sender] = tokenBalance[_tokenAddress][msg.sender].sub(_amount);

       tokenBalance[address(SUT)][_tokenAddress] = tokenBalance[address(SUT)][_tokenAddress].sub(acquireSut);
       tokenBalance[address(SUT)][msg.sender] = tokenBalance[address(SUT)][msg.sender].add(acquireSut);

       if(tokenBalance[_tokenAddress][msg.sender] == 0){
           ctImpl.removeCtHolder(_tokenAddress, msg.sender);
       }


       emit SellCt(_tokenAddress,msg.sender,_amount,acquireSut);

   }

    //10000000000000000000000
    //100000000000000000
    //makerValue[0] amount, makerValue[1] CTprice, makerValue[2] makerTimeStamp,
    //makerAddress[0] sourceAddress, makerAddress[1] targetAddress makerAddress[2] makerAddress
    //takerValue[0] amount, takerValue[1] CTprice, takerValue[2]takerTimeStamp , takerValue[3] takerTransactionFee,
    //takerAddress[0]sourceAddress takerAddress[1] targetAddress takerAddress[2] takerAddress 
    //makerSign[0] sign
    //takerSign[0] sign
    //["1000000000000000000000","100000000000000000","1565676685","1000000000000000000000","100000000000000000","1565676685"]
    //["0x837d9d85d34fa72570b65962d2195dac2b7ad2ea","0xf1899c6eb6940021c1ae4e9c3a8e29ee93704b03","0x745C36aC79A4D9A5f4d69CB404AbE0c5Cd3BAff5","0x837d9d85d34fa72570b65962d2195dac2b7ad2ea","0xf1899c6eb6940021c1ae4e9c3a8e29ee93704b03","0xea997cfc8beF47730DFd8716A300bDAB219c1f89"]
    //["1500000000000000000000","100000000000000000","1565676686","1000000000000000"]
    //["0xf1899c6eb6940021c1ae4e9c3a8e29ee93704b03","0x837d9d85d34fa72570b65962d2195dac2b7ad2ea","0x8b36b88450075bead50f163d7b0e5bcbc9039257"]
    //["0xf4dac695ad3bd70803f26ab0da18317e3f79727662dc73f8709c907e27097dea","0x478a4f5dfc61ca85e1f30a50612f9bf1499dc641e947cefe9b46181d3206c4a1","0xea150221a775266497b291973ca02f81959ec212a49c1bfdf54bc1beb12d5fa3","0x5fd751fbe89cdad23fb95d8952f13c7b2b7d7aab232b7f612060430dba1ff2ac"]
    //["27","28"]
    //"0xd7de187e13887f5758356dc57b7dfe661afbd5fd075f94ef7b08f24135074f1635be7dab5819b364dc3e31ef31245c7f4f713e909131932903101831c8f1e7fa1c"
    function trade(uint256[] memory makerValue, address[] memory makerAddress, uint256[4] memory takerValue, address[3] memory takerAddress, bytes32[] memory rs, uint8[] memory v, bytes memory takerSign)public onlyAdmin {
       //check taker sign
       bytes32 takerHash = keccak256(abi.encodePacked(takerValue[0],takerValue[1],takerValue[2],takerValue[3],takerAddress[0],takerAddress[1],takerAddress[2]));

       require(ecrecovery(takerHash, takerSign) == takerAddress[2]);

       //only SUT
       require(takerAddress[0] == address(SUT) || takerAddress[1] == address(SUT));

       if(takerAddress[0] == address(SUT)){
           //TODO !
           require(ctStore(takerAddress[1]).isInFirstPeriod() && !ctStore(takerAddress[1]).dissolved());
       }else{
           require(ctStore(takerAddress[0]).isInFirstPeriod() && !ctStore(takerAddress[0]).dissolved());
           require(ctStore(takerAddress[0]).migrationTarget() == address(0));
       }
       
       //order not filled
       require(orderFills[takerHash] < takerValue[0]);

       //have enough sut to pay;
       require(tokenBalance[takerAddress[0]][takerAddress[2]] >= takerValue[0].sub(orderFills[takerHash]).mul(takerValue[1]).div(DECIMALS_RATE));

       //check maker parameter  info
       require(makerValue.length % 3 == 0 && makerAddress.length % 3 == 0 && rs.length == makerValue.length.div(3).mul(2) && v.length == makerValue.length.div(3));
       

       //trade
       for(uint256 i = 0; i < makerValue.length.div(3); i++){
           //check sign
           //*******************************************************//
           //
           //  makerHash problem
           //
           //****************************************************** */
           bytes32 makerHash = keccak256(abi.encodePacked(makerValue[i.mul(3)],makerValue[i.mul(3).add(1)],makerValue[i.mul(3).add(2)],makerAddress[i.mul(3)],makerAddress[i.mul(3).add(1)],makerAddress[i.mul(3).add(2)]));
           
        //    bytes memory prefix = "\x19Ethereum Signed Message:\n32";

        //    bytes32 _makerHash =  keccak256(abi.encodePacked(prefix, makerHash));

           require(ecverifyRSV(makerHash, v[i], rs[i.mul(2)], rs[i.mul(2).add(1)]) == makerAddress[i.mul(3).add(2)]);
           
           //maker remain
           uint256 makerRemain = makerValue[i.mul(3)].sub(orderFills[makerHash]);

           require(makerRemain > 0);

           //taker remain
           uint256 takerRemain = takerValue[0].sub(orderFills[takerHash]);
           
           //taker not be filled 
           require(takerRemain > 0);

           //takerPrice must >= makerPrice;
           require(takerValue[1] >= makerValue[i.mul(3).add(1)]);

           //check the market is rigth
           require(makerAddress[i.mul(3)] == takerAddress[1]);
           
           // if order not enough trade full
           if(takerRemain >= makerRemain){

               uint256 cost = makerRemain.mul(makerValue[i.mul(3).add(1)]).div(DECIMALS_RATE);

               singleTrade(takerAddress[0],takerAddress[1],takerAddress[2],makerAddress[i.mul(3).add(2)],makerRemain,cost,takerHash,makerHash);
               
            }else{

               uint256 cost = takerRemain.mul(makerValue[i.mul(3).add(1)]).div(DECIMALS_RATE);

               singleTrade(takerAddress[0],takerAddress[1],takerAddress[2],makerAddress[i.mul(3).add(2)],takerRemain,cost,takerHash,makerHash);

            }
        }

        //fee exchange
        tokenBalance[address(0)][takerAddress[2]] = tokenBalance[address(0)][takerAddress[2]].sub(takerValue[3]);
        tokenBalance[address(0)][feeAccount] = tokenBalance[address(0)][feeAccount].add(takerValue[3]);

        //emit TotalTrade(takerAddress[0], takerAddress[1], takerAddress[2], takerValue[0], takerValue[1], takerValue[2], tranValue, tranSource);
       
   }

   function singleTrade(address _source, address _target, address _taker, address _maker, uint256 _targetAmount, uint256 _sourceAmount, bytes32 _takerHash, bytes32 _makerHash)private{
               //uint256 cost = makerRemain.mul(makerValue[i.mul(3).add(1)]).div(DECIMALS_RATE);

               tokenBalance[_target][_maker] = tokenBalance[_target][_maker].sub(_targetAmount);

               tokenBalance[_target][_taker] = tokenBalance[_target][_taker].add(_targetAmount);

               tokenBalance[_source][_taker] = tokenBalance[_source][_taker].sub(_sourceAmount);

               tokenBalance[_source][_maker] = tokenBalance[_source][_maker].add(_sourceAmount);

               orderFills[_takerHash] = orderFills[_takerHash].add(_targetAmount);

               orderFills[_makerHash] = orderFills[_makerHash].add(_sourceAmount);

               if (_source == address(SUT)) {

                   marketAdminCheck(_target, _maker);
                   marketAdminCheck(_target, _taker);
                   
                   if(tokenBalance[_target][_maker] == 0) {
                       ctImpl.removeCtHolder(_target, _maker);
                   }
                   ctImpl.buyct(_target,_taker);
               }else{

                   marketAdminCheck(_source, _maker);
                   marketAdminCheck(_source, _taker);

                   if(tokenBalance[_source][_taker] == 0){
                       ctImpl.removeCtHolder(_source, _taker);
                   }
                   ctImpl.buyct(_source,_maker);
               }
               

               emit Trade(_source,_target,_taker,_maker,_targetAmount,_sourceAmount);
   }



   //upgrade Issue

   function upgradeMarket(address marketAddress, address upgraderAddress, address upgrader, uint256 fee, bytes memory upgraderSign) public onlyAdmin {
       require(ctStore(marketAddress).migrationTarget() == address(0));

        bytes32 upgraderHash = keccak256(abi.encodePacked(marketAddress,upgraderAddress,upgrader, fee));

        require(ecrecovery(upgraderHash, upgraderSign) == upgrader);


        tokenBalance[address(0)][upgrader] = tokenBalance[address(0)][upgrader].sub(fee);
        tokenBalance[address(0)][feeAccount] = tokenBalance[address(0)][feeAccount].add(fee);

        ctImpl.setUpgradeMarket(marketAddress, upgraderAddress);        
   }

   function setMigrateFrom(address marketAddress, address migrateFrom, address upgrader, uint256 fee, bytes memory upgraderSign) public onlyAdmin {
        require(ctStore(marketAddress).migrationFrom() == address(0));

        bytes32 upgraderHash = keccak256(abi.encodePacked(marketAddress,migrateFrom,upgrader, fee));

        require(ecrecovery(upgraderHash, upgraderSign) == upgrader);


        tokenBalance[address(0)][upgrader] = tokenBalance[address(0)][upgrader].sub(fee);
        tokenBalance[address(0)][feeAccount] = tokenBalance[address(0)][feeAccount].add(fee);

        ctImpl.setCtMigrateFrom(marketAddress, migrateFrom);    
   }
   
   function destory()public onlyAdmin {
       selfdestruct(msg.sender);
   }

}
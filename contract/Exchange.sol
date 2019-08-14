pragma solidity >=0.4.21 <0.6.0;

import "./Ownable.sol";
import "./SafeMath.sol";
import "./ExchangeConfig.sol";
import "./Ecrecovery.sol";

interface ctStore {
    function isInFirstPeriod()external view returns(bool);
    function exchangeRate()external pure returns(uint256); 
    function recycleRate()external pure returns(uint256);
    function dissolved()external pure returns(bool);
    function isRecycleOpen()external pure returns(bool);

 }

contract Exchange is Ownable, ExchangeConfig, Ecrecovery{
    using SafeMath for uint256;
    
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



    constructor(address _sut, address _fee, address _sutProxy, address _ctImpl)public Ownable(msg.sender) ExchangeConfig(_sut,_fee, _sutProxy,_ctImpl){
        
    }
    
    function ()external payable{

    }

    function receiveApproval(address sutOwner, uint256 approvedSutAmount, address token, bytes calldata extraData) external{
        require(msg.sender == address(SUT));
        require(token == address(SUT));
        require(approvedSutAmount >= MIN_VALUE);

        depositSut(sutOwner, approvedSutAmount, token);
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
        
        tokenBalance[address(SUT)][_creator] = tokenBalance[address(SUT)][_creator].sub(initialDeposit);
        tokenBalance[(address(SUT))][_tokenAddress] = tokenBalance[(address(SUT))][_tokenAddress].add(initialDeposit);
        tokenBalance[_tokenAddress][_tokenAddress] = _supply;

        expireHash[signHash] = true;

        emit BalanceChange(marketCreator,tokenBalance[address(SUT)][_creator],tokenBalance[address(0)][_creator]);       
   }


   function buyCt(address _tokenAddress, uint256 _amount, address _buyer, uint256 fee, bytes32 _hash, bytes memory signature)public onlyAdmin{

       bytes32 signHash = keccak256(abi.encodePacked(_tokenAddress, _amount, _buyer, fee, _hash));

       address buyer = ecrecovery(signHash, signature);

       require(buyer == _buyer);
       require(!expireHash[signHash]);
       
       require(_amount >= MIN_VALUE);
       ctStore market = ctStore(_tokenAddress);
       require(market.isInFirstPeriod() && !market.dissolved());
       require(tokenBalance[_tokenAddress][_tokenAddress] >= _amount);

       uint256 costSut = _amount.mul(market.exchangeRate()).div(DECIMALS_RATE);
       require(tokenBalance[address(SUT)][buyer] >= costSut);

       tokenBalance[_tokenAddress][_tokenAddress] = tokenBalance[_tokenAddress][_tokenAddress].sub(_amount);
       tokenBalance[_tokenAddress][buyer] = tokenBalance[_tokenAddress][buyer].add(_amount);

       tokenBalance[address(SUT)][_tokenAddress] = tokenBalance[address(SUT)][_tokenAddress].add(costSut);
       tokenBalance[address(SUT)][buyer] = tokenBalance[address(SUT)][buyer].sub(costSut);

       tokenBalance[address(0)][buyer] = tokenBalance[address(0)][buyer].sub(fee);
       tokenBalance[address(0)][feeAccount] = tokenBalance[address(0)][feeAccount].add(fee);
       
       ctImpl.buyct(_tokenAddress, _buyer);

       if (tokenBalance[_tokenAddress][_tokenAddress] == 0) {
           ctImpl.finishFirstPeriod(_tokenAddress);
       }

       expireHash[signHash] = true;
       
       emit FirstPeriodBuyCt(_tokenAddress, buyer, _amount, costSut, fee);

   }

   function sellCt(address _tokenAddress, uint256 _amount)public{
       require(_amount >= MIN_VALUE);
       ctStore market = ctStore(_tokenAddress);

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

    //makerValue[0] amount, makerValue[1] CTprice, makerValue[2] makerTimeStamp,
    //makerAddress[0] sourceAddress, makerAddress[1] targetAddress makerAddress[2] makerAddress
    //takerValue[0] amount, takerValue[1] CTprice, takerValue[2]takerTimeStamp , takerValue[3] takerTransactionFee,
    //takerAddress[0]sourceAddress takerAddress[1] targetAddress takerAddress[2] takerAddress 
    //makerSign[0] sign
    //takerSign[0] sign
    //["5000000000000000000","100000000000000000","1565676685"]
    //["0x42cd6cbe0a0465b50522c5274d024c745028849a","0x8449b6d5ec1e32f66e2475866981e167fd624a43","0x745C36aC79A4D9A5f4d69CB404AbE0c5Cd3BAff5"]
    //["4000000000000000000","100000000000000000","1565676686","10000000000000000"]
    //["0x8449b6d5ec1e32f66e2475866981e167fd624a43","0x42cd6cbe0a0465b50522c5274d024c745028849a","0x8B36B88450075BEad50f163d7b0e5bcbc9039257"]
    //["0x98c3447c64ed473e2f617d33bc6f93cec3269c965a153b1a1b35019d64728da2","0x2a053bbcba1adf4abdfe2142a38a154761f59dfc3e4a1d0f6b05401733b68288"]
    //["28"]
    //"0xfcfc9447bc72a983d8a553e4b36b7e020179c118b9f9cd8044fb5a8239272de20ea0281d1602463940a6f52c23ee886a481282caf829dc7421ff9a3ec25c2d2c1b"
    function trade(uint256[] memory makerValue, address[] memory makerAddress, uint256[4] memory takerValue, address[3] memory takerAddress, bytes32[] memory rs, uint8[] memory v, bytes memory takerSign)public onlyAdmin {
       //check taker sign
       bytes32 takerHash = keccak256(abi.encodePacked(takerValue[0],takerValue[1],takerValue[2],takerValue[3],takerAddress[0],takerAddress[1],takerAddress[2]));

       require(ecrecovery(takerHash, takerSign) == takerAddress[2]);

       //only SUT
       require(takerAddress[0] == address(SUT) || takerAddress[1] == address(SUT));

       if(takerAddress[0] == address(SUT)){
           require(!ctStore(takerAddress[1]).isInFirstPeriod() && !ctStore(takerAddress[1]).dissolved());
       }else{
           require(!ctStore(takerAddress[0]).isInFirstPeriod() && !ctStore(takerAddress[0]).dissolved());
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

           require(ecverifyRSV(makerHash, v[i], rs[i.mul(2).add(0)], rs[i.mul(2).add(1)]) == makerAddress[i.mul(3).add(2)]);
           
           //maker remain
           uint256 makerRemain = makerValue[i.mul(3)].sub(orderFills[takerHash]);

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
                   if(tokenBalance[_target][_maker] == 0) {
                       ctImpl.removeCtHolder(_target, _maker);
                   }
                   ctImpl.buyct(_target,_taker);
               }else{
                   if(tokenBalance[_source][_taker] == 0){
                       ctImpl.removeCtHolder(_source, _taker);
                   }
                   ctImpl.buyct(_source,_maker);
               }

               emit Trade(_source,_target,_taker,_maker,_targetAmount,_sourceAmount);
   }

}
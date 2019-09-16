## SmartUp 2.0 合约说明

#### 合约步骤

```
1.SUT token合约 （ctConfig 需要设置） 0xF1899c6eB6940021C1aE4E9C3a8e29EE93704b03
2.NTT 合约  （ctConfig 需要设置）（如果需要增加更改NTT权限 去要设置） 0x846cE03199A759A183ccCB35146124Cd3F120548

3.sutStore 合约      0xbEa30a20693cf6470d57C7FB396F79531D0FF1D3
   Gas Limit: 4027415
   Gas Price: 10 Gwei
   Fee:0.0402 Ether

4.SutProxy 合约   0xcE03Adb6c9Cd167039417b0CBFA421349b2d8C22
Value:
0 Ether ($0.00)
Transaction Fee:
0.05008636 Ether ($0.000000)
Gas Limit:
2,504,318
Gas Used by Transaction:
2,504,318 (100%)
Gas Price:
0.00000002 Ether (20 Gwei)

CtProposal(需要设置Exchange 地址) 0xc6Ab19f4adB704e729334695D3FbfCBc86d1039A

5.CTimpl 合约   0x6B907D4Dd3F63e1123FAE2c6572Ca6F48a6C5D83
Value:
0 Ether ($0.00)
Transaction Fee:
0.03207403 Ether ($0.000000)
Gas Limit:
3,207,403
Gas Used by Transaction:
3,207,403 (100%)
Gas Price:
0.00000001 Ether (10 Gwei)


6.SutImpl合约    0xB2e1DEAE6f7E0DE18Fc7d90eE2dA5a2d98526891
Transaction Fee:
0.0564316 Ether ($0.000000)
Gas Limit:
5,643,160
Gas Used by Transaction:
5,643,160 (100%)
Gas Price:
0.00000001 Ether (10 Gwei)
7.Exchange 合约   0xD6f5F5029cAB6BE693Dd1e477A6cca3A07CaF03C
Gas Limit:
2,870,286
Gas Used by Transaction:
2,870,286 (100%)
Gas Price:
0.00000001 Ether (10 Gwei)
8.SutStore 设置sutImplAddress

9.SutProxy 设置sutImplAddress 设置 Exchange地址

10. SutProxy 设置 exchange Address

11.CTimpl 设置 sutImpl地址  exchange地址

12.Exchange 设置Admin

```

#### Exchange 其他地址信息

```
owner: 0x8b36b88450075bead50f163d7b0e5bcbc9039257
feeAccount: 0x8b36b88450075bead50f163d7b0e5bcbc9039257
Admin:[0x8b36b88450075bead50f163d7b0e5bcbc9039257,0xea997cfc8beF47730DFd8716A300bDAB219c1f89]
```

#### Ropsten 测试网络合约地址信息

```
SUT: 0xf1899c6eb6940021c1ae4e9c3a8e29ee93704b03

NTT: 0x846ce03199a759a183cccb35146124cd3f120548
```

#### 1.存SUT（调用的合约SUTtoken合约）

```
方法：function approveAndCall(address _spender, uint256 _value, bytes memory _extraData) public returns (bool success)
方法签名：
0xcae9ca51
参数说明：
address _spender  存钱的合约地址
uint256 _value    存的SUT数量
bytes memory _extraData  其他（可以是0x)

事件：
Deposit(address _token, address _owner, uint256 _amount，uint256 _total);
事件签名：
0xdcbc1c05240f31ff3ad067ef1ee35ce4997762752e3a095284754544f4c709d7
参数说明：
address _token  代币合约地址（sut合约地址如果存的是ETH则为0x0000000000000000000000000000000000000000）
address _owner 存钱的人
uint256 _amount 存的数量
uint256 _total   当前余额；

```

#### 2.存ETH（调用的合约Exchange）

```
function depositEther()public payable
方法签名：
0x98ea5fca

事件：
Deposit(address _token, address _owner, uint256 _amount);
事件签名：
0xdcbc1c05240f31ff3ad067ef1ee35ce4997762752e3a095284754544f4c709d7
参数说明：
address _token  存的代币（sut合约地址如果存的是ETH则为0x0x0000000000000000000000000000000000000000）
address _owner 存钱的人
uint256 _amount 存的数量
uint256 _total   当前余额
```

### 3.存其他ERC20代币

```
function depositERC20(address _token, uint256 _amount) public
方法签名：0x97feb926

参数：
address _token ERC20代币地址
uint256 _amount 存的代币数量

事件：
Deposit(address _token, address _owner, uint256 _amount);
事件签名：
0xdcbc1c05240f31ff3ad067ef1ee35ce4997762752e3a095284754544f4c709d7
参数说明：
address _token  存的代币（sut合约地址如果存的是ETH则为0x0x0000000000000000000000000000000000000000）
address _owner 存钱的人
uint256 _amount 存的数量
uint256 _total   当前余额
```

#### 4.用户自己取钱（调用的合约Exchange）

```
function withdraw(address _token, uint256 _amount)public
方法签名：
0xf3fef3a3
参数说明：
0xed5d967cede8ef16b70e2a4085119dca93c01661
0xed5d967cede8ef16b70e2a4085119dca93c01661
address _token  取钱token地址，若为eth则为（0x0000000000000000000000000000000000000000）
uint256 _amount 数量(必须大于10的15次方)
事件：Withdraw(address _token, address _owner, uint256 _amount, uint256 _reamain);
address _token  取钱的token，若为eth则为（0x0000000000000000000000000000000000000000）
address _owner  取钱的人
uint256 _amount 一共取了多少
uint256 _reamain 用户余额

事件签名：0xf341246adaac6f497bc2a656f546ab9e182111d630394f0c57c710a59a2cb567
```

#### 4.管理员帮用户取钱（调用的合约Exchange）

```
function adminWithdraw(address _token, uint256 _amount, address payable _owner, uint256 feeWithdraw, bytes32 _hash, bytes memory sign)public onlyAdmin
方法签名：
0x04c557a9

参数说明：
address _token  取钱token地址，若为eth则为（0x0000000000000000000000000000000000000000）
uint256 _amount 数量(必须大于10的15次方)
address payable _owner  取钱的用户地址
uint256 feeWithdraw 取钱的手续费
bytes32 签名时时间戳哈希
bytes memory sign  用户对_token，_amount，_owner，feeWithdraw的签名

签名的数据: _token, _amount, _owner, nonce, feeWithdraw, _hash，

事件：
AdminWithdarw(address _withdrawer, address _token, address _owner, uint256 _value, uint256 _fee, uint256 _remain);
事件签名：
0x379612486dbf6da40d2087b9ab46f0630c963e9c92d24087c00af355ef39fe0d
参数说明：
address _withdrawer  帮用户取钱的admin地址
address _token  取钱的token，若为eth则为（0x0000000000000000000000000000000000000000）
address _owner  取钱的人
uint256 _value 一共取了多少
uint256 _fee 手续费
uint256 _reamain 用户余额

```

#### 5. 查询余额（调用的合约Exchange）

```
mapping (address => mapping(address => uint256)) public tokenBalance;
tokenBalance[address][address];
参数说明
adddress   token地址(若为eth则为（0x0000000000000000000000000000000000000000）,sut则为sut地址)
address    要查询的账号地址

返回值：
uint256   用户对应的token余额
```

#### 6. 创建市场（调用的合约Exchange）

````
function createCtMarket(address marketCreator, uint256 initialDeposit, string memory _name, string memory _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 fee, uint256 _closingTime, bytes memory signature) public onlyAdmin

方法签名：0x435dbf35

参数说明：
address marketCreator  市场创建者
uint256 initialDeposit  创建市场的押金(2500SUT)
string memory _name   市场名字（比如：smartupToken）
string memory _symbol 市场简称（比如： SUT）
uint256 _supply   CT 发行量（1 个 ct 为：1000000000000000000);
uint256 _rate     第一阶段 CT 兑换 SUT 比例（1 个 ct 能换 0.1 个 sut 则为：10 ** 17）；
uint256 _lastRate  市场最后的兑换价格(同 _rate)
uint256 fee  创建市场的费用
uint256 _closingTime 市场的有效时间（以秒为单位，1 - 90 天时长）
bytes memory signature 签名

签名的数据：marketCreate， initialDeposit, _name, _symbol, _supply, _rate, _lastRate, Fee,_closingTime

事件一：
MarketCreated(address _ctAddress,address _marketCreator,uint256 _initialDeposit);
签名：
0xab80d4f237153664013aad30815c82af95ab8234bfb2d63a6518a3656e4d3a8c
参数说明：
address _ctAddress 创建的CT市场地址
address _marketCreator 市场创建者
uint256 _initialDeposit  创建市场的押金

事件二： 
event BalanceChange(address _owner, uint256 _sutRemain, uint256 _ethRemain);
签名：
0xf4e3f146ef01bfe65e811aade3a860b33927625771e1f2c45ae705ae2e44d3e8
参数说明：
address _owner  改变余额的地址
uint256 _sutRemain  sut余额
uint256 _ethRemain  eth余额

消耗的gas信息：    //0x3d37e33c589b3b105f8752239b5298386e04cda3039529654cee303d272a3ad6
Gas Limit:
推荐 3,000,000
````

#### 6.查询Ct市场价格（调用合约CT市场合约）

```
uint256 public exchangeRate;
方法：
function exchangeRate()public pure returns(uint256)
方法签名：0x3ba0b9a9

返回值：
uint256 市场的CT价格
```

#### 7. 查询Ct市场最后的卖出价（调用Ct市场合约）

```
uint256 public recycleRate;
方法：
function recycleRate()public pure returns(uint256)
方法签名：0xb55795e3

返回值：
uint256 市场的CT最后的价格
```

#### 8.第一阶段购买CT（调用的合约Exchange）

````
function buyCt(address _tokenAddress, uint256 _amount, address _buyer, uint256 fee, bytes32 _hash, bytes memory signature)public onlyAdmin
方法签名：0xc3198905
参数说明：
address _tokenAddress  Ct市场地址
uint256 _amount   ct数量(ct数量必须大于等于 1 个 即 10 ** 18)
address _buyer  买ct人的地址
uint256 fee 手续费
bytes32 签名时时间戳哈希
bytes memory signature 签名

签名数据： _tokenAddress,_amount,_buyer，fee, _hash



事件：
FirstPeriodBuyCt(address _ctAddress, address buyer, uint256 _amount, uint256 _costSut，uint256 fee);
签名：
0x50e93854cadfd287beac9039b6a35a542b5d0d63737f6e379e0248048a579002
参数说明：
address _ctAddress  ct市场地址
address buyer       buyer地址
uint256 _amount     买的ct数量
uint256 _costSut    花费的Sut

gas消耗：推荐 320,000
Gas Limit:
推荐 320,000
````

#### 9.最后卖出CT （调用的合约Exchange）

````
function sellCt(address _tokenAddress, uint256 _amount)public
方法签名：
0x3610f844

参数说明：
address _tokenAddress  Ct市场地址
uint256 _amount   ct数量(ct数量必须大于等于 1 个 即 10 ** 18)

事件：
SellCt(address _ctAddress, address _seller, uint256 _amount, uint256 acquireSut);
签名：
参数说明：
address _ctAddress  ct市场地址
address _seller     seller地址
uint256 _amount      卖出ct数量
uint256 acquireSut   得到的SUT数量
````

#### 10.查询市场阶段(调CT市场合约)

```
bool public isInFirstPeriod;

方法签名：
0xccf42c3b

返回值：bool 
true 在第一阶段
false  不在第一阶段

```

#### 11.第二阶段交易(调用Exchange 合约)

```
function trade(uint256[] memory makerValue, address[] memory makerAddress, uint256[4] memory takerValue, address[3] memory takerAddress, bytes32[] memory rs, uint8[] memory v, bytes memory takerSign)public onlyAdmin

方法签名：0xb94140b1

参数说明：
uint256[] memory makerValue 每三个为一个挂单(maker)的参数makerValue[0] amount（挂单的数量）, makerValue[1] CTprice（价格，若价格为1个SUT 则为1000000000000000000）, makerValue[2] makerTimeStamp（挂单时间）

address[] memory makerAddress 每三个为一个挂单的参数 makerAddress[0] sourceAddress(挂单的币想要卖出的币), makerAddress[1] targetAddress（想要换取得币） makerAddress[2] makerAddress（挂单者自己的地址）

uint256[4] memory takerValue  吃单者的参数 takerValue[0] amount（数量）, takerValue[1] CTprice（价格，若价格为1个SUT 则为1000000000000000000）, takerValue[2]takerTimeStamp（吃单时间） , takerValue[3] takerTransactionFee（手续费）

address[3] memory takerAddress 吃单的地址参数 takerAddress[0]sourceAddress（吃单者想要卖出的币） takerAddress[1] targetAddress（吃单者想要获取的币） takerAddress[2] takerAddress（吃单者自己的地址）

bytes32[] memory rs 每两个参数为一组，对应的是挂单人的 RS 签名

uint8[] memory v  对应挂单人的 v 签名

bytes memory takerSign  吃单者的签名

maker签名的来源：一组 rsv 对应的签名为 makerValue 的 amount，CTprice，makerTimeStamp 个 和 makerAddress 的 sourceAddress，targetAddress， makerAddress

taker 签名的来源：吃单者的参数 takerValue[0] amount（数量）, takerValue[1] CTprice（价格，若价格为1个SUT 则为1000000000000000000）, takerValue[2]takerTimeStamp（吃单时间） , takerValue[3] takerTransactionFee（手续费），吃单的地址参数 takerAddress[0]sourceAddress（吃单者想要卖出的币） takerAddress[1] targetAddress（吃单者想要获取的币） takerAddress[2] takerAddress（吃单者自己的地址）
依次按顺序

事件：
Trade(address _sourceAddress, address _targetAddress, address _taker, address _maker, uint256 _targetAmount, uint256 _sourceAmount);

address _sourceAddress   针对吃单人来说的，吃单者想卖出的币
address _targetAddress   吃单者想买的币
address _taker           吃单者地址
address _maker           吃的挂单者地址
_targetAmount            吃了多少个单，比如吃单者为买CT，则为CT数量
uint256 _sourceAmount    吃单者卖出的数量，比如吃单者为买CT， 则为SUT数量

事件签名：0x9ae6c84f444be403f63f3a126829553edc7ac75f1e4911cfff892b274a214907

吃一笔单建议gas: 300,000 以此类推
```

#### 12. 给市场所在的提案捐赠ETH（调用Proposal 合约）

```
function donateETH(address marketAddress)public onlyStart payable
方法签名：0xa1e14f9f

参数说明：
address marketAddress 捐给市场的地址

事件：
event RecivedDonate(address marketAddress, address donator, address tokenAddress, uint256 value);
address marketAddress 捐赠的市场地址
address donator 捐赠者
address tokenAddress 捐赠代币的token地址
uint256 value  捐赠的数量

0x9d7eb72b
事件签名：0x8d29859c113f224d6afae8445c7c99741c85f31b9024083a21e8f8bac7ef6f6e
```

#### 13.给市场所在的提案捐赠ERC20代币(调用Proposal 合约)

```
function donateERC20(address marketAddress, address erc20Address, uint256 value) public onlyStart
方法签名：0x9d7eb72b

参数说明：
address marketAddress   捐赠的市场地址
address erc20Address    ERC20代币地址
uint256 value  捐赠的数量

事件：
event RecivedDonate(address marketAddress, address donator, address tokenAddress, uint256 value);
address marketAddress 捐赠的市场地址
address donator 捐赠者
address tokenAddress 捐赠代币的token地址
uint256 value  捐赠的数量

0x9d7eb72b
事件签名：0x8d29859c113f224d6afae8445c7c99741c85f31b9024083a21e8f8bac7ef6f6e
```

#### 12. 用户发起提案(调用Proposal 合约)

```
function newProposal(uint8 _milestone, address _marketAddress, uint256[] memory _reward, uint256[] memory _deadline, address[] memory _rewardCoin, address payable[] memory _beneficiary)public  onlyStart

方法签名：0x3f6dcb7a

uint8 _milestone 里程碑数量
address _marketAddress  发起提案的市场地址
uint256[] memory _reward  提案奖励币的数量
uint256[] memory _deadline  每个里程碑的结束时间
address[] memory _rewardCoin  每个里程碑对应的奖励的币种地址 ETH 为0x0000000000000000000000000000000000000000
address payable[] memory _beneficiary 每个里程碑对应的受益人地址

事件：
event NewProposal(uint256 _proposalCount, address _marketAddress, address _creator);

uint256 _proposalCount  提案ID；
address _marketAddress  发起提案的市场地址；
address _creator  发起提案的人；

事件签名：0x4c8033652a83d28932764a69975304c3acb70295a0f31e86eced53c91a22c614
```

#### 13.把提案转给其他人(调用Proposal 合约)

```
function transferProposal(uint256 _proposalId, address newCreator) public onlyStart

方法签名：0x8d5b3d99

参数说明：
uint256 _proposalId  提案ID
address newCreator   新的creator 地址
```

#### 14.获取提案状态(调用Proposal 合约)

```
function getPropsoalStatus(uint256 _proposalId) public view returns(bool) 

方法签名：0xf9c49ee6

参数说明：
uint256 _proposalId  提案ID

返回值：
bool  true 活跃可用状态， false 不可用状态

```

#### 15.获取提案ID对应的市场地址(调用Proposal 合约)

```
function getProposalMarket(uint256 _proposalId) public view returns(address)

方法签名：0x5e39c785

参数说明：
uint256 _proposalId  提案ID

返回值：
address 提案对应的市场地址
```

#### 16. 获取对应提案的创建者(调用Proposal 合约)

```
function getProposalCreator(uint256 _proposalId) public view returns(address) 
方法签名：0xff05d7fd

参数说明：
uint256 _proposalId  提案ID

返回值：
address  提案创建者地址
```

#### 17. 获取对应提案的当前里程碑阶段(调用Proposal 合约)

```
function getProposalStage(uint256 _proposalId) public  view returns(uint8) 

方法签名：0x582ae53b

参数说明：
uint256 _proposalId  提案ID

返回值：
uint8 当前提案所在的里程碑
```

#### 18. 获取对应提案的总的里程碑阶段数量(调用Proposal 合约)

```
function getProposalMilestone(uint256 _proposalId) public  view returns(uint8)

方法签名：0x2fe9bfdd

参数说明：
uint256 _proposalId  提案ID

返回值：
uint8 当前提案的总的里程碑数量
```

#### 19. 获取对应提案的奖励代币数量(调用Proposal 合约)

```
function getProposalReward(uint256 _proposalId) public view returns(uint256[] memory) 

方法签名：0xb8e938a3

参数说明：
uint256 _proposalId  提案ID


返回值：
uint256[] memory  对应里程碑的对应奖励数量
```

#### 20. 获取对应提案的各个里程碑截至时间(调用Proposal 合约)

```
function getProposalDeadline(uint256 _proposalId) public view returns(uint256[] memory) 

方法签名：0x8f363200

参数说明：
uint256 _proposalId  提案ID

返回值：
uint256[] memory 对应里程碑的截止时间
```

#### 21. 获取对应提案的奖励币种(调用Proposal 合约)

```
function getProposalRewardCoin(uint256 _proposalId) public view returns(address[] memory) 
方法签名：0xf6ba968b

参数说明：
uint256 _proposalId  提案ID


返回值：
address[] memory 对应奖励代币的地址 ETH则为0x0000000000000000000000000000000000000000
```

#### 22.  获取对应提案的受益人信息(调用Proposal 合约)

```
function getProposalBeneficiary(uint256 _proposalId) public  view returns(address payable[] memory) 
方法签名：0xa656985d

参数说明：
uint256 _proposalId  提案ID

返回值：
address payable[] memory  受益人地址
```

#### 23.获取对应提案的对应里程碑阶段的得票数量(调用Proposal 合约)

```
function getProposalVote(uint256 _proposalId, uint8 _stage) public view returns(uint256) 

方法签名：0x45f3c4d6

参数说明：
uint256 _proposalId  提案ID
uint8 _stage 对应的阶段

返回值：
uint256  投票数量
```

#### 24. 获取对应提案对应阶段的投票信息(调用Proposal 合约)

```
function getProposalDetaials(uint256 _proposalId, uint8 _stage) public view returns(address[] memory) 

方法签名：0xae53cab0

参数说明：
uint256 _proposalId  提案ID
uint8 _stage   对应的阶段

返回值：
address[] memory 当前阶段的对应投票地址信息
```

#### 25. 获取某个地址是否对 提案的某个阶段投票情况(调用Proposal 合约)

```
function isVoteForProposal(address _voter, uint256 _proposalId, uint8 _milestone) public view returns(bool) 

方法签名：0xc6435d8a

参数说明：
address _voter  投票人的地址
uint256 _proposalId  提案ID
uint8 _milestone   对应的阶段

返回值：
bool true 已经投票， false 没有投票
```

#### 26.提案创建者修改提案(调用Proposal 合约)

```
function modifyProposal(uint256 _proposalId, uint8 _milestone, uint256[] memory _reward, uint256[] memory _deadline, address[] memory _rewardCoin, address payable[] memory _beneficiary) public onlyStart

方法签名：0xc051dc22

参数说明：
uint256 _proposalId  提案ID
uint8 _milestone    里程碑数
uint256[] memory _reward  奖励代币数量
uint256[] memory _deadline  提案对应里程碑截至时间
address[] memory _rewardCoin  提案的奖励币种  ETH则为0x0000000000000000000000000000000000000000
address payable[] memory _beneficiary  受益人地址

```

#### 27. 给提案投票(调用Proposal 合约)

```
function vote(uint256 _proposalId)public onlyStart 

方法签名：0x0121b93f

参数说明：
uint256 _proposalId  提案ID
```

#### 28. 提案时间截止时总结提案(调用Proposal 合约)

```
function conclusionVote(uint256 _proposalId) public onlyStart
方法签名：0x4d64bcea

参数说明：
uint256 _proposalId  提案ID
```

#### 29.市场解散后市场的人领取属于市场的币(调用Proposal 合约)

```
function withDraw(address _marketAddress) public 
方法签名：0x14174f33

参数说明：
address _marketAddress 市场地址
```

#### 30. 市场管理员请求更改市场回收价(调用市场合约)

```
function requestRecycleChange(uint256 _recycle) public
方法签名：0xfa411dd7

参数说明：
uint256 _recycle  更改的回收价

```

#### 31. 获取可以更改市场回收价的最大值(调用市场合约)

```
function getMaxRecycleRate() public view returns(uint256)

方法签名：0x1e80ef1e

返回值：
uint256 最大回收价
```

#### 32. 管理员给更改市场回收价投票(调用市场合约)

```
function voteForRecycleRate() public 

方法签名：0x7843b705
```

#### 33. 总结更改市场回收价(调用市场合约)

```
function conclusionRecycle() public

方法签名：0x3daf45e6
```

#### 34. 请求升级市场(调用Exchange地址)

```
function upgradeMarket(address marketAddress, address upgraderAddress, address upgrader, uint256 fee, bytes memory upgraderSign) public onlyAdmin 

方法签名：0xb5495f5d


参数说明： 
address marketAddress   市场地址
address upgraderAddress  升级到的另外的市场地址
address upgrader  升级的人
uint256 fee  手续费
bytes memory upgraderSign  升级人的签名
```

#### 35.设置升级的市场地址(调用Exchange地址)

```
function setMigrateFrom(address marketAddress, address migrateFrom, address upgrader, uint256 fee, bytes memory upgraderSign) public onlyAdmin 

方法签名：0x38622004

参数说明： 
address marketAddress   市场地址
address upgraderAddress 需要升级的市场地址
address upgrader  升级的人
uint256 fee  手续费
bytes memory upgraderSign  升级人的签名
```

#### 36.迁移市场(调用市场合约)

```
function migrate(uint256 batchSize) whenMigrating external
方法签名：0x454b0608

参数说明： 
uint256 batchSize  转移的人数

```


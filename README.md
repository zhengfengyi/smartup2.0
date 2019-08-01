## SmartUp 2.0 合约说明

#### 合约步骤

```
1.SUT token合约 （ctConfig 需要设置） 0xf1899c6eb6940021c1ae4e9c3a8e29ee93704b03
2.NTT 合约  （ctConfig 需要设置）（如果需要增加更改NTT权限 去要设置） 0x846ce03199a759a183cccb35146124cd3f120548

3.sutStore 合约      0x6b0d0c9442eaf3079fbc9933900e17b1542e97da
   Gas Limit: 4027415
   Gas Price: 10 Gwei
   Fee:0.0402 Ether

4.SutProxy 合约   0xca9728b23745525eb2e455e17a901080eb7422ec
Transaction Fee:
0.02699552 Ether ($0.000000)
Gas Limit:
2,699,552
Gas Used by Transaction:
2,699,552 (100%)
Gas Price:
0.00000001 Ether (10 Gwei)

5.CreateCtMarket 合约   0x57bE7b5bE0e00206f8fA90925A78A85c285893cf
Transaction Fee:
0.02560621 Ether ($0.000000)
Gas Limit:
2,560,621
Gas Used by Transaction:
2,560,621 (100%)
Gas Price:
0.00000001 Ether (10 Gwei)

6.SutImpl合约    0xe93912ae9316dfc2b4f6661e0b8bcf0b8fe5f92a
Transaction Fee:
0.05915803 Ether ($0.000000)
Gas Limit:
5,915,803
Gas Used by Transaction:
5,915,803 (100%)
Gas Price:
0.00000001 Ether (10 Gwei)

7.Exchange 合约   0x225bd29c241a3874467ccea4fdc6bc4d3d181e3d
//0x225bd29c241a3874467ccea4fdc6bc4d3d181e3d
Transaction Fee:
0.02516133 Ether ($0.000000)
Gas Limit:
2,516,133
Gas Used by Transaction:
2,516,133 (100%)
Gas Price:
0.00000001 Ether (10 Gwei)

8.SutStore 设置sutImplAddress

9.SutProxy 设置sutImplAddress 设置 Exchange地址

10. SutProxy 设置 exchange Address

11.CreateCtMarket 设置 sutImpl地址  exchange地址

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
方法签名：

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
function adminWithdraw(address _token, uint256 _amount, address payable _owner, uint256 nonce, uint256 feeWithdraw, uint256 expires, bytes memory sign)public onlyAdmin
方法签名：
0xb34cdd69

参数说明：
address _token  取钱token地址，若为eth则为（0x0000000000000000000000000000000000000000）
uint256 _amount 数量(必须大于10的15次方)
address payable _owner  取钱的用户地址
uint256 nonce  用户的nonce值
uint256 feeWithdraw 取钱的手续费
uint256 expires  过期区块高度（可以默认为当前区块 + 100， 例如当前区块高度为 100， 则可设置为 200）
bytes memory sign  用户对_token，_amount，_owner，nonce，feeWithdraw的签名

签名的数据: _token, _amount, _owner, nonce, feeWithdraw, expires， sign

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
function createCtMarket(address marketCreator, uint256 initialDeposit, string memory _name, string memory _symbol, uint256 _supply, uint256 _rate, uint256 _lastRate, uint256 fee, uint256 _closingTime, uint256 expires, bytes memory signature) public onlyAdmin

方法签名：0x0d4f1009

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
uint256 expires  过期区块高度（可以默认为当前区块 + 100， 例如当前区块高度为 100， 则可设置为 200);
bytes memory signature 签名

签名的数据：marketCreate， initialDeposit, _name, _symbol, _supply, _rate, _lastRate, Fee,_closingTime,expires

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

消耗的gas信息：    //0xc492daed53502717c5adb5b5a3495cc1e09997f1
Transaction Fee:
0.01681122 Ether ($0.000000)
Gas Limit:
1,800,000
Gas Used by Transaction:
1,681,122 (98.81%)
Gas Price:
0.00000001 Ether (10 Gwei)
````

#### 6.查询Ct市场价格（调用合约CT市场合约）

```
uint256 public exchangeRate;
方法：
function exchangeRate()public pure returns(uint256)
方法签名：0x2c4e722e

返回值：
uint256 市场的CT价格
```

#### 7. 查询Ct市场最后的卖出价（调用Ct市场合约）

```
uint256 public recycleRate;
方法：
function recycleRate()public pure returns(uint256)
方法签名：0x82cac6df

返回值：
uint256 市场的CT最后的价格
```

#### 8.第一阶段购买CT（调用的合约Exchange）

````
function buyCt(address _tokenAddress, uint256 _amount, address _buyer, uint256 fee, uint256 expires, bytes memory signature)public onlyAdmin
方法签名：0x841259a1
参数说明：
address _tokenAddress  Ct市场地址
uint256 _amount   ct数量(ct数量必须大于等于 1 个 即 10 ** 18)
address _buyer  买ct人的地址
uint256 fee 手续费
uint256 expires  过期区块高度（可以默认为当前区块 + 100， 例如当前区块高度为 100， 则可设置为 200);
bytes memory signature 签名

签名数据： _tokenAddress,_amount,_buyer，fee, expires



事件：
FirstPeriodBuyCt(address _ctAddress, address buyer, uint256 _amount, uint256 _costSut);
签名：
0x9015b5305608921691745c016f5aaf6a460a4d2305f3809cc5b51a184a686440
参数说明：
address _ctAddress  ct市场地址
address buyer       buyer地址
uint256 _amount     买的ct数量
uint256 _costSut    花费的Sut
````

#### 9.最后卖出CT （调用的合约Exchange）

````
function sellCt(address _tokenAddress, uint256 _amount)public
方法签名：

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




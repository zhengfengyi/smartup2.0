pragma solidity >=0.4.21 <0.6.0;

interface ICoinStore {
    function internalTransferFrom(address _token, address _from, address _to, uint256 _value) external;
    function internalTransfer(address _token, address _to, uint256 _value) external; 
    function balanceOf(address _token, address _owner) external view returns(uint256);
    function setMarketCreatedBalance(address _market, uint256 _value) external;
    function marketInternalTransfer(address _token, address _from, address _to, uint256 _value) external;
}
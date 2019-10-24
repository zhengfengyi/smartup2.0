pragma solidity >=0.4.21 <0.6.0;

interface IAdmin {
    function onlyAdmin(address _admin) external view returns(bool);
}
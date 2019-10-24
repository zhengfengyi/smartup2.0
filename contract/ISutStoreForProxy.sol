pragma solidity >=0.4.21 <0.6.0;

interface ISutStoreForProxy {

    function creator(address ctAddress) external view returns(address);
    function flaggerSize(address ctAddress) external view returns (uint256);
    function flaggerList(address ctAddress) external view returns (address[] memory);
    function flaggerDeposits(address ctAddress) external view returns (uint256[] memory);
    function jurorSize(address ctAddress) external view returns (uint256);
    function nextFlaggableDate(address ctAddress) external view returns (uint256);
    function flaggingPeriod(address ctAddress) external view returns (uint256 start, uint256 end);
    function votingPeriod(address ctAddress) external view returns (uint256 start, uint256 end);
    function appealRound(address ctAddress) external view returns (uint8);
    function appealerList(address ctAddress) external view returns (address[] memory);
    function appealersDeposit(address ctAddress) external view returns (uint256[] memory);
    function appealerTotalDeposit(address ctAddress) external view returns (uint256);
    function ballots(address ctAddress) external view returns (uint8);
    function marketSize() external view returns (uint256);    
    function getAppealerDeposit(address ctAddress) external view returns(uint256);
    function jurorList(address ctAddress) external view returns (address[] memory);
    function state(address ctAddress) external view returns (uint8);
    function appealerSize(address ctAddress) external view returns (uint256);
    function getFlaggerDeposit(address ctAddress)external view returns (uint256 _dispense);
    function getInitalDeposit(address ctAddress)external view returns(uint256);
    function appealingPeriod(address ctAddress) external view returns (uint256 start, uint256 end);
    
    
    
}
    

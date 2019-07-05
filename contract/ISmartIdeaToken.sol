pragma solidity >=0.4.21 <0.6.0;


/**
 * @title SmartIdeaTokenERC20 token interface
 */
interface ISmartIdeaToken {
    
    function transfer(address _to, uint256 _value) external;

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender and
     *      notify spender of the approval.
     *
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param extraData Data passed to spender, allowing extra operation
     */
    function approveAndCall(address spender, uint256 value, bytes calldata extraData) external returns (bool);
}
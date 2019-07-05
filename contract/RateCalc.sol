pragma solidity >=0.4.21 <0.6.0;

import "./Math.sol";


contract RateCalc {

    using Math for uint256;
    

    uint256 constant FACTOR = 18;
    
    int256 constant f1 = int256(10 ** FACTOR);
    int256 constant f2 = int256(10 ** (18 + FACTOR));
    
    int256 constant a = 74999921875000;
    int256 constant b = 15625000 / 2;
    int256 constant MULTIPLES = 1000;    
    

    /**
     * @dev formula for calculating CT <-> SUT conversion
     */
    function calcSut(uint256 existingCtCount, uint256 newCtCount)
        external
        pure
        returns (int256)
    {   
        return MULTIPLES * ((a * (int256(newCtCount) * (int256(newCtCount.ln(FACTOR)) - f1) - int256(existingCtCount) * (int256(existingCtCount.ln(FACTOR)) - f1)) + b * int256(newCtCount * newCtCount - existingCtCount * existingCtCount)) / f2);
    }
}
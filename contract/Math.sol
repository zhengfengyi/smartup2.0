pragma solidity >=0.4.21 <0.6.0;

import "./SafeMath.sol";

/**
 * @title Math
 * @dev ln operations with safety checks that throw on error
 *      reference: https://www.reddit.com/r/ethereum/comments/253ymf/could_contracts_including_logarithms_be/
 */
library Math {

    using SafeMath for uint256;

    uint256 constant BASE = 100000000000000000000;
    uint256 constant F1_5 =  150000000000000000000;
    uint256 constant LN1_5 = 40546510810816438198;

    uint256 constant DIGITS = 18;
    
    
    function ln(uint256 input, uint256 factor) internal pure returns (uint256) {
        require(factor >= 4 && factor <= DIGITS);
        require(input >= 10 ** factor);
        
        // to increase precision
        input = input.mul(100);
        
        uint256 h = 10 ** (DIGITS - factor);
        uint256 base = BASE / h;

        uint256 result = 0;
        while (input >= F1_5 / h) {
            result = result + LN1_5 / h;
            input = input * 2 / 3;
        }
        input = input - base;
        uint256 y = input;
        uint256 i = 1;
        
        // max iteration is 25, stop if (y / i) == 0 because it would no longer change the result
        while (y / i > 0 && i < 50) {
            result = result + y / i;
            ++i;
            y = y * input / base;
            result = result - y / i;
            ++i;
            y = y * input / base;
        }
        return result / 100;
    }
    
    
    // /**
    //  * @dev gives square root of given x.
    //  */
    // function sqrt(uint256 x)
    //     internal
    //     pure
    //     returns (uint256 y)
    // {
    //     uint256 z = ((x.add(1)) / 2);
    //     y = x;
    //     while (z < y)
    //     {
    //         y = z;
    //         z = x.div(z).add(z).div(2);
    //     }
    // }

    // /**
    //  * @dev gives square. multiplies x by x
    //  */
    // function sq(uint256 x)
    //     internal
    //     pure
    //     returns (uint256)
    // {
    //     return (x.mul(x));
    // }

    // /**
    //  * @dev x to the power of y
    //  */
    // function pwr(uint256 x, uint256 y)
    //     internal
    //     pure
    //     returns (uint256)
    // {
    //     if (x == 0)
    //         return (0);
    //     else if (y == 0)
    //         return (1);
    //     else
    //     {
    //         uint256 z = x;
    //         for (uint256 i = 1; i < y; i++)
    //             z = z.mul(x);
    //         return (z);
    //     }
    // }
}
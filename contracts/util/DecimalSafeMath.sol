pragma solidity ^0.6.6;

library DecimalSafeMath {

    function decimalDiv(uint256 a, uint256 b)internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
       
        uint256 c = (a * 1000000000000000000) / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function decimalMul(uint256 a, uint256 b)internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = (a * b) / 1000000000000000000;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }
}
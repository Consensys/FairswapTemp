pragma solidity ^0.6.0;

import "../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ShareToken is ERC20 {
    constructor (string memory name, string memory symbol) 
    public ERC20(name, symbol) {}
}

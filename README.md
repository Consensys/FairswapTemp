### This is iDOL vs ETH swap 
- Basic structure is the same as other Fairswaps (Fairswap_iDOLvsLBT, Fairswap_iDOLvsLien, Fairswap_OPYN)

## Some differences from other Fairswaps
- Fee transfer to lien token is paid in both ETH and eth(iDOL)
- Fee for lientoken can be transfered to lien token anytime

## Test
- When you execute test, try using `ganache-cli -b 1` to execute `Promise.all(orders)`

## interfaces
### functions about deployment
- constructor(address _tokenAddress, address payable _lienTokenAddress) public
- function initializeExchange(uint256 _ethAmount, 
                            uint256 _tokenAmount)external

### functions about liquidity
- function removeLiquidity (uint _timeout,
                            uint256 _mineth,
                            uint256 _minTokens,
                            uint256 _sharesBurned) external
- function addLiquidity(uint256 _timeout,
                         uint256 _ethAmount,
                         uint256 _minShares) external isOpen
- function removeAfterMaturity() external

### functions that submit order and execution
- function OrderEthToToken(uint256 _timeout,
                               uint256 _ethAmount,
                               bool _isLimit) isOpen external
- function OrderTokenToEth(uint256 _timeout,
                                 uint256 _tokenAmount,
                                 bool _isLimit) isOpen external
- function excuteUnexecutedBox() public

### function that transfer some part of fee to Lien Token
- function sendFeeToLien() external

### view functions
- function getExchangeData() external view returns 
(uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256)
- function getShare(address user) external view returns (uint256)
- function getTokenAddress() external view returns (address) 
- function getTokensForLien() external view returns (uint256, uint256)
- function getTotalShare() external view returns (uint256)
- function getPoolAmount() external view returns (uint256, uint256) 
- function getBoxSummary() external view 
                        returns (uint256, uint256, uint256, uint256)
- function getBuyerdata(uint256 place, bool _isLimit) external view
                        returns (address, uint256)
- function getSellerdata(uint256 place, bool _isLimit) external view
                        returns (address, uint256)
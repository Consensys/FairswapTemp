pragma solidity >=0.5.0 <0.7.0;
import "./SafeMath.sol";
import "./ExchangeFactory.sol";
import "./ShareToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BoxExchange {
    using DecimalSafeMath for uint256;

    /// EVENTS
    event AcceptEthToTokenOrders(
        address indexed buyer,
        uint256 indexed ethIn,
        uint256 indexed boxNumber
    );
    event AcceptTokenToEthOrders(
        address indexed buyer,
        uint256 indexed tokensIn,
        uint256 indexed boxNumber
    );
    event InvestLiqidity(
        address indexed liquidityProvider,
        uint256 indexed sharesPurchased
    );
    event RemoveLiquidity(
        address indexed liquidityProvider,
        uint256 indexed sharesBurned
    );
    event ExecuteOrder(
        uint256 indexed boxNumber,
        bool isSurplus
    );
    event Price(
        uint256 Price,
        uint256 refundRateBuy0,
        uint256 refundRateBuy1,
        uint256 refundRateSell0,
        uint256 refundRateSell1
    );
    event pool(uint256 ethpool, uint256 tokenpool);

     /// CONSTANTS
    uint256 public constant POOL_RATE = 800000000000000000; // 80% of fee goes to pool
    uint256 public constant FEE_RATE = 3000000000000000; //fee = 0.3%
    uint256 public constant FEE_RATE_FOR_LIEN = 600000000000000; //6 basis point
    uint256 public constant TOLERANCE_RATE = 1000000000000000; //= 0.1%
    uint256 public constant SECURE_RATE = 50000000000000000; //5%
    uint256 public constant DECIMAL = 1000000000000000000;
    uint256 public constant MAX_EXECUTE_ACCOUNT = 10;//one transaction can execute 10 orders

  
    struct ExchangeBox {
        uint32 unexecuted;
        uint8 unexecutedCategory;
        uint32 blockNumber;
        uint128 FEE_RATE;
        mapping(uint8 => uint256) price;
        mapping(address => uint256) buyOrdersLimit;
        mapping(address => uint256) buyOrders;
        mapping(address => uint256) sellOrders;
        mapping(address => uint256) sellOrdersLimit;
        address payable[] buyers;
        address payable[] buyersLimit;
        address payable[] sellers;
        address payable[] sellersLimit;
        uint256 totalBuyAmount;
        uint256 totalBuyAmountLimit;
        uint256 totalSellAmount;
        uint256 totalSellAmountLimit;
    }

    /// STORAGE
    mapping(uint256 => ExchangeBox) Exchange;
    bool private isSurplus;//if true, some orders are unexecuted yet.
    uint32 private nextExecuteBoxNumber = 1;
    uint32 private nextBoxNumber = 1;
    uint256 private tokenPool;// pool of token(iDOL)
    uint256 private ethPool;// pool of ETH
    uint256 private ethForLien;//amount of ETH for Lien token
    uint256 private tokenForLien;//amount of token for Lien token
    address private tokenAddress;
    address payable private lienTokenAddress;

    ShareToken share;
    IERC20 token;

    /// MODIFIERS
    modifier exchangeInitialized() {
        require((share.totalSupply() > 0 && ethPool > 0 && tokenPool > 0), "exchange is not initialized");
        _;
    }

    modifier onlyLienToken {
        require(msg.sender == lienTokenAddress, "Only LienToken can call this function.");
        _;
    }

    constructor(address _tokenAddress, address payable _lienTokenAddress) public {
        tokenAddress = _tokenAddress;
        token = IERC20(tokenAddress);
        lienTokenAddress = _lienTokenAddress;
        share = new ShareToken("ShareEthIDOL", "SEID");
    }
    //At first one LP should open exchange and get 1000 shares
    //First LP can define ratio of token
    //Both Amount should be bigger than 10000
    function initializeExchange(uint256 _tokenAmount) external payable {
        require(share.totalSupply() == 0, "Already initialized");
        require(msg.value >= 10000 && _tokenAmount >= 10000, "You should approve over 10000 tokens");
        require(token.transferFrom(msg.sender, address(this), _tokenAmount), "Could not receive your base token.");
        
        ethPool = msg.value;
        tokenPool = _tokenAmount;
        share.mint(msg.sender, 1000 * DECIMAL);
    }
    //Submit Buy Order
    //if _isLimit is true and ethPool/tokenPool * 0.999 < Price, the order will be executed, otherwise baseToken will be refunded
    //if _isLimit is false and ethPool/tokenPool * 0.95 < Price, the order will be executed, otherwise baseToken will be refunded
    function OrderEthToToken(uint256 _timeout, bool _isLimit) external payable {
        require(_timeout > nextBoxNumber, "Time out"); 
        require(msg.value > 0, "Amount should bigger than 0");

        if (Exchange[nextBoxNumber - 1].blockNumber != 0 && Exchange[nextBoxNumber - 1].blockNumber + 1 >= block.number) {
            if(nextBoxNumber - 1 > nextExecuteBoxNumber){
                _executionOrders();
            }
            if(_isLimit){
                if (Exchange[nextBoxNumber - 1].buyOrdersLimit[msg.sender] == 0) {
                    Exchange[nextBoxNumber - 1].buyOrdersLimit[msg.sender] = msg.value.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].buyersLimit.push(msg.sender);
                    Exchange[nextBoxNumber - 1].totalBuyAmountLimit += msg.value;
                } else {
                    Exchange[nextBoxNumber - 1].buyOrdersLimit[msg.sender] += msg.value.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].totalBuyAmountLimit += msg.value;
                }
            } else {
                if (Exchange[nextBoxNumber - 1].buyOrders[msg.sender] == 0) {
                    Exchange[nextBoxNumber - 1].buyOrders[msg.sender] = msg.value.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].buyers.push(msg.sender);
                    Exchange[nextBoxNumber - 1].totalBuyAmount += msg.value;
                }else{
                    Exchange[nextBoxNumber - 1].buyOrders[msg.sender] += msg.value.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].totalBuyAmount += msg.value;
                }
            }
        } else {
            //when new box is generated, orderer should execute privious box
            if (nextBoxNumber > 1 && nextBoxNumber > nextExecuteBoxNumber) {
                _executionOrders();
            }
            //open new box
            nextBoxNumber += 1;
            Exchange[nextBoxNumber-1].blockNumber = uint32(block.number);
            if(_isLimit){
                    Exchange[nextBoxNumber - 1].buyOrdersLimit[msg.sender] = msg.value.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].buyersLimit.push(msg.sender);
                    Exchange[nextBoxNumber - 1].totalBuyAmountLimit += msg.value;
            }else{
                    Exchange[nextBoxNumber - 1].buyOrders[msg.sender] = msg.value.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].buyers.push(msg.sender);
                    Exchange[nextBoxNumber - 1].totalBuyAmount += msg.value;
                }
        }
        emit AcceptEthToTokenOrders(msg.sender, msg.value, nextBoxNumber);
    }
//Submit Sell Order
//if _isLimit is true and ethPool/tokenPool * 1.001 > Price, the order will be executed, otherwise baseToken will be refunded
//if _isLimit is false and when ethPool/tokenPool * 1.01 > Price, the order will be executed, otherwise baseToken will be refunded
 function OrderTokenToEth(uint256 _timeout, uint256 _tokenAmount, bool _isLimit) external {
        require(_tokenAmount > 0, "Amount should bigger than 0");
        require(_timeout > nextBoxNumber, "Time out");
        require(token.transferFrom(msg.sender, address(this), _tokenAmount), "Could not receive your token.");
         if (Exchange[nextBoxNumber - 1].blockNumber != 0 && Exchange[nextBoxNumber - 1].blockNumber + 1 >= block.number) {
            if(nextBoxNumber - 1 > nextExecuteBoxNumber){
                _executionOrders();
            }
            if(_isLimit){
                if (Exchange[nextBoxNumber - 1].sellOrdersLimit[msg.sender] == 0) {
                    Exchange[nextBoxNumber - 1].sellOrdersLimit[msg.sender] = _tokenAmount.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].sellersLimit.push(msg.sender);
                    Exchange[nextBoxNumber - 1].totalSellAmountLimit += _tokenAmount;
                } else {
                    Exchange[nextBoxNumber - 1].sellOrdersLimit[msg.sender] += _tokenAmount.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].totalSellAmountLimit += _tokenAmount;
                }
            } else {
                if (Exchange[nextBoxNumber - 1].sellOrders[msg.sender] == 0) {
                    Exchange[nextBoxNumber - 1].sellOrders[msg.sender] = _tokenAmount.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].sellers.push(msg.sender);
                    Exchange[nextBoxNumber - 1].totalSellAmount += _tokenAmount;
                }else{
                    Exchange[nextBoxNumber - 1].sellOrders[msg.sender] += _tokenAmount.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].totalSellAmount += _tokenAmount;
                }
            }
        } else {
            //when new box is generated, orderer should execute privious box
            if (nextBoxNumber > 1 && nextBoxNumber > nextExecuteBoxNumber) {
                _executionOrders();
            }
            //open new box
            nextBoxNumber += 1;
            Exchange[nextBoxNumber-1].blockNumber = uint32(block.number);
            if(_isLimit){
                    Exchange[nextBoxNumber - 1].sellOrdersLimit[msg.sender] = _tokenAmount.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].sellersLimit.push(msg.sender);
                    Exchange[nextBoxNumber - 1].totalSellAmountLimit += _tokenAmount;
            }else{
                    Exchange[nextBoxNumber - 1].sellOrders[msg.sender] = _tokenAmount.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].sellers.push(msg.sender);
                    Exchange[nextBoxNumber - 1].totalSellAmount += _tokenAmount;
                }
        }
        emit AcceptTokenToEthOrders(msg.sender, _tokenAmount, nextBoxNumber);
    }

     function addLiquidity(uint256 _timeout, uint256 _minShares) external payable{   
        require(msg.value > 0);
        require(_timeout > nextBoxNumber, "Time out");
        require(_minShares > 0,  "minimum share < 0");
        uint256 _totalShares = share.totalSupply().div(DECIMAL);
        uint256 ethPerShare = ethPool.div(_totalShares);
        require(msg.value >= ethPerShare, "Please send enough eth");
        uint256 sharesPurchased = msg.value.div(ethPerShare);
        require(sharesPurchased >= _minShares, "You can't get enough shares");
        uint256 tokensPerShare = tokenPool.div(_totalShares);
        uint256 tokensRequired = sharesPurchased.mul(tokensPerShare);
        require(token.transferFrom(msg.sender, address(this), tokensRequired), "Could not receive settlement token.");
        share.mint(msg.sender, sharesPurchased.mul(DECIMAL));
        ethPool = ethPool.add(msg.value);
        tokenPool = tokenPool.add(tokensRequired);
    }
// Remove liquidity for LP
//_sharesBurned is amount of burn
//_minEth is minimum ETH they will get (revert if baseToken amount is smaller than _minBaseTokens)
//_mintokens is minimum token they will get (revert if lienToken amount is smaller than _minLienTokens)
//this kind of order is not contained in exchange box
 function removeLiquidity (uint _timeout,
        uint256 _minEth,
        uint256 _minTokens,
        uint256 _sharesBurned
    ) external {
        require(_timeout > nextBoxNumber,"Time out");
        require(share.balanceOf(msg.sender) >= _sharesBurned, "You don't have enough shares");
        if (_sharesBurned > 0) {
            uint256 _totalShares = share.totalSupply().div(DECIMAL);
            uint256 ethPerShare = ethPool.div(_totalShares);
            uint256 tokensPerShare = tokenPool.div(_totalShares);
            uint256 ethDivested = ethPerShare.mul(_sharesBurned);
            uint256 tokensDivested = tokensPerShare.mul(_sharesBurned);
            require(ethDivested >= _minEth, "Invalid minimum ETH");
            require(tokensDivested >= _minTokens, "Invalid minimum token");
            share.burn(msg.sender, _sharesBurned * DECIMAL);
            ethPool = ethPool.sub(ethDivested);
            tokenPool = tokenPool.sub(tokensDivested);
            require(token.transfer(msg.sender, tokensDivested), "Error: Could not send token.");
            msg.sender.transfer(ethDivested);
        }
    }

    //If users want to excute their order instantly, anyone can try this function
    function excuteUnexecutedBox() external{
        //condition of execution is the same as that of OrderSettlementToBase() and OrderBaseToSettlement
        if (Exchange[nextBoxNumber - 1].blockNumber != 0 && Exchange[nextBoxNumber - 1].blockNumber + 1 >= block.number) {
            if(nextBoxNumber - 1 > nextExecuteBoxNumber){
                _executionOrders();
            }
        } else {
           if (nextBoxNumber > 1 && nextBoxNumber > nextExecuteBoxNumber) {
                _executionOrders();
            }
        }
    }

    //Send ETH and iDOL to Lien token
    function sendFeeToLien() external {
        
        lienTokenAddress.transfer(ethForLien);
        
        require(token.transfer(lienTokenAddress, tokenForLien), "could not send token to lien");
        ethForLien = 0;
        tokenForLien = 0;
        
    }

    //calculate and return price, and refund rates
    //refund for careful users if change of price is bigger than TORELANCE_RATE
    //refund for all traders if change of price is bigger than SECURE_RATE
    function _calculatePrice() private returns (uint256, uint256, uint256, uint256, uint256) {
        uint256 buyAmount = _calculateAmount(Exchange[nextExecuteBoxNumber].totalBuyAmount);
        uint256 sellAmount = _calculateAmount(Exchange[nextExecuteBoxNumber].totalSellAmount);
        uint256 buyAmountLimit = _calculateAmount(Exchange[nextExecuteBoxNumber].totalBuyAmountLimit);
        uint256 sellAmountLimit = _calculateAmount(Exchange[nextExecuteBoxNumber].totalSellAmountLimit);
        //initial price = tokenPool / ethPool
        uint256 price = ((tokenPool.mul(DECIMAL)).add(sellAmount).add(sellAmountLimit)).decimalDiv((ethPool.mul(DECIMAL)).add(buyAmount).add(buyAmountLimit));
        // initial low Price is price of Limit order(initial price * 0.999)
        uint256 lowPrice = (tokenPool.decimalDiv(ethPool)).decimalMul(DECIMAL.sub(TOLERANCE_RATE));
        // initial high Price is price of Limit order(initial price * 1.001)
        uint256 highPrice = (tokenPool.decimalDiv(ethPool)).decimalMul(DECIMAL.add(TOLERANCE_RATE));
    
        // if initial price is within the TORELANCE_RATE, return initial price and execute all orders
        if(price >= lowPrice && price <= highPrice){
            _calculatePool(buyAmount.add(buyAmountLimit), sellAmount.add(sellAmountLimit), price);
            _calculateTokenForLien(buyAmount.add(buyAmountLimit), sellAmount.add(sellAmountLimit));
            return (price, 0, 0, 0, 0);
        } else if(price < lowPrice){
            //executeAmount is amount of buy orders when the price is lower than lowPrice (initial price * 0.999)
            uint256 executeAmount = (((tokenPool.mul(DECIMAL)).add(sellAmount).add(sellAmountLimit)).decimalDiv(lowPrice)).sub((ethPool.mul(DECIMAL)));
            //if executeAmount > buyAmount, (buyAmount - executeAmount) in limit order will be executed
            if(executeAmount > buyAmount){
                uint256 refundRate = (buyAmount.add(buyAmountLimit).sub(executeAmount)).decimalDiv(buyAmountLimit);
                _calculatePool(executeAmount, sellAmount.add(sellAmountLimit), lowPrice);
                _calculateTokenForLien(executeAmount, sellAmount.add(sellAmountLimit));
                return(lowPrice, 0, refundRate.decimalMul(DECIMAL + FEE_RATE), 0, 0);
            } else {// refumd all limit buy orders
                //update lowPrice to SECURE_RATE
                lowPrice =(tokenPool.decimalDiv(ethPool)).decimalMul(DECIMAL.sub(SECURE_RATE));
                if( lowPrice > price){
                     //executeAmount is amount of buy orders when the price is lower than lowPrice (initial price * 0.95)
                    executeAmount = (((tokenPool.mul(DECIMAL)).add(sellAmount).add(sellAmountLimit)).decimalDiv(lowPrice)).sub(ethPool.mul(DECIMAL));
                    //if executeAmount < buyAmount, refund all of limit buy orders and refund some parts of no-limit buy orders
                    if(executeAmount < buyAmount){
                        uint256 refundRate = (buyAmount.sub(executeAmount)).decimalDiv(buyAmount);
                        _calculatePool(executeAmount, sellAmount.add(sellAmountLimit), lowPrice);
                        _calculateTokenForLien(executeAmount, sellAmount.add(sellAmountLimit));
                        return(lowPrice, refundRate.decimalMul(DECIMAL + FEE_RATE), (DECIMAL + FEE_RATE), 0, 0);
                    }else{
                        // execute all no-limit buy orders and refund all limit buy orders
                        // update price
                        price = ((tokenPool.mul(DECIMAL)).add(sellAmount).add(sellAmountLimit)).decimalDiv((ethPool.mul(DECIMAL)).add(buyAmount));
                         _calculatePool(buyAmount, sellAmount.add(sellAmountLimit), price);
                         _calculateTokenForLien(buyAmount, sellAmount.add(sellAmountLimit));
                        return(price, 0, DECIMAL + FEE_RATE, 0, 0);
                    }
                }else{
                    // execute all no-limit buy orders and refund all limit buy orders
                    // update price
                    price = ((tokenPool.mul(DECIMAL)).add(sellAmount).add(sellAmountLimit)).decimalDiv((ethPool.mul(DECIMAL)).add(buyAmount));
                     _calculatePool(buyAmount, sellAmount.add(sellAmountLimit), price);
                     _calculateTokenForLien(buyAmount, sellAmount.add(sellAmountLimit));
                    return(price, 0, DECIMAL + FEE_RATE, 0, 0);
                }
            }
        } else {
            //executeAmount is amount of sell orders when the price is higher than highPrice(initial price * 1.001)
            uint256 executeAmount = (((ethPool.mul(DECIMAL)).add(buyAmount).add(buyAmountLimit)).decimalMul(highPrice)).sub(tokenPool.mul(DECIMAL));
            if(executeAmount > sellAmount){
                 //if executeAmount > sellAmount, (sellAmount - executeAmount) in limit order will be executed
                uint256 refundRate = (sellAmount.add(sellAmountLimit).sub(executeAmount)).decimalDiv(sellAmountLimit);
                _calculatePool(buyAmount.add(buyAmountLimit), executeAmount, highPrice);
                _calculateTokenForLien(buyAmount.add(buyAmountLimit), executeAmount);
                return (highPrice, 0, 0, 0, refundRate.decimalMul(DECIMAL + FEE_RATE));
            } else {// refumd all limit sell orders
                //update highPrice to SECURE_RATE
                highPrice = (tokenPool.decimalDiv(ethPool)).decimalMul(DECIMAL.add(SECURE_RATE));
                if(highPrice < price){
                    //executeAmount is amount of sell orders when the price is higher than highPrice(initial price * 1.05)
                    executeAmount = (((ethPool.mul(DECIMAL)).add(buyAmount).add(buyAmountLimit)).decimalMul(highPrice)).sub(tokenPool.mul(DECIMAL));
                    // if executeAmount < sellAmount, refund all of limit sell orders and refund some parts of no-limit sell orders
                    if(executeAmount < sellAmount){
                        uint256 refundRate = (sellAmount.sub(executeAmount)).decimalDiv(sellAmount);
                        _calculatePool(buyAmount.add(buyAmountLimit), executeAmount, highPrice);
                        _calculateTokenForLien(buyAmount.add(buyAmountLimit), executeAmount);
                        return (highPrice, 0, 0, refundRate.decimalMul(DECIMAL + FEE_RATE), DECIMAL + FEE_RATE);
                    }else{// execute all no-limit sell orders and refund all limit sell orders
                        // update price
                        price = ((tokenPool.mul(DECIMAL)).add(sellAmount)).decimalDiv((ethPool.mul(DECIMAL)).add(buyAmount).add(buyAmountLimit));
                        _calculatePool(buyAmount.add(buyAmountLimit), sellAmount, price);
                        _calculateTokenForLien(buyAmount.add(buyAmountLimit), sellAmount);
                        return (price, 0, 0, 0, DECIMAL + FEE_RATE);
                }
                }else{
                    // execute all no-limit sell orders and refund all limit sell orders
                    // update price
                    price = ((tokenPool.mul(DECIMAL)).add(sellAmount)).decimalDiv((ethPool.mul(DECIMAL)).add(buyAmount).add(buyAmountLimit));
                    _calculatePool(buyAmount.add(buyAmountLimit), sellAmount, price);
                    _calculateTokenForLien(buyAmount.add(buyAmountLimit), sellAmount);
                    return (price, 0, 0, 0, DECIMAL + FEE_RATE);
                }
            }
        } 
    }


    //calculate both pools and add fees
    function _calculatePool(uint256 buyAmount, uint256 sellAmount, uint256 price) private{
         uint256 decimalethPool = ethPool.mul(DECIMAL);
         uint256 decimaltokenPool = tokenPool.mul(DECIMAL);
         ethPool = (decimalethPool.add(buyAmount.decimalMul(DECIMAL + (FEE_RATE.decimalMul(POOL_RATE)))).sub(sellAmount.decimalDiv(price))).div(DECIMAL);
         tokenPool = (decimaltokenPool.add(sellAmount.decimalMul(DECIMAL + (FEE_RATE.decimalMul(POOL_RATE)))).sub(buyAmount.decimalMul(price))).div(DECIMAL);
    }

// when amount > 0, mul 10**18 to amount, else return 1
    function _calculateAmount(uint256 amount) private pure returns (uint256) {
        if (amount == 0) {
            return 1;
        } else {
            return (amount.mul(DECIMAL).decimalDiv(DECIMAL + FEE_RATE));
        }
    }
//Calculate fees for Lien token
    function _calculateTokenForLien(uint256 _buyAmount, uint256 _sellAmount) private{
        ethForLien += (_buyAmount.decimalMul(uint256(FEE_RATE_FOR_LIEN))).div(DECIMAL);
        tokenForLien += (_sellAmount.decimalMul(uint256(FEE_RATE_FOR_LIEN))).div(DECIMAL);
    }

//Private functions

//execution has 4 steps
//1. calculate price and refund rate (if isSurplus is true, get price and refund rate from latest exchange box)
//2. detect addresses whose order will be executed in this transaction
//3. send and refund tokens
//4. update information (if execution is finished, isSurplus = false. Otherwise, register price and refund rate, and set isSurplus = true)

function _executionOrders() private {
        uint256 price;
        uint256 refundBuy0;
        uint256 refundBuy1;
        uint256 refundSell0;
        uint256 refundSell1;
        uint8 category;
        uint256 k;
        uint256 unexecuted;
        if(isSurplus){//if surplus is true, get price and refundRate from current nextExecuteBoxNumber
            price = Exchange[nextExecuteBoxNumber].price[0];
            refundBuy0 = Exchange[nextExecuteBoxNumber].price[1];
            refundBuy1 = Exchange[nextExecuteBoxNumber].price[2];
            refundSell0 = Exchange[nextExecuteBoxNumber].price[3];
            refundSell1 = Exchange[nextExecuteBoxNumber].price[4];
            category = Exchange[nextExecuteBoxNumber].unexecutedCategory;//last executed order category
            unexecuted = Exchange[nextExecuteBoxNumber].unexecuted;//place of last executed address
        }else{
           (price, refundBuy0, refundBuy1, refundSell0, refundSell1) = _calculatePrice();
        }

        emit Price(price, refundBuy0, refundBuy1, refundSell0, refundSell1);
        emit pool(ethPool, tokenPool);
        address payable[] storage buyers0 = Exchange[nextExecuteBoxNumber].buyers;
        address payable[] storage buyers1 = Exchange[nextExecuteBoxNumber].buyersLimit;
        address payable[] storage sellers0 = Exchange[nextExecuteBoxNumber].sellers;
        address payable[] storage sellers1 = Exchange[nextExecuteBoxNumber].sellersLimit;
        //count the number of addresses of execution in this transaction
        uint256[5] memory length = _calculateLength(buyers0.length, buyers1.length, sellers0.length, sellers1.length, category, unexecuted);
        
        emit Price(length[0], length[1], length[2], length[3], length[4]);
        
        if(category == 1){k = unexecuted;}else{k = 0;}
        _paymentBuy(k, length[0], price, refundBuy0, buyers0, Exchange[nextExecuteBoxNumber].buyOrders);
        if(category == 2){k = unexecuted;}else{k = 0;}
        _paymentBuy(k, length[1], price, refundBuy1, buyers1, Exchange[nextExecuteBoxNumber].buyOrdersLimit);
        if(category == 3){k = unexecuted;}else{k = 0;}
        _paymentSell(k, length[2], price, refundSell0, sellers0, Exchange[nextExecuteBoxNumber].sellOrders);
        if(category == 4){k = unexecuted;}else{k = 0;}
        _paymentSell(k, length[3], price, refundSell1, sellers1, Exchange[nextExecuteBoxNumber].sellOrdersLimit);
        
        if(length[4] == 0){
            // increment nextExecuteBoxNumber
            nextExecuteBoxNumber += 1;
            isSurplus = false;
        } else{
            //if execution has not ended due to the number of orders, register price and refundRate data
            Exchange[nextExecuteBoxNumber].unexecutedCategory = uint8(length[4]);
            isSurplus = true;
            Exchange[nextExecuteBoxNumber].unexecuted = uint8(length[length[4] - 1]);
            Exchange[nextExecuteBoxNumber].price[0] = price;
            Exchange[nextExecuteBoxNumber].price[1] = refundBuy0;
            Exchange[nextExecuteBoxNumber].price[2] = refundBuy1;
            Exchange[nextExecuteBoxNumber].price[3] = refundSell0;
            Exchange[nextExecuteBoxNumber].price[4] = refundSell1;
        }

    }

    //send tokens of buy order
    //orders are executed from _start to _end
    function _paymentBuy(uint _start, uint _end, uint _price, uint _refundRate,
                         address payable[] memory orderers, 
                         mapping(address => uint) storage buyOrders) 
                         private {
        if(_end > 0){
            if (_refundRate > 0){
                for (uint256 i = _start; i < _end; i++) {
                address payable orderer = orderers[i];
                uint256 refundAmount = _refundRate.decimalMul(buyOrders[orderer]);
                if(_refundRate < DECIMAL){
                    require(token.transfer(orderer, (buyOrders[orderer].sub(refundAmount)).decimalMul(_price)), "send token error");
                }
                orderer.transfer(refundAmount);
                
                }   
            } else{
                for (uint256 i = _start; i < _end; i++) {
                address payable orderer = orderers[i];
                require(token.transfer(orderer, (buyOrders[orderer]).decimalMul(_price)), "send token error");         
                } 
            }
        }
    }

    //send tokens of sell order
    //orders are executed from _start to _end
    function _paymentSell(uint _start, uint _end, uint _price, uint _refundRate,
                         address payable[] memory orderers, 
                         mapping(address => uint) storage sellOrders)
                         private {
        if(_end > 0){
            if (_refundRate > 0){
                for (uint256 i = _start; i < _end; i++) {
                address payable orderer = orderers[i];
                uint256 refundAmount = _refundRate.decimalMul(sellOrders[orderer]);
                require(token.transfer(orderer, refundAmount), "refund token error");
                if(_refundRate < DECIMAL){
                    orderer.transfer((sellOrders[orderer].sub(refundAmount)).decimalDiv(_price));
                }
                
                }   
            } else{
                for (uint256 i = _start; i < _end; i++) {
                    address payable orderer = orderers[i];
                    orderer.transfer((sellOrders[orderer]).decimalDiv(_price));         
                } 
            }
        }
    }

    //count number of addresses of execution in this transaction
    //the number of addresses should lesser than MAX_EXECUTE_ACCOUNT
     function _calculateLength(uint _buyers0, uint _buyers1, uint _sellers0, uint _sellers1, uint _lastExecuted, uint _unexecuted) private view returns(uint256[5] memory){
        if(isSurplus){
            _lastExecuted -= 1;
            uint256[4] memory orderlength = [_buyers0, _buyers1, _sellers0, _sellers1];
            uint256[5] memory length = [DECIMAL, DECIMAL, DECIMAL, DECIMAL, 0];
            uint256 accountLength = MAX_EXECUTE_ACCOUNT;
            for(uint i = 0; i < 4; i++){
                if(i < _lastExecuted){
                    length[i] = 0;
                } else if(i == _lastExecuted){
                    if(orderlength[i] - _unexecuted < MAX_EXECUTE_ACCOUNT){
                        length[i] = orderlength[i] - _unexecuted;
                        accountLength -= orderlength[i] - _unexecuted;
                    }else{
                        length[i] = _unexecuted + MAX_EXECUTE_ACCOUNT;
                        length[4] = i + 1;
                        return length;
                    }
                } else {
                    if(orderlength[i] > accountLength){
                        length[i] = accountLength;
                        length[4] = i + 1;
                        return length;
                    } else {
                        length[i] = orderlength[i];
                        accountLength -= orderlength[i];
                    }
                }
            }
            return length;
        } else if(_buyers0 > MAX_EXECUTE_ACCOUNT){
            return [MAX_EXECUTE_ACCOUNT, 0, 0, 0, 1];
        } else if((_buyers0 + _buyers1) > MAX_EXECUTE_ACCOUNT){
            return [_buyers0, MAX_EXECUTE_ACCOUNT - _buyers0, 0, 0, 2];
        } else if((_buyers0 + _buyers1 + _sellers0) > MAX_EXECUTE_ACCOUNT){
            return [_buyers0, _buyers1, MAX_EXECUTE_ACCOUNT - _buyers0 - _buyers1, 0, 3];
        } else if((_buyers0 + _buyers1 + _sellers0 + _sellers1) > MAX_EXECUTE_ACCOUNT){
            return [_buyers0, _buyers1, _sellers0, MAX_EXECUTE_ACCOUNT - _buyers0 - _buyers1 - _sellers0, 4];
        } else {
            return[_buyers0, _buyers1, _sellers0, _sellers1, 0];
        }
    }

    function getExchangeData() external view returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256){
        uint buyPrice = (DECIMAL + FEE_RATE).decimalMul(tokenPool).decimalDiv(ethPool);
        uint sellPrice = (ethPool.sub(tokenPool)).decimalDiv(DECIMAL + FEE_RATE);
        return(nextBoxNumber, ethPool, tokenPool, 
            share.totalSupply(), ethPool.div(share.totalSupply()), tokenPool.div(share.totalSupply()), buyPrice, sellPrice);
    }
    
    function getShare(address user) external view returns (uint256) {
        return share.balanceOf(user);
    }

    function getTokenAddress() external view returns (address) {
        return tokenAddress;
    }
    
    function getTokensForLien() external view returns (uint256, uint256) {
        return(ethForLien, tokenForLien);
    }


    function getTotalShare() external view returns (uint256) {
        return share.totalSupply();
    }

    function getPoolAmount() external view returns (uint256, uint256) {
        return (ethPool, tokenPool);
    }

    function getBoxSummary()
        external
        view
        returns (uint256, uint256, uint256, uint256)
    {
        return (
            Exchange[nextExecuteBoxNumber].totalBuyAmount,
            Exchange[nextExecuteBoxNumber].totalBuyAmountLimit,
            Exchange[nextExecuteBoxNumber].totalSellAmount,
            Exchange[nextExecuteBoxNumber].totalSellAmountLimit
        );
    }
    

    function getBuyerdata(uint256 place, bool _isLimit)
        external
        view
        returns (address, uint256)
    {
        if(_isLimit){
            address payable[] storage users = Exchange[nextExecuteBoxNumber].buyersLimit;
            address user = users[place];
        
            return (user, Exchange[nextExecuteBoxNumber].buyOrdersLimit[user]);
        }else{
            address payable[] storage users = Exchange[nextExecuteBoxNumber].buyers;
            address user = users[place];
        
            return (user, Exchange[nextExecuteBoxNumber].buyOrders[user]);
        }
    }

    function getSellerdata(uint256 place, bool _isLimit)
        external
        view
        returns (address, uint256)
    {
        if(_isLimit){
            address payable[] storage users = Exchange[nextExecuteBoxNumber].sellersLimit;
            address user = users[place];
        
            return (user, Exchange[nextExecuteBoxNumber].sellOrdersLimit[user]);
        }else{
            address payable[] storage users = Exchange[nextExecuteBoxNumber].sellers;
            address user = users[place];
        
            return (user, Exchange[nextExecuteBoxNumber].sellOrders[user]);
        }
    }
}

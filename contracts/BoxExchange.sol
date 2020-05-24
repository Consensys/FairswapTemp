pragma solidity >=0.5.0 <0.7.0;
import "./ExchangeFactory.sol";
import "./ShareToken.sol";
import "./util/DecimalSafeMath.sol";

contract BoxExchange is ShareToken("ShareiDOLETH", "siDOL") {
    using DecimalSafeMath for uint256;
    using SafeMath for uint256;

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
    event ExecuteOrder(uint256 indexed boxNumber, bool isSurplus);
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
    uint256 public constant MAX_EXECUTE_ACCOUNT = 10; //one transaction can execute 10 orders

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
    mapping(uint256 => ExchangeBox) private Exchange;
    bool private isSurplus; //if true, some orders are unexecuted yet.
    uint32 internal nextExecuteBoxNumber = 1;
    uint32 internal nextBoxNumber = 1;
    uint256 public tokenPool; // pool of token(iDOL)
    uint256 public ethPool; // pool of ETH
    uint256 public ethForLien; //amount of ETH for Lien token
    uint256 public tokenForLien; //amount of token for Lien token
    address public tokenAddress;
    address payable public lienTokenAddress;

    IERC20 token;

    /// MODIFIERS

    modifier onlyLienToken {
        require(
            msg.sender == lienTokenAddress,
            "Only LienToken can call this function."
        );
        _;
    }

    /**
     * constructor
     * @param _tokenAddress Address of token
     * @param _lienTokenAddress Address of Lien token
     **/
    constructor(address _tokenAddress, address payable _lienTokenAddress)
        public
    {
        tokenAddress = _tokenAddress;
        token = IERC20(tokenAddress);
        lienTokenAddress = _lienTokenAddress;
    }

    /**
     * initializeExchange
     * @notice At first one LP should open exchange through providing liquidity and get 1000 shares. First LP can define ratio of token
     * @param _tokenAmount Amount of token
     * @dev Both token Amount should be bigger than 10000
     * @dev LP should send ETH
     **/
    function initializeExchange(uint256 _tokenAmount) external payable {
        require(totalSupply() == 0, "Already initialized");
        require(
            msg.value >= 10000 && _tokenAmount >= 10000,
            "You should approve over 10000 tokens"
        );

        ethPool = msg.value;
        tokenPool = _tokenAmount;
        require(
            token.transferFrom(msg.sender, address(this), _tokenAmount),
            "Could not receive your base token."
        );
        _mint(msg.sender, 1000 * DECIMAL);
    }

    /**
     * OrderBaseToSettlement
     * @notice Submit and resister Buy Order
     * @param _timeout Revert if nextBoxNumber exceeds _timeout
     * @param _isLimit Whether the order restricts a large slippage.
     * @dev if _isLimit is true and ethPool/tokenPool * 0.999 < Price, the order will be executed, otherwise ETH will be refunded
     * @dev if _isLimit is false and ethPool/tokenPool * 0.95 < Price, the order will be executed, otherwise ETH will be refunded
     **/
    function orderEthToToken(uint256 _timeout, bool _isLimit) external payable {
        require(_timeout > nextBoxNumber, "Time out");
        require(msg.value > 0, "Amount should bigger than 0");

        if (
            Exchange[nextBoxNumber - 1].blockNumber != 0 &&
            Exchange[nextBoxNumber - 1].blockNumber + 1 >= block.number
        ) {
            if (nextBoxNumber - 1 > nextExecuteBoxNumber) {
                _executionOrders();
            }
            // the following amounts are guaranteed never to overflow as each value is capped by the total issue amount of each token.
            if (_isLimit) {
                if (
                    Exchange[nextBoxNumber - 1].buyOrdersLimit[msg.sender] == 0
                ) {
                    Exchange[nextBoxNumber - 1].buyOrdersLimit[msg.sender] = msg
                        .value
                        .decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].buyersLimit.push(msg.sender);
                    Exchange[nextBoxNumber - 1].totalBuyAmountLimit += msg
                        .value;
                } else {
                    Exchange[nextBoxNumber - 1].buyOrdersLimit[msg
                        .sender] += msg.value.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].totalBuyAmountLimit += msg
                        .value;
                }
            } else {
                if (Exchange[nextBoxNumber - 1].buyOrders[msg.sender] == 0) {
                    Exchange[nextBoxNumber - 1].buyOrders[msg.sender] = msg
                        .value
                        .decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].buyers.push(msg.sender);
                    Exchange[nextBoxNumber - 1].totalBuyAmount += msg.value;
                } else {
                    Exchange[nextBoxNumber - 1].buyOrders[msg.sender] += msg
                        .value
                        .decimalDiv(DECIMAL + FEE_RATE);
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
            Exchange[nextBoxNumber - 1].blockNumber = uint32(block.number);
            if (_isLimit) {
                Exchange[nextBoxNumber - 1].buyOrdersLimit[msg.sender] = msg
                    .value
                    .decimalDiv(DECIMAL + FEE_RATE);
                Exchange[nextBoxNumber - 1].buyersLimit.push(msg.sender);
                Exchange[nextBoxNumber - 1].totalBuyAmountLimit += msg.value;
            } else {
                Exchange[nextBoxNumber - 1].buyOrders[msg.sender] = msg
                    .value
                    .decimalDiv(DECIMAL + FEE_RATE);
                Exchange[nextBoxNumber - 1].buyers.push(msg.sender);
                Exchange[nextBoxNumber - 1].totalBuyAmount += msg.value;
            }
        }
        emit AcceptEthToTokenOrders(msg.sender, msg.value, nextBoxNumber);
    }

    /**
     * OrderSettlementToBase
     * @notice Submit and resister Sell Order
     * @param _timeout Revert if nextBoxNumber exceeds _timeout
     * @param _tokenAmount Amount of token that should be approved before executing this function
     * @param _isLimit Whether the order restricts a large slippage.
     * @dev if _isLimit is true and ethPool/tokenPool * 1.001 > Price, the order will be executed, otherwise token will be refunded
     * @dev if _isLimit is false and when ethPool/tokenPool * 1.01 > Price, the order will be executed, otherwise token will be refunded
     **/
    function orderTokenToEth(
        uint256 _timeout,
        uint256 _tokenAmount,
        bool _isLimit
    ) external {
        require(_tokenAmount > 0, "Amount should bigger than 0");
        require(_timeout > nextBoxNumber, "Time out");
        if (
            Exchange[nextBoxNumber - 1].blockNumber != 0 &&
            Exchange[nextBoxNumber - 1].blockNumber + 1 >= block.number
        ) {
            if (nextBoxNumber - 1 > nextExecuteBoxNumber) {
                _executionOrders();
            }
            if (_isLimit) {
                // the following amounts are guaranteed never to overflow as each value is capped by the total issue amount of each token.
                if (
                    Exchange[nextBoxNumber - 1].sellOrdersLimit[msg.sender] == 0
                ) {
                    Exchange[nextBoxNumber - 1].sellOrdersLimit[msg
                        .sender] = _tokenAmount.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].sellersLimit.push(msg.sender);
                    Exchange[nextBoxNumber - 1]
                        .totalSellAmountLimit += _tokenAmount;
                } else {
                    Exchange[nextBoxNumber - 1].sellOrdersLimit[msg
                        .sender] += _tokenAmount.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1]
                        .totalSellAmountLimit += _tokenAmount;
                }
            } else {
                if (Exchange[nextBoxNumber - 1].sellOrders[msg.sender] == 0) {
                    Exchange[nextBoxNumber - 1].sellOrders[msg
                        .sender] = _tokenAmount.decimalDiv(DECIMAL + FEE_RATE);
                    Exchange[nextBoxNumber - 1].sellers.push(msg.sender);
                    Exchange[nextBoxNumber - 1].totalSellAmount += _tokenAmount;
                } else {
                    Exchange[nextBoxNumber - 1].sellOrders[msg
                        .sender] += _tokenAmount.decimalDiv(DECIMAL + FEE_RATE);
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
            Exchange[nextBoxNumber - 1].blockNumber = uint32(block.number);
            if (_isLimit) {
                Exchange[nextBoxNumber - 1].sellOrdersLimit[msg
                    .sender] = _tokenAmount.decimalDiv(DECIMAL + FEE_RATE);
                Exchange[nextBoxNumber - 1].sellersLimit.push(msg.sender);
                Exchange[nextBoxNumber - 1]
                    .totalSellAmountLimit += _tokenAmount;
            } else {
                Exchange[nextBoxNumber - 1].sellOrders[msg
                    .sender] = _tokenAmount.decimalDiv(DECIMAL + FEE_RATE);
                Exchange[nextBoxNumber - 1].sellers.push(msg.sender);
                Exchange[nextBoxNumber - 1].totalSellAmount += _tokenAmount;
            }
        }
        emit AcceptTokenToEthOrders(msg.sender, _tokenAmount, nextBoxNumber);
        require(
            token.transferFrom(msg.sender, address(this), _tokenAmount),
            "Could not receive your token."
        );
    }

    /**
     * addLiquidity
     * @notice Add liquidity for LP
     * @param _timeout Revert if nextBoxNumber exceeds _timeout
     * @param _minShares Minimum shares they will get (revert if share amount is smaller than _minShares)
     * @dev Amount of token will be calculated based on msg.value
     **/
    function addLiquidity(uint256 _timeout, uint256 _minShares)
        external
        payable
    {
        require(msg.value > 0);
        require(_timeout > nextBoxNumber, "Time out");
        require(_minShares > 0, "Invalid _minshares");
        uint256 _totalShares = totalSupply();
        uint256 ethPerShare = (ethPool.mul(DECIMAL)).decimalDiv(_totalShares);
        require(
            msg.value >= ethPerShare.div(DECIMAL),
            "Please send enough eth"
        );
        uint256 sharesPurchased = (msg.value.mul(DECIMAL)).decimalDiv(
            ethPerShare
        );
        require(sharesPurchased >= _minShares, "You can't get enough shares");
        uint256 tokensPerShare = (tokenPool.mul(DECIMAL)).decimalDiv(
            _totalShares
        );
        uint256 tokensRequired = (sharesPurchased.decimalMul(tokensPerShare))
            .div(DECIMAL);
        ethPool = ethPool.add(msg.value);
        tokenPool = tokenPool.add(tokensRequired);
        require(
            token.transferFrom(msg.sender, address(this), tokensRequired),
            "Could not receive settlement token."
        );
        _mint(msg.sender, sharesPurchased);
    }

    /**
     * removeLiquidity
     * @notice Remove liquidity for LP
     * @param _timeout Revert if nextBoxNumber exceeds _timeout
     * @param _minEth Minimum ETH they will get (revert if ETH amount is smaller than _minETH)
     * @param _minTokens Minimum token they will get (revert if token amount is smaller than _mintokens)
     * @param _sharesBurned Amount of burn
     * @dev This kind of order is not contained in exchange box
     **/
    function removeLiquidity(
        uint256 _timeout,
        uint256 _minEth,
        uint256 _minTokens,
        uint256 _sharesBurned
    ) external {
        require(_timeout > nextBoxNumber, "Time out");
        require(
            balanceOf(msg.sender) >= _sharesBurned,
            "You don't have enough shares"
        );
        require(_sharesBurned > 0);
        uint256 _totalShares = totalSupply();
        uint256 ethDivested = (ethPool.mul(_sharesBurned)).div(_totalShares);
        uint256 tokensDivested = (tokenPool.mul(_sharesBurned)).div(
            _totalShares
        );
        require(ethDivested >= _minEth, "Invalid minimum ETH");
        require(tokensDivested >= _minTokens, "Invalid minimum token");
        ethPool = ethPool.sub(ethDivested);
        tokenPool = tokenPool.sub(tokensDivested);
        _burn(msg.sender, _sharesBurned);
        require(
            token.transfer(msg.sender, tokensDivested),
            "Error: Could not send token."
        );
        _transferETH(msg.sender, ethDivested);
    }

    /**
     * executeUnexecutedBox
     * @notice If users want to excute their order instantly, anyone can try this function.
     **/
    function executeUnexecutedBox() external {
        //condition of execution is the same as that of OrderSettlementToBase() and OrderBaseToSettlement
        if (
            Exchange[nextBoxNumber - 1].blockNumber != 0 &&
            Exchange[nextBoxNumber - 1].blockNumber + 1 >= block.number
        ) {
            if (nextBoxNumber - 1 > nextExecuteBoxNumber) {
                _executionOrders();
            }
        } else {
            if (nextBoxNumber > 1 && nextBoxNumber > nextExecuteBoxNumber) {
                _executionOrders();
            }
        }
    }

    /**
     * sendFeeToLien
     * @notice Send baseToken and ETH from LBT to Lien token.
     **/
    function sendFeeToLien() external {
        uint256 _ethForLien = ethForLien;
        uint256 _tokenForLien = tokenForLien;
        ethForLien = 0;
        tokenForLien = 0;
        lienTokenAddress.transfer(_ethForLien);
        require(
            token.transfer(lienTokenAddress, _tokenForLien),
            "could not send token to lien"
        );
    }

    /**
     * @notice calculate and return price, and refund rates
     * @return price Price in this box
     * @return refundBuy0 Refund rate of no-limit buy order
     * @return refundBuy1 Refund rate of limit buy order
     * @return refundSell0 Refund rate of no-limit sell order
     * @return refundSell1 Refund rate of limit sell order
     * @dev Refund for careful users if change of price is bigger than TORELANCE_RATE
     * @dev Refund for all traders if change of price is bigger than SECURE_RATE
     **/
    function _calculatePrice()
        private
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 buyAmount = _calculateAmount(
            Exchange[nextExecuteBoxNumber].totalBuyAmount
        );
        uint256 sellAmount = _calculateAmount(
            Exchange[nextExecuteBoxNumber].totalSellAmount
        );
        uint256 buyAmountLimit = _calculateAmount(
            Exchange[nextExecuteBoxNumber].totalBuyAmountLimit
        );
        uint256 sellAmountLimit = _calculateAmount(
            Exchange[nextExecuteBoxNumber].totalSellAmountLimit
        );
        //initial price = tokenPool / ethPool
        uint256 price = (
            (tokenPool.mul(DECIMAL)).add(sellAmount).add(sellAmountLimit)
        )
            .decimalDiv(
            (ethPool.mul(DECIMAL)).add(buyAmount).add(buyAmountLimit)
        );
        // initial low Price is price of Limit order(initial price * 0.999)
        uint256 lowPrice = (tokenPool.decimalDiv(ethPool)).decimalMul(
            DECIMAL.sub(TOLERANCE_RATE)
        );
        // initial high Price is price of Limit order(initial price * 1.001)
        uint256 highPrice = (tokenPool.decimalDiv(ethPool)).decimalMul(
            DECIMAL.add(TOLERANCE_RATE)
        );

        // if initial price is within the TORELANCE_RATE, return initial price and execute all orders
        if (price >= lowPrice && price <= highPrice) {
            _calculatePool(
                buyAmount.add(buyAmountLimit),
                sellAmount.add(sellAmountLimit),
                price
            );
            return (price, 0, 0, 0, 0);
        } else if (price < lowPrice) {
            return
                _calculateLowPrice(
                    price,
                    lowPrice,
                    buyAmount,
                    buyAmountLimit,
                    sellAmount.add(sellAmountLimit)
                );
        } else {
            return
                _calculateHighPrice(
                    price,
                    highPrice,
                    buyAmount.add(buyAmountLimit),
                    sellAmount,
                    sellAmountLimit
                );
        }
    }

    /**
     * @notice calculate price and refund rates if price is lower than lowPrice
     * @param price price which is calculated in _calculatePrice()
     * @param lowPrice tokenPool / ethPool * 0.999
     * @param buyAmount Amount of no-limit buy order
     * @param buyAmountLimit Amount of limit buy order
     * @param sellAmount Amount of all sell order. In this function, all sell order will be executed.
     * @return price Price in this box
     * @return refundBuy0 Refund rate of no-limit buy order
     * @return refundBuy1 Refund rate of limit buy order
     * @return refundSell0 Refund rate of no-limit sell order
     * @return refundSell1 Refund rate of limit sell order
     * @dev Refund for careful users if change of price is bigger than TORELANCE_RATE
     * @dev Refund for all traders if change of price is bigger than SECURE_RATE
     **/
    function _calculateLowPrice(
        uint256 price,
        uint256 lowPrice,
        uint256 buyAmount,
        uint256 buyAmountLimit,
        uint256 sellAmount
    )
        private
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        // executeAmount is amount of buy orders in lowPrice(initial price * 0.999)
        uint256 executeAmount = (
            ((tokenPool.mul(DECIMAL)).add(sellAmount)).decimalDiv(lowPrice)
        )
            .sub((ethPool.mul(DECIMAL)));
        //if executeAmount > buyAmount, (buyAmount - executeAmount) in limit order will be executed
        if (executeAmount > buyAmount) {
            uint256 refundRate = (
                buyAmount.add(buyAmountLimit).sub(executeAmount)
            )
                .decimalDiv(buyAmountLimit);
            _calculatePool(executeAmount, sellAmount, lowPrice);
            return (
                lowPrice,
                0,
                refundRate.decimalMul(DECIMAL + FEE_RATE),
                0,
                0
            );
        } else {
            // refumd all limit buy orders
            //update lowPrice to SECURE_RATE
            lowPrice = (tokenPool.decimalDiv(ethPool)).decimalMul(
                DECIMAL.sub(SECURE_RATE)
            );
            if (lowPrice > price) {
                //executeAmount is amount of buy orders when the price is lower than lowPrice (initial price * 0.95)
                executeAmount = (
                    ((tokenPool.mul(DECIMAL)).add(sellAmount)).decimalDiv(
                        lowPrice
                    )
                )
                    .sub(ethPool.mul(DECIMAL));
                //if executeAmount < buyAmount, refund all of limit buy orders and refund some parts of no-limit buy orders
                if (executeAmount < buyAmount) {
                    uint256 refundRate = (buyAmount.sub(executeAmount))
                        .decimalDiv(buyAmount);
                    _calculatePool(executeAmount, sellAmount, lowPrice);
                    return (
                        lowPrice,
                        refundRate.decimalMul(DECIMAL + FEE_RATE),
                        (DECIMAL + FEE_RATE),
                        0,
                        0
                    );
                } else {
                    // execute all no-limit buy orders and refund all limit buy orders
                    // update price
                    price = ((tokenPool.mul(DECIMAL)).add(sellAmount))
                        .decimalDiv((ethPool.mul(DECIMAL)).add(buyAmount));
                    _calculatePool(buyAmount, sellAmount, price);
                    return (price, 0, DECIMAL + FEE_RATE, 0, 0);
                }
            } else {
                // execute all no-limit buy orders and refund all limit buy orders
                // update price
                price = ((tokenPool.mul(DECIMAL)).add(sellAmount)).decimalDiv(
                    (ethPool.mul(DECIMAL)).add(buyAmount)
                );
                _calculatePool(buyAmount, sellAmount, price);
                return (price, 0, DECIMAL + FEE_RATE, 0, 0);
            }
        }
    }

    /**
     * @notice calculate price and refund rates if price is higher than highPrice
     * @param price price which is calculated in _calculatePrice()
     * @param highPrice tokenPool / ethPool * 1.001
     * @param buyAmount Amount of all buy order. In this function, all buy order will be executed.
     * @param sellAmount Amount of no-limit buy order.
     * @param sellAmountLimit Amount of limit sell order
     * @return price Price in this box
     * @return refundBuy0 Refund rate of no-limit buy order
     * @return refundBuy1 Refund rate of limit buy order
     * @return refundSell0 Refund rate of no-limit sell order
     * @return refundSell1 Refund rate of limit sell order
     * @dev Refund for careful users if change of price is bigger than TORELANCE_RATE
     * @dev Refund for all traders if change of price is bigger than SECURE_RATE
     **/
    function _calculateHighPrice(
        uint256 price,
        uint256 highPrice,
        uint256 buyAmount,
        uint256 sellAmount,
        uint256 sellAmountLimit
    )
        private
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        //executeAmount is amount of sell orders when the price is higher than highPrice(initial price * 1.001)
        uint256 executeAmount = (
            ((ethPool.mul(DECIMAL)).add(buyAmount)).decimalMul(highPrice)
        )
            .sub(tokenPool.mul(DECIMAL));
        if (executeAmount > sellAmount) {
            //if executeAmount > sellAmount, (sellAmount - executeAmount) in limit order will be executed
            uint256 refundRate = (
                sellAmount.add(sellAmountLimit).sub(executeAmount)
            )
                .decimalDiv(sellAmountLimit);
            _calculatePool(buyAmount, executeAmount, highPrice);
            return (
                highPrice,
                0,
                0,
                0,
                refundRate.decimalMul(DECIMAL + FEE_RATE)
            );
        } else {
            // refumd all limit sell orders
            //update highPrice to SECURE_RATE
            highPrice = (tokenPool.decimalDiv(ethPool)).decimalMul(
                DECIMAL.add(SECURE_RATE)
            );
            if (highPrice < price) {
                //executeAmount is amount of sell orders when the price is higher than highPrice(initial price * 1.05)
                executeAmount = (
                    ((ethPool.mul(DECIMAL)).add(buyAmount)).decimalMul(
                        highPrice
                    )
                )
                    .sub(tokenPool.mul(DECIMAL));
                // if executeAmount < sellAmount, refund all of limit sell orders and refund some parts of no-limit sell orders
                if (executeAmount < sellAmount) {
                    uint256 refundRate = (sellAmount.sub(executeAmount))
                        .decimalDiv(sellAmount);
                    _calculatePool(buyAmount, executeAmount, highPrice);
                    return (
                        highPrice,
                        0,
                        0,
                        refundRate.decimalMul(DECIMAL + FEE_RATE),
                        DECIMAL + FEE_RATE
                    );
                } else {
                    // execute all no-limit sell orders and refund all limit sell orders
                    // update price
                    price = ((tokenPool.mul(DECIMAL)).add(sellAmount))
                        .decimalDiv((ethPool.mul(DECIMAL)).add(buyAmount));
                    _calculatePool(buyAmount, sellAmount, price);
                    return (price, 0, 0, 0, DECIMAL + FEE_RATE);
                }
            } else {
                // execute all no-limit sell orders and refund all limit sell orders
                // update price
                price = ((tokenPool.mul(DECIMAL)).add(sellAmount)).decimalDiv(
                    (ethPool.mul(DECIMAL)).add(buyAmount)
                );
                _calculatePool(buyAmount, sellAmount, price);
                return (price, 0, 0, 0, DECIMAL + FEE_RATE);
            }
        }
    }

    /**
     * @notice Calculate both pool after execution
     * @param _buyAmount Amount of ETH that will be executed
     * @param _sellAmount Amount of token that will be executed
     * @param _price Price of in this box
     **/
    function _calculatePool(
        uint256 _buyAmount,
        uint256 _sellAmount,
        uint256 _price
    ) private {
        uint256 decimalethPool = ethPool.mul(DECIMAL);
        uint256 decimaltokenPool = tokenPool.mul(DECIMAL);
        _calculateTokenForLien(_buyAmount, _sellAmount);
        ethPool = (
            decimalethPool
                .add(
                _buyAmount.decimalMul(
                    DECIMAL + (FEE_RATE.decimalMul(POOL_RATE))
                )
            )
                .sub(_sellAmount.decimalDiv(_price))
        )
            .div(DECIMAL);
        tokenPool = (
            decimaltokenPool
                .add(
                _sellAmount.decimalMul(
                    DECIMAL + (FEE_RATE.decimalMul(POOL_RATE))
                )
            )
                .sub(_buyAmount.decimalMul(_price))
        )
            .div(DECIMAL);
    }

    /**
     * @return when amount > 0, mul 10**18 to amount, else return 1
     **/
    function _calculateAmount(uint256 amount) private pure returns (uint256) {
        if (amount == 0) {
            return 1;
        } else {
            return (amount.mul(DECIMAL).decimalDiv(DECIMAL + FEE_RATE));
        }
    }

    /**
     * @notice Calculate and update fee for Lien token
     * @param _buyAmount Amount of ETH that will be executed
     * @param _sellAmount Amount of token that will be executed
     **/
    // the following amounts are guaranteed never to overflow as each value is capped by the total issue amount of each token.
    function _calculateTokenForLien(uint256 _buyAmount, uint256 _sellAmount)
        private
    {
        ethForLien += (_buyAmount.decimalMul(uint256(FEE_RATE_FOR_LIEN))).div(
            DECIMAL
        );
        tokenForLien += (_sellAmount.decimalMul(uint256(FEE_RATE_FOR_LIEN)))
            .div(DECIMAL);
    }

    //Private functions

    /**
     * @notice Calculate price and execute orders
     * @dev This function can execute only ten orders in one transaction
     * @dev 1. calculate price and refund rate (if isSurplus is true, get price and refund rate from latest exchange box)
     * @dev 2. detect addresses whose order will be executed in this transaction
     * @dev 3. send and refund token and ETH
     * @dev 4. update information (if execution is finished, isSurplus = false. Otherwise, register price and refund rate, and set isSurplus = true)
     **/
    function _executionOrders() private {
        uint256 price;
        uint256 refundBuy0;
        uint256 refundBuy1;
        uint256 refundSell0;
        uint256 refundSell1;
        uint8 category;
        uint256 unexecuted;
        uint256 _nextExecuteBoxNumber = nextExecuteBoxNumber;
        if (isSurplus) {
            //if surplus is true, get price and refundRate from current nextExecuteBoxNumber
            price = Exchange[_nextExecuteBoxNumber].price[0];
            refundBuy0 = Exchange[_nextExecuteBoxNumber].price[1];
            refundBuy1 = Exchange[_nextExecuteBoxNumber].price[2];
            refundSell0 = Exchange[_nextExecuteBoxNumber].price[3];
            refundSell1 = Exchange[_nextExecuteBoxNumber].price[4];
            category = Exchange[_nextExecuteBoxNumber].unexecutedCategory; //last executed order category
            unexecuted = Exchange[_nextExecuteBoxNumber].unexecuted; //place of last executed address
        } else {
            (
                price,
                refundBuy0,
                refundBuy1,
                refundSell0,
                refundSell1
            ) = _calculatePrice();
        }

        emit Price(price, refundBuy0, refundBuy1, refundSell0, refundSell1);
        emit pool(ethPool, tokenPool);
        address payable[] storage buyers0 = Exchange[_nextExecuteBoxNumber]
            .buyers;
        address payable[] storage buyers1 = Exchange[_nextExecuteBoxNumber]
            .buyersLimit;
        address payable[] storage sellers0 = Exchange[_nextExecuteBoxNumber]
            .sellers;
        address payable[] storage sellers1 = Exchange[_nextExecuteBoxNumber]
            .sellersLimit;
        //count the number of addresses of execution in this transaction
        uint256[5] memory length = _calculateLength(
            buyers0.length,
            buyers1.length,
            sellers0.length,
            sellers1.length,
            category,
            unexecuted
        );

        emit Price(length[0], length[1], length[2], length[3], length[4]);
        if (length[4] == 0) {
            // increment nextExecuteBoxNumber
            nextExecuteBoxNumber += 1;
            isSurplus = false;
        } else {
            //if execution has not ended due to the number of orders, register price and refundRate data
            Exchange[_nextExecuteBoxNumber].unexecutedCategory = uint8(
                length[4]
            );
            isSurplus = true;
            Exchange[_nextExecuteBoxNumber].unexecuted = uint8(
                length[length[4] - 1]
            );
            Exchange[_nextExecuteBoxNumber].price[0] = price;
            Exchange[_nextExecuteBoxNumber].price[1] = refundBuy0;
            Exchange[_nextExecuteBoxNumber].price[2] = refundBuy1;
            Exchange[_nextExecuteBoxNumber].price[3] = refundSell0;
            Exchange[_nextExecuteBoxNumber].price[4] = refundSell1;
        }

        if (category == 1) {
            _payment(
                unexecuted,
                length[0],
                price,
                refundBuy0,
                true,
                buyers0,
                Exchange[_nextExecuteBoxNumber].buyOrders
            );
        } else {
            _payment(
                0,
                length[0],
                price,
                refundBuy0,
                true,
                buyers0,
                Exchange[_nextExecuteBoxNumber].buyOrders
            );
        }

        if (category == 2) {
            _payment(
                unexecuted,
                length[1],
                price,
                refundBuy1,
                true,
                buyers1,
                Exchange[_nextExecuteBoxNumber].buyOrdersLimit
            );
        } else {
            _payment(
                0,
                length[1],
                price,
                refundBuy1,
                true,
                buyers1,
                Exchange[_nextExecuteBoxNumber].buyOrdersLimit
            );
        }

        if (category == 3) {
            _payment(
                unexecuted,
                length[2],
                price,
                refundSell0,
                false,
                sellers0,
                Exchange[_nextExecuteBoxNumber].sellOrders
            );
        } else {
            _payment(
                0,
                length[2],
                price,
                refundSell0,
                false,
                sellers0,
                Exchange[_nextExecuteBoxNumber].sellOrders
            );
        }

        if (category == 4) {
            _payment(
                unexecuted,
                length[3],
                price,
                refundSell1,
                false,
                sellers1,
                Exchange[_nextExecuteBoxNumber].sellOrdersLimit
            );
        } else {
            _payment(
                0,
                length[3],
                price,
                refundSell1,
                false,
                sellers1,
                Exchange[_nextExecuteBoxNumber].sellOrdersLimit
            );
        }
    }

    /**
     * @notice Send and Refund tokens.
     * @param _start First place of execution in order list.
     * @param _end Last place of execution in this order list.
     * @param _price Price of this box
     * @param _refundRate Refund rate in this order list
     * @param orderers List of orderers
     * @param orders mapping of orders
     **/
    function _payment(
        uint256 _start,
        uint256 _end,
        uint256 _price,
        uint256 _refundRate,
        bool _isBuy,
        address payable[] memory orderers,
        mapping(address => uint256) storage orders
    ) private {
        if (_end > 0) {
            for (uint256 i = _start; i < _end; i++) {
                address payable orderer = orderers[i];
                uint256 refundAmount = _refundRate.decimalMul(orders[orderer]);
                if (_isBuy) {
                    if (_refundRate < DECIMAL) {
                        require(
                            token.transfer(
                                orderer,
                                (orders[orderer].sub(refundAmount)).decimalDiv(
                                    _price
                                )
                            ),
                            "Send error"
                        );
                    }
                    if (_refundRate > 0) {
                        //if refundrate > 0, refund baseToken
                        _transferETH(orderer, refundAmount);
                    }
                } else {
                    if (_refundRate < DECIMAL) {
                        _transferETH(
                            orderer,
                            (orders[orderer].sub(refundAmount)).decimalDiv(
                                _price
                            )
                        );
                    }
                    if (_refundRate > 0) {
                        //if refundrate > 0, refund baseToken
                        require(
                            token.transfer(orderer, refundAmount),
                            "Refund error"
                        );
                    }
                }
            }
        }
    }

    /**
     * @notice Safe transfer of ETH
     * @param _recipient Recipient of ETH
     * @param _amount Amount of ETH
     **/
    function _transferETH(address _recipient, uint256 _amount) private {
        (bool success, ) = _recipient.call{value: _amount}(
            abi.encodeWithSignature("")
        );
        require(success, "Transfer Failed");
    }

    /**
     * @notice Count number of addresses of execution in this transaction
     * @param _buyers0 Length of no-limit buyer list.
     * @param _buyers1 Length of limit buyer list.
     * @param _sellers0 Length of no-limit seller list.
     * @param _sellers1 Length of limit seller list.
     * @dev the number of addresses should be smaller than MAX_EXECUTE_ACCOUNT
     **/
    function _calculateLength(
        uint256 _buyers0,
        uint256 _buyers1,
        uint256 _sellers0,
        uint256 _sellers1,
        uint256 _lastExecuted,
        uint256 _unexecuted
    ) private view returns (uint256[5] memory) {
        if (isSurplus) {
            _lastExecuted -= 1;
            uint256[4] memory orderlength = [
                _buyers0,
                _buyers1,
                _sellers0,
                _sellers1
            ];
            uint256[5] memory length = [DECIMAL, DECIMAL, DECIMAL, DECIMAL, 0];
            uint256 accountLength = MAX_EXECUTE_ACCOUNT;
            for (uint256 i = 0; i < 4; i++) {
                if (i < _lastExecuted) {
                    length[i] = 0;
                } else if (i == _lastExecuted) {
                    if (orderlength[i] - _unexecuted < MAX_EXECUTE_ACCOUNT) {
                        length[i] = orderlength[i] - _unexecuted;
                        accountLength -= orderlength[i] - _unexecuted;
                    } else {
                        length[i] = _unexecuted + MAX_EXECUTE_ACCOUNT;
                        length[4] = i + 1;
                        return length;
                    }
                } else {
                    if (orderlength[i] > accountLength) {
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
        } else if (_buyers0 > MAX_EXECUTE_ACCOUNT) {
            return [MAX_EXECUTE_ACCOUNT, 0, 0, 0, 1];
        } else if ((_buyers0 + _buyers1) > MAX_EXECUTE_ACCOUNT) {
            return [_buyers0, MAX_EXECUTE_ACCOUNT - _buyers0, 0, 0, 2];
        } else if ((_buyers0 + _buyers1 + _sellers0) > MAX_EXECUTE_ACCOUNT) {
            return [
                _buyers0,
                _buyers1,
                MAX_EXECUTE_ACCOUNT - _buyers0 - _buyers1,
                0,
                3
            ];
        } else if (
            (_buyers0 + _buyers1 + _sellers0 + _sellers1) > MAX_EXECUTE_ACCOUNT
        ) {
            return [
                _buyers0,
                _buyers1,
                _sellers0,
                MAX_EXECUTE_ACCOUNT - _buyers0 - _buyers1 - _sellers0,
                4
            ];
        } else {
            return [_buyers0, _buyers1, _sellers0, _sellers1, 0];
        }
    }

    function getExchangeData()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 buyPrice = (DECIMAL + FEE_RATE)
            .decimalMul(tokenPool)
            .decimalDiv(ethPool);
        uint256 sellPrice = (ethPool.sub(tokenPool)).decimalDiv(
            DECIMAL + FEE_RATE
        );
        return (
            nextBoxNumber,
            ethPool,
            tokenPool,
            totalSupply(),
            ethPool.div(totalSupply()),
            tokenPool.div(totalSupply()),
            buyPrice,
            sellPrice
        );
    }

    function getBoxSummary()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
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
        if (_isLimit) {
            address payable[] storage users = Exchange[nextExecuteBoxNumber]
                .buyersLimit;
            address user = users[place];

            return (user, Exchange[nextExecuteBoxNumber].buyOrdersLimit[user]);
        } else {
            address payable[] storage users = Exchange[nextExecuteBoxNumber]
                .buyers;
            address user = users[place];

            return (user, Exchange[nextExecuteBoxNumber].buyOrders[user]);
        }
    }

    function getSellerdata(uint256 place, bool _isLimit)
        external
        view
        returns (address, uint256)
    {
        if (_isLimit) {
            address payable[] storage users = Exchange[nextExecuteBoxNumber]
                .sellersLimit;
            address user = users[place];

            return (user, Exchange[nextExecuteBoxNumber].sellOrdersLimit[user]);
        } else {
            address payable[] storage users = Exchange[nextExecuteBoxNumber]
                .sellers;
            address user = users[place];

            return (user, Exchange[nextExecuteBoxNumber].sellOrders[user]);
        }
    }
}

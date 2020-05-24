pragma solidity >=0.5.0 <0.7.0;
import "./BoxExchange.sol";


interface FactoryInterface {
    function launchExchange(address _token) external returns (address exchange);

    function tokenToExchangeLookup(address _token)
        external
        view
        returns (address exchange);

    event ExchangeLaunch(address indexed exchange, address indexed token);
}


contract ExchangeFactory is FactoryInterface {
    event ExchangeLaunch(address indexed exchange, address indexed token);
    address payable private lienTokenAddress;
    mapping(address => address) tokenToExchange;

    /**
     * constructor
     * @param _lienTokenAddress Address of Lien token
     **/
    constructor(address payable _lienTokenAddress) public {
        lienTokenAddress = _lienTokenAddress;
    }

    /**
     * launchExchange
     * @notice Launch new exchange
     * @param _token Target token address
     * @dev Get strileprice and maturity from bond maker contract
     **/
    function launchExchange(address _token)
        external
        override(FactoryInterface)
        returns (address exchange)
    {
        require(tokenToExchange[_token] == address(0)); //There can be only one exchange per token
        require(_token != address(0) && _token != address(this));
        BoxExchange newExchange = new BoxExchange(_token, lienTokenAddress);
        address exchangeAddress = address(newExchange);
        tokenToExchange[_token] = exchangeAddress;
        emit ExchangeLaunch(exchangeAddress, _token);
        return exchangeAddress;
    }

    /**
     * tokenToExchangeLookup
     * @notice Get exchange address from Address of LBT
     * @param _token Address of LBT
     **/
    function tokenToExchangeLookup(address _token)
        external
        override(FactoryInterface)
        view
        returns (address exchange)
    {
        return tokenToExchange[_token];
    }
}

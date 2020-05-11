pragma solidity ^0.6.6;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ShareToken is ERC20 {
  address owner;

  event Mint(address indexed to, uint256 amount);
  event Burn(address indexed to, uint256 amount);

  bool public mintingFinished = false;

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }
  constructor(
        string memory name,
        string memory symbol
    )
        ERC20(name, symbol)
        public
    {
        owner = msg.sender;
    }


  /**
   * @dev Function to mint tokens
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function mint(
    address _to,
    uint256 _amount
  )
    public
    onlyOwner
    returns (bool)
  {
    _mint(_to, _amount);
    emit Mint(_to, _amount);
    return true;
  }

  /**
   * @dev Function to mint tokens
   * @param _to The address that will receive the minted tokens.
   * @param _amount The amount of tokens to mint.
   * @return A boolean that indicates if the operation was successful.
   */
  function burn(
    address _to,
    uint256 _amount
  )
    public
    onlyOwner
    returns (bool)
  {
    _burn(_to, _amount);
    emit Burn(_to, _amount);
    return true;
  }

  
}
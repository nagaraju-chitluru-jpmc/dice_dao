// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    /**
     * @dev Multiplies two numbers, throws on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
     * @dev Integer division of two numbers, truncating the quotient.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
     * @dev Adds two numbers, throws on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @title DiceToken (DT)
 * @dev ERC20 Token implementation for the Dice lab
 * Total supply: 10,000 DT
 * Price: 0.01 ETH per DT
 */
contract DiceToken is IERC20 {
    using SafeMath for uint256;
    
    string public constant name = "DiceToken";
    string public constant symbol = "DT";
    uint8 public constant decimals = 18;
    
    // Total supply is 10,000 tokens (with 18 decimals)
    uint256 private _totalSupply = 10000 * 10**uint256(decimals);
    uint256 private _remainingSupply;
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowed;
    
    address public owner;
    
    // Price per token: 0.01 ETH
    uint256 public constant PRICE_PER_TOKEN = 10000000000000000; // 0.01 ETH in wei
    
    constructor() {
        owner = msg.sender;
        _remainingSupply = _totalSupply;
    }
    
    /**
     * @dev Total number of tokens in existence
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    /**
     * @dev Gets the balance of the specified address.
     * @param who The address to query the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address who) public view override returns (uint256) {
        return _balances[who];
    }
    
    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param owner address The address which owns the funds.
     * @param spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowed[owner][spender];
    }
    
    /**
     * @dev Transfer token to a specified address
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
    function transfer(address to, uint256 value) public override returns (bool) {
        require(to != address(0), "Cannot transfer to zero address");
        require(value <= _balances[msg.sender], "Insufficient balance");
        
        _balances[msg.sender] = _balances[msg.sender].sub(value);
        _balances[to] = _balances[to].add(value);
        
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     */
    function approve(address spender, uint256 value) public override returns (bool) {
        require(spender != address(0), "Cannot approve zero address");
        
        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    /**
     * @dev Transfer tokens from one address to another
     * @param from address The address which you want to send tokens from
     * @param to address The address which you want to transfer to
     * @param value uint256 the amount of tokens to be transferred
     */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        require(to != address(0), "Cannot transfer to zero address");
        require(value <= _balances[from], "Insufficient balance");
        require(value <= _allowed[from][msg.sender], "Insufficient allowance");
        
        _balances[from] = _balances[from].sub(value);
        _balances[to] = _balances[to].add(value);
        _allowed[from][msg.sender] = _allowed[from][msg.sender].sub(value);
        
        emit Transfer(from, to, value);
        return true;
    }
    
    /**
     * @dev Function to check the remaining token supply available for purchase
     * @return The amount of tokens available
     */
    function remainingSupply() public view returns (uint256) {
        return _remainingSupply;
    }
    
    /**
     * @dev Function to purchase DT tokens at the rate of 0.01 ETH per DT
     * Allows anyone to top up DT by sending ETH
     */
    function topUp() public payable {
        require(msg.value > 0, "Must send ETH to buy tokens");
        
        // Calculate how many tokens to mint based on ETH sent
        uint256 tokensToMint = msg.value.div(PRICE_PER_TOKEN);
        
        // Check if there are enough tokens in the supply
        require(tokensToMint <= _remainingSupply, "DT supply is not enough");
        
        // Update balances and remaining supply
        _balances[msg.sender] = _balances[msg.sender].add(tokensToMint);
        _remainingSupply = _remainingSupply.sub(tokensToMint);
        
        // If there's any remainder ETH (due to division), send it back
        uint256 remainder = msg.value.mod(PRICE_PER_TOKEN);
        if (remainder > 0) {
            payable(msg.sender).transfer(remainder);
        }
        
        emit Transfer(address(0), msg.sender, tokensToMint);
    }
    
    /**
     * @dev Function to allow the contract owner to withdraw all ETH from the contract
     */
    function withdrawFunds() public {
        require(msg.sender == owner, "Only owner can withdraw funds");
        payable(owner).transfer(address(this).balance);
    }
}

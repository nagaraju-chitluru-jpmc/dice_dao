// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Dice.sol";
import "./DiceToken.sol";

contract DiceMarketWithDT {
    address public owner;
    uint256 public commissionFee;
    Dice public diceContract;
    DiceToken public dtToken;
    
    struct DiceForSale {
        uint256 price;
        address seller;
        bool isListed;
    }
    
    mapping(uint256 => DiceForSale) public diceListings;
    
    event DiceListed(uint256 id, uint256 price, address seller);
    event DiceUnlisted(uint256 id, address seller);
    event DiceSold(uint256 id, address from, address to, uint256 price);
    event Commission(uint256 commission);
    
    constructor(address diceContractAddress, address dtTokenAddress, uint256 _commissionFee) {
        owner = msg.sender;
        commissionFee = _commissionFee;
        diceContract = Dice(diceContractAddress);
        dtToken = DiceToken(dtTokenAddress);
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    // Function to update commission fee
    function setCommissionFee(uint256 _commissionFee) public onlyOwner {
        commissionFee = _commissionFee;
    }
    
    // Seller lists dice for sale after transferring the ownership to dice market
    function list(uint256 id, uint256 price) public {
        // Check price meets minimum requirements (value + commission)
        uint256 diceValue = diceContract.getDiceValue(id) / 0.01 ether; // Convert from wei to DT (1 DT = 0.01 ETH)
        require(price >= diceValue + commissionFee, "Price must be at least value + commission fee");
        
        // Verify the sender is the owner of the dice
        require(diceContract.getOwner(id) == msg.sender, "You are not the owner of this dice");
        
        // Transfer ownership to the DiceMarket contract
        diceContract.transfer(id, address(this));
        
        // Add to listings
        diceListings[id] = DiceForSale({
            price: price,
            seller: msg.sender,
            isListed: true
        });
        
        emit DiceListed(id, price, msg.sender);
    }
    
    // Unlist a dice from market
    function unlist(uint256 id) public {
        DiceForSale storage listing = diceListings[id];
        
        // Check if the dice is listed
        require(listing.isListed, "Dice is not listed");
        
        // Check if caller is the seller
        require(listing.seller == msg.sender, "Only the seller can unlist");
        
        // Unlist the dice but do not transfer ownership back
        listing.isListed = false;
        
        emit DiceUnlisted(id, msg.sender);
    }
    
    // Get the price of a dice
    function checkPrice(uint256 id) public view returns (uint256) {
        require(diceListings[id].isListed, "Dice is not listed for sale");
        return diceListings[id].price;
    }
    
    // Buy a dice at the requested price (dice price + market commission) using DT
    function buy(uint256 id) public {
        DiceForSale storage listing = diceListings[id];
        
        // Check if the dice is listed
        require(listing.isListed, "Dice is not listed for sale");
        
        // Check if buyer has approved this contract to spend DT
        require(dtToken.allowance(msg.sender, address(this)) >= listing.price, 
                "You need to approve DiceMarket to spend your DT");
        
        // Check if buyer has enough DT
        require(dtToken.balanceOf(msg.sender) >= listing.price, 
                "Not enough DT balance");
        
        // Calculate commission and payment to seller
        uint256 commission = commissionFee;
        uint256 payment = listing.price - commission;
        
        // Transfer DT from buyer to seller
        dtToken.transferFrom(msg.sender, listing.seller, payment);
        
        // Transfer DT for commission to owner
        if (commission > 0) {
            dtToken.transferFrom(msg.sender, owner, commission);
        }
        
        // Transfer ownership of the dice to the buyer
        diceContract.transfer(id, msg.sender);
        
        emit Commission(commission);
        
        // Remove the listing
        delete diceListings[id];
        
        emit DiceSold(id, listing.seller, msg.sender, listing.price);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "./DiceExt.sol";

contract DiceMarket {
    address payable public owner;
    uint256 public commissionFee;
    DiceExt public diceContract;
    
    struct DiceForSale {
        uint256 price;
        address payable seller;
        bool isListed;
    }
    
    mapping(uint256 => DiceForSale) public diceListings;
    
    event DiceListed(uint256 id, uint256 price, address seller);
    event DiceUnlisted(uint256 id, address seller);
    event DiceSold(uint256 id, address from, address to, uint256 price);
    
    constructor(address _diceExtAddress, uint256 _commissionFee) public {
        owner = msg.sender;
        commissionFee = _commissionFee;
        diceContract = DiceExt(_diceExtAddress);
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    // Function to update commission fee
    function setCommissionFee(uint256 _commissionFee) public onlyOwner {
        commissionFee = _commissionFee;
    }
    
    // List a dice for sale
    function list(uint256 id, uint256 price) public {
        // Check that caller is the owner of the dice
        require(diceContract.isDiceOwner(id, msg.sender), "Only the owner can list the dice");
        
        // Check price meets minimum requirements (value + commission)
        require(price >= diceContract.getDiceValue(id) + commissionFee, "Price must be at least value + commission fee");
        
        // Transfer dice ownership to this contract
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
    
    // Buy a dice at the requested price
    function buy(uint256 id) public payable {
        DiceForSale storage listing = diceListings[id];
        
        // Check if the dice is listed
        require(listing.isListed, "Dice is not listed for sale");
        
        // Check if enough ether is sent
        require(msg.value >= listing.price, "Sent ether is less than the price");
        
        // Transfer ownership of the dice to the buyer
        diceContract.transfer(id, msg.sender);
        
        // Calculate commission and payment to seller
        uint256 commission = commissionFee;
        uint256 payment = listing.price - commission;
        
        // Transfer payment to seller
        listing.seller.transfer(payment);
        
        // Transfer commission to market owner
        owner.transfer(commission);
        
        // Return excess ether if any
        if (msg.value > listing.price) {
            msg.sender.transfer(msg.value - listing.price);
        }
        
        // Remove the listing
        delete diceListings[id];
        
        emit DiceSold(id, listing.seller, msg.sender, listing.price);
    }
    
    // Withdraw any accumulated ether (only owner)
    function withdrawEther() public onlyOwner {
        owner.transfer(address(this).balance);
    }
}
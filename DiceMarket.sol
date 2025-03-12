// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "./DiceExt.sol";

//Steps:
//1. Deploy DiceExt.sol using account: 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
//2. Add dice with numOfSlides, color by settings value 11000000000000000 wei
//3. Deply DiceMarket.sol using account: 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2 with Dice contrct and commistion 2
//4. Transfer Dice owner ship to DiceMarket contrct address by calling from 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
//5. List Dice calling from 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4 with dice id 0 and value 11000000000000004
//6. Buy dice from 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db with value 11000000000000006
//7. Add another dice, tranfer ownership, list and call unlist

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

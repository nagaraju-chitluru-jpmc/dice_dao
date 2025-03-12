// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Import the updated Dice contract
import "./Dice.sol";

// Extend the Dice contract using inheritance
contract DiceExt is Dice {
    // Map diceId directly to luckyTimes counter
    mapping(uint256 => uint256) public luckyTimes;
    
    // New event for when max number is rolled
    event luckyTimesEvent(uint256 diceId, uint256 luckyTimesCount);
    
    // New event for when dice is destroyed
    event diceDestroyed(uint256 diceId, address owner, uint256 value);
    
    // Override the stopRoll function to track lucky times
    function stopRoll(uint256 diceId) public override ownerOnly(diceId) validDiceId(diceId) {
        // Call the parent contract's stopRoll function
        super.stopRoll(diceId);
        
        // Check if max number was rolled (the number of sides is the max value)
        if (getDiceNumber(diceId) == getDiceSides(diceId)) {
            luckyTimes[diceId]++; // Increment luckyTimes
            emit luckyTimesEvent(diceId, luckyTimes[diceId]); // Emit the lucky times event
        }
    }
    
    // Getter function for luckyTimes
    function getLuckyTimes(uint256 diceId) public view validDiceId(diceId) returns (uint256) {
        return luckyTimes[diceId];
    }
    
    // Function to destroy dice and return ether
    function destroyDice(uint256 diceId) public ownerOnly(diceId) validDiceId(diceId) {
        uint256 valueToReturn = getDiceValue(diceId);
        address payable owner = payable(dices[diceId].owner); // Updated for Solidity 0.8.0
        
        emit diceDestroyed(diceId, owner, valueToReturn);
        
        // If this is the last dice, simply decrement the counter
        if (diceId == numDices - 1) {
            numDices--;
        } else {
            // Otherwise, replace the deleted dice with the last dice and decrement the counter
            dices[diceId] = dices[numDices - 1];
            // Also move the luckyTimes counter
            luckyTimes[diceId] = luckyTimes[numDices - 1];
            numDices--;
        }
        
        // Transfer the creation value back to the owner
        owner.transfer(valueToReturn);
    }
}

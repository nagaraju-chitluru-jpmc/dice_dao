// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Dice.sol";

/**
1. First create dice using the Dice contract
2. Transfer both die to this contract using the contract's address
3. Use setBattlePair from each player's account to decide enemy
4. Use the battle function to roll, stop rolling and then compare the numbers
5. The player with the higher number gets BOTH dice
6. If there is a tie, return the dice to their previous owner
*/
contract DiceBattle {
    Dice public diceContract;
    mapping(address => address) public battle_pair;
    mapping(uint256 => address) public originalOwner;
    
    event BattlePairSet(address indexed player, address indexed enemy);
    event BattleStarted(uint256 myDice, uint256 enemyDice);
    event BattleResult(uint256 myDice, uint256 enemyDice, uint256 myRoll, uint256 enemyRoll, address winner);
    event DiceReturned(uint256 diceId, address returnedTo);
    
    constructor(address diceAddress) {
        diceContract = Dice(diceAddress);
    }
    
    // Set an enemy to battle with
    function setBattlePair(address enemy) public {
        // Require that enemy is not the same as the sender
        require(enemy != msg.sender, "Cannot battle yourself");
        
        // Each player can only select one enemy at a time
        battle_pair[msg.sender] = enemy;
        
        emit BattlePairSet(msg.sender, enemy);
    }
    
    // Function to record original owner when dice is transferred to this contract
    function recordOriginalOwner(uint256 diceId, address owner) public {
        // Only the dice contract should be able to call this
        require(msg.sender == address(diceContract), "Only dice contract can record ownership");
        originalOwner[diceId] = owner;
    }
    
    // Battle function to compare dice rolls and determine winner
    function battle(uint256 myDice, uint256 enemyDice) public {
        address enemy = battle_pair[msg.sender];
        
        // Require that battle pairs align (both players have accepted the battle)
        require(enemy != address(0), "You have not set a battle pair");
        require(battle_pair[enemy] == msg.sender, "Enemy has not accepted battle with you");
        
        // Verify that the dice are owned by this contract
        require(diceContract.getOwner(myDice) == address(this), "My dice is not owned by battle contract");
        require(diceContract.getOwner(enemyDice) == address(this), "Enemy dice is not owned by battle contract");
        
        // Verify that the dice belonged to the correct owners before transfer
        require(originalOwner[myDice] == msg.sender, "Not the original owner of myDice");
        require(originalOwner[enemyDice] == enemy, "Not the original owner of enemyDice");
        
        emit BattleStarted(myDice, enemyDice);
        
        // Roll both dice
        uint256 myRoll = diceContract.roll(myDice);
        uint256 enemyRoll = diceContract.roll(enemyDice);
        
        // Determine winner
        address winner;
        
        if (myRoll > enemyRoll) {
            // Sender wins
            winner = msg.sender;
            
            // Transfer both dice to sender
            diceContract.transfer(myDice, msg.sender);
            diceContract.transfer(enemyDice, msg.sender);
            
        } else if (enemyRoll > myRoll) {
            // Enemy wins
            winner = enemy;
            
            // Transfer both dice to enemy
            diceContract.transfer(myDice, enemy);
            diceContract.transfer(enemyDice, enemy);
            
        } else {
            // It's a tie, return dice to their original owners
            diceContract.transfer(myDice, msg.sender);
            diceContract.transfer(enemyDice, enemy);
            
            emit DiceReturned(myDice, msg.sender);
            emit DiceReturned(enemyDice, enemy);
        }
        
        emit BattleResult(myDice, enemyDice, myRoll, enemyRoll, winner);
        
        // Reset battle pairs
        delete battle_pair[msg.sender];
        delete battle_pair[enemy];
    }
    
    // Get the current battle pair for an address
    function getBattlePair(address player) public view returns (address) {
        return battle_pair[player];
    }
    
    // Get the original owner of a dice
    function getOriginalOwner(uint256 diceId) public view returns (address) {
        return originalOwner[diceId];
    }
}

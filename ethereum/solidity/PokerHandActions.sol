pragma solidity ^0.4.5;
/**
* 
* Processes full-cost ("full contract"), unsigned actions and transactions for an authorizing PokerHandData contract.
* 
* (C)opyright 2016 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
contract PokerHandActions { 
    
    address public owner; //the contract's owner / publisher
   
  	function PokerHandActions() {
		owner = msg.sender;
    }
	
	/**
	* Anonymous fallback function.
	*/
	function () {
          throw;
    }

	/**
     * Records a bet for the sending player in "playerBets", updates the "pot", subtracts the value from their "playerChips" total.
     * The sending player must have agreed, it must be their turn to bet according to the "betPosition" index, the bet value must
     * be less than or equal to the player's available "playerChips" value, and all players must be at a valid betting phase (4, 7, 10, or 13).
     * 
     * Player bets are automatically added to the "pot" and when all players' bets are equal they (bets) are reset to 0 and 
     * their phases are automatically incremented.
     * 
     * @param betValue The bet, in wei, being placed by the player.
     */
	function storeBet (address dataAddr, uint256 betValue) public  {	
		PokerHandData dataStorage = PokerHandData(dataAddr);	
		if (dataStorage.agreed(msg.sender) == false) {
		    throw;
		}
	    if ((dataStorage.allPlayersAtPhase(4) == false) && (dataStorage.allPlayersAtPhase(7) == false) && 
			(dataStorage.allPlayersAtPhase(10) == false) && (dataStorage.allPlayersAtPhase(13) == false)) {			
            throw;
        }
        if (dataStorage.playerChips(msg.sender) < betValue) {			
            throw;
        }
        if (dataStorage.players(dataStorage.betPosition()) != msg.sender) {			
            throw;
        }
        if (dataStorage.players(1) == msg.sender) {
            if (dataStorage.bigBlindHasBet() == false) {
                dataStorage.set_bigBlindHasBet(true);
            } else {
                dataStorage.set_playerHasBet(msg.sender, true);
            }
        } else {
			dataStorage.set_playerHasBet(msg.sender, true);  
        }
        dataStorage.set_playerBets(msg.sender, dataStorage.playerBets(msg.sender) + betValue);
        dataStorage.set_playerChips(msg.sender, dataStorage.playerChips(msg.sender) - betValue);
		dataStorage.set_pot (dataStorage.pot() + betValue);
		dataStorage.set_betPosition((dataStorage.betPosition() + 1) % dataStorage.num_Players());
		uint256 currentBet = dataStorage.playerBets(dataStorage.players(0));
		dataStorage.set_lastActionBlock (block.number);
		for (uint count=1; count<dataStorage.num_Players(); count++) {
		    if (dataStorage.playerBets(dataStorage.players(count)) != currentBet) {
		        //all player bets should match in order to end betting round
		        return;
		    }
		}
		if (allPlayersHaveBet(dataAddr, true) == false) {
		    return;
		}
		//all players have placed at least one bet and bets are equal: reset bets, increment phases, reset bet position and "playerHasBet" flags
		for (count=0; count<dataStorage.num_Players(); count++) {
		    dataStorage.set_playerBets(dataStorage.players(count), 0);
		    dataStorage.set_phase(dataStorage.players(count), dataStorage.phases(dataStorage.players(count))+1);
			dataStorage.set_playerHasBet(dataStorage.players(count), false);
		    dataStorage.set_betPosition(0);
		}
    }
	
	 /**
     * Checks if all players have bet during this round of betting by analyzing the playerHasBet mapping.
     * 
     * @param reset If all players have bet, all playerHasBet entries are set to false if this parameter is true. If false
     * then the values of playerHasBet are not affected.
     * 
     * @return True if all players have bet during this round of betting.
     */
    function allPlayersHaveBet(address dataAddr, bool reset) public constant returns (bool) {
		PokerHandData dataStorage = PokerHandData(dataAddr);
        for (uint count = 0; count < dataStorage.num_Players(); count++) {
            if (dataStorage.playerHasBet(dataStorage.players(count)) == false) {
                return (false);
            }
        }
        if (reset) {
            for (count = 0; count < dataStorage.num_Players(); count++) {
                dataStorage.set_playerHasBet(dataStorage.players(count), false);
            }
        }
        return (true);
    }	 
	 
    /**
     * Records a "fold" action for a player. The player must exist in the "players" array, must have agreed, and must be at a valid
     * betting phase (4,7,10), and it must be their turn to bet according to the "betPosition" index. When fold is correctly invoked
     * any unspent wei in the player's chips are refunded, as opposed to simply abandoning the contract in which case those chips 
     * are not refunded.
     * 
     * Once a player folds correctly they are removed from the "players" array and the betting position is adjusted if necessary. If
     * only one other player remains active in the contract they receive the pot plus their remaining chips while other (folded) players 
     * receive their remaining chips.
     */
    function fold(address dataAddr) public  {	
		PokerHandData dataStorage = PokerHandData(dataAddr);
        if (dataStorage.agreed(msg.sender) == false) {			
		    throw;
		}
		if (dataStorage.lastActionBlock() > 0) {
			if ((dataStorage.allPlayersAtPhase(4) == false) && (dataStorage.allPlayersAtPhase(7) == false) && 
				(dataStorage.allPlayersAtPhase(10) == false) && (dataStorage.allPlayersAtPhase(13) == false)) {            
				throw;
			}
			if (dataStorage.players(dataStorage.betPosition()) != msg.sender) {            
				throw;
			}
		}
        address[] memory newPlayersArray = new address[](dataStorage.num_Players()-1);
        uint pushIndex=0;
        for (uint count=0; count < dataStorage.num_Players(); count++) {
            if (dataStorage.players(count) != msg.sender) {
                newPlayersArray[pushIndex]=dataStorage.players(count);
                pushIndex++;
            }
        }
        if (newPlayersArray.length == 1) {
            //game has ended since only one player's left
            dataStorage.add_winner(newPlayersArray[0]);
            payout(dataAddr);
        } else {
            //game may continue
            dataStorage.new_players(newPlayersArray);
			if (dataStorage.lastActionBlock() > 0) {
				dataStorage.set_betPosition (dataStorage.betPosition() % dataStorage.num_Players()); 
			}
        }
		if (dataStorage.lastActionBlock() > 0) {
			dataStorage.set_lastActionBlock (block.number);
		}
    }
    
    /**
     * Declares the sending player as a winner. Sending player must have agreed to contract and all players must be at be 
     * at phase 14. A winning player may only be declared once at which point all players' phases are updated to 15.
     * 
     * A declared winner may be challenged before timeoutBlocks have elapsed, or later if resolveWinner hasn't yet
     * been called.
     * 
     */
    function declareWinner(address dataAddr, address winnerAddr) public {
		PokerHandData dataStorage = PokerHandData(dataAddr);
        if (dataStorage.agreed(msg.sender) == false) {
		    throw;
		}
	    if (dataStorage.allPlayersAtPhase(14) == false) {
            throw;
        }
		dataStorage.add_declaredWinner(msg.sender, winnerAddr);
        for (uint count=0; count<dataStorage.num_Players(); count++) {
            dataStorage.set_phase(dataStorage.players(count), 15);
        }
		dataStorage.set_lastActionBlock(block.number);
    }
	
	/**
     * Pays out the contract's value by sending the pot + winner's remaining chips to the winner and sending the othe player's remaining chips
     * to them. When all amounts have been paid out, "pot" and all "playerChips" are set to 0 as is the "winner" address. All players'
     * phases are set to 18 and the reset function is invoked.
     * 
     * The "winner" address must be set prior to invoking this call.
     */
    function payout(address dataAddr) private {		
		PokerHandData dataStorage = PokerHandData(dataAddr);
        if (dataStorage.num_winner() == 0) {
            throw;
        }
        for (uint count=0; count<dataStorage.num_winner(); count++) {
            if ((dataStorage.pot() / dataStorage.num_winner()) + dataStorage.playerChips(dataStorage.winner(count)) > 0) {
				if (dataStorage.pay(dataStorage.winner(count), 
					(dataStorage.pot() / dataStorage.num_winner()) 
						+ dataStorage.playerChips(dataStorage.winner(count)))) {                
                    dataStorage.set_pot(0);
					dataStorage.set_playerChips(dataStorage.winner(count), 0);                    
                }
            }
        }
         for (count=0; count < dataStorage.num_Players(); count++) {
            dataStorage.set_phase(dataStorage.players(count), 18);
            if (dataStorage.playerChips(dataStorage.players(count)) > 0) {
				if (dataStorage.pay (dataStorage.players(count), dataStorage.playerChips(dataStorage.players(count)))) {                
                    dataStorage.set_playerChips(dataStorage.players(count), 0);
                }
            }
        }
		dataStorage.set_complete (true);
    }	
}

contract PokerHandData {    
	struct Card {
        uint index;
        uint suit; 
        uint value;
    }
	struct CardGroup {
       Card[] cards;
    }
	struct Key {
        uint256 encKey;
        uint256 decKey;
        uint256 prime;
    }
    address public owner;
    address[] public authorizedGameContracts;
	uint public numAuthorizedContracts;
    address[] public players;
    uint256 public buyIn;
    mapping (address => bool) public agreed;
	uint256 public prime;
    uint256 public baseCard;
    mapping (address => uint256) public playerBets;
	mapping (address => uint256) public playerChips;
	mapping (address => bool) public playerHasBet;
	bool public bigBlindHasBet;
    uint256 public pot;
    uint public betPosition;
    mapping (address => uint256[52]) public encryptedDeck;
    mapping (address => uint256[2]) public privateCards;
    struct DecryptPrivateCardsStruct {
        address sourceAddr;
        address targetAddr;
        uint256[2] cards;
    }
    DecryptPrivateCardsStruct[] public privateDecryptCards;
    uint256[5] public publicCards;
	mapping (address => uint256[5]) public publicDecryptCards;
    mapping (address => Key[]) public playerKeys;    
    mapping (address => uint[5]) public playerBestHands; 
    mapping (address => Card[]) public playerCards;
    mapping (address => uint256) public results;
    mapping (address => address) public declaredWinner;
    address[] public winner;
    uint public lastActionBlock;
    uint public timeoutBlocks;
	uint public initBlock;
	mapping (address => uint) public nonces;
    mapping (address => uint) public validationIndex;
    address public challenger;
	bool public complete;
	bool public initReady;
    mapping (address => uint8) public phases;

  	function PokerHandData() {}
	function () {}
	modifier onlyAuthorized {
		uint allowedContractsFound = 0;
        for (uint count=0; count<authorizedGameContracts.length; count++) {
            if (msg.sender == authorizedGameContracts[count]) {
                allowedContractsFound++;
            }
        }
        if (allowedContractsFound == 0) {
             throw;
        }
        _;
	}
	function agreeToContract(uint256 nonce) payable public {}
	function initialize(uint256 primeVal, uint256 baseCardVal, uint256 buyInVal, uint timeoutBlocksVal) public onlyAuthorized {}
    function getPrivateDecryptCard(address sourceAddr, address targetAddr, uint cardIndex) constant public returns (uint256) {}
    function allPlayersAtPhase(uint phaseNum) public constant returns (bool) {}
    function num_Players() public constant returns (uint) {}
	function num_Keys(address target) public constant returns (uint) {}
	function num_PlayerCards(address target) public constant returns (uint) {}
	function num_PrivateCards(address targetAddr) public constant returns (uint) {}
	function num_PublicCards() public constant returns (uint) {}
	function num_PrivateDecryptCards(address sourceAddr, address targetAddr) public constant returns (uint) {}
	function num_winner() public constant returns (uint) {}
	function setAuthorizedGameContracts (address[] contractAddresses) public {}
	function add_playerCard(address playerAddress, uint index, uint suit, uint value) public onlyAuthorized {}
    function update_playerCard(address playerAddress, uint cardIndex, uint index, uint suit, uint value) public onlyAuthorized {}
    function set_validationIndex(address playerAddress, uint index) public onlyAuthorized {}
	function set_result(address playerAddress, uint256 result) public onlyAuthorized {}
	function set_complete (bool completeSet) public onlyAuthorized {}
	function set_publicCard (uint256 card, uint index) public onlyAuthorized {}
	function set_encryptedDeck (address fromAddr, uint256[] cards) public onlyAuthorized {}
	function set_privateCards (address fromAddr, uint256[] cards) public onlyAuthorized {}
	function set_betPosition (uint betPositionVal) public onlyAuthorized {}
	function set_bigBlindHasBet (bool bigBlindHasBetVal) public onlyAuthorized {}
	function set_playerHasBet (address fromAddr, bool hasBet) public onlyAuthorized {}
	function set_playerBets (address fromAddr, uint betVal) public onlyAuthorized {}
	function set_playerChips (address forAddr, uint numChips) public onlyAuthorized {}
	function set_pot (uint potVal) public onlyAuthorized {}
	function set_agreed (address fromAddr, bool agreedVal) public onlyAuthorized {}
	function add_winner (address winnerAddress) public onlyAuthorized {}
	function clear_winner () public onlyAuthorized {}
	function new_players (address[] newPlayers) public onlyAuthorized {}
	function set_phase (address fromAddr, uint8 phaseNum) public onlyAuthorized {}
	function set_lastActionBlock(uint blockNum) public onlyAuthorized {}
	function set_privateDecryptCards (address fromAddr, uint256[] cards, address targetAddr) public onlyAuthorized {}
	function set_publicCards (address fromAddr, uint256[] cards) public onlyAuthorized {}
	function set_publicDecryptCards (address fromAddr, uint256[] cards) public onlyAuthorized {}
	function add_declaredWinner(address fromAddr, address winnerAddr) public onlyAuthorized {}
    function privateDecryptCardsIndex (address sourceAddr, address targetAddr) public onlyAuthorized returns (uint) {}
	function set_playerBestHands(address fromAddr, uint cardIndex, uint256 card) public onlyAuthorized {}
	function add_playerKeys(address fromAddr, uint256[] encKeys, uint256[] decKeys) public onlyAuthorized {}
	function remove_playerKeys(address fromAddr) public onlyAuthorized {}
	function set_challenger(address challengerAddr) public onlyAuthorized {}
	function pay (address toAddr, uint amount) public onlyAuthorized returns (bool) {}
	function publicDecryptCardsInfo() public constant returns (uint maxLength, uint playersAtMaxLength) {}
    function length_encryptedDeck(address fromAddr) public constant returns (uint) {}
}
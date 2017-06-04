pragma solidity ^0.4.5;
/**
* 
* Manages game startup routines such as initialization and card dtorage for a single CypherPoker hand (round). 
* Most data operations are done on an external PokerHandData contract.
* 
* (C)opyright 2016 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
contract PokerHandStartup { 
    
    address public owner; //the contract's owner / publisher
   
  	/**
	* Contract constructor.
	*/
	function PokerHandStartup() {
		owner = msg.sender;
    }
	
	/**
	* Anonymous fallback function.
	*/
	function () {
          throw;
    }
	
	/**
	 * Attempts to initialize a PokerHandData contract.
	 * 
	 * @param requiredPlayers The players required to agree to the contract before further interaction is allowed. The first player is considered the 
	 * dealer.
	 * @param primeVal The shared prime modulus on which plaintext card values are based and from which encryption/decryption keys are derived.
	 * @param baseCardVal The value of the base or first card of the plaintext deck. The next 51 ascending quadratic residues modulo primeVal are assumed to
	 * comprise the remainder of the deck (see "getCardIndex" for calculations).
	 * @param buyInVal The exact per-player buy-in value, in wei, that must be sent when agreeing to the contract. Must be greater than 0.
	 * @param timeoutBlocksVal The number of blocks that elapse between the current block and lastActionBlock before the current valid player is
	 * considered to have timed / dropped out if they haven't committed a valid action. A minimum of 2 blocks (roughly 24 seconds), is imposed but
	 * a slightly higher value is highly recommended.	 
	 * @param dataAddr The address of PokerHandData contract to initialize.
	 *
	 */
	function initialize(address[] requiredPlayers, uint256 primeVal, uint256 baseCardVal, uint256 buyInVal, uint timeoutBlocksVal, address dataAddr) public {
		PokerHandData handData = PokerHandData (dataAddr);		
		if (handData.initReady() == false) {
			throw;
		}
		if (requiredPlayers.length < 2) {
	        throw;
	    }
	    if (primeVal < 2) {
	        throw;
	    }
	    if (buyInVal == 0) {
	        throw;
	    }
	    if (timeoutBlocksVal < 12) {
	        timeoutBlocksVal = 12;
	    }		
		handData.set_pot(0);
        handData.set_betPosition(0);		
        handData.set_complete (false);
		handData.new_players(requiredPlayers);
		handData.set_lastActionBlock(0);
		handData.initialize(primeVal, baseCardVal, buyInVal, timeoutBlocksVal);
	}	
	
	/**
	 * Resets the poker hand data contract so that it becomes available for re-use. Typically this function only needs to be used
	 * when the data contract has been used in "full" mode (i.e. the game writes most of its data to the contract).
	 *
	 * The contract's 'complete' flag must be set to true prior to calling this function otherwise an exception is throw.
	 *
	 * @param dataAddr The address of the PokerHandData contract to reset.
	 */
	function reset(address dataAddr) public {
		PokerHandData dataContract = PokerHandData(dataAddr);	  
	    if (dataContract.complete() == false) {
	        throw;
	    }	    
	    for (uint count=0; count<dataContract.num_Players(); count++) {
			dataContract.set_agreed(dataContract.players(count), false);	        
			dataContract.set_playerBets(dataContract.players(count), 0);
	        dataContract.set_playerChips(dataContract.players(count), 0);
			dataContract.set_playerHasBet(dataContract.players(count), false);	        
	        dataContract.remove_playerKeys(dataContract.players(count));
			uint256[] memory emptySet;
			dataContract.set_encryptedDeck(dataContract.players(count), emptySet);
			dataContract.set_privateCards(dataContract.players(count), emptySet);	        
	        dataContract.set_publicDecryptCards(dataContract.players(count), emptySet);
	        dataContract.set_result(dataContract.players(count), 0);
			dataContract.set_validationIndex(dataContract.players(count), 0);
			dataContract.add_declaredWinner(dataContract.players(count), 0);	
	    }			    
		dataContract.set_bigBlindHasBet(false);
		dataContract.set_pot(0);
		dataContract.set_betPosition(0);        
		dataContract.clear_winner();
	    dataContract.set_lastActionBlock(0);	    
		dataContract.set_privateDecryptCards(msg.sender, emptySet, 0x0);
		dataContract.set_publicCards(msg.sender, emptySet);	
		dataContract.set_complete(false);
		address[] memory emptyAddrSet;
		dataContract.new_players(emptyAddrSet);	//clears players list and sets initReady to true (so call last)
	}
        
    
  	/**
	* Stores up to 52 encrypted cards of a full deck for a player. The player must have been specified during initialization, must have agreed,
	* and must be at phase 1. This function may be invoked multiple times by the same player during the encryption phase if transactions need 
	* to be broken up into smaler units.
	*
	* @param dataAddr The address of a data contract that has authorized this contract to communicate.
	* @param cards The encrypted card values to store. Once 52 cards (and only 52 cards) have been stored the player's phase is updated. 
	*/
	function storeEncryptedDeck(address dataAddr, uint256[] cards) {
		PokerHandData dataStorage = PokerHandData(dataAddr);
		if (dataStorage.agreed(msg.sender) != true) {
           throw;
        } 
        if (dataStorage.phases(msg.sender) > 1) {
           throw;
        } 
		dataStorage.set_encryptedDeck(msg.sender, cards);		
		if (dataStorage.length_encryptedDeck(msg.sender) == 52) {
            dataStorage.set_phase(msg.sender, 2);
        }
		dataStorage.set_lastActionBlock(block.number);
	}
    
	/**
	 * Stores up to 2 encrypted private or hole card selections for a player. The player must have been specified during initialization, must have agreed,
 	 * and must be at phase 2. This function may be invoked multiple times by the same player during the encryption phase if transactions need 
	 * to be broken up into smaler units.
	 *
	 * @param cards The encrypted card values to store. Once 2 cards (and only 2 cards) have been stored the player's phase is updated. 	 
	 */
    function storePrivateCards(address dataAddr, uint256[] cards) public {
		PokerHandData dataStorage = PokerHandData(dataAddr);
		if (dataStorage.agreed(msg.sender) != true) {
           throw;
        } 
        if (dataStorage.phases(msg.sender) != 2) {
           throw;
        } 
		dataStorage.set_privateCards(msg.sender, cards);
		if (dataStorage.num_PrivateCards(msg.sender) == 2) {
            dataStorage.set_phase(msg.sender, 3);
        }
		dataStorage.set_lastActionBlock(block.number);
    }
    
    /**
	 * Stores up to 2 partially decrypted private or hole cards for a target player. Both sending and target players must have been specified during initialization, 
	 * must have agreed, and target must be at phase 3. This function may be invoked multiple times by the same player during the private/hold card decryption phase if transactions need 
	 * to be broken up into smaler units.
	 *
	 * @param cards The partially decrypted card values to store for the target player. Once 2 cards (and only 2 cards) have been stored by all other players for the target, the target's phase is
	 * updated to 4.
	 * @param targetAddr The address of the target player for whom the cards are being decrypted (the two cards are their private/hold cards).
	 */
    function storePrivateDecryptCards(address dataAddr, uint256[] cards, address targetAddr) public {
		PokerHandData dataStorage = PokerHandData(dataAddr);
		if (dataStorage.agreed(msg.sender) != true) {
           throw;
        } 
        if (dataStorage.agreed(targetAddr) != true) {
           throw;
        } 
		if (dataStorage.phases(targetAddr) != 3) {
           throw;
        }		
		dataStorage.set_privateDecryptCards(msg.sender, cards, targetAddr);
		//Checks whether all partially decrypted cards for a specific target player have been stored
        //by all other players.
		uint cardGroupsStored = 0;
		for (uint count=0; count < dataStorage.num_Players(); count++) {
			if (dataStorage.num_PrivateDecryptCards(dataStorage.players(count), targetAddr) == 2) {
				 cardGroupsStored++;
			}
		}
		//partially decrypted cards should be stored by all players except the target
        if (cardGroupsStored == (dataStorage.num_Players() - 1)) {
            dataStorage.set_phase(targetAddr, 4);
        }
		dataStorage.set_lastActionBlock(block.number);
    }    
    
    /**
	* Stores the encrypted public or community card(s) for the hand. Currently only the dealer may store public/community card
	* selections to the contract.
	*
	* @param cards The encrypted public/community cards to store. The number of cards that may be stored depends on the
	* current player phases (all players). Three cards are stored at phase 5 (in multiple invocations if desired), and one card is stored at 
	* phases 8 and 11.
	*/
    function storePublicCards(address dataAddr, uint256[] cards) public {
		PokerHandData dataStorage = PokerHandData(dataAddr);		
		if (msg.sender != dataStorage.players(dataStorage.num_Players()-1)) {
	        //not the dealer
	        throw;
	    }
	    if (dataStorage.agreed(msg.sender) != true) {
           throw;
        }
        if ((dataStorage.allPlayersAtPhase(5) == false) && (dataStorage.allPlayersAtPhase(8) == false) && (dataStorage.allPlayersAtPhase(11) == false)) {
            throw;
        }
        if ((dataStorage.allPlayersAtPhase(5)) && ((cards.length + dataStorage.num_PublicCards()) > 3)) {
            //at phase 5 we can store a maximum of 3 cards
            throw;
        }
        if ((dataStorage.allPlayersAtPhase(5) == false) && (cards.length > 1)) {
            //at valid phases above 5 we can store a maximum of 1 card
            throw;
        }
        dataStorage.set_publicCards(msg.sender, cards);
        if (dataStorage.num_PublicCards() > 2) {
            //phases are incremented at 3, 4, and 5 cards
            for (uint count=0; count < dataStorage.num_Players(); count++) {
                dataStorage.set_phase(dataStorage.players(count), dataStorage.phases(dataStorage.players(count)) + 1);
            }
        }
		dataStorage.set_lastActionBlock(block.number);
	}
	
	 /**
	 * Stores up to 5 partially decrypted public or community cards from a target player. The player must must have agreed to the 
	 * contract, and must be at phase 6, 9, or 12. Multiple invocations may be used to store cards during the multi-card 
	 * phase (6) if desired.
	 * 
	 * In order to correlate decryptions during subsequent rounds cards are stored at matching indexes for players involved.
	 * To illustrate this, in the following example players 1 and 2 decrypted the first three cards and players 2 and 3 decrypted the following
	 * two cards:
	 * 
	 * publicDecryptCards(player 1) = [0x32] [0x22] [0x5A] [ 0x0] [ 0x0] <- partially decrypted only the first three cards
	 * publicDecryptCards(player 2) = [0x75] [0xF5] [0x9B] [0x67] [0xF1] <- partially decrypted all five cards
	 * publicDecryptCards(player 3) = [ 0x0] [ 0x0] [ 0x0] [0x1C] [0x22] <- partially decrypted only the last two cards
	 * 
	 * The number of players involved in the partial decryption of any card at a specific index should be the total number of players minus one
	 * (players.length - 1), since the final decryption results in the fully decrypted card and therefore doesn't need to be stored.
	 *
	 * @param cards The partially decrypted card values to store. Three cards must be stored at phase 6, one card at phase 9, and one card
	 * at phase 12.
	 */
    function storePublicDecryptCards(address dataAddr, uint256[] cards) public {
		PokerHandData dataStorage = PokerHandData(dataAddr);
		if (dataStorage.agreed(msg.sender) != true) {
           throw;
        }
        if ((dataStorage.phases(msg.sender) != 6) && (dataStorage.phases(msg.sender) != 9) && (dataStorage.phases(msg.sender) != 12)){
           throw;
        }
        if ((dataStorage.phases(msg.sender) == 6) && (cards.length != 3)) {
            throw;
        }
        if ((dataStorage.phases(msg.sender) != 6) && (cards.length != 1)) {
            throw;
        }
		dataStorage.set_publicDecryptCards(msg.sender, cards);		
        var (maxLength, playersAtMaxLength) = dataStorage.publicDecryptCardsInfo();
        if (playersAtMaxLength == (dataStorage.num_Players()-1)) {
            for (uint count=0; count < dataStorage.num_Players(); count++) {
                dataStorage.set_phase(dataStorage.players(count), dataStorage.phases(dataStorage.players(count)) + 1);
            }
        }
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
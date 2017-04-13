pragma solidity ^0.4.5;
/**
* 
* Manages data storage for a single CypherPoker hand (round), and provides some publicly-available utility functions.
* 
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
contract PokerHandData { 
    
	//Single card definition including card's sorting index within the entire deck (1-52), suit value (0 to 3), and value (1 to 13 or 14 if aces are high)
	struct Card {
        uint index;
        uint suit; 
        uint value;
    }
	
	//A group of Card structs.
	struct CardGroup {
       Card[] cards;
    }
	
	//Encryption / decryption key definition including the encryption key, decryption key, and prime modulus.
	struct Key {
        uint256 encKey;
        uint256 decKey;
        uint256 prime;
    }
	
    address public owner; //the contract's owner / publisher
    address[] public authorizedGameContracts; //the "PokerHand*" contracts exclusively authorized to make changes in this contract's data. This value may only be changed when initReady is ready.
	uint public numAuthorizedContracts; //set when authorizedGameContracts is set
    address[] public players; //players, in order of play, who must agree to contract before game play may begin; the last player is the dealer, player 1 (index 0) is small blind, player 2 (index 2) is the big blind
    uint256 public buyIn; //buy-in value, in wei, required in order to agree to the contract    
    mapping (address => bool) public agreed; //true for all players who agreed to this contract; only players in "players" struct may agree
	uint256 public prime; //shared prime modulus
    uint256 public baseCard; //base or first plaintext card in the deck (all subsequent cards are quadratic residues modulo prime)
    mapping (address => uint256) public playerBets; //stores cumulative bets per betting round (reset before next)    
	mapping (address => uint256) public playerChips; //the players' chips, wallets, or purses on which players draw on to make bets, currently equivalent to the wei value sent to the contract.	
	mapping (address => bool) public playerHasBet; //true if the player has placed a bet during the current active betting round (since bets of 0 are valid)
	bool public bigBlindHasBet; //set to true after initial big blind commitment in order to allow big blind to raise during first round
    uint256 public pot; //total cumulative pot for hand
    uint public betPosition; //current betting player index (in players array)    
    mapping (address => uint256[52]) public encryptedDeck; //incrementally encrypted decks; deck of players[players.length-1] is the final encrypted deck
    mapping (address => uint256[2]) public privateCards; //selected encrypted private/hole cards per player
    struct DecryptPrivateCardsStruct {
        address sourceAddr; //the source player providing the partially decrypted cards
        address targetAddr; //the target player for whom the partially decrypted cards are intended
        uint256[2] cards; //the two partially decrypted private/hole cards
    }
    DecryptPrivateCardsStruct[] public privateDecryptCards; //stores partially decrypted private/hole cards for players
    uint256[5] public publicCards; //selected encrypted public cards
	mapping (address => uint256[5]) public publicDecryptCards; //stores partially decrypted public/community cards
    mapping (address => Key[]) public playerKeys; //players' crypto keypairs 
    //Indexes to the cards comprising the players' best hands. Indexes 0 and 1 are the players' private cards and 2 to 6 are indexes
    //of public cards. All five values are supplied during teh final L1Validate call and must be unique and be in the range 0 to 6 in order to be valid.
    mapping (address => uint[5]) public playerBestHands; 
    mapping (address => Card[]) public playerCards; //final decrypted cards for players (as generated from playerBestHands)
    mapping (address => uint256) public results; //hand ranks per player or numeric score representing actions (1=fold lost, 2=fold win, 3=concede loss, 4=concede win, otherwise hand score)    
    mapping (address => address) public declaredWinner; //address of the self-declared winner of the contract (may be challenged)
    address[] public winner; //address of the hand's/contract's resolved or actual winner(s)
    uint public lastActionBlock; //block number of the last valid player action that was committed. This value is set to the current block on every new valid action.
    uint public timeoutBlocks; //the number of blocks that may elapse before the next valid player's (lack of) action is considered to have timed out 
	uint public initBlock; //the block number on which the "initialize" function was called; used to validate signed transactions
	mapping (address => uint) public nonces; //unique nonces used per contract to ensure that signed transactions aren't re-used
    mapping (address => uint) public validationIndex; //highest successfully completed validation index for each player
    address public challenger; //the address of the current contract challenger / validation initiator    
	bool public complete; //contract is completed.
	bool public initReady; //contract is ready for initialization call (all data reset)
    
    /**
     * Phase values:
     * 0 - Agreement (not all players have agreed to contract yet)contract
     * 1 - Encrypted deck storage (all players have agreed to contract)
     * 2 - Private/hole cards selection
	 * 3 - Interim private cards decryption
     * 4 - Betting
     * 5 - Flop cards selection
     * 6 - Interim flop cards decryption
     * 7 - Betting
     * 8 - Turn card selection
     * 9 - Interim turn card decryption
     * 10 - Betting
     * 11 - River card selection
     * 12 - Interim river card decryption
     * 13 - Betting
     * 14 - Declare winner
     * 15 - Resolution
     * 16 - Level 1 challenge - submit crypto keys
	 * 17 - Level 2 challenge - full contract verification
     * 18 - Payout / hand complete
     * 19 - Mid-game challenge
	 * 20 - Hand complete (unchallenged / signed contract game)
	 * 21 - Contract complete (unchallenged / signed contract game)
     */
    mapping (address => uint8) public phases;

  	/**
	* Contract constructor.
	*/
	function PokerHandData() {  	    
		owner = msg.sender;
		complete = true;
		initReady = true; //ready for initialize
    }
	
	/**
	* Modifier for functions to allow access only by addresses contained in the "authorizedGameContracts" array.
	*/
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
	
	/**
	* Anonymous fallback function.
	*/
	function () {
        throw;		
    }
	
	/*
	* Sets the "agreed" flag to true for the transaction sender. Only accounts registered during the "initialize"
	* call are allowed to agree. Once all valid players have agreed the block timeout is started and the next
	* player must commit the next valid action before the timeout has elapsed.
	*
	* The value sent with this function invocation must equal the "buyIn" value (wei) exactly, otherwise
	* an exception is thrown and any included value is refunded. Only when the buy-in value is matched exactly
	* will the "agreed" flag for the player be set and the phase updated to 1.
	*
	* @param nonce A unique nonce to store for the player for this contract. This value must not be re-used until the contract is closed
	* and paid-out in order to prevent re-use of signed transactions.
	*/
	function agreeToContract(uint256 nonce) payable public {
		bool found = false;
        for (uint count=0; count<players.length; count++) {
            if (msg.sender == players[count]) {
                found = true;
            }
        }
        if (found == false) {
			throw;
		}
		if (playerChips[msg.sender] == 0) {
			if (msg.value != buyIn) {
				throw;
			}
			//include additional validation deposit calculations here if desired
			playerChips[msg.sender] = msg.value;
		}
		agreed[msg.sender]=true;
        phases[msg.sender]=1;
		playerBets[msg.sender] = 0;
		playerHasBet[msg.sender] = false;
		validationIndex[msg.sender] = 0;
		nonces[msg.sender] = nonce;
    }	
	
	/**
	 * Initializes the data contract.
	 * 
	 * @param primeVal The shared prime modulus on which plaintext card values are based and from which encryption/decryption keys are derived.
	 * @param baseCardVal The value of the base or first card of the plaintext deck. The next 51 ascending quadratic residues modulo primeVal are assumed to
	 * comprise the remainder of the deck (see "getCardIndex" for calculations).
	 * @param buyInVal The exact per-player buy-in value, in wei, that must be sent when agreeing to the contract. Must be greater than 0.
	 * @param timeoutBlocksVal The number of blocks that elapse between the current block and lastActionBlock before the current valid player is
	 * considered to have timed / dropped out if they haven't committed a valid action. A minimum of 2 blocks (roughly 24 seconds), is imposed but
	 * a slightly higher value is highly recommended.	 
	 *
	 */
	function initialize(uint256 primeVal, uint256 baseCardVal, uint256 buyInVal, uint timeoutBlocksVal) public onlyAuthorized {	   	
	    prime = primeVal;
	    baseCard = baseCardVal;
	    buyIn = buyInVal;
	    timeoutBlocks = timeoutBlocksVal;
		initBlock = block.number;
		initReady = false;        
	}	
    
    /**
     * Accesses partially decrypted private/hole cards for a player that has agreed to the contract.
     * 
     * @param sourceAddr The source player that provided the partially decrypted cards for the target.
     * @param targetAddr The target player for whom the partially descrypted cards were intended.
     * @param cardIndex The index of the card (0 or 1) to retrieve.
	 *
	 * @return The partially decrypted private card record found at the specified index for the specified player.
     */
    function getPrivateDecryptCard(address sourceAddr, address targetAddr, uint cardIndex) constant public returns (uint256) {
        for (uint8 count=0; count < privateDecryptCards.length; count++) {
            if ((privateDecryptCards[count].sourceAddr == sourceAddr) && (privateDecryptCards[count].targetAddr == targetAddr)) {
                return (privateDecryptCards[count].cards[cardIndex]);
            }
        }
    }
    
    /**
     * Checks if all valild/agreed players are at a specific game phase.
     * 
     * @param phaseNum The phase number that all agreed players should be at.
     * 
     * @return True if all agreed players are at the specified game phase, false otherwise.
     */
    function allPlayersAtPhase(uint phaseNum) public constant returns (bool) {
        for (uint count=0; count < players.length; count++) {
            if (phases[players[count]] != phaseNum) {
                return (false);
            }
        }
        return (true);
    }       
	
	//---------------------------------------------------
	// PUBLICLY ACCESSIBLE UTILITY FUNCTIONS 
    //---------------------------------------------------
   
	/**
	* @return The number of players in the 'players' array.
	*/
	function num_Players() public constant returns (uint) {
	    return (players.length);
	}
	 
	/**
	* @param target The address of the target agreed player for which to retrieve the number of stored keypairs.
	*
	* @return The number of keypairs stored for the target player address.
	*/
	function num_Keys(address target) public constant returns (uint) {
	    return (playerKeys[target].length);
	}
	 
	/**
	* @param target The address of the target agreed player for which to retrieve the number of cards in the 'playerCards' array.
	*
	* @return The number of cards stored for the target player in the 'playerCards' array.
	*/
	function num_PlayerCards(address target) public constant returns (uint) {
	    return (playerCards[target].length);
	}
	
	/**
	* @param targetAddr The address of the target agreed player for which to retrieve the number of cards in the 'privateCards' array.
	*
	* @return The number of cards stored for the target player in the 'privateCards' array.
	*/
	function num_PrivateCards(address targetAddr) public constant returns (uint) {
	    return (DataUtils.arrayLength2(privateCards[targetAddr]));
	}
	
	/**
	* @return The number of cards stored in the 'publicCards' array.
	*/
	function num_PublicCards() public constant returns (uint) {
	    return (DataUtils.arrayLength5(publicCards));
	}	 
	
	/**
	* @param sourceAddr The source or sending address of the player who stored the partially-decrypted private cards for the
	* player specified by the 'targetAddr' address.
	* @param targetAddr The target address of the player for whom the partially-decrypted cards are being stored by the 'sourceAddr'
	* player's address.
	*
	* @return The number of partially-decrypted private cards stored for the 'targetAddr' player by the 'sourceAddr' player.
	*/
	function num_PrivateDecryptCards(address sourceAddr, address targetAddr) public constant returns (uint) {
       for (uint8 count=0; count < privateDecryptCards.length; count++) {
           if ((privateDecryptCards[count].sourceAddr == sourceAddr) && (privateDecryptCards[count].targetAddr == targetAddr)) {
               return (privateDecryptCards[count].cards.length);
           }
       }
       return (0);
	}
	
	/**
	* @return The number of addresses stored in the 'winner' array.
	*/
	function num_winner() public constant returns (uint) {
	    return (winner.length);
	}
	
	/**
	* Sets the 'authorizedGameContracts' array to the specified addresses. The 'initReady' and 'complete' flags must
	* be trued before this function is invoked otherwise an exception is thrown.
	*
	* @param contractAddresses An array of addresses that are to be authorized to invoke functions in this contract once it's
	* been initialized. Typically these are addresses of external "PokerHand*" contracts but may include standard account 
	* addresses as well.
	*/
	function setAuthorizedGameContracts (address[] contractAddresses) public {
	    if ((initReady == false) || (complete == false)) {
	        throw;
	    }
	    authorizedGameContracts=contractAddresses;
		numAuthorizedContracts = authorizedGameContracts.length;
	}
	
	//---------------------------------------------------
	// AUTHORIZED CONTRACT / ADDRESS UTILITY FUNCTIONS 
    //---------------------------------------------------

	/**
	* Adds a card for a specific player to the end of the 'playerCards' array.
	* 
	* @param playerAddress The target address of the agreed player for whom to store the card.
	* @param index The index value of the card to store.
	* @param suit The suit value of the card to store.
	* @param value The face value of the card to store.
	*/
	function add_playerCard(address playerAddress, uint index, uint suit, uint value) public onlyAuthorized {         
       playerCards[playerAddress].push(Card(index, suit, value));
    }
    
    /**
	* Updates a card for a specific player within the 'playerCards' array.
	*
	* @param playerAddress The target address of the agreed player for whom to update the card.
	* @param cardIndex The index of the card within the 'playerCards' array for the 'playerAddress' player.
	* @param index The index value of the card to update.
	* @param suit The suit value of the card to update.
	* @param value The face value of the card to update.
	*/
	function update_playerCard(address playerAddress, uint cardIndex, uint index, uint suit, uint value) public onlyAuthorized {
        playerCards[playerAddress][cardIndex].index = index;
        playerCards[playerAddress][cardIndex].suit = suit;
        playerCards[playerAddress][cardIndex].value = value;
    }
     
    /**
	* Sets the validation index value for a specific player address.
	*
	* @param playerAddress The address of the player to set the validation index value for.
	* @param index The validation index value to set.
	*/
	function set_validationIndex(address playerAddress, uint index) public onlyAuthorized {
		if (index == 0) {
		} else {	
			validationIndex[playerAddress] = index;
		}
    }
	
	/**
	* Sets or resets a result value for an agreed player in the 'results' array.
	*
	* @param playerAddress The address of the player to set the result for.
	* @param result The result value to set. If 0 the entry is removed from the 'results' array.
	*/
	function set_result(address playerAddress, uint256 result) public onlyAuthorized {
		if (result == 0) {
			 delete results[playerAddress];
		} else {
			results[playerAddress] = result;
		}
    }
	 
	/**
	* Sets the 'complete' flag value.
	*
	* @param completeSet The value to set the 'complete' flag to.
	*/
	function set_complete (bool completeSet) public onlyAuthorized {
		complete = completeSet;
	}
	 
	/**
	* Sets a public card value in the 'publicCards' array.
	*
	* @param card The card value to set.
	* @param index The index within the 'publicCards' array to set the value to.
	*/
	function set_publicCard (uint256 card, uint index) public onlyAuthorized {		
		publicCards[index] = card;
	}
	 
	/**
	* Adds newly encrypted cards for an address or clears out the 'encryptedDeck' data for the address. 	
	*
	* @param fromAddr The target address of the player for which to set the encrypted cdeck values.
	* @param cards The array of cards encrypted by the 'fromAddr' player to store in the 'encryptedDeck' array. If this is
	* an empty array the elements for the 'fromAddr' player address are cleared from the 'encryptedDeck' array.
	*/
	function set_encryptedDeck (address fromAddr, uint256[] cards) public onlyAuthorized {
	    if (cards.length == 0) {
			/*
			for (uint count2=0; count2<52; count2++) {
				delete encryptedDeck[fromAddr][count2];
			}
			*/
        	delete encryptedDeck[fromAddr];
	    } else {
		    for (uint8 count=0; count < cards.length; count++) {
                encryptedDeck[fromAddr][DataUtils.arrayLength52(encryptedDeck[fromAddr])] = cards[count];             
            }
	    }
	}
	 
	/**
	* Adds or resets private card selection(s) for a player address to the 'privateCards' array.
	*
	* @param fromAddr The player address for which to add private card selections.
	* @param cards The card(s) to add to the 'privateCards' array for the 'fromAddr' player address. If this is an
	* empty array the existing elements in 'privateCards' for the 'fromAddr' address are cleared.
	*/
	function set_privateCards (address fromAddr, uint256[] cards) public onlyAuthorized {	
		if (cards.length == 0) {
			for (uint8 count=0; count<2; count++) {				
				delete privateCards[fromAddr][count];
			}
			delete privateCards[fromAddr];
			for (count= 0; count<playerCards[fromAddr].length; count++) {
				delete playerCards[fromAddr][count];
			}
			delete playerCards[fromAddr];
		} else {
			for (count=0; count<cards.length; count++) {
				privateCards[fromAddr][DataUtils.arrayLength2(privateCards[fromAddr])] = cards[count];             
			} 
		}
	}
	 
	/**
	* Sets the betting position as an offset within the players array. The current betting player address is 'players[betPosition]'.
	*
	* @param betPositionVal The bet position value to assign to the 'betPosition' variable.
	*/
	function set_betPosition (uint betPositionVal) public onlyAuthorized {		
        betPosition = betPositionVal;
	}
	 
	/**
	* Sets the 'bigBlindHasBet' flag value. When true this flag indicates that at least one complete round of betting has completed.
	*
	* @param bigBlindHasBetVal The value to assign to the 'bigBlindHasBet' variable.
	*
	*/
	function set_bigBlindHasBet (bool bigBlindHasBetVal) public onlyAuthorized {
        bigBlindHasBet = bigBlindHasBetVal;
	}
	 
	/**
	* Sets the 'playerHasBet' flag for a specific agreed player address. When true this flag indicates that the associated player 
	* has bet during this round of betting.
	*
	* @param fromAddr The agreed player address to set the 'playerHasBet' flag for.
	* @param hasBet The value to assign to the 'playerHasBet' array for the 'fromAddr' player address.
	*/
	function set_playerHasBet (address fromAddr, bool hasBet) public onlyAuthorized {		
        playerHasBet[fromAddr] = hasBet;
	}
	 
	/**
	* Sets the bet value for a player in the 'playerBets' array.
	*
	* @param fromAddr The address of the agreed player for which to set the bet value.
	* @param betVal The bet value, in wei, to set for the 'fromAddr' player address.
	*/
	function set_playerBets (address fromAddr, uint betVal) public onlyAuthorized {		
        playerBets[fromAddr] = betVal;
	}
	 
	/**
	* Sets the chips value for a player in the 'playerChips' array.
	*
	* @param forAddr The agreed player address for which to set the chips value.
	* @param numChips The number of chips, in wei, to set for the 'forAddr' player address.
	*/
	function set_playerChips (address forAddr, uint numChips) public onlyAuthorized {		
        playerChips[forAddr] = numChips;
	}
	 
	/**
	* Sets the 'pot' variable value.
	*
	* @param potVal The pot value, in wei, to assign to the 'pot' variable.
	*/
	function set_pot (uint potVal) public onlyAuthorized {		
        pot = potVal;
	}
	 
	/**
	* Sets the contract agreed value of a player in the 'agreed' array.
	* 
	* @param fromAddr The address of the player for which to set the agreement flag. This player should
	* appear in the 'players' array.
	* @param agreedVal The value to assign to the 'agreed' array for the 'fromAddr' player address.
	*/
	function set_agreed (address fromAddr, bool agreedVal) public onlyAuthorized {		
        agreed[fromAddr] = agreedVal;
	}
	 
	/**
	* Adds a winning player's address to the end of the 'winner' array.
	*
	* @param winnerAddress The agreed player address to add to the end of the 'winner' array.
	*/
	function add_winner (address winnerAddress) public onlyAuthorized {		
       winner.push(winnerAddress);
	}
	 
	/**
	* Clears/resets the contents of the 'winner' array.
	*/
	function clear_winner () public onlyAuthorized {		
        winner.length=0;
	}
	 
	/**
	* Sets or resets the 'players' array with the addresses supplied, optionally resetting 'nonces' and 'initReady' values.
	* 
	* @param newPlayers The addresses of the players to assign to the 'players' array. Each of these
	* addresses must agree to the contract before a game can begin. If an empty array is supplied, the 'players'
	* and 'nonces' arrays are cleared/reset, and the 'initReady' flag is set to true.
	*/
	function new_players (address[] newPlayers) public onlyAuthorized {
		if (newPlayers.length == 0) {
			for (uint count=0; count<players.length; count++) {
				delete nonces[players[count]];
			}
		}		
        players = newPlayers;
		if (newPlayers.length == 0) {
			initReady=true;
		}
	}
	 
	/**
	* Sets the game phase in the 'phases' array for a specific player address.
	*
	* @param fromAddr The agreed player address for which to set the phase value.
	* @param phaseNum The phase number to set for the 'fromAddr' player address.
	*/
	function set_phase (address fromAddr, uint8 phaseNum) public onlyAuthorized {		
        phases[fromAddr] = phaseNum;
	}
	 
	/**
	* Sets the last action block time value, 'lastActionBlock', for this contract.
	*
	* @param blockNum The block number to assign to the 'lastActionlock' variable.
	*/
	function set_lastActionBlock(uint blockNum) public onlyAuthorized {		
		lastActionBlock = blockNum;
	}
	 
	/**
	* Sets or resets the partial private card decryptions in the 'privateDecryptCards' array for a player address from a decrypting player.
	* 
	* @param fromAddr The sending or decrypting agreed player address that is supplying the partially-decrypted card values.
	* @param cards The partially-decrypted cards being stored for the 'targetAddr' player address. If this is an empty array
	* all of the elements of 'privateDecryptCards' are cleared / reset (for all players).
	* @param targetAddr The target agreed player address to whom the partially-decrypted card selections belong.
	*/	
	function set_privateDecryptCards (address fromAddr, uint256[] cards, address targetAddr) public onlyAuthorized {			
		if (cards.length == 0) {
			for (uint8 count=0; count < privateDecryptCards.length; count++) {
				delete privateDecryptCards[count];
			}
		} else {
			uint structIndex = privateDecryptCardsIndex(fromAddr, targetAddr);
			for (count=0; count < cards.length; count++) {
				privateDecryptCards[structIndex].cards[DataUtils.arrayLength2(privateDecryptCards[structIndex].cards)] = cards[count];
			}
		}
	}
	 
	/**
	* Adds or resets encrypted public card selections to the 'publicCards' array. 
	*
	* @param fromAddr The sending agreed player address storing the public card values. 
	* @param cards The encrypted public card(s) selection(s) to add to the 'publicCards' array. If this array is empty then the entire
	* 'publicCards'	array is reset.
	*/
	function set_publicCards (address fromAddr, uint256[] cards) public onlyAuthorized {
		if (cards.length == 0) {
			for (uint8 count = 0; count < 5; count++) {
				publicCards[count]=1;
			}
		} else {
			for (count=0; count < cards.length; count++) {
				publicCards[DataUtils.arrayLength5(publicCards)] = cards[count];
			}
		}
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
	* @param fromAddr The sending or decrypting agreed player storing the partially-decrypted public card values.
	* @param cards The partially-decrypted card value(s) to store. If this parameter is an empty array the 'publicDecrypCards' and 
	* 'playerBestHands' arrays are reset/cleared.
	*/
	function set_publicDecryptCards (address fromAddr, uint256[] cards) public onlyAuthorized {
		if (cards.length == 0) {
			/*
			for (uint count=0; count<5; count++) {				
	            delete publicDecryptCards[fromAddr][count];
	            delete playerBestHands[fromAddr][count];
	        }
			*/
	        delete publicDecryptCards[fromAddr];
			delete playerBestHands[fromAddr];
		} else {			 
			var (maxLength, playersAtMaxLength) = publicDecryptCardsInfo();
			//adjust maxLength value to use as index
			if ((playersAtMaxLength < (players.length - 1)) && (maxLength > 0)) {
				maxLength--;
			}
			for (uint count=0; count < cards.length; count++) {
				publicDecryptCards[fromAddr][maxLength] = cards[count];
				maxLength++;
			}
		}
	}	 
	 
	/**
	* Sets the 'declaredWinner' address declared by a player.
	*
	* @param fromAddr The agreed player address storing a declared winner address.
	* @param winnerAddr The declared agreed player address being stored by the 'fromAddr' player address.
	*/
	function add_declaredWinner(address fromAddr, address winnerAddr) public onlyAuthorized {
		if (winnerAddr == 0) {
			delete declaredWinner[fromAddr];
		} else {
			declaredWinner[fromAddr] = winnerAddr;
		}
	}
	 
	/**
    * Returns the index / position of the 'privateDecryptCards' struct for a specific source and target player address
    * combination. If the combination doesn't exist it is created and the index of the new element is returned.
    * 
    * @param sourceAddr The address of the source or sending player.
    * @param targetAddr The address of the target player to whom the associated partially decrypted cards belong.
    * 
    * @return The index of the element within the privateDecryptCards array that matched the source and target addresses.
    * The element may be new if no matching element can be found.
    */
    function privateDecryptCardsIndex (address sourceAddr, address targetAddr) public onlyAuthorized returns (uint) {      
		for (uint count=0; count < privateDecryptCards.length; count++) {
              if ((privateDecryptCards[count].sourceAddr == sourceAddr) && (privateDecryptCards[count].targetAddr == targetAddr)) {
                  return (count);
              }
        }
        //none found, create a new one
        uint256[2] memory tmp;
        privateDecryptCards.push(DecryptPrivateCardsStruct(sourceAddr, targetAddr, tmp));
        return (privateDecryptCards.length - 1);
    }
	
	/**
	* Sets an encrypted card in the 'playerBestHands' array for a specific player address. 
	*
	* @param fromAddr The player for which to store the encrypted card.
	* @param cardIndex The 0-based card index within the 'playerBestHands' array for the 'fromAddr' address to set.
	* @param card The encrypted card value to set for the 'fromAddr' player at index 'cardIndex' within the 'playerBestHands' array.
	*/
	function set_playerBestHands(address fromAddr, uint cardIndex, uint256 card) public onlyAuthorized {		
		playerBestHands[fromAddr][cardIndex] = card;
	}
	
	/**
	* Adds encryption and decryption keys to the 'playerKeys' array for an agreed player address.
	* 
	* @param fromAddr The agreed player address for which to set the encryption and decryption keys.
	* @param encKeys The encryption keys to store for the 'fromAddr' player address.
	* @param decKeys The decryption keys to store for the 'fromAddr' player address.
	*/
	function add_playerKeys(address fromAddr, uint256[] encKeys, uint256[] decKeys) public onlyAuthorized {		
		//caller guarantees that the number of encryption keys matches number decryption keys
		for (uint count=0; count<encKeys.length; count++) {
			playerKeys[fromAddr].push(Key(encKeys[count], decKeys[count], prime));
		}
	}
	
	/**
	* Deletes / clears the 'playerKeys' array for an agreed player address.
	*
	* @param fromAddr The agreed player address for which to clear entries (encryption and decryption keys), from the 'playerKeys' array.
	*/
	function remove_playerKeys(address fromAddr) public onlyAuthorized {		
		 delete playerKeys[fromAddr];
	}
	
	/**
	* Sets the 'challenger' address.
	*
	* @param challengerAddr The address of the challenging player to assign to the 'challenger' variable.
	*/
	function set_challenger(address challengerAddr) public onlyAuthorized {		
		challenger = challengerAddr;
	}
	
	/**
	* Send an amount, up to and including the current contract's value, to an address. This address does not need to be a player address.
	*
	* @param toAddr The address to send some or all of the contract's value to.
	* @param amount The amount, in wei, to send to the 'toAddr' address.
	*
	* @return The result of the "toAddr.send" operation.
	*/
	function pay (address toAddr, uint amount) public onlyAuthorized returns (bool) {	
		if (toAddr.send(amount)) {
			return (true);
		} 
		return (false);
	}
		
	/**
	* @return Information about the 'publicDecryptCards' array. The tuple includes a 'maxLength' property which
	* is the maximum length of 'publicDecryptCards' for all agreed players (some players may have stored fewer cards), and 
	* 'playersAtMaxLength' which is a count of players that have stored 'maxLength' cards in the 'publicDecryptCards' array.
	*/
	function publicDecryptCardsInfo() public constant returns (uint maxLength, uint playersAtMaxLength) {
        uint currentLength = 0;
        maxLength = 0;
        for (uint8 count=0; count < players.length; count++) {
            currentLength = DataUtils.arrayLength5(publicDecryptCards[players[count]]);
            if (currentLength > maxLength) {
                maxLength = currentLength;
            }
        }
        playersAtMaxLength = 0;
        for (count=0; count < players.length; count++) {
            currentLength = DataUtils.arrayLength5(publicDecryptCards[players[count]]);
            if (currentLength == maxLength) {
                playersAtMaxLength++;
            }
        }
    }
    
    /**
	* Returns the length number of elements stored by a player address in the 'encryptedDeck' array.
	*
	* @param fromAddr The address for which to retrieve the number of stored elements.
	*
	* @return The number of elements stored by 'fromAddr' in the 'encryptedDeck' array.
	*/
	function length_encryptedDeck(address fromAddr) public constant returns (uint) {
        return (DataUtils.arrayLength52(encryptedDeck[fromAddr]));
    }       	 
    
}

library DataUtils {
	
	/**
     * Returns the number of elements in a non-dynamic, 52-element array. The final element in the array that is
     * greater than 1 is considered the end of the array even if all preceeding elements are less than 2.
     * 
     * @param inputArray The non-dynamic storage array to check for length.
     * 
     */
    function arrayLength52(uint[52] inputArray) internal returns (uint) {
       for (uint count=52; count>0; count--) {
            if ((inputArray[count-1] > 1)) {
                return (count);
            }
        }
        return (0);
    }
    
     /**
     * Returns the number of elements in a non-dynamic, 5-element array. The final element in the array that is
     * greater than 1 is considered the end of the array even if all preceeding elements are less than 2.
     * 
     * @param inputArray The non-dynamic storage array to check for length..
     * 
     */
    function arrayLength5(uint[5] inputArray) internal returns (uint) {
        for (uint count=5; count>0; count--) {
            if ((inputArray[count-1] > 1)) {
                return (count);
            }
        }
        return (0);
    }
    
    /**
     * Returns the number of elements in a non-dynamic, 2-element array. The final element in the array that is
     * greater than 1 is considered the end of the array even if all preceeding elements are less than 2.
     * 
     * @param inputArray The non-dynamic storage array to check for length.
     * 
     */
    function arrayLength2(uint[2] inputArray) internal returns (uint) {
       for (uint count=2; count>0; count--) {
            if ((inputArray[count-1] > 1)) {
                return (count);
            }
        }
        return (0);
    }
}

contract PokerHandValidator {		
	struct Card {
        uint index;
        uint suit; 
        uint value;
    }	
	struct Key {
        uint256 encKey;
        uint256 decKey;
        uint256 prime;
    }
    address public owner;
    address public lastSender;
    PokerHandData public pokerHandData;
    Card[5] public workCards; 
    Card[] public sortedGroup;
    Card[][] public sortedGroups;
    Card[][15] public cardGroups;
    function PokerHandValidator () {}
	function () {}
	modifier isAuthorized {
		PokerHandData handData = PokerHandData(msg.sender);
		bool found = false;
		for (uint count=0; count<handData.numAuthorizedContracts(); count++) {
			if (handData.authorizedGameContracts(count) == msg.sender) {
				found = true;
				break;
			}
		}
		if (!found) {			
             throw;
        }
        _;		
	}
    function challenge (address dataAddr, address challenger) public isAuthorized returns (bool) {}
    function validate(address dataAddr, address msgSender) public isAuthorized returns (bool) {}
    function decryptCard(address target, uint cardIndex) private {}
    function validateCard(address target, uint cardIndex) private {}
    function generateScore(address target) private {}
    function checkDecryptedCard (address sender, uint256 cardValue) private returns (bool) {}
	function modExp(uint256 base, uint256 exp, uint256 mod) internal returns (uint256 result) {}
	function getCardIndex(uint256 value, uint256 baseCard, uint256 prime) public constant returns (uint256 index) {}
    function calculateHandScore() private returns (uint256) {}
    function groupWorkCards(bool byValue) private {}
    function clearGroups() private {}
	function sortWorkCards(bool acesHigh) private {}
	function scoreStraights(bool acesHigh) private returns (uint256) {}
    function scoreGroups(bool valueGroups, bool acesHigh) private returns (uint256) {}
    function checkGroupExists(uint8 memberCount) private returns (bool) {}
	function addCardValues(uint256 startingValue, bool acesHigh) private returns (uint256) {}
    function getSortedGroupLength32(uint8 index) private returns (uint32) {}  
}
pragma solidity ^0.4.5;
/**
* 
* Manages wagers, verifications, and disbursement for a single CypherPoker hand (round).
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
contract PokerHandBI { 
    
	using CryptoCards for *;
	using PokerHandAnalyzer for *;
	
    
    address public owner; //the contract owner -- must exist in any valid Pokerhand-type contract
    address[] public players; //players, in order of play, who must agree to contract before game play may begin; the last player is the dealer, player 1 (index 0) is small blind, player 2 (index 2) is the big blind
    uint256 public buyIn; //buy-in value, in wei, required in order to agree to the contract (send with "agreeToContract" call)
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
    mapping (address => CryptoCards.Key) public playerKeys; //playerss crypo keypairs
    CryptoCards.SplitCardGroup private analyzeCards; //face/value split cards being used for analysis    
    mapping (address => CryptoCards.Card[]) public playerCards; //final decrypted cards for players (only generated during a challenge)
    uint256[5] public communityCards;  //final decrypted community cards (only generated during a challenge)
    uint256 public highestResult=0; //highest hand rank (only generated during a challenge)
    mapping (address => uint256) public results; //hand ranks per player or numeric score representing actions (1=fold lost, 2=fold win, 3=concede loss, 4=concede win)    
    address public declaredWinner; //address of the self-declared winner of the contract (may be challenged)
    address public winner; //address of the hand's/contract's resolved or actual winner
    uint public lastActionBlock; //block number of the last valid player action that was committed. This value is set to the current block on every new valid action.
    uint public timeoutBlocks; //the number of blocks that may elapse before the next valid player's (lack of) action is considered to have timed out 
	
    //--- PokerHandAnalyzer required work values BEGIN ---
	
    CryptoCards.Card[5] public workCards; 
    CryptoCards.Card[] public sortedGroup;
    CryptoCards.Card[][] public sortedGroups;
    CryptoCards.Card[][15] public cardGroups;	
	
    //--- PokerHandAnalyzer required work values END ---
    
    /**
     * Phase values:
     * 0 - Agreement (not all players have agreed to contract yet)
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
     */
    mapping (address => uint8) public phases;

  	function PokerHandBI() {
		owner = msg.sender;
    }
	
	/**
	 * Initializes the contract
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
	 *
	 * Gas required ~250000
	 */
	function initialize(address[] requiredPlayers, uint256 primeVal, uint256 baseCardVal, uint256 buyInVal, uint timeoutBlocksVal) public {
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
	    prime = primeVal;
	    baseCard = baseCardVal;
	    buyIn = buyInVal;
	    timeoutBlocks = timeoutBlocksVal;
        for (uint count=0; count<requiredPlayers.length; count++) {
            players.push(requiredPlayers[count]);
            phases[requiredPlayers[count]] = 0;
			playerChips[requiredPlayers[count]] = 0;
			playerBets[requiredPlayers[count]] = 0;
			playerHasBet[requiredPlayers[count]] = false;
        }
        pot=0;
        betPosition=0;
	}	
	
	/**
	* Returns a the card index of a supplied value. Card indexes are calculated as offsets of quadratic residues modulo prime (storage) with respect
	* to baseCard. If 0 is returned then the supplied value is not a valid card.
	*
	* Gas required for full (52-card) evaluation ~2600000 (usually less if value is determined before full evaluation)
	*/
	function getCardIndex(uint256 value) private returns (uint256 index) {
		index = 1;
		if (value == baseCard) {
			return;
		}
		index++;
		uint256 baseVal = baseCard;
		uint256 exp = (prime-1)/2;		
		while (index < 53) {
			baseVal++;			
			if (CryptoCards.modExp(baseVal, exp, prime) == 1) {
				if (baseVal == value) {					
					return;
				} else {
					index++;
				}
			}			
		}
		index = 0;
		return;
	}
	
	
	/**
	 * Temporary self-destuct function to remove contract from blockchain during development.
	 */
	function destroy() {		
		selfdestruct(msg.sender); 
	}
   
   /*
   * Returns true if the supplied address is allowed to agree to this contract.
   */
   function allowedToAgree (address player) private returns (bool) {		
        for (uint count=0; count<players.length; count++) {
            if (player==players[count]) {
                return (true);
            }
        }
        return (false);		
    }
    
    /*
	* Sets the "agreed" flag to true for the transaction sender. Only accounts registered during the "initialize"
	* call are allowed to agree. Once all valid players have agreed the block timeout is started and the next
	* player must commit the next valid action before the timeout has elapsed.
	*
	* The value sent with this function invocation must equal the "buyIn" value (wei) exactly, otherwise
	* an exception is thrown and any included value is refunded. Only when the buy-in value is matched exactly
	* will the "agreed" flag for the player be set and the phase updated to 1.
	*/
	function agreeToContract() payable public {      		
        if (!allowedToAgree(msg.sender)) {
            throw;
        }
		if (phases[msg.sender] != 0) {
			throw;
		}
		if (msg.value != buyIn) {
		    throw;
		}
		playerChips[msg.sender] = msg.value;
		agreed[msg.sender]=true;
        phases[msg.sender]=1;
        uint agreedNum;
        for (uint count=0; count<players.length; count++) {
            if (agreed[players[count]]) {
                agreedNum++;
            }
        }
        if (agreedNum == players.length) {
            lastActionBlock = block.number;
        }
    }
    
    /**
     * Returns the number of elements in a non-dynamic, 52-element array. The final element in the array that is
     * greater than 1 is considered the end of the array even if all preceeding elements are less than 2.
     * 
     * @param inputArray The non-dynamic storage array to check for length.
     * 
     */
    function arrayLength52(uint256[52] storage inputArray) private returns (uint) {
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
    function arrayLength5(uint256[5] storage inputArray) private returns (uint) {
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
    function arrayLength2(uint256[2] storage inputArray) private returns (uint) {
       for (uint count=2; count>0; count--) {
            if ((inputArray[count-1] > 1)) {
                return (count);
            }
        }
        return (0);
    }
    
  	/**
	* Stores up to 52 encrypted cards of a full deck for a player. The player must have been specified during initialization, must have agreed,
	* and must be at phase 1. This function may be invoked multiple times by the same player during the encryption phase if transactions need 
	* to be broken up into smaler units.
	*
	* @param cards The encrypted card values to store. Once 52 cards (and only 52 cards) have been stored the player's phase is updated. 
	*/
	function storeEncryptedDeck(uint256[] cards) {
		 if (agreed[msg.sender] != true) {
           throw;
        } 
        if (phases[msg.sender] > 1) {
           throw;
        }  
        for (uint8 count=0; count<cards.length; count++) {
            encryptedDeck[msg.sender][arrayLength52(encryptedDeck[msg.sender])] = cards[count];             
        }
        if (arrayLength52(encryptedDeck[msg.sender]) == 52) {
            phases[msg.sender]=2;
        }		
	}
    
	/**
	 * Stores up to 2 encrypted private or hole cards for a player. The player must have been specified during initialization, must have agreed,
 	 * and must be at phase 2. This function may be invoked multiple times by the same player during the encryption phase if transactions need 
	 * to be broken up into smaler units.
	 *
	 * @param cards The encrypted card values to store. Once 2 cards (and only 2 cards) have been stored the player's phase is updated. 	 
	 */
    function storePrivateCards(uint256[] cards) public {
		if (agreed[msg.sender] != true) {
           throw;
        } 
        if (phases[msg.sender] != 2) {
           throw;
        }  
        for (uint8 count=0; count<cards.length; count++) {
            privateCards[msg.sender][arrayLength2(privateCards[msg.sender])] = cards[count];             
        }
        if (arrayLength2(privateCards[msg.sender]) == 2) {
            phases[msg.sender]=3;
        }
        lastActionBlock = block.number;
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
    function storePrivateDecryptCards(uint256[] cards, address targetAddr) public {
		if (agreed[msg.sender] != true) {
           throw;
        }
        if (agreed[targetAddr] != true) {
           throw;
        } 
        if (phases[targetAddr] != 3) {
           throw;
        }
        uint structIndex = privateDecryptCardsIndex(msg.sender, targetAddr);
        for (uint8 count=0; count < cards.length; count++) {
            privateDecryptCards[structIndex].cards[arrayLength2(privateDecryptCards[structIndex].cards)] = cards[count];
        }
        if (allPrivateDecryptCardsStored(targetAddr)) {
            phases[targetAddr]=4;
        }
        lastActionBlock = block.number;
    }
    
    /**
     * Accesses partially decrypted private/hole cards for a player that has agreed to the contract.
     * 
     * @param sourceAddr The source player that provided the partially decrypted cards for the target.
     * @param targetAddr The target player for whom the partially descrypted cards were intended.
     * @param cardIndex The index of the card (0 or 1) to retrieve. 
     */
    function getPrivateDecryptCard(address sourceAddr, address targetAddr, uint cardIndex) constant public returns (uint256) {
        for (uint8 count=0; count < privateDecryptCards.length; count++) {
            if ((privateDecryptCards[count].sourceAddr == sourceAddr) && (privateDecryptCards[count].targetAddr == targetAddr)) {
                return (privateDecryptCards[count].cards[cardIndex]);
            }
        }
    }
    
    /**
     * Checks whether all partially decrypted cards for a specific target player have been stored
     * by all other players.
     * 
     * @param targetAddr The target player for whom partially decrypted cards should be stored.
     * 
     * @return True if all partially decrypted cards for the target player have been stored by all other players,
     * false otherwise.
     */
    function allPrivateDecryptCardsStored(address targetAddr) private returns (bool) {
        uint cardGroupsStored = 0;
        for (uint count=0; count < privateDecryptCards.length; count++) {
            if (privateDecryptCards[count].targetAddr == targetAddr) {
                if (arrayLength2(privateDecryptCards[count].cards) == 2) {
                    cardGroupsStored++;
                }
            }
        }
        if (cardGroupsStored == (players.length-1)) {
            //all other players have stored their partial decryptions
            return (true);
        } else {
            //some other players have yet to store partial decryptions
            return (false);
        }
    }
    
    /**
     * Returns the index / position of the privateDecryptCards struct for a specific source and target address
     * combination. If the combination doesn't exist it is created and the index of the new element is
     * returned.
     * 
     * @param sourceAddr The address of the source or sending player.
     * @param targetAddr The address of the target player to whom the associated partially decrypted cards belong.
     * 
     * @return The index of the element within the privateDecryptCards array that matched the source and target addresses.
     * The element may be new if no matching element can be found.
     */
    function privateDecryptCardsIndex (address sourceAddr, address targetAddr) private returns (uint) {
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

    /*
	* Stores the encrypted public or community card(s) for the hand. Currently only the dealer may store public/community card
	* selections to the contract.
	*
	* @param cards The encrypted public/community cards to store. The number of cards that may be stored depends on the
	* current player phases (all players). Three cards are stored at phase 5 (in multiple invocations if desired), and one card is stored at 
	* phases 8 and 11.
	*/
    function storePublicCards(uint256[] cards) public {   
	    if (msg.sender != players[players.length-1]) {
	        //not the dealer
	        throw;
	    }
	    if (agreed[msg.sender] != true) {
           throw;
        }
        if ((allPlayersAtPhase(5) == false) && (allPlayersAtPhase(8) == false) && (allPlayersAtPhase(11) == false)) {
            throw;
        }
        if ((allPlayersAtPhase(5)) && ((cards.length + arrayLength5(publicCards)) > 3)) {
            //at phase 5 we can store a maximum of 3 cards
            throw;
        }
        if ((allPlayersAtPhase(5) == false) && (cards.length > 1)) {
            //at valid phases above 5 we can store a maximum of 1 card
            throw;
        }
        for (uint8 count=0; count < cards.length; count++) {
            publicCards[arrayLength5(publicCards)] = cards[count];
        }
        if (arrayLength5(publicCards) > 2) {
            //phases are incremented at 3, 4, and 5 cards
            for (count=0; count < players.length; count++) {
                phases[players[count]]++;
            }
        }
        lastActionBlock = block.number;
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
    function storePublicDecryptCards(uint256[] cards) public {
		if (agreed[msg.sender] != true) {
           throw;
        }
        if ((phases[msg.sender] != 6) && (phases[msg.sender] != 9) && (phases[msg.sender] != 12)){
           throw;
        }
        if ((phases[msg.sender] == 6) && (cards.length != 3)) {
            throw;
        }
        if ((phases[msg.sender] != 6) && (cards.length != 1)) {
            throw;
        }
        var (maxLength, playersAtMaxLength) = publicDecryptCardsInfo();
        //adjust maxLength value to use as index
        if ((playersAtMaxLength < (players.length-1)) && (maxLength > 0)) {
            maxLength--;
        }
        for (uint count=0; count < cards.length; count++) {
            publicDecryptCards[msg.sender][maxLength] = cards[count];
            maxLength++;
        }
        (maxLength, playersAtMaxLength) = publicDecryptCardsInfo();
        if (playersAtMaxLength == (players.length-1)) {
            for (count=0; count < players.length; count++) {
                phases[players[count]]++;
            }
        }
        lastActionBlock = block.number;
    }
    
    /**
     * Returns information about the publicDecryptCards arrays for all players.
     * 
     * @return maxLength The maximum length of one or more publicDecryptCards arrays.
     * @return playersAtMaxLength The number of player arrays that are at maxLength.
     */
    function publicDecryptCardsInfo() private returns (uint maxLength, uint playersAtMaxLength) {
        uint currentLength = 0;
        maxLength = 0;
        for (uint8 count=0; count < players.length; count++) {
            currentLength = arrayLength5(publicDecryptCards[players[count]]);
            if (currentLength > maxLength) {
                maxLength = currentLength;
            }
        }
        playersAtMaxLength = 0;
        for (count=0; count < players.length; count++) {
            currentLength = arrayLength5(publicDecryptCards[players[count]]);
            if (currentLength == maxLength) {
                playersAtMaxLength++;
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
    function allPlayersAtPhase(uint phaseNum) private returns (bool) {
        for (uint count=0; count < players.length; count++) {
            if (phases[players[count]] != phaseNum) {
                return (false);
            }
        }
        return (true);
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
	function storeBet (uint256 betValue) public  {		
		if (agreed[msg.sender] == false) {
		    throw;
		}
	    if ((allPlayersAtPhase(4) == false) && (allPlayersAtPhase(7) == false) && (allPlayersAtPhase(10) == false) && (allPlayersAtPhase(13) == false)) {
            throw;
        }
        if (playerChips[msg.sender] < betValue) {
            throw;
        }
        if (players[betPosition] != msg.sender) {
            throw;
        }
        if (players[1] == msg.sender) {
            if (bigBlindHasBet == false) {
                bigBlindHasBet = true;
            } else {
                playerHasBet[msg.sender] = true;
            }
        } else {
          playerHasBet[msg.sender] = true;  
        }
        playerBets[msg.sender] += betValue;
        playerChips[msg.sender] -= betValue;
		pot += betValue;
		betPosition++;
		betPosition %= players.length;
		uint256 currentBet = playerBets[players[0]];
		lastActionBlock = block.number;
		for (uint count=1; count<players.length; count++) {
		    if (playerBets[players[count]] != currentBet) {
		        //all player bets should match in order to end betting round
		        return;
		    }
		}
		if (allPlayersHaveBet(true) == false) {
		    return;
		}
		//all players have placed at least one bet and bets are equal: reset bets, increment phases, reset bet position and "playerHasBet" flags
		for (count=0; count<players.length; count++) {
		    playerBets[players[count]] = 0;
		    phases[players[count]]++;
		    playerHasBet[players[count]] = false;
		    betPosition = 0;
		}
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
    function fold() public {
        if (agreed[msg.sender] == false) {
		    throw;
		}
	    if ((allPlayersAtPhase(4) == false) && (allPlayersAtPhase(7) == false) && (allPlayersAtPhase(10) == false) && (allPlayersAtPhase(13) == false)) {
            throw;
        }
        if (players[betPosition] != msg.sender) {
            throw;
        }
        address[] memory newPlayersArray = new address[](players.length-1);
        uint pushIndex=0;
        for (uint count=0; count<players.length; count++) {
            if (players[count] != msg.sender) {
                newPlayersArray[pushIndex]=players[count];
                pushIndex++;
            }
        }
        if (newPlayersArray.length == 1) {
            //game has ended since only one player's left
            winner=newPlayersArray[0];
            payout();
        } else {
            //game may continue
            players=newPlayersArray;
            betPosition = betPosition % players.length; 
        }
        lastActionBlock = block.number;
    }
    
    /**
     * Declares the sending player as a winner. Sending player must have agreed to contract and all players must be at be 
     * at phase 14. A winning player may only be declared once at which point all players' phases are updated to 15.
     * 
     * A declared winner may be challenged before timeoutBlocks have elapsed, or later if resolveWinner hasn't yet
     * been called.
     * 
     */
    function declareWinner() public {
       if (agreed[msg.sender] == false) {
		    throw;
		}
	    if (allPlayersAtPhase(14) == false) {
            throw;
        }
        if (declaredWinner == 0) {
            declaredWinner = msg.sender;
        } else {
            throw;
        }
        for (uint count=0; count<players.length; count++) {
            phases[players[count]] = 15;
        }
        lastActionBlock = block.number;
    }
    
    /**
     * Returns true if the hand/contract has timed out. A time out occurs when the current
     * block number is higher than or equal to lastActionBlock + timeoutBlocks.
     * 
     * If lastActionBlock or timeoutBlocks is 0, false will always be returned.
     */
    function hasTimedOut() public constant returns (bool) {
        if ((lastActionBlock==0) || (timeoutBlocks == 0)) {
            return (false);
        }
         if ((lastActionBlock+timeoutBlocks) <= block.number) {
            return (true);
        } else {
            return (false);
        }
    }
    
    /**
     * Resolves the declared winner if no challenge has been raised. The declaredWinner address must be set, all players
     * must be at phase 15, and the contract must be timed out. If successfully invoked this function will call "payout".
     * 
     * This function may be invoked by any account but will usually be called by the winner.
     */
    function resolveWinner() public {
        if (allPlayersAtPhase(15) == false) {
            throw;
        }
        if (declaredWinner == 0) {
            throw;
        }
        if (hasTimedOut()) {
            winner=declaredWinner;
            payout();
        }
    }
    
    /**
     * Invokes a level 1 challenge in which all players are required to submit their encryption and decryption keys.
     * These are stored in the contract so that they may be independently verified by external code. Should the verification
     * fail then a level 2 challenge may be issued.
     * 
     * This function may only be invoked if "winner" has not been set, by a non-declaredWinner address, and only if declaredWinner
     * has been set and all players are at phase 15. When successfully invoked the submitting player's phase is updated to 16. 
     * 
     * @param encKeys All the encryption keys used during the hand. The number of keys must be greater than 0 and must 
     * match the number of decKeys.
     * @param decKeys All the decruption keys used during the hand. The number of keys must be greater than 0 and 
     * match the number of encKeys.
     */
    function L1Challenge(uint256[] encKeys, uint256[] decKeys) public {
         if (allPlayersAtPhase(15) == false) {
            throw;
        }
        if (declaredWinner == msg.sender) {
            throw;
        }
        if (winner != 0) {
            throw;
        }
        if ((encKeys.length==0) || (decKeys.length==0)) {
            throw;
        }
        if (encKeys.length != decKeys.length) {
            throw;
        }
        phases[msg.sender] = 16;
        lastActionBlock = block.number;
    }
    
    function L2Challenge() public {
        if (allPlayersAtPhase(16) == false) {
            throw;
        }
        if (declaredWinner == msg.sender) {
            throw;
        }
    }
    
    function resolveChallenge() public {
        
    }
    
    /**
     * Pays out the contract's value by sending the pot + winner's remaining chips to the winner and sending the othe player's remaining chips
     * to them. When all amounts have been paid out, "pot" and all "playerChips" are set to 0 as is the "winner" address. All players'
     * phases are set to 18.
     * 
     * The "winner" address must be set prior to invoking this call.
     */
    function payout() private {
        if (winner == 0) {
            throw;
        }
        if (pot+playerChips[winner] > 0) {
            if(winner.send(pot+playerChips[winner])) {
                pot = 0;
                playerChips[winner] = 0;
            }
        }
        for (uint count=0; count < players.length; count++) {
            phases[players[count]] = 18;
            if (players[count] != winner) {
                if (playerChips[players[count]] > 0) {
                    if (players[count].send(playerChips[players[count]])) {
                        playerChips[players[count]]=0;
                    }
                }
            }
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
    function allPlayersHaveBet(bool reset) private returns (bool) {
        for (uint count = 0; count < players.length; count++) {
            if (playerHasBet[players[count]] == false) {
                return (false);
            }
        }
        if (reset) {
            for (count = 0; count < players.length; count++) {
                playerHasBet[players[count]] = false;
            }
        }
        return (true);
    }
     
}

/**
* 
* Provides cryptographic services for CypherPoker hand contracts.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
* Morden testnet address: 0x07a6864227a8b03943ea4a78e9004726a9548daa
*
*/
library CryptoCards {
    
    /*
	* A standard playing card type.
	*/
	struct Card {
        uint index; //plaintext or encrypted
        uint suit; //1-4
        uint value; //1-13
    }
    
    /*
	* A group of cards.
	*/
	struct CardGroup {
       Card[] cards;
    }
    
    /*
	* Used when grouping suits and values.
	*/
	struct SplitCardGroup {
        uint[] suits;
        uint[] values;
    }
    
    /*
	* A crypto keypair type.
	*/
	struct Key {
        uint256 encKey;
        uint256 decKey;
        uint256 prime;
    }
	
	/*
	* Multiple keypairs.
	*/
	struct Keys {
        Key[] keys;
    }
    
    /*
	* Decrypt a group of cards using multiple supplied crypto keypairs.
	*/
	function decryptCards (CardGroup storage self, Keys storage mKeys) {
        uint cardIndex;
		for (uint8 keyCount=0; keyCount<mKeys.keys.length; keyCount++) {
			Key keyRef=mKeys.keys[keyCount];
			for (uint8 count=0; count<self.cards.length; count++) {            
				cardIndex=modExp(self.cards[count].index, keyRef.decKey, keyRef.prime);
				//store first card index, then suit=(((startingIndex-cardIndex-2) / 13) + 1)   value=(((startingIndex-cardIndex-2) % 13) + 1)
				self.cards[count]=Card(cardIndex, (((cardIndex-2) / 13) + 1), (((cardIndex-2) % 13) + 1));
			}
		}
    }
	
	
	/**
	* Performs an arbitrary-size modular exponentiation calculation.
	*/
	function modExp(uint256 base, uint256 exp, uint256 mod) internal returns (uint256 result)  {
		result = 1;
		for (uint count = 1; count <= exp; count *= 2) {
			if (exp & count != 0)
				result = mulmod(result, base, mod);
			base = mulmod(base, base, mod);
		}
	}	
    
    /**
     * Adjust indexes after final decryption if card indexes need to start at 0.
     */
    function adjustIndexes(Card[] storage self) {
        for (uint8 count=0; count<self.length; count++) {
            self[count].index-=2;
        }
    }
   
    /*
	* Appends card from one deck to another.
	*/
	function appendCards (CardGroup storage self, CardGroup storage targetRef) {
        for (uint8 count=0; count<self.cards.length; count++) {
            targetRef.cards.push(self.cards[count]);
        }
    }
  
    /*
	* Splits cards from a deck into sequantial suits and values.
	*/
	function splitCardData (CardGroup storage self, SplitCardGroup storage targetRef) {
         for (uint8 count=0; count<self.cards.length; count++) {
             targetRef.suits.push(self.cards[count].suit);
             targetRef.values.push(self.cards[count].value);
         }
    }
}

/**
* 
* Poker Hand Analysis library for CypherPoker.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
* Morden testnet address: 0x1887b0571d8e42632ca6509d31e3edc072408a90
*
*/
library PokerHandAnalyzer {
    
	using CryptoCards for *;
	
    /*
    Hand score:
    
    > 800000000 = straight/royal flush
    > 700000000 = four of a kind
    > 600000000 = full house
    > 500000000 = flush
    > 400000000 = straight
    > 300000000 = three of a kind
    > 200000000 = two pair
    > 100000000 = one pair
    > 0 = high card
    */   
	
	struct CardGroups {
		mapping (uint256 => CryptoCards.Card[15]) groups;
	}


	/*
	* Analyzes and scores a single 5-card permutation.
	*/
    function analyze(CryptoCards.Card[5] storage workCards, CryptoCards.Card[] storage sortedGroup, CryptoCards.Card[][] storage sortedGroups, CryptoCards.Card[][15] storage cardGroups) returns (uint256) {
		uint256 workingHandScore=0;
		bool acesHigh=false;  		
        sortWorkCards(workCards, cardGroups, acesHigh);
        workingHandScore=scoreStraights(sortedGroups, workCards, acesHigh);
        if (workingHandScore==0) {
           //may still be royal flush with ace high           
		   acesHigh=true;
		   sortWorkCards(workCards, cardGroups, acesHigh);
           workingHandScore=scoreStraights(sortedGroups, workCards, acesHigh);
        } else {
           //straight / straight flush 
           clearGroups(sortedGroup, sortedGroups, cardGroups);
           return (workingHandScore);
        }
        if (workingHandScore>0) {
           //royal flush
		   clearGroups(sortedGroup, sortedGroups, cardGroups);
           return (workingHandScore);
        } 
        clearGroups(sortedGroup, sortedGroups, cardGroups);
		acesHigh=false;
        groupWorkCards(true, sortedGroup, sortedGroups, workCards, cardGroups); //group by value
        if (sortedGroups.length > 4) {         
		    clearGroups(sortedGroup, sortedGroups, cardGroups);
			acesHigh=false;
            groupWorkCards(false, sortedGroup, sortedGroups, workCards, cardGroups); //group by suit
            workingHandScore=scoreGroups(false, sortedGroups, workCards, acesHigh);
        } else {
            workingHandScore=scoreGroups(true, sortedGroups, workCards, acesHigh);
        }
        if (workingHandScore==0) {            
			acesHigh=true;    
		    clearGroups(sortedGroup, sortedGroups, cardGroups);
            workingHandScore=addCardValues(0, sortedGroups, workCards, acesHigh);
        }
		clearGroups(sortedGroup, sortedGroups, cardGroups);
		return (workingHandScore);
    }
    
     /*
	* Sort work cards in preparation for group analysis and scoring.
	*/
    function groupWorkCards(bool byValue, CryptoCards.Card[] storage sortedGroup, CryptoCards.Card[][] storage sortedGroups, CryptoCards.Card[5] memory workCards,  CryptoCards.Card[][15] storage cardGroups) internal {
        for (uint count=0; count<5; count++) {
            if (byValue == false) {
                cardGroups[workCards[count].suit].push(CryptoCards.Card(workCards[count].index, workCards[count].suit, workCards[count].value));
            } 
            else {
                cardGroups[workCards[count].value].push(CryptoCards.Card(workCards[count].index, workCards[count].suit, workCards[count].value));
            }
        }
        uint8 maxValue = 15;
        if (byValue == false) {
            maxValue = 4;
        }
        uint pushedCards=0;
        for (count=0; count<maxValue; count++) {
           for (uint8 count2=0; count2<cardGroups[count].length; count2++) {
               sortedGroup.push(CryptoCards.Card(cardGroups[count][count2].index, cardGroups[count][count2].suit, cardGroups[count][count2].value));
               pushedCards++;
           }
           if (sortedGroup.length>0) {
             sortedGroups.push(sortedGroup);
			 sortedGroup.length=0;
           }
        }
    }
    
    
    function clearGroups(CryptoCards.Card[] storage sortedGroup, CryptoCards.Card[][] storage sortedGroups, CryptoCards.Card[][15] storage cardGroups) {
         for (uint count=0; count<sortedGroup.length; count++) {
             delete sortedGroup[count];
        }
        sortedGroup.length=0;
		for (count=0; count<cardGroups.length; count++) {
		    delete cardGroups[count];
        }
        for (count=0; count<sortedGroups.length; count++) {
             delete sortedGroups[count];
        }
        sortedGroups.length=0;
    }
    
    /*
	* Sort work cards in preparation for straight analysis and scoring.
	*/
	function sortWorkCards(CryptoCards.Card[5] memory workCards,  CryptoCards.Card[][15] storage cardGroups, bool acesHigh) internal {
        uint256 workValue;
		CryptoCards.Card[5] memory swapCards;
        for (uint8 value=1; value<15; value++) {
            for (uint8 count=0; count < 5; count++) {
                workValue=workCards[count].value;
                if (acesHigh && (workValue==1)) {
                    workValue=14;
                }
                if (workValue==value) {
                    swapCards[count]=workCards[count];
                }
            }
        }        
        for (count=0; count<swapCards.length; count++) {
			workCards[count]=swapCards[count];            
        }		
    }
        
   /*
	* Returns a straight score based on the current 5-card permutation, if a straigh exists.
	*/
	function scoreStraights(CryptoCards.Card[][] storage sortedGroups, CryptoCards.Card[5] memory workCards, bool acesHigh) internal returns (uint256) {
        uint256 returnScore;
        uint256 workValue;
        for (uint8 count=1; count<5; count++) {
            workValue = workCards[count].value;
            if (acesHigh && (workValue==1)) {
                workValue=14;
            }
            if ((workValue-workCards[count-1].value) != 1) {
                //not a straight, delta between sucessive values must be 1
                return (0);
            }
        }
        uint256 suitMatch=workCards[0].suit;
        returnScore=800000000; //straight flush
        for (count=1; count<5; count++) {
            if (workCards[count].suit != suitMatch) {
                returnScore=400000000; //straight (not all suits match)
                break;
            }
        }
        return(addCardValues(returnScore, sortedGroups, workCards, acesHigh));
    }    
    
    /*
	* Returns a group score based on the current 5-card permutation, if either suit or face value groups exist.
	*/
    function scoreGroups(bool valueGroups, CryptoCards.Card[][] storage sortedGroups, CryptoCards.Card[5] memory workCards, bool acesHigh) internal returns (uint256) {
        if (valueGroups) {
            //cards grouped by value
            if (checkGroupExists(4, sortedGroups)) {
                //four of a kind
                acesHigh=true;
                return (addCardValues(700000000, sortedGroups, workCards, acesHigh));
            } 
            else if (checkGroupExists(3, sortedGroups) && checkGroupExists(2, sortedGroups)) {
                //full house
                acesHigh=true;
                return (addCardValues(600000000, sortedGroups, workCards, acesHigh));
            }  
            else if (checkGroupExists(3, sortedGroups) && checkGroupExists(1, sortedGroups)) {
                //three of a kind
                acesHigh=true;
                return (addCardValues(300000000, sortedGroups, workCards, acesHigh));
            } 
            else if (checkGroupExists(2, sortedGroups)){
                uint8 groupCount=0;
                for (uint8 count=0; count<sortedGroups.length; count++) {
                    if (sortedGroups[count].length == 2) {
                        groupCount++;
                    }
                }
                acesHigh=true;
                if (groupCount > 1)  {
                    //two pair
                   return (addCardValues(200000000, sortedGroups, workCards, acesHigh));
                } else {
                    //one pair
                    return (addCardValues(100000000, sortedGroups, workCards, acesHigh));
                }
            }
        } 
        else {
            //cards grouped by suit
            if (sortedGroups[0].length==5) {
                //flush
                acesHigh=true;
                return (addCardValues(500000000, sortedGroups, workCards, acesHigh));
            }
        }
        return (0);
    }
    
	/*
	* Returns true if a group exists that has a specified number of members (cards) in it.
	*/
    function checkGroupExists(uint8 memberCount,  CryptoCards.Card[][] storage sortedGroups) returns (bool) {
        for (uint8 count=0; count<sortedGroups.length; count++) {
            if (sortedGroups[count].length == memberCount) {
                return (true);
            }
        }
        return (false);
    }
    
    /*
	* Adds individual card values to the hand score after group or straight scoring has been applied.
	*/
	function addCardValues(uint256 startingValue,  CryptoCards.Card[][] storage sortedGroups, CryptoCards.Card[5] memory workCards, bool acesHigh) internal returns (uint256) {
        uint256 groupLength=0;
        uint256 workValue;
        uint256 highestValue = 0;
        uint256 highestGroupValue = 0;
        uint256 longestGroup = 0;
        uint8 count=0;
        if (sortedGroups.length > 1) {
            for (count=0; count<sortedGroups.length; count++) {
                groupLength=getSortedGroupLength32(count, sortedGroups);
                for (uint8 count2=0; count2<sortedGroups[count].length; count2++) {
                    workValue=sortedGroups[count][count2].value;
                    if (acesHigh && (workValue==1)) {
                       workValue=14;
                    }
                    if ((sortedGroups[count].length>1) && (sortedGroups[count].length<5)) {
                        startingValue+=(workValue * (10**(groupLength+2))); //start at 100000
                        if ((longestGroup<groupLength) || ((longestGroup==groupLength) && (workValue > highestGroupValue))) {
                            //add weight to longest group or to work value when group lengths are equal (two pair)
                            highestGroupValue=workValue;
                            longestGroup=groupLength;
                        }
                    } 
                    else {
                        startingValue+=workValue;
                        if (workValue > highestValue) highestValue=workValue;
                    }
                }
            }
            startingValue+=highestValue**3;
            startingValue+=highestGroupValue*1000000;
        } 
        else {
            //bool isFlush=(workCards.length == sortedGroups[0].length);
            for (count=0; count<5; count++) {
                workValue=workCards[count].value;
                if (acesHigh && (workValue==1)) {
                   workValue=14;
                }
                startingValue+=workValue**(count+1); //cards are sorted so count+1 produces weight
                if (workValue > highestValue) {
                    highestValue=workValue;
                }
            }
            startingValue+=highestValue*1000000;
        }
        return (startingValue);
    }
    
    /*
    * Returns the group length of a specific sorted group as a uint32 (since .length property is natively uint256)
    */
    function getSortedGroupLength32(uint8 index,  CryptoCards.Card[][] storage sortedGroups)  returns (uint32) {
        uint32 returnVal;
         for (uint8 count=0; count<sortedGroups[index].length; count++) {
             returnVal++;
         }
         return (returnVal);
    }  
}
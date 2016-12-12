pragma solidity ^0.4.5;
/**
* 
* Manages wagers, data storage, and disbursement for a single CypherPoker hand (round).
* 
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
contract PokerHandBI { 
    
    using PHUtils for *;
    
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
    address public owner; //the contract owner -- must exist in any valid Pokerhand-type contract
    address[] public players; //players, in order of play, who must agree to contract before game play may begin; the last player is the dealer, player 1 (index 0) is small blind, player 2 (index 2) is the big blind
    uint256 public buyIn; //buy-in value, in wei, required in order to agree to the contract (send with "agreeToContract" call)
    PokerHandBIValidator public validator; //known and trusted contract to perform valildations on the current contract
    mapping (address => bool) public agreed; //true for all players who agreed to this contract; only players in "players" struct may agree
	uint256 public prime; //shared prime modulus
    uint256 public baseCard; //base or first plaintext card in the deck (all subsequent cards are quadratic residues modulo prime)
    mapping (address => uint256) public playerBets; //stores cumulative bets per betting round (reset before next)
    mapping (address => uint256) public signedBets; //cumulative bets per player per hand accumulated through multiple signed betting messages
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
    address public declaredWinner; //address of the self-declared winner of the contract (may be challenged)
    address[] public winner; //address of the hand's/contract's resolved or actual winner(s)
    uint public lastActionBlock; //block number of the last valid player action that was committed. This value is set to the current block on every new valid action.
    uint public timeoutBlocks; //the number of blocks that may elapse before the next valid player's (lack of) action is considered to have timed out 
    mapping (address => uint) public validationIndex; //highest successfully completed validation index for each player
    address public challenger; //the address of the current contract challenger / validation initiator
    bool reusable; //should contract be re-used?    
    
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
     */
    mapping (address => uint8) public phases;

  	function PokerHandBI() {
  	    reusable = true;
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
	 * @param validatorAddr The address of a valid, trusted contract that can perform validations on the current poker hand contract.
	 *
	 */
	function initialize(address[] requiredPlayers, uint256 primeVal, uint256 baseCardVal, uint256 buyInVal, uint timeoutBlocksVal, address validatorAddr) public {
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
	    if (validatorAddr == 0) {
	        //throw;
	    } else {
	        validator = PokerHandBIValidator(validatorAddr);
	    }
	    prime = primeVal;
	    baseCard = baseCardVal;
	    buyIn = buyInVal;
	    timeoutBlocks = timeoutBlocksVal;
        for (uint count=0; count<requiredPlayers.length; count++) {
            players.push(requiredPlayers[count]);
        }
        pot=0;
        betPosition=0;
	}
	
	/**
     * Returns the address associated with a supplied signature and input data (usually hashed value).
     * 
     * @param data The 32-byte input data that was signed by the associated signature. This is usually a
     * sha3/keccak hash of some plaintext message.
     * @param v The recovery value, calculated as the last byte of the full signature plus 27 (usually either 27 or
     * 28)
     * @param r The first 32 bytes of the signature.
     * @param s The second 32 bytes of the signature.
     * 
     */
    function verifySignature(bytes32 data, uint8 v, bytes32 r, bytes32 s) public constant returns (address) {
        return(ecrecover(data, v, r, s));
    }
	
	/**
	 * Cancels the contract if it has timed out and all required players have not yet agreed. Any playerChips submitted are returned to their original accounts.
	 */
	function cancel() {		
		if (hasTimedOut()) {
		    for (uint count=0; count<players.length; count++) {
		        if (agreed[players[count]] == false) {
		            for (uint count2=0; count2<players.length; count2++) {
		                if (playerChips[players[count2]] > 0) {
		                    if (players[count].send(playerChips[players[count2]])) {
                                playerChips[players[count2]]=0;
                            }
		                }
		            }
		            reset();
		            return;
		        }
		    }
		}
	}
	
	/**
	 * Resets the smart contract data so that it becomes available for re-use.
	 */
	function reset() private {
	    /*
	    if (!reusable) {
	        throw;
	    }
	    if (PokerHandBI(msg.sender) == this) {
	        throw;
	    }
	    //TODO: verify that all data is being properly cleaned up
	    for (uint count=0; count<players.length; count++) {
	        delete players[count];
	        delete agreed[players[count]];
	        delete playerBets[players[count]];
	        delete signedBets[players[count]];
	        delete playerChips[players[count]];
	        delete playerHasBet[players[count]];
	        delete playerKeys[players[count]];
	        for (uint count2=0; count2<52; count2++) {
	            delete encryptedDeck[players[count]][count2];
	        }
	        delete encryptedDeck[players[count]];
	        for (count2=0; count2<2; count2++) {
	            delete privateCards[players[count]][count2];
	            delete playerCards[players[count]][count2];
	        }
	        delete privateCards[players[count]];
	        for (count2=0; count2<5; count2++) {
	            delete publicDecryptCards[players[count]][count2];
	            delete playerBestHands[players[count]][count2];
	        }
	        delete publicDecryptCards[players[count]];
	        delete results[players[count]];
	        delete validationIndex[players[count]];
	    }
	    buyIn=1;
	    validator = PokerHandBIValidator(0);
        prime = 1;
        baseCard = 1;
        bigBlindHasBet = false;
	    pot = 0;
	    betPosition = 0;
	    declaredWinner = 1;
	    for (count=0; count < winner.length; count++) {
	       winner[count] = 1;    
	    }
	    lastActionBlock=1;
	    timeoutBlocks=1;
        for (count = 0; count < privateDecryptCards.length; count++) {
            delete privateDecryptCards[count];
        }
        for (count = 0; count < 5; count++) {
           publicCards[count]=1;
        }
        */
	}
	
    /**
     * Processes a signed transaction as provided by opponents. The transaction hash is created by combining the input values (as strings):
     * txType + txDelimiter + txValue + txDelimiter + txNonce 
     * 
     * @param txType The type of transaction to be processed. Valide types include "B" (bet), "D" (fully-encrypted deck card), 
     * "d" (partially-encrypted deck card), "C" (private card selection), "c" (partially-decrypted card selection - msg.sender is the target
     * and signing account is the source)
     * @param txValue The value to process; may be the bet value or the card value depending on the txType
     * @param txDelimiter The delimiter
     */
    function processSignedTransaction(bytes32 txType, uint256 txValue, string txNonce, string txDelimiter, uint8 v, bytes32 r, bytes32 s) public {
       bytes32 hash=sha3(PHUtils.bytes32ToString(txType), txDelimiter, PHUtils.bytes32ToString(PHUtils.uintToBytes32(txValue)), txDelimiter, txNonce);
       address account = verifySignature (hash, v, r, s);
       bool found=false;
       for (uint count=0; count<players.length; count++) {
           if (players[count] == account) {
               found=true;
           }
       }
       if (!found) {
           throw;
       }
       //TODO: implement signed transaction processing like the following:
       /*
       if (txType=="B") {
            pot+=txValue;
            playerChips[account]-=txValue;
       }
       */
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
		if (msg.value != buyIn) {
		    throw;
		}
		playerChips[msg.sender] = msg.value;
		agreed[msg.sender]=true;
        phases[msg.sender]=1;
		playerBets[msg.sender] = 0;
		playerHasBet[msg.sender] = false;
		validationIndex[msg.sender] = 0;
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
            encryptedDeck[msg.sender][PHUtils.arrayLength52(encryptedDeck[msg.sender])] = cards[count];             
        }
        if (PHUtils.arrayLength52(encryptedDeck[msg.sender]) == 52) {
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
            privateCards[msg.sender][PHUtils.arrayLength2(privateCards[msg.sender])] = cards[count];             
        }
        if (PHUtils.arrayLength2(privateCards[msg.sender]) == 2) {
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
            privateDecryptCards[structIndex].cards[PHUtils.arrayLength2(privateDecryptCards[structIndex].cards)] = cards[count];
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
                if (PHUtils.arrayLength2(privateDecryptCards[count].cards) == 2) {
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

    /**
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
        if ((allPlayersAtPhase(5)) && ((cards.length + PHUtils.arrayLength5(publicCards)) > 3)) {
            //at phase 5 we can store a maximum of 3 cards
            throw;
        }
        if ((allPlayersAtPhase(5) == false) && (cards.length > 1)) {
            //at valid phases above 5 we can store a maximum of 1 card
            throw;
        }
        for (uint8 count=0; count < cards.length; count++) {
            publicCards[PHUtils.arrayLength5(publicCards)] = cards[count];
        }
        if (PHUtils.arrayLength5(publicCards) > 2) {
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
            currentLength = PHUtils.arrayLength5(publicDecryptCards[players[count]]);
            if (currentLength > maxLength) {
                maxLength = currentLength;
            }
        }
        playersAtMaxLength = 0;
        for (count=0; count < players.length; count++) {
            currentLength = PHUtils.arrayLength5(publicDecryptCards[players[count]]);
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
            winner.push(newPlayersArray[0]);
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
     * Resolves the winner using the most current resolution state. If players are at phase 16 (Level 2 validation) the hand is
	 * first checked for a timeout. If the hand has timed out then the players' validation indexes are compared; the player with the
	 * highest index is awarded all of the other player's chips and declared the winner. If more than one player has the highest
	 * validation index then their results are compared and the player with the highest score is declared the winner. Any players
	 * who have not completed their L2 validation will lose all of their chips which will be split evenly among the fully-validated 
	 * players. In the rare event of a tie, no winner is declared and the fully-validated players split the pot evenly.
     * 
     * This function may be invoked by any account but will usually be called by the winner.
     */
    function resolveWinner() public {
        if (hasTimedOut() == false) {
			throw;
		}
        if (allPlayersAtPhase(15) || allPlayersAtPhase(16)){				
            //Level 1 validation or unchallenged
			if (declaredWinner == 0) {
				//no winnder declared!
				throw;
			}
			winner.push(declaredWinner);
		} else if (allPlayersAtPhase(17) || allPlayersAtPhase(19)) {
			//Level 2 validation or challenge
			uint highest=0;
			uint highestPlayers = 0;
			for (uint count=0; count<players.length; count++) {
			    if (validationIndex[players[count]] > highest) {
			        highest = validationIndex[players[count]];
			        highestPlayers=0;
			    }
			    if (validationIndex[players[count]] == highest) {
			        highestPlayers++;
			    }
			}
			if (highestPlayers > 2) {
			    //compare results
			    for (count=0; count<players.length; count++) {
			        if (results[players[count]] > highest) {
			            highest=results[players[count]];
			        }
			    }
			    for (count=0; count<players.length; count++) {
			         if (results[players[count]] == highest) {
			             winner.push(players[count]); //may be more than one winner
			         }
			    }
			} else {
			    //
			    for (count=0; count<players.length; count++) {
			        if (validationIndex[players[count]] == highest) {
			            winner.push(players[count]);
			        }
			    }
			}
			//TODO: implement validation fund refunds (add values to playerChips prior to payout)
		    //Note deposit is: 600000000000000000
		} 
		payout();
    }
    
     /**
     * Invokes a mid-game challenge. This process is similar to the Level 2 challenge and has the effect of stopping the game but does not 
     * result in a player score. Unlike a Level 2 challenge only one value is evaluated for correctness. The card owner (player that submitted the card),
     * is penalized if the value is incorrect otherwise the challenger is penalized. At the completion of a challenge the contract is cancelled.
     * 
     * As with Level 2 validation, the first time that challenge is invoked it must be provided with sufficient challenge funds
     * to cover all other players. This is equal to 0.6 Ether (600000000000000000) per player, excluding self. In other words, if there are only
     * 2 players then 0.6 Ether must be included but if there are 3 players then 1.2 Ether must be included.
     * 
     * @param challengeValue A stored card value being challenged. 
     */
    function challenge (uint256[] encKeys, uint256[] decKeys, uint256 challengeValue) payable public {
        if (agreed[msg.sender] == false) {
            throw;
        }
        if (phases[msg.sender] != 19) {
             //do we need to segregate these funds?
            if (msg.value != (600000000000000000*(players.length-1))) {
                throw;
            }
            if (challenger < 2) {
                //set just once
                challenger = msg.sender;
                playerBestHands[msg.sender][0] = challengeValue; //as reference by the validator
            }
            if ((encKeys.length==0) || (decKeys.length==0)) {
                throw;
            }
            if (encKeys.length != decKeys.length) {
                throw;
            }
            for (uint count=0; count<encKeys.length; count++) {
                playerKeys[msg.sender].push(Key(encKeys[count], decKeys[count], prime));
            }
            phases[msg.sender] = 19;
        }
        validator.challenge.gas(msg.gas-30000)(challenger);
        lastActionBlock = block.number;
    }
    
    
    /**
     * Begins a level 1 validation in which all players are required to submit their encryption and decryption keys.
     * These are stored in the contract so that they may be independently verified by external code. Should the verification
     * fail then a level 2 validation may be issued.
     * 
     * This function may only be invoked if "winner" has not been set, by a non-declaredWinner address, and only if declaredWinner
     * has been set and all players are at phase 15. When successfully invoked the submitting player's phase is updated to 16. 
     * 
     * Keys may be submitted in multiple invocations if required. On the last call all five "bestCards" must be included in order
     * to signal to the contract that no further keys are being submitted.
     * 
     * @param encKeys All the encryption keys used during the hand. The number of keys must be greater than 0 and must 
     * match the number of decKeys.
     * @param decKeys All the decryption keys used during the hand. The number of keys must be greater than 0 and 
     * match the number of encKeys.
     * @param bestCards Indexes of the five best cards of the player. All five values must be unique and be in the range 0 to 6. 
     * Indexes 0 and 1 are the player's encrypted private cards (privateCards), in the order stored in the contract, and indexes 2 to 6 are encrypted 
     * public cards (publicCards), in the order stored in the contract. The five indexes must be supplied with the final call to L1Validate in order 
     * to signal that all keys have now been submitted and validation may begin.
     */
    function L1Validate(uint256[] encKeys, uint256[] decKeys, uint[] bestCards) public {
        if (phases[msg.sender] != 15) {
            throw;
        }
        if (winner.length != 0) {
            throw;
        }
        if ((encKeys.length==0) || (decKeys.length==0)) {
            throw;
        }
        if (encKeys.length != decKeys.length) {
            throw;
        }
        for (uint count=0; count<encKeys.length; count++) {
            playerKeys[msg.sender].push(Key(encKeys[count], decKeys[count], prime));
        }
        if (bestCards.length == 5) {
            uint currentIndex=0;
            //check for uniqueness
            for (count=0; count < 5; count++) {
                currentIndex = bestCards[count];
                for (uint count2=0; count2 < 5; count2++) {
                    if ((count!=count2) && (currentIndex==bestCards[count2])) {
                        //duplicate index
                        throw;
                    }
                }
            }
            for (count=0; count < 5; count++) {
                playerBestHands[msg.sender][count] = bestCards[count];
            }
            phases[msg.sender] = 16;
        }
        lastActionBlock = block.number;
    }
    
    /**
     * Performs one round of Level 2 validation. The first time that L2Validate is invoked it must be provided with sufficient challenge funds
     * to cover all other players. This is equal to 0.6 Ether (600000000000000000) per player, excluding self. In other words, if there are only
     * 2 players then 0.6 Ether must be included but if there are 3 players then 1.2 Ether must be included.
     */
    function L2Validate() payable public {       
        if (allPlayersAtPhase(16) == false) {
            throw;
        }
        if (phases[msg.sender]==16) {
            //do we need to segregate these funds?
            if (msg.value != (600000000000000000*(players.length-1))) {
                throw;
            }
            phases[msg.sender]=17;
        }
        if (challenger < 2) {
            challenger = msg.sender;
        }
        validator.validate.gas(msg.gas-30000)(msg.sender);
		lastActionBlock = block.number;
    }
    
    /**
     * Pays out the contract's value by sending the pot + winner's remaining chips to the winner and sending the othe player's remaining chips
     * to them. When all amounts have been paid out, "pot" and all "playerChips" are set to 0 as is the "winner" address. All players'
     * phases are set to 18 and the reset function is invoked.
     * 
     * The "winner" address must be set prior to invoking this call.
     */
    function payout() private {		
        if (winner.length == 0) {
            throw;
        }
        for (uint count=0; count<winner.length; count++) {
            if ((pot/winner.length)+playerChips[winner[count]] > 0) {
                if(winner[count].send((pot/winner.length)+playerChips[winner[count]])) {
                    pot = 0;
                    playerChips[winner[count]] = 0;
                }
            }
        }
        for (count=0; count < players.length; count++) {
            phases[players[count]] = 18;
            if (playerChips[players[count]] > 0) {
                if (players[count].send(playerChips[players[count]])) {
                    playerChips[players[count]]=0;
                }
            }
        }
        reset();
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
    
    /**
     * Validator contract utility functions.
     */
    function add_playerCard(address playerAddress, uint index, uint suit, uint value) public {
         if (msg.sender != address(validator)) {
            throw;
        }
        playerCards[playerAddress].push(Card(index, suit, value));
    }
    
     function update_playerCard(address playerAddress, uint cardIndex, uint index, uint suit, uint value) public {
         if (msg.sender != address(validator)) {
            throw;
        }
        playerCards[playerAddress][cardIndex].index = index;
        playerCards[playerAddress][cardIndex].suit = suit;
        playerCards[playerAddress][cardIndex].value = value;
    }
    
    function set_validationIndex(address playerAddress, uint index) public {
        if (msg.sender != address(validator)) {
            throw;
        }
        validationIndex[playerAddress] = index;
    }
    
    function set_result(address playerAddress, uint256 result) public {
        if (msg.sender != address(validator)) {
            throw;
        }
        results[playerAddress] = result;
    }
    
    function num_Players() public returns (uint) {
	     return (players.length);
	 }
	 
	 function num_Keys(address target) public returns (uint) {
	     return (playerKeys[target].length);
	 }
	 
	 function num_PlayerCards(address target) public returns (uint) {
	     return (playerCards[target].length);
	 }
	 
	 function num_PrivateCards(address targetAddr) public returns (uint) {
	     return (privateCards[targetAddr].length);
	 }
	 
	 function num_PublicCards() public returns (uint) {
	     return (publicCards.length);
	 }
	 
	 function num_PrivateDecryptCards(address sourceAddr, address targetAddr)  public returns (uint) {
        for (uint8 count=0; count < privateDecryptCards.length; count++) {
            if ((privateDecryptCards[count].sourceAddr == sourceAddr) && (privateDecryptCards[count].targetAddr == targetAddr)) {
                return (privateDecryptCards[count].cards.length);
            }
        }
        return (0);
	 }
     
}

library PHUtils {
    
    /**
     * Converts a string input to a uint256 value. It is assumed that the input string is compatible with an unsigned
     * integer type up to 2^256-1 bits.
     * 
     * @param input The string to convert to a uint256 value.
     * 
     * @return A uint256 representation of the input string.
     */
    function stringToUint256(string input) internal returns (uint256 result) {
      bytes memory inputBytes = bytes(input);
      for (uint count = 0; count < inputBytes.length; count++) {
        if ((inputBytes[count] >= 48) && (inputBytes[count] <= 57)) {
          result *= 10;
          result += uint(inputBytes[count]) - 48;
        }
      }
    }
    
    /**
     * Converts an input uint256 value to a bytes32 value.
     * 
     * @param input The input uint256 value to convert to bytes32.
     * 
     * @return The bytes32 representation of the input uint256 value.
     */
    function uintToBytes32(uint256 input) internal returns (bytes32 result) {
        if (input == 0) {
            result = '0';
        } else {
            while (input > 0) {
                result = bytes32(uint(result) / (2 ** 8));
                result |= bytes32(((input % 10) + 48) * 2 ** (8 * 31));
                input /= 10;
            }
        }
        return result;
    }
    
    /**
     * Converts a bytes32 value to a string type.
     * 
     * @param input The bytes32 input to convert to a string output.
     * 
     * @return The string representation of the bytes32 input.
     */
    function bytes32ToString(bytes32 input) internal returns (string) {
        bytes memory byteStr = new bytes(32);
        uint numChars = 0;
        for (uint count = 0; count < 32; count++) {
            byte currentByte = byte(bytes32(uint(input) * 2 ** (8 * count)));
            if (currentByte != 0) {
                byteStr[count] = currentByte;
                numChars++;
            }
        }
        bytes memory outputBytes = new bytes(numChars);
        for (count = 0; count < numChars; count++) {
            outputBytes[count] = byteStr[count];
        }
        return string(outputBytes);
    }
	
	 /**
     * Returns the number of elements in a non-dynamic, 52-element array. The final element in the array that is
     * greater than 1 is considered the end of the array even if all preceeding elements are less than 2.
     * 
     * @param inputArray The non-dynamic storage array to check for length.
     * 
     */
    function arrayLength52(uint[52] storage inputArray) internal returns (uint) {
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
    function arrayLength5(uint[5] storage inputArray) internal returns (uint) {
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
    function arrayLength2(uint[2] storage inputArray) internal returns (uint) {
       for (uint count=2; count>0; count--) {
            if ((inputArray[count-1] > 1)) {
                return (count);
            }
        }
        return (0);
    }
    
}

contract PokerHandBIValidator {
    //include only functions and variables that are accessed
    function challenge(address msgSender) public returns (bool) {}  
    function validate(address msgSender) public returns (bool) {}  
}
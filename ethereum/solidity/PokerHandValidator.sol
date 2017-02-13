pragma solidity ^0.4.5;
/**
* 
* Provides validation services for a PokerHand-style contract.
* 
* (C)opyright 2016 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*
*/
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

    address public owner; //contract owner
    address public lastSender; //address of last player to invoke a validation function, set to 1 after each round of validation
    PokerHandData public pokerHandData; //the last PokerHandData-style contract to invoke the validator, set to the address 1 after each round of validation

	//Following values are used during hand analysis:
    Card[5] public workCards; 
    Card[] public sortedGroup;
    Card[][] public sortedGroups;
    Card[][15] public cardGroups;
    
     
    
    function PokerHandValidator () {
        owner = msg.sender;
    }
    
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
	
    /**
     * Performs one round of mid-game challenge validation. The contract address being validated is evaluated from msg.sender
     * 
	 * @param dataAddr The address of the PokerHandData contract to work with.
     * @param challenger The address of the challenging player.
     * 
     * @return True if the current challenge verification step was successfully completed and the source contract's validation index has
     * been updated.
     * 
     */
    function challenge (address dataAddr, address challenger) public isAuthorized returns (bool) {		
        //TODO: implement challenge verification
        pokerHandData = PokerHandData(dataAddr);
        lastSender = challenger;
        uint256 challengeValue=pokerHandData.playerBestHands(lastSender, 0);
        //use pokerHandData.playerCards(lastSender, 0) to store decrypted card
        //reset values to prevent external invocations from non-contracts
        pokerHandData=PokerHandData(1);
        lastSender=1;
    }
    
    /**
     * Performs one round of validation on a target contract. The contract address being validated is evaluated from msg.sender
     * 
     * @param dataAddr The address of the PokerHandData contract to work with.
	 * @param msgSender The address of the sending/invoking player.
     * 
     * @return True if the current validation step was successfully completed and the source contract's validation index has
     * been updated.
     * 
     */
    function validate(address dataAddr, address msgSender) public isAuthorized returns (bool) {
       pokerHandData = PokerHandData(dataAddr);	   
       lastSender = msgSender;
       uint validationIndex=pokerHandData.validationIndex(lastSender);
       if (validationIndex < 5) {
           decryptCard(lastSender, pokerHandData.playerBestHands(lastSender, validationIndex));
       }
       if ((validationIndex > 4) && (validationIndex<10)) {
            validateCard(lastSender, (validationIndex-5));
       }
       if (validationIndex == 10) {
           generateScore(lastSender);
       }
       if (validationIndex == 11) {
           //reset values to prevent external invocations from non-contracts
           lastSender=1;
           pokerHandData=PokerHandData(1);
           //no further validations possible
           throw;
       }
       validationIndex++;
       pokerHandData.set_validationIndex(lastSender, validationIndex);
       pokerHandData=PokerHandData(1);
       lastSender=1;
       return (true);
    }
    
    /**
     * Decrypts a card for a target player address and stores the result in the originating PokerHandData contract's "playerCard" variable
     * via the "add_playerCard" function.
     * 
     * @param target The address of the player for which to decrypt the specified card.
     * @param cardIndex The index of the card to decrypt. If the index is less than 2 then the index refers to a card within the target player's privateCards
     * variable within the originating contract, otherwise the 2 is subtracted from the index and is used to retrieve a card from the publicCards variable 
     * within the originating contract.
     * 
     */
    function decryptCard(address target, uint cardIndex) private {
       uint256 selectedCard;
       if (cardIndex < 2) {
           //decrypt private card
           selectedCard=pokerHandData.privateCards(target, cardIndex);
       } else {
           //decrypt public card
           selectedCard=pokerHandData.publicCards(cardIndex-2);
       }
       address currentPlayer;
       for (uint count=0; count < pokerHandData.num_Players(); count++) {
           currentPlayer = pokerHandData.players(count);
           for (uint keyIndex=0; keyIndex<pokerHandData.num_Keys(currentPlayer); keyIndex++) {
               var (encKey, decKey, mod) = pokerHandData.playerKeys(currentPlayer, keyIndex);
               selectedCard = modExp(selectedCard, decKey, mod);
            }
           // if (checkDecryptedCard(currentPlayer, selectedCard) == false) {
                //currentPlayer did not store correct decryption for player!
                //ensure we're not checking fully decrypted card here
          //  }
       }
       pokerHandData.add_playerCard(lastSender, selectedCard, 0, 0);
    }
    
    /**
     * Validates a card for a target player by calculating its quadratic residue index as an offset from the base card of the
     * originating PokerHandData contract. If validated the resulting card is stored an [index, suit, value] tupple in the originating
     * PokerHandData contract for the target playe, in the "playerCard" variable, via the "update_playerCard" function.
     * 
     * @param target The address of the player for which to validate the card.
     * @param cardIndex The index of the card within the originating contract's playerCards array to validate. If validated this same
     * index is updated with the validated tuple.
     */
    function validateCard(address target, uint cardIndex) private {
        var (index, suit, value) = pokerHandData.playerCards(target, cardIndex);
        index=getCardIndex(index, pokerHandData.baseCard(), pokerHandData.prime());
        if ((index > 0) && (index < 53)) {
             pokerHandData.update_playerCard(target, cardIndex, index, (((index-1) / 13) + 1), (((index-1) % 13) + 1));
        }
    }
    
    /**
     * Recalls the target player's best cards, which should now be decrypted and validated, and submits them for analysis
     * to produce a hand score that may be used in ranking players' results. The resulting score is set in the originating PokerHandData
     * contracts "result" mapping via the "set_result" function.
     * 
     * * See "calculateHandScore" for resulting poker hand score ranges.
     * 
     * @param target The target player for which to generate a score and store the result.
     * 
     */
    function generateScore(address target) private {
        for (uint count=0; count<pokerHandData.num_PlayerCards(target); count++) {
             var (index, suit, value) = pokerHandData.playerCards(target, count);
             workCards[count] = Card(index, suit, value);
        }
        pokerHandData.set_result(target, calculateHandScore());
    }
    
    /**
     * Checks if a partially decrypted card value was provided by another player.
     * 
     * @param sender The sending address, or the address of the player for whom the partially decrypted card belongs
     * @param cardValue The partially encrypted card value to be checked.
     * 
     * @return True if the partially decrypted card was provided by another player, false if no matching card could be found.
     */
    function checkDecryptedCard (address sender, uint256 cardValue) private returns (bool) {
        address currentPlayer;
        for (uint count=0; count<pokerHandData.num_Players(); count++) {
            currentPlayer = pokerHandData.players(count);
            if (currentPlayer != sender) {
                for (uint cardIndex=0; cardIndex < pokerHandData.num_PrivateDecryptCards(currentPlayer,sender); cardIndex++) {
                    if (pokerHandData.getPrivateDecryptCard(currentPlayer, sender, cardIndex) == cardValue) {
                        return (true);
                    } 
                }
            }
        }
        return (false);
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
	* Returns a the card index of a supplied value. Card indexes are calculated as offsets of quadratic residues modulo prime (storage) with respect
	* to baseCard. If 0 is returned then the supplied value is not a valid card.
	*
	* Gas required for full (52-card) evaluation ~2600000 (usually less if value is determined before full evaluation)
	* 
	* @param value The plaintext card value for which to return an index.
	* @param baseCard The base, or lowest, card value in the card deck. This value should be a quadratic residue modulo prime.
	* @param prime The prime modulus to use in the evaluation function
	* 
	* @return index The index of the card as an offset minus 1 from the baseCard value (count of quadratic residues modulo prime). A 0
	* is returned if the value isn't a quadratc residue modulo prime or if the index exceeds 52.
	*/
	function getCardIndex(uint256 value, uint256 baseCard, uint256 prime) public constant returns (uint256 index) {
		index = 1;
		if (value == baseCard) {
			return;
		}
		index++;
		uint256 baseVal = baseCard;
		uint256 exp = (prime-1)/2;		
		while (index < 53) {
			baseVal++;			
			if (modExp(baseVal, exp, prime) == 1) {
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
	
	/*
	* Analyzes and scores a single 5-card permutation. Resulting scores ranges include:
	*
	* > 800000000 = straight/royal flush
    * > 700000000 = four of a kind
    * > 600000000 = full house
    * > 500000000 = flush
    * > 400000000 = straight
    * > 300000000 = three of a kind
    * > 200000000 = two pair
    * > 100000000 = one pair
    * > 0 = high card
	*/
    function calculateHandScore() private returns (uint256) {
		uint256 workingHandScore=0;
		bool acesHigh=false;  		
        sortWorkCards(acesHigh);
        workingHandScore=scoreStraights(acesHigh);
        if (workingHandScore==0) {
           //may still be royal flush with ace high           
		   acesHigh=true;
		   sortWorkCards(acesHigh);
           workingHandScore=scoreStraights(acesHigh);
        } else {
           //straight / straight flush 
           clearGroups();
           return (workingHandScore);
        }
        if (workingHandScore>0) {
           //royal flush
		   clearGroups();
           return (workingHandScore);
        } 
        clearGroups();
		acesHigh=false;
        groupWorkCards(true); //group by value
        if (sortedGroups.length > 4) {         
		    clearGroups();
			acesHigh=false;
            groupWorkCards(false); //group by suit
            workingHandScore=scoreGroups(false, acesHigh);
        } else {
            workingHandScore=scoreGroups(true, acesHigh);
        }
        if (workingHandScore==0) {            
			acesHigh=true;    
		    clearGroups();
            workingHandScore=addCardValues(0, acesHigh);
        }
		clearGroups();
		return (workingHandScore);
    }
    
    /*
	* Sort work cards in preparation for group analysis and scoring.
	*/
    function groupWorkCards(bool byValue) private {
        for (uint count=0; count<5; count++) {
            if (byValue == false) {
                cardGroups[workCards[count].suit].push(Card(workCards[count].index, workCards[count].suit, workCards[count].value));
            } 
            else {
                cardGroups[workCards[count].value].push(Card(workCards[count].index, workCards[count].suit, workCards[count].value));
            }
        }
        uint8 maxValue = 15;
        if (byValue == false) {
            maxValue = 4;
        }
        uint pushedCards=0;
        for (count=0; count<maxValue; count++) {
           for (uint8 count2=0; count2<cardGroups[count].length; count2++) {
               sortedGroup.push(Card(cardGroups[count][count2].index, cardGroups[count][count2].suit, cardGroups[count][count2].value));
               pushedCards++;
           }
           if (sortedGroup.length>0) {
             sortedGroups.push(sortedGroup);
			 sortedGroup.length=0;
           }
        }
    }
    
    /**
     * Clear data found in sortedGroup, cardGroups, and sortedGroups.
     */
    function clearGroups() private {
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
	function sortWorkCards(bool acesHigh) private {
        uint256 workValue;
		Card[5] memory swapCards;
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
	function scoreStraights(bool acesHigh) private returns (uint256) {
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
        return(addCardValues(returnScore, acesHigh));
    }    
    
    /*
	* Returns a group score based on the current 5-card permutation, if either suit or face value groups exist.
	*/
    function scoreGroups(bool valueGroups, bool acesHigh) private returns (uint256) {
        if (valueGroups) {
            //cards grouped by value
            if (checkGroupExists(4)) {
                //four of a kind
                acesHigh=true;
                return (addCardValues(700000000, acesHigh));
            } 
            else if (checkGroupExists(3) && checkGroupExists(2)) {
                //full house
                acesHigh=true;
                return (addCardValues(600000000, acesHigh));
            }  
            else if (checkGroupExists(3) && checkGroupExists(1)) {
                //three of a kind
                acesHigh=true;
                return (addCardValues(300000000, acesHigh));
            } 
            else if (checkGroupExists(2)){
                uint8 groupCount=0;
                for (uint8 count=0; count<sortedGroups.length; count++) {
                    if (sortedGroups[count].length == 2) {
                        groupCount++;
                    }
                }
                acesHigh=true;
                if (groupCount > 1)  {
                    //two pair
                   return (addCardValues(200000000, acesHigh));
                } else {
                    //one pair
                    return (addCardValues(100000000, acesHigh));
                }
            }
        } else {
            //cards grouped by suit
            if (sortedGroups[0].length==5) {
                //flush
                acesHigh=true;
                return (addCardValues(500000000, acesHigh));
            }
        }
        return (0);
    }
    
	/*
	* Returns true if a group exists that has a specified number of members (cards) in it.
	*/
    function checkGroupExists(uint8 memberCount) private returns (bool) {
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
	function addCardValues(uint256 startingValue, bool acesHigh) private returns (uint256) {
        uint256 groupLength=0;
        uint256 workValue;
        uint256 highestValue = 0;
        uint256 highestGroupValue = 0;
        uint256 longestGroup = 0;
        uint8 count=0;
        if (sortedGroups.length > 1) {
            for (count=0; count<sortedGroups.length; count++) {
                groupLength=getSortedGroupLength32(count);
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
        } else {
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
    function getSortedGroupLength32(uint8 index) private returns (uint32) {
        uint32 returnVal;
         for (uint8 count=0; count<sortedGroups[index].length; count++) {
             returnVal++;
         }
         return (returnVal);
    }  
}


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
    address[] public authorizedGameContracts; //the "PokerHand*" contracts exclusively authorized to make changes in this contract's data. This value may only be changed when initReady is ready.
	uint public numAuthorizedContracts; //set when authorizedGameContracts is set
    address[] public players; //players, in order of play, who must agree to contract before game play may begin; the last player is the dealer, player 1 (index 0) is small blind, player 2 (index 2) is the big blind
    uint256 public buyIn; //buy-in value, in wei, required in order to agree to the contract    
    mapping (address => bool) public agreed; //true for all players who agreed to this contract; only players in "players" struct may agree
	uint256 public prime; //shared prime modulus
    uint256 public baseCard; //base or first plaintext card in the deck (all subsequent cards are quadratic residues modulo prime)
    mapping (address => uint256) public playerBets; //stores cumulative bets per betting round (reset before next)    
	mapping (address => uint256) public playerChips; //the players' chips, wallets, or purses on which players draw on to make bets, currently equivalent to the wei value sent to the contract.
	mapping (address => uint256) public playerPhases; //current game phase per player
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
    bool public reusable; //should contract be re-used?
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
     */
    mapping (address => uint8) public phases;

  	function PokerHandData() {
  	    reusable = true; //default
		owner = msg.sender;
		complete = true;
		initReady = true; //ready for initialize
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
		if (msg.value != buyIn) {
		    throw;
		}
		//include additional validation deposit calculations here if desired
		playerChips[msg.sender] = msg.value;
		agreed[msg.sender]=true;
        playerPhases[msg.sender]=1;
		playerBets[msg.sender] = 0;
		playerHasBet[msg.sender] = false;
		validationIndex[msg.sender] = 0;
		nonces[msg.sender] = nonce;
		/*
        uint agreedNum;
        for (count=0; count<players.length; count++) {
            if (agreed[players[count]]) {
                agreedNum++;
            }
        }
        if (agreedNum == players.length) {
            lastActionBlock = block.number;
        }
		*/
    }
	
	/**
	* Anonymous fallback function.
	*/
	function () {
        throw;		
    }
	
	/**
	* Modifier for functions to allow access only by addresses contained in the "authorizedGameContracts" array.
	*/
	modifier onlyPokerHand {
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
	function initialize(uint256 primeVal, uint256 baseCardVal, uint256 buyInVal, uint timeoutBlocksVal) public onlyPokerHand {	   	
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
	
	//Public utility functions
    
    function num_Players() public constant returns (uint) {
	     return (players.length);
	 }
	 
	 function num_Keys(address target) public constant returns (uint) {
	     return (playerKeys[target].length);
	 }
	 
	 function num_PlayerCards(address target) public constant returns (uint) {
	     return (playerCards[target].length);
	 }
	 
	 function num_PrivateCards(address targetAddr) public constant returns (uint) {
	     return (DataUtils.arrayLength2(privateCards[targetAddr]));
	 }
	 
	 function num_PublicCards() public constant returns (uint) {
	     return (publicCards.length);
	 }	 
	 
	 function num_PrivateDecryptCards(address sourceAddr, address targetAddr) public constant returns (uint) {
        for (uint8 count=0; count < privateDecryptCards.length; count++) {
            if ((privateDecryptCards[count].sourceAddr == sourceAddr) && (privateDecryptCards[count].targetAddr == targetAddr)) {
                return (privateDecryptCards[count].cards.length);
            }
        }
        return (0);
	 }
	 
	 function num_winner() public constant returns (uint) {
	     return (winner.length);
	 }
	 
	 /**
     * Owner / Administrator utility functions.
     */
	 function set_reusable (bool reusableSet) public {
	    if (msg.sender != address(owner)) {
            throw;
        }
	    reusable = reusableSet;
	 }
	 
	 function setAuthorizedGameContracts (address[] contractAddresses) public {
	     if ((initReady == false) || (complete == false)) {
	         throw;
	     }
	     authorizedGameContracts=contractAddresses;
		 numAuthorizedContracts = authorizedGameContracts.length;
	 }
	 
	 /**
	 * Attached PokerHand utility functions.
	 */	
	 
	function add_playerCard(address playerAddress, uint index, uint suit, uint value) public onlyPokerHand{         
        playerCards[playerAddress].push(Card(index, suit, value));
    }
    
    function update_playerCard(address playerAddress, uint cardIndex, uint index, uint suit, uint value) public onlyPokerHand {
        playerCards[playerAddress][cardIndex].index = index;
        playerCards[playerAddress][cardIndex].suit = suit;
        playerCards[playerAddress][cardIndex].value = value;
    }
     
    function set_validationIndex(address playerAddress, uint index) public onlyPokerHand {
		if (index == 0) {
		} else {	
			validationIndex[playerAddress] = index;
		}
    }
	
	function set_result(address playerAddress, uint256 result) public onlyPokerHand {
		if (result == 0) {
			 delete results[playerAddress];
		} else {
			results[playerAddress] = result;
		}
    }
	 
	 function set_complete (bool completeSet) public onlyPokerHand {
		complete = completeSet;
	 }
	 
	 function set_publicCard (uint256 card, uint index) public onlyPokerHand {		
		publicCards[index] = card;
	 }
	 
	 /**
	 * Adds newly encrypted cards for an address or clears out the "encryptedDeck" data for the address. 
	 * Caller must be the same address as "attachedPokerHand".
	 */
	 function set_encryptedDeck (address fromAddr, uint256[] cards) public onlyPokerHand {
	     if (cards.length == 0) {
         	for (uint count2=0; count2<52; count2++) {
	        	delete encryptedDeck[fromAddr][count2];
        	}
        	delete encryptedDeck[fromAddr];
	    } else {
		    for (uint8 count=0; count < cards.length; count++) {
                encryptedDeck[fromAddr][DataUtils.arrayLength52(encryptedDeck[fromAddr])] = cards[count];             
            }
	    }
	 }
	 
	 /**
	 * Adds a private card selection for an address. Caller must be the same address as "attachedPokerHand".
	 */
	 function set_privateCards (address fromAddr, uint256[] cards) public onlyPokerHand {	
		 if (cards.length == 0) {
			for (uint8 count=0; count<52; count++) {				
				delete privateCards[fromAddr][count];
				delete playerCards[fromAddr][count];
			}
			delete privateCards[fromAddr];			
		 } else {
			for (count=0; count<cards.length; count++) {
				privateCards[fromAddr][DataUtils.arrayLength2(privateCards[fromAddr])] = cards[count];             
			} 
		 }
	 }
	 
	 /**
	 * Sets the betting position as an offset within the players array (i.e. current bet position is players[betPosition])
	 */
	 function set_betPosition (uint betPositionVal) public onlyPokerHand {		
        betPosition = betPositionVal;
	 }
	 
	 /**
	 * Sets the bigBlindHasBet flag indicating that at least one complete round of betting has completed.
	 */
	 function set_bigBlindHasBet (bool bigBlindHasBetVal) public onlyPokerHand {
        bigBlindHasBet = bigBlindHasBetVal;
	 }
	 
	 /**
	 * Sets the playerHasBet flag indicating that the player has bet during this round of betting.
	 */
	 function set_playerHasBet (address fromAddr, bool hasBet) public onlyPokerHand {		
        playerHasBet[fromAddr] = hasBet;
	 }
	 
	 /**
	 * Sets the bet value for a player.
	 */
	 function set_playerBets (address fromAddr, uint betVal) public onlyPokerHand {		
        playerBets[fromAddr] = betVal;
	 }
	 
	 /**
	 * Sets the chips value for a player.
	 */
	 function set_playerChips (address fromAddr, uint numChips) public onlyPokerHand {		
        playerChips[fromAddr] = numChips;
	 }
	 
	 /**
	 * Sets the pot value.
	 */
	 function set_pot (uint potVal) public onlyPokerHand {		
        pot = potVal;
	 }
	 
	 /**
	 * Sets the "agreed" value of a player.
	 */
	 function set_agreed (address fromAddr, bool agreedVal) public onlyPokerHand {		
        agreed[fromAddr] = agreedVal;
	 }
	 
	 /**
	 * Adds a winning player's address to the end of the internal "winner" array.
	 */
	 function add_winner (address winnerAddress) public onlyPokerHand {		
        winner.push(winnerAddress);
	 }
	 
	 /**
	 * Adds winning player's addresses.
	 */
	 function clear_winner () public onlyPokerHand {		
        winner.length=0;
	 }
	 
	 /**
	 * Resets the internal "players" array with the addresses supplied.
	 */
	 function new_players (address[] newPlayers) public onlyPokerHand {
        players = newPlayers;
	 }
	 
	 /**
	 * Sets the game phase for a specific address. Caller must be the same address as "attachedPokerHand".
	 */
	 function set_phase (address fromAddr, uint8 phaseNum) public onlyPokerHand {		
        phases[fromAddr] = phaseNum;
	 }
	 
	 /**
	 * Sets the last action block time for this contract. Caller must be the same address as "attachedPokerHand".
	 */
	 function set_lastActionBlock(uint blockNum) public onlyPokerHand {		
		lastActionBlock = blockNum;
	 }
	 
	function set_privateDecryptCards (address fromAddr, uint256[] cards, address targetAddr) public onlyPokerHand {			
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
	 
	function set_publicCards (address fromAddr, uint256[] cards) public onlyPokerHand {
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
	 * @param cards The partially decrypted card values to store. Three cards must be stored at phase 6, one card at phase 9, and one card
	 * at phase 12.
	 */
	 function set_publicDecryptCards (address fromAddr, uint256[] cards) public onlyPokerHand {
		if (cards.length == 0) {
			for (uint count=0; count<5; count++) {
	            delete publicDecryptCards[fromAddr][count];
	            delete playerBestHands[fromAddr][count];
	        }
	        delete publicDecryptCards[fromAddr];
		} else {			 
			var (maxLength, playersAtMaxLength) = publicDecryptCardsInfo();
			//adjust maxLength value to use as index
			if ((playersAtMaxLength < (players.length - 1)) && (maxLength > 0)) {
				maxLength--;
			}
			for (count=0; count < cards.length; count++) {
				publicDecryptCards[fromAddr][maxLength] = cards[count];
				maxLength++;
			}
		}
	 }	 
	 
	 /**
	 * Sets the internal "declaredWinner" address for a sender.
	 */
	 function add_declaredWinner(address fromAddr, address winnerAddr) public onlyPokerHand {
		if (winnerAddr == 0) {
		} else {
			declaredWinner[fromAddr] = winnerAddr;
		}
	 }
	 
	 /**
     * Returns the index / position of the privateDecryptCards struct for a specific source and target address
     * combination. If the combination doesn't exist it is created and the index of the new element is
     * returned. Caller must be the same address as "attachedPokerHand".
     * 
     * @param sourceAddr The address of the source or sending player.
     * @param targetAddr The address of the target player to whom the associated partially decrypted cards belong.
     * 
     * @return The index of the element within the privateDecryptCards array that matched the source and target addresses.
     * The element may be new if no matching element can be found.
     */
    function privateDecryptCardsIndex (address sourceAddr, address targetAddr) public onlyPokerHand returns (uint) {      
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
	
	function set_playerBestHands(address fromAddr, uint cardIndex, uint256 card) public onlyPokerHand {		
		playerBestHands[fromAddr][cardIndex] = card;
	}
	
	function add_playerKeys(address fromAddr, uint256[] encKeys, uint256[] decKeys) public onlyPokerHand {		
		//caller guarantees that the number of encryption keys matches number decryption keys
		for (uint count=0; count<encKeys.length; count++) {
			playerKeys[fromAddr].push(Key(encKeys[count], decKeys[count], prime));
		}
	}
	
	function remove_playerKeys(address fromAddr) public onlyPokerHand {		
		 delete playerKeys[fromAddr];
	}
	
	function set_challenger(address challengerAddr) public onlyPokerHand {		
		challenger = challengerAddr;
	}
	
	function pay (address toAddr, uint amount) public onlyPokerHand returns (bool) {	
		if (toAddr.send(amount)) {
			return (true);
		} 
		return (false);
	}
		
	
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
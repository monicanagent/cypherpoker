pragma solidity ^0.4.5;
/**
* 
* Provides validation services for a PokerHandBI-style contract.
* 
* (C)opyright 2016 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*
*/
contract PokerHandBIValidator {
	
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
    PokerHandBI public pokerHandContract; //the last PokerHandBI-style contract to invoke the validator, set to the address 1 after each round of validation

	//Following values are used during hand analysis:
    Card[5] public workCards; 
    Card[] public sortedGroup;
    Card[][] public sortedGroups;
    Card[][15] public cardGroups;
    
     
    
    function PokerHandBIValidator () {
        owner = msg.sender;
    }
    
    /**
     * Performs one round of mid-game challenge validation. The contract address being validated is evaluated from msg.sender
     * 
     * @param challenger The address of the challenging player.
     * 
     * @return True if the current challenge verification step was successfully completed and the source contract's validation index has
     * been updated.
     * 
     */
    function challenge (address challenger) public returns (bool) {
        //TODO: implement challenge verification
        pokerHandContract = PokerHandBI(msg.sender);
        lastSender = challenger;
        uint256 challengeValue=pokerHandContract.playerBestHands(lastSender, 0);
        //use pokerHandContract.playerCards(lastSender, 0) to store decrypted card
        //reset values to prevent external invocations from non-contracts
        pokerHandContract=PokerHandBI(1);
        lastSender=1;
    }
    
    /**
     * Performs one round of validation on a target contract. The contract address being validated is evaluated from msg.sender
     * 
     * @param msgSender The address of the sending/invoking player.
     * 
     * @return True if the current validation step was successfully completed and the source contract's validation index has
     * been updated.
     * 
     */
    function validate(address msgSender) public returns (bool) {
       pokerHandContract = PokerHandBI(msg.sender);
       lastSender = msgSender;
       uint validationIndex=pokerHandContract.validationIndex(lastSender);
       if (validationIndex < 5) {
           decryptCard(lastSender, pokerHandContract.playerBestHands(lastSender, validationIndex));
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
           pokerHandContract=PokerHandBI(1);
           //no further validations possible
           throw;
       }
       validationIndex++;
       pokerHandContract.set_validationIndex(lastSender, validationIndex);
       pokerHandContract=PokerHandBI(1);
       lastSender=1;
       return (true);
    }
    
    /**
     * Decrypts a card for a target player address and stores the result in the originating PokerHandBI contract's "playerCard" variable
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
           selectedCard=pokerHandContract.privateCards(target, cardIndex);
       } else {
           //decrypt public card
           selectedCard=pokerHandContract.publicCards(cardIndex-2);
       }
       address currentPlayer;
       for (uint count=0; count < pokerHandContract.num_Players(); count++) {
           currentPlayer = pokerHandContract.players(count);
           for (uint keyIndex=0; keyIndex<pokerHandContract.num_Keys(currentPlayer); keyIndex++) {
               var (encKey, decKey, mod) = pokerHandContract.playerKeys(currentPlayer, keyIndex);
               selectedCard = modExp(selectedCard, decKey, mod);
            }
           // if (checkDecryptedCard(currentPlayer, selectedCard) == false) {
                //currentPlayer did not store correct decryption for player!
                //ensure we're not checking fully decrypted card here
          //  }
       }
       pokerHandContract.add_playerCard(lastSender, selectedCard, 0, 0);
    }
    
    /**
     * Validates a card for a target player by calculating its quadratic residue index as an offset from the base card of the
     * originating PokerHandBI contract. If validated the resulting card is stored an [index, suit, value] tupple in the originating
     * PokerHandBI contract for the target playe, in the "playerCard" variable, via the "update_playerCard" function.
     * 
     * @param target The address of the player for which to validate the card.
     * @param cardIndex The index of the card within the originating contract's playerCards array to validate. If validated this same
     * index is updated with the validated tuple.
     */
    function validateCard(address target, uint cardIndex) private {
        var (index, suit, value) = pokerHandContract.playerCards(target, cardIndex);
        index=getCardIndex(index, pokerHandContract.baseCard(), pokerHandContract.prime());
        if ((index > 0) && (index < 53)) {
             pokerHandContract.update_playerCard(target, cardIndex, index, (((index-1) / 13) + 1), (((index-1) % 13) + 1));
        }
    }
    
    /**
     * Recalls the target player's best cards, which should now be decrypted and validated, and submits them for analysis
     * to produce a hand score that may be used in ranking players' results. The resulting score is set in the originating PokerHandBI
     * contracts "result" mapping via the "set_result" function.
     * 
     * * See "calculateHandScore" for resulting poker hand score ranges.
     * 
     * @param target The target player for which to generate a score and store the result.
     * 
     */
    function generateScore(address target) private {
        for (uint count=0; count<pokerHandContract.num_PlayerCards(target); count++) {
             var (index, suit, value) = pokerHandContract.playerCards(target, count);
             workCards[count] = Card(index, suit, value);
        }
        pokerHandContract.set_result(target, calculateHandScore());
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
        for (uint count=0; count<pokerHandContract.num_Players(); count++) {
            currentPlayer = pokerHandContract.players(count);
            if (currentPlayer != sender) {
                for (uint cardIndex=0; cardIndex < pokerHandContract.num_PrivateDecryptCards(currentPlayer,sender); cardIndex++) {
                    if (pokerHandContract.getPrivateDecryptCard(currentPlayer, sender, cardIndex) == cardValue) {
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


contract PokerHandBI { 
    //include only data and functions that are accessed by the validator
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
    PokerHandBIValidator public validator; //known and trusted contract to perform valildations on the current contract
    mapping (address => bool) public agreed; //true for all players who agreed to this contract; only players in "players" struct may agree
	uint256 public prime; //shared prime modulus
    uint256 public baseCard; //base or first plaintext card in the deck (all subsequent cards are quadratic residues modulo prime)
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
    mapping (address => uint[5]) public playerBestHands; 
    mapping (address => Card[]) public playerCards; //final decrypted cards for players (as generated from playerBestHands)
    mapping (address => uint256) public results; //hand ranks per player or numeric score representing actions (1=fold lost, 2=fold win, 3=concede loss, 4=concede win)    
    mapping (address => uint) public validationIndex;
    function getPrivateDecryptCard(address sourceAddr, address targetAddr, uint cardIndex) constant public returns (uint256) {}
    function privateDecryptCardsIndex (address sourceAddr, address targetAddr) private returns (uint) {}
    function add_playerCard(address playerAddress, uint index, uint suit, uint value) public {}
    function update_playerCard(address playerAddress, uint cardIndex, uint index, uint suit, uint value) public {}
    function set_validationIndex(address playerAddress, uint index) public {}
    function set_result(address playerAddress, uint256 result) public {}
    function num_Players() public returns (uint) {}
	function num_Keys(address target) public returns (uint) {}
	function num_PlayerCards(address target) public returns (uint) {}
	function num_PrivateCards(address targetAddr) public returns (uint) {}
	function num_PublicCards() public returns (uint) {}
	function num_PrivateDecryptCards(address sourceAddr, address targetAddr)  public returns (uint) {}
}

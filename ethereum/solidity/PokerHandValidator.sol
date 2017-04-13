pragma solidity ^0.4.5;
/**
* 
* Provides validation functionality such as hand decryption, scoring, and ranking for an authorizing PokerHandData contract.
* 
* (C)opyright 2016 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*
*/
contract PokerHandValidator {
	
	//Single card definition including card's sorting index within the entire deck (1-52), suit value (0 to 3), and value (1 to 13 or 14 if aces are high)
	struct Card {
        uint index;
        uint suit; 
        uint value;
    }
	
	//Encryption / decryption key definition including the encryption key, decryption key, and prime modulus.
	struct Key {
        uint256 encKey;
        uint256 decKey;
        uint256 prime;
    }

    address public owner; //the contract's owner / publisher
    address public lastSender; //address of last player to invoke a validation function, set to 1 after each round of validation
    PokerHandData public pokerHandData; //the last PokerHandData-style contract to invoke the validator, set to the address 1 after each round of validation

	//Arrays used during hand analysis (may be safely cleared afterward):
    Card[5] public workCards; 
    Card[] public sortedGroup;
    Card[][] public sortedGroups;
    Card[][15] public cardGroups;
    
     
    /**
	* Contract constructor.
	*/
    function PokerHandValidator () {
        owner = msg.sender;
    }
	
	/**
	* Anonymous fallback function.
	*/
	function () {
        throw;		
    }
    
	/**
	* Function modifier that allows only authorized accounts (e.g. contracts) to invoke functions.
	*/
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
			/*
            if (checkDecryptedCard(currentPlayer, selectedCard) == false) {
                //currentPlayer did not store correct decryption for player!
                //ensure we're not checking fully decrypted card here
            }
			*/
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
	*
	* @param base The base value for the modular exponentiation calculation.
	* @param exp The exponent value for the modular exponentiation calculation.
	* @param mod The modulus value for the modular exponentiation calculation.
	*
	* @return The result of the calculation (base^exp) % mod
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
	* Group cards in the 'workCards' array. Card groups are stored in the 'sortedGroups' array in which each element 
	* holds a group of cards.
	*
	* @param byValue If true work cards are grouped by (face) value otherwise they're grouped by suit.
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
     * Clear data found in 'sortedGroup', 'cardGroups', and 'sortedGroups'.
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
	* Sort cards in the 'workCards' array by (face) value.
	*
	* @param acesHigh If true aces are ranked higher than kings otherwise aces are the lowest ranked cards.
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
	* Returns a score based on a straight in the current 5-card permutation stored in 'workCards'.
	*
	* @param acesHigh If true aces are ranked higher than kings otherwise they're ranked as the lowest card.
	*
	* @return A score representing the type of straight found in the 'workCards' array. If no straight is found 0 is returned.
	* A value between 400000000 and 499999999 is returned if a normal straight is found, and 800000000 to 899999999 is 
	* returned if a straight flush is found.
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
	* Returns a group score based on the current 5-card permutation, if either suit or face value groups exist in 'workCards'.
	*
	* @param valueGroups If true the score generated is based on the (face) values of the cards otherwise the score is generated
	* from suit groups.
	* @param acesHigh If true aces are ranked higher than kings otherwise they're ranked as the lowest cards.
	*
	* @return The highest score found in cards in the 'workCards' array based on the type of evaluation being done. Values
	* between 5 and 799999999 may be generated with the exception of straight scores (400000000 to 499999999, 800000000 to 899999999), which
	* are generated by the 'scoreStraights' function.
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
	*
	* @param memberCount The expected number of members or cards expected in the 'sortedGroups' array.
	*
	* @return True if 'memberCount' card/member groups exist in the 'sortedGroups' array, false otherwise.
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
	* Adds individual card values to a hand score. This is typically applied after base group or straight scoring has been calculated.
	* 
	* @param startingValue The starting or base hand score to which to add individual card values.
	* @param acesHigh If true aces are scored as ranking higher than kings otherwise they're the lowest ranking cards.
	*
	* @return The calculated hand value incorporating the base 'startingValue' and individual card (face) values.	
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
    * Returns the group length of a specific sorted group in the 'sortedGroups' array as a uint32 value.
	*
	* @param index The index (0-based) of the group in the 'sortedGroups' array to get a length for.
	*
	* @return The length of the group 'sortedGroups[index]' as a uint32 value (normally the 'length' property is
	* returned as a uint256 value).
    */
    function getSortedGroupLength32(uint8 index) private returns (uint32) {
        uint32 returnVal;
         for (uint8 count=0; count<sortedGroups[index].length; count++) {
             returnVal++;
         }
         return (returnVal);
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
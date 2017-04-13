pragma solidity ^0.4.5;
/**
* 
* Manages hand / game resolutions for an authorizing PokerHandData contract when in full-cost or "full contract" mode.
* 
* (C)opyright 2016 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
contract PokerHandResolutions { 
    
    address public owner; //the contract's owner / publisher
   
  	/**
	* Contract constructor.
	*/
	function PokerHandResolutions() {
		owner = msg.sender;
    }
	
	/**
	* Anonymous fallback function.
	*/
	function () {
		throw;
    }
	
	/**
	* Sets a declared a winner/winners within a poker hand data contract. If all agreed players have submitted the same declared
	* winner/winners then the 'payout' function is invoked.
	*
	* @param dataAddr The address of the poker hand data contract for which this contract has been authorized.
	* @param winnerAddr The address(es) of the declared winner(s).
	*
	*/
	function declareWinner(address dataAddr, address winnerAddr) public {
		PokerHandData dataStorage = PokerHandData(dataAddr);
		if (dataStorage.agreed(msg.sender)) {			
			 dataStorage.add_declaredWinner(msg.sender, winnerAddr);
		}		
		uint resolutions = 0;
		for (uint count = 0; count<dataStorage.num_Players(); count++) {
			if (dataStorage.declaredWinner(dataStorage.players(count)) == winnerAddr) {
				resolutions++;
			}
		}
		if (resolutions == dataStorage.num_Players()) {
			//everyone has declared the same winner
			dataStorage.add_winner(winnerAddr);
			payout(dataAddr);
			return;
		}
	}
	
	/**
     * Resolves the winner using the most current resolution state or via a declaration. If players are at phase 16 (Level 2 validation) the hand is
	 * first checked for a timeout. If the hand has timed out then the players' validation indexes are compared; the player with the
	 * highest index is awarded all of the other player's chips and declared the winner. If more than one player has the highest
	 * validation index then their results are compared and the player with the highest score is declared the winner. Any players
	 * who have not completed their L2 validation will lose all of their chips which will be split evenly among the fully-validated 
	 * players. In the rare event of a tie, no winner is declared and the fully-validated players split the pot evenly.
	 *
	 * If a winner is declared by a valid player their address is stored in the resolvedWinner array. If all players agree on the same winner
	 * the game is considered uncontested and the contract pays out immediately using current pot/playerChips values. Player's phases are not
	 * checked if the verifiedWinner parameter is supplied.
	 *
	 * @param dataAddr The address of the poker hand data contract for which this contract has been authorized.
     */
    function resolveWinner(address dataAddr) public {
		PokerHandData dataStorage = PokerHandData(dataAddr);
		/*
		if (dataStorage.agreed(msg.sender)) {
			address verifiedWinner = dataStorage.declaredWinner(dataStorage.players(0));
			uint resolutions = 0;
			for (uint count = 1; count<dataStorage.num_Players(); count++) {
				if (dataStorage.declaredWinner(dataStorage.players(count)) == verifiedWinner) {
					resolutions++;
				}
			}
			if (resolutions == dataStorage.num_Players()) {
				//everyone has declared the same winner
				dataStorage.add_winner(verifiedWinner);
				payout(dataAddr);
				return;
			}
		}
		*/
        if (hasTimedOut(dataAddr) == false) {
			throw;
		}
        if (dataStorage.allPlayersAtPhase(15) || dataStorage.allPlayersAtPhase(16)){				
            //Level 1 validation or unchallenged
			address verifiedWinner = 0;
			uint resolutions=0;
			for (uint count = 1; count<dataStorage.num_Players(); count++) {
				if (dataStorage.declaredWinner(dataStorage.players(count)) == verifiedWinner) {
					resolutions++;					
				} else {
					if (verifiedWinner == 0) {
						resolutions++;
						verifiedWinner = dataStorage.declaredWinner(dataStorage.players(count));
					}
				}
			}
			if (verifiedWinner == 0) {
				//no winnder declared!
				throw;
			}
			if (resolutions != dataStorage.num_Players()) {
				//not all players agree on declared player so start Level 2 validation
				for (count=0; count < dataStorage.num_Players(); count++) {
					dataStorage.set_phase(dataStorage.players(count), 17);
				}
			} else {	
				dataStorage.add_winner(verifiedWinner);
			}
		} else if (dataStorage.allPlayersAtPhase(17) || dataStorage.allPlayersAtPhase(19)) {
			//Level 2 validation or challenge
			uint highest=0;
			uint highestPlayers = 0;
			for (count=0; count<dataStorage.num_Players(); count++) {
			    if (dataStorage.validationIndex(dataStorage.players(count)) > highest) {
			        highest = dataStorage.validationIndex(dataStorage.players(count));
			        highestPlayers=0;
			    }
			    if (dataStorage.validationIndex(dataStorage.players(count)) == highest) {
			        highestPlayers++;
			    }
			}
			if (highestPlayers > 2) {
			    //compare results
			    for (count=0; count<dataStorage.num_Players(); count++) {
			        if (dataStorage.results(dataStorage.players(count)) > highest) {
			            highest=dataStorage.results(dataStorage.players(count));
			        }
			    }
			    for (count=0; count<dataStorage.num_Players(); count++) {
			         if (dataStorage.results(dataStorage.players(count)) == highest) {
			             dataStorage.add_winner(dataStorage.players(count)); //may be more than one winner
			         }
			    }
			} else {
			    //
			    for (count=0; count<dataStorage.num_Players(); count++) {
			        if (dataStorage.validationIndex(dataStorage.players(count)) == highest) {
			            dataStorage.add_winner(dataStorage.players(count));
			        }
			    }
			}
			//TODO: implement validation fund refunds (add values to playerChips prior to payout)
		    //Note deposit is: 600000000000000000
		}
    }
    
     /**
	 * Checks whether a specific poker hand data contract has timed out.
	 *
	 * @param dataAddr The addres of the poker hand data contract to check. The target contract does not need to include
	 * this contract as an authorized contract since this is a public read-only operation.
	 *
     * @return True if the hand/contract has timed out. A time out occurs when the current
     * block number is higher than or equal to lastActionBlock + timeoutBlocks. If lastActionBlock 
	 * or timeoutBlocks is 0, false will always be returned
     */
    function hasTimedOut(address dataAddr) public constant returns (bool) {
		PokerHandData dataStorage = PokerHandData(dataAddr);
        if ((dataStorage.lastActionBlock()==0) || (dataStorage.timeoutBlocks() == 0)) {
            return (false);
        }
         if ((dataStorage.lastActionBlock() + dataStorage.timeoutBlocks()) <= block.number) {
            return (true);
        } else {
            return (false);
        }
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
	 * @param dataAddr The address of the poker hand data contract for which this contract has been authorized.
	 * @param validatorAddr The address of a PokerHandValidator contract for which the poker hand data contract has been authorized.
	 * @param encKeys The encryption keys being submitted by the sending player to use during validation. These are stored in the poker hand
	 * data contract.
	 * @param decKeys The decryption keys being submitted by the sending player to use during validation. These are stored in the poker hand
	 * data contract.
     * @param challengeValue A stored card value being challenged. (???)
     */
    function challenge (address dataAddr, address validatorAddr, uint256[] encKeys, uint256[] decKeys, uint256 challengeValue) payable public {
		PokerHandData dataStorage = PokerHandData(dataAddr);
        if (dataStorage.agreed(msg.sender) == false) {
            throw;
        }
        if (dataStorage.phases(msg.sender) != 19) {
             //do we need to segregate these funds?
            if (msg.value != (600000000000000000*(dataStorage.num_Players()-1))) {
                throw;
            }
            if (dataStorage.challenger() < 2) {
                //set just once
				dataStorage.set_challenger(msg.sender);
                dataStorage.set_playerBestHands(msg.sender, 0, challengeValue); //as reference by the validator
            }
            if ((encKeys.length==0) || (decKeys.length==0)) {
                throw;
            }
            if (encKeys.length != decKeys.length) {
                throw;
            }
			dataStorage.add_playerKeys(msg.sender, encKeys, decKeys);
            dataStorage.set_phase(msg.sender, 19);
        }
        PokerHandValidator validator = PokerHandValidator(validatorAddr);
        validator.challenge.gas(msg.gas-30000)(dataAddr, dataStorage.challenger());
        dataStorage.set_lastActionBlock (block.number);
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
    function L1Validate(address dataAddr, uint256[] encKeys, uint256[] decKeys, uint[] bestCards) public {
		PokerHandData dataStorage = PokerHandData(dataAddr);
        if (dataStorage.phases(msg.sender) != 15) {
            throw;
        }
        if (dataStorage.num_winner() != 0) {
            throw;
        }
        if ((encKeys.length==0) || (decKeys.length==0)) {
            throw;
        }
        if (encKeys.length != decKeys.length) {
            throw;
        }
		dataStorage.add_playerKeys(msg.sender, encKeys, decKeys);
        if (bestCards.length == 5) {
            uint currentIndex=0;
            //check for uniqueness
            for (uint count=0; count < 5; count++) {
                currentIndex = bestCards[count];
                for (uint count2=0; count2 < 5; count2++) {
                    if ((count!=count2) && (currentIndex==bestCards[count2])) {
                        //duplicate index
                        throw;
                    }
                }
            }
            for (count=0; count < 5; count++) {
                dataStorage.set_playerBestHands(msg.sender, count, bestCards[count]);
            }
            dataStorage.set_phase(msg.sender, 16);
        }
        dataStorage.set_lastActionBlock(block.number);
    }
    
    /**
     * Performs one round of Level 2 validation. The first time that L2Validate is invoked it must be provided with sufficient challenge funds
     * to cover all other players. This is equal to 0.6 Ether (600000000000000000) per player, excluding self. In other words, if there are only
     * 2 players then 0.6 Ether must be included but if there are 3 players then 1.2 Ether must be included.
	 *
	 * @param dataAddr The address of the poker hand data contract for which this contract is authorized.
	 * @param validatorAddr The address of a PokerHandValidator contract for which the poker hand data contract has been authorized.
     */
    function L2Validate(address dataAddr, address validatorAddr) payable public {       
		PokerHandData dataStorage = PokerHandData(dataAddr);
        if (dataStorage.allPlayersAtPhase(16) == false) {
            throw;
        }
        if (dataStorage.phases(msg.sender)==16) {
            //do we need to segregate these funds?
            if (msg.value != (600000000000000000*(dataStorage.num_Players()-1))) {
                throw;
            }
            dataStorage.set_phase(msg.sender, 17);
        }
        if (dataStorage.challenger() < 2) {
            dataStorage.set_challenger (msg.sender);
        }
		PokerHandValidator validator = PokerHandValidator(validatorAddr);
        validator.validate.gas(msg.gas-30000)(dataAddr, msg.sender); 
		dataStorage.set_lastActionBlock (block.number);
    } 

    /**
     * Pays out the contract's value by sending the pot + winner's remaining chips to the winner and sending the othe player's remaining chips
     * to them. When all amounts have been paid out, "pot" and all "playerChips" are set to 0 as is the "winner" address. All players'
     * phases are set to 18 and the reset function is invoked.
     * 
     * The "winner" address must be set prior to invoking this call.
	 *
	 * @param dataAddr The address of the poker hand data contract for which this contract is authorized.
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
	
	/*		
	function validate(address dataAddr, address validatorAddr, address fromAddr) payable {
	    PokerHandValidator validator = PokerHandValidator(validatorAddr);
        validator.validate.gas(msg.gas-30000)(dataAddr, fromAddr);
	} 	
	*/ 
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
pragma solidity ^0.4.5;
/**
* 
* Processes light, low-cost, signed actions, transactions, and resolutions for an authorizing PokerHandData contract.
* 
* (C)opyright 2016 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
contract PokerHandSignedActions { 
    
    address public owner; //the contract's owner / publisher   
   
  	/**
	* Contract constructor.
	*/
	function PokerHandSignedActions() {
		owner = msg.sender;
    }
	
	/**
	* Anonymous fallback function.
	*/
	function () {
		throw;
    }
	
	/**
	* Ends a hand played using signed transactions by updating players' bets. Once all players have invoked this function with
	* matching parameters the bet chips are awarded to the stated winner(s) and the poker hand data contract is reset for the next hand.
	*
	* @param dataAddr The address of a poker hand data contract for which this contract is authorized.
	* @param winnerAddr The address(es) of the declared winner(s) of the hand.
	* @param players The addresses of the agreed (within the poker hand data contract) players. The order of this array must match
	* the order of the values in the 'playerBets' parameter.
	* @param playerBets The bets, in wei, committed by the players listed in the 'players' parameter. The order of bets must match
	* the order of players in the 'players' parameter.
	*/
	function endHand(address dataAddr, address[] winnerAddr, address[] players, uint256[] playerBets) public {
		PokerHandData dataStorage = PokerHandData(dataAddr);
		if (dataStorage.agreed(msg.sender) == false) {
			throw;
		}
		if (dataStorage.phases(msg.sender) > 19) {
			throw;
		}
		uint matchingWinners = 0;
		for (uint count=0; count<winnerAddr.length; count++) {
			for (uint count2=0; count2<dataStorage.num_winner(); count2++) {
				if (winnerAddr[count] == dataStorage.winner(count2)) {
					matchingWinners++;
				}
			}
			if (matchingWinners == 0) {
				dataStorage.add_winner(winnerAddr[count]);
			}
			matchingWinners=0;
		}
		for (count=0; count<players.length; count++) {
			dataStorage.set_playerBets(players[count], playerBets[count]);
		}			
		dataStorage.set_complete(true);
		dataStorage.set_phase(msg.sender, 20);
		if (dataStorage.allPlayersAtPhase(20)) {
			//TODO: make this work for more than 2 players!
			for (count=0; count<players.length; count++) {
				if (dataStorage.playerBets(players[count]) != playerBets[count]) {
					//supplied bet value doesn't match value set by other player(s); initiate challenge!
					throw;
				}
			}
			matchingWinners = 0;
			for (count=0; count<winnerAddr.length; count++) {
				for (count2=0; count2<dataStorage.num_winner(); count2++) {
					if (winnerAddr[count] == dataStorage.winner(count2)) {
						matchingWinners++;
					}
				}
			}
			if (matchingWinners != winnerAddr.length) {
				throw;
			}
			uint pot = 0;
			for (count=0; count < players.length; count++) {
				pot += playerBets[count];
				dataStorage.set_playerChips(players[count], dataStorage.playerChips(players[count]) - playerBets[count]);
			}
			for (count=0; count<winnerAddr.length; count++) {
				dataStorage.set_playerChips(winnerAddr[count], dataStorage.playerChips(winnerAddr[count])+(pot / winnerAddr.length));
			}
			for (count=0; count < players.length; count++) {
				dataStorage.set_phase(players[count], 0);
				dataStorage.set_agreed(players[count], false);
				dataStorage.set_playerBets(players[count], 0);
			}
			dataStorage.clear_winner(); //reset winners array
			address[] memory emptyAddrSet;
			dataStorage.new_players(emptyAddrSet); //reset initReady
			dataStorage.set_complete(false); //reset complete
			dataStorage.new_players(players); //re-add players			
		}
	}
	
	/**
	* Ends a poker hand data contract and pays out each player's 'playerChips' from the data contract's value. All agreed players
	* must invoke this function before a payout is carried out.
	*
	* @param dataAddr The address of a poker hand data contract for which this contract is authorized.
	*/
	function endContract(address dataAddr) public {
		PokerHandData dataStorage = PokerHandData(dataAddr);
		if ((dataStorage.complete() == true) || (dataStorage.initReady() == false)) {
			throw;
		}
		dataStorage.set_phase(msg.sender, 21);
		dataStorage.set_lastActionBlock(block.number); //set last action block in case not all players end gracefully 
		if (dataStorage.allPlayersAtPhase(21) || hasTimedOut(dataAddr)) {
			for (uint count=0; count<dataStorage.num_Players(); count++) {
				if (dataStorage.playerChips(dataStorage.players(count)) > 0) {
					dataStorage.pay(dataStorage.players(count), dataStorage.playerChips(dataStorage.players(count)));					
					dataStorage.set_playerChips(dataStorage.players(count), 0);
				}
			}
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
	* Activates the specified data contract by setting its "lastActionBlock" value to the current block.
	* Once activated the data contract expects updates within the "timeoutBlocks" time limit and is
	* subject to timeout resolutions. Typically the data contract should only be activated if signed
	* transactions between players have failed and "full contract" / full-cost mode is required.
	*
	* @param dataAddr The address of the poker hand data contract for which this contract is authorized.
	*/
	function activate(address dataAddr) public {
		PokerHandData dataStorage = PokerHandData (dataAddr);
		if (dataStorage.lastActionBlock() == 0) {
			dataStorage.set_lastActionBlock(block.number);
		}
	}
	
	/**
	* Processes a signed transaction received by the invoker from another player. Signed transactions are first
	* checked for validity (to verify which adddress they were signed with), before being processed.
	*
	* NOTE: Not yet fully implemented!
	*
	* @param dataAddr The address of the poker hand data contract for which this contract is authorized.
	* @param hash ---
	* @param v ---
	* @param r ---
	* @param s ---
	*/
	function processSignedTransaction(address dataAddr, bytes32 hash, uint8 v, bytes32 r, bytes32 s) public {
	   PokerHandData dataStorage = PokerHandData(dataAddr);
       address account = verifySignature (hash, v, r, s);
       bool found=false;
       for (uint count=0; count<dataStorage.num_Players(); count++) {
           if (dataStorage.players(count) == account) {
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
	
	/**
     * Returns the address associated with a supplied signature and input data (usually hashed value).
	 *
	 * When verifying the signature for a transaction for this contract the "data" should be a SHA3 hash of a string that combines the following:
	 * txType + txDelimiter + txValue + txDelimiter + txNonce + initBlock
     * 
     * The txType is the type of transaction being validated. Valid types include "B" (bet), "D" (fully-encrypted deck card), 
     * "d" (partially-encrypted deck card), "C" (private card selection), or "c" (partially-decrypted card selection).
	 * The txValue is the value of the associated transaction. If it's a bet value (B) this value is in wei, otherwise this is a plaintext or
	 * encrypted card value (depending on the txType).
	 * The txNonce should match the nonce registered by the player when they agreed to the contract (nonces[account] == txNonce).
	 * The initBlock value should match the "initBlock" variable set when the contract was initialized.
     * 
     * @param data The 32-byte input data that was signed by the associated signature. This is usually a
     * sha3/keccak hash of some plaintext message.
     * @param v The recovery value, calculated as the last byte of the full signature plus 27 (usually either 27 or
     * 28)
     * @param r The first 32 bytes of the signature.
     * @param s The second 32 bytes of the signature.
	 *
	 * @return The address recovered from the signed data.
     */
    function verifySignature(bytes32 data, uint8 v, bytes32 r, bytes32 s) public constant returns (address) {
        return(ecrecover(data, v, r, s));
    }
	
	 /**
     * Converts a string input to a uint256 value. It is assumed that the input string is compatible with an unsigned
     * integer type up to 2^256-1 bits.
     * 
     * @param input The string to convert to a uint256 value.
     * 
     * @return A uint256 representation of the input string.
     */
    function stringToUint256(string input) public returns (uint256 result) {
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
    function uintToBytes32(uint256 input) public returns (bytes32 result) {
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
    function bytes32ToString(bytes32 input) public returns (string) {
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
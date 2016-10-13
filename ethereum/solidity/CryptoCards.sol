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
* Game phase tracking library for CypherPoker.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
* Morden testnet address: 0xbd9ebebb7d9a6c184eaea92c50d0295539415452
*
*/
library GamePhase {
    
    /*
	* A player phase structure.
	*/
	struct Phase {
        address player;
        uint8 phaseNum;
    }
	/*
	* Phases mapped to players.
	*/
    struct PhasesMap {
        Phase[] phases;
    }
    
    /*
	* Sets the phase for a specified player (address) in a referenced contract.
	*/
	function setPlayerPhase(PhasesMap storage self, address player, uint8 phaseNum)  {
        for (uint8 count=0; count<self.phases.length; count++) {
            if (self.phases[count].player == player) {
                self.phases[count].phaseNum = phaseNum;
                return;
            }
        }
    }
    
    /*
	* Retrieves the phase value currently stored for a player in a referenced contract.
	*/
	function getPlayerPhase(PhasesMap storage self, address player) returns (uint8) {
        for (uint8 count=0; count<self.phases.length; count++) {
            if (self.phases[count].player == player) {
                return (self.phases[count].phaseNum);
            }
        }
    }
   
    /*
	* True if all players are at a specific phase in a referenced contract.
	*/
	function allPlayersAtPhase(PhasesMap storage self, uint8 phaseNum) returns (bool) {
        if (self.phases.length == 0) {
            return (false);
        }
        for (uint8 count=0; count<self.phases.length; count++) {
            if (self.phases[count].phaseNum != phaseNum) {
                return (false);
            }
        }
        return (true);
    }
   
     /*
	* True if all players are above a specific phase in a referenced contract.
	*/
	function allPlayersAbovePhase(PhasesMap storage self, uint8 phaseNum) returns (bool) {
        if (self.phases.length == 0) {
            return (false);
        }
        for (uint8 count=0; count<self.phases.length; count++) {
            if (self.phases[count].phaseNum <= phaseNum) {
                return (false);
            }
        }
        return (true);
    }    
}
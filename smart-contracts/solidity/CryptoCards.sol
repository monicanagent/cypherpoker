/**
* 
* Provides cryptographic services for CypherPoker hand contracts.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
library CryptoCards {
    
    /*
	* A standard playing card type.
	*/
	struct CardType {
        uint256 index; //plaintext or encrypted
        uint256 suit; //1-4
        uint256 value; //1-13
    }
    
    /*
	* A card deck type.
	*/
	struct CardsType {
       CardType[] cards;
    }
    
    /*
	* Used when grouping suits and values.
	*/
	struct SplitCardsType {
        uint256[] suits;
        uint256[] values;
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
	* Decrypt a group of cards using a supplied crypto keypair.
	*/
	function decryptCards (CardsType storage cardsRef, Key storage keyRef) {
        uint256 cardIndex;
        for (uint8 count=0; count<cardsRef.cards.length; count++) {
            cardIndex=(cardsRef.cards[count].index ** keyRef.decKey) % keyRef.prime;
            //cardIndex-2  <-  adjust for minimum allowable encryption value
            cardsRef.cards[count]=CardType(cardIndex, (((cardIndex-2) / 13) + 1), (((cardIndex-2) % 13) + 1));
        }
    }
    
    /**
     * Adjust indexes after final decryption if card indexes need to start at 0.
     */
    function adjustIndexes(CardType[] storage cardsRef) {
        for (uint8 count=0; count<cardsRef.length; count++) {
            cardsRef[count].index-=2;
        }
    }
   
    /*
	* Appends card from one deck to another.
	*/
	function appendCards (CardsType storage sourceRef, CardsType storage targetRef) {
        for (uint8 count=0; count<sourceRef.cards.length; count++) {
            targetRef.cards.push(sourceRef.cards[count]);
        }
    }
  
    /*
	* Splits cards from a deck into sequantial suits and values.
	*/
	function splitCardData (CardsType storage sourceRef, SplitCardsType storage targetRef) {
         for (uint8 count=0; count<sourceRef.cards.length; count++) {
             targetRef.suits.push(sourceRef.cards[count].suit);
             targetRef.values.push(sourceRef.cards[count].value);
         }
    }
}
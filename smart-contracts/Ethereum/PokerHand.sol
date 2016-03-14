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
contract PokerHand { 
    
    /*
	* Addresses of existing libraries (must be updated when switching blockchains!)
	*/
    CryptoCards cardsLib = CryptoCards(0x1e4fb2dc80eeb755ad8334f829d5010e0cab7a3d);
    GamePhase phase = GamePhase(0x07fbc852fbf6e3aea6e5436a70e641199185b602);
    PokerBetting betting = PokerBetting(0xf486bb3bcb6fa17b31eb5ca4d2571721f8096918);
    pha phaLib = pha(0x57b9d92c80bf2a52e1503bd91ccebeb93566e014);
    

    uint256 public prime = 59; //this would usually be generated outside of the contract   
    address public owner; //the contract owner
    PokerBetting.playersType players; //players who must agree to contract before game play may begin; player 1 is assumed to be dealer, player 2 is big blind, player 3 (or 1 in headsup) is small blind
    address public winner;
    mapping (address => bool) public agreed; //true for all players who agreed to this contract
    PokerBetting.betsType private playerBets; //stores cumulative bets per betting round (reset before next)
    PokerBetting.potType public pot; //total pot for game
    PokerBetting.positionType public betPos; //current betting player in players array    
    mapping (address => CryptoCards.CardsType) encryptedDecks; //incrementally encrypted decks; deck of players[players.length-1] is the final encrypted deck
    mapping (address => CryptoCards.CardsType) privateCards; //encrypted private/hole cards per player
    CryptoCards.CardsType publicCards; //encrypted public cards
    mapping (address => CryptoCards.Key) public playerKeys; //playerss crypo keypairs
    CryptoCards.SplitCardsType private analyzeCards; //face/value split cards being used for analysis    
    mapping (address => CryptoCards.CardType[]) public playerCards; //final decrypted cards for players (only generated during a challenge)
    CryptoCards.CardType[] public communityCards;  //final decrypted community cards (only generated during a challenge)
    uint256 public highestResult=0; //highest hand rank (only generated during a challenge)
    mapping (address => uint256) public results; //hand ranks per player or numeric score representing actions (1=fold lost, 2=fold win, 3=concede loss, 4=concede win)    
    
    /**
     * Phase values:
     * 0 - Agreement (not all players have agreed to contract yet)
     * 1 - Encrypted deck storage (all players have agreed to contract)
     * 2 - Private/hole card selection
     * 3 - Private/hole card decryption
     * 4 - Betting
     * 5 - Flop cards selection
     * 6 - Flop cards decryption
     * 7 - Betting
     * 8 - Turn card selection
     * 9 - Turn card decryption
     * 10 - Betting
     * 11 - River card selection
     * 12 - River card decryption
     * 13 - Betting
     * 14 - Submit keys + verify
     * 15 - Game complete
     */
    GamePhase.PhasesMap playerPhases;
    GamePhase.Phase[] public phases;
    
    
    /*
	* Constructor for contract. Must be instantiated with addresses of the required players for the hand.
	*/
	function PokerHand(address[] requiredPlayers) {
        owner=msg.sender;
        for (uint8 count=0; count<requiredPlayers.length; count++) {
            players.list.push(requiredPlayers[count]);
            playerPhases.phases.push(GamePhase.Phase(requiredPlayers[count], 0));
            //phases.push(playerPhases.phases[count]);
            playerBets.bet[requiredPlayers[count]] = 0;
            playerKeys[requiredPlayers[count]].encKey=0;
            playerKeys[requiredPlayers[count]].decKey=0;
            playerKeys[requiredPlayers[count]].prime=0;
        }
        pot.value=0;
        betPos.index=1;
        agreed[msg.sender]=true; //contract creator automatically agrees to its conditions
        phase.setPlayerPhase(playerPhases, msg.sender, phase.getPlayerPhase(playerPhases, msg.sender)+1);
        updatePhases();
    }
   
	/*
	* Updates the internal game phase tracker for all players.
	*/
   function updatePhases() internal {
       phases.length=0;
       for (uint8 count=0; count<2; count++) {
           phases.push( GamePhase.Phase(playerPhases.phases[count].player, playerPhases.phases[count].phaseNum));
       }
   }
   
   /*
   * Returns true if the supplied address is allowed to agree to this contract.
   */
   function allowedToAgree (address player) private returns (bool)
    {
        for (uint count=0; count<players.list.length; count++) {
            if (player==players.list[count]) {
                return (true);
            }
        }
        return (false);
    }
    
    /*
	* Sets the "agreed" flag to true for the transaction sender.
	*/
	function agreeToContract() {
       /*
        if (phase.allPlayersAbovePhase(playerPhases, 0)) {
           return;
        }
        if (!allowedToAgree(msg.sender)) {
            //only for players initially specified
            return;
        } 
        //only allow setting of property once
        if (!agreed[msg.sender]) {
            agreed[msg.sender]=true;
        } else {
            return;
        }
      */
      agreed[msg.sender]=true;
        phase.setPlayerPhase(playerPhases, msg.sender, phase.getPlayerPhase(playerPhases, msg.sender)+1);
       updatePhases();
       // playerHasAgreed(msg.sender);
    }
  
    /*
	* Stores the fully encrypted card deck.
	*/
	function storeEncryptedCards(uint256[] cards) {
        /*
        if (phase.allPlayersAbovePhase(playerPhases, 0) == false) {
           return;
        }
        if (phase.getPlayerPhase(playerPhases, msg.sender) != 1) {
           return;
        }
        if (agreed[msg.sender] != true) {
           return;
        }
        */
        for (uint8 count=0; count<cards.length; count++) {
            encryptedDecks[msg.sender].cards.push(CryptoCards.CardType(cards[count],0,0));   
            
        }
        if (encryptedDecks[msg.sender].cards.length == 52) {
            phase.setPlayerPhase(playerPhases, msg.sender, phase.getPlayerPhase(playerPhases, msg.sender)+1);
        }
         updatePhases();
    }
    
	/*
	* Stores encrypted private cards for a player for the hand.
	*/
    function storePrivateCards(uint256[] cards) {
        /*
        if (agreed[msg.sender] != true) {
           return;
        }
        if (phase.allPlayersAbovePhase(playerPhases, 1) == false) {
           return;
        }
        if (cards.length != 2) {
           return;
        }
        */
        for (uint8 count=0; count<cards.length; count++) {
            privateCards[msg.sender].cards.push(CryptoCards.CardType(cards[count],0,0));         
        }
        if (privateCards[msg.sender].cards.length == 2) {
            phase.setPlayerPhase(playerPhases, msg.sender, phase.getPlayerPhase(playerPhases, msg.sender)+1);
            phase.setPlayerPhase(playerPhases, msg.sender, phase.getPlayerPhase(playerPhases, msg.sender)+1); //shortcut decryption phase for now
          updatePhases();
        }
    }

    /*
	* Stores the public or community card(s) for the hand.
	*/
    function storePublicCard(uint256 card) {
        /*
        if (agreed[msg.sender] != true) {
           return;
        }
        if (msg.sender != players.list[0]) {
            //only dealer can set public cards
            return;
        }
        if ((phase.allPlayersAtPhase(playerPhases, 5) == false) && 
            (phase.allPlayersAtPhase(playerPhases, 8) == false) && 
            (phase.allPlayersAtPhase(playerPhases, 11) == false)) {
           return;
        }
        */
        publicCards.cards.push(CryptoCards.CardType(card,0,0));
        //updates once at 3 cards (flop), 4 cards (turn), and 5 cards (river)
        if (publicCards.cards.length >= 3) {
            for (uint8 count=0; count<players.list.length; count++) {
                phase.setPlayerPhase(playerPhases, players.list[count], phase.getPlayerPhase(playerPhases, players.list[count])+1);
                phase.setPlayerPhase(playerPhases, players.list[count], phase.getPlayerPhase(playerPhases, players.list[count])+1); //shortcut decryption storage phase for now
            }
            updatePhases();
            betPos.index=1;
        }
    }
    
    /*
	* Stores a play-money player bet in the contract.
	*/
	function storeBet()  {
        /*
      if (agreed[msg.sender] != true) {
        return;
      }
      if ((phase.allPlayersAtPhase(playerPhases, 4) == false) && 
          (phase.allPlayersAtPhase(playerPhases, 7) == false) && 
          (phase.allPlayersAtPhase(playerPhases, 10) == false) && 
          (phase.allPlayersAtPhase(playerPhases, 13) == false)) {
          return;
      }
      if (players.list[betPos.index] != msg.sender) {
          return;
      }
      */
      if (betting.storeBet(players, playerBets, pot, betPos, msg.value)) {
           for (uint8 count=0; count<players.list.length; count++) {
              phase.setPlayerPhase(playerPhases, players.list[count], phase.getPlayerPhase(playerPhases, players.list[count])+1);
          }
          updatePhases();
      }
    }
    
    /*
	* Indicates that the transaction sender is folding their hand.
	*/
	function fold() {
        for (uint8 count=0; count<players.list.length; count++) {
            if (players.list[count] == msg.sender) {
                results[msg.sender]=1;
            } else {
                winner=players.list[count];
                results[players.list[count]]=2;
            }
        }
        payWinner();
    }
    
    /*
	* Sends the value of the contract to the contract winner.
	*/
	function payWinner() {
        winner.send(this.balance); //keeps the contract on the blockchain
        //suicide(winner); //removes the contract from the blockchain
    }
    
    /*
	* Store the crypto keypair for the transaction sender.
	*/
	function storeKeys(uint256 encKey, uint256 decKey) {
        /*
        if (agreed[msg.sender] != true) {
        return;
        }
      
        if (phase.allPlayersAtPhase(playerPhases, 14) == false) {
          return;
        }
        */
        playerKeys[msg.sender].encKey=encKey;
        playerKeys[msg.sender].decKey=decKey;
        playerKeys[msg.sender].prime=prime;        
        if (playerKeysSubmitted()) {
            decryptCards();
        }
      
    }
    
    /*
    * Decrypts all players' private and public/community cards. All crypto keypairs must be stored by this point.
	*/
    function decryptCards()  {
       // if (handIsComplete()) {
        //    throw;
    //    }
         for (uint8 count=0; count<players.list.length; count++) {
            cardsLib.decryptCards (publicCards, playerKeys[players.list[count]]);
            for (uint8 count2=0; count2<players.list.length; count2++){
                cardsLib.decryptCards (privateCards[players.list[count2]], playerKeys[players.list[count]]);                
            }
         }
         for (count=0; count<players.list.length; count++) {
             for (count2=0; count2<privateCards[players.list[count]].cards.length; count2++) {
                 playerCards[players.list[count]].push(privateCards[players.list[count]].cards[count2]);
            }
         }
         for (count=0; count<publicCards.cards.length; count++) {
             communityCards.push(publicCards.cards[count]);
         }
    }
    
	/*
	* Uses the poker hand analyzer library to generate player scores from full decrypted hands.
	*/
    function generatePlayerScore() external {
        uint256 currentResult=0;
        cardsLib.appendCards(publicCards, privateCards[msg.sender]);
        cardsLib.splitCardData(privateCards[msg.sender], analyzeCards);
        currentResult=phaLib.analyze(analyzeCards.suits, analyzeCards.values);
        results[msg.sender]=currentResult;
         if (highestResult < currentResult) {
            highestResult=currentResult;
            winner=msg.sender;
        }
        /*
        phase.setPlayerPhase(playerPhases, msg.sender, phase.getPlayerPhase(playerPhases, msg.sender)+1);
        updatePhases();
        */
        analyzeCards.suits.length=0;
        analyzeCards.values.length=0;
        //payWinner();
    }
        
    /*
	* True if all players have committed their encryption/decryption keys.
	*/
    function playerKeysSubmitted() private returns (bool) {
        for (uint8 count=1; count<players.list.length; count++) {
            if ((playerKeys[players.list[count]].prime == 0) || (playerKeys[players.list[count]].encKey == 0) 
                || (playerKeys[players.list[count]].decKey == 0)) {
                return (false);
            }
        }
        return (true);
    }
    
    /*
	* True if hand is complete (hand results have been established).
	*/
	function handIsComplete() internal returns (bool) {
        for (uint8 count=0; count<players.list.length; count++) {
            if (results[players.list[count]] > 0) {
                return (true);
            }
        }
        return (false);
    }
     
}
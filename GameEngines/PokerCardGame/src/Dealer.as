/**
* Core dealer class; extends Player class.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package  {		
	import events.PokerBettingEvent;
	import interfaces.IPlayer;
	import interfaces.IPokerPlayerInfo;
	import org.cg.interfaces.ICard;
	import p2p3.interfaces.ICryptoWorkerHost;	
	import p2p3.workers.WorkerMessage;
	import p2p3.workers.events.CryptoWorkerHostEvent;
	import p2p3.interfaces.INetCliqueMember;
	import crypto.SRAKey;
	import org.cg.DebugView;
	
	public class Dealer extends Player implements IPlayer 
	{
		
		public var encryptionProgressCount:uint = 0; //number of cards currently encrypted
		private var _communityCardSelect:Number = 0; //number of community cards to select
		private var _onSelectCommunityCards:Function = null; //to invoke when community cards are selected
		
		/**
		 * Creates a new Dealer instance.
		 * 
		 * @param	gameInstance A reference to the parent PokerCardGame instance.
		 * @param	initObject An object containing name-matched properties to be copied into internal values. 
		 * Usually used when switching roles mid-round such as during re-keying operations.
		 */
		public function Dealer(gameInstance:PokerCardGame, initObject:Object=null)
		{
			super(gameInstance);
			if (initObject != null) {
				//this is done in Player so that super values are not overwritten
				super.initialize(initObject);
			}						
		}
		
		/**
		 * Resets the game phase, creates new peer message logs and peer message handler, and enables game message handling.
		 */
		override public function start():void 
		{
			super.start(); //reset gamePhase
			DebugView.addText ("************");
			DebugView.addText ("Dealer.start");
			DebugView.addText ("************");
			DebugView.addText ("   Current betting round: " + game.bettingModule.currentSettings.currentLevel);
			if (game.bettingModule.currentSettings.currentLevel == 0) {
				setStartingBettingOrder();				
				setStartingBlinds();
				setStartingPlayerBalances();
			} else {
				//we have now assumed dealer role from previous dealer
			}
			var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;			
			DebugView.addText  ("   Crypto Byte Length: " + game.lounge.maxCryptoByteLength);
			DebugView.addText  ("   Generating shared prime modulus...");
			//this can be pre-computed to significantly reduce start-up time.
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGeneratePrime);
			cryptoWorker.directWorkerEventProxy = onGeneratePrimeProxy;
			var CBL:uint = game.lounge.maxCryptoByteLength * 8;
			new PokerGameStatusReport("Generating shared prime modulus.").report();
			var msg:WorkerMessage = cryptoWorker.generateRandomPrime(CBL, 16);			
		}
		
		/**
		 * Begins the process of selecting by community cards by determining the number of
		 * cards to be selected in the current game phase and starting the asynchronous, pseudo-random 
		 * selection. This process can be altered to allow manual selection of cards by the dealer instead
		 * of the current automated one.
		 */
		override public function selectCommunityCards():void 
		{
			DebugView.addText("Dealer.selectCommunityCards");
			DebugView.addText("   Current game phase: " + game.gamePhase);
			var phasesNode:XML = game.settings["getSettingsCategory"]("gamephases");			
			var currentPhaseNode:XML = phasesNode.children()[game.gamePhase] as XML;
			try {
				var communitycards:Number = Number(currentPhaseNode.communitycards);
				if (isNaN(communitycards)) {
					communitycards = 0;
				}
			} catch (err:*) {
				communitycards = 0;
			}
			DebugView.addText  ("   Comunity cards to select: " + communitycards);			
			try {
				if (currentPhaseNode != null) {
					if (communitycards>0) {
						pickRandomCommunityCards(communitycards, decryptNewCommunityCards);
					} else {					
						if (!game.bettingModule.selfPlayerInfo.hasFolded) {
							game.bettingModule.startNextBetting();
						} else {
							//next player should have betting enabled
						}
					}
				} else {
					DebugView.addText("   All community cards dealt. Final betting round.");
					if (!game.bettingModule.selfPlayerInfo.hasFolded) {
						game.bettingModule.startNextBetting();
					} else {
						//next player should have betting enabled
					}
				}
			} catch (err:*) {
				DebugView.addText("   * " + err.getStackTrace());
			}
		}
		
		/**
		 * Destroys the instance and its data, usually before references to it are removed for garbage collection.
		 * 
		 * @param	transferToDealer This parameter is ignored in the Dealer instance and always defaults to false.
		 */
		override public function destroy(transferToDealer:Boolean=false):void 
		{
			_onSelectCommunityCards = null;
			super.destroy(false); //force removal since there's no transfer to Player
		}
		
		/**
		 * Proxy function for onGeneratePrime intended to be called by a CryptoWorker in direct mode.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		public function onGeneratePrimeProxy(eventObj:CryptoWorkerHostEvent):void 
		{
			onGeneratePrime(eventObj);			
		}
		
		/**
		 * Proxy function for onGenerateKey intended to be called by a CryptoWorker in direct mode.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		override public function onGenerateKeyProxy(eventObj:CryptoWorkerHostEvent):void 
		{
			onGenerateKey(eventObj);			
		}
		
		/**
		 * Proxy function for onGenerateCardValues intended to be called by a CryptoWorker in direct mode.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		public function onGenerateCardValuesProxy(eventObj:CryptoWorkerHostEvent):void 
		{				
			onGenerateCardValues(eventObj);
		}
		
		/**
		 * Proxy function for onEncryptCard intended to be called by a CryptoWorker in direct mode.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		override public function onEncryptCardProxy(eventObj:CryptoWorkerHostEvent):void 
		{				
			onEncryptCard(eventObj);
		}
		
		/**
		 * Proxy function for onSelectCommunityCards intended to be called by a CryptoWorker in direct mode.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		public function onSelectCommunityCardsProxy(eventObj:CryptoWorkerHostEvent):void 
		{
			onSelectCommunityCards(eventObj);
		}
		
		/**
		 * Sets the starting player balances or common starting buy-in value.
		 */
		private function setStartingPlayerBalances():void
		{
			DebugView.addText("Dealer.setStartingPlayerBalances");
			var balanceVal:Number = Number.NEGATIVE_INFINITY; //default (use settings value)
			try {
				balanceVal = Number(game.lounge["startingPlayerBalances"].text);
			} catch (err:*) {
				balanceVal=Number.NEGATIVE_INFINITY
			}
			game.bettingModule.setAllPlayerBalances(balanceVal);
		}
		
		/**
		 * Creates and broadcasts an initial betting order at the beginning of a new game (first round).
		 */
		private function setStartingBettingOrder():void 
		{			
			DebugView.addText("Dealer.setStartingBettingOrder");
			if (game.bettingModule.bettingOrderLocked) {
				DebugView.addText("   Betting order established in previous round. Skipping.");
				return;
			}
			game.lounge.currentLeader = game.lounge.clique.localPeerInfo;
			for (var count:int = 0; count < game.lounge.clique.connectedPeers.length; count++) {				
				var currentPlayer:INetCliqueMember = game.lounge.clique.connectedPeers[count];					
				game.bettingModule.addPlayer(currentPlayer);
				if (!game.bettingModule.smallBlindIsSet) {					
					game.bettingModule.setSmallBlind(currentPlayer, true);
				} else if (!game.bettingModule.bigBlindIsSet) {					
					game.bettingModule.setBigBlind(currentPlayer, true);
				}
			}
			game.bettingModule.addPlayer(game.lounge.clique.localPeerInfo); //add at the end since we're the dealer
			game.bettingModule.setDealer(game.lounge.clique.localPeerInfo, true);	
			if (!game.bettingModule.bigBlindIsSet) {				
				game.bettingModule.setBigBlind(game.lounge.clique.localPeerInfo, true);
			}			
			game.bettingModule.broadcastBettingOrder();
			game.bettingModule.lockBettingOrder();
		}
		
		/**
		 * Sets the initial blinds values in the current PokerBettingModule instance.
		 */
		private function setStartingBlinds():void 
		{
			DebugView.addText("Dealer.setStartingBlinds");			
			game.bettingModule.dealerSetBlinds(game.bettingModule.currentSettings.currentLevelSmallBlind, game.bettingModule.currentSettings.currentLevelBigBlind);
		}
		
		/**
		 * Handles the event dispatched by a CryptoWorker when a primer number value is generated. An asynchronous
		 * operation to generate a cryptographically secure, pseudo-random crypto key pair is started if no
		 * errors occur.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		private function onGeneratePrime(eventObj:CryptoWorkerHostEvent):void 
		{
			DebugView.addText  ("Dealer.onGeneratePrime");						
			eventObj.target.removeEventListener(CryptoWorkerHostEvent.RESPONSE, onGeneratePrime);
			DebugView.addText  ("   Prime: " + eventObj.data.prime);
			DebugView.addText  ("   Operation took " + eventObj.message.elapsed + " ms");
			var dealerMessage:PokerCardGameMessage = new PokerCardGameMessage();
			var primeObj:Object = new Object();
			primeObj.prime = eventObj.data.prime;			
			primeObj.byteLength=game.lounge.maxCryptoByteLength;
			dealerMessage.createPokerMessage(PokerCardGameMessage.DEALER_MODGENERATED, primeObj);
			game.lounge.clique.broadcast(dealerMessage);
			game.log.addMessage(dealerMessage);			
			var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;
			cryptoWorker.directWorkerEventProxy = onGeneratePrimeProxy;
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateKey);				
			var CBL:uint = game.lounge.maxCryptoByteLength * 8;
			new PokerGameStatusReport("Generating crypto key.").report();
			var msg:WorkerMessage = cryptoWorker.generateRandomSRAKey(eventObj.data.prime, true, CBL);		
		}
		
		/**
		 * Handles the event dispatched by a CryptoWorker when a crypto key pair is generated. If no errors occur,
		 * an asynchronous operation to generate quadratic residues/non-residues (plaintext card values) is started.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		override protected function onGenerateKey(eventObj:CryptoWorkerHostEvent):void 
		{
			DebugView.addText  ("Dealer.onGenerateKey");
			DebugView.addText  ("   Operation took " + eventObj.message.elapsed + " ms");
			eventObj.target.removeEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateKey);			
			super.onGenerateKey(eventObj);			
			var numCards:uint = game.currentDeck.size;		
			var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;			
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateCardValues);
			cryptoWorker.directWorkerEventProxy = onGenerateCardValuesProxy;			
			var ranges:Object = SRAKey.getQRNRValues(key.modulusHex, String(game.currentDeck.size));
			DebugView.addText  ("   Generating quadratic residues/non-residues (" + numCards + " card values).");
			new PokerGameStatusReport("Generating "+numCards+" cards.").report();
			//these can be pre-computed to significantly reduce start-up time.
			var msg:WorkerMessage = cryptoWorker.QRNR (ranges.start, ranges.end, eventObj.data.prime, 16);
		}		
		
		/**
		 * Handles the CryptoWorker event dispatched when a series of quadratic residues/non-residues (plaintext
		 * card values) have been generated. If all values are valid, asynchronous operations are
		 * started to encrypt the card values.
		 * 
		 * @param	eventObj Event object dispatched by a CryptoWorkerHost instance.
		 */
		private function onGenerateCardValues(eventObj:CryptoWorkerHostEvent):void
		{
			DebugView.addText ("Dealer.onGenerateCardValues");
			DebugView.addText ("   Operation took " + eventObj.message.elapsed + " ms");
			DebugView.addText ("   Number of candidate values generated: " + eventObj.data.qr.length);
			eventObj.target.removeEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateCardValues);
			var numCards:uint = game.currentDeck.size;			
			if (numCards > uint(String(eventObj.data.qr.length))) {
				//not enough quadratic residues generated...try again with twice as many
				var ranges:Object = SRAKey.getQRNRValues(key.modulusHex, String((eventObj.data.qr.length+eventObj.data.qnr.length)*2));
				var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateCardValues);
				var msg:WorkerMessage = cryptoWorker.QRNR (ranges.start, ranges.end, eventObj.data.prime, 16);
				return;
			} else {
				new PokerGameStatusReport("Encrypting generated card deck.").report();
				dealerCards = new Array();
				var broadcastData:Array = new Array();				
				//eventObj.data.qnr is also available if quadratic non-residues are desired				
				for (var count:uint = 0; count < eventObj.data.qr.length; count++) {
					var currentQR:String = eventObj.data.qr[count] as String;
					var currentCard:ICard = game.currentDeck.getCardByIndex(count);										
					if (currentCard!=null) {						
						broadcastData[count] = new Object();
						broadcastData[count].mapping = currentQR;
						broadcastData[count].frontClassName = currentCard.frontClassName;
						broadcastData[count].faceColor = currentCard.faceColor;
						broadcastData[count].faceText = currentCard.faceText;
						broadcastData[count].faceValue = currentCard.faceValue;
						broadcastData[count].faceSuit = currentCard.faceSuit;
						game.currentDeck.mapCard(currentQR, currentCard);					
					}
				}
				//if QR/NR are pre-computed, this message can be shortened significantly (just send an index value?)
				var dealerMessage:PokerCardGameMessage = new PokerCardGameMessage();
				dealerMessage.createPokerMessage(PokerCardGameMessage.DEALER_CARDSGENERATED, broadcastData);
				game.lounge.clique.broadcast(dealerMessage);
				game.log.addMessage(dealerMessage);				
				for (count = 0; count < eventObj.data.qr.length; count++) {
					currentQR = eventObj.data.qr[count] as String;
					currentCard = game.currentDeck.getCardByIndex(count);										
					if (currentCard != null) {
						cryptoWorker = game.lounge.nextAvailableCryptoWorker;
						cryptoWorker.directWorkerEventProxy = onEncryptCardProxy;
						cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onEncryptCard);						
						msg=cryptoWorker.encrypt(currentQR, key, 16);
					}
				}
			}
		}		
		
		/**
		 * Handles events dispatched by a CryptoWorker when card values are encrypted. If all cards are
		 * encrypted, an asynchronous operation to shuffle the cards is started after which 
		 * the encrypted deck is broadcast to the first peer in order to begin multi-party encryption.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		override protected function onEncryptCard(eventObj:CryptoWorkerHostEvent):void 
		{
			encryptionProgressCount++;
			var numCards:uint = game.currentDeck.size;				
			dealerCards.push(eventObj.data.result);
			try {
				var percent:Number = encryptionProgressCount / numCards;
				DebugView.addText  ("Dealer.onEncryptCard #"+encryptionProgressCount+" ("+Math.round(percent*100)+"%)");
				DebugView.addText  ("   Operation took " + eventObj.message.elapsed + " ms");
				DebugView.addText  ("   Card generated: " + eventObj.data.result);
				if (encryptionProgressCount >= numCards) {
					super.clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptCard);
					encryptionProgressCount = 0;			
					shuffleDealerCards(shuffleCount, broadcastDealerEncryptedDeck);	
				}
			} catch (err:*) {
				DebugView.addText(err);
			}
		}		
		
		/**
		 * Broadcasts an encrypted dealer deck to the first participating peer to continue
		 * multi-party encryption operations on the cards.
		 */
		private function broadcastDealerEncryptedDeck():void 
		{			
			DebugView.addText  ("Dealer.broadcastDealerEncryptedDeck");			
			var broadcastData:Array = new Array();
			try {
				DebugView.addText("   Included cards in deck: "+dealerCards.length);
				for (var count:uint = 0; count < dealerCards.length; count++) {				
					var currentCryptoCard:String = new String(dealerCards[count] as String);	
					broadcastData[count] = currentCryptoCard;
				}
				var dealerMessage:PokerCardGameMessage = new PokerCardGameMessage();
				dealerMessage.createPokerMessage(PokerCardGameMessage.PLAYER_CARDSENCRYPTED, broadcastData);
				var connectedPeers:Vector.<INetCliqueMember> = new Vector.<INetCliqueMember>();
				for (count = 0; count < game.lounge.clique.connectedPeers.length; count++) {					
					var playerInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(game.lounge.clique.connectedPeers[count]);					
					//will be null if player has busted (balance is 0)
					if (playerInfo != null) {
						connectedPeers.push(game.lounge.clique.connectedPeers[count]);
					}
				}				
				for (count = 0; count < connectedPeers.length; count++) {
					var currentPeer:INetCliqueMember = connectedPeers[count];				
					dealerMessage.addTargetPeerID(currentPeer.peerID);
				}
			} catch (err:*) {
				DebugView.addText(err);
			}
			var truncatedPeerID:String = dealerMessage.getTargetPeerIDList()[0].peerID.substr(0, 15) + "...";
			new PokerGameStatusReport("Sending encrypted deck to peer "+truncatedPeerID+".").report();
			game.lounge.clique.broadcast(dealerMessage);
			game.log.addMessage(dealerMessage);
		}
		
		/**
		 * Handles CryptoWorker error events.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost instance.
		 */
		private function onError(eventObj:CryptoWorkerHostEvent):void 
		{
			DebugView.addText (eventObj.humanMessage);
		}
		
		/**
		 * Handler for BETTING_FINAL_DONE events dispatched by a PokerBettingModule instance. Invokes
		 * onFinalBettingComplete in the Player (super) class.
		 * 
		 * @param	eventObj Event dispatched by a PokerBettingModule instance.
		 */
		override protected function onFinalBettingComplete(eventObj:PokerBettingEvent):void 
		{		
			DebugView.addText  ("Dealer.onFinalBettingComplete");			
			super.onFinalBettingComplete(eventObj);
		}
		
		/**
		 * Handles BETTING_DONE events dispatched from a PokerBettingModule instance. If the current
		 * betting phase has completed, new community cards are selected as appropriate. If all betting
		 * phases have completed, onFinalBet is invoked.
		 * 
		 * @param	eventObj Event dispatched by a PokerBettingModule instance.
		 */
		override protected function onBettingComplete(eventObj:PokerBettingEvent):void 
		{
			DebugView.addText  ("Dealer.onBettingComplete");
			var phasesNode:XML = game.settings["getSettingsCategory"]("gamephases");
			try {
				var currentPhaseNode:XML = phasesNode.children()[game.gamePhase] as XML;
			} catch (err:*) {
				currentPhaseNode = null;
			}
			if (currentPhaseNode == null) {				
				DebugView.addText("   All game phases complete.");
				game.bettingModule.onFinalBet();
				return;
			}
			DebugView.addText  ("   Game phase #" + game.gamePhase+" - "+currentPhaseNode.@name);
			selectCommunityCards();
			_peerMessageHandler.unblock();
		}		

		/**
		 * Begins the asynchronous process of selecting pseudo-random (cryptographically secure) 
		 * community/public cards.
		 * 
		 * @param	cardsCount The number of cards to select.
		 * @param	onSelectCards The function to invoke when all the specified cards are chosen.
		 */
		protected function pickRandomCommunityCards(cardsCount:Number, onSelectCards:Function):void 
		{
			DebugView.addText  ("Dealer.pickRandomCommunityCards cards=" + cardsCount);
			new PokerGameStatusReport("I'm selecting "+cardsCount+" community cards.").report();
			_communityCardSelect = cardsCount;
			_onSelectCommunityCards = onSelectCards;
			var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onSelectCommunityCards);
			cryptoWorker.directWorkerEventProxy = onSelectCommunityCardsProxy;
			//multiply by 8x4=32 since we're using bits, 4 bytes per random value for a good range (there should be a more flexible/generic way to do this);
			//see onGenerateRandomShuffle for how this is handled once generated
			var msg:WorkerMessage = cryptoWorker.generateRandom((cardsCount*32), false, 16);
		}
		
		/**
		 * Event handler invoked when a CryptoWorker has completed selecting cryptographically secure, pseudo-random values 
		 * used to select community/public cards.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost instance.
		 */
		private function onSelectCommunityCards(eventObj:CryptoWorkerHostEvent):void 
		{
			eventObj.target.removeEventListener(CryptoWorkerHostEvent.RESPONSE, onSelectCommunityCards);			
			var randomStr:String = eventObj.data.value;
			if (randomStr == null) {
				pickRandomCommunityCards(_communityCardSelect, _onSelectCommunityCards);
				return;
			}
			randomStr = randomStr.substr(2); //we know this is a "0x" hex value
			var selectedCards:Array = new Array();
			for (var count:Number = 0; count < _communityCardSelect; count++) {
				try {
					var rawIndexStr:String = randomStr.substr(0, 4);
					var rawIndex:uint = uint("0x" + rawIndexStr);
					var indexMod:Number = rawIndex % dealerCards.length;						
					var splicedCards:Array = dealerCards.splice(indexMod, 1);						
					selectedCards.push(splicedCards[0] as String);
					super.communityCards.push(splicedCards[0] as String);
					randomStr = randomStr.substr(3);
				} catch (err:*) {				
					break;
				}
			}
			if (_onSelectCommunityCards != null) {
				_onSelectCommunityCards(selectedCards);
				_onSelectCommunityCards = null;
			}
			super._peerMessageHandler.unblock();
		}		
		
		/**
		 * Begins the asynchronous process of decrypting newly chosen community/public cards via
		 * multi-party computation.
		 * 
		 * @param	cards A list of numeric strings representing the encrypted card values to decrypt.
		 */
		protected function decryptNewCommunityCards(cards:Array):void 
		{
			DebugView.addText  ("Dealer.decryptNewCommunityCards");
			DebugView.addText  ("   Cards to decrypt: " + cards.length);
			var msg:PokerCardGameMessage = new PokerCardGameMessage();
			msg.createPokerMessage(PokerCardGameMessage.DEALER_DECRYPTCARDS, cards);
			var members:Vector.<INetCliqueMember> = game.getSMOShiftList();
			for (var count:int = 0; count < members.length; count++) {
				var playerInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(members[count]);
				if (playerInfo != null) {					
					msg.addTargetPeerID(members[count].peerID);
				}				
			}			
			if (msg.isNextTargetID(game.lounge.clique.localPeerInfo.peerID)) {
				//we decrypt first, then relay to peers
				_currentActiveMessage = msg;
				super.decryptCommunityCards(cards, super.relayDecryptCommunityCards);
			} else {
				//we relay, then decrypt later at some point
				game.lounge.clique.broadcast(msg);
				game.log.addMessage(msg);
			}
		}
		
		/**
		 * Begins the asynchronous process of selecting community/public cards based on the current
		 * game phase.
		 */
		override protected function startCommunityCardsSelection():void 
		{
			DebugView.addText  ("Dealer.startCommunityCardsSelection");				
			var phasesNode:XML = game.settings["getSettingsCategory"]("gamephases");						
			var currentPhaseNode:XML = phasesNode.children()[game.gamePhase] as XML;			
			DebugView.addText  ("   Current game phase: " + currentPhaseNode);
			new PokerGameStatusReport("Selecting community cards for next game phase: "+currentPhaseNode.@name).report();
			var dealCards:Number = Number(currentPhaseNode.dealcards);	
			new PokerGameStatusReport("Selecting "+dealCards+" community cards.").report();
			DebugView.addText  ("   Number of cards to deal this phase: "+dealCards);
			var selectionTargets:Vector.<INetCliqueMember> = game.getSMOShiftList();			
			var msg:PokerCardGameMessage = new PokerCardGameMessage();		
			for (var count:uint = 0; count < selectionTargets.length; count++) {
				var targetID:String = selectionTargets[count].peerID;
				var playerInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(selectionTargets[count]);
				//will be null if balance is 0 (busted)
				if (playerInfo != null) {
					msg.addTargetPeerID(targetID);					
				}				
			}	
			var payload:Object = new Object();
			payload.cards = new Array();
			payload.pick = dealCards;
			for (count = 0; count < dealerCards.length; count++) {				
				var currentCryptoCard:String = new String(dealerCards[count] as String);	
				payload.cards[count] = currentCryptoCard;
			}
			msg.createPokerMessage(PokerCardGameMessage.DEALER_PICKCARDS, payload);
			if (msg.isNextTargetID(game.lounge.clique.localPeerInfo.peerID)) {				
				_currentActiveMessage = msg;
				super.pickPlayerHand(dealCards);
			} else {
				game.lounge.clique.broadcast(msg);
				game.log.addMessage(msg);
				super._peerMessageHandler.unblock();
			}
		}		
	}
}
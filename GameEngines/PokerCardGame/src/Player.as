/**
* Base player class.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package 
{
	import interfaces.IPlayer;
	import events.PokerBettingEvent;
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.PeerMessageHandler;
	import p2p3.events.PeerMessageHandlerEvent;
	import PokerCardGame;
	import org.cg.interfaces.ICard;
	import org.cg.Card;
	import org.cg.CardDeck;
	import p2p3.interfaces.ICryptoWorkerHost;
	import p2p3.interfaces.IPeerMessage;
	import p2p3.events.NetCliqueEvent;	
	import p2p3.workers.events.CryptoWorkerHostEvent;
	import p2p3.workers.WorkerMessage;	
	import crypto.interfaces.ISRAKey;
	import PokerBettingModule;
	import org.cg.DebugView;
	import p2p3.PeerMessageLog;
	import PokerHandAnalyzer;
	
	public class Player implements IPlayer 
	{
		
		public var game:PokerCardGame; //reference to game instance
		protected var _peerMessageHandler:PeerMessageHandler; //reference to a PeerMessageHandler instance
		protected var _messageLog:PeerMessageLog; //reference to a peer message log instance
		protected var _errorLog:PeerMessageLog; //reference to a peer message error log instance
		protected var _currentActiveMessage:IPeerMessage; //peer message currently being processed		
		public var dealerCards:Array = new Array(); //face-down dealer cards
		public var communityCards:Array = new Array(); //face-up community cards
		public var heldCards:Array = new Array(); //face-up held/private cards
		private var _workCards:Array = new Array(); //cards currently being worked on (encryption, decryption, etc.)
		private var _workCardsComplete:Array = new Array(); //completed work cards		
		private var _postCardShuffle:Function = null; //function to invoke after a shuffle operation completes
		private var _postCardDecrypt:Function = null; //function to invoke after card operations complete		
		protected var _key:ISRAKey = null; //player's crypto key		
		private var _cardsToChoose:Number = 0; //used during card selection to track # of cards to choose
		private var _pokerHandAnalyzer:PokerHandAnalyzer = null; //used post-round to analyze hands
		
		protected static var _instances:uint = 0; //number of active instances
		
		
		/**
		 * Create a new Player instance.
		 * 
		 * @param	gameInstance A reference to the containing PokerCardGame instance.
		 * @param	isDealer Player is a dealer type (used by extending Dealer class).
		 */
		public function Player(gameInstance:PokerCardGame) 
		{
			_instances++;
			if (_instances > 1) {
				var err:Error = new Error("More than one Player or extending instance exists!");
				throw (err);
			}
			game = gameInstance;			
		}
		
		/**
		 * @return The number of times a shuffle operation should be carried out on cards, as defined in the
		 * settings data.
		 */
		protected function get shuffleCount():uint 
		{
			var shuffleStr:String = game.settings["getSettingData"]("defaults", "shufflecount");
			if ((shuffleStr!=null) && (shuffleStr!="")) {
				var shuffleTimes:uint = uint(shuffleStr);
			} else {
				shuffleTimes = 3;
			}
			return (shuffleTimes);		
		}

		/**
		 * The encryption key currently being used by the player.
		 */
		public function set key(keySet:ISRAKey):void 
		{
			_key = keySet;
		}
		
		public function get key():ISRAKey 
		{
			return (_key);
		}
	
		/**
		 * Resets the game phase, creates new peer message logs and peer message handler, and enables game message handling.
		 */
		public function start():void 
		{			
			DebugView.addText ("************");
			DebugView.addText ("Player.start");
			DebugView.addText ("************");
			game.gamePhase = 0;
			_messageLog = new PeerMessageLog();
			_errorLog = new PeerMessageLog();
			_peerMessageHandler = new PeerMessageHandler(_messageLog, _errorLog);
			enableGameMessaging();
			_peerMessageHandler.addToClique(game.lounge.clique);
		}
		
		/**
		 * Enable event listeners for the instance.
		 */
		public function enableGameMessaging():void 
		{				
			disableGameMessaging(); //prevents multiple listeners
			game.bettingModule.addEventListener(PokerBettingEvent.BETTING_DONE, onBettingComplete);
			game.bettingModule.addEventListener(PokerBettingEvent.BETTING_FINAL_DONE, onFinalBettingComplete);
			_peerMessageHandler.addEventListener(PeerMessageHandlerEvent.PEER_MSG, onPeerMessage);		
		}
		
		/**
		 * Disable event listeners for instance.
		 */
		public function disableGameMessaging():void 
		{
			game.bettingModule.removeEventListener(PokerBettingEvent.BETTING_DONE, onBettingComplete);
			game.bettingModule.removeEventListener(PokerBettingEvent.BETTING_FINAL_DONE, onFinalBettingComplete);
			_peerMessageHandler.removeEventListener(PeerMessageHandlerEvent.PEER_MSG, onPeerMessage);		
		}
		
		/**
		 * Handles events from the PeerMessageHandler.
		 * 
		 * @param	eventObj An event from the PeerMessageHandler.
		 */
		public function onPeerMessage(eventObj:PeerMessageHandlerEvent):void 
		{
			try {
				processPeerMessage(eventObj.message);
			} catch (err:*) {
				DebugView.addText("Player.onPeerMessage ERROR: " + err);
			}
		}
		
		/**
		 * Intended to be overriden by extending Dealer class.
		 */
		public function selectCommunityCards():void {
			DebugView.addText("Player.selectCommunityCards - Nothing to do.");
		}
		
		/**
		 * 
		 */
		public function destroy():void 
		{
			/*
			 * TODO: commented items cause problems with subsequent instances; for further investigation
			 */
			disableGameMessaging();	
			_currentActiveMessage = null;
			_pokerHandAnalyzer = null;
			_peerMessageHandler.removeFromClique(game.lounge.clique);
			//_peerMessageHandler = null;
			_messageLog.destroy();
			_errorLog.destroy();
			//_messageLog = null;
			//_errorLog = null;
			if (_key!=null) {
				_key.scrub();
			}			
			//_key = null;			
			//dealerCards = null;
			//communityCards = null;
			//heldCards = null;
			//game = null;
			_instances--;
		}
		
		/**
		 * Begins an asynchronous, cryptographically secure, pseudo-random shuffle operation on the cards in the 
		 * dealerCards array.
		 * 
		 * @param	loops The number of shuffles to apply to the dealerCards array.
		 * @param	postShuffle The function to invoke when the shuffle operation(s) complete.
		 */
		protected function shuffleDealerCards(loops:uint = 1, postShuffle:Function = null):void 
		{
			DebugView.addText("shuffleDealerCards x " + loops);
			var tempCards:Array = new Array();
			_postCardShuffle = postShuffle;
			var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateRandomShuffle);
			cryptoWorker.directWorkerEventProxy = onGenerateRandomShuffleProxy;
			//multiply by 8x4=32 since we're using bits, 4 bytes per random value for a good range (there should be a more flexible/generic way to do this);
			//also see onGenerateRandomShuffle for how this is handled once generated
			var msg:WorkerMessage = cryptoWorker.generateRandom((dealerCards.length*32)*loops, false, 16);
		}		
		
		/**
		 * Handler invoked when a CryptoWorker has generated a cryptographically secure random shuffle sequence.
		 * The generated value is used to shuffle the dealerCards array.
		 * 
		 * @param	eventObj Event dispatched from a CryptoWorkerHost.
		 */
		protected function onGenerateRandomShuffle(eventObj:CryptoWorkerHostEvent):void 		
		{			
			eventObj.target.removeEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateRandomShuffle);			
			var randomStr:String = eventObj.data.value;
			if (randomStr == null) {
				shuffleDealerCards(shuffleCount, _postCardShuffle);
				return;
			}
			randomStr = randomStr.substr(2); //because we know this is a "0x" hex value						
			var loops:Number = randomStr.length / (8*dealerCards.length); //2 hex characters per byte x 4 bytes per loop x length of dealer deck			
			for (var count1:Number = 0; count1 < loops; count1++) {
				var shuffledCards:Array = new Array();				
				var deckLength:Number = Number(dealerCards.length);
				while (dealerCards.length>0) {					
					try {
						var rawIndexStr:String = randomStr.substr(0, 4);
						var rawIndex:uint = uint("0x" + rawIndexStr);
						var indexMod:Number = rawIndex % dealerCards.length;						
						var splicedCards:Array = dealerCards.splice(indexMod, 1);						
						shuffledCards.push(splicedCards[0] as String);					
						randomStr = randomStr.substr(3);
					} catch (err:*) {				
						break;
					}
				}
				dealerCards = shuffledCards;				
			}
			if (_postCardShuffle != null) {
				_postCardShuffle();
				_postCardShuffle = null;
			}
		}	
		
		public function onGenerateRandomShuffleProxy(eventObj:CryptoWorkerHostEvent):void 
		{
			onGenerateRandomShuffle(eventObj);
		}

		/**
		 * Handler invoked when a CryptoWorker has generated a crypto key pair.
		 * 
		 * @param	eventObj An event dispatched by a CryptoWorkerHost.
		 */
		protected function onGenerateKey(eventObj:CryptoWorkerHostEvent):void 
		{
			eventObj.target.removeEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateKey);			
			key = eventObj.data.sraKey;			
			_peerMessageHandler.unblock();
		}
		
		public function onGenerateKeyProxy(eventObj:CryptoWorkerHostEvent):void
		{
			onGenerateKey(eventObj);
		}

		/**
		 * Processes a received peer message. Any message that does not validate as a PokerCardGameMessage
		 * is discarded.
		 * 
		 * @param	peerMessage
		 */
		protected function processPeerMessage(peerMessage:IPeerMessage):void 
		{			
			var peerMsg:PokerCardGameMessage = PokerCardGameMessage.validatePokerMessage(peerMessage);		
			if (peerMsg == null) {				
				//not a valid PokerCardGameMessage
				return;
			}		
			if (peerMessage.isNextSourceID(game.lounge.clique.localPeerInfo.peerID)) {				
				//message came from us (we are the next source ID meaning no other peer has processed the message)
				return;
			}			
			peerMsg.timestampReceived = peerMsg.generateTimestamp();
			try {
				//TODO: this should work with peerMsg too but some values are not being properly copied; to investigate
				if (peerMessage.hasTargetPeerID(game.lounge.clique.localPeerInfo.peerID)) {
					//message is either for us or whole clique (*)
					_peerMessageHandler.block();					
					switch (peerMsg.pokerMessageType) {						
						case PokerCardGameMessage.DEALER_MODGENERATED:							
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_MODGENERATED");	
							DebugView.addText  ("   Dealer generated modulus: " + peerMsg.data.prime);
							DebugView.addText  ("   Crypto Bit Length (CBL): " + peerMsg.data.byteLength);							
							game.lounge.maxCryptoByteLength = uint(peerMsg.data.byteLength);
							var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;
							cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateKey);
							var maxCBL:uint = game.lounge.maxCryptoByteLength * 8;
							var msg:WorkerMessage = cryptoWorker.generateRandomSRAKey(String(peerMsg.data.prime), false, maxCBL);
							break;
						case PokerCardGameMessage.DEALER_CARDSGENERATED:							
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_CARDSGENERATED");
							var cards:Array = peerMsg.data as Array;							
							for (var count:uint = 0; count < cards.length; count++) {
								var currentCardObj:Object = cards[count];
								/*
								object contains the following values (strings):
									
								currentCardObj[count].mapping -- the mapping (usually hex) string of the associated card. This is the plain text, "face up" value after decryption.
								currentCardObj[count].frontClassName -- the class name of the card face in the loaded card deck SWF (AceOfSpades, etc.)
								currentCardObj[count].faceColor -- the card color name (red, black)
								currentCardObj[count].faceText -- the card face text (nine, queen, ace, etc.)
								currentCardObj[count].faceValue -- the card face value (1 to 13 with ";" ace high value)
								currentCardObj[count].faceSuit -- the card face suit (spades, clubs, diamonds, hearts)
								*/
								var cardRef:ICard = game.currentDeck.getCardByClass(currentCardObj.frontClassName) as ICard;							
								game.currentDeck.mapCard(currentCardObj.mapping, cardRef);							
							}
							_peerMessageHandler.unblock();
							break;
						case PokerCardGameMessage.PLAYER_DECRYPTCARDS:
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.PLAYER_DECRYPTCARDS");							
							try {	
								var cCards:Array = new Array();
								//we do this since the data object is a generic object, not an array as we expect at this point								
								for (var item:* in peerMsg.data) {									
									cCards[Number(item)] = String(peerMsg.data[item]);
								}
							} catch (err:*) {
								DebugView.addText (err);
								return;
							}
							if (peerMsg.isNextTargetID(game.lounge.clique.localPeerInfo.peerID)) {
								DebugView.addText("   Decrypting player hand: "+cCards);
								_currentActiveMessage=peerMessage;
								decryptPlayerHand(cCards);
							} else {
								_peerMessageHandler.unblock();
							}
							break;
						case PokerCardGameMessage.PLAYER_CARDSENCRYPTED:
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.PLAYER_CARDSENCRYPTED");							
							try {							
								cCards = peerMsg.data;							
							} catch (err:*) {
								DebugView.addText  (err);
								return;
							}
							dealerCards = new Array();
							for (count = 0; count < cCards.length; count++) {	
								var currentCCard:String = cCards[count] as String;								
								if (currentCCard!=null) {
									dealerCards[count] = currentCCard;
								}
							}							
							if (peerMsg.isNextTargetID(game.lounge.clique.localPeerInfo.peerID)) {
								DebugView.addText  ("   Continuing deck encryption from peers: " + peerMsg.sourcePeerIDs);
								_currentActiveMessage=peerMessage;
								encryptDealerDeck();
							} else if (peerMsg.targetPeerIDs == "*") {								
								if (game.lounge.leaderIsMe) {									
									DebugView.addText  ("   Dealer deck encrypted and shuffled by all players.");
									startCommunityCardsSelection();
								} else {
									_peerMessageHandler.unblock();
								}
							} else {
								_peerMessageHandler.unblock();
							}
							break;
						case PokerCardGameMessage.DEALER_PICKCARDS:
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_PICKCARDS");								
							try {							
								cCards = peerMsg.data.cards;							
							} catch (err:*) {
								DebugView.addText  (err);
								break;
							}
							dealerCards = new Array();
							for (count = 0; count < cCards.length; count++) {	
								currentCCard = cCards[count] as String;								
								if (currentCCard!=null) {
									dealerCards[count] = currentCCard;
								}
							}							
							if (peerMsg.targetPeerIDs == "*") {
								_peerMessageHandler.unblock();
								if (game.lounge.leaderIsMe) {
									DebugView.addText  ("   Cards are selected. About to starting next betting round.");									
								}
							} else {
								if (peerMsg.isNextTargetID(game.lounge.clique.localPeerInfo.peerID)) {								
									DebugView.addText  ("   My turn to choose " + peerMsg.data.pick + " cards.");	
									//Player may manually select here too...
									_currentActiveMessage = peerMessage;
									pickPlayerHand(Number(peerMsg.data.pick));
								} else {
									_peerMessageHandler.unblock();
								}
							}
							break;
						case PokerCardGameMessage.DEALER_DECRYPTCARDS:						
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_DECRYPTCARDS");							
							cCards = new Array();
							try {	
								for (item in peerMsg.data) {									
									cCards[Number(item)] = String(peerMsg.data[item]);
								}
							} catch (err:*) {
								DebugView.addText  (err);
								return;
							}
							_currentActiveMessage = peerMessage;							
							try {
								if (peerMsg.targetPeerIDs=="*") {
									if (game.lounge.leaderIsMe) {
										broadcastDealerCommunityCards(cCards);
									} else {
										_peerMessageHandler.unblock();
									}
								} else {									
									if (peerMsg.isNextTargetID(game.lounge.clique.localPeerInfo.peerID)) {
										decryptCommunityCards(cCards, relayDecryptCommunityCards);
									} else {
										_peerMessageHandler.unblock();
									}
								}							
							} catch (err:*) {
								DebugView.addText  (err);
							}
							break;
						case PokerCardGameMessage.DEALER_CARDSDECRYPTED:
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_CARDSDECRYPTED");							
							cCards = new Array();
							try {	
								for (item in peerMsg.data) {									
									cCards[Number(item)] = String(peerMsg.data[item]);
								}
								var previousCard:Card = null;
								var cardMaps:Vector.<ICard> = new Vector.<ICard>();
								for (count = 0; count < cCards.length; count++) {
									var currentCardMapping:String = cCards[count] as String;
									communityCards.push(currentCardMapping);
									cardMaps.push(game.currentDeck.getCardByMapping(currentCardMapping));
								}
								game.addToCommunityCards(cardMaps);							
							} catch (err:*) {
								DebugView.addText (err);
								return;
							}
							_peerMessageHandler.unblock();
							break;
						default: 
							_peerMessageHandler.unblock();
							break;
					}				
				} else {
					_peerMessageHandler.unblock();
				}
			} catch (err:*) {
				_peerMessageHandler.unblock();
			}
		}		
		
		/**
		 * Begins an asynchronous decryption operation on community/public cards. An error is thrown if the crypto
		 * key pair has not yet been set.
		 * 
		 * @param	cards An array of numeric strings representing the cards to decrypt.
		 * @param	onDecrypt The function to invoke when the cards are decrypted.
		 */
		protected function decryptCommunityCards(cards:Array, onDecrypt:Function):void 
		{			
			DebugView.addText  ("Player.decryptCommunityCards");
			if (cards == null) {
				return;
			}
			if (key == null) {
				var error:Error = new Error("Crypto key is null.");
				throw (error);
			}
			_workCardsComplete = new Array();
			_workCards = new Array();
			for (var count:uint = 0; count < cards.length; count++) {				
				_workCards[count] = cards[count];
			}
			_postCardDecrypt = onDecrypt;			
			for (count = 0; count < cards.length; count++) {
				var currentCCard:String = cards[count] as String;				
				DebugView.addText  ("About to decrypt community card #" + count + ": " + currentCCard);
				try {
					var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;							
					cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onDecryptCommunityCard);					
					var msg:WorkerMessage = cryptoWorker.decrypt(currentCCard, key, 16);					
				} catch (err:*) {
					DebugView.addText (err);
					DebugView.addText (err.getStackTrace());
				}
			}
		}	
		
		/**
		 * Handles CryptoWorkerHost events during decryption of community/public cards.
		 * 
		 * @param	eventObj An event dispatched by the CryptoWorkerHost.
		 */
		protected function onDecryptCommunityCard(eventObj:CryptoWorkerHostEvent):void 
		{
			DebugView.addText  ("Player.onDecryptCommunityCard: " + eventObj.data.result);			
			_workCardsComplete.push(eventObj.data.result);
			DebugView.addText  ("   Cards remaining: "+_workCards.length);
			DebugView.addText  ("   Cards completed: "+_workCardsComplete.length);
			if (_workCards.length == _workCardsComplete.length) {				
				clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onDecryptCommunityCard);
				if (_postCardDecrypt != null) {					
					_postCardDecrypt(_workCardsComplete);
					_postCardDecrypt = null;
				}	
				_workCards = null;
			}
		}
		
		/**
		 * Broadcasts the dealer-generated community/public cards. This function should only be invoked
		 * by the current dealer.
		 * 
		 * @param	cards
		 */
		protected function broadcastDealerCommunityCards(cards:Array):void 
		{
			//TODO: move this functionality to Dealer class
			DebugView.addText  ("Dealer.broadcastDealerCommunityCards()");
			var msg:PokerCardGameMessage = new PokerCardGameMessage();
			msg.createPokerMessage(PokerCardGameMessage.DEALER_CARDSDECRYPTED, cards);			
			game.lounge.clique.broadcast(msg);
			var previousCard:Card = null;
			var cardMaps:Vector.<ICard> = new Vector.<ICard>();
			for (var count:uint = 0; count < cards.length; count++) {
				var currentCardMapping:String = cards[count] as String;
				cardMaps.push(game.currentDeck.getCardByMapping(currentCardMapping));
			}
			game.addToCommunityCards(cardMaps);
			_peerMessageHandler.unblock();		
		}
		
		/**
		 * Relays a community/public card decryption operation to the next peer.
		 * 
		 * @param	cards A list of numeric card values to relay with the peer message.
		 */
		protected function relayDecryptCommunityCards(cards:Array):void 
		{
			DebugView.addText  ("Player.relayDecryptCommunityCards()");
			var currentMsg:IPeerMessage = _currentActiveMessage;			
			try {
				currentMsg.updateSourceTargetForRelay(); //if no targets available after this, broadcast method should broadcast to all "*"
			} catch (err:*) {
				DebugView.addText  (err);
				return;
			}
			if (currentMsg.targetPeerIDs == "*") {				
				if (game.lounge.leaderIsMe) {
					//TODO: move this functionality to Dealer class
					broadcastDealerCommunityCards(cards);
					return;
				}
			}
			var payload:Object = new Object();		
			for (var count:uint = 0; count < cards.length; count++) {
				var currentCryptoCard:String = new String(cards[count] as String);
				payload[count] = currentCryptoCard;
			}			
			currentMsg.data.payload = payload;
			game.lounge.clique.broadcast(currentMsg);
			game.log.addMessage(currentMsg);
			_peerMessageHandler.unblock();
		}
		
		/**
		 * Handles BETTING_DONE events dispatched by a PokerBettingModule instance. The game
		 * phase is adjusted as appropriate and onFinalBet is invoked at the end of a round.
		 * 
		 * @param	eventObj An event object dispatched by a PokerBettingModule instance.
		 */
		protected function onBettingComplete(eventObj:PokerBettingEvent):void 
		{
			DebugView.addText  ("Player.onBettingComplete("+eventObj+")");
			var phasesNode:XML = game.settings["getSettingsCategory"]("gamephases");
			try {
				var currentPhaseNode:XML = phasesNode.children()[game.gamePhase] as XML;
			} catch (err:*) {
				currentPhaseNode = null;
			}
			if (currentPhaseNode == null) {				
				DebugView.addText(" All game phases complete.");
				game.bettingModule.onFinalBet();
				return;
			}
			DebugView.addText  (" Game phase #" + game.gamePhase+" - "+currentPhaseNode.@name);
			_peerMessageHandler.unblock();
		}		
		
		/**
		 * Handles BETTING_FINAL_DONE events dispatched from the PokerBettingModule. The current
		 * player/private and community/public cards are analyzed and broadcastGameResults is
		 * incoked in the current PokerBettingModule instance.
		 * 
		 * @param	eventObj An event disatched from a PokerBettingModule instance.
		 */
		protected function onFinalBettingComplete(eventObj:PokerBettingEvent):void 
		{			
			DebugView.addText  ("Player.onFinalBettingComplete("+eventObj+")");			
			_peerMessageHandler.unblock();
			//analyze hands
			var handDefs:XML = game.settings["getSettingsCategory"]("hands");
			_pokerHandAnalyzer = new PokerHandAnalyzer(game.playerCards, game.communityCards, handDefs);
			var keychain:Vector.<ISRAKey> = new Vector.<ISRAKey>(); //for future drop out support
			keychain[0] = key;
			game.bettingModule.broadcastGameResults(_pokerHandAnalyzer, keychain);
		}		
		
		/**
		 * To be overriden by extending Dealer class.
		 */
		protected function startCommunityCardsSelection():void 
		{
			DebugView.addText  ("Player.startCommunityCardsSelection - Player can't invoke startCommunityCardsSelection -- method must be overloaded by extending Dealer class.");
		}			
		
		/**
		 * Begins the asynchronous selection of player/private cards from the dealerCards array. This functionality may
		 * be extended to allow the player to manually choose encrypted card values instead of the current automated
		 * system.
		 * 
		 * @param	numCards The number of private cards to pick.
		 */
		protected function pickPlayerHand(numCards:Number):void
		{
			DebugView.addText  ("Player.pickPlayerHand(" + numCards+")");
			var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onPickPlayerHand);
			_cardsToChoose = numCards;
			//multiply by 8x4=32 since we're using bits, 4 bytes per random value.
			var msg:WorkerMessage = cryptoWorker.generateRandom((numCards*32), false, 16);
		}
		
		/**
		 * Event handler invoked when a cryptographically secure pseudo-random value is generated
		 * by the CryptoWorker for player/private card selection.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		protected function onPickPlayerHand(eventObj:CryptoWorkerHostEvent):void 
		{
			DebugView.addText  ("Player.onPickPlayerHand("+eventObj+")");
			eventObj.target.removeEventListener(CryptoWorkerHostEvent.RESPONSE, onPickPlayerHand);
			var randomStr:String = eventObj.data.value;			
			if (randomStr == null) {
				pickPlayerHand(_cardsToChoose);
				return;
			}
			heldCards = new Array();
			randomStr = randomStr.substr(2); //we know this is a "0x" hex value		
			for (var count:Number = 0; count < _cardsToChoose; count++) {
				var rawIndexStr:String = randomStr.substr(0, 4); //random generated 4 byte value...
				var rawIndex:uint = uint("0x" + rawIndexStr); //...converted into a uint...
				var indexMod:Number = rawIndex % dealerCards.length; //...and modulus-ed with the available deck length...
				var splicedCards:Array = dealerCards.splice(indexMod, 1); //...creates a random index into the existing deck...
				heldCards.push(splicedCards[0] as String); //...which points to a card that's now ours.
				randomStr = randomStr.substr(3); //strip off the first four bytes now that we're done with them.
			}
			DebugView.addText (" Cards chosen: "+heldCards.length);
			DebugView.addText (" Remaining dealer cards available: " + dealerCards.length);			
			var currentMsg:IPeerMessage = _currentActiveMessage;			
			try {
				currentMsg.updateSourceTargetForRelay(); //if no targets available after this, broadcast method should broadcast to all "*"
			} catch (err:*) {
				DebugView.addText (err);
				return;
			}			
			var payload:Object = new Object();
			payload.cards = new Array();
			payload.pick = _cardsToChoose;
			for (var count1:uint = 0; count1 < dealerCards.length; count1++) {
				var currentCryptoCard:String = new String(dealerCards[count1] as String);
				payload.cards[count1] = currentCryptoCard;
			}			
			currentMsg.data.payload = payload;			
			game.lounge.clique.broadcast(currentMsg);
			game.log.addMessage(currentMsg);			
			startDecryptPlayerHand(heldCards);
		}
		
		/**
		 * Begins the asynchronous operation of decrypting a player/private hand as part of a multi-party
		 * computation.
		 * 
		 * @param	cards List of numeric strings representing the encrypted card values to decrypt.
		 */
		protected function decryptPlayerHand(cards:Array):void 
		{
			DebugView.addText("Player.decryptPlayerHand: " + cards);
			_workCards = cards;
			_workCardsComplete = new Array();
			var cardLength:uint = _workCards.length;
			for (var count:uint = 0; count < cardLength; count++) {
				var currentCCard:String = _workCards[count] as String;
				DebugView.addText  ("  Decrypting card #"+count+": " + currentCCard);
				var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onDecryptPlayerCard);
				var msg:WorkerMessage = cryptoWorker.decrypt(currentCCard, key, 16);				
			}			
		}
		
		/**
		 * Handles a decryption completion event from a CryptoWorker while decrypting player/private cards. 
		 * Once all cards are decrypted and ff this is the final peer designated for the operation then the cards 
		 * are stored as the player's private cards, otherwise they are relayed to the next peer for further 
		 * decryption.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		protected function onDecryptPlayerCard(eventObj:CryptoWorkerHostEvent):void 
		{
			DebugView.addText ("Player.onDecryptPlayerCard: " + eventObj.data.result);
			DebugView.addText (" Operation took " + eventObj.message.elapsed + " ms");
			_workCardsComplete.push(eventObj.data.result);			
			DebugView.addText  ("   Cards completed: "+_workCardsComplete.length);
			if (_workCards.length == _workCardsComplete.length) {
				_workCards = null;
				clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onDecryptPlayerCard);
				var currentMsg:IPeerMessage = _currentActiveMessage;
				try {
					currentMsg.updateSourceTargetForRelay(); //if no targets available after this, broadcast method should broadcast to all "*"
				} catch (err:*) {
					DebugView.addText  (err);
					return;
				}
				if (currentMsg.targetPeerIDs == "*") {
					DebugView.addText("   Player cards decrypted.");
					var playerCards:Vector.<ICard> = new Vector.<ICard>();
					for (var count:uint = 0; count < _workCardsComplete.length; count++) {		
						var cardMap:String = _workCardsComplete[count] as String;
						var currentCard:ICard = game.currentDeck.getCardByMapping(cardMap);
						if (currentCard!=null) {
							playerCards.push(currentCard);
							DebugView.addText("    Card class #" + count +": " + currentCard.frontClassName);
						}
					}
					game.addToPlayerCards(playerCards);
					if (game.lounge.leaderIsMe) {
						selectCommunityCards();
					}
				} else {
					DebugView.addText("   Sending to next player for decryption.");
					var payload:Object = new Object();
					for (count = 0; count < _workCardsComplete.length; count++) {
						var currentCryptoCard:String = new String(_workCardsComplete[count] as String);
						payload[count] = currentCryptoCard;
					}			
					currentMsg.data.payload = payload;
					game.lounge.clique.broadcast(currentMsg);
					game.log.addMessage(currentMsg);
				}
				_peerMessageHandler.unblock();
			}
		}
		
		/**
		 * Begins an asynchronous operation to decrypt the player's private cards via
		 * multi-party computation.
		 * 
		 * @param	cards A list of numeric strings representing the chosen encrypted cards.
		 */
		protected function startDecryptPlayerHand(cards:Array):void 
		{
			DebugView.addText  ("Player.startDecryptPlayerHand: " + cards);
			var currentMsg:PokerCardGameMessage = new PokerCardGameMessage();
			var payload:Array = new Array();
			for (var count:uint = 0; count < cards.length; count++) {
				var currentCryptoCard:String = new String(cards[count] as String);
				payload[count] = currentCryptoCard;
			}
			currentMsg.createPokerMessage(PokerCardGameMessage.PLAYER_DECRYPTCARDS, payload);			
			var SMOList:Vector.<INetCliqueMember> = game.getSMOShiftList();
			SMOList = game.adjustSMOList(SMOList, game.SMO_SHIFTSELFTOEND);			
			currentMsg.setTargetPeerIDs(SMOList);			
			game.lounge.clique.broadcast(currentMsg);
			game.log.addMessage(currentMsg);
			_peerMessageHandler.unblock();
		}
		
		/**
		 * Begins an asynchronous operation to encrypt the dealer deck. Both the dealerDeck and key
		 * objects must exist and contain valid data prior to invoking this function.
		 */
		protected function encryptDealerDeck():void 
		{			
			DebugView.addText  ("Player.encryptDealerDeck");
			var cardsToEncrypt:Array=new Array();
			for (var count:uint = 0; count < dealerCards.length; count++) {
				cardsToEncrypt.push(dealerCards[count] as String);
			}
			DebugView.addText  (" Cards to encrypt: " + cardsToEncrypt.length);
			dealerCards = new Array();
			for (count = 0; count < cardsToEncrypt.length; count++) {
				var currentCCard:String = cardsToEncrypt[count] as String;
				DebugView.addText  ("  Encrypting card #"+(count+1)+": " + currentCCard);
				var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onEncryptCard);
				cryptoWorker.directWorkerEventProxy = onEncryptCardProxy;
				var msg:WorkerMessage = cryptoWorker.encrypt(currentCCard, key, 16);					
			}
		}
		
		/**
		 * Event handler for CryptoWorker events dispatched after dealer card (deck) encryption operations.
		 * Once all dealer cards have been encrypted they are shuffled using the shuffleDealerCards function.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost instance.
		 */
		protected function onEncryptCard(eventObj:CryptoWorkerHostEvent):void 
		{
			dealerCards.push(eventObj.data.result);
			var percent:Number = dealerCards.length / game.currentDeck.size;
			DebugView.addText  ("Player.onEncryptCard #"+dealerCards.length+" ("+Math.round(percent*100)+"%)");
			DebugView.addText  (" Operation took " + eventObj.message.elapsed + " ms");
			if (dealerCards.length == game.currentDeck.size) {
				clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptCard);
				shuffleDealerCards(shuffleCount, broadcastPlayerEncryptedDeck);
			}
		}
		
		public function onEncryptCardProxy(eventObj:CryptoWorkerHostEvent):void
		{
			onEncryptCard(eventObj);
		}
		
		/**
		 * Broadcasts the encrypted and shuffled dealer cards (deck) to the next peer.
		 */
		protected function broadcastPlayerEncryptedDeck():void 
		{
			DebugView.addText  ("Player.broadcastPlayerEncryptedDeck");
			var currentMsg:IPeerMessage = _currentActiveMessage;
			currentMsg.updateSourceTargetForRelay();
			var payload:Array = new Array();			
			for (var count:uint = 0; count < dealerCards.length; count++) {				
				var currentCryptoCard:String = new String(dealerCards[count] as String);	
				payload[count] = currentCryptoCard;
			}
			currentMsg.data.payload = payload;
			game.lounge.clique.broadcast(currentMsg);				
			game.log.addMessage(currentMsg);						 
			_peerMessageHandler.unblock();
		}
		
		/**
		 * Clears all event listeners of a specific type of CryptoWorkerHost event.
		 * 
		 * @param	eventType The event type to clear all listeners for.
		 * @param	responder The responder function currently assigned as the event handler.
		 */
		protected function clearAllCryptoWorkerHostListeners(eventType:String, responder:Function):void 
		{
			var maxWorkers:uint = game.lounge.settings["getSettingData"]("defaults", "maxcryptoworkers");
			maxWorkers++; //this ensures that all workers are accounted for
			for (var count:uint = 0; count < maxWorkers; count++) {
				try {
					var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;	
					cryptoWorker.directWorkerEventProxy = null;
					cryptoWorker.removeEventListener(eventType, responder);					
				} catch (err:*) {					
				}
			}
		}		
	}
}
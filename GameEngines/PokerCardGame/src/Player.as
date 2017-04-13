/**
* Base player class.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package {
	
	import feathers.controls.Alert;
	import feathers.data.ListCollection;
	import flash.events.EventDispatcher;
	import crypto.events.SRAMultiKeyEvent;
	import crypto.SRAKey;
	import interfaces.IPlayer;	
	import events.PokerBettingEvent;
	import interfaces.IPokerPlayerInfo;
	import EthereumTransactions;
	import EthereumMessagePrefix;
	import org.cg.WorkerMessageFilter;
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.PeerMessageHandler;
	import p2p3.events.PeerMessageHandlerEvent;
	import org.cg.BaseCardGame;
	import PokerCardGame;
	import org.cg.interfaces.ICard;
	import org.cg.Card;
	import org.cg.CardDeck;
	import p2p3.workers.CryptoWorkerHost;
	import p2p3.interfaces.IPeerMessage;
	import p2p3.events.NetCliqueEvent;	
	import p2p3.workers.events.CryptoWorkerHostEvent;
	import events.PokerGameStatusEvent;
	import p2p3.workers.WorkerMessage;	
	import org.cg.events.SmartContractEvent;
	import org.cg.SmartContract;
	import org.cg.SmartContractDeferState;
	import org.cg.SmartContractFunction;
	import crypto.interfaces.ISRAMultiKey;
	import crypto.SRAMultiKey;
	import PokerBettingModule;
	import org.cg.DebugView;
	import p2p3.PeerMessageLog;
	import PokerHandAnalyzer;
	import org.cg.StarlingViewManager;
	import starling.events.Event;
	import flash.utils.setTimeout;
	
	public class Player extends EventDispatcher implements IPlayer {
		
		public var game:PokerCardGame; //reference to game instance		
		public var dealerCards:Array = new Array(); //available face-down (encypted) dealer cards; array will shrink as selections are made
		public var communityCards:Array = new Array(); //face-up (decrypted) community cards
		public var heldCards:Array = new Array(); //face-up held/private cards
		protected static const _defaultShuffleCount:uint = 3; //the default number of times to shuffle cards in a shuffle operation
		protected static var _instances:uint = 0; //number of active instances
		protected var _keychain:Vector.<ISRAMultiKey> = new Vector.<ISRAMultiKey>(); //all of the player's keys for the round, most recent first
		protected var _peerMessageHandler:PeerMessageHandler = null; //reference to a PeerMessageHandler instance
		protected var _messageLog:PeerMessageLog; //reference to a peer message log instance
		protected var _errorLog:PeerMessageLog; //reference to a peer message error log instance
		protected var _currentActiveMessage:IPeerMessage; //peer message currently being processed		
		protected var _encryptedDeck:Array = new Array(); //most current full deck (encrypted); unlike dealerCards this array will not shrink with selections
		protected var _cryptoOperationLoops:uint = 4; //the number of times each card should be encrypted
		protected var _IPCryptoOperations:Array = new Array(); //In-Progress Crypto Operations
		protected var _messageFilter:WorkerMessageFilter; //used to filter messages not currently being processed by this instance
		protected var _totalComparisonDeck:Vector.<String> = null; //generated comparison deck, used during rekeyeing operations
		protected var _smartContractDecryptPhase:uint = 0; //decrypt phase (index) to use with smart contract deferred invocations
		protected var _transactions:EthereumTransactions; //manages received Ethereum transactions to be used in case of challenges		
		private var _workCards:Array = new Array(); //cards currently being worked on (encryption, decryption, etc.)
		private var _workCardsComplete:Array = new Array(); //completed work cards		
		private var _postCardShuffle:Function = null; //function to invoke after a shuffle operation completes
		private var _postCardDecrypt:Function = null; //function to invoke after card operations complete				
		private var _cardsToChoose:Number = 0; //used during card selection to track # of cards to choose		
		private var _pokerHandAnalyzer:PokerHandAnalyzer = null; //used post-round to analyze hands
		private var _rekeyOperationActive:Boolean = false; //is a rekeying operation currently in progress?		
				
		/**
		 * Creates a new Player instance.
		 * 
		 * @param	gameInstance A reference to the containing PokerCardGame instance.
		 * @param	isDealer Player is a dealer type (used by extending Dealer class).
		 */
		public function Player(gameInstance:PokerCardGame) {
			_instances++;
			game = gameInstance;
			this._transactions = new EthereumTransactions();
			this._messageFilter = new WorkerMessageFilter();
			super (this);
		}
		
		/**
		 * A reference to the peer message handler instance in use by this instance.
		 */
		public function set peerMessageHandler(handlerSet:PeerMessageHandler):void {
			this._peerMessageHandler = handlerSet;
		}
		
		public function get peerMessageHandler():PeerMessageHandler {
			return (this._peerMessageHandler);
		}

		/**
		 * The crypto keys currently being used by the player.
		 */
		public function set key(keySet:ISRAMultiKey):void {			
			_keychain[0] = keySet;
			/*
			if (_keychain[0].securable) {				
				//key is securable (may not be secured)
			} else {
				//key is not securable
			}
			*/
		}
		
		public function get key():ISRAMultiKey {			
			return (_keychain[0]);
		}
		
		/**
		 * @return The player's keychain for the current round.
		 */
		public function get keychain():Vector.<ISRAMultiKey> {
			return (_keychain);
		}
		
		/**
		 * @return True if a rekeyeing operation is currently active, usually as a result of a player disconnect.
		 * Most game functionality should be disabled until this value is false.
		 */
		public function get rekeyOperationActive():Boolean {
			return (_rekeyOperationActive);
		}
	
		/**
		 * Resets the game phase, creates new peer message logs and peer message handler, and enables game message handling.
		 * 
		 * @param useEventDispatch If true a PokerGameStatusEvent.START event will be dispatched, otherwise no such event will be dispatche
		 * (such as when this function is being called via an extending Dealer instance).
		 */
		public function start(useEventDispatch:Boolean = true):void {			
			DebugView.addText ("************");
			DebugView.addText ("Player.start");
			DebugView.addText ("************");
			if (useEventDispatch) {
				game.dispatchStatusEvent(PokerGameStatusEvent.START, this, {dealer:false});
			}
			game.gamePhase = 0;			
			//Uncomment below and other sections in this class to enable message logging.
			//_messageLog = new PeerMessageLog();
			//_errorLog = new PeerMessageLog();
			//_peerMessageHandler = new PeerMessageHandler(_messageLog, _errorLog);			
			if (_peerMessageHandler == null) {
				_peerMessageHandler = new PeerMessageHandler();
			}
			enableGameMessaging();			
		}
		
		/**
		 * Begins an asynchronous, cryptographically secure, pseudo-random shuffle operation on the cards in the 
		 * dealerCards array.
		 * 
		 * @param	loops The number of shuffles to apply to the dealerCards array.
		 * @param	postShuffle The function to invoke when the shuffle operation(s) complete.
		 */
		public function shuffleDealerCards(loops:uint = 1, postShuffle:Function = null):void {
			var tempCards:Array = new Array();
			_postCardShuffle = postShuffle;
			var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateRandomShuffle);
			cryptoWorker.directWorkerEventProxy = onGenerateRandomShuffleProxy;
			game.dispatchStatusEvent(PokerGameStatusEvent.SHUFFLE_DECK, this, {shuffleCount:loops});
			//multiply by 8x4=32 since we're using bits, 4 bytes per random value for a good range (there should be a more flexible/generic way to do this);
			//also see onGenerateRandomShuffle for how this is handled once generated
			var msg:WorkerMessage = cryptoWorker.generateRandom((dealerCards.length * 32) * loops, false, 16);
			this._messageFilter.addMessage(msg);
		}
		
		/**
		 * Intended to be overriden by extending Dealer class.
		 */
		public function selectCommunityCards():void {
			//nothing to do
		}
		
		/**
		 * Continues the asynchronous operation of decrypting a player/private hand as part of a multi-party
		 * computation.
		 * 
		 * @param	cards List of numeric strings representing the encrypted card values to decrypt.
		 */
		public function decryptPlayerHand(cards:Array):void {
			_workCards = cards;
			_workCardsComplete = new Array();
			var cardLength:uint = _workCards.length;
			this._IPCryptoOperations = new Array();
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onDecryptPlayerCard);
			for (var count:uint = 0; count < cardLength; count++) {
				var currentCCard:String = _workCards[count] as String;
				var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onDecryptPlayerCard);
				var msg:WorkerMessage = cryptoWorker.decrypt(currentCCard, key.getKey(this._cryptoOperationLoops - 1), 16);
				this._messageFilter.addMessage(msg);
				this._IPCryptoOperations[msg.requestId] = this._cryptoOperationLoops;
			}			
		}

		/**		 		
		 * Begins the process of regenerating player keys, usually as a result of a player drop-out.
		 */
		public function regeneratePlayerKeys():void	{							
			for (var count:int = 0; count < game.bettingModule.allPlayers.length; count++) {				
				var currentPlayer:IPokerPlayerInfo = game.bettingModule.allPlayers[count];
					currentPlayer.comparisonDeck = null;
			}
			var CBL:uint = game.lounge.maxCryptoByteLength * 8; //parameter is in bits
			var currentPrime:String = key.getKey(0).modulusHex;
			var newKey:SRAMultiKey = new SRAMultiKey();
			newKey.addEventListener(SRAMultiKeyEvent.ONGENERATEKEYS, this.onRegenerateKeys);
			this.key = newKey;
			game.dispatchStatusEvent(PokerGameStatusEvent.GEN_KEYS, this, {numKeys:this._cryptoOperationLoops, CBL:CBL, modulus:currentPrime});
			newKey.generateKeys(CryptoWorkerHost.getNextAvailableCryptoWorker, this._cryptoOperationLoops, CBL, currentPrime);
		}
		
		/**
		 * Enable event listeners for the instance.
		 */
		public function enableGameMessaging():void {
			disableGameMessaging(); //prevents multiple listeners			
			game.bettingModule.addEventListener(PokerBettingEvent.BETTING_DONE, onBettingComplete);
			game.bettingModule.addEventListener(PokerBettingEvent.BETTING_FINAL_DONE, onFinalBettingComplete);
			game.clique.addEventListener(NetCliqueEvent.PEER_DISCONNECT, onPeerDisconnect);
			_peerMessageHandler.addToClique(game.table.clique);
			_peerMessageHandler.addEventListener(PeerMessageHandlerEvent.PEER_MSG, onPeerMessage);
			_peerMessageHandler.unblock();
		}
		
		/**
		 * Disable event listeners for instance.
		 */
		public function disableGameMessaging():void	{
			game.bettingModule.removeEventListener(PokerBettingEvent.BETTING_DONE, onBettingComplete);
			game.bettingModule.removeEventListener(PokerBettingEvent.BETTING_FINAL_DONE, onFinalBettingComplete);
			game.clique.removeEventListener(NetCliqueEvent.PEER_DISCONNECT, onPeerDisconnect);			
			_peerMessageHandler.block();
			_peerMessageHandler.removeEventListener(PeerMessageHandlerEvent.PEER_MSG, onPeerMessage);
		}
		
		/**
		 * Handles events from the PeerMessageHandler.
		 * 
		 * @param	eventObj An event from the PeerMessageHandler.
		 */
		public function onPeerMessage(eventObj:PeerMessageHandlerEvent):void {
			try {
				processPeerMessage(eventObj.message);
			} catch (err:*) {
				DebugView.addText("Player.onPeerMessage ERROR: " + err);
			}
		}		

		/**
		 * Proxy function for onGenerateRandomShuffle intended to be called by a CryptoWorker in direct mode.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		public function onGenerateRandomShuffleProxy(eventObj:CryptoWorkerHostEvent):void {
			onGenerateRandomShuffle(eventObj);
		}
		
		
		/**
		 * Proxy function for onEncryptCard intended to be called by a CryptoWorker in direct mode.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */	
		public function onEncryptCardProxy(eventObj:CryptoWorkerHostEvent):void	{
			onEncryptCard(eventObj);
		}
		
		/**
		 * Proxy function for onGenerateContractCard intended to be called by a CryptoWorker in direct mode.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		public function onGenerateContractCardProxy(eventObj:CryptoWorkerHostEvent):void {				
			onGenerateContractCard(eventObj);
		}

		/**
		 * Destroys the instance and its data, usually before references to it are removed for garbage collection.
		 * 
		 * @param	transferToDealer If true only unneeded references and event listeners are removed such as when the
		 * instance is being transferred to a new Dealer instance, otherwise all data is scrubbed such as at the end of
		 * a round.
		 */
		public function destroy(transferToDealer:Boolean=false):void {			
			disableGameMessaging();
			_encryptedDeck = null;
			game.deferStates = null;			
			this._messageFilter.destroy();
			this._messageFilter = null;
			_currentActiveMessage = null;
			_pokerHandAnalyzer = null;			
			if (transferToDealer == false) {
				_currentActiveMessage = null;
				_pokerHandAnalyzer = null;
			}
			_instances--;
		}
		
		/**
		 * Initializes the instance by copying name-matched properties from the supplied parameter to
		 * internal values and enabling game messaging. For example: 
		 * encryptionProgressCount=initObject.encryptionProgressCount. 
		 * No type checking is done on the included properties.
		 * 
		 * @param	initObject Contains name-matched properties to copy to this instance.
		 */
		protected function initialize(initObject:Object):void {			
			for (var item:* in initObject) {
				try {		
					this[item] = initObject[item];
				} catch (err:*) {					
				}
			}
			enableGameMessaging();			
		}
		
		/**
		 * @return The number of times a shuffle operation should be carried out on cards, as defined in the
		 * settings data, or the _defaultShuffleCount value if not defined.
		 */
		protected function get shuffleCount():uint {
			var shuffleStr:String = game.settings["getSettingData"]("defaults", "shufflecount");
			if ((shuffleStr!=null) && (shuffleStr!="")) {
				var shuffleTimes:uint = uint(shuffleStr);
			} else {
				shuffleTimes = _defaultShuffleCount;
			}
			return (shuffleTimes);		
		}
		
		/**
		 * Handles peer disconnections and begins a rekeying operation.
		 * 
		 * @param	eventObj Event dispatched from the NetClique.
		 */
		protected function onPeerDisconnect(eventObj:NetCliqueEvent):void {
			_rekeyOperationActive = true;
			_peerMessageHandler.block();
			var playerInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(eventObj.memberInfo);
			if (playerInfo == null) {
				//don't re-key since dropped-out peer is not an active player
				_rekeyOperationActive = false;
				_peerMessageHandler.unblock();
				return;
			}
			if (game.bettingModule.gameHasEnded) {
				return;
			}
			//must be done before removing player
			if (game.bettingModule.allPlayers.length <= 2) {
				game.bettingModule.disable();				
				return;
			}
			//stop any current crypto operation(s) in progress if another player drops out during re-keying
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGenerateRandomShuffle);			
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGenerateKeys);	
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onDecryptCommunityCard);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onPickPlayerHand);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onDecryptPlayerCard);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptCard);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onRegenerateKeys);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptComparisonCard);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onReencryptComparisonCard);
			var wasDealer:Boolean = false;
			if (game.bettingModule.selfPlayerInfo != null) {
				if (game.bettingModule.currentDealerMember.peerID==game.bettingModule.selfPlayerInfo.netCliqueInfo.peerID) {
					wasDealer = true;
				}
			}
			game.bettingModule.pause();
			game.bettingModule.removePlayer(eventObj.memberInfo.peerID, true);
			if (game.bettingModule.allPlayers.length < 2) {
				return;
			}
			var amDealer:Boolean = false;
			if (game.bettingModule.selfPlayerInfo != null) {
				if (game.bettingModule.currentDealerMember.peerID == game.bettingModule.selfPlayerInfo.netCliqueInfo.peerID) {
					amDealer = true;
					game.table.currentDealerPeerID = game.bettingModule.selfPlayerInfo.netCliqueInfo.peerID;
				}
			}
			if (wasDealer != amDealer) {
				if (amDealer) {
					switchToDealer("regeneratePlayerKeys");
				} else {
					var err:Error = new Error("Dealer role lost after update.");
					throw (err);
				}				
			} else {			
				regeneratePlayerKeys();
			}
		}		
		
		/**
		 * Invoked when a new keys are generated as part of a re-keyeing operation.
		 * 
		 * @param	eventObj Event dispatched from a SRAMultiKey instance.
		 */
		protected function onRegenerateKeys(eventObj:SRAMultiKeyEvent):void {
			eventObj.target.removeEventListener(SRAMultiKeyEvent.ONGENERATEKEYS, this.onRegenerateKeys);
			var keychainLength:uint = unshiftKeychain();
			key = ISRAMultiKey(eventObj.target);
			game.dispatchStatusEvent(PokerGameStatusEvent.NEW_KEYS, this, {keys:key, keychain:_keychain});
			generateComparisonDeck();		
		}
		
		/**
		 * Generates a comparison card deck used to establish a new deck during rekeying operations.
		 */
		protected function generateComparisonDeck():void {
			var cardsToEncrypt:Array = new Array();
			_totalComparisonDeck = new Vector.<String>();			
			for (var count:int = 0; count < game.currentDeck.allCards.length; count++) {
				//copy all cards from existing deck to totalDeck
				_totalComparisonDeck.push(game.currentDeck.getMappingByCard(game.currentDeck.allCards[count]));
			}			
			if (game.playerCards != null) {
					//remove player/private cards from totalDeck
					for (count = 0; count < game.playerCards.length; count++) {
						var currentPlayerCard:String = game.currentDeck.getMappingByCard(game.playerCards[count]);
						for (var count2:int = 0; count2 < _totalComparisonDeck.length; count2++) {							
							if (_totalComparisonDeck[count2] == currentPlayerCard) {
								_totalComparisonDeck.splice(count2, 1);
							}
						}										
					}
				}
			if (game.communityCards != null) {
				//remove community/public cards from totalDeck
				for (count = 0; count < game.communityCards.length; count++) {
					currentPlayerCard = game.currentDeck.getMappingByCard(game.communityCards[count]);
					for (count2 = 0; count2 < _totalComparisonDeck.length; count2++) {							
						if (_totalComparisonDeck[count2] == currentPlayerCard) {
							_totalComparisonDeck.splice(count2, 1);
						}
					}
				}
			}
			dealerCards = new Array();
			this._IPCryptoOperations = new Array();
			for (count = 0; count < _totalComparisonDeck.length; count++) {
				var currentCCard:String = _totalComparisonDeck[count];
				var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onEncryptComparisonCard);
				game.dispatchStatusEvent(PokerGameStatusEvent.ENCRYPT_CARD, this, {card:currentCCard, key:key.getKey(this._cryptoOperationLoops - 1)});
				var msg:WorkerMessage = cryptoWorker.encrypt(currentCCard, key.getKey(this._cryptoOperationLoops - 1), 16);
				this._messageFilter.addMessage(msg);
				this._IPCryptoOperations[msg.requestId] = this._cryptoOperationLoops;
			}
		}
		
		/**
		 * Event responder that handles the encryption of a single comparison card used in a re-keying operation.
		 * 
		 * @param	eventObj Event object dispatched by a CryptoWorkerHost.
		 */
		protected function onEncryptComparisonCard(eventObj:CryptoWorkerHostEvent):void	{
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			var requestId:String = eventObj.message.requestId;
			this._IPCryptoOperations[requestId]--;
			if (this._IPCryptoOperations[requestId] > 0) {
				var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onEncryptComparisonCard);
				game.dispatchStatusEvent(PokerGameStatusEvent.ENCRYPT_CARD, this, {card:eventObj.data.result, key:key.getKey(this._IPCryptoOperations[requestId] - 1)});
				var msg:WorkerMessage = cryptoWorker.encrypt(eventObj.data.result, key.getKey(this._IPCryptoOperations[requestId] - 1), 16);
				this._messageFilter.addMessage(msg);
				this._IPCryptoOperations[msg.requestId] = this._IPCryptoOperations[requestId];
				return;
			}
			game.dispatchStatusEvent(PokerGameStatusEvent.ENCRYPTED_CARD, this, {card:eventObj.data.result});
			dealerCards.push(eventObj.data.result);
			var percent:Number = dealerCards.length / _totalComparisonDeck.length;
			try {				
				if (dealerCards.length == _totalComparisonDeck.length) {
					clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptComparisonCard);
					shuffleDealerCards(shuffleCount, broadcastPlayerComparisonDeck);
				}
			} catch (err:*) {
				DebugView.addText(err);
			}
		}
		
		/**
		 * Broadcasts the partially encrypted and shuffled comparison deck to peers to continue encryption during a 
		 * re-keying operation.
		 */
		protected function broadcastPlayerComparisonDeck():void	{
			var msg:PokerCardGameMessage = new PokerCardGameMessage();			
			var payload:Array = new Array();			
			for (var count:int = 0; count < dealerCards.length; count++) {
				var currentCryptoCard:String = new String(dealerCards[count] as String);
				payload[count] = currentCryptoCard;				
			}
			msg.createPokerMessage(PokerCardGameMessage.PLAYER_DECKRENECRYPTED, payload);						
			var peerList:Vector.<INetCliqueMember> = new Vector.<INetCliqueMember>();
			//dropped-out player(s) should already be removed from betting module at this point
			var allPlayers:Vector.<IPokerPlayerInfo> = game.bettingModule.allPlayers;			
			for (count = 0; count < allPlayers.length; count++) {				
				peerList.push(allPlayers[count].netCliqueInfo);
			}			
			//next player is shifted to end to more evenly distribute multi-party operation load, must be done before removing self
			peerList = game.adjustSMOList(peerList, PokerCardGame.SMO_SHIFTNEXTPLAYERTOEND);			
			peerList = game.adjustSMOList(peerList, PokerCardGame.SMO_REMOVESELF); //already encrypted			
			for (count = 0; count < peerList.length; count++) {
				var playerInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(peerList[count]);
				if (playerInfo != null) {
					msg.addTargetPeerID(peerList[count].peerID);					
				}				
			}			
			game.clique.broadcast(msg);
			game.log.addMessage(msg);
			_currentActiveMessage = null;
			_peerMessageHandler.unblock();
		}
		
		/**
		 * Continues the multi-party rencryption of another player's comparison deck.
		 * 
		 * @param	currentDeck An array containing the encrypted card deck values as numeric strings.
		 */
		protected function continueComparisonDeckEncrypt(currentDeck:Array):void {
			_peerMessageHandler.block();
			dealerCards = new Array();
			_totalComparisonDeck = new Vector.<String>();
			this._IPCryptoOperations = new Array();
			for (var count:int = 0; count < currentDeck.length; count++) {
				_totalComparisonDeck.push(String(currentDeck[count]));
			}			
			for (count = 0; count < _totalComparisonDeck.length; count++) {
				var currentCCard:String = _totalComparisonDeck[count];
				var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onReencryptComparisonCard);
				game.dispatchStatusEvent(PokerGameStatusEvent.ENCRYPT_CARD, this, {card:currentCCard, key:key.getKey(this._cryptoOperationLoops - 1)});
				var msg:WorkerMessage = cryptoWorker.encrypt(currentCCard, key.getKey(this._cryptoOperationLoops - 1), 16);
				this._messageFilter.addMessage(msg);
				this._IPCryptoOperations[msg.requestId] = this._cryptoOperationLoops;
			}			
		}
		
		/**
		 * Event listener invoked when a comparison card has been re-encrypted (second or later round of encryption) during
		 * a re-keying operation.
		 * 
		 * @param	eventObj Event object dispatched by a CryptoWorkerHost.
		 */
		protected function onReencryptComparisonCard(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			var requestId:String = eventObj.message.requestId;
			this._IPCryptoOperations[requestId]--;
			if (this._IPCryptoOperations[requestId] > 0) {
				var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onReencryptComparisonCard);
				game.dispatchStatusEvent(PokerGameStatusEvent.ENCRYPT_CARD, this, {card:eventObj.data.result, key:key.getKey(this._IPCryptoOperations[requestId] - 1)});
				var msg:WorkerMessage = cryptoWorker.encrypt(eventObj.data.result, key.getKey(this._IPCryptoOperations[requestId] - 1), 16);
				this._messageFilter.addMessage(msg);
				this._IPCryptoOperations[msg.requestId] = this._IPCryptoOperations[requestId];
				return;
			}
			dealerCards.push(eventObj.data.result);
			var percent:Number = dealerCards.length / _totalComparisonDeck.length;
			try {				
				if (dealerCards.length == _totalComparisonDeck.length) {
					clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onReencryptComparisonCard);
					shuffleDealerCards(shuffleCount, rebroadcastPlayerComparisonDeck);
				}
			} catch (err:*) {
				DebugView.addText(err);
			}
		}
		
		/**
		 * Rebroadcasts a partially or fully re-encrypted, shuffled deck to either the next peer or to all peers if complete.
		 */
		protected function rebroadcastPlayerComparisonDeck():void {
			var msg:IPeerMessage = _currentActiveMessage;			
			msg.updateSourceTargetForRelay();
			var payload:Array = new Array();
			var localPlayer:IPokerPlayerInfo = null;
			if (msg.targetPeerIDs == "*") {
				var sourcePeerList:Vector.<INetCliqueMember> = msg.getSourcePeerIDList();
				localPlayer = game.bettingModule.getPlayerInfo(sourcePeerList[sourcePeerList.length - 1]);
				localPlayer.comparisonDeck = new Vector.<String>();
			}
			for (var count:int = 0; count < dealerCards.length; count++) {
				var currentCryptoCard:String = new String(dealerCards[count] as String);
				payload[count] = currentCryptoCard;
				if ((msg.targetPeerIDs == "*") && (localPlayer != null)) {
					localPlayer.comparisonDeck.push(currentCryptoCard);
				}
			}
			msg.data.payload = payload;
			game.clique.broadcast(msg);
			game.log.addMessage(msg);
			_currentActiveMessage = null;
			_peerMessageHandler.unblock();
		}
				
		/**
		 * Merges and validates fully encrypted, re-keyed comparison decks for all players and optionally assigns 
		 * the results to the current encrypted dealer deck. Re-encrypted cards that are known to already have been dealt will be
		 * excluded due to cryptographic homomorphism.
		 * 
		 * @param assignToDealerDeck If true and all validations pass the merged deck will be assigned to the dealer deck
		 * as a final step.
		 * 
		 * @return True if decks were successfully merged, false if there was a problem merging.
		 */
		protected function mergeComparisonDecks(assignToDealerDeck:Boolean=false):Boolean {
			var currentPlayer:IPokerPlayerInfo = game.bettingModule.allPlayers[0];
			if (currentPlayer.comparisonDeck == null) {
				return (false);
			}
			var cardCount:int = currentPlayer.comparisonDeck.length;			
			for (var count:int = 1; count < game.bettingModule.allPlayers.length; count++) {				
				currentPlayer = game.bettingModule.allPlayers[count];								
				//all comparison decks must exist and be the same length
				if (currentPlayer.comparisonDeck == null) {
					return (false);
				} else if (currentPlayer.comparisonDeck.length != cardCount) {
					return (false);
				}
			}
			//basic verification passed, create merged deck
			var mergedDeck:Vector.<String> = new Vector.<String>();
			currentPlayer = game.bettingModule.allPlayers[0];
			var matchCount:uint = 0;
			for (count = 0; count < currentPlayer.comparisonDeck.length; count++) {
				var currentCard:String = currentPlayer.comparisonDeck[count];
				//first card is always a match
				matchCount = 1;
				for (var count2:int = 1; count2 < game.bettingModule.allPlayers.length; count2++) {
					var nextPlayer:IPokerPlayerInfo = game.bettingModule.allPlayers[count2];
					for (var count3:int = 0; count3 < nextPlayer.comparisonDeck.length; count3++) {
						var nextCard:String = nextPlayer.comparisonDeck[count3];
						if (currentCard == nextCard) {
							matchCount++;
						}
					}
				}
				//card must be found in all players' comparison decks
				if (matchCount==game.bettingModule.allPlayers.length) {
					//card found in all decks so add it (still in dealer deck)
					mergedDeck.push(currentCard);
				}
			}
			//expected number of cards is the length of all decks minus two cards per player, omitting one
			//player already represented in the deck length
			var expectedDeckLength:int = cardCount - ((game.bettingModule.allPlayers.length - 1) * 2);			
			if (expectedDeckLength == mergedDeck.length) {
				if (assignToDealerDeck) {
					dealerCards = new Array();
					for (count = 0; count < mergedDeck.length; count++) {						
						dealerCards.push(mergedDeck[count]);
					}					
				}
				return (true);
			} else {
				return (false);
			}
		}
		
		/**
		 * Handler invoked when a CryptoWorker has generated a cryptographically secure random shuffle sequence.
		 * The generated value is used to shuffle the dealerCards array.
		 * 
		 * @param	eventObj Event dispatched from a CryptoWorkerHost.
		 */
		protected function onGenerateRandomShuffle(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
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
						DebugView.addText ("Player.onGenerateRandomShuffle - problem choosing cards.");
						DebugView.addText (err.getStackTrace());
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
				
		/**
		 * Handler invoked when a SRAMultiKey instance has generated a number of crypto key pairs.
		 * 
		 * @param	eventObj An event dispatched by a SRAMultiKey instance.
		 */
		protected function onGenerateKeys(eventObj:SRAMultiKeyEvent):void {
			eventObj.target.removeEventListener(SRAMultiKeyEvent.ONGENERATEKEYS, this.onGenerateKeys);			
			key = ISRAMultiKey(eventObj.target);	
			game.dispatchStatusEvent(PokerGameStatusEvent.NEW_KEYS, this, {keys:key, keychain:_keychain});
			_peerMessageHandler.unblock();
		}
		
		/**
		 * Inserts a new null entry at the beginning of the keychain and shifts all elements
		 * to the next index.
		 * 
		 * @return The new length of the keychain vector.
		 */
		protected function unshiftKeychain():uint {
			return(_keychain.unshift(null));
		}		

		/**
		 * Processes a received peer message. Any message that does not validate as a PokerCardGameMessage
		 * is discarded.
		 * 
		 * @param	peerMessage The IPeerMessage instance to process
		 */
		protected function processPeerMessage(peerMessage:IPeerMessage):void {						
			var peerMsg:PokerCardGameMessage = PokerCardGameMessage.validatePokerMessage(peerMessage);				
			if (peerMsg == null) {					
				//not a valid PokerCardGameMessage
				return;
			}			
			if (peerMessage.isNextSourceID(game.clique.localPeerInfo.peerID)) {
				//message came from us (we are the next source ID meaning no other peer has processed the message)
				return;
			}			
			peerMsg.timestampReceived = peerMsg.generateTimestamp();			
			if (rekeyOperationActive) {
				//process only rekey messages
				try {
					if (peerMessage.hasTargetPeerID(game.clique.localPeerInfo.peerID)) {						
						_peerMessageHandler.block();					
						switch (peerMsg.pokerMessageType) {							
							case PokerCardGameMessage.PLAYER_DECKRENECRYPTED:
								DebugView.addText("PokerCardGameMessage.PLAYER_DECKRENECRYPTED");	
								var peerList:Vector.<INetCliqueMember> = peerMessage.getSourcePeerIDList();
								var sourcePeer:INetCliqueMember = peerList[peerList.length - 1];
								if (peerMessage.isNextTargetID(game.clique.localPeerInfo.peerID)) {
									_currentActiveMessage = peerMessage;
									continueComparisonDeckEncrypt(peerMsg.data);
								} else if (peerMessage.targetPeerIDs == "*") {
									var sourcePlayer:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(sourcePeer);
									sourcePlayer.comparisonDeck = new Vector.<String>();
									for (var item:* in peerMsg.data) {
										sourcePlayer.comparisonDeck.push(String(peerMsg.data[item]));
									}
									var allComparisonDecksReceived:Boolean = true;
									for (var count:int = 0; count < game.bettingModule.allPlayers.length; count++) {
										var currentPlayer:IPokerPlayerInfo = game.bettingModule.allPlayers[count];
										if (currentPlayer.comparisonDeck == null) {
											allComparisonDecksReceived = false;
										}
									}
									if (allComparisonDecksReceived) {
										if (mergeComparisonDecks(true)) {
											_rekeyOperationActive = false;
											game.bettingModule.resume();
										} else {
											_peerMessageHandler.unblock();
											//should we retry from the beginning instead?
											var err:Error = new Error("Encrypted comparison decks couldn't be successfully merged.");
											throw (err);
										}										
									}
									_peerMessageHandler.unblock();
								} else {
									_peerMessageHandler.unblock();
								}
								break;
							default: break;
						}
					}
				} catch (err:*) {					
				} finally {
					return;
				}
			}			
			try {
				//TODO: this should work with peerMsg too but some values are not being properly copied; to investigate
				if (peerMessage.hasTargetPeerID(game.clique.localPeerInfo.peerID)) {
					//message is either for us or whole clique (*)
					_peerMessageHandler.block();					
					switch (peerMsg.pokerMessageType) {
						case PokerCardGameMessage.GAME_START:
							DebugView.addText ("PokerCardGameMessage.GAME_START");
							if (game.ethereum != null) {
								var descriptor:XML = SmartContract.findDescriptorByAddress(game.table.smartContractAddress, "ethereum", game.ethereum.client.networkID);
								if (descriptor == null) {
									try {
										descriptor = new XML(peerMessage.data.payload);
									} catch (err:*) {
										descriptor = null;
									}									
									if (descriptor == null) {
										var alertMsg:String = "Required contract information for the hand could not be found and wasn't provided by the dealer.\n";
										alertMsg += "The game can't start.";
										var buttons:ListCollection = new ListCollection([{label:"QUIT", choice:"leave"}]);
										var alert:Alert = StarlingViewManager.alert(alertMsg, "Missing contract info", buttons, null, true, true);
									} else {
										if (descriptor.child("address")[0].toString() == game.table.smartContractAddress) {
											alertMsg = "Contract at address " + game.table.smartContractAddress + " is not recorded as a verified contract for network " + String(game.ethereum.client.networkID) + ".\n";
											alertMsg += "Do you want to use the contract information provided by the dealer for only this hand, record it as a verified contract for future use, or leave this game?";
											buttons = new ListCollection([{label:"USE FOR THIS HAND", choice:"use", descriptor:descriptor},
														{label:"RECORD AS VERIFIED", choice:"record", descriptor:descriptor},
														{label:"LEAVE", choice:"leave"}]);
											alert = StarlingViewManager.alert(alertMsg, "Unrecognized contract address", buttons, null, true, true);
										} else if (descriptor.child("address").length() == 0) {
											alertMsg = "Required contract information for the hand is incomplete and insufficient to continue.\n";
											alertMsg += "The game can't start.";
											buttons = new ListCollection([{label:"QUIT", choice:"leave"}]);
											alert = StarlingViewManager.alert(alertMsg, "Incomplete contract info", buttons, null, true, true);
										} else {	
											alertMsg = "Contract at address " + game.table.smartContractAddress + " does not match the address provided for the table (" + game.table.smartContractAddress + ").\n";
											alertMsg += "For security reasons it's highly recommended that you leave the game.\n";
											alertMsg += "Do you still want to use the contract information for only this hand, record it as a verified contract for future use, or leave?";
											buttons = new ListCollection([{label:"LEAVE", choice:"leave"},
														{label:"USE FOR THIS HAND", choice:"use", descriptor:descriptor},
														{label:"RECORD AS VERIFIED", choice:"record", descriptor:descriptor}]);
											alert = StarlingViewManager.alert(alertMsg, "Mismatched contract address", buttons, null, true, true);
										}
									}
									alert.addEventListener(Event.CLOSE, this.onUnverifiedContractAlertClose);
									return;
								}
								game.smartContractBuyIn = game.ethereum.web3.toWei(game.table.buyInAmount, "ether");
								var contractName:String = descriptor.localName();
								var contract:SmartContract = new SmartContract(contractName, game.ethereumAccount, game.ethereumPassword, descriptor);
								contract.create();
								contract.previousContract = game.activeSmartContract;
								game.activeSmartContract = contract;
								//this._initializeAlert = StarlingViewManager.alert("Waiting for data contract @"+game.activeSmartContract.address+" to be initialized.", "Waiting for initialization", null, null, true, true);
							}						
							_peerMessageHandler.unblock();
							break;						
						case PokerCardGameMessage.DEALER_MODGENERATED:						
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_MODGENERATED");
							if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {	
								if (!this.verifySignedValue(EthereumMessagePrefix.PRIME, String(peerMsg.data.prime), peerMsg.data["ethTransaction"])) {
									this.waitForContractPrime(peerMsg);
									return;
								}
								this._transactions.addTransaction(peerMsg.data.ethTransaction, peerMsg);
							}								
							game.lounge.maxCryptoByteLength = uint(peerMsg.data.byteLength);
							game.dispatchStatusEvent(PokerGameStatusEvent.DEALER_NEW_MODULUS, this, {CBL:game.lounge.maxCryptoByteLength, radix:16, modulus:peerMsg.data.prime, preGen:false, elapsed:0});
							var newKey:SRAMultiKey = new SRAMultiKey();
							newKey.addEventListener(SRAMultiKeyEvent.ONGENERATEKEYS, this.onGenerateKeys);
							this.key = newKey;
							var CBL:uint = game.lounge.maxCryptoByteLength * 8;
							game.dispatchStatusEvent(PokerGameStatusEvent.GEN_KEYS, this, {numKeys: this._cryptoOperationLoops, CBL:CBL, modulus:String(peerMsg.data.prime)});
							newKey.generateKeys(CryptoWorkerHost.getNextAvailableCryptoWorker, this._cryptoOperationLoops, CBL, String(peerMsg.data.prime));
							break;
						case PokerCardGameMessage.DEALER_CARDSGENERATED:
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_CARDSGENERATED");	
							var cards:Array = peerMsg.data as Array;							
							for (count = 0; count < cards.length; count++) {
								var currentCardObj:Object = cards[count];
								if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {	
									if (!this.verifySignedValue(EthereumMessagePrefix.CARD, currentCardObj.mapping, currentCardObj.ethTransaction)) {									
										this.waitForContractCards(peerMsg);
										return;
									}
									this._transactions.addTransaction(peerMsg.data.ethTransaction, peerMsg);
								}
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
								game.currentGameVerifier.addPlaintextCard(currentCardObj.mapping);								
							}
							game.dispatchStatusEvent(PokerGameStatusEvent.NEW_DECK, this, {deck:game.currentDeck, elapsed:0});
							if (game.activeSmartContract != null) {
								//Create deferred smart contract invocation to agree to contract
								var dataObj1:Object = new Object();
								var playerList:Array = game.bettingModule.toEthereumAccounts(game.bettingModule.nonFoldedPlayersBO);
								dataObj1.requiredPlayers = playerList;
								dataObj1.modulus = key.getKey(0).modulusHex;
								dataObj1.baseCard = cards[0].mapping;
								dataObj1.agreedPlayers = new Array();
								dataObj1.agreedPlayers.push(playerList[playerList.length - 1]); //last player (dealer) must have already agreed
								dataObj1.authorizedContracts = [game.startupContract, game.actionsContract, game.signedActionsContract, game.resolutionsContract, game.validatorContract];
								var dataObj2:Object = new Object();
								var selfAccount:String = game.ethereum.getAccountByPeerID(game.clique.localPeerInfo.peerID);
								dataObj2.agreePlayers = [selfAccount];
								//Agreement will be set when the above conditions can be evaluated
								var defer1:SmartContractDeferState = new SmartContractDeferState(game.initializeDeferCheck, dataObj1, game);								
								var defer2:SmartContractDeferState = new SmartContractDeferState(game.agreeDeferCheck, dataObj1, game);
								var defer3:SmartContractDeferState = new SmartContractDeferState(game.agreeReadyDeferCheck, dataObj2, game);
								defer1.operationContract = game.activeSmartContract;
								defer2.operationContract = game.activeSmartContract;
								defer3.operationContract = game.activeSmartContract;
								var defer4:SmartContractDeferState = new SmartContractDeferState(game.isCompleteDeferCheck, null, game);
								defer4.operationContract = game.activeSmartContract;
								if (game.activeSmartContract.previousContract == null) {
									//new game
									game.activeSmartContract.agreeToContract(game.activeSmartContract.nonce).defer([defer1, defer2, defer3, defer4]).invoke({from:game.ethereumAccount, gas:1900000, value:game.smartContractBuyIn}, false, true);
								} else {
									//continuing game
									game.activeSmartContract.agreeToContract(game.activeSmartContract.nonce).defer([defer1, defer2, defer3, defer4]).invoke({from:game.ethereumAccount, gas:1900000, value:0}, false, true);
								}
							}
							_peerMessageHandler.unblock();
							break;
						case PokerCardGameMessage.PLAYER_DECRYPTCARDS:
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.PLAYER_DECRYPTCARDS");							
							try {	
								var cCards:Array = new Array();
								//we do this since the data object is a generic object, not an array as we expect at this point								
								for (item in peerMsg.data) {									
									cCards[Number(item)] = String(peerMsg.data[item].card);
									if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {	
										if (!this.verifySignedValue(EthereumMessagePrefix.PRIVATE_DECRYPT, peerMsg.data[item].card, peerMsg.data[item]["ethTransaction"])) {
											this.waitForEncryptedCards(peerMsg);
											return;
										}
										this._transactions.addTransaction(peerMsg.data[item].ethTransaction, peerMsg);
									}		
								}
							} catch (err:*) {
								DebugView.addText (err);
								return;
							}
							var sourcePeers:Vector.<INetCliqueMember> = peerMsg.getSourcePeerIDList();
							var owningPeer:INetCliqueMember = sourcePeers[sourcePeers.length - 1];
							var decryptorPeer:INetCliqueMember = peerMessage.getTargetPeerIDList()[0];
							var ownerInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(owningPeer);
							var decryptorInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(decryptorPeer);
							game.dispatchStatusEvent(PokerGameStatusEvent.DECRYPT_PRIVATE_CARDS, this, {player: ownerInfo, decryptor:decryptorInfo});
							if (peerMsg.getSourcePeerIDList().length == 1) {
								for (item in cCards) {
									game.currentGameVerifier.addPrivateCardSelection(peerMsg.getSourcePeerIDList()[0].peerID, cCards[item]);
								}
							}
							if (peerMsg.isNextTargetID(game.clique.localPeerInfo.peerID)) {								
								_currentActiveMessage=peerMessage;
								decryptPlayerHand(cCards);
							} else {
								_peerMessageHandler.unblock();
							}
							break;
						case PokerCardGameMessage.PLAYER_CARDSENCRYPTED:
							DebugView.addText ("Player.processPeerMessage -> PokerCardGameMessage.PLAYER_CARDSENCRYPTED");							
							try {							
								cCards = peerMsg.data;							
							} catch (err:*) {
								DebugView.addText (err);
								return;
							}
							dealerCards = new Array();
							_encryptedDeck = new Array(); //store the most current full deck encryption (last encrypting player updates this in broadcastPlayerEncryptedDeck)
							for (count = 0; count < cCards.length; count++) {
								var currentCCard:String = cCards[count].card as String;	
								if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {
									if (!this.verifySignedValue(EthereumMessagePrefix.ENCRYPT, currentCCard, cCards[count]["ethTransaction"])) {
										this.waitForPrivateCardDecryption(peerMsg);
										return;
									}
									this._transactions.addTransaction(cCards[count].ethTransaction, peerMsg);
								}																
								if (currentCCard!=null) {
									dealerCards[count] = currentCCard;
									_encryptedDeck.push(currentCCard);
									if (peerMsg.targetPeerIDs == "*") {
										//only add fully-encypted cards
										game.currentGameVerifier.addEncryptedCard(currentCCard);
									}
								}
							}
							if (peerMsg.isNextTargetID(game.clique.localPeerInfo.peerID)) {
								_currentActiveMessage=peerMessage;
								encryptDealerDeck();
							} else if (peerMsg.targetPeerIDs == "*") {
								if (game.table.dealerIsMe) {
									startCardsSelection();
								} else {
									_peerMessageHandler.unblock();
								}
							} else {
								_peerMessageHandler.unblock();
							}
							break;
						case PokerCardGameMessage.DEALER_PICKPRIVATECARDS:
							DebugView.addText ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_PICKPRIVATECARDS");								
							try {							
								cCards = peerMsg.data.cards;
								var selectedCards:Array = peerMsg.data.selected;
							} catch (err:*) {
								DebugView.addText (err);
								break;
							}
							dealerCards = new Array();
							for (count = 0; count < cCards.length; count++) {	
								currentCCard = cCards[count] as String;								
								if (currentCCard!=null) {
									dealerCards[count] = currentCCard;
								}
							}
							if (selectedCards.length > 0) {
								var deferDataObj:Object = new Object();
								deferDataObj.storageVariable = "privateCards";
								if (game.ethereum != null) {
									deferDataObj.fromAddress = game.ethereum.getAccountByPeerID(peerMsg.getSourcePeerIDList()[0].peerID);
								} else {
									deferDataObj.fromAddress = "0x";
								}
								deferDataObj.cards = new Array();
								for (count = 0; count < selectedCards.length; count++) {
									if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {
										if (!this.verifySignedValue(EthereumMessagePrefix.PRIVATE_SELECT, selectedCards[count].card, selectedCards[count]["ethTransaction"])) {
											this.waitForPrivateCardSelection(peerMsg);
											return;
										}
										this._transactions.addTransaction(peerMsg.data.ethTransaction, peerMsg);
									}	
									deferDataObj.cards.push(selectedCards[count].card);
								}
								var defer:SmartContractDeferState =  new SmartContractDeferState(game.encryptedCardsDeferCheck, deferDataObj, game);
								defer.operationContract = game.activeSmartContract;
								game.deferStates.push(defer);
							}
							if (peerMsg.targetPeerIDs == "*") {
								_peerMessageHandler.unblock();
							} else {
								if (peerMsg.isNextTargetID(game.clique.localPeerInfo.peerID)) {
									//player may manually select here instead...
									_currentActiveMessage = peerMessage;									
									pickPlayerHand(Number(peerMsg.data.pick));									
								} else {
									var nextPeer:INetCliqueMember = peerMsg.getTargetPeerIDList()[0];
									var playerInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(nextPeer);
									game.dispatchStatusEvent(PokerGameStatusEvent.SELECT_PRIVATE_CARDS, this, {player:playerInfo});
									_peerMessageHandler.unblock();
								}
							}
							break;
						case PokerCardGameMessage.DEALER_PICKPUBLICCARDS:
							DebugView.addText ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_PICKPUBLICCARDS");
							var deferStateObj:Object = new Object();
							deferStateObj.cards =new Array()
							cCards = new Array();
							var numCards:uint = 0;
							try {	
								for (item in peerMsg.data.selected) {
									if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {
										if (!this.verifySignedValue(EthereumMessagePrefix.PUBLIC_SELECT, peerMsg.data.selected[item].card, peerMsg.data.selected[item]["ethTransaction"])) {
											this.waitForPublicCardSelection(peerMsg);
											return;
										}
										this._transactions.addTransaction(peerMsg.data.ethTransaction, peerMsg);
									}
									cCards[Number(item)] = String(peerMsg.data.selected[item].card);
									numCards++;
									deferStateObj.cards.push(String(peerMsg.data.selected[item].card));
									game.currentGameVerifier.addPublicCardSelection(String(peerMsg.data.selected[item].card));
								}
							} catch (err:*) {
								DebugView.addText (err);
								return;
							}
							var sendingPeerID:String = peerMsg.getSourcePeerIDList()[0].peerID;
							if (sendingPeerID != game.bettingModule.currentDealerMember.peerID) {
								_peerMessageHandler.unblock();
								return;
							}
							if ((game.ethereum != null) && (game.activeSmartContract != null)) {
								var sendingAccount:String = game.ethereum.getAccountByPeerID(sendingPeerID);							
								deferStateObj.fromAddress = sendingAccount;
								deferStateObj.storageVariable = "publicCards";									
								defer = new SmartContractDeferState(game.encryptedCardsDeferCheck, deferStateObj, game);
								defer.operationContract = game.activeSmartContract;
								game.deferStates.push(defer); //push onto defer state stack to ensure stated cards exist before we commit to further actions
							}
							var dealerInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(game.bettingModule.currentDealerMember);
							game.dispatchStatusEvent(PokerGameStatusEvent.SELECT_PUBLIC_CARDS, this, {player:dealerInfo, numCards:numCards})
							_peerMessageHandler.unblock();
							break;
						case PokerCardGameMessage.DEALER_DECRYPTCARDS:						
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_DECRYPTCARDS");							
							cCards = new Array();
							var cardObjs:Array = new Array();
							try {	
								for (item in peerMsg.data) {									
									cCards[Number(item)] = String(peerMsg.data[item].card);
									cardObjs.push(peerMsg.data[item]);
									if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {
										if (!this.verifySignedValue(EthereumMessagePrefix.PUBLIC_DECRYPT, cCards[Number(item)], peerMsg.data[item]["ethTransaction"])) {
											this.waitForPublicCardDecryption(peerMsg);
											return;
										}
										this._transactions.addTransaction(peerMsg.data.ethTransaction, peerMsg);
									}
								}
							} catch (err:*) {
								DebugView.addText (err);
								return;
							}
							_currentActiveMessage = peerMessage;							
							try {
								if (peerMsg.targetPeerIDs == "*") {
									if (game.table.dealerIsMe) {
										broadcastDealerCommunityCards(cardObjs);
									} else {
										_peerMessageHandler.unblock();
									}
								} else {
									if ((game.ethereum != null) && (game.activeSmartContract != null)) {
										if (peerMsg.getTargetPeerIDList().length != game.bettingModule.nonFoldedPlayers.length) {
											sendingPeerID = peerMsg.getSourcePeerIDList()[0].peerID;
											sendingAccount = game.ethereum.getAccountByPeerID(sendingPeerID);																		
											deferStateObj = new Object();
											deferStateObj.cards = cCards;
											deferStateObj.fromAddress = sendingAccount;
											deferStateObj.storageVariable = "publicDecryptCards";
											defer = new SmartContractDeferState(game.encryptedCardsDeferCheck, deferStateObj, game);
											defer.operationContract = game.activeSmartContract;
											game.deferStates.push(defer); //push onto defer state stack to ensure stated cards exist before we commit to further actions
										}
									}
									decryptorPeer = peerMessage.getTargetPeerIDList()[0];
									var dealerPeer:INetCliqueMember = game.bettingModule.currentDealerMember;
									decryptorInfo = game.bettingModule.getPlayerInfo(decryptorPeer);
									dealerInfo = game.bettingModule.getPlayerInfo(dealerPeer);
									game.dispatchStatusEvent(PokerGameStatusEvent.DECRYPT_PUBLIC_CARDS, this, {player:dealerInfo, decryptor:decryptorInfo});
									if (peerMessage.isNextTargetID(game.clique.localPeerInfo.peerID)) {
										decryptCommunityCards(cCards, relayDecryptCommunityCards);
									} else {
										nextPeer = peerMessage.getTargetPeerIDList()[0];
										_peerMessageHandler.unblock();
									}
								}							
							} catch (err:*) {								
								DebugView.addText (err);
							}
							break;
						case PokerCardGameMessage.DEALER_CARDSDECRYPTED:
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_CARDSDECRYPTED");
							cCards = new Array();
							try {
								for (item in peerMsg.data) {
									cCards.push(peerMsg.data[item]);
								}
								var previousCard:Card = null;
								var cardMaps:Vector.<ICard> = new Vector.<ICard>();
								for (count = 0; count < cCards.length; count++) {
									var currentCardMapping:String = cCards[count].card as String;
									if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {
										if (!this.verifySignedValue(EthereumMessagePrefix.PUBLIC_DECRYPT, currentCardMapping, cCards[count]["ethTransaction"])) {
											//card signature couln't be verified
										} else {
											this._transactions.addTransaction(cCards[count].ethTransaction, peerMsg);
										}
									}
									communityCards.push(currentCardMapping);									
									cardMaps.push(game.currentDeck.getCardByMapping(currentCardMapping));									
								}								
								game.addToCommunityCards(cardMaps);
							} catch (err:*) {
								DebugView.addText (err);
							}
							_peerMessageHandler.unblock();
							break;
						case PokerCardGameMessage.GAME_END:
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.GAME_END");
							if (game.bettingModule.handComplete) {
								defer1 = new SmartContractDeferState(game.completeDeferCheck, null, this);
								defer1.operationContract = game.activeSmartContract;
								defer2 = new SmartContractDeferState(game.isCompleteDeferCheck, null, game);
								defer2.operationContract = game.activeSmartContract;					
								game.signedActionsContract.endContract(game.activeSmartContract.address).defer([defer1, defer2]).invoke({from:game.ethereumAccount, gas:1000000});								
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
			} catch (err:Error) {
				DebugView.addText (err.getStackTrace());
				_peerMessageHandler.unblock();
			}
		}
		
		/**
		 * Event listener invoked when an unverified contract Alert dialog is closed. The player may continue to play using the
		 * contract once, record the contract for permanent future use, or exit the game immediately.
		 * 
		 * @param	eventObj An Event object.
		 */
		protected function onUnverifiedContractAlertClose(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.CLOSE, this.onUnverifiedContractAlertClose);
			if (eventObj.data.choice == "leave") {
				game.lounge.destroyCurrentGame();
				return;
			} else if (eventObj.data.choice == "use") {
				//use once so do nothing
			} else if (eventObj.data.choice == "record") {
				eventObj.data.descriptor.@type = "contract";
				eventObj.data.descriptor.@status = "new";
				var ethereumNode:XML = game.lounge.settings["getSetting"]("smartcontracts", "ethereum");
				var networkNodes:XMLList = ethereumNode.child("network") as XMLList;				
				for (var count:int = 0; count < networkNodes.length(); count++) {
					var currentNetworkNode:XML = networkNodes[count] as XML;
					var currentNetworkID:int = int(currentNetworkNode.@id);
					if (currentNetworkID == game.lounge.ethereum.client.networkID) {
						currentNetworkNode.appendChild(eventObj.data.descriptor);
						game.lounge.settings["saveSettings"]();
						break;
					}
				}
			}
			game.smartContractBuyIn = game.ethereum.web3.toWei(game.table.buyInAmount, "ether");
			var contractName:String = eventObj.data.descriptor.localName();
			var contract:SmartContract = new SmartContract(contractName, game.ethereumAccount, game.ethereumPassword, eventObj.data.descriptor);
			contract.create();
			contract.previousContract = game.activeSmartContract;
			game.activeSmartContract = contract;			
			_peerMessageHandler.unblock();
		}
		
		/**
		 * Verifies a signed value message supplied by an external player.
		 * 
		 * @param	type The expected message type (prefix).
		 * @param	value The value to verify.
		 * @param	transactionObj The Ethereum transaction object containing the original message, signature, hash, etc.
		 * 
		 * @return True if the message type and value are correct and properly signed, false otherwise.
		 */
		protected function verifySignedValue(type:String, value:String, transactionObj:Object = null):Boolean {
			if (transactionObj == null) {
				DebugView.addText("Player.verifySignedValue: Transaction object is null.");
				return (false);
			}						
			//message should have the format: "MSG_TYPE:SIGNED_VALUE:NONCE" where MSG_TYPE must match the type parameter and SIGNED_VALUE must match the value parameter
			var messageSplit:Array = String(transactionObj.message).split(":");
			if (String(messageSplit[0]) != type) {
				DebugView.addText("Player.verifySignedValue: Message is not the correct type.");
				DebugView.addText("      Type expected: " + type);
				DebugView.addText("      Type supplied: "+ String(messageSplit[0]));
				return (false);
			}
			if (String(messageSplit[1]) != value) {
				DebugView.addText("Player.verifySignedValue: Message value does match provided value.");
				DebugView.addText("      Value expected: " + value);
				DebugView.addText("      Value supplied: "+ String(messageSplit[1]));
				return (false);
			}
			if (game.signedActionsContract.verifySignedTransaction(transactionObj, game.bettingModule.toEthereumAccounts(game.bettingModule.nonFoldedPlayers))) {				
				return (true);
			}
			return (false);
		}
		
		/**
		 * Waits a valid prime value to appear in the contract. Once the value becomes available game functionality is resumed.
		 */
		protected function waitForContractPrime (sourceMsg:IPeerMessage):void {
			DebugView.addText("PokerBettingModule.waitForContractPrime");
			//TODO: implement contract check; when complete, update sourceMsg and call the following:
			/*
			var contractPrime:String = 
			game.lounge.maxCryptoByteLength = uint(peerMsg.data.byteLength);
			var newKey:SRAMultiKey = new SRAMultiKey();
			newKey.addEventListener(SRAMultiKeyEvent.ONGENERATEKEYS, this.onGenerateKeys);
			this.key = newKey;
			var CBL:uint = game.lounge.maxCryptoByteLength * 8;
			newKey.generateKeys(CryptoWorkerHost.getNextAvailableCryptoWorker, this._cryptoOperationLoops, CBL, contractPrime);			
			*/						
		}
		
		/**
		 * Waits a valid generated/plaintext base card value to appear in the contract. Once the value becomes available the remainder
		 * of the values are generated and populate the Player instance after which the game continues.
		 */
		protected function waitForContractCards(sourceMsg:IPeerMessage):void {
			DebugView.addText("PokerBettingModule.waitForContractCards");
			//TODO: implement loop to check for valid baseCard value
			/*
			dealerCards = new Array();
			var baseCard:String = String(game.activeSmartContract.toHex.baseCard());
			dealerCards.push(baseCard);
			var numCards:uint = game.currentDeck.size;		
			var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;			
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateContractCard);
			cryptoWorker.directWorkerEventProxy = onGenerateCardValuesProxy;
			//Use the first available key (though all should work).
			var ranges:Object = SRAKey.getQRNRRange(baseCard, String(game.currentDeck.size));
			DebugView.addText  ("   Generating quadratic residues/non-residues (" + numCards + " card values).");			
			DebugView.addText("   Base card: " + baseCard);
			DebugView.addText("   Range start: " + ranges.start); //should match base card
			DebugView.addText("   Range end: " + ranges.end);
			//these can be pre-computed to significantly reduce start-up time.
			game.dispatchStatusEvent(PokerGameStatusEvent.GEN_DECK, this, {rangeStart:ranges.start, rangeEnd:ranges.end, modulus:key.getKey(0).modulusHex});
			var msg:WorkerMessage = cryptoWorker.QRNR (ranges.start, ranges.end, key.getKey(0).modulusHex, 16);
			this._messageFilter.addMessage(msg);
			*/
		}
		
		/**
		 * Waits for encrypted card values to be stored in the associated smart contract before continuing the game.
		 */
		protected function waitForEncryptedCards(sourceMsg:IPeerMessage):void {
			DebugView.addText("PokerBettingModule.waitForEncryptedCards");				
			/*
			 var cCards:Array =
			dealerCards = new Array();
			_encryptedDeck = new Array(); //store the most current full deck encryption (last encrypting player updates this in broadcastPlayerEncryptedDeck)
			for (count = 0; count < cCards.length; count++) {
				var currentCCard:String = cCards[count].card as String;	
				if (currentCCard!=null) {
					dealerCards[count] = currentCCard;
					_encryptedDeck.push(currentCCard);
					if (peerMsg.targetPeerIDs == "*") {
						//only add fully-encypted cards
						game.currentGameVerifier.addEncryptedCard(currentCCard);
					}
				}
			}
			if (sourceMsg.isNextTargetID(game.clique.localPeerInfo.peerID)) {
				DebugView.addText ("   Continuing deck encryption from peers: " + sourceMsg.sourcePeerIDs);				
				_currentActiveMessage=sourceMsg;
				encryptDealerDeck();
			} else if (sourceMsg.targetPeerIDs == "*") {
				if (game.table.dealerIsMe) {
					DebugView.addText ("   Dealer deck encrypted and shuffled by all players.");									
					startCardsSelection();
				} else {
					_peerMessageHandler.unblock();
				}
			} else {
				_peerMessageHandler.unblock();
			}
			*/
		}
		
		/**
		 * Waits for private card values to be stored in the associated smart contract before continuing the game.
		 */
		protected function waitForPrivateCardSelection(sourceMsg:IPeerMessage):void {
			DebugView.addText("PokerBettingModule.waitForPrivateCardSelection");			
			/*
			if (sourceMsg.targetPeerIDs == "*") {
				_peerMessageHandler.unblock();
			} else {
				if (sourceMsg.isNextTargetID(game.clique.localPeerInfo.peerID)) {
					DebugView.addText  ("   My turn to choose " + sourceMsg.data.pick + " private cards.");									
					//player may manually select here instead...
					_currentActiveMessage = sourceMsg;									
					pickPlayerHand(Number(sourceMsg.data.pick));									
				} else {
					_peerMessageHandler.unblock();
				}
			}
			*/
		}
		
		/**
		 * Waits for private card selection values to be stored in the associated smart contract before continuing the game.
		 */
		protected function waitForPrivateCardDecryption(sourceMsg:IPeerMessage):void {
			DebugView.addText("PokerBettingModule.waitForPrivateCardDecryption");
			/*
			var decryptCards:Array = 
			for (count = 0; count < decryptCards.length; count++) {
				var currentCCard:String = decryptCards as String;				
				if (currentCCard!=null) {
					dealerCards[count] = currentCCard;
					_encryptedDeck.push(currentCCard);
					if (sourceMsg.targetPeerIDs == "*") {
						//only add fully-encypted cards
						game.currentGameVerifier.addEncryptedCard(currentCCard);
					}
				}
			}
			if (sourceMsg.isNextTargetID(game.clique.localPeerInfo.peerID)) {
				_currentActiveMessage=peerMessage;
				encryptDealerDeck();
			} else if (sourceMsg.targetPeerIDs == "*") {
				if (game.table.dealerIsMe) {
					startCardsSelection();
				} else {
					_peerMessageHandler.unblock();
				}
			} else {
				_peerMessageHandler.unblock();
			}
			*/
		}
		
		/**
		 * Waits for public card selection values to be stored in the associated smart contract before continuing the game.
		 */
		protected function waitForPublicCardSelection(sourceMsg:IPeerMessage):void {
			DebugView.addText("PokerBettingModule.waitForPublicCardSelection");	
			/*
			var selectedCards:Array =
			for (var item:* in selectedCards) {				
				cCards[Number(item)] = String(selectedCards[item]);
				deferStateObj.cards.push(String(selectedCards[item]));
				game.currentGameVerifier.addPublicCardSelection(String(selectedCards[item]));
			}
			var sendingPeerID:String = sourceMsg.getSourcePeerIDList()[0].peerID;
			if (sendingPeerID != game.bettingModule.currentDealerMember.peerID) {
				DebugView.addText ("    Public cards selection sent by non-dealer!");
				_peerMessageHandler.unblock();
				return;
			}
			if ((game.ethereum != null) && (game.activeSmartContract != null)) {
				var sendingAccount:String = game.ethereum.getAccountByPeerID(sendingPeerID);							
				deferStateObj.fromAddress = sendingAccount;
				deferStateObj.storageVariable = "publicCards";									
				defer = new SmartContractDeferState(game.encryptedCardsDeferCheck, deferStateObj, game);
				defer.operationContract = game.activeSmartContract;
				game.deferStates.push(defer); //push onto defer state stack to ensure stated cards exist before we commit to further actions
			}
			_peerMessageHandler.unblock();
			*/
		}		
		
		/**
		 * Waits for public card decryption values to be stored in the associated smart contract before continuing the game.
		 */
		protected function waitForPublicCardDecryption (sourceMsg:IPeerMessage):void {
			DebugView.addText("PokerBettingModule.waitForPublicCardDecryption");
			/*
			var decryptedCards:Array = 
			for (item in decryptedCards) {									
				cCards[Number(item)] = String(decryptedCards);				
			}
			_currentActiveMessage = sourceMsg;									
			if (sourceMsg.targetPeerIDs == "*") {									
				if (game.table.dealerIsMe) {
					broadcastDealerCommunityCards(cCards);
				} else {
					_peerMessageHandler.unblock();
				}
			} else {
				DebugView.addText("Next target ID for message: " + peerMessage.getTargetPeerIDList()[0].peerID);
				DebugView.addText("I am: "+game.clique.localPeerInfo.peerID);
				if (sourceMsg.isNextTargetID(game.clique.localPeerInfo.peerID)) {
					decryptCommunityCards(cCards, relayDecryptCommunityCards);
				} else {
					_peerMessageHandler.unblock();
				}
			}		
			*/
		}
		
		/**
		 * Handles the CryptoWorker event dispatched when a series of quadratic residues/non-residues (plaintext
		 * card values) have been generated. If all values are valid, asynchronous operations are
		 * started to encrypt the card values.
		 * 
		 * UNTESTED!
		 * 
		 * @param	eventObj Event object dispatched by a CryptoWorkerHost instance.
		 */
		protected function onGenerateContractCard(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			eventObj.target.removeEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateContractCard);
			var numCards:uint = game.currentDeck.size;			
			if (numCards > uint(String(eventObj.data.qr.length))) {
				//not enough quadratic residues generated...try again with twice as many
				var ranges:Object = SRAKey.getQRNRRange(dealerCards[0], String((eventObj.data.qr.length+eventObj.data.qnr.length)*2));
				var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateContractCard);
				game.dispatchStatusEvent(PokerGameStatusEvent.GEN_DECK, this, {rangeStart:ranges.start, rangeEnd:ranges.end, modulus:String(eventObj.data.prime)});
				var msg:WorkerMessage = cryptoWorker.QRNR (ranges.start, ranges.end, eventObj.data.prime, 16);
				this._messageFilter.addMessage(msg);
				return;
			} else {				
				this._IPCryptoOperations = new Array();
				var baseCard:String = dealerCards[0];			
				dealerCards = new Array();
				var broadcastData:Array = new Array();				
				//eventObj.data.qnr is also available if quadratic non-residues are desired				
				for (var count:uint = 0; count < eventObj.data.qr.length; count++) {
					var currentQR:String = eventObj.data.qr[count] as String;
					var currentCard:ICard = game.currentDeck.getCardByIndex(count);										
					if (currentCard!=null) {
						game.currentGameVerifier.addPlaintextCard(currentQR);						
						game.currentDeck.mapCard(currentQR, currentCard);						
					}
				}
				game.dispatchStatusEvent(PokerGameStatusEvent.NEW_DECK, this, {deck:game.currentDeck, elapsed:eventObj.message.elapsed});
			}			
			if (game.activeSmartContract != null) {
				//Create deferred smart contract invocation to agree to contract
				var dataObj:Object = new Object();
				var playerList:Array = game.bettingModule.toEthereumAccounts(game.bettingModule.nonFoldedPlayersBO);
				dataObj.requiredPlayers = playerList;
				dataObj.modulus = key.getKey(0).modulusHex;
				dataObj.baseCard = baseCard;
				dataObj.agreedPlayers = new Array();
				dataObj.agreedPlayers.push(playerList[playerList.length - 1]); //last player (dealer) must have already agreed
				dataObj.authorizedContracts = [game.startupContract, game.actionsContract, game.resolutionsContract, game.validatorContract];				
				var defer1:SmartContractDeferState = new SmartContractDeferState(game.initializeDeferCheck, dataObj, game);
				var defer2:SmartContractDeferState = new SmartContractDeferState(game.agreeDeferCheck, dataObj, game);
				defer1.operationContract = game.activeSmartContract;				
				defer2.operationContract = game.activeSmartContract;
				var defer3:SmartContractDeferState = new SmartContractDeferState(game.isCompleteDeferCheck, null, game);
				defer3.operationContract = game.activeSmartContract;
				//Agreement will be set when the above conditions can be evaluated
				if (game.activeSmartContract.previousContract == null) {
					//new game
					game.activeSmartContract.agreeToContract(game.activeSmartContract.nonce).defer([defer1, defer2, defer3]).invoke({from:game.ethereumAccount, gas:1900000, value:game.activeSmartContract.toString.buyIn()}, false, true);
				} else {
					//continuing game
					game.activeSmartContract.agreeToContract(game.activeSmartContract.nonce).defer([defer1, defer2, defer3]).invoke({from:game.ethereumAccount, gas:1900000, value:0}, false, true);
				}
			}
			_peerMessageHandler.unblock();
		}		
		
		/**
		 * Begins an asynchronous decryption operation on community/public cards. An error is thrown if the crypto
		 * key pair has not yet been set.
		 * 
		 * @param	cards An array of encrypted card value strings.
		 * @param	onDecrypt The function to invoke when the cards are decrypted.
		 */
		protected function decryptCommunityCards(cards:Array, onDecrypt:Function):void {
			if (cards == null) {
				return;
			}
			if (key == null) {
				var error:Error = new Error("Crypto key is null.");
				throw (error);
			}
			_workCardsComplete = new Array();
			this._IPCryptoOperations = new Array();
			_workCards = new Array();
			for (var count:uint = 0; count < cards.length; count++) {				
				_workCards[count] = cards[count];
			}
			_postCardDecrypt = onDecrypt;			
			for (count = 0; count < cards.length; count++) {
				var currentCCard:String = cards[count] as String;
				try {
					var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;							
					cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onDecryptCommunityCard);
					var msg:WorkerMessage = cryptoWorker.decrypt(currentCCard, key.getKey(this._cryptoOperationLoops - 1), 16);
					this._messageFilter.addMessage(msg);
					this._IPCryptoOperations[msg.requestId] = this._cryptoOperationLoops;
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
		protected function onDecryptCommunityCard(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			var requestId:String = eventObj.message.requestId;
			this._IPCryptoOperations[requestId]--;
			if (this._IPCryptoOperations[requestId] > 0) {
				var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;							
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onDecryptCommunityCard);
				var msg:WorkerMessage = cryptoWorker.decrypt(eventObj.data.result, key.getKey(this._IPCryptoOperations[requestId] - 1), 16);
				this._messageFilter.addMessage(msg);
				this._IPCryptoOperations[msg.requestId] = this._IPCryptoOperations[requestId];
				return;
			}
			_workCardsComplete.push(eventObj.data.result);			
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
		 * Broadcasts fully decrypted community/public cards. This function should only be invoked by the current dealer.
		 * 
		 * @param	cards The decrypted card values to broadcast to all other players.
		 */
		protected function broadcastDealerCommunityCards(cards:Array):void {
			var msg:PokerCardGameMessage = new PokerCardGameMessage();
			msg.createPokerMessage(PokerCardGameMessage.DEALER_CARDSDECRYPTED, cards);			
			game.clique.broadcast(msg);
			var previousCard:Card = null;
			var cardMaps:Vector.<ICard> = new Vector.<ICard>();
			for (var count:uint = 0; count < cards.length; count++) {
				var currentCardMapping:String = cards[count].card as String;
				cardMaps.push(game.currentDeck.getCardByMapping(currentCardMapping));
			}
			game.addToCommunityCards(cardMaps);
			if (game.bettingModule.currentDealerMember.peerID == game.clique.localPeerInfo.peerID) {
				game.bettingModule.startNextBetting();
			}
			_currentActiveMessage = null;
			_peerMessageHandler.unblock();								
		}
		
		/**
		 * Relays a community/public card decryption operation to the next peer.
		 * 
		 * @param	cards A list of numeric card values to relay with the peer message.
		 */
		protected function relayDecryptCommunityCards(cards:Array):void {
			var currentMsg:IPeerMessage = _currentActiveMessage;			
			try {
				currentMsg.updateSourceTargetForRelay(); //if no targets available after this, broadcast method should broadcast to all "*"
			} catch (err:*) {
				DebugView.addText  (err);
				return;
			}
			if (currentMsg.targetPeerIDs == "*") {
				if (game.table.dealerIsMe) {
					this._smartContractDecryptPhase++;
					var cardsArray:Array = new Array();
					for (var count:uint = 0; count < cards.length; count++) {
						var cardObj:Object = new Object();
						cardObj.card = cards[count];
						if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {
							cardObj.ethTransaction = game.ethereum.sign([EthereumMessagePrefix.PUBLIC_DECRYPT, cards[count]]);
						} else {
							cardObj.ethTransaction = new Object();
						}
						cardsArray.push(cardObj);
					}
					broadcastDealerCommunityCards(cardsArray);
					return;
				}
			}
			var payload:Object = new Object();
			var deferCards:Array = new Array();
			for (count = 0; count < cards.length; count++) {
				var currentCryptoCard:String = new String(cards[count] as String);
				cardObj =  new Object();
				cardObj.card = currentCryptoCard;
				if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {
					cardObj.ethTransaction = game.ethereum.sign([EthereumMessagePrefix.PUBLIC_DECRYPT, currentCryptoCard]);
				} else {
					cardObj.ethTransaction = new Object();
				}
				payload[count] = cardObj;
				deferCards.push(currentCryptoCard);
			}	
			if (currentMsg.targetPeerIDs != "*") {
				if ((game.ethereum != null) && (game.activeSmartContract != null)) {
					// begin smart contract deferred invocation: storePublicDecryptCards
					var deferStateObj:Object = new Object();	
					var contractDecryptPhases:String = game.activeSmartContract.getDefault("publicdecryptphases");				
					var phasesSplit:Array = contractDecryptPhases.split(",");
					deferStateObj.phases = phasesSplit[this._smartContractDecryptPhase];
					deferStateObj.account = game.ethereumAccount;
					var defer1:SmartContractDeferState = new SmartContractDeferState(game.phaseDeferCheck, deferStateObj, game, true);
					defer1.operationContract = game.activeSmartContract;
					var defer2:SmartContractDeferState = new SmartContractDeferState(game.isCompleteDeferCheck, null, game);
					defer2.operationContract = game.activeSmartContract;
					var deferArray:Array = game.combineDeferStates(game.deferStates, [defer1, defer2]);
					game.startupContract.storePublicDecryptCards(game.activeSmartContract.address, deferCards).defer(deferArray).invoke({from:game.ethereumAccount, gas:1900000}, game.txSigningEnabled);
					// end smart contract deferred invocation: storePublicDecryptCards					
				}
			}
			this._smartContractDecryptPhase++; //only store at each phase once
			currentMsg.data.payload = payload;
			game.clique.broadcast(currentMsg);
			game.log.addMessage(currentMsg);
			_currentActiveMessage = null;
			_peerMessageHandler.unblock();
		}
		
		/**
		 * Handles BETTING_DONE events dispatched by a PokerBettingModule instance. The game
		 * phase is adjusted as appropriate and onFinalBet is invoked at the end of a round.
		 * 
		 * @param	eventObj An event object dispatched by a PokerBettingModule instance.
		 */
		protected function onBettingComplete(eventObj:PokerBettingEvent):void {
			var phasesNode:XML = game.settings["getSettingsCategory"]("gamephases");
			try {
				var currentPhaseNode:XML = phasesNode.children()[game.gamePhase] as XML;
			} catch (err:*) {
				currentPhaseNode = null;
			}
			if (currentPhaseNode == null) {
				game.bettingModule.onFinalBet();
				return;
			}
			_peerMessageHandler.unblock();
		}		
		
		/**
		 * Handles BETTING_FINAL_DONE events dispatched from the PokerBettingModule. The current
		 * player/private and community/public cards are analyzed and broadcastGameResults is
		 * incoked in the current PokerBettingModule instance.
		 * 
		 * @param	eventObj An event disatched from a PokerBettingModule instance.
		 */
		protected function onFinalBettingComplete(eventObj:PokerBettingEvent):void {						
			_peerMessageHandler.unblock();
			//analyze hands
			var handDefs:XML = game.settings["getSettingsCategory"]("hands");			
			_pokerHandAnalyzer = new PokerHandAnalyzer(game.playerCards, game.communityCards, handDefs);
			var keychain:Vector.<ISRAMultiKey> = new Vector.<ISRAMultiKey>();
			keychain[0] = key;
			game.bettingModule.broadcastGameResults(_pokerHandAnalyzer, keychain);
		}		
		
		/**
		 * To be overriden by extending Dealer class.
		 */
		protected function startCardsSelection():void {
			//can only be started by dealer
		}			
		
		/**
		 * Begins the asynchronous selection of player/private cards from the dealerCards array. This functionality may
		 * be extended to allow the player to manually choose encrypted card values instead of the current automated
		 * system.
		 * 
		 * @param	numCards The number of private cards to pick.
		 */
		protected function pickPlayerHand(numCards:Number):void	{
			var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onPickPlayerHand);
			_cardsToChoose = numCards;
			game.dispatchStatusEvent(PokerGameStatusEvent.SELECT_PRIVATE_CARDS, this, {player:game.bettingModule.selfPlayerInfo});
			//multiply by 8x4=32 since we're using bits, 4 bytes per random value.
			var msg:WorkerMessage = cryptoWorker.generateRandom((numCards * 32), false, 16);
			this._messageFilter.addMessage(msg);
		}
		
		/**
		 * Event handler invoked when a pseudo-random value is generated by the CryptoWorker for player/private card selection.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		protected function onPickPlayerHand(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			eventObj.target.removeEventListener(CryptoWorkerHostEvent.RESPONSE, onPickPlayerHand);
			var randomStr:String = eventObj.data.value;			
			if (randomStr == null) {
				pickPlayerHand(_cardsToChoose);
				return;
			}
			heldCards = new Array();
			var selectedCardsArr:Array = new Array();
			randomStr = randomStr.substr(2); //we know this is a "0x" hex value		
			for (var count:Number = 0; count < _cardsToChoose; count++) {
				var rawIndexStr:String = randomStr.substr(0, 4); //random generated 4 byte value...
				var rawIndex:uint = uint("0x" + rawIndexStr); //...converted into a uint...
				var indexMod:Number = rawIndex % dealerCards.length; //...and modulus-ed with the available deck length...
				var splicedCards:Array = dealerCards.splice(indexMod, 1); //...creates a random index into the existing deck...				
				var dataObj:Object = new Object();
				dataObj.card = splicedCards[0] as String; 
				heldCards.push(dataObj.card); //...which points to a card that's now ours.
				if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {
					dataObj.ethTransaction = game.ethereum.sign([EthereumMessagePrefix.PRIVATE_SELECT, dataObj.card]);
				} else {
					dataObj.ethTransaction = new Object();
				}
				selectedCardsArr.push(dataObj); 				
				game.currentGameVerifier.addPrivateCardSelection(game.clique.localPeerInfo.peerID, String(splicedCards[0]));
				randomStr = randomStr.substr(3); //strip off the first four bytes now that we're done with them.
			}
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
			payload.selected = selectedCardsArr;
			for (var count1:uint = 0; count1 < dealerCards.length; count1++) {
				var currentCryptoCard:String = new String(dealerCards[count1] as String);
				payload.cards[count1] = currentCryptoCard;
			}
			if ((game.ethereum != null) && (game.activeSmartContract != null)) {				
				// begin smart contract deferred invocation: storePrivateCards
				var deferDataObj:Object = new Object();
				var numPeers:int = currentMsg.getSourcePeerIDList().length;				
				deferDataObj.storageVariable = "encryptedDeck";
				deferDataObj.cards = this._encryptedDeck;
				if (numPeers > 1) {
					deferDataObj.fromAddress = game.ethereum.getAccountByPeerID(currentMsg.getSourcePeerIDList()[numPeers-2].peerID);
					var defer1:SmartContractDeferState = new SmartContractDeferState(game.encryptedCardsDeferCheck, deferDataObj, game);
					defer1.operationContract = game.activeSmartContract;
					var defer2:SmartContractDeferState = new SmartContractDeferState(game.isCompleteDeferCheck, null, game);
					defer2.operationContract = game.activeSmartContract;
					game.deferStates.push(defer1);
					game.deferStates.push(defer2);
					game.startupContract.storePrivateCards(game.activeSmartContract.address, heldCards).defer(game.deferStates).invoke({from:game.ethereumAccount, gas:2000000}, game.txSigningEnabled);
				} else {
					deferDataObj.fromAddress = game.ethereum.getAccountByPeerID(game.bettingModule.selfPlayerInfo.netCliqueInfo.peerID);
					game.startupContract.storePrivateCards(game.activeSmartContract.address, heldCards).defer(game.deferStates).invoke({from:game.ethereumAccount, gas:2000000}, game.txSigningEnabled);
				}
				defer2 = new SmartContractDeferState(game.encryptedCardsDeferCheck, deferDataObj, game);
				defer2.operationContract = game.activeSmartContract;
				game.deferStates.push(defer2); //store state for checks throughout remainder of hand (but not at this time)
				// end smart contract deferred invocation: storePrivateCards
			}
			currentMsg.data.payload = payload;			
			game.clique.broadcast(currentMsg);
			game.log.addMessage(currentMsg);			
			startDecryptPlayerHand(heldCards);			
		}
		
		/**
		 * Handles a decryption completion event from a CryptoWorker while decrypting player/private cards. 
		 * Once all cards are decrypted and if this is the final peer designated for the operation then the cards 
		 * are stored as the player's private cards, otherwise they are relayed to the next peer for further 
		 * decryption.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		protected function onDecryptPlayerCard(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			var requestId:String = eventObj.message.requestId;
			try{
				this._IPCryptoOperations[requestId]--;
			} catch (err:*) {
				//invalid/no longer valid requestId
				return;
			}
			if (this._IPCryptoOperations[requestId] > 0) {
				var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onDecryptPlayerCard);
				var msg:WorkerMessage = cryptoWorker.decrypt(eventObj.data.result, key.getKey(this._IPCryptoOperations[requestId] - 1), 16);
				this._messageFilter.addMessage(msg);
				this._IPCryptoOperations[msg.requestId] = this._IPCryptoOperations[requestId];
				return;
			}
			_workCardsComplete.push(eventObj.data.result);
			if (_workCards.length == _workCardsComplete.length) {
				clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onDecryptPlayerCard);
				var currentMsg:IPeerMessage = _currentActiveMessage;
				_workCards = null;				
				try {
					currentMsg.updateSourceTargetForRelay(); //if no targets available after this, broadcast method should broadcast to all "*"
				} catch (err:*) {
					DebugView.addText (err);
					return;
				}
				if (currentMsg.targetPeerIDs == "*") {
					var playerCards:Vector.<ICard> = new Vector.<ICard>();
					for (var count:uint = 0; count < _workCardsComplete.length; count++) {		
						var cardMap:String = _workCardsComplete[count] as String;
						var currentCard:ICard = game.currentDeck.getCardByMapping(cardMap);
						if (currentCard!=null) {
							playerCards.push(currentCard);
						} else {
							var infoObj:Object = new Object();
							infoObj.description = "A hole/private card value has been fully decrypted but doesn't match any plaintext values in the deck!";
							infoObj.fatal = true;
							game.dispatchStatusEvent(PokerGameStatusEvent.ERROR, this, infoObj);							
							return;						
						}
					}
					game.addToPlayerCards(playerCards);
					if (game.table.dealerIsMe) {
						selectCommunityCards();
					}
				} else {
					if ((game.ethereum != null) && (game.activeSmartContract != null)) {
						// begin smart contract deferred invocation: storePrivateDecryptCards
						var deferDataObj:Object = new Object();					
						deferDataObj.phases = 3;					
						var peerIDList:Vector.<INetCliqueMember> = currentMsg.getTargetPeerIDList();				
						var targetAccount:String = game.ethereum.getAccountByPeerID(peerIDList[peerIDList.length - 1].peerID);
						deferDataObj.account = targetAccount;
						var defer1:SmartContractDeferState = new SmartContractDeferState(game.phaseDeferCheck, deferDataObj, game);
						defer1.operationContract = game.activeSmartContract;
						var defer2:SmartContractDeferState = new SmartContractDeferState(game.isCompleteDeferCheck, null, game);
						defer2.operationContract = game.activeSmartContract;
						var deferArray:Array = game.combineDeferStates(game.deferStates, [defer1, defer2]); //phase should only be 3 once so use temporary defer states						
						game.startupContract.storePrivateDecryptCards(game.activeSmartContract.address, _workCardsComplete, targetAccount).defer(deferArray).invoke({from:game.ethereumAccount, gas:1000000}, game.txSigningEnabled);
						// end smart contract deferred invocation: storePrivateDecryptCards	
					}
					var payload:Object = new Object();
					for (count = 0; count < _workCardsComplete.length; count++) {
						var currentCryptoCard:String = new String(_workCardsComplete[count] as String);
						var cardObj:Object = new Object();
						cardObj.card = currentCryptoCard;
						if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {
							cardObj.ethTransaction = game.ethereum.sign([EthereumMessagePrefix.PRIVATE_DECRYPT, currentCryptoCard]);
						} else {
							cardObj.ethTransaction = new Object();
						}
						payload[count] = cardObj;
					}			
					currentMsg.data.payload = payload;
					game.clique.broadcast(currentMsg);
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
		protected function startDecryptPlayerHand(cards:Array):void {
			var currentMsg:PokerCardGameMessage = new PokerCardGameMessage();
			var payload:Array = new Array();
			for (var count:uint = 0; count < cards.length; count++) {
				var currentCryptoCard:String = new String(cards[count] as String);
				var cardObj:Object =  new Object();
				cardObj.card = currentCryptoCard;
				if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {
					cardObj.ethTransaction = game.ethereum.sign([EthereumMessagePrefix.PRIVATE_DECRYPT, currentCryptoCard]);
				} else {
					cardObj.ethTransaction = new Object();
				}
				payload.push(cardObj);
			}
			currentMsg.createPokerMessage(PokerCardGameMessage.PLAYER_DECRYPTCARDS, payload);			
			var SMOList:Vector.<INetCliqueMember> = game.getSMOShiftList();			
			for (count = 0; count < SMOList.length; count++) {
				var playerInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(SMOList[count]);
				if (playerInfo == null) {					
					SMOList.splice(count, 1);					
				}
			}
			SMOList = game.adjustSMOList(SMOList, PokerCardGame.SMO_SHIFTSELFTOEND);			
			currentMsg.setTargetPeerIDs(SMOList);
			var decryptorPeer:INetCliqueMember = currentMsg.getTargetPeerIDList()[0];
			var ownerInfo:IPokerPlayerInfo = game.bettingModule.selfPlayerInfo;
			var decryptorInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(decryptorPeer);
			game.dispatchStatusEvent(PokerGameStatusEvent.DECRYPT_PRIVATE_CARDS, this, {player: ownerInfo, decryptor:decryptorInfo});
			game.clique.broadcast(currentMsg);
			game.log.addMessage(currentMsg);
			_peerMessageHandler.unblock();
		}
		
		/**
		 * Begins an asynchronous operation to encrypt the dealer deck. Both the dealerDeck and key
		 * objects must exist and contain valid data prior to invoking this function.
		 */
		protected function encryptDealerDeck():void {
			var cardsToEncrypt:Array=new Array();			
			for (var count:uint = 0; count < dealerCards.length; count++) {
				cardsToEncrypt.push(dealerCards[count] as String);
			}
			this._IPCryptoOperations = new Array();
			dealerCards = new Array();
			for (count = 0; count < cardsToEncrypt.length; count++) {
				var currentCCard:String = cardsToEncrypt[count] as String;
				var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onEncryptCard);
				cryptoWorker.directWorkerEventProxy = onEncryptCardProxy;
				game.dispatchStatusEvent(PokerGameStatusEvent.ENCRYPT_CARD, this, {card:currentCCard, key:key.getKey(this._cryptoOperationLoops - 1)});
				var msg:WorkerMessage = cryptoWorker.encrypt(currentCCard, key.getKey(this._cryptoOperationLoops - 1), 16);
				this._messageFilter.addMessage(msg);
				this._IPCryptoOperations[msg.requestId] = this._cryptoOperationLoops;
			}
		}
		
		/**
		 * Event handler for CryptoWorker events dispatched after dealer card (deck) encryption operations.
		 * Once all dealer cards have been encrypted they are shuffled using the shuffleDealerCards function.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost instance.
		 */
		protected function onEncryptCard(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			var requestId:String = eventObj.message.requestId;
			this._IPCryptoOperations[requestId]--;
			if (this._IPCryptoOperations[requestId] > 0) {				
				var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
				cryptoWorker.directWorkerEventProxy = onEncryptCardProxy;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onEncryptCard);
				game.dispatchStatusEvent(PokerGameStatusEvent.ENCRYPT_CARD, this, {card:eventObj.data.result, key:key.getKey(this._IPCryptoOperations[requestId] - 1)});
				var msg:WorkerMessage = cryptoWorker.encrypt(eventObj.data.result, key.getKey(this._IPCryptoOperations[requestId] - 1), 16);
				this._messageFilter.addMessage(msg);
				this._IPCryptoOperations[msg.requestId] = this._IPCryptoOperations[requestId];
				return;
			}
			game.dispatchStatusEvent(PokerGameStatusEvent.ENCRYPTED_CARD, this, {card:eventObj.data.result});
			dealerCards.push(eventObj.data.result);
			var percent:Number = dealerCards.length / game.currentDeck.size;
			if (dealerCards.length == game.currentDeck.size) {
				clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptCard);
				shuffleDealerCards(shuffleCount, broadcastPlayerEncryptedDeck);
			}
		}

		/**
		 * Broadcasts the encrypted and shuffled dealer cards (deck) to the next peer.
		 */
		protected function broadcastPlayerEncryptedDeck():void {
			var currentMsg:IPeerMessage = _currentActiveMessage;
			if ((game.ethereum != null) && (game.activeSmartContract != null)) {
				var deferDataObj:Object = new Object();
				//store the original source address before updating for relay!
				deferDataObj.fromAddress = game.ethereum.getAccountByPeerID(currentMsg.getSourcePeerIDList()[0].peerID);
			}
			currentMsg.updateSourceTargetForRelay();
			var payload:Array = new Array();
			var storageDeck:Array = new Array();
			for (var count:int = 0; count < dealerCards.length; count++) {				
				var currentCryptoCard:String = new String(dealerCards[count] as String);	
				payload[count] = new Object();
				payload[count].card = currentCryptoCard;
				if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {
					payload[count].ethTransaction = game.ethereum.sign([EthereumMessagePrefix.ENCRYPT, currentCryptoCard]);
				} else {
					payload[count].ethTransaction = new Object();
				}
				storageDeck.push(currentCryptoCard);
			}
			if ((game.ethereum != null) && (game.activeSmartContract != null)) {
				deferDataObj.cards = new Array();
				for (count=0; count < _encryptedDeck.length; count++) {	
					deferDataObj.cards.push(_encryptedDeck[count]); //store in independent array since _encryptedDeck may be updated before the deferred invocation occurs
				}
				// begin smart contract deferred invocation: storeEncryptedDeck
				deferDataObj.storageVariable = "encryptedDeck";
				var defer1:SmartContractDeferState = new SmartContractDeferState(game.encryptedCardsDeferCheck, deferDataObj, game);
				defer1.operationContract = game.activeSmartContract;	
				var defer2:SmartContractDeferState = new SmartContractDeferState(game.isCompleteDeferCheck, null, game);
				defer2.operationContract = game.activeSmartContract;
				game.startupContract.storeEncryptedDeck(game.activeSmartContract.address, storageDeck).defer([defer1, defer2]).invoke({from:game.ethereumAccount, gas:1900000}, game.txSigningEnabled); //include plenty of gas just in case
				// end smart contract deferred invocation: storeEncryptedDeck
			}
			if (currentMsg.targetPeerIDs == "*") {
				for (count = 0; count < dealerCards.length; count++) {
					game.currentGameVerifier.addEncryptedCard(dealerCards[count]);	
				}
			}
			currentMsg.data.payload = payload;			
			game.clique.broadcast(currentMsg);				
			game.log.addMessage(currentMsg);
			//store most current encryption (any other players encrypting subsequently will overwrite this)
			_encryptedDeck = new Array();				
			for (count = 0; count < dealerCards.length; count++) {		
				_encryptedDeck.push (dealerCards[count]);
			}			
			_currentActiveMessage = null;			
			_peerMessageHandler.unblock();
		}
		
		/**
		 * Clears all event listeners of a specific type of CryptoWorkerHost event.
		 * 
		 * @param	eventType The event type to clear all listeners for.
		 * @param	responder The responder function currently assigned as the event handler.
		 */
		protected function clearAllCryptoWorkerHostListeners(eventType:String, responder:Function):void {
			var maxWorkers:uint = game.lounge.settings["getSettingData"]("defaults", "maxcryptoworkers");
			maxWorkers++; //this ensures that all workers are accounted for
			for (var count:uint = 0; count < maxWorkers; count++) {
				try {
					var cryptoWorker:CryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;	
					cryptoWorker.directWorkerEventProxy = null;
					cryptoWorker.removeEventListener(eventType, responder);
				} catch (err:*) {					
				}
			}
		}
		
		/**
		 * Stores all this instance's data and forwards it to the game to switch player to dealer.
		 * 
		 * @param	invokedInDealer Optional function name to invoke in new Dealer instance after initialization.
		 */
		private function switchToDealer(invokeInDealer:String=null):void {	
			var initObject:Object = new Object();
			initObject.game = game; //in case new instance doesn't have a reference
			initObject._peerMessageHandler = _peerMessageHandler;
			//initObject._messageLog = _messageLog;
			//initObject._errorLog = _errorLog;
			initObject._currentActiveMessage = _currentActiveMessage;
			if (dealerCards!=null) {
				initObject.dealerCards = new Array();
				for (var count:int = 0; count < dealerCards.length; count++) {
					initObject.dealerCards.push(dealerCards[count]);
				}
			} else {
				initObject.dealerCards = null;
			}
			if (communityCards!=null) {
				initObject.communityCards = new Array();
				for (count = 0; count < communityCards.length; count++) {
					initObject.communityCards.push(communityCards[count]);
				}
			} else {
				initObject.communityCards = null;
			}
			if (heldCards!=null) {
				initObject.heldCards = new Array();
				for (count = 0; count < heldCards.length; count++) {
					initObject.heldCards.push(heldCards[count]);
				}
			} else {
				initObject.heldCards = null;
			}
			if (_workCards!=null) {
				initObject._workCards = new Array();
				for (count = 0; count < _workCards.length; count++) {
					initObject._workCards.push(_workCards[count]);
				}
			} else {
				initObject._workCards = null;
			}
			if (_workCardsComplete!=null) {
				initObject._workCardsComplete = new Array();
				for (count = 0; count < _workCardsComplete.length; count++) {
					initObject._workCardsComplete.push(_workCardsComplete[count]);
				}
			} else {
				initObject._workCardsComplete = null;
			}
			initObject._postCardShuffle = _postCardShuffle;
			initObject._postCardDecrypt = _postCardDecrypt;			
			initObject._keychain = new Vector.<ISRAMultiKey>();
			for (count = 0; count < _keychain.length; count++) {
				initObject._keychain.push(_keychain[count]);
			}
			initObject._cardsToChoose = _cardsToChoose;			
			initObject._pokerHandAnalyzer = _pokerHandAnalyzer;
			initObject._rekeyOperationActive = _rekeyOperationActive;
			if (_totalComparisonDeck!=null) {
				initObject._totalComparisonDeck = new Vector.<String>();
				for (count = 0; count < _totalComparisonDeck.length; count++) {
					initObject._totalComparisonDeck.push(_totalComparisonDeck[count]);
				}
			} else {
				initObject._totalComparisonDeck = null;
			}
			//game will destroy this instance in the following call so don't do anything else
			game.changePlayerToDealer(initObject, invokeInDealer);
		}
	}
}
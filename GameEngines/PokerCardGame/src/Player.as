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
	import crypto.SRAKey;
	import interfaces.IPlayer;
	import events.PokerBettingEvent;
	import interfaces.IPokerPlayerInfo;
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
	import events.PokerGameStatusEvent;
	import p2p3.workers.WorkerMessage;	
	import crypto.interfaces.ISRAKey;
	import PokerBettingModule;
	import org.cg.DebugView;
	import p2p3.PeerMessageLog;
	import PokerHandAnalyzer;
	import PokerGameStatusReport;
	
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
		protected var _keychain:Vector.<ISRAKey> = new Vector.<ISRAKey>(); //all of the player's keys for the round, most recent first
		private var _cardsToChoose:Number = 0; //used during card selection to track # of cards to choose
		private var _pokerHandAnalyzer:PokerHandAnalyzer = null; //used post-round to analyze hands
		private var _rekeyOperationActive:Boolean = false; //is a rekeying operation currently in progress?
		protected var _totalComparisonDeck:Vector.<String> = null; //generated comparison deck, used during rekeyeing operations		
		
		protected static const _defaultShuffleCount:uint = 3; //the default number of times to shuffle cards in a shuffle operation
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
			game = gameInstance;
		}
		
		/**
		 * Initializes the instance by copying name-matched properties from the supplied parameter to
		 * internal values and enabling game messaging. For example: 
		 * encryptionProgressCount=initObject.encryptionProgressCount. 
		 * No type checking is done on the included properties.
		 * 
		 * @param	initObject Contains name-matched properties to copy to this instance.
		 */
		protected function initialize(initObject:Object):void 
		{			
			for (var item:* in initObject) {
				try {		
					this[item] = initObject[item];
				} catch (err:*) {					
				}
			}
			enableGameMessaging();
		}		

		/**
		 * The crypto key currently being used by the player.
		 */
		public function set key(keySet:ISRAKey):void 
		{			
			_keychain[0] = keySet;
			if (_keychain[0].securable) {				
				DebugView.addText("> Assigned key is securable.");
			} else {
				DebugView.addText("> Assigned key is not securable. Compromised environments may be vulnerable.");
			}
		}
		
		public function get key():ISRAKey 
		{			
			return (_keychain[0]);
		}
		
		/**
		 * @return The player's keychain for the current round.
		 */
		public function get keychain():Vector.<ISRAKey>
		{
			return (_keychain);
		}		
		
		/**
		 * @return True if a rekeyeing operation is currently active, usually as a result of a player disconnect.
		 * Most game functionality should be disabled until this value is false.
		 */
		public function get rekeyOperationActive():Boolean
		{
			return (_rekeyOperationActive);
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
			DebugView.addText ("   enabling game messaging...");
			disableGameMessaging(); //prevents multiple listeners			
			game.bettingModule.addEventListener(PokerBettingEvent.BETTING_DONE, onBettingComplete);
			game.bettingModule.addEventListener(PokerBettingEvent.BETTING_FINAL_DONE, onFinalBettingComplete);
			game.lounge.clique.addEventListener(NetCliqueEvent.PEER_DISCONNECT, onPeerDisconnect);
			_peerMessageHandler.addEventListener(PeerMessageHandlerEvent.PEER_MSG, onPeerMessage);		
		}
		
		/**
		 * Disable event listeners for instance.
		 */
		public function disableGameMessaging():void 
		{
			game.bettingModule.removeEventListener(PokerBettingEvent.BETTING_DONE, onBettingComplete);
			game.bettingModule.removeEventListener(PokerBettingEvent.BETTING_FINAL_DONE, onFinalBettingComplete);
			game.lounge.clique.removeEventListener(NetCliqueEvent.PEER_DISCONNECT, onPeerDisconnect);
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
		 * Begins the process of regenerating a player key, usually as a result of a player drop-out.
		 */
		public function regeneratePlayerKey():void
		{							
			for (var count:int = 0; count < game.bettingModule.allPlayers.length; count++) {				
				var currentPlayer:IPokerPlayerInfo = game.bettingModule.allPlayers[count];
					currentPlayer.comparisonDeck = null;
			}	
			/*
			var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;			
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onRegenerateKey);			
			var maxCBL:uint = game.lounge.maxCryptoByteLength * 8; //parameter is in bits						
			var msg:WorkerMessage = cryptoWorker.generateRandomSRAKey(key.modulusHex, false, maxCBL);
			*/
			onRegenerateKeyPOC();
		}

		/**
		 * Proxy function for onGenerateRandomShuffle intended to be called by a CryptoWorker in direct mode.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */
		public function onGenerateRandomShuffleProxy(eventObj:CryptoWorkerHostEvent):void 
		{
			onGenerateRandomShuffle(eventObj);
		}
		
		/**
		 * Proxy function for onGenerateKey intended to be called by a CryptoWorker in direct mode.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */		
		public function onGenerateKeyProxy(eventObj:CryptoWorkerHostEvent):void 
		{
			onGenerateKey(eventObj);			
		}
		
		/**
		 * Proxy function for onEncryptCard intended to be called by a CryptoWorker in direct mode.
		 * 
		 * @param	eventObj Event dispatched by a CryptoWorkerHost.
		 */	
		public function onEncryptCardProxy(eventObj:CryptoWorkerHostEvent):void
		{
			onEncryptCard(eventObj);
		}

		/**
		 * Destroys the instance and its data, usually before references to it are removed for garbage collection.
		 * 
		 * @param	transferToDealer If true only unneeded references and event listeners are removed such as when the
		 * instance is being transferred to a new Dealer instance, otherwise all data is scrubbed such as at the end of
		 * a round.
		 */
		public function destroy(transferToDealer:Boolean=false):void 
		{
			/*
			 * TODO: commented items cause problems with subsequent instances; for further investigation
			 */
			disableGameMessaging();				
			if (transferToDealer == false) {
				_currentActiveMessage = null;
				_pokerHandAnalyzer = null;
				_peerMessageHandler.removeFromClique(game.lounge.clique);
				//_peerMessageHandler = null;
				_messageLog.destroy();
				_errorLog.destroy();
				//_messageLog = null;
				//_errorLog = null;
				if (key!=null) {
					key.scrub();
				}			
				//key = null;			
				//dealerCards = null;
				//communityCards = null;
				//heldCards = null;
				//game = null;
			}
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
		 * @return The number of times a shuffle operation should be carried out on cards, as defined in the
		 * settings data, or the _defaultShuffleCount value if not defined.
		 */
		protected function get shuffleCount():uint 
		{
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
		protected function onPeerDisconnect(eventObj:NetCliqueEvent):void 
		{
			DebugView.addText ("Player.onPeerDisconnect");
			DebugView.addText ("   Disconnected peer: "+eventObj.memberInfo.peerID);
			_rekeyOperationActive = true;
			_peerMessageHandler.block();
			var truncatedPeerID:String = eventObj.memberInfo.peerID.substr(0, 15) + "...";
			var playerInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(eventObj.memberInfo);
			if (playerInfo == null) {
				//don't re-key since dropped-out peer is not an active player
				new PokerGameStatusReport("Non-player peer " + truncatedPeerID + " has disconnected.").report();
				_rekeyOperationActive = false;
				_peerMessageHandler.unblock();
				return;
			}
			if (game.bettingModule.gameHasEnded) {
				new PokerGameStatusReport("Player peer " + truncatedPeerID + " has disconnected.").report();
				return;
			}
			//must be done before removing player
			if (game.bettingModule.allPlayers.length <= 2) {
				new PokerGameStatusReport("Peer " + truncatedPeerID + " has disconnected. No players are connected - game can't continue!").report();
				game.bettingModule.disable();				
				return;
			} else {
				new PokerGameStatusReport("Peer " + truncatedPeerID + " has disconnected. Starting deck re-keying operation.").report();
			}			
			DebugView.addText  ("Player.onPeerDisconnect: " + eventObj.memberInfo.peerID);
			DebugView.addText  ("   Disabling game and starting multi-party rekeying operation.");
			DebugView.addText  ("   Dealer generated modulus: " + key.modulusHex);
			DebugView.addText  ("   Crypto Byte Length (CBL): " + game.lounge.maxCryptoByteLength);
			//stop any current crypto operation(s) in progress if another player drops out during re-keying
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGenerateRandomShuffle);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGenerateKey);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onDecryptCommunityCard);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onPickPlayerHand);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onDecryptPlayerCard);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptCard);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onRegenerateKey);
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
				DebugView.addText ("   I'm the only player left, game is ending.");
				return;
			}
			var amDealer:Boolean = false;
			if (game.bettingModule.selfPlayerInfo != null) {
				if (game.bettingModule.currentDealerMember.peerID == game.bettingModule.selfPlayerInfo.netCliqueInfo.peerID) {
					amDealer = true;
					game.lounge.leaderIsMe = true;
				}
			}
			if (wasDealer != amDealer) {
				if (amDealer) {
					DebugView.addText("   Assuming dealer role.");
					switchToDealer("regeneratePlayerKey");
				} else {
					DebugView.addText("   I'm no longer the dealer. Something went wrong!");
					var err:Error = new Error("Dealer role lost after update.");
					throw (err);
				}				
			} else {			
				regeneratePlayerKey();
			}
		}
		
		/**
		 * Stores all this instance's data and forwards it to the game to switch player to dealer.
		 * 
		 * @param	invokedInDealer Optional function name to invoke in new Dealer instance after initialization.
		 */
		private function switchToDealer(invokeInDealer:String=null):void
		{	
			var initObject:Object = new Object();
			initObject.game = game; //in case new instance doesn't have a reference
			initObject._peerMessageHandler = _peerMessageHandler;
			initObject._messageLog = _messageLog;
			initObject._errorLog = _errorLog;
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
			initObject._keychain = new Vector.<ISRAKey>();
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
		
		/**
		 * Invoked when a new key is generated as part of a re-keyeing operation.
		 * 
		 * @param	eventObj Event dispatched from the crypto worker.
		 */
		protected function onRegenerateKey(eventObj:CryptoWorkerHostEvent):void 
		{
			DebugView.addText  ("Player.onRegenerateKey");
			eventObj.target.removeEventListener(CryptoWorkerHostEvent.RESPONSE, onRegenerateKey);
			var keychainLength:uint = unshiftKeychain();
			DebugView.addText ("   New keychain length: " + keychainLength);
			key = eventObj.data.sraKey;			
			generateComparisonDeck();		
		}
		
		/**
		 * POC handler invoked when a new key is generated as part of a re-keyeing operation.
		 * 
		 * @param	eventObj Event dispatched from the crypto worker.
		 */
		protected function onRegenerateKeyPOC():void 
		{
			DebugView.addText  ("Player.onRegenerateKeyPOC");
			var keychainLength:uint = unshiftKeychain();
			var selection:Number = Math.round(Math.random()*7);
			switch (selection) {
				case 0:key = new SRAKey("3", "39", "59"); break;
				case 1:key = new SRAKey("5", "35", "59"); break;
				case 2:key = new SRAKey("7", "25", "59"); break;
				case 3:key = new SRAKey("9", "13", "59"); break;
				case 4:key = new SRAKey("11", "37", "59"); break;
				case 5:key = new SRAKey("15", "31", "59"); break;
				case 6:key = new SRAKey("17", "41", "59"); break;
				case 7:key = new SRAKey("27", "43", "59"); break;
			}
			generateComparisonDeck();		
		}	
		/**
		 * Generates a comparison card deck used to establish a new deck during rekeying operations.
		 */
		protected function generateComparisonDeck():void 
		{			
			DebugView.addText("Player.generateComparisonDeck");
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
			DebugView.addText  ("   Cards to encrypt: " + _totalComparisonDeck.length);
			dealerCards = new Array();
			for (count = 0; count < _totalComparisonDeck.length; count++) {
				var currentCCard:String = _totalComparisonDeck[count];
				DebugView.addText  ("   Encrypting card #"+(count+1));
				var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onEncryptComparisonCard);
				var msg:WorkerMessage = cryptoWorker.encrypt(currentCCard, key, 16);					
			}
		}
		
		/**
		 * Event responder that handles the encryption of a single comparison card used in a re-keying operation.
		 * 
		 * @param	eventObj Event object dispatched by a CryptoWorkerHost.
		 */
		protected function onEncryptComparisonCard(eventObj:CryptoWorkerHostEvent):void
		{			
			dealerCards.push(eventObj.data.result);
			var percent:Number = dealerCards.length / _totalComparisonDeck.length;
			DebugView.addText  ("Player.onEncryptComparisonCard #"+dealerCards.length+" ("+Math.round(percent*100)+"%)");
			DebugView.addText  ("    Operation took " + eventObj.message.elapsed + " ms");
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
		protected function broadcastPlayerComparisonDeck():void
		{
			DebugView.addText("Player.broadcastPlayerComparisonDeck");
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
			peerList = game.adjustSMOList(peerList, game.SMO_SHIFTNEXTPLAYERTOEND);			
			peerList = game.adjustSMOList(peerList, game.SMO_REMOVESELF); //already encrypted			
			for (count = 0; count < peerList.length; count++) {
				var playerInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(peerList[count]);
				if (playerInfo != null) {
					msg.addTargetPeerID(peerList[count].peerID);					
				}				
			}			
			game.lounge.clique.broadcast(msg);
			game.log.addMessage(msg);
			_currentActiveMessage = null;
			_peerMessageHandler.unblock();
		}
		
		/**
		 * Continues the multi-party rencryption of another player's comparison deck.
		 * 
		 * @param	currentDeck An array containing the encrypted card deck values as numeric strings.
		 */
		protected function continueComparisonDeckEncrypt(currentDeck:Array):void
		{
			_peerMessageHandler.block();
			dealerCards = new Array();
			_totalComparisonDeck = new Vector.<String>();
			for (var count:int = 0; count < currentDeck.length; count++) {
				_totalComparisonDeck.push(String(currentDeck[count]));
			}			
			for (count = 0; count < _totalComparisonDeck.length; count++) {
				var currentCCard:String = _totalComparisonDeck[count];
				DebugView.addText  ("   Encrypting card #"+(count+1));
				var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onReencryptComparisonCard);
				var msg:WorkerMessage = cryptoWorker.encrypt(currentCCard, key, 16);					
			}			
		}
		
		/**
		 * Event listener invoked when a comparison card has been re-encrypted (second or later round of encryption) during
		 * a re-keying operation.
		 * 
		 * @param	eventObj Event object dispatched by a CryptoWorkerHost.
		 */
		protected function onReencryptComparisonCard(eventObj:CryptoWorkerHostEvent):void
		{			
			dealerCards.push(eventObj.data.result);
			var percent:Number = dealerCards.length / _totalComparisonDeck.length;
			DebugView.addText  ("Player.onReencryptComparisonCard #"+dealerCards.length+" ("+Math.round(percent*100)+"%)");
			DebugView.addText  ("    Operation took " + eventObj.message.elapsed + " ms");
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
		protected function rebroadcastPlayerComparisonDeck():void 
		{	
			DebugView.addText("Player.rebroadcastPlayerComparisonDeck");						
			var msg:IPeerMessage = _currentActiveMessage;			
			msg.updateSourceTargetForRelay();
			var payload:Array = new Array();
			var localPlayer:IPokerPlayerInfo = null;
			if (msg.targetPeerIDs == "*") {
				DebugView.addText("   Comparison deck fully encrypted.");
				var sourcePeerList:Vector.<INetCliqueMember> = msg.getSourcePeerIDList();
				localPlayer = game.bettingModule.getPlayerInfo(sourcePeerList[sourcePeerList.length - 1]);
				DebugView.addText("    Storing completed deck received from: " + localPlayer.netCliqueInfo.peerID);
				localPlayer.comparisonDeck = new Vector.<String>();
			} else {
				DebugView.addText("   Relaying to peers: " + msg.targetPeerIDs);
			}
			for (var count:int = 0; count < dealerCards.length; count++) {
				var currentCryptoCard:String = new String(dealerCards[count] as String);
				payload[count] = currentCryptoCard;
				if ((msg.targetPeerIDs == "*") && (localPlayer != null)) {
					localPlayer.comparisonDeck.push(currentCryptoCard);
				}
			}
			msg.data.payload = payload;
			game.lounge.clique.broadcast(msg);
			game.log.addMessage(msg);
			_currentActiveMessage = null;
			_peerMessageHandler.unblock();
		}
				
		/**
		 * Merges and validates fully encrypted, re-keyed comparison decks for all players and optionally assigns 
		 * the results to the current encrypted dealer deck.
		 * 
		 * @param assignToDealerDeck If true and all validations pass the merged deck will be assigned to the dealer deck
		 * as a final step.
		 * 
		 * @return True if decks were successfully merged, false if there was a problem merging.
		 */
		protected function mergeComparisonDecks(assignToDealerDeck:Boolean=false):Boolean 
		{
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
				} else {
					//card not found in all decks so reject it (already dealt)					
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
		
		
		protected function onGenerateKeyError(eventObj:CryptoWorkerHostEvent):void {
			DebugView.addText ("Player.onGenerateKeyError");
			DebugView.addText(eventObj.humanMessage);
		}
		
		/**
		 * Handler invoked when a CryptoWorker has generated a crypto key pair.
		 * 
		 * @param	eventObj An event dispatched by a CryptoWorkerHost.
		 */
		protected function onGenerateKey(eventObj:CryptoWorkerHostEvent):void 
		{
			DebugView.addText("Player.onGenerateKey");
			eventObj.target.removeEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateKey);						
			key = eventObj.data.sraKey;			
			_peerMessageHandler.unblock();
		}
		
		/**
		 * POC handler invoked when a CryptoWorker has generated a crypto key pair.
		 * 
		 * @param	eventObj An event dispatched by a CryptoWorkerHost.
		 */
		protected function onGenerateKeyPOC():void 
		{
			DebugView.addText("Player.onGenerateKeyPOC");
			var selection:Number = Math.round(Math.random()*7);
			switch (selection) {
				case 0:key = new SRAKey("3", "39", "59"); break;
				case 1:key = new SRAKey("5", "35", "59"); break;
				case 2:key = new SRAKey("7", "25", "59"); break;
				case 3:key = new SRAKey("9", "13", "59"); break;
				case 4:key = new SRAKey("11", "37", "59"); break;
				case 5:key = new SRAKey("15", "31", "59"); break;
				case 6:key = new SRAKey("17", "41", "59"); break;
				case 7:key = new SRAKey("27", "43", "59"); break;
			}
			_peerMessageHandler.unblock();
		}
		
		/**
		 * Inserts a new null entry at the beginning of the keychain and shifts all elements
		 * to the next index.
		 * 
		 * @return The new length of the keychain vector.
		 */
		protected function unshiftKeychain():uint 
		{
			return(_keychain.unshift(null));
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
			if (rekeyOperationActive) {
				//process only rekey messages
				try {
					if (peerMessage.hasTargetPeerID(game.lounge.clique.localPeerInfo.peerID)) {						
						_peerMessageHandler.block();					
						switch (peerMsg.pokerMessageType) {							
							case PokerCardGameMessage.PLAYER_DECKRENECRYPTED:
								DebugView.addText("PokerCardGameMessage.PLAYER_DECKRENECRYPTED");	
								var peerList:Vector.<INetCliqueMember> = peerMessage.getSourcePeerIDList();
								var sourcePeer:INetCliqueMember = peerList[peerList.length - 1];
								if (peerMessage.isNextTargetID(game.lounge.clique.localPeerInfo.peerID)) {
									var truncatedPeerID:String = sourcePeer.peerID.substr(0, 15) + "...";
									new PokerGameStatusReport("Continuing encryption of re-keyed comparison deck from peer "+truncatedPeerID+".").report();
									DebugView.addText("   Continuing multi-party encryption of comparison deck.");
									_currentActiveMessage = peerMessage;
									continueComparisonDeckEncrypt(peerMsg.data);
								} else if (peerMessage.targetPeerIDs == "*") {									
									truncatedPeerID = sourcePeer.peerID.substr(0, 15) + "...";
									new PokerGameStatusReport("Fully encrypted comparison deck received for peer "+truncatedPeerID+".").report();
									DebugView.addText("   Completed comparison deck received from: "+sourcePeer.peerID);
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
										DebugView.addText("   All re-keyed comparison decks received.");
										if (mergeComparisonDecks(true)) {											
											new PokerGameStatusReport("Re-keyed comparison decks received for all players.").report();
											DebugView.addText("   Decks merged successfully.");
											_rekeyOperationActive = false;
											game.bettingModule.resume();
										} else {
											DebugView.addText("   Comparison decks couldn't be merged!");
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
				if (peerMessage.hasTargetPeerID(game.lounge.clique.localPeerInfo.peerID)) {
					//message is either for us or whole clique (*)
					_peerMessageHandler.block();					
					switch (peerMsg.pokerMessageType) {
						case PokerCardGameMessage.ETH_POKERGAMECONTRACT:
							DebugView.addText("PokerCardGameMessage.ETH_POKERGAMECONTRACT");
							DebugView.addText("   Contract address=" + peerMsg.data.address);
							DebugView.addText("   Transaction hash=" + peerMsg.data.txhash);
							game.contracts.unshift(peerMsg.data.address);							
							_peerMessageHandler.unblock();
							break;
						case PokerCardGameMessage.DEALER_MODGENERATED:						
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_MODGENERATED");	
							DebugView.addText  ("   Dealer generated modulus: " + peerMsg.data.prime);
							DebugView.addText  ("   Crypto Byte Length (CBL): " + peerMsg.data.byteLength);							
							game.lounge.maxCryptoByteLength = uint(peerMsg.data.byteLength);
							/*
							var cryptoWorker:ICryptoWorkerHost = game.lounge.nextAvailableCryptoWorker;
							cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateKey);
							cryptoWorker.addEventListener(CryptoWorkerHostEvent.ERROR, onGenerateKeyError);
							cryptoWorker.directWorkerEventProxy = onGenerateKeyProxy;
							var maxCBL:uint = game.lounge.maxCryptoByteLength * 8;
							var msg:WorkerMessage = cryptoWorker.generateRandomSRAKey(String(peerMsg.data.prime), false, maxCBL);
							*/
							onGenerateKeyPOC();
							break;
						case PokerCardGameMessage.DEALER_CARDSGENERATED:
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_CARDSGENERATED");
							new PokerGameStatusReport("Dealer has generated the deck.").report();
							var cards:Array = peerMsg.data as Array;							
							for (count = 0; count < cards.length; count++) {
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
								for (item in peerMsg.data) {									
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
							DebugView.addText ("Player.processPeerMessage -> PokerCardGameMessage.PLAYER_CARDSENCRYPTED");							
							try {							
								cCards = peerMsg.data;							
							} catch (err:*) {
								DebugView.addText (err);
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
								DebugView.addText ("   Continuing deck encryption from peers: " + peerMsg.sourcePeerIDs);								
								new PokerGameStatusReport("I'm now encrypting the card deck.").report();
								_currentActiveMessage=peerMessage;
								encryptDealerDeck();
							} else if (peerMsg.targetPeerIDs == "*") {
								new PokerGameStatusReport("The deck is fully encrypted and ready for play.").report();
								if (game.lounge.leaderIsMe) {									
									DebugView.addText ("   Dealer deck encrypted and shuffled by all players.");									
									startCommunityCardsSelection();
								} else {
									_peerMessageHandler.unblock();
								}
							} else {								
								var nextPeer:INetCliqueMember = peerMsg.getTargetPeerIDList()[0];								
								new PokerGameStatusReport("Peer "+nextPeer.peerID.substr(0, 15)+"... is now encrypting the deck.").report();
								_peerMessageHandler.unblock();
							}
							break;
						case PokerCardGameMessage.DEALER_PICKCARDS:
							DebugView.addText ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_PICKCARDS");								
							try {							
								cCards = peerMsg.data.cards;							
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
							if (peerMsg.targetPeerIDs == "*") {
								new PokerGameStatusReport("All players have selected their private cards.").report();
								_peerMessageHandler.unblock();
								if (game.lounge.leaderIsMe) {
									DebugView.addText ("   Cards are selected. About to starting next betting round.");									
								}
							} else {
								if (peerMsg.isNextTargetID(game.lounge.clique.localPeerInfo.peerID)) {
									new PokerGameStatusReport("I'm now selecting "+peerMsg.data.pick+" private cards.").report();
									DebugView.addText  ("   My turn to choose " + peerMsg.data.pick + " private cards.");	
									//player may manually select here too...
									_currentActiveMessage = peerMessage;
									pickPlayerHand(Number(peerMsg.data.pick));
								} else {
									nextPeer = peerMsg.getTargetPeerIDList()[0];								
									new PokerGameStatusReport("Peer "+nextPeer.peerID.substr(0, 15)+"... is now selecting "+peerMsg.data.pick+" cards.").report();
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
								DebugView.addText (err);
								return;
							}
							_currentActiveMessage = peerMessage;							
							try {
								if (peerMsg.targetPeerIDs == "*") {									
									if (game.lounge.leaderIsMe) {
										broadcastDealerCommunityCards(cCards);
									} else {
										_peerMessageHandler.unblock();
									}
								} else {									
									if (peerMsg.isNextTargetID(game.lounge.clique.localPeerInfo.peerID)) {
										new PokerGameStatusReport("I'm now decrypting the next community card(s).").report();
										decryptCommunityCards(cCards, relayDecryptCommunityCards);
									} else {
										nextPeer = peerMsg.getTargetPeerIDList()[0];								
										new PokerGameStatusReport("Peer "+nextPeer.peerID.substr(0, 15)+"... is now decrypting the next community card(s).").report();
										_peerMessageHandler.unblock();
									}
								}							
							} catch (err:*) {								
								DebugView.addText (err);
							}
							break;
						case PokerCardGameMessage.DEALER_CARDSDECRYPTED:
							DebugView.addText  ("Player.processPeerMessage -> PokerCardGameMessage.DEALER_CARDSDECRYPTED");
							new PokerGameStatusReport("New community card(s) have been fully decrypted.").report();
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
								new PokerGameStatusReport("New community card(s).", PokerGameStatusEvent.NEW_COMMUNITY_CARDS, cCards).report();
							} catch (err:*) {
								DebugView.addText (err);
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
			new PokerGameStatusReport("Now decrypting community card(s).").report();
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
			new PokerGameStatusReport("Broadcasting fully decrypted community card(s) to all players.").report();
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
			new PokerGameStatusReport("New community card(s).", PokerGameStatusEvent.NEW_COMMUNITY_CARDS, cards).report();
			_currentActiveMessage = null;
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
			var truncatedPeerID:String = currentMsg.getTargetPeerIDList()[0].peerID.substr(0, 15) + "...";
			new PokerGameStatusReport("Sending community cards to peer "+truncatedPeerID+" for decryption.").report();
			var payload:Object = new Object();		
			for (var count:uint = 0; count < cards.length; count++) {
				var currentCryptoCard:String = new String(cards[count] as String);
				payload[count] = currentCryptoCard;
			}			
			currentMsg.data.payload = payload;
			game.lounge.clique.broadcast(currentMsg);
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
			DebugView.addText ("Player.onPickPlayerHand");
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
			DebugView.addText ("   Cards chosen: "+heldCards.length);
			DebugView.addText ("   Remaining dealer cards available: " + dealerCards.length);
			try {
				DebugView.addText("Storing private cards to Ethereum contract: " + game.currentContract);
				game.lounge.ethereum.client.lib.storePrivateCards(game.currentContract, heldCards); //currently contract accepts integers only				
			} catch (err:*) {
				DebugView.addText(err);
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
			DebugView.addText ("    Operation took " + eventObj.message.elapsed + " ms");
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
					DebugView.addText(" _workCardsComplete.length=" + _workCardsComplete.length);
					var playerCards:Vector.<ICard> = new Vector.<ICard>();
					for (var count:uint = 0; count < _workCardsComplete.length; count++) {		
						var cardMap:String = _workCardsComplete[count] as String;
						DebugView.addText(" cardMap for "+count+"=" + cardMap);
						var currentCard:ICard = game.currentDeck.getCardByMapping(cardMap);
						DebugView.addText ("Mapped card: " + currentCard);
						if (currentCard!=null) {
							playerCards.push(currentCard);
							DebugView.addText("    Card class #" + count +": " + currentCard.frontClassName);
						}
					}
					game.addToPlayerCards(playerCards);
					new PokerGameStatusReport("New player card(s).", PokerGameStatusEvent.NEW_PLAYER_CARDS, playerCards).report();
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
			for (count = 0; count < SMOList.length; count++) {
				var playerInfo:IPokerPlayerInfo = game.bettingModule.getPlayerInfo(SMOList[count]);
				if (playerInfo == null) {
					//if (playerInfo.balance <= 0) {
						SMOList.splice(count, 1);
					//}
				}
			}
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
			DebugView.addText  ("    Operation took " + eventObj.message.elapsed + " ms");
			DebugView.addText ("   Encrypted Value: " + eventObj.data.result);
			if (dealerCards.length == game.currentDeck.size) {
				clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptCard);
				shuffleDealerCards(shuffleCount, broadcastPlayerEncryptedDeck);
			}
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
			var concPeerID:String = currentMsg.getTargetPeerIDList()[0].peerID.substr(0, 15) + "...";
			var status:String = "Sending encypted deck to peer "+concPeerID+".";
			new PokerGameStatusReport(status, PokerGameStatusEvent.STATUS).report();
			currentMsg.data.payload = payload;
			game.lounge.clique.broadcast(currentMsg);				
			game.log.addMessage(currentMsg);
			_currentActiveMessage = null;
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
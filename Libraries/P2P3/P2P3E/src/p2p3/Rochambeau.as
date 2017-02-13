/**
* An implementation of the Rochambeau protocol used to determine an initial leader role for a clique.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3 {	
	
	import crypto.interfaces.ISRAKey;
	import flash.events.AsyncErrorEvent;	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import p2p3.interfaces.IPeerMessage;
	import p2p3.events.PeerMessageHandlerEvent;
	import p2p3.interfaces.INetClique;
	import org.cg.Table;
	import p2p3.events.RochambeauEvent;
	import p2p3.events.RochambeauGameEvent;
	import org.cg.interfaces.ILounge;
	import p2p3.events.NetCliqueEvent;
	import p2p3.interfaces.ICryptoWorkerHost;
	import p2p3.interfaces.IPeerMessageHandler;
	import p2p3.workers.WorkerMessage;
	import p2p3.workers.events.CryptoWorkerHostEvent;
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.PeerMessageHandler;
	import p2p3.PeerMessageLog;
	import p2p3.workers.CryptoWorkerHost
	import crypto.SRAKey;
	import org.cg.DebugView;
	import org.cg.WorkerMessageFilter;
	import flash.utils.setTimeout;		
	
	public class Rochambeau extends EventDispatcher	{
		
		public static const DEFAULT_CBL:uint = 128;	//1024-bit
		protected static var _defaultCWBusyRetry:Number = 500; //default busy cryptoworker retry time (max), in milliseconds
		protected var _messageFilter:WorkerMessageFilter;		
		//precalculated value profiles (may be updated by any instance)
		protected static var profiles:Vector.<Object> = new <Object>[
		{ //64 bits
		   CBL:8, 
		   prime: "0xB796DE0545AAEF71"
		},
		{ //512 bits
			CBL: 64,
			prime: "0x956C62AB0DD1C266BD5D50948140A2B44E819F8B0F596126E1B3DE625DD24BB239F80BAA7B1DC02BD781A" +
			"37D70625B208D9F6247F49AC498EE7B39F6AD875535"
		},
		{ //768 bits
		   CBL: 96, 
		   prime: "0x857B6FFE7F3ECC8BB63179938B29CBB2210455DCE61734" +
			"ACD621983B59047B3F0507EC46ACD904EFDE304306712B3E62F4086DDA7EBDA4404DA09FB9ECD626E413B9C76792C6" +
			"402C96CACF829181D1B4D61DE5B46C13ACEE7C9BDC80938328A5"		   
		},
		{ //1024 bits
		   CBL: 128, 
		   prime: "0xFF56C5048374AAAEC42CD12B214E7C7C27C70E7F1B6EE0EC6A" +
			"C39E8227599C689A7D757F8F953EC1AD5C6ED505D153C10D6E956483109E032E66388FC65BAE6189B9FAE239BE3A21E" +
			"FA6991365E8E79C06F713390D38063FD1CC27003AEFAD78961F390601A8B283F8D15587EC4C69F09EEEFF315807D4C1" +
			"D672452F494AE4D5"		   
		},
		{ //1536 bits
		   CBL: 192, 
		   prime: "0xB5322D3236F89686FFB86380697143FD8F33908B86DA0" +
			"9E5EB30ED4F0BC6B3B442DFB820309465A978A59A631F0F373333E0623BE48A205907A05809C1BD12FA1676C88CB6C7" +
			"8BA70D2A905FCEFA3CF2BEC1FAD802F35E6580F7288C6AFF775146B4024B6D6374A13E9CCFEB8EC0982BD6DB8E43306" +
			"7971C0227878E05E3D8904F873954B74EBE131D2DECC8FBC0A6AD51F823DE9F1B13F7E884BC88B58C1CACDBF9CFDD64" +
			"FCE4B488C9D04F77DDCB1C87E9424341E98476AC293EE4A9FB4947"
		},
		{ //2048 bits
		   CBL: 256, 
		   prime: "0x84A5F480BEED0DE0E385127B07331034B3EBD66898B8D283584B4" +
			"14BC44C7307EB63093240F290EEC7EF0E211298F1FD86EA55C11A107F08EADBB11A371D9DB09E9EEB6C796A1DE99578" +
			"421A9E7C98FF965A82F6F9559231CF440F038D33CCEE17DE0680948B806769922C25C1DDCEE338ED69968B85B511A65D" +
			"4453DF6276195FE54E9191FDE41CFDCA96ED74B06C53058FBE748BBAE6DBB4B935AC34458E89E5E0A084D95835E71CD4" +
			"004575938E80CBE67B18160BAFBE79760AC2CD79081EAFB7E21F9D97191CA6E68AAE82E44F7F5B3B10EE47080FB22D33" +
			"5826A9905F0FEF1EF6F74C416C6B00510B7CAD643B51FA6B31016324FBB76B73EAB06C0ED85D"
		}
		];		
		protected var _cryptoWorkerBusyRetry:Number = Number.NEGATIVE_INFINITY;	//delay, in milliseconds, to retry crypto operations when an error is generated		
		private var _table:Table = null; //active Table instance containing a segregated clique
		private var _gameName:String = null; //a unique game name to use to establish a segregated room
		private var _gamePassword:String = null; //optional password used to restrict access
		private var _peerMessageHandler:PeerMessageHandler = null; //peer message handler used with incoming messages
		private var _messageLog:PeerMessageLog = null; //message log used with _peerMessageHandler
		private var _errorLog:PeerMessageLog = null; //error log used with _peerMessageHandler		
		private var _lounge:ILounge = null; //current lounger reference (should never be null after instantiation)
		private var _targetCBL:uint = DEFAULT_CBL; //the target or desired CBL to use with own (self/local) Rochambeau games
		private var _useDynamic:Boolean = false; //should dynamic (generated) values be used? If false, pre-geneated values from matching profiles (above) are used.
		private var _fullRecalcOnRestart:Boolean = true; //if dynamic, should the prime recalculation be restarted? if false, the existing prime is used instead.
		private var _startOnReady:Boolean = false;	//should Rochambeau protocol start as soon as initial required values are generated?
		private var _started:Boolean = false; //has "start" function already been invoked?		
		private var _requiredPeers:int = -1; //the required number of peers for the protocol
		private var _activePeers:Vector.<INetCliqueMember> = new Vector.<INetCliqueMember>; //currently active peers, including self (will get smaller as games are completed/won)
		private var _completedPhase:uint = RochambeauGame.NO_PHASE; //the phase currently completed by all child RochambeauGame instances
		private var _busy:Boolean = false; //is instance busy with an operation?
		private var _wins:Vector.<Object> = new Vector.<Object>(); //each object temporarily stores a count of "wins" associated with a "peerID" when a round of Rochambeau is complete
		
		/**
		 * Creates an instance of the Rochambeau protocol class.
		 * 
		 * @param	loungeSet The requesting (parent) lounge. The lounge instance should have
		 * a connected clique reference.
		 * @param	gameNameStr A unique game/room name to either create or join for the Rochambeau process. If none is provided
		 * then a (somewhat) unique name is generated instead.
		 * @param   gamePasswordStr Optional password to use to access or create the Rochambeau game with.
		 * @param	targetCBL The desired crypto byte length setting for the protocol.
		 * @param   useDynamic If true all values are generated dynamically and the protocol won't begin until they are ready. 
		 * If false, pre-generated values closest to the target CBL are used.
		 */
		public function Rochambeau(loungeSet:ILounge, gameNameStr:String, gamePasswordStr:String = null, targetCBL:uint=DEFAULT_CBL, useDynamic:Boolean=false) {
			_lounge = loungeSet;			
			this._gameName = gameNameStr;
			this._gamePassword = gamePasswordStr;
			_targetCBL = targetCBL;
			_useDynamic = useDynamic;			
			_messageLog = new PeerMessageLog();
			_errorLog = new PeerMessageLog();
			_peerMessageHandler = new PeerMessageHandler(_messageLog, _errorLog);						
			_messageFilter = new WorkerMessageFilter();
			addListeners();			
			if (_useDynamic) {				
				generatePrime(_targetCBL);
			} else {				
				_targetCBL = findNearestCBL(_targetCBL);
				var newGame:RochambeauGame = new RochambeauGame(this, null);				
				newGame.addEventListener(RochambeauGameEvent.PHASE_CHANGE, onGamePhaseChanged);
				newGame.profile = getProfileByCBL(_targetCBL);				
				newGame.pause();
				newGame.initialize();
			}			
		}

		/**
		 * The highest game phase completed by all child RochambeauGame instances (refer to RochambeauGame class for static
		 * values to use for comparison). 
		 */
		public function get completedPhase():uint {
			return (_completedPhase);
		}
		
		/**
		 * Currently active peers involved in the Rochambeau process. This list will shrink as games are completed/won and will
		 * eventually contain just one peer: the final winner.
		 */
		public function get activePeers():Vector.<INetCliqueMember> {
			return (_activePeers);
		}

		/**
		 * The final winning peer for the Rochambeau process. A null value is returned if no winner can be determined.
		 */
		public function get winningPeer():INetCliqueMember {
			if (_activePeers == null) {
				return (null);
			}
			if (_activePeers.length != 1) {				
				return (null);
			}
			return (_activePeers[0]);
		}	
		
		/**
		 * True if the Rochambeau instance has correctly set or generated all required references and initial values.
		 */
		public function get ready():Boolean	{
			if (clique == null) {
				return (false);
			}
			if (clique.connected == false) {
				return (false);
			}
			var activeProfile:Object = getProfileByCBL(_targetCBL);
			try {
				if (activeProfile == null) {					
					return (false);
				}
				if ((activeProfile.CBL == undefined) || (activeProfile.CBL == null) || (activeProfile.CBL <= 0)) {					
					return (false);
				}
				if ((activeProfile.prime == undefined) || (activeProfile.prime == null) || (activeProfile.prime == "")) {					
					return (false);
				}
			} catch (err:*) {
				return (false);
			}
			return (true);
		}
		
		public function get gameName():String {
			if (this._gameName == null) {
				this._gameName=this.generateUniqueGameName();
			}
			return (this._gameName);
		}
		
		public function get gamePassword():String {
			if (this._gamePassword.split(" ").join("") == "") {
				this._gamePassword = null;
			}
			return (this._gamePassword);
		}
		
		private function generateUniqueGameName():String {
			var dateObj:Date = new Date();
			var ts:String = new String();
			ts = "RochambeauGame";
			ts += String(dateObj.getUTCFullYear())
			if ((dateObj.getUTCMonth()+1) <= 9) {
				ts += "0";
			}
			ts += String((dateObj.getUTCMonth()+1));
			if ((dateObj.getUTCDate()) <= 9) {
				ts += "0";
			}
			ts += String(dateObj.getUTCDate());
			if (dateObj.getUTCHours() <= 9) {
				ts += "0";
			}
			ts += String(dateObj.getUTCHours());
			if (dateObj.getUTCMinutes() <= 9) {
				ts += "0";
			}
			ts += String(dateObj.getUTCMinutes());
			if (dateObj.getUTCSeconds() <= 9) {
				ts += "0";
			}
			ts += String(dateObj.getUTCSeconds());
			if (dateObj.getUTCMilliseconds() <= 9) {
				ts += "0";
			}
			if (dateObj.getUTCMilliseconds() <= 99) {
				ts += "0";
			}
			ts += String(dateObj.getUTCMilliseconds());
			return (ts);
		}
		
		/**
		 * True if the Rochambeau instance's "start" function has been called.
		 */
		public function get started():Boolean {
			return (_started);
		}
		
		/**
		 * A reference to the default peer message handler for the Rochambeau instance.
		 */
		public function get peerMessageHandler():IPeerMessageHandler {
			return (_peerMessageHandler);
		}		
		
		/**
		 * A reference to the default clique being used with this instance, usually the same instance being used by the current lounge.
		 */
		public function get clique():INetClique {
			return (this._table.clique);
		}	
		
		/**
		 * A reference to the Table instance containing the segregated clique with active/valid players.
		 */
		public function get table():Table {
			return (this._table);
		}
		
		public function set table(tableSet:Table):void {
			this._table = tableSet;			
		}		
		
		/**
		 * A reference to the parent lounge instance, usually set at instantiation time.
		 */
		public function get lounge():ILounge {
			return (_lounge);
		}
		
		/**
		 * A reference to the default message log used with the peer message handler.
		 */
		public function get messageLog():PeerMessageLog {
			return (_messageLog);
		}
			
		/**
		 * A reference to the default error log used with the peer message handler.
		 */
		public function get errorLog():PeerMessageLog {
			return (_errorLog);
		}
		
		/**
		 * True if profile values are to be dynamically generated, false if pre-generated profile values are being used.
		 */
		public function get useDynamic():Boolean {
			return (_useDynamic);
		}
		
		/**
		 * The current maximum busy cryptoworker retry time, in milliseconds. If this values hasn't been set yet, the default
		 * value from the settings XML data will is used, and if this isn't available or is improperly formatted the internal
		 * _defaultCWBusyRetry value is used.
		 */
		public function get cryptoWorkerBusyRetry():Number {
			if (_cryptoWorkerBusyRetry == Number.NEGATIVE_INFINITY) {
				try {
					_cryptoWorkerBusyRetry = new Number(lounge.settings["getSettingData"]("defaults", "workerbusyretry"));
					if (isNaN(_cryptoWorkerBusyRetry)) {
						_cryptoWorkerBusyRetry = _defaultCWBusyRetry;
					}
				} catch (err:*) {
					_cryptoWorkerBusyRetry = _defaultCWBusyRetry;
				}
			}			
			return (_cryptoWorkerBusyRetry);
		}
		
		public function set cryptoWorkerBusyRetry(retrySet:Number):void {
			_cryptoWorkerBusyRetry = retrySet;
		}
		
		/**
		 * Starts the Rochambeau protocol on the connected clique if all values are ready and peers are connected, otherwise
		 * a start is queued to begin once they're available. More than 1 member must be connected to the clique
		 * before this method is invoked. If the Rochambeau protocol has already started, invoking this function
		 * does nothing.
		 * 
		 * @param requiredPeers The number of peers, other than self, that must be connected to the clique before automatically starting. 
		 * If less than 0 or not supplied the current number of connected peers is used (start immediately).
		 */
		public function start(requiredPeers:int = -1):void {
			if (_started) {
				//already started
				return;
			}
			_requiredPeers = requiredPeers; //this was probably the problem
			/*
			if (this.clique == null) {
				var options:Object = new Object();
				options.groupName = this.gameName;
				if (this.gamePassword != null) {
					options.groupPassword = this.gamePassword;
				}
				this.clique = _lounge.clique.newRoom(options);
				this.clique.addEventListener(NetCliqueEvent.CLIQUE_CONNECT, this.onCliqueConnect);
			} else {
				this.continueStart();
			}
			*/
			//clique should already be connected by Table
			this.continueStart();
		}
		
		private function onCliqueConnect(eventObj:NetCliqueEvent):void {
			this.clique.removeEventListener(NetCliqueEvent.CLIQUE_CONNECT, this.onCliqueConnect);
			this.continueStart();
		}
			
		private function continueStart():void {			
			if (_requiredPeers < 0) {
				//_requiredPeers = clique.connectedPeers.length;
				_requiredPeers = table.connectedPeers.length;
			}
			//store currently connected peers (maybe there's a better way to handle this?)
			if (_activePeers == null) {
				_activePeers = new Vector.<INetCliqueMember>();
			}
			if (_activePeers.length == 0) {
				//don't re-populate if _activePeers already contains peers
				//for (var count:int = 0; count < this.clique.connectedPeers.length; count++) {				
				//	_activePeers.push(clique.connectedPeers[count]);
				//}
				for (var count:int = 0; count < this.table.connectedPeers.length; count++) {				
					_activePeers.push(this.table.connectedPeers[count]);
				}
				_activePeers.push(clique.localPeerInfo);
			}
			if (ready == false) {				
				_started = false;
				_startOnReady = true;
				return;
			}
			if (_activePeers.length < 2) {
				//need 2 or more players
				DebugView.addText ("   Not enough connected members to start protocol ("+_activePeers.length+").");
				_startOnReady = true;
				return;
			}
			if ((_activePeers.length - 1) < _requiredPeers) {				
				DebugView.addText ("   Not enough connected members to start protocol, need "+(_requiredPeers-(_activePeers.length - 1))+" more.");
				_startOnReady = true;
				return;
			}			
			_startOnReady = false;
			_started = true;
			if (_messageLog==null) {
				_messageLog = new PeerMessageLog();
			}
			if (_messageLog==null) {
				_messageLog = new PeerMessageLog();
			}			
			var dataObj:Object = new Object();
			dataObj.requiredPeers = _requiredPeers;
			var newMsg:RochambeauMessage = new RochambeauMessage();
			newMsg.createRochMessage(RochambeauMessage.START, dataObj);
			messageLog.addMessage(newMsg);
			clique.broadcast(newMsg);			
			var selfGame:RochambeauGame = RochambeauGame.getGameBySourceID(this.clique.localPeerInfo.peerID);			
			var requiredSelections:int = _requiredPeers + 2; //connected players + self + 1 extra selection			
			selfGame.addEventListener(RochambeauGameEvent.PHASE_CHANGE, onGamePhaseChanged);			
			selfGame.unpause();			
			selfGame.start(requiredSelections);
			var event:RochambeauEvent = new RochambeauEvent(RochambeauEvent.START);
			dispatchEvent(event);			
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
				DebugView.addText("Rochambeau.onPeerMessage ERROR: " + err);
			}
		}
		
		/**
		 * Invoked by child RochambeauGame instances whenever they complete a game phase, and blocks or unblocks the peer message
		 * handler depending on the busy status of all game instances. The function is not intended to be called from elsewhere.
		 * 
		 * @param	gameRef A reference to the calling RochambeauGame instance.
		 */
		public function onGameBusyStateChanged(gameRef:RochambeauGame = null):void {
			if (_peerMessageHandler == null) {
				return;
			}
			if (RochambeauGame.isBusy()) {				
				//block or continue blocking if any game is busy
				_peerMessageHandler.block();				
			} else {
				//unblock only when no games are busy				
				_peerMessageHandler.unblock();				
			}			
		}
		
		/**
		 * Proxy event handler for non-concurrent cryptoworker prime generation result.
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */
		public function onGeneratePrimeProxy(eventObj:CryptoWorkerHostEvent):void {
			onGeneratePrime(eventObj);
		}
		
		/**
		 * Destroys the instance by clearing any internal data and removing event listeners. The instance reference may be safely nulled
		 * after calling this method.
		 */
		public function destroy():void {
			removeListeners();
			destroyAllGames();			
			_lounge = null;
			_peerMessageHandler = null;
			
		}
		
		/**
		 * Processes a received peer message. Any message that does not validate as a PokerCardGameMessage
		 * is discarded.
		 * 
		 * @param	peerMessage An IPeerMessage implementation object.
		 */
		protected function processPeerMessage(peerMessage:IPeerMessage):void {			
			var peerMsg:RochambeauMessage = RochambeauMessage.validateRochMessage(peerMessage);			
			if (peerMsg == null) {								
				//not a valid RochambeauMessage
				return;
			}
			if (peerMessage.isNextSourceID(clique.localPeerInfo.peerID)) {	
				//message came from us (we are the next source ID meaning no other peer has processed the message)				
				return;
			}
			peerMessage.timestampReceived = peerMessage.generateTimestamp();			
			messageLog.addMessage(peerMessage);
			try {				
				var peerList:Vector.<INetCliqueMember> = peerMessage.getSourcePeerIDList();								
				var gameRef:RochambeauGame = RochambeauGame.getGameBySourceID(peerList[peerList.length-1].peerID);
				//message is either for us or whole clique (*)
				switch (peerMsg.rochambeauMessageType) {
					case RochambeauMessage.START:
						DebugView.addText("RochambeauMessage.START received for peer: "+gameRef.sourcePeerID);
						if ((_started) || (_startOnReady)) {
							DebugView.addText ("   Protocol already started. Ignoring.");
							return;
						}							
						_requiredPeers = int(peerMsg.data.requiredPeers);
						var selfGameRef:RochambeauGame = RochambeauGame.getGameBySourceID(clique.localPeerInfo.peerID);							
						if (selfGameRef == null) {
							DebugView.addText("   Creating new RochambeauGame for self.");
							_targetCBL = findNearestCBL(_targetCBL);
							selfGameRef = new RochambeauGame(this, null);								
							selfGameRef.addEventListener(RochambeauGameEvent.PHASE_CHANGE, onGamePhaseChanged);
							selfGameRef.profile = getProfileByCBL(_targetCBL);
							selfGameRef.pause();
							selfGameRef.initialize();																	
						}//if
						start(_requiredPeers);
						break;					
					case RochambeauMessage.ENCRYPT:	
						if (peerMessage.isNextTargetID(clique.localPeerInfo.peerID)) {
							if (gameRef == null) {
								gameRef = new RochambeauGame(this, peerMessage); //use the original source message (verified one has no "type")
								gameRef.addEventListener(RochambeauGameEvent.PHASE_CHANGE, onGamePhaseChanged);									
							} else {
								//continuing game for source peer
								gameRef.processRochMessage(peerMessage);
							}							
						} else {
							//game may not have been created locally yet
							if (gameRef != null) {									
								gameRef.processRochMessage(peerMessage);
							}
						}
						selfGameRef = RochambeauGame.getGameBySourceID(clique.localPeerInfo.peerID);							
						if (selfGameRef == null) {
							DebugView.addText("   Creating new RochambeauGame for self.");
							_targetCBL = findNearestCBL(_targetCBL);
							selfGameRef = new RochambeauGame(this, null);								
							selfGameRef.addEventListener(RochambeauGameEvent.PHASE_CHANGE, onGamePhaseChanged);
							selfGameRef.profile = getProfileByCBL(_targetCBL);
							selfGameRef.pause();
							selfGameRef.initialize();																	
						}//if
						start(_requiredPeers);
						break;
					case RochambeauMessage.SELECT:								
						if (gameRef != null) {
							//game must exist at this point
							gameRef.processRochMessage(peerMessage);								
						} else {
							DebugView.addText("   SELECT message received for game that doesn't exist! -> " + peerList[peerList.length - 1].peerID);
						}
						break;
					case RochambeauMessage.DECRYPT:	
						gameRef = RochambeauGame.getGameBySourceID(peerMessage.data.payload.sourcePeerID);
						if (gameRef != null) {								
							gameRef.processDecryptMessage(peerMessage);
						}
						break;
				}
			} catch (err:*) {				
			}
		}
		
		/**
		 * Event handler invoked whenever a child RochambeauGame instance changes a game phase.
		 * 
		 * @param	eventObj A RochambeauGameEvent object.
		 */
		private function onGamePhaseChanged(eventObj:RochambeauGameEvent):void {			
			var completedEncryption:Boolean = RochambeauGame.gamesAtPhase(RochambeauGame.ENCRYPTION_PHASE);
			var completedSelection:Boolean = RochambeauGame.gamesAtPhase(RochambeauGame.SELECTION_PHASE);
			var completedDecryption:Boolean = RochambeauGame.gamesAtPhase(RochambeauGame.DECRYPTION_PHASE);
			if (completedEncryption) {
				DebugView.addText(RochambeauGame.games.length + " games have completed encryption phase.");
				_completedPhase == RochambeauGame.ENCRYPTION_PHASE;
				var event:RochambeauEvent = new RochambeauEvent(RochambeauEvent.PHASE_CHANGE);
				dispatchEvent(event);				
			}
			if (completedSelection) {
				DebugView.addText(RochambeauGame.games.length + " games have completed selection phase.");
				_completedPhase == RochambeauGame.SELECTION_PHASE;
				event = new RochambeauEvent(RochambeauEvent.PHASE_CHANGE);
				dispatchEvent(event);
			}
			if (completedDecryption) {
				DebugView.addText(RochambeauGame.games.length + " games have completed decryption phase.");
				_completedPhase == RochambeauGame.DECRYPTION_PHASE;
				event = new RochambeauEvent(RochambeauEvent.PHASE_CHANGE);
				dispatchEvent(event);
				sortWinningGames();				
			}
		}		
		
		/**
		 * Sorts through completed child RochambeauGame instances to determine the winner(s). If more than one winner is found the 
		 * Rochambeau process is repeated with only the winning peers.
		 */
		private function sortWinningGames():void {		
			try {
				//prepare wins sorting object
				_wins = new Vector.<Object>(); 
				for (var count:int = 0;  count < RochambeauGame.games.length; count++) {
					var newWinObj:Object = new Object();
					newWinObj.wins = 0;
					newWinObj.peerID = RochambeauGame.games[count].sourcePeerID;
					_wins.push (newWinObj);
				}
				//count wins
				var highestWins:int = 0;			
				for (count = 0; count < RochambeauGame.games.length; count++) {				
					var winsObj:Object = getWinsObjectFor(RochambeauGame.games[count].winnerInfo.peerID);
					winsObj.wins++;				
					if (highestWins < winsObj.wins) {
						highestWins = winsObj.wins;
					}				
				}						
				var trimmedWins:Vector.<Object> = new Vector.<Object>();
				var selfgameActive:Boolean = false;				
				for (count = 0; count < _wins.length; count++) {
					var currentWinsObj:Object = _wins[count];				
					if (currentWinsObj.wins == highestWins) {					
						trimmedWins.push(currentWinsObj);
						if (currentWinsObj.peerID == clique.localPeerInfo.peerID) {
							selfgameActive = true;
						}
					} else {					
						trimActiveMember(currentWinsObj.peerID);
					}
				}			
				if (_activePeers.length == 1) {
					var event:RochambeauEvent = new RochambeauEvent(RochambeauEvent.COMPLETE);
					dispatchEvent(event);
				} else {				
					destroyAllGames();
					if (selfgameActive) {
						restart();
					}
				}
			} catch (err:*) {
				DebugView.addText (err);
				DebugView.addText (err.getStackTrace());
			}
		}	
		
		/**
		 * Restarts the Rochambeau process if multiple winners are found from the previous round.
		 */
		private function restart():void {			
			if (_activePeers == null) {
				return;
			}
			if (_activePeers.length < 2) {
				return;
			}
			_startOnReady = false;
			_started = false;
			_completedPhase = RochambeauGame.NO_PHASE;
			_wins = new Vector.<Object>();
			_requiredPeers = _activePeers.length - 1;
			_busy = false;
			if (_useDynamic && _fullRecalcOnRestart) {				
				_started = false;
				_startOnReady = true;				
				generatePrime(_targetCBL);				
			} else {
				_targetCBL = findNearestCBL(_targetCBL);
				var selfGame:RochambeauGame = new RochambeauGame(this, null);				
				selfGame.addEventListener(RochambeauGameEvent.PHASE_CHANGE, onGamePhaseChanged);
				selfGame.profile = getProfileByCBL(_targetCBL);				
				selfGame.pause();
				selfGame.initialize();
				start(_requiredPeers);
			}
		}
		
		/**
		 * Destroys all child RochambeauGame instances, usually to prepare for another round.
		 */
		private function destroyAllGames():void {			
			while (RochambeauGame.games.length > 0) {
				//games array should shrink with each destroy call so index 0 should be valid until the end
				RochambeauGame.games[0].removeEventListener(RochambeauGameEvent.PHASE_CHANGE, onGamePhaseChanged);
				RochambeauGame.games[0].removeEventListener(RochambeauGameEvent.VALIDATION_ERROR, onGeneratePrimeError);
				RochambeauGame.games[0].destroy();				
			}			
		}
		
		/**
		 * Removes a specific member from the activePeers list.
		 * 
		 * @param	peerID The peer ID of the member to remove.
		 */
		private function trimActiveMember(peerID:String):void {			
			for (var count:int = 0; count < _activePeers.length; count++) {				
				if (_activePeers[count].peerID == peerID) {					
					_activePeers.splice(count, 1);
					return;
				}
			}
		}
		
		/**
		 * Finds a "wins" object for a specific member.
		 * 
		 * @param	peerID The peer ID of the member for which to retrieve a "wins" obejct.
		 * 
		 * @return Object containing a "wins" value and an associated "peerID" value, or null if no "object could be found.
		 */
		private function getWinsObjectFor(peerID:String):Object {			
			var currentPeerObj:Object = null;
			for (var count:int = 0; count < _wins.length; count++) {
				currentPeerObj = _wins[count];				
				if (currentPeerObj.peerID == peerID) {
					break;
				} else {
					currentPeerObj = null;
				}
			}
			return (currentPeerObj);
		}
		
		/**
		 * Finds the winning peer ID for a supplied source peer (game) ID.
		 * 
		 * @param	sourcePeerID The source peer ID (game ID) of the game for which to find the winning peer ID.
		 * 
		 * @return The winning peer ID for the specified source peer (game) ID, or null if no winner can be found.
		 */
		private function getWinningPeerIDFor(sourcePeerID:String):String {
			if (completedPhase != RochambeauGame.DECRYPTION_PHASE) {
				return (null);
			}
			for (var count:int = 0; count < RochambeauGame.games.length; count++) {
				if (sourcePeerID == RochambeauGame.games[count].sourcePeerID) {
					return (RochambeauGame.games[count].winnerInfo.peerID);
				}
			}
			return (null);
		}
		
		/**
		 * Adds default event listeners for the instance.
		 */
		private function addListeners():void {
			removeListeners();
			if (clique!=null) {
				_peerMessageHandler.addToClique(clique);				
			}
			_peerMessageHandler.addEventListener(PeerMessageHandlerEvent.PEER_MSG, onPeerMessage);	
			this.clique.addEventListener(NetCliqueEvent.PEER_CONNECT, onPeerConnect);
		}
		
		/**
		 * Removes default event listeners for the instance.
		 */
		private function removeListeners():void {
			if (clique!=null) {
				_peerMessageHandler.removeFromClique(clique);				
			}
			_peerMessageHandler.removeEventListener(PeerMessageHandlerEvent.PEER_MSG, onPeerMessage);	
			this.clique.removeEventListener(NetCliqueEvent.PEER_CONNECT, onPeerConnect);
		}
		
		/**
		 * Returns a profile object for a desired CBL, or null if no such profile exists. See the profiles at the top of the class definition
		 * for values contained in the object.
		 */
		private function getProfileByCBL(CBL:uint):Object {					
			for (var count:int = 0; count < profiles.length; count++) {				
				if (profiles[count].CBL == CBL) {					
					return (profiles[count]);
				}
			}
			return (null);
		}	
		
		/**
		 * Finds the nearest matching CBL from existing profiles.
		 * 
		 * @param	targetCBL The desired or target CBL for which to find a matching profile's CBL.
		 * 		 
		 * @return The nearest matching CBL found in existing profiles.
		 */
		private function findNearestCBL(targetCBL:uint):uint {
			var delta:uint = uint.MAX_VALUE;
			var nearestCBL:uint = 0;
			for (var count:int = 0; count < profiles.length; count++) {
				var currentDelta:uint = uint(Math.abs(profiles[count].CBL - targetCBL));
				if (currentDelta < delta) {
					nearestCBL = profiles[count].CBL;
					delta = currentDelta;
				}
			}
			return (nearestCBL);
		}		
		
		/**
		 * Handles peer connection events.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onPeerConnect(eventObj:NetCliqueEvent):void {			
			//if (clique.connectedPeers.length == _requiredPeers) {
			if (this.table.connectedPeers.length == _requiredPeers) {
				start(_requiredPeers);
				clique.removeEventListener(NetCliqueEvent.PEER_CONNECT, onPeerConnect);
			} else {
			//	_activePeers.push(eventObj.memberInfo);
			}
		}
		
		/**
		 * Begins the dynamic generation of a prime number of length CBL.
		 * 
		 * @param	CBL The desired CBL of the generated prime number.
		 */
		private function generatePrime(CBL:uint):void {			
			if (RochambeauGame.isBusy() || _busy) {				
				setTimeout(generatePrime, Math.random() * cryptoWorkerBusyRetry, _targetCBL);				
				return;
			}			
			_busy = true;
			var cryptoWorker:ICryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;						
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGeneratePrime);
			cryptoWorker.directWorkerEventProxy = onGeneratePrimeProxy;			
			var bitLength:uint = CBL * 8;			
			this._messageFilter.addMessage(cryptoWorker.generateRandomPrime(bitLength, 16));
		}		
		
		/**
		 * Event handler invoked when a prime number is asynchronously generated.
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */
		private function onGeneratePrime(eventObj:CryptoWorkerHostEvent):void {				
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGeneratePrime);
			if (resultIsValid(eventObj.data, "prime") == false) {				
				_busy = false;
				setTimeout (generatePrime, Math.random()*1000, _targetCBL);
				return;
			}
			var CBL:uint = uint(Math.round(eventObj.data.bits / 8));
			var primeVal:String = eventObj.data.prime;							
			var selfGameRef:RochambeauGame = RochambeauGame.getGameBySourceID(clique.localPeerInfo.peerID);	
			if (selfGameRef==null) {
				for (var count:int = 0; count < profiles.length; count++) {
					if (profiles[count].CBL == CBL) {
						profiles[count].prime = primeVal;
						var newGame:RochambeauGame = new RochambeauGame(this, null);						
						newGame.addEventListener(RochambeauGameEvent.PHASE_CHANGE, onGamePhaseChanged);
						newGame.addEventListener(RochambeauGameEvent.VALIDATION_ERROR, onGeneratePrimeError);
						newGame.profile = profiles[count];
						newGame.pause();
						newGame.initialize();
						_busy = false;
						if (_startOnReady) {
							start(_requiredPeers);							
						}
						return;
					}
				}			
				var profileObj:Object = new Object();
				profileObj.CBL = CBL;
				profileObj.prime = primeVal;			
				profiles.push(profileObj);			
				newGame = new RochambeauGame(this, null);				
				newGame.addEventListener(RochambeauGameEvent.PHASE_CHANGE, onGamePhaseChanged);
				newGame.addEventListener(RochambeauGameEvent.VALIDATION_ERROR, onGeneratePrimeError);
				newGame.profile = profileObj;
				newGame.pause();
				newGame.initialize();
			}
			_busy = false;
			if (_startOnReady) {
				start(_requiredPeers);
			}
		}
		
		/**
		 * Rochambeau game event listener invoked when there was an error generating a prime value.
		 * 
		 * @param	eventObj A RochambeauGameEvent object.
		 */
		private function onGeneratePrimeError(eventObj:RochambeauGameEvent):void {
			var selfGameRef:RochambeauGame = RochambeauGame.getGameBySourceID(clique.localPeerInfo.peerID);	
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGeneratePrime);			
			clearAllCryptoWorkerHostListeners(RochambeauGameEvent.VALIDATION_ERROR, onGeneratePrimeError);			
			selfGameRef.destroy();
			selfGameRef = null;
			_busy = false;
			setTimeout (generatePrime, Math.random()*1000, _targetCBL);
		}
		
		/**
		 * Clears all CryptoWorkerHost listeners for a specific event type for this game instance.
		 * 
		 * @param	eventType The event type for which to clear any and all listeners for this game instance.
		 * @param	responder The responder function associated with the event type.
		 */		
		private function clearAllCryptoWorkerHostListeners(eventType:String, responder:Function):void {
			var maxWorkers:uint = lounge.settings["getSettingData"]("defaults", "maxcryptoworkers");
			maxWorkers++;
			for (var count:uint = 0; count < maxWorkers; count++) {
				try {
					var cryptoWorker:ICryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;	
					cryptoWorker.directWorkerEventProxy = null;
					cryptoWorker.removeEventListener(eventType, responder);
				} catch (err:*) {					
				}
			}
		}
		
		/**
		 * Verifies the validity of a supplied result (for example, CryptoWorker) or message value.
		 * 
		 * @param	input The containing object within which resultVariable is to be tested for validity.
		 * @param	resultVariable The name of the property within the input object to check for validity.
		 * 
		 * @return True if resultVariable exists within input and is valid, false otherwise.
		 */
		private function resultIsValid(input:Object, resultVariable:String):Boolean	{
			if (input == null) {
				return (false);
			}
			try {
				if (input[resultVariable] == null) {
					return (false);
				}
				if (input[resultVariable] == "") {
					return (false);
				}
				if (input[resultVariable] == "0") {
					return (false);
				}
				if (input[resultVariable] == 0) {
					return (false);
				}								
				if (input[resultVariable] == "0x0") {
					return (false);
				}
				if (input[resultVariable] == undefined) {
					return (false);
				}
				if (input[resultVariable] == "undefined") {
					return (false);
				}
			} catch (err:*) {
				return (false);
			}
			return (true);			
		}
	}
}
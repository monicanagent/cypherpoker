/**
* A single Rochambeau game instance, usually created by the Rochambeau class.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3 {
		
	import flash.events.EventDispatcher;	
	import p2p3.events.RochambeauGameEvent;
	import p2p3.interfaces.IPeerMessage;
	import p2p3.interfaces.IRochambeauGame;
	import crypto.interfaces.ISRAKey;
	import p2p3.interfaces.INetClique;	
	import p2p3.events.NetCliqueEvent;
	import p2p3.interfaces.ICryptoWorkerHost;
	import p2p3.workers.CryptoWorkerHost;
	import p2p3.workers.CryptoWorkerCommand;
	import p2p3.workers.WorkerMessage;
	import p2p3.workers.events.CryptoWorkerHostEvent;
	import p2p3.interfaces.INetCliqueMember;
	import org.cg.WorkerMessageFilter;
	import crypto.SRAKey;
	import flash.utils.setTimeout;
	import org.cg.DebugView;	
	
	public class RochambeauGame extends EventDispatcher implements IRochambeauGame	{
				
		private static var _games:Vector.<RochambeauGame> = new Vector.<RochambeauGame>(); //all currently active RochambeauGame instances
		
		//completed game phase identifiers
		public static const NO_PHASE:uint = 0;
		public static const ENCRYPTION_PHASE:uint = 1;
		public static const SELECTION_PHASE:uint = 2;
		public static const DECRYPTION_PHASE:uint = 3;		
		public static const DEFAULT_SELECTIONS:uint = 10; //default number of selections to pre-generate at startup, can be increased if larger numbers of players are expected
		protected static var _defaultCWBusyRetry:Number = 500; //default busy cryptoworker retry time (max), in milliseconds
		protected static var _defaultMIDelay:Number = 10; //default delay for some sequential operations when multiple instances are sharing the same device
		protected var _messageFilter:WorkerMessageFilter;
		protected var _cryptoWorkerBusyRetry:Number = Number.NEGATIVE_INFINITY;	//delay, in milliseconds, to retry crypto operations when an error is generated
		private var _selections:Vector.<String> = new Vector.<String>(); //plaintext selections
		private var _encSelections:Vector.<String> = new Vector.<String>(); //encrypted selections
		private var _extSelections:Vector.<String> = new Vector.<String>(); //temporary external (encrypted) selections
		//selected values per player; each object stores "peerID", "encValue" (encrypted value), and "value" (decrypted plaintext value)
		private var _selectedValues:Vector.<Object> = new Vector.<Object>(); //selected values per peer, contains "peerID", plaintext selection "value", and encrypted selection "encValue".
		private var _currentDecryptValue:String = new String(); //value currently being decrypted
		private var _currentDecryptObj:Object = null; //object from _selectedValues array currently being decrypted
		private var _selectionCount:uint; //set before selections are encrypted and decrements on each successful operation
		private var _shuffleLoops:uint = 3; //number of loops to use in a shuffle operation
		private var _extraGenSelections:uint = 0; //extra selections to generate, used on generation restart when not enough selections have been generated
		//Request-To-Selection Map used to re-order asynchronous encryption results. Contains: requestID and selection
		private var _RTSMap:Vector.<Object> = null; 
		private var _requiredSelections:uint = DEFAULT_SELECTIONS; //the required number of selections for this instance
		private var _key:ISRAKey = null; //own (self/local) cryptokeys object
		private var _extKeys:Vector.<ISRAKey> = new Vector.<ISRAKey>(); //received external keys
		private var _workKeys:Vector.<ISRAKey> = new Vector.<ISRAKey>(); //keys remaining to be applied in final decryption		
		private var _rochambeau:Rochambeau; //reference to parent Rochambeau instance
		private var _sourceMessage:IPeerMessage = null;	//source message used to instantiate this instance; the source peer ID of the message becomes the source peer (game) ID for this instance.
		private var _currentMessage:IPeerMessage = null; //current message being processed
		private var _profile:Object = null;	//profile to be used for cryptographic operations in self-initiated game (see Rochambeau "profiles" object for examples)
		private var _ready:Boolean = false; //have required values been generated for this instance?
		private var _startOnReady:Boolean = false; //should game start immediately when ready?
		private var _started:Boolean = false; //"start" method has been invoked		
		private var _phaseCompleted:uint = NO_PHASE; //the completed phase for the instance (used with completed game phase identifiers above)
		private var _sendQueue:Vector.<IPeerMessage> = new Vector.<IPeerMessage>(); //outgoing message queue (stores messages when instance is paused)
		private var _paused:Boolean = false; //is instance paused?
		private var _busy:Boolean = false; //is instance busy with an operation?
		private var _keysSent:Boolean = false; //have crypto keys for this instance been broadcast yet?				
		private var _multiInstanceDelay:Number = Number.NEGATIVE_INFINITY; //delay, in milliseconds, required to accomodate crypto operations for multiple instances on a single device
		
		/**
		 * Creates a RochambeauGame instance, usually by a parent Rochambeau instance.
		 * 
		 * @param	rochInst The parent Rochambeau instance creating this instance. Must not be null.
		 * @param	sourceMessage An optional initial external message for the game. If no message is supplied the game is assumed to
		 * be local (self).
		 */
		public function RochambeauGame(rochInst:Rochambeau, sourceMessage:IPeerMessage=null) {
			_rochambeau = rochInst;
			_sourceMessage = sourceMessage;				
			_games.push(this);
			this._messageFilter = new WorkerMessageFilter();
			processRochMessage(_sourceMessage);
		}
		
		/**
		 * A list of all currently active RochambeauGame instances.
		 */
		public static function get games():Vector.<RochambeauGame> {
			return (_games);
		}
		
		/**
		 * The busy state of the current instance. Setting this value will notify the parent Rochambeau instance if the game's busy state has changed.
		 */
		public function get gameIsBusy():Boolean {
			return (_busy);
		}
		
		public function set gameIsBusy(busySet:Boolean):void {						
			var stateHasChanged:Boolean = false;
			if (_busy != busySet) {
				stateHasChanged = true;
			}
			_busy = busySet; //this value should be updated before dispatching the event in case it's read immediately			
			if (stateHasChanged) {	
				//event broadcast instead of direct invocation here may cause race conditions and unexpected results
				_rochambeau.onGameBusyStateChanged(this);
			}
		}
		
		/**
		 * The current maximum busy cryptoworker retry time, in milliseconds. If this values hasn't been set yet, the default
		 * value from the settings XML data will is used, and if this isn't available or is improperly formatted the internal
		 * _defaultCWBusyRetry value is used.
		 */
		public function get cryptoWorkerBusyRetry():Number {
			if (_cryptoWorkerBusyRetry == Number.NEGATIVE_INFINITY) {
				try {
					_cryptoWorkerBusyRetry = new Number(_rochambeau.lounge.settings["getSettingData"]("defaults", "workerbusyretry"));
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
		 * The current multi-instance sequential operation delay time, in milliseconds. If this values hasn't been set yet, the default
		 * value from the settings XML data will is used and if this isn't available, or is improperly formatted, the internal
		 * _defaultMIDelay value is used.
		 */
		public function get multiInstanceDelay():Number {
			if (_multiInstanceDelay == Number.NEGATIVE_INFINITY) {
				try {
					_multiInstanceDelay = new Number(_rochambeau.lounge.settings["getSettingData"]("defaults", "multiinstancedelay"));
					if (isNaN(_multiInstanceDelay)) {
						_multiInstanceDelay = _defaultMIDelay;
					}
				} catch (err:*) {
					_multiInstanceDelay = _defaultMIDelay;
				}
			}			
			return (_multiInstanceDelay);
		}
		
		public function set multiInstanceDelay(MIDSet:Number):void {
			_multiInstanceDelay = MIDSet;
		}
		
		/**
		 * The current crypto profile being used by this instance, usually set by the parent Rochambeau instance. 
		 * Refer to the "profiles" vector array of the Rochambeau class for sample properties of this object.
		 */
		public function get profile():Object {
			return (_profile);
		}
		
		public function set profile(profileSet:Object):void {
			_profile = profileSet;
		}
	
		/**
		 * The source peer (game) ID of this instance, usually set at instantiation time. This identifier is the ID of the peer
		 * that initiated this game instance (the game "owner").
		 */
		public function get sourcePeerID():String {
			if (_sourceMessage != null) {
				var peerList:Vector.<INetCliqueMember> = _sourceMessage.getSourcePeerIDList();
				return (peerList[peerList.length-1].peerID);
			} else {
				return (_rochambeau.clique.localPeerInfo.peerID);
			}
		}		
		
		/**
		 * The crypto keys generated locally for the current game instance.
		 */
		public function get key():ISRAKey {
			return (_key);
		}
		
		/**
		 * A list of plaintext (unencrypted) selections for this game instance. This list should not change once established.
		 */
		public function get selections():Vector.<String> {
			return (_selections);
		}
		
		/**
		 * A list of encrypted selections for this game instance. This list will become smaller as encrypted selections are made by peers.
		 */
		public function get encSelections():Vector.<String>	{
			return (_encSelections);
		}
		
		/**
		 * The ready state of the instance. An instance is ready when all required initial values and references are generated and set.
		 */
		public function get ready():Boolean	{
			return (_ready);
		}
		
		/**
		 * The completed phase of the game instance matching one of the static phase properties defined by this class.
		 */
		public function get phaseCompleted():uint {
			return (_phaseCompleted);
		}		
		
		/**
		 * True if the game is "owned" by the local player (self); that is, if the source peer (game) ID matches the local (self) peer ID.
		 */
		public function get isSelfGame():Boolean {
			try {
				if (_rochambeau.clique.localPeerInfo.peerID == sourcePeerID) {
					return (true);
				}
			} catch (err:*) {				
			}
			return (false);
		}
		
		/**		 
		 * @return An object containing information about the winner of the game. The returned object will contain a "peerID",
		 * plaintext selection "value", and encrypted selection "encValue". If the winner can't be determined null is returned.
		 * 
		 * The game must be fully completed the decryption phase before this function is called, otherwise null is returned.		 
		 */
		public function get winnerInfo():Object {			
			if ((_selections == null) || (_selectedValues == null)) {				
				return (null);
			}			
			if ((_selections.length - 1) != _selectedValues.length) {				
				return (null);
			}			
			for (var count:int = 0; count < _selectedValues.length; count++) {
				var currentSelectionObj:Object = _selectedValues[count];
				if ((currentSelectionObj.value == "") || (currentSelectionObj.value == null) || (currentSelectionObj.value == undefined)) {					
					return (null);
				}
			}		
			var currentSelectionValue:String = null;
			var found:Boolean;
			//index must be an "int" value
			for (var index:int = 0; index < _selections.length; index++) {				
				currentSelectionValue = _selections[index];
				found = false;
				for (count = 0; count < _selectedValues.length; count++) {
					if (_selectedValues[count].value == currentSelectionValue) {			
						found = true;
						break;
					}
				}
				if (found == false) {				
					break;
				}				
			}			
			index--; //the index before the "gap" is the winner
			if (index < 0) {
				index = _selectedValues.length - 1;
			}			
			var winningSelection:String = _selections[index];			
			for (count = 0; count < _selectedValues.length; count++) {
				currentSelectionObj = _selectedValues[count];				
				if (currentSelectionObj.value == winningSelection) {					
					return (currentSelectionObj); //the winner
				}
			}			
			return (null); //something else went wrong
		}
		
		/**
		 * Returns the busy state of either a single instance or all instances.
		 * 
		 * @param	gameRef A specific IRochambeauGame implementation to return the busy state for. If null, the busy
		 * state of all current instances is returned.
		 * 
		 * @return True if the specified instance is busy, or if any RochambeauGame is busy when no instance is specified. False
		 * is returned if the specified instance isn't busy, or if no instances are busy when no gameRef is not specified.
		 */
		public static function isBusy(gameRef:IRochambeauGame = null):Boolean {
			if (_games == null) {
				return (false);
			}
			for (var count:int = 0; count < _games.length; count++) {
				if (gameRef != null) {
					if (gameRef == _games[count]) {
						if (_games[count].gameIsBusy) {
							return (true);
						}
					}
				} else {
					if (_games[count].gameIsBusy) {
						return (true);
					}
				}
			}
			return (false);
		}
		
		/**
		 * Finds a RochambeauGame instance from a specified source peer (game) ID.
		 * 
		 * @param	peerID The source peer (game) ID for which to find a RochambeauGame instance for.
		 * 
		 * @return The RochambeauGame instance matching the specified source peer (game) ID, or null if none can be found.
		 */
		public static function getGameBySourceID(peerID:String):RochambeauGame {			
			if (_games == null) {				
				return (null);
			}
			if (_games.length == 0) {				
				return (null);
			}
			for (var count:int = 0; count < _games.length; count++) {
				var currentGame:RochambeauGame = _games[count];				
				if (currentGame.sourcePeerID == peerID) {
					return (currentGame);
				}
			}
			return (null);
		}
		
		/**
		 * Checks whether or not all currently active RochambeauGame instances have completed a specific phase.
		 * 
		 * @param	phaseNum The phase to check for, as defined in the static phase definitions of this class.
		 * 
		 * @return True if all currently active RochambeauGame instances have completed the specific phase, false otherwise or if the
		 * phase parameter is invalid.
		 */
		public static function gamesAtPhase(phaseNum:uint):Boolean	{			
			if ((phaseNum != NO_PHASE) && (phaseNum != SELECTION_PHASE) && (phaseNum != ENCRYPTION_PHASE) && (phaseNum != DECRYPTION_PHASE)) {				
				return (false);
			}			
			for (var count:int = 0; count < RochambeauGame.games.length; count++) {				
				if (RochambeauGame.games[count].phaseCompleted != phaseNum) {
					return (false);
				}
			}
			return (true);		
		}
		
		/**
		 * Initializes the instance by generating the game's crypto keys if this is a local (self) game.
		 */
		public function initialize():void {			
			if (_sourceMessage == null) {				
				generateKey();
			}
		}
		
		/**
		 * Starts, or queues to start, the current instance.
		 * 
		 * @param	requiredSelections The required number of selections to generate for the instance. This value should always
		 * be 1 greater than the currently active (participating) number of peers. If a sufficient number of selections have been
		 * pre-generated tehy will be used instead.
		 * 
		 * @return True if the instance was successfully started, false if already started.
		 */
		public function start(requiredSelections:int):Boolean {
			if (_started) {
				//already started
				return (false);
			}
			_started = true;
			_requiredSelections = uint(requiredSelections);			
			if (_profile != null) {
				if (_requiredSelections <= selections.length) {					
					if (ready) {						
						//protocol should already be running						
						_startOnReady = false;						
					} else {
						//protocol is ready but hasn't started yet						
						_startOnReady = true;
						shuffleEncyptedSelections();						
						return (false);
					}
				} else {					
					//starts when generation/shuffle are completed					
					_startOnReady = true;										
					return (false);
				}
			}
			return (true);
		}
		
		/**
		 * Pauses the game instance by storing outgoing messages. Any currently active or newly-received operations will be processed to completion but
		 * result messages will not be sent to peers.
		 */
		public function pause():void {
			_paused = true;
		}
		
		/**
		 * Unpauses the game and immediately sends any stored outgoing messages.
		 */
		public function unpause():void {
			_paused = false;
			broadcast(null);
		}		
		
		/**
		 * Processes a external RochambeauMessage.DECRYPT messages.
		 * 
		 * @param	incomingMsg An external IPeerMessage implementation.
		 */
		public function processDecryptMessage(incomingMsg:IPeerMessage):void {
			if (incomingMsg == null) {
				return;
			}
			if (incomingMsg.data == null) {
				return;
			}
			if (incomingMsg.data.payload == null) {
				return;
			}
			var extKey:ISRAKey = new SRAKey(incomingMsg.data.payload.encKeyHex, incomingMsg.data.payload.decKeyHex, incomingMsg.data.payload.modulusHex);
			_extKeys.push(extKey);
			sendCryptoKeys();
			if (_selectedValues.length != (activePeers.length + 1)) {
				//not enough selected values - messages may be out of order
				return;
			}			
			startDecryptSelections();
		}				
		
		/**
		 * Parses and processes an incoming (external) Rochambeau message.
		 * 
		 * @param	incomingMsg An IPeerMessage implementation containing RochambeauMessage data structures.
		 */
		public function processRochMessage(incomingMsg:IPeerMessage):void {						
			if (incomingMsg == null) {
				return;
			}
			var sourcePeers:Vector.<INetCliqueMember> = incomingMsg.getSourcePeerIDList();
			if (sourcePeers.length == 0) {
				return;
			}
			if (resultIsValid(incomingMsg.data.payload, "selectedValue")) {				
				storeSelection(incomingMsg.getSourcePeerIDList()[0].peerID, incomingMsg.data.payload.selectedValue, true);
			}
			if (sourcePeers[sourcePeers.length - 1].peerID != sourcePeerID) {
				//message is not for this game
				return;
			}
			_currentMessage = incomingMsg;
			if (incomingMsg.targetPeerIDs == "*") {
				//Note: switch on "_phaseCompleted"; currently active phase is about to be completed.
				switch (_phaseCompleted) {
					case NO_PHASE:						
						storeMessageSelections(incomingMsg);
						updatePhaseChange();
						//encryption phase is now complete
						if (isSelfGame) {							
							startSelectionProtocol();
						}						
						break;	
					case ENCRYPTION_PHASE:						
						storeMessageSelections(incomingMsg);						
						if (_encSelections.length == 1) {
							updatePhaseChange();	
							//selection phase is now complete							
							sendCryptoKeys();							
						}						
						break;
					case SELECTION_PHASE:						
						updatePhaseChange();
						sendCryptoKeys();
						//decryption phase is now complete
						break;
					default:
						updatePhaseChange();
						break;
				}				
			} else {				
				switch (_phaseCompleted) {
					case NO_PHASE:
						//in encryption phase
						storeMessageSelections(incomingMsg);
						if (incomingMsg.isNextTargetID(_rochambeau.clique.localPeerInfo.peerID)) {
							continueEncryptionProtocol();							
						}
						break;
					case ENCRYPTION_PHASE:
						//in selection phase						
						storeMessageSelections(incomingMsg);
						if (incomingMsg.isNextTargetID(_rochambeau.clique.localPeerInfo.peerID)) {							
							continueSelectionProtocol();
						}
					case SELECTION_PHASE:
						//in decryption phase						
						break;
					default: 						
						break;
				}				
			}
		}		
		
		/**
		 * Proxy event handler for generated random shuffle values.
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */		
		public function onGenerateRandomShuffleProxy(eventObj:CryptoWorkerHostEvent):void {
			onGenerateRandomShuffle(eventObj);
		}		
		
		/**
		 * Proxy event handler for generated random selection values.
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */
		public function onGenerateSelectionsProxy(eventObj:CryptoWorkerHostEvent):void {			
			onGenerateSelections(eventObj);			
		}
		
		/**
		 * Proxy event handler for encrypted selection values.
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */
		public function onEncryptSelectionsProxy(eventObj:CryptoWorkerHostEvent):void {
			onEncryptSelections(eventObj);			
		}
		
		/**
		 * Proxy event handler for generated crypto keys.
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */
		public function onGenerateKeyProxy(eventObj:CryptoWorkerHostEvent):void {
			onGenerateKey(eventObj);			
		}
		
		/**
		 * Proxy event handler for a generated random selection index value (used to select an ecnrypted selection).
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */
		public function onGenerateSelectionValueProxy(eventObj:CryptoWorkerHostEvent):void {
			onGenerateSelectionValue(eventObj);	
		}
		
		/**
		 * Proxy event handler for decrypted selection values.
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */
		public function onDecryptSelectionProxy(eventObj:CryptoWorkerHostEvent):void {
			onDecryptSelection(eventObj);
		}
		
		/**
		 * Destroys the game instance by clearing data references, removing event listeners, and removing a reference to itself
		 * from the internal _games array.
		 */
		public function destroy():void {			
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGenerateKey);			
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGenerateSelections);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.ERROR, onGenerateSelectionsError);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptSelections);			
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGenerateRandomShuffle);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGenerateSelectionValue);
			this._messageFilter.destroy();
			this._messageFilter = null;
			_selections = null;
			_encSelections = null;
			_extSelections = null;		
			_selectedValues = null;
			_currentDecryptValue = null;
			_currentDecryptObj = null;					 		
			_RTSMap = null;
			_requiredSelections = 0;
			_key = null;
			_extKeys = null;
			_workKeys = null;
			_rochambeau = null;
			_sourceMessage = null;
			_currentMessage = null;
			_profile = null;			
			_ready = false;
			_startOnReady = false;
			_started = false;
			_phaseCompleted = 0;
			_sendQueue = null;
			_paused = false;
			_busy = false;
			_keysSent = false;
			var trimmedGames:Vector.<RochambeauGame> = new Vector.<RochambeauGame>();
			for (var count:int = 0; count < _games.length; count++) {
				if (_games[count] != this) {
					trimmedGames.push(games[count]);
				}
			}
			_games = trimmedGames;
		}
		
		/**
		 * The current prime number value of the game, either as defined by the supplied profile object if this is a local (self) game or by the source message
		 * if this is an external game.
		 */
		private function get prime():String	{
			if (_sourceMessage != null) {
				return (_sourceMessage.data.payload.prime as String);
			} else {
				return (_profile.prime);
			}
			return (null);
		}
		
		/**
		 * The current CBL of the game, either as defined by the supplied profile object if this is a local (self) game or by the source message
		 * if this is an external game.
		 */
		private function get CBL():uint	{
			if (_sourceMessage != null) {
				return (uint(_sourceMessage.data.payload.CBL));
			} else {
				return (_profile.CBL);
			}
			return (uint.MIN_VALUE);
		}
		
		/**
		 * Vector array of all currently active peers. This list will shrink as games are
		 * completed
		 */
		private function get activePeers():Vector.<INetCliqueMember> {
			var returnList:Vector.<INetCliqueMember> = new Vector.<INetCliqueMember>();
			//strip out own instance
			for (var count:int = 0; count < _rochambeau.activePeers.length; count++) {
					if (_rochambeau.activePeers[count].peerID != _rochambeau.clique.localPeerInfo.peerID) {
						returnList.push (_rochambeau.activePeers[count]);
					}
			}
			return (returnList);
		}
		
		/**
		 * Stores the selected value for a specific peer for this game .
		 * 
		 * @param	peerID The peer ID for which to store the value for.
		 * @param	selectionValue The selection value to store.
		 * @param	encrypted If true, the selectionValue parameter is encrypted. If false, selectionValue is unencrypted (plaintext).
		 */
		private function storeSelection(peerID:String, selectionValue:String, encrypted:Boolean):void {			
			var selectionObj:Object = null;			
			for (var count:int = 0; count < _selectedValues.length; count++) {
				if (_selectedValues[count].peerID == peerID) {
					selectionObj = _selectedValues[count];					
					break;
				}
			}			
			if (selectionObj == null) {
				selectionObj = new Object();
				selectionObj.peerID = peerID;
				selectionObj.value = new String();
				selectionObj.encValue = new String();	
				_selectedValues.push(selectionObj);
			}						
			if (encrypted) {
				selectionObj.encValue = selectionValue;				
			} else {
				selectionObj.value = selectionValue;
			}						
		}
		
		/**
		 * Returns the selection value for a specified peer ID.
		 * 
		 * @param	peerID The peer ID for which to return the selection.
		 * @param	encrypted True if the encrypted selection should be returned, false if the plaintext selection should be returned.
		 * 
		 * @return The selection, either encrypted or plaintext, for the peer ID. Null is returned if no selection exists.
		 */
		private function getSelectionFor(peerID:String, encrypted:Boolean=false):String {
			for (var count:int = 0; count < _selectedValues.length; count++) {
				if (_selectedValues[count].peerID == peerID) {
					if (encrypted) {
						return (_selectedValues[count].encValue);
					} else {
						return (_selectedValues[count].value);
					}
				}
		
			}
			return (null);
		}
		
		/**
		 * Checks if the supplied value is present in the plaintext _selections array.
		 * 
		 * @param	selectionValue The selection value string to check for.
		 * 
		 * @return True if selectionValue is present in the _selections array, false if not or if
		 * selectionValue is null or an empty string.
		 */
		private function isSelectionValid(selectionValue:String):Boolean {
			if ((selectionValue == null) || (selectionValue == "")) {
				return (false);
			}
			if (_selections == null) {
				return (false);
			}
			if (_selections.length == 0) {
				return (false);
			}
			for (var count:int = 0; count < _selections.length; count++) {
				if (_selections[count] == selectionValue) {
					return (true);
				}
			}
			return (false);
		}
		
		/**
		 * Begins the asynchronous process of generating a local (self) crypto keys object for the game. This function is invoked
		 * as the default restart for any local (self) generation processes such as prime, key, and selections generation.
		 * 		 
		 */
		private function generateKey():void	{			
			if (isSelfGame && isBusy()) {				
				gameIsBusy = false;
				setTimeout(generateKey, Math.random() * cryptoWorkerBusyRetry);
				return;
			}
			gameIsBusy = true;			
			var cryptoWorker:ICryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
			cryptoWorker.directWorkerEventProxy = onGenerateKeyProxy;
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateKey);			
			var msg:WorkerMessage = cryptoWorker.generateRandomSRAKey(prime, true, (CBL * 8));
			this._messageFilter.addMessage(msg);
		}
		
		/**
		 * Event responder that handles the generation of a local (self) crypto keys object for the game. If the game is
		 * also local the asynchronous plaintext (unencrypted) selections generation process is started. If the game
		 * isn't local (external), the asynchronous encryption phase is started.
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */
		private function onGenerateKey(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGenerateKey);			
			//also included: eventObj.data.bits, eventObj.data.prime;
			if (resultIsValid(eventObj.data, "sraKey") == false) {
				gameIsBusy = false;
				setTimeout(generateKey, Math.random() * cryptoWorkerBusyRetry);
				return;				
			}			
			_key = eventObj.data.sraKey;			
			_encSelections = new Vector.<String>();
			if (isSelfGame == false) {			
				encryptSelections();
			} else {				
				_selections = new Vector.<String>();				
				if (_requiredSelections <= 0) {					
					_requiredSelections = DEFAULT_SELECTIONS;					
				}
				generateSelections(_requiredSelections + _extraGenSelections);
			}
		}
		
		/**
		 * Generates new or additional plaintext (unencrypted) selections for the current game. This function should only be invoked if this
		 * is a local (self) game.
		 * 
		 * @param numSelections The number of selections required.
		 */
		private function generateSelections(numSelections:uint):void {						
			if (numSelections == 0) {
				return;
			}
			gameIsBusy = true;
			_selections = new Vector.<String>();
			_encSelections = new Vector.<String>();
			_extSelections = new Vector.<String>();			
			var cryptoWorker:ICryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;			
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateSelections);
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.ERROR, onGenerateSelectionsError);
			cryptoWorker.directWorkerEventProxy = onGenerateSelectionsProxy;
			var ranges:Object = SRAKey.getQRNRValues(prime, String(numSelections));				
			var msg:WorkerMessage = cryptoWorker.QRNR (ranges.start, ranges.end, prime, 16);
			this._messageFilter.addMessage(msg);
		}
		
		/**
		 * Event responder that handles generated plaintext (unencrypted) selections for the game, usually a local (self) one. Once selections
		 * are correctly generated the asynchronous encryption process is started.
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */
		private function onGenerateSelections(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGenerateSelections);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.ERROR, onGenerateSelectionsError);			
			if (resultIsValid(eventObj.data, "qr") == false) {				
				_selections = null;
				_key = null;
				gameIsBusy = false;				
				setTimeout(generateKey, Math.random() * cryptoWorkerBusyRetry);
				return;
			}
			if (_selections == null) {
				_selections = new Vector.<String>();
			}
			try {
				if (eventObj.data.qr.length >= _requiredSelections) {
					for (var count:int = 0; count < eventObj.data.qr.length; count++) {
						if (_selections.length < _requiredSelections) {
							//CryptoWorker usually returns more than is required so only inlcude required number of selections (to speed up encryption)
							var currentQR:String = eventObj.data.qr[count] as String;							
							_selections.push(currentQR);
						} else {
							break;
						}
					}
				} else {
					_selections = null;					
					gameIsBusy = false;
					_extraGenSelections += 3;					
					setTimeout(generateKey, Math.random() * cryptoWorkerBusyRetry);
					return;
				}
			} catch (err:*) {
				_selections = null;				
				gameIsBusy = false;
				setTimeout(generateKey, Math.random() * cryptoWorkerBusyRetry);
				return;
			}			
			encryptSelections();		
		}
		
		/**
		 * Event handler for CryptoWorker errors raised during selections generation.
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */
		private function onGenerateSelectionsError(eventObj:CryptoWorkerHostEvent):void {
			this._messageFilter.includes(eventObj.message, true);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGenerateSelections);
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.ERROR, onGenerateSelectionsError);			
			var event:RochambeauGameEvent = new RochambeauGameEvent(RochambeauGameEvent.VALIDATION_ERROR);
			dispatchEvent (event);
		}
				
		
		/**
		 * Starts the asynchronous process of encrypting the plaintext (unencrypted) selection values for the game.
		 */
		private function encryptSelections():void {			
			gameIsBusy = true;
			_encSelections = new Vector.<String>();
			var cryptoWorker:ICryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;			
			if (isSelfGame == false) {				
				if (_extSelections.length > 0) {
					//encrypted selections - external game					
					if (cryptoWorker.concurrent) {
						//concurrent results may need to be re-ordered
						_RTSMap = new Vector.<Object>();
					} else {
						//non-concurrent results will always be received in order						
						_RTSMap = null;
					}									
					_selectionCount = _extSelections.length;
					clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptSelections);					
					for (var count:int = 0; count < _extSelections.length; count++) {
						var currentEncSelection:String = _extSelections[count];							
						cryptoWorker.directWorkerEventProxy = onEncryptSelectionsProxy;
						cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onEncryptSelections);						
						var msg:WorkerMessage = cryptoWorker.encrypt(currentEncSelection, this.key, 16);
						this._messageFilter.addMessage(msg);
						mapRequestToSelection(msg, currentQR);
						cryptoWorker = CryptoWorkerHost.nextAvailableCryptoWorker;						
					}
				}				
			} else {				
				//plaintext selections - own game
				_selectionCount = _selections.length;				
				if (cryptoWorker.concurrent) {
					//concurrent results may need to be re-ordered
					_RTSMap = new Vector.<Object>();
				} else {
					//non-concurrent results will always be received in order
					_RTSMap = null;
				}
				clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptSelections);
				for (count = 0; count < _selections.length; count++) {
					var currentQR:String = _selections[count];					
					_encSelections.push(currentEncSelection); //pre-populate for orderered encryption					
					cryptoWorker.directWorkerEventProxy = onEncryptSelectionsProxy;
					cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onEncryptSelections);
					msg = cryptoWorker.encrypt(currentQR, this.key, 16);
					this._messageFilter.addMessage(msg);
					mapRequestToSelection(msg, currentQR);					
					//update reference at end to compensate for concurrency check above
					cryptoWorker = CryptoWorkerHost.nextAvailableCryptoWorker;
				}
			}			
		}
		
		/**
		 * Event responder that handles encrypted selection values. If all values appear to be valid, the asynchronous selection shuffle
		 * process is started.
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */
		private function onEncryptSelections(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			if (resultIsValid(eventObj.data, "result") == false){
				//cryptosystem has failed to generate valid encrypted values so try again				
				clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptSelections);
				if (isSelfGame) {
					gameIsBusy = false;
					setTimeout(generateKey, Math.random() * cryptoWorkerBusyRetry);
				} else {
					setTimeout(encryptSelections, Math.random() * cryptoWorkerBusyRetry);
				}				
				return;
			}			
			var RTSObj:Object = getRTSMapByRequestID(eventObj.message.requestId);			
			var selectionIndex:int = RTSMapSelectionIndex(RTSObj);									
			_selectionCount--; //length of encrypted array won't necessarily match length of selections array
			if (selectionIndex > -1) {				
				_encSelections[selectionIndex] = eventObj.data.result;				
			} else {				
				if (_RTSMap == null) {					
					//synchronous will be received in order					
					_encSelections.push(eventObj.data.result);					
				} else {					
					if (_RTSMap.length == 0) {						
						_RTSMap = null;
						clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptSelections);
						setTimeout(encryptSelections, Math.random() * cryptoWorkerBusyRetry);						
						return;
					} else {						
						_encSelections.push(eventObj.data.result);
					}
				}
			}			
			if (_selectionCount == 0) {	
				clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onEncryptSelections);					
				if ((_sourceMessage != null) || (_startOnReady)) {					
					setTimeout(shuffleEncyptedSelections, multiInstanceDelay);
				} else {					
					gameIsBusy = false;
				}
			}			
		}		
		
		/**
		 * Begins the asynchronous process of generating values to be used to randomly shuffle encrypted selections.
		 */
		private function shuffleEncyptedSelections():void {			
			gameIsBusy = true;
			if (isSelfGame) {				
				//only needed for self game since number of pre-generated selections may exceed required number
				trimSelectionsTo(_requiredSelections);
			}			
			var cryptoWorker:ICryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateRandomShuffle);
			cryptoWorker.directWorkerEventProxy = onGenerateRandomShuffleProxy;			
			this._messageFilter.addMessage(cryptoWorker.generateRandom((_requiredSelections*32)*_shuffleLoops, false, 16));
		}
		
		/**
		 * Event responder that handles the generation of values to randomly shuffle encrypted selection values. If the generated
		 * shuffle values are valid sendEncryptionToNextPeer will be invoked.
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */
		private function onGenerateRandomShuffle(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGenerateRandomShuffle);			
			var randomStr:String = eventObj.data.value;	
			if (resultIsValid(eventObj.data, "value") == false) {
				//cryptosystem has failed to generate valid values so try again
				setTimeout(shuffleEncyptedSelections, Math.random() * cryptoWorkerBusyRetry);					
				return;
			}			
			randomStr = randomStr.substr(2); //because we know this is a "0x" hex value												
			var sourceSelections:Vector.<String> = _encSelections;			
			var targetSelections:Vector.<String> = new Vector.<String>();
			for (var count:Number = 0; count < _shuffleLoops; count++) {				
				while (sourceSelections.length > 0) {						
					try {
						var rawIndexStr:String = randomStr.substr(0, 4);
						var rawIndex:uint = uint("0x" + rawIndexStr);						
						var indexMod:Number = rawIndex % sourceSelections.length;												
						var splicedSelections:Vector.<String> = sourceSelections.splice(indexMod, 1);						
						targetSelections.push(splicedSelections[0]);					
						randomStr = randomStr.substr(3);
					} catch (err:*) {				
						break;
					}
				}
				for (var count2:int = 0; count2 < targetSelections.length; count2++) {
					_encSelections.push (targetSelections[count2]);
				}
				targetSelections = new Vector.<String>();			
			}			
			sendEncryptionToNextPeer();				
		}
		
		/**
		 * Sends encrypted selections for the game to the next peer for encryptions.
		 */
		private function sendEncryptionToNextPeer():void {			
			var dataObj:Object = new Object();
			dataObj.prime = prime;
			dataObj.CBL = CBL;
			dataObj.selections = new Array();
			dataObj.encSelections = new Array();
			for (var count:int = 0; count < _selections.length; count++) {
				dataObj.selections.push(_selections[count]);
			}
			for (count = 0; count < _encSelections.length; count++) {
				dataObj.encSelections.push(_encSelections[count]);				
			}
			if (isSelfGame == false) {				
				//external game
				var msg:IPeerMessage = _sourceMessage;				
				msg.updateSourceTargetForRelay();
				if (msg.targetPeerIDs == "*") {
					//all encryptions complete
					updatePhaseChange();
				}				
				msg.data.payload = dataObj;				
				broadcast(msg, false);
			} else {				
				//own game				
				var newMsg:RochambeauMessage = new RochambeauMessage();
				newMsg.createRochMessage(RochambeauMessage.ENCRYPT, dataObj);
				broadcast(newMsg);
			}
			_ready = true;			
			gameIsBusy = false;
		}
		
		/**
		 * Continues the multi-party encryption operation for the game. The incoming message must exist and contain valid data.
		 */
		private function continueEncryptionProtocol():void {			
			gameIsBusy = true;
			generateKey();
		}
		
		/**
		 * Begins the asynchronous selection phase of the game. This function should only be called after all selections have been fully encrypted by
		 * all active peers.
		 */
		private function startSelectionProtocol():void {
			if (isSelfGame == false) {
				return;
			}
			gameIsBusy = true;			
			var cryptoWorker:ICryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateSelectionValue);
			cryptoWorker.directWorkerEventProxy = onGenerateSelectionValueProxy;			
			var selectionRange:uint = 32; //increase this value if 32-bits is insufficient to cover number of possible selections
			this._messageFilter.addMessage(cryptoWorker.generateRandom(selectionRange, false, 16));
		}
		
		/**
		 * Continues the asynchronous selection phase for this game, usually after one or more previously targetted active peer(s) has made their selection.
		 */
		private function continueSelectionProtocol():void {
			if (isSelfGame) {
				return;
			}						
			gameIsBusy = true;
			var cryptoWorker:ICryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onGenerateSelectionValue);
			cryptoWorker.directWorkerEventProxy = onGenerateSelectionValueProxy;			
			var selectionRange:uint = 32; //increase this value if 32-bits is insufficient to cover number of possible selections
			this._messageFilter.addMessage(cryptoWorker.generateRandom(selectionRange, false, 16));
		}
		
		/**
		 * Event responder that handles the generation of a random selection index for available selections during the selection
		 * phase of the game, both local (self) and external.
		 * 
		 * @param	eventObj A CryptoWorkerHostEvent object.
		 */
		private function onGenerateSelectionValue(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onGenerateSelectionValue);
			if (resultIsValid(eventObj.data, "value") == false) {				
				//cryptosystem has failed to generate valid values so try again				
				if (isSelfGame) {					
					setTimeout(startSelectionProtocol, Math.random() * cryptoWorkerBusyRetry);					
				} else {
					setTimeout(continueSelectionProtocol, Math.random() * cryptoWorkerBusyRetry);							
				}
				return;
			}			
			var randomStr:String = eventObj.data.value;	
			randomStr = randomStr.substr(2); //because we know this is a "0x" hex value												
			var indexStr:String = randomStr.substr(0, 4);
			var indexVal:uint = uint("0x" + indexStr);
			var payloadObj:Object = new Object();
			payloadObj.encSelections = new Array();
			payloadObj.selections = new Array();			
			if (isSelfGame == false) {
				//external game				
				var selectIndex:Number = indexVal % _extSelections.length;
				var splicedSelections:Vector.<String> = _extSelections.splice(selectIndex, 1);
				_encSelections = new Vector.<String>();
				var msg:IPeerMessage = _currentMessage;
				for (var count:int = 0; count < _extSelections.length; count++) {
					payloadObj.encSelections.push(_extSelections[count]);
					_encSelections.push(_extSelections[count]); //make encrypted selection match external selections
				}
				for (count = 0; count < _selections.length; count++) {
					payloadObj.selections.push(_selections[count]);	
				}				
				storeSelection(_rochambeau.lounge.clique.localPeerInfo.peerID, splicedSelections[0], true);
				payloadObj.selectedValue = splicedSelections[0];
				msg.data.payload = payloadObj;
				msg.updateSourceTargetForRelay();				
				broadcast(msg, false);				
				if (msg.targetPeerIDs == "*") {					
					updatePhaseChange();					
				}
			} else {
				//self game
				selectIndex = indexVal % _encSelections.length;
				splicedSelections = _encSelections.splice(selectIndex, 1);
				for (count = 0; count < _encSelections.length; count++) {
					payloadObj.encSelections.push(_encSelections[count]);
				}
				for (count = 0; count < _selections.length; count++) {
					payloadObj.selections.push(_selections[count]);
				}								
				storeSelection(_rochambeau.lounge.clique.localPeerInfo.peerID, splicedSelections[0], true);
				payloadObj.selectedValue = splicedSelections[0];
				var newMsg:RochambeauMessage = new RochambeauMessage();
				newMsg.createRochMessage(RochambeauMessage.SELECT, payloadObj);				
				broadcast(newMsg, true);
			}		
			gameIsBusy = false;
		}
		
		/**
		 * Begins the asynchronous process of decrypting all of the encrypted selections made by all active peers for this game.
		 * All encrypted selections and crypto keys for all active players must have been received prior to calling this function.
		 */
		private function startDecryptSelections():void {				
			if (_extKeys.length == activePeers.length) {
				gameIsBusy = true;
				_workKeys = new Vector.<ISRAKey>();
				for (var count:int = 0; count < _extKeys.length; count++) {
					_workKeys.push(_extKeys[count]);
				}				
				_workKeys.push(_key); //don't forget to include own key!			
				_currentDecryptObj = getNextSelectionForDecrypt();				
				if (_currentDecryptObj != null) {
					_currentDecryptObj.value = _currentDecryptObj.encValue;
					decryptSelection();
				} else {					
					gameIsBusy = false; //state not be released any earlier than this					
					updatePhaseChange();					
					//update phase ... all decryptions done!
				}
			} else {
				//Not enough keys to begin decryptions yet
			}
		}
		
		/**
		 * Begins the process of decrypting the currently-selected 
		 */
		private function decryptSelection():void {
			gameIsBusy = true;
			if (_workKeys.length>0) {
				var currentKey:ISRAKey = _workKeys[0];				
				var cryptoWorker:ICryptoWorkerHost = CryptoWorkerHost.nextAvailableCryptoWorker;
				cryptoWorker.directWorkerEventProxy = onDecryptSelectionProxy;
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, onDecryptSelection);				
				var msg:WorkerMessage = cryptoWorker.decrypt(_currentDecryptObj.value, currentKey, 16);
				this._messageFilter.addMessage(msg);
			} else {				
			}
		}
		
		/**		 
		 * @return Returns the next available encrypted-only selection for a peer. If all selections have decrypted values, null is returned.
		 */
		private function getNextSelectionForDecrypt():Object {
			for (var count:int = 0; count < _selectedValues.length; count++) {
				if ((_selectedValues[count].value == "") || (_selectedValues[count].value == null) || (_selectedValues[count].value == undefined)) {
					return (_selectedValues[count]);
				}
			}
			return (null);
		}
		
		/**
		 * Event responder invoked when an encrypted selection has been partially or fully decrypted.
		 * 
		 * @param	eventObj a CryptoWorkerHostEvent object.
		 */
		private function onDecryptSelection(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			clearAllCryptoWorkerHostListeners(CryptoWorkerHostEvent.RESPONSE, onDecryptSelection);					
			if (resultIsValid(eventObj.data, "result")) {				
				_currentDecryptObj.value = eventObj.data.result;
				_workKeys.shift();				
			}
			if (_workKeys.length > 0) {
				//decryption cycle continues
				setTimeout(decryptSelection, (Math.random()*multiInstanceDelay)+1);
			} else {				
				//decryption cycle for selection is complete
				if (isSelectionValid(_currentDecryptObj.value)) {					
					storeSelection(_currentDecryptObj.peerID, _currentDecryptObj.value, false);
					setTimeout(startDecryptSelections, (Math.random()*multiInstanceDelay)+1);					
				} else {					
					//a problem occured somewhere in the process - restarting the game here would be the easiest solution
					var errString:String = "FULLY DECRYPTED RESULT IS INCORRECT: " + eventObj.data.result + "\n";
					errString += "Available selections ("+_selections.length+"): " + _selections;
					var err:Error = new Error(errString);
					throw (err);					
				}
					
			}
		}
		
		/**
		 * Sends the current local (self) crypto keys to all active peers for this game in a RochambeauMessage.DECRYPT message. This function
		 * should only be invoked when all active peers have made their selections for this game.
		 */
		private function sendCryptoKeys():void {						
			if (_keysSent) {
				//only send keys once
				return;
			}
			_keysSent = true;
			var payloadObj:Object = new Object();
			payloadObj.decKeyHex = _key.decKeyHex;
			payloadObj.encKeyHex = _key.encKeyHex;
			payloadObj.modulusHex = _key.modulusHex;
			payloadObj.modBitLength = _key.modBitLength;
			payloadObj.sourcePeerID = sourcePeerID;
			var msg:RochambeauMessage = new RochambeauMessage();
			msg.createRochMessage(RochambeauMessage.DECRYPT, payloadObj);			
			msg.targetPeerIDs = "*";
			//not strictly needed but useful for identifying the message source (game ID)
			msg.sourcePeerIDs = sourcePeerID;
			msg.addSourcePeerID(_rochambeau.clique.localPeerInfo.peerID);			
			broadcast(msg, false);
		}		
		
		/**
		 * Broadcasts a message or all queued messages to all connected peers, or stores it the message if  the game is paused.
		 * 
		 * @param	msg The message to broadcast. If null and the game is not paused, all queued messages are broadcast.
		 * @param   autoTarget The active peer list (activePeers) will be automatically added as targets for the broadcast if true.
		 * If false, targets will not be automatically appended and should already be added.
		 */		
		private function broadcast(msg:IPeerMessage, autoTarget:Boolean=true):void {
			if (msg != null) {
				if (_paused) {
					_sendQueue.push(msg); //FIFO
					return;
				} else {
					//target peers on outgoing message have not been set...
					if (isSelfGame && autoTarget) {
						//this is our game...
						addTargetPeers(msg, activePeers, true);
					}
					_rochambeau.messageLog.addMessage(msg);
					_rochambeau.clique.broadcast(msg);
				}
			} else {
				if (_paused == false) {
					if (_sendQueue == null) {
						_sendQueue = new Vector.<IPeerMessage>();
						return;
					}
					while (_sendQueue.length > 0) {
						var currentMessage:IPeerMessage = _sendQueue.shift(); //FIFO
						if (isSelfGame && autoTarget) {
							addTargetPeers(currentMessage, activePeers, true);
						}
						_rochambeau.messageLog.addMessage(currentMessage);
						_rochambeau.clique.broadcast(currentMessage);
					}
				}
			}
		}
		
		/**
		 * Optionally adds target peer IDs from a supplied peer list to a target (usually outgoing) message.
		 * 
		 * @param	msg The IPeerMessage implementation, usually a RochambeauMessage instance, to which to add the target peerList.
		 * @param	peerList The list of INetCliqueMembet implementations to add to the message, in order.
		 * @param	onlyEmpty If true, the target peer list of msg will only modified if it's empty. If false, the target peer
		 * list of msg will be modified even if not empty.
		 */
		private function addTargetPeers(msg:IPeerMessage, peerList:Vector.<INetCliqueMember>, onlyEmpty:Boolean=true):void {
			if (peerList == null) {
				return;
			}
			if (peerList.length == 0) {
				return;
			}
			if (onlyEmpty) {
				if ((msg.targetPeerIDs != "") && (msg.targetPeerIDs != null)) {
					return;
				}
			}			
			for (var count:int = 0; count < peerList.length; count++) {
				//add currently connected peer
				var currentPeer:INetCliqueMember = peerList[count];
				msg.addTargetPeerID(currentPeer.peerID);
			}			
		}		
		
		/**
		 * Maps an asynchronously-generated plaintext (unencrypted) selection value to its initiating WorkerMessage request ID.
		 * This is used to match potentially out-of-order encrypted values with their plaintext values during the game's pre-generation process.
		 * 
		 * @param	msg The initiating WorkerMessage object.
		 * @param	selectionValue The plaintext (unencrypted) selection value to associate with the initiating WorkerMessage.
		 */
		private function mapRequestToSelection(msg:WorkerMessage, selectionValue:String):void {
			if (_RTSMap == null) {
				return;
			}
			if (msg == null) {
				return;
			}
			for (var count:int = 0; count < _RTSMap.length; count++) {
				if ((_RTSMap[count].requestID == msg.requestId) || (_RTSMap[count].selection == selectionValue)) {
					//already mapped
					return;
				}
			}
			var mapObj:Object = new Object();
			mapObj.requestID = msg.requestId;
			mapObj.selection = selectionValue;
			_RTSMap.push(mapObj);
		}
		
		/**
		 * Finds a mapping object, as created by the mapRequestToSelection function, for a specific request ID from a WorkerMessage.
		 * 
		 * @param	requestID A WorkerMessage request ID for which to find the RTS mapping object.
		 * 
		 * @return An RTS mapping object containing the original "requestID" and the associated plaintext (unencrypted) "selection", or
		 * null if no mapping object exists.
		 */
		private function getRTSMapByRequestID(requestID:String):Object {
			if (_RTSMap == null) {
				return (null);
			}
			for (var count:int = 0; count < _RTSMap.length; count++) {
				var currentMapObj:Object = _RTSMap[count];
				if (currentMapObj.requestID == requestID) {
					return (currentMapObj);
				}
			}
			return (null);
		}
		
		/**
		 * Finds the index of a plaintext (unencrypted) selection value within the _selection array from a RTS mapping object.
		 * 
		 * @param	RTSMapObject The RTS mapping object for which to find the plaintext index.
		 * 
		 * @return The index of the plaintext (unencrypted) selection value within the _selections array that matches the supplied RTS mapping
		 * object, or null if one can't be found.
		 */
		private function RTSMapSelectionIndex(RTSMapObject:Object):int {
			if (RTSMapObject == null) {
				return ( -1);
			}
			if ((RTSMapObject.requestID == null) || ((RTSMapObject.requestID == ""))) {
				return ( -1);
			}
			if ((RTSMapObject.selection == null) || ((RTSMapObject.selection == ""))) {
				return ( -1);
			}			
			if (_RTSMap == null) {
				return (-1);
			}
			//first find matching selection value
			var selectionValue:String = null;
			for (var count:int = 0; count < _RTSMap.length; count++) {
				var currentMapObj:Object = _RTSMap[count];
				if (currentMapObj.requestID == RTSMapObject.requestID) {
					selectionValue = RTSMapObject.selection;
				}
			}
			if ((selectionValue==null) || (selectionValue=="")) {
				return (-1);
			}
			//second find index based on found selection value
			for (count = 0; count < _selections.length; count++) {
				var currentSelection:String = _selections[count];
				if (currentSelection == selectionValue) {
					return (count);
				}
			}
			return (-1);
		}		

		/**
		 * Verifies the validity of a supplied result (for example, CryptoWorker) or message value.
		 * 
		 * @param	input The containing object within which resultVariable is to be tested for validity.
		 * @param	resultVariable The name of the property within the input object to check for validity.
		 * 
		 * @return True if resultVariable exists within input and is valid, false otherwise.
		 */
		private function resultIsValid(input:Object, resultVariable:String):Boolean {
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
		
		/**
		 * Trims the ends of the _selections, _encSelection, and _extSelections arrays to the specified number of selections. This is 
		 * usually used with pre-generated values when there are more selections than required for the game.
		 * 
		 * @param	requiredLength The number of selections to trim the arrays to.
		 */
		private function trimSelectionsTo(requiredLength:uint):void {			
			try {
				_selections = _selections.slice(0, int(requiredLength));
			} catch (err:*) {				
			}
			try {
				_encSelections = _encSelections.slice(0, int(requiredLength));
			} catch (err:*) {				
			}
			try {
				_extSelections = _extSelections.slice(0, int(requiredLength));
			} catch (err:*) {				
			}
		}
		
		/**
		 * Updates the internal phase value when the game has successfully completed a phase. This function should be called with
		 * care since the phase is updated every time it's invoked.
		 */
		private function updatePhaseChange():void {			
			//the following structure implies that we only expect three group (*) broadcasts per game
			switch (_phaseCompleted) {
				case NO_PHASE :
					_phaseCompleted = ENCRYPTION_PHASE;
					break;
				case ENCRYPTION_PHASE :
					_phaseCompleted = SELECTION_PHASE;
					break;
				case SELECTION_PHASE :
					_phaseCompleted = DECRYPTION_PHASE;
					break;
				case DECRYPTION_PHASE :
					var err:Error = new Error("Too many phase updates!");
					DebugView.addText (err);
					throw (err)
					break;	
				default: break;					
			}			
			var event:RochambeauGameEvent = new RochambeauGameEvent(RochambeauGameEvent.PHASE_CHANGE);
			dispatchEvent(event);
		}	
		
		/**
		 * Stores included selections and/or encrypted selections for this game from an external peer message.
		 * 
		 * @param	incomingMsg An IPeerMessage implementation containing selections for the game
		 */
		private function storeMessageSelections(incomingMsg:IPeerMessage):void {				
			//data validation should be done here to ensure continuity (some data should match before and after update)				
			try {				
				//populate only once				
				if (_selections.length == 0) {					
					_selections = new Vector.<String>();					
					for (var count:int = 0; count < incomingMsg.data.payload.selections.length; count++) {
						var currentSelection:String = incomingMsg.data.payload.selections[count] as String;
						_selections.push(currentSelection);
					}
				}
			} catch (err:*) {		
				DebugView.addText(err.getStackTrace());
			}			
			try {
				if (incomingMsg.data.payload.encSelections.length > -1) {
					_encSelections = new Vector.<String>();	
					_extSelections = new Vector.<String>();	
				}
				for (count = 0; count < incomingMsg.data.payload.encSelections.length; count++) {
					currentSelection = incomingMsg.data.payload.encSelections[count] as String;						
					_extSelections.push(currentSelection);
					_encSelections.push(currentSelection);
				}
			} catch (err:*) {
				DebugView.addText(err.getStackTrace());
			}			
		}	
				
		/**
		 * Clears all CryptoWorkerHost listeners for a specific event type for this game instance.
		 * 
		 * @param	eventType The event type for which to clear any and all listeners for this game instance.
		 * @param	responder The responder function associated with the event type.
		 */		
		private function clearAllCryptoWorkerHostListeners(eventType:String, responder:Function):void {
			var maxWorkers:uint = _rochambeau.lounge.settings["getSettingData"]("defaults", "maxcryptoworkers");
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
	}
}
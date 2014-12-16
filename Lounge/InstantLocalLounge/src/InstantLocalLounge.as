/**
* Document class for Instant Local Lounge over LAN / WLAN.
* 
* This implementation uses a simple delay timer to establish the leader/dealer role.
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package 
{
		
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.text.TextField;
	import flash.system.Security;
	import flash.system.Capabilities;
	import flash.utils.setInterval;
	import flash.utils.setTimeout;
	import flash.utils.clearTimeout;
	import flash.utils.clearInterval;
	import org.cg.interfaces.ILounge;
	import org.cg.GlobalSettings;
	import org.cg.GlobalDispatcher;
	import org.cg.events.SettingsEvent;
	import org.cg.events.GameEngineEvent;
	import org.cg.ViewManager;
	import org.cg.NetCliqueManager;
	import p2p3.events.NetCliqueEvent;
	import p2p3.interfaces.INetClique;	
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.workers.CryptoWorkerHost;
	import p2p3.PeerMessage;
	import p2p3.PeerMessageLog;	
	import com.bit101.components.PushButton;
	import flash.events.MouseEvent;	
	import org.cg.DebugView;
		
	dynamic public class InstantLocalLounge extends MovieClip implements ILounge 
	{
		
		public static const version:String = "1.0"; //ILL version
		public static const resetConfig:Boolean = true; //Reload default settings XML at startup?
		public static var xmlConfigFilePath:String = "./xml/settings.xml"; //Default settings file
		private static var _illLog:PeerMessageLog = new PeerMessageLog();
		private static var _cryptoWorkers:Vector.<CryptoWorkerHost> = new Vector.<CryptoWorkerHost>();
		private static var _currentCWIndex:uint = 0; //0-based index of current crypto worker to apply next action to (from _cryptoWorkers)
		
		private var _leaderSet:Boolean = false; //Has game leader /dealer been established?
		private var _leaderIsMe:Boolean = false; //Am I game leader / dealer?
		private var _currentLeader:INetCliqueMember = null; //Current game leader / dealer
		private var _delayFrames:Number; //Leader start delay counter
		private var _playersReady:uint = 0; //Number of other players joined and ready to play
		
		private static var _netClique:INetClique;
		private var _maxCryptoByteLength:uint = 0; //Maximum allowable CBL
		public var activeConnectionsText:TextField; //Displays number of clique peer connections
		public var startGame:PushButton;
		
		private var _currentGame:MovieClip; //Game instance loaded at runtime
		
		public function InstantLocalLounge():void 
		{		
			DebugView.addText ("InstantLocalLounge v" + version);
			DebugView.addText ("CPU: " + Capabilities.cpuArchitecture);			
			DebugView.addText ("XML config file path: " + xmlConfigFilePath);
			DebugView.addText ("---");
			try {
				Security.allowDomain("*");
				Security.allowInsecureDomain("*");			
			} catch (err:*) {				
			}
			if (stage) {
				initialize();
			} else {
				addEventListener(Event.ADDED_TO_STAGE, initialize);
			}
		}
		
		/**
		 * True if the leader / dealer role has been established.
		 */
		public function get leaderSet():Boolean 
		{
			return (_leaderSet);
		}
		
		/**
		 * True if the leader / dealer role is the local peer.
		 */
		public function get leaderIsMe():Boolean 
		{
			return (_leaderIsMe);
		}
		
		/**
		 * Reference to the global settings handler.
		 */
		public function get settings():Class 
		{
			return (GlobalSettings);
		}
		
		/**
		 * Reference to the current clique connection.
		 */
		public function get clique():INetClique 
		{
			return (_netClique);
		}
		
		/**
		 * Reference to the current game leader / dealer.
		 */
		public function get currentLeader():INetCliqueMember 
		{
			return (_currentLeader);
		}
		
		public function set currentLeader(leaderSet:INetCliqueMember):void 
		{
			_currentLeader = leaderSet;
		}
		
		/**
		 * A reference to the next available CryptoWorkerHost instance. The CryptoWorker may be busy with
		 * an operation but using this method to retrieve a valid reference balances the queue load on all current
		 * CryptoWorkers.
		 */
		public function get nextAvailableCryptoWorker():CryptoWorkerHost 
		{
			var concurrency:Boolean = GlobalSettings.toBoolean(GlobalSettings.getSettingData("defaults", "concurrency"));			
			if (concurrency) {
				var maxWorkers:uint = 2;
				try {
					maxWorkers=uint(GlobalSettings.getSettingData("defaults", "maxcryptoworkers"));					
				} catch (err:*) {
					maxWorkers = 2;
				}				
				if (_cryptoWorkers.length < maxWorkers) {									
					var newWorkerHost:CryptoWorkerHost = new CryptoWorkerHost(true);
					newWorkerHost.start();
					_cryptoWorkers.push(newWorkerHost);
					_currentCWIndex = _cryptoWorkers.length - 1;
					return (newWorkerHost);
				}
				_currentCWIndex++;
				if (_currentCWIndex >= _cryptoWorkers.length) {
					_currentCWIndex = 0;
				}				
			} else {
				//length should never be > 1
				if (_cryptoWorkers.length==0) {
					newWorkerHost = new CryptoWorkerHost(false);
					_cryptoWorkers.push(newWorkerHost);				
				}
				_currentCWIndex = 0;
			}			
			return (_cryptoWorkers[_currentCWIndex]);
		}
		
		/**
		 * The maximum Crypto Byte Length.
		 */
		public function get maxCryptoByteLength():uint 
		{
			if (_maxCryptoByteLength == 0) {
				_maxCryptoByteLength = uint(GlobalSettings.getSettingData("defaults", "cryptobytelength"));
			}
			return (_maxCryptoByteLength);
		}
		
		public function set maxCryptoByteLength(mcblSet:uint):void {
			_maxCryptoByteLength = mcblSet;
		}
		
		/**
		 * Invoked when the loaded game engine dispatches a READY event.
		 * 
		 * @param	eventObj A GameEngineEvent event object.
		 */
		public function onGameEngineReady(eventObj:GameEngineEvent):void 
		{
			DebugView.addText ("InstantLocalLounge.onGameEngineReady");
			_currentGame = eventObj.source as MovieClip;
			//note the pairing in "case InstantLoungeMessage.PLAYER_READY" above in onPeerMessage -- is there a better way to handle this?
			if (!_leaderIsMe) {
				_currentGame.start();
			}			
			var ilMessage:InstantLoungeMessage = new InstantLoungeMessage();			
			ilMessage.createLoungeMessage(InstantLoungeMessage.PLAYER_READY);				
			_netClique.broadcast(ilMessage);
			_illLog.addMessage(ilMessage);
		}

		/**
		 * Invoked when the loaded game engine dispatches a CREATED event.
		 * 
		 * @param	eventObj A GameEngineEvent event object.
		 */
		public function onGameEngineCreated(eventObj:GameEngineEvent):void 
		{
			DebugView.addText ("InstantLocalLounge.onGameEngineCreated");			
			eventObj.source.initialize(null, resetConfig, this);
		}  
		
		/**
		 * Processes a frame-based delay.
		 * 
		 * @param	eventObj Standard Event object.
		 */
		private function delayLoop(eventObj:Event):void 
		{
			_delayFrames--;			
			if (_delayFrames <= 0) {
				onLeaderDelay();
			}
 		}
		
		/**
		 * Begin delay to wait for leader / dealer. This role will be assumed if no leader responds within the timeout period.
		 */
		private function startLeaderDelay():void 
		{
			clearLeaderDelay();
			try {
				var delayVal:Number = new Number(GlobalSettings.getSettingData("defaults", "leadertimeout"));
			} catch (err:* ) {
				delayVal = 2;
			}
			_delayFrames = delayVal * stage.frameRate;			
			addEventListener(Event.ENTER_FRAME, delayLoop);
		}
		
		/**
		 * Invoked when the leader / dealer role is assumed after startup delay.
		 */
		private function onLeaderDelay():void 
		{
			DebugView.addText ("InstantLocalLounge.onLeaderDelay -- now assuming leader role.");
			clearLeaderDelay();
			if (!_leaderSet) {
				startGame.enabled = true;
				startGame.label = "START GAME";
				_leaderIsMe = true;
			} else {
				_leaderIsMe = false;
			}
			_leaderSet = true;
		}
		
		/**
		 * Clears the leader /dealer delay event listener.
		 */
		private function clearLeaderDelay():void 
		{			
			try {
				removeEventListener(Event.ENTER_FRAME, delayLoop);				
			} catch (err:*) {				
			}			
		}
		
		/**
		 * Updates the UI with the current number of clique connections.
		 * 
		 * @param	connections New number of connections to update the UI with.
		 */
		private function updateConnectionsCount(connections:int):void 
		{
			activeConnectionsText.text = String(connections);
		}
		
		
		/**
		 * Invoked when a connection to a clique is established.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onCliqueConnect(eventObj:NetCliqueEvent):void 
		{
			DebugView.addText ("InstantLocalLounge.onCliqueConnect");
			DebugView.addText ("   My peer ID: "+eventObj.target.localPeerInfo.peerID);
			_playersReady = 0;
			_netClique.removeEventListener(NetCliqueEvent.CLIQUE_CONNECT, onCliqueConnect);			
			ViewManager.render(GlobalSettings.getSetting("views", "debug"), this);
			ViewManager.render(GlobalSettings.getSetting("views", "start"), this);
			startGame.enabled = false;
			startGame.label = "...CONNECTING...";
			startGame.addEventListener(MouseEvent.CLICK, onStartGameClick);		
			try {			
				updateConnectionsCount(1);
			} catch (err:*) {				
			}
			startLeaderDelay();
		}
		
		/**
		 * Invoked when a new peer connects to a connected clique.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onPeerConnect(eventObj:NetCliqueEvent):void 
		{
			DebugView.addText("InstantLocalLounge.onPeerConnect: " + eventObj.memberInfo.peerID);
			clearLeaderDelay();	
			try {			
				updateConnectionsCount(_netClique.connectedPeers.length + 1);				
			} catch (err:*) {				
			}
			if (_leaderIsMe) {				
				var illMessage:InstantLoungeMessage = new InstantLoungeMessage();
				illMessage.createLoungeMessage(InstantLoungeMessage.ASSUME_DEALER);				
				_netClique.broadcast(illMessage);
				_illLog.addMessage(illMessage);
			} else {				
				illMessage = new InstantLoungeMessage();
				var infoObj:Object = new Object();				
				infoObj.cryptoByteLength= uint(GlobalSettings.getSettingData("defaults", "cryptobytelength"));
				illMessage.createLoungeMessage(InstantLoungeMessage.PLAYER_INFO, infoObj);				
				_netClique.broadcast(illMessage);
				_illLog.addMessage(illMessage);
			}
		}
		
		/**
		 * Invoked when a peer disconnects from a connected clique.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onPeerDisconnect(eventObj:NetCliqueEvent):void 
		{			
			try {
				_playersReady--;
				updateConnectionsCount(_netClique.connectedPeers.length + 1);
			} catch (err:*) {				
			}
		}
		
		/**		 
		 * Handles all incoming peer messages from the connexted clique. Lounge messages are logged and processed.
		 * Non-lounge messages are discarded.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onPeerMessage(eventObj:NetCliqueEvent):void 
		{				
			var peerMsg:InstantLoungeMessage = InstantLoungeMessage.validateLoungeMessage(eventObj.message);						
			if (peerMsg == null) {				
				//not a lounge message
				return;
			}
			DebugView.addText("InstantLocalLounge.onPeerMessage");			
			if (eventObj.message.hasSourcePeerID(_netClique.localPeerInfo.peerID)) {
				//already processed by us				
				return;
			}
			_illLog.addMessage(eventObj.message);			
			if (eventObj.message.hasTargetPeerID(_netClique.localPeerInfo.peerID)) {
				//message is for us or for everyone ("*")
				switch (peerMsg.loungeMessageType) {
					case InstantLoungeMessage.ASSUME_DEALER:
						DebugView.addText ("InstantLocalLounge.onPeerMessage InstantLoungeMessage.ASSUME_DEALER");
						DebugView.addText ("   Dealer peer ID: " + peerMsg.sourcePeerIDs);						
						_leaderIsMe = false;
						startGame.enabled = false;							
						startGame.label = peerMsg.sourcePeerIDs;
						_leaderSet = true;
						_currentLeader = eventObj.memberInfo;						
						break;
					case InstantLoungeMessage.GAME_START:						
						DebugView.addText ("InstantLocalLounge.onPeerMessage InstantLoungeMessage.GAME_START");
						startGame.enabled = false;							
						startGame.visible = false;						
						ViewManager.render(GlobalSettings.getSetting("views", "game"), this);						
						break;
					case InstantLoungeMessage.PLAYER_INFO:
						DebugView.addText ("InstantLocalLounge.onPeerMessage InstantLoungeMessage.PLAYER_INFO");
						DebugView.addText ("   Peer Crypto Byte Length: " + peerMsg.data.cryptoByteLength);
						if (_leaderIsMe) {							
							var peerCBL:uint = uint(peerMsg.data.cryptoByteLength);
							var localCBL:uint = uint(GlobalSettings.getSettingData("defaults", "cryptobytelength"));
							if (peerCBL < localCBL) {
								DebugView.addText ("   Peer " + peerMsg.sourcePeerIDs + " has changed the clique Crypto Byte Length to: " + peerMsg.data.cryptoByteLength);
								GlobalSettings.setSettingData("defaults", "cryptobytelength", String(peerMsg.data.cryptoByteLength));
								GlobalSettings.saveSettings();
							}
						}
						break;
					case InstantLoungeMessage.PLAYER_READY:
						DebugView.addText ("InstantLocalLounge.onPeerMessage InstantLoungeMessage.PLAYER_READY");
						_playersReady++;
						DebugView.addText ("   Players ready=" + _playersReady);
						DebugView.addText ("   # of connected peers=" + _netClique.connectedPeers.length);
						if (_playersReady >= _netClique.connectedPeers.length) {
							DebugView.addText ("   All players are ready.");
							try {
								if (_leaderIsMe) {
									_currentGame.start();					
								}
							} catch (err:*) {								
							}
						}
						break;	
					default: 
						DebugView.addText("   Unrecognized peer message:");
						DebugView.addText(peerMsg);
						break;
				}				
			}		
		}
		
		/**
		 * Handler for clicks on the Start Game button.
		 * 
		 * @param	eventObj A MouseEvent object.
		 */
		private function onStartGameClick(eventObj:MouseEvent):void 
		{
			var illMessage:InstantLoungeMessage = new InstantLoungeMessage();
			illMessage.createLoungeMessage(InstantLoungeMessage.GAME_START);			
			_netClique.broadcast(illMessage);
			_illLog.addMessage(illMessage);
			startGame.enabled = false;							
			startGame.visible = false;
			ViewManager.render(GlobalSettings.getSetting("views", "game"), this);					
		}		
		
		/**
		 * Invoked when the GlobalSettings data is loaded and parsed.
		 * 
		 * @param	eventObj A SettingsEvent object.
		 */
		private function onLoadSettings(eventObj:SettingsEvent):void 
		{
			DebugView.addText ("InstantLocalLounge.onLoadSettings");			
			DebugView.addText (GlobalSettings.data);			
			_netClique = NetCliqueManager.getInitializedInstance("RTMFP_LAN");
			_netClique.addEventListener(NetCliqueEvent.CLIQUE_CONNECT, onCliqueConnect);
			_netClique.addEventListener(NetCliqueEvent.PEER_CONNECT, onPeerConnect);
			_netClique.addEventListener(NetCliqueEvent.PEER_DISCONNECT, onPeerDisconnect);
			_netClique.addEventListener(NetCliqueEvent.PEER_MSG, onPeerMessage);
			if (_netClique == null) {
				DebugView.addText("Couldn't initialize RTMFP_LAN NetClique. Can't continue.");
				var err:Error = new Error("Couldn't initialize RTMFP_LAN NetClique. Can't continue.");
				throw (err);
			}
			DebugView.addText("Connecting to NetClique: "+_netClique.connect(GlobalSettings.getSettingData("defaults", "rtmfpgroup")));
		}
		
		/**
		 * Initializes the Lounge instance when the stage exists.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function initialize(eventObj:Event = null):void 
		{
			DebugView.addText ("InstantLocalLounge.initialize");
			removeEventListener(Event.ADDED_TO_STAGE, initialize);
			GlobalDispatcher.addEventListener(GameEngineEvent.CREATED, onGameEngineCreated);
			GlobalDispatcher.addEventListener(GameEngineEvent.READY, onGameEngineReady);
			GlobalSettings.dispatcher.addEventListener(SettingsEvent.LOAD, onLoadSettings);
			GlobalSettings.loadSettings(xmlConfigFilePath, resetConfig);
		}
	}	
}
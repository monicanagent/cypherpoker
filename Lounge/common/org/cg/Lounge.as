/**
* Main Lounge class. This class is usually extended by specific runtime implementations.
* 
* This implementation uses a simple delay timer to establish the leader/dealer role.
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg
{
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.net.URLVariables;
	import flash.text.TextField;
	import flash.system.Security;
	import flash.system.Capabilities;
	import flash.utils.setInterval;
	import flash.utils.setTimeout;
	import flash.utils.clearTimeout;
	import flash.utils.clearInterval;
	import LoungeMessage;
	import org.cg.interfaces.ILounge;
	import org.cg.GlobalSettings;
	import org.cg.GlobalDispatcher;
	import org.cg.events.SettingsEvent;
	import org.cg.events.GameEngineEvent;
	import org.cg.GameParameters;
	import org.cg.interfaces.IGameParameters;
	import org.cg.ViewManager;
	import org.cg.NetCliqueManager;
	import p2p3.events.NetCliqueEvent;
	import p2p3.interfaces.INetClique;	
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.PeerMessageHandler;
	import p2p3.events.PeerMessageHandlerEvent;
	import p2p3.Rochambeau;
	import p2p3.events.RochambeauEvent;
	import org.cg.Status;
	import p2p3.workers.CryptoWorkerHost;
	import p2p3.PeerMessage;
	import p2p3.PeerMessageLog;	
	import flash.events.MouseEvent;	
	import org.cg.DebugView;
	import flash.utils.getDefinitionByName;
	import flash.ui.Keyboard;
	import flash.system.Worker;
	import EthereumWeb3Client;
		
	dynamic public class Lounge extends MovieClip implements ILounge 
	{		
		public static const version:String = "1.3"; //Lounge version
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
		
		private static var _netClique:INetClique; //default clique communications handler
		private var _maxCryptoByteLength:uint = 0; //maximum allowable CBL
		public var activeConnectionsText:TextField; //displays number of clique peer connections
		public var startingPlayerBalances:TextField; //input field for starting player balances	
		private var _rochambeau:Rochambeau = null;
		
		private var _connectView:MovieClip; //container for the connect view
		private var _startView:MovieClip; //container for the start game view
		private var _gameView:MovieClip; //container for the game view
		private var _gameParameters:GameParameters; //startup parameters for the game
		private var _currentGame:MovieClip; //game instance loaded at runtime
		private var _peerMessageHandler:PeerMessageHandler; //message handler for incoming messages
		private var _messageLog:PeerMessageLog = new PeerMessageLog(); //message log for _peerMessageHandler
		private var _errorLog:PeerMessageLog = new PeerMessageLog(); //error log for _peerMessageHandler
		private var _privateGameID:String = new String();
		
		private var _ethereumClient:EthereumWeb3Client; //Ethereum Web3 integration library
		private var _ethereum:Ethereum; //Ethereum library
		private var _contracts:Vector.<String> = new Vector.<String>(); //index 0 is the most current contract
		
		public function Lounge():void 
		{
			DebugView.addText ("Lounge v" + version);
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
		
		public function set leaderIsMe(leaderSet:Boolean):void
		{
			_leaderIsMe = leaderSet;
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
		 * The initial parameters supplied to the currently loaded game.
		 */
		public function get gameParameters():IGameParameters
		{
			return (_gameParameters);
		}
		
		/**
		 * Invoked when the start view is fully or partially rendered to set default values and
		 * visibilities.
		 */
		public function onRenderStartView():void
		{
			try {			
				updateConnectionsCount(1);				
				_startView.startGame.removeEventListener(MouseEvent.CLICK, onStartGameClick);
				_startView.startGame.addEventListener(MouseEvent.CLICK, onStartGameClick);
				_startView.startingPlayerBalances.text = "50.00";
				_startView.startingPlayerBalances.restrict = "0-9 .";
				_startView.startingPlayerBalances.visible = true;
			} catch (err:*) {				
			}			
		}		
		
		/**
		 * A reference to the next available CryptoWorkerHost instance. The CryptoWorker may be busy with
		 * an operation but using this method to retrieve a valid reference balances the queue load on all current
		 * CryptoWorkers.
		 */
		public function get nextAvailableCryptoWorker():CryptoWorkerHost 
		{
			var concurrency:Boolean = GlobalSettings.toBoolean(GlobalSettings.getSettingData("defaults", "concurrency"));
			if (Worker.isSupported == false) {
				concurrency = false;
			}		
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
		
		public function set maxCryptoByteLength(mcblSet:uint):void 
		{
			_maxCryptoByteLength = mcblSet;
		}
				
		/**
		 * Reference to the active Ethereum client library.
		 */
		public function get ethereum():Ethereum
		{
			return (_ethereum);
		}	
		
		/**
		 * Invoked when the start view is fully or partially rendered to set default values and
		 * visibilities.
		 */
		public function onRenderConnectView():void
		{
			try {				
				_connectView.connectLANGame.removeEventListener(MouseEvent.CLICK, this.onConnectLANGameClick);
				_connectView.connectLANGame.addEventListener(MouseEvent.CLICK, this.onConnectLANGameClick);
				_connectView.connectWebGame.removeEventListener(MouseEvent.CLICK, this.onConnectWebGameClick);
				_connectView.connectWebGame.addEventListener(MouseEvent.CLICK, this.onConnectWebGameClick);
			} catch (err:*) {			
			}
		}
		
		/**
		 * Invoked when the loaded game engine dispatches a READY event.
		 * 
		 * @param	eventObj A GameEngineEvent event object.
		 */
		public function onGameEngineReady(eventObj:GameEngineEvent):void 
		{
			DebugView.addText ("Lounge.onGameEngineReady");
			_currentGame = eventObj.source as MovieClip;
			//note the pairing in "case LoungeMessage.PLAYER_READY" above in onPeerMessage -- is there a better way to handle this?
			if (!_leaderIsMe) {
				_currentGame.start();
			}			
			var ilMessage:LoungeMessage = new LoungeMessage();			
			ilMessage.createLoungeMessage(LoungeMessage.PLAYER_READY);				
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
			DebugView.addText ("Lounge.onGameEngineCreated");			
			eventObj.source.initialize(null, resetConfig, this);
		} 	
		
		/**
		 * Updates the UI with the current number of clique connections.
		 * 
		 * @param	connections New number of connections to update the UI with.
		 */
		private function updateConnectionsCount(connections:int):void 
		{
			_startView.activeConnectionsText.text = String(connections);
		}

		/**
		 * Invoked when a connection to a clique is established.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onCliqueConnect(eventObj:NetCliqueEvent):void 
		{
			DebugView.addText ("Lounge.onCliqueConnect");
			DebugView.addText ("   My peer ID: " + eventObj.target.localPeerInfo.peerID);
			DebugView.addText ("   Default Ethereum account: " + ethereum.web3.eth.accounts[0]);
			ethereum.mapPeerIDToEthAddr(eventObj.target.localPeerInfo.peerID, ethereum.web3.eth.accounts[0]);
			_playersReady = 0;
			_netClique.removeEventListener(NetCliqueEvent.CLIQUE_CONNECT, onCliqueConnect);
			_rochambeau = new Rochambeau(this, 8, GlobalSettings.useCryptoOptimizations);
			_rochambeau.addEventListener(RochambeauEvent.COMPLETE, this.onLeaderFound);		
		}
		
		/**
		 * Handles click events on the main "START GAME" button
		 * 
		 * @param	eventObj A MouseEvent object.
		 */
		private function onStartGameClick(eventObj:MouseEvent):void
		{	
			_startView.startGame.alpha = 0.5;
			_startView.startGame.removeEventListener(MouseEvent.CLICK, onStartGameClick);			
			_rochambeau.start();
		}
		
		
		/**
		 * Invoked when a new peer connects to a connected clique.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onPeerConnect(eventObj:NetCliqueEvent):void 
		{
			DebugView.addText("Lounge.onPeerConnect: " + eventObj.memberInfo.peerID);			
			try {			
				updateConnectionsCount(_netClique.connectedPeers.length + 1);				
			} catch (err:*) {				
			}
			var illMessage:LoungeMessage = new LoungeMessage();
			var infoObj:Object = new Object();				
			infoObj.cryptoByteLength = uint(GlobalSettings.getSettingData("defaults", "cryptobytelength"));
			infoObj.ethAddress = ethereum.web3.eth.accounts[0]; //main ethereum account
			illMessage.createLoungeMessage(LoungeMessage.PLAYER_INFO, infoObj);				
			_netClique.broadcast(illMessage);			
			_illLog.addMessage(illMessage);			
		}
		
		/**
		 * Invoked when a peer disconnects from a connected clique.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onPeerDisconnect(eventObj:NetCliqueEvent):void 
		{
			DebugView.addText("InstantLocalLoung.onPeerDisconnect: " + eventObj.memberInfo.peerID);
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
		private function onPeerMessage(eventObj:PeerMessageHandlerEvent):void 
		{				
			var peerMsg:LoungeMessage = LoungeMessage.validateLoungeMessage(eventObj.message);						
			if (peerMsg == null) {					
				//not a lounge message
				return;
			}			
			if (eventObj.message.hasSourcePeerID(_netClique.localPeerInfo.peerID)) {
				//already processed by us				
				return;
			}
			_illLog.addMessage(eventObj.message);			
			if (eventObj.message.hasTargetPeerID(_netClique.localPeerInfo.peerID)) {
				//message is for us or for everyone ("*")
				switch (peerMsg.loungeMessageType) {					
					case LoungeMessage.GAME_START:						
						DebugView.addText ("LoungeMessage.GAME_START");
						ViewManager.render(GlobalSettings.getSetting("views", "game"), _gameView);						
						break;
					case LoungeMessage.PLAYER_INFO:
						DebugView.addText ("LoungeMessage.PLAYER_INFO");
						DebugView.addText ("   Peer: " + peerMsg.getSourcePeerIDList()[0].peerID);
						DebugView.addText ("   Ethereum address: " + peerMsg.data.ethAddress);
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
						ethereum.mapPeerIDToEthAddr(peerMsg.getSourcePeerIDList()[0].peerID, peerMsg.data.ethAddress);
						updateConnectionsCount(clique.connectedPeers.length + 1);
						break;
					case LoungeMessage.PLAYER_READY:
						DebugView.addText ("LoungeMessage.PLAYER_READY");
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
			} else {
				DebugView.addText ("   Message not for us!");
				DebugView.addText ("   Targets: " + peerMsg.targetPeerIDs);
			}
		}
		
		/**
		 * If current instance is the dealer, signals to connected peers that the game should now begin and renders the main game view.
		 * 		 
		 */
		private function beginGame():void 
		{	
			if (_leaderIsMe) {
				ViewManager.render(GlobalSettings.getSetting("views", "game"), _gameView);
				var illMessage:LoungeMessage = new LoungeMessage();
				illMessage.createLoungeMessage(LoungeMessage.GAME_START);
				_illLog.addMessage(illMessage);
				_netClique.broadcast(illMessage);				
			}			
		}		
		
		/**
		 * Handler for clicks on the "Connect LAN/WLAN Game" button.
		 * 
		 * @param	eventObj A MouseEvent object.
		 */
		private function onConnectLANGameClick(eventObj:MouseEvent):void 
		{			
			_connectView.connectLANGame.removeEventListener(MouseEvent.CLICK, this.onConnectLANGameClick);
			ViewManager.render(GlobalSettings.getSetting("views", "localstart"), _startView, onRenderStartView);
			_netClique = NetCliqueManager.getInitializedInstance("RTMFP_LAN");			
			_peerMessageHandler = new PeerMessageHandler(_messageLog, _errorLog);
			_peerMessageHandler.addEventListener(PeerMessageHandlerEvent.PEER_MSG, onPeerMessage);
			_peerMessageHandler.addToClique(_netClique);
			_netClique.addEventListener(NetCliqueEvent.CLIQUE_CONNECT, onCliqueConnect);
			_netClique.addEventListener(NetCliqueEvent.PEER_CONNECT, onPeerConnect);
			_netClique.addEventListener(NetCliqueEvent.PEER_DISCONNECT, onPeerDisconnect);
			_netClique.connect(GlobalSettings.getSettingData("defaults", "rtmfpgroup"));
			this.removeChild(_connectView);
		}
		
		/**
		 * Responds to click events on the "Connect to Web Game" button.
		 * 
		 * @param	eventObj A MouseEvent object.
		 */
		private function onConnectWebGameClick(eventObj:MouseEvent):void		
		{			
			_connectView.connectWebGame.removeEventListener(MouseEvent.CLICK, this.onConnectWebGameClick);
			ViewManager.render(GlobalSettings.getSetting("views", "localstart"), _startView, onRenderStartView);
			_netClique = NetCliqueManager.getInitializedInstance("RTMFP_INET");
			_netClique["developerKey"] = "62e2b64ae0b7b80aafb8166b-de8c7d88fb19";
			_peerMessageHandler = new PeerMessageHandler(_messageLog, _errorLog);			
			_peerMessageHandler.addEventListener(PeerMessageHandlerEvent.PEER_MSG, onPeerMessage);
			_peerMessageHandler.addToClique(_netClique);
			_netClique.addEventListener(NetCliqueEvent.CLIQUE_CONNECT, onCliqueConnect);
			_netClique.addEventListener(NetCliqueEvent.PEER_CONNECT, onPeerConnect);
			_netClique.addEventListener(NetCliqueEvent.PEER_DISCONNECT, onPeerDisconnect);			
			_netClique.connect(_connectView.privateGameID.text);			
		}
				
		/**
		 * Invoked when the GlobalSettings data is loaded and parsed.
		 * 
		 * @param	eventObj A SettingsEvent object.
		 */
		private function onLoadSettings(eventObj:SettingsEvent):void 
		{
			DebugView.addText ("Lounge.onLoadSettings");			
			DebugView.addText (GlobalSettings.data);			
			_gameParameters = new GameParameters();
			_connectView = new MovieClip();
			_startView = new MovieClip();
			_gameView = new MovieClip();
			this.addChild(_connectView);
			this.addChild(_startView);
			this.addChild(_gameView);				
			ViewManager.render(GlobalSettings.getSetting("views", "connect"), _connectView, onRenderConnectView);
			ViewManager.render(GlobalSettings.getSetting("views", "debug"), this);			
		}	
		
		/**
		 * Invoked when the initial leader has been determined via Rochambeau.
		 * 
		 * @param	eventObj A RochambeauEvent object.
		 */
		private function onLeaderFound(eventObj:RochambeauEvent):void
		{			
			_currentLeader = _rochambeau.winningPeer; 
			_leaderSet = true;
			_rochambeau.removeEventListener(RochambeauEvent.COMPLETE, this.onLeaderFound);			
			if (_rochambeau.winningPeer.peerID == clique.localPeerInfo.peerID) {
				DebugView.addText("   I am the initial dealer.");
				try {		
					_gameParameters.funBalances = Number(_startView.startingPlayerBalances.text);
				} catch (err:*) {
					_gameParameters.funBalances =  0;
				}
				_leaderIsMe = true;
				_rochambeau.destroy();
				beginGame();
			} else {
				DebugView.addText("   The initial dealer is: "+ _currentLeader.peerID);
				_leaderIsMe = false;
				_rochambeau.destroy();
			}			
			_rochambeau = null;			
		}
		
		/**
		 * Handles keyboard and mobile system key events.
		 * 
		 * @param	eventObj Dispatched by the keyboard handler.
		 */
		private function onKeyPress(eventObj:KeyboardEvent):void		
		{			
			if (eventObj.keyCode == Keyboard.BACK) {				
				if (GlobalSettings.systemSettings.isMobile) {
					//mobile back button
					eventObj.stopPropagation();
					eventObj.stopImmediatePropagation();
					eventObj.preventDefault();
					var na:Class = getDefinitionByName("flash.desktop.NativeApplication") as Class;
					na.nativeApplication.exit(0);
				}
			}			
		}
		
		/**
		 * Event handler invoked when the Ethereum client library has been successfuly loaded and initialized.
		 */
		private function onEthereumReady(eventObj:Event):void
		{	
			DebugView.addText ("Lounge.onEthereumReady - Ethereum client library is ready.");
			_ethereumClient.removeEventListener(Event.CONNECT, onEthereumReady);			
			_ethereum = new Ethereum(_ethereumClient);			
			try {
				DebugView.addText("   Main account: " + _ethereum.web3.eth.accounts[0]); //there must be a better way to determine this...
			} catch (err:*) {
				DebugView.addText("   Connection to Ethereum client failed! Check initialization settings.");	
			}
					
		}
		
		/**
		 * Initializes the Lounge instance when the stage exists.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function initialize(eventObj:Event = null):void 
		{
			DebugView.addText ("Lounge.initialize");			
			removeEventListener(Event.ADDED_TO_STAGE, initialize);			
			if (GlobalSettings.systemSettings.isMobile) {
				stage.addEventListener(KeyboardEvent.KEY_UP, onKeyPress);
			}
			var ethereumAddress:String = "localhost";
			var ethereumPort:uint = 8545;
			if (GlobalSettings.urlParameters != null) {	
				try {
					if ((GlobalSettings.urlParameters.ethaddress != undefined) && (GlobalSettings.urlParameters.ethaddress != null) && 
					(GlobalSettings.urlParameters.ethaddress != "")) {
						ethereumAddress = String(GlobalSettings.urlParameters.ethaddress);
					}
				} catch (err:*) {
					ethereumAddress = "localhost";
				}
				try {
					if ((GlobalSettings.urlParameters.ethport != undefined) && (GlobalSettings.urlParameters.ethport != null) && 
					(GlobalSettings.urlParameters.ethport != "")) {
						ethereumPort = uint(GlobalSettings.urlParameters.ethport);
					}
				} catch (err:*) {
					ethereumPort = 8545;
				}
			}
			_ethereumClient = new EthereumWeb3Client(ethereumAddress, ethereumPort);			
			_ethereumClient.addEventListener(Event.CONNECT, onEthereumReady);
			GlobalDispatcher.addEventListener(GameEngineEvent.CREATED, onGameEngineCreated);
			GlobalDispatcher.addEventListener(GameEngineEvent.READY, onGameEngineReady);
			GlobalSettings.dispatcher.addEventListener(SettingsEvent.LOAD, onLoadSettings);
			GlobalSettings.loadSettings(xmlConfigFilePath, resetConfig);
		}		
	}	
}
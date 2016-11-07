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
	import events.EthereumWeb3ClientEvent;
	import flash.net.URLLoader;
	import flash.system.SecurityDomain;
	import flash.system.WorkerDomain;
	import flash.text.TextField;
	import flash.system.Security;
	import flash.system.Capabilities;
	import flash.utils.setInterval;
	import flash.utils.setTimeout;
	import flash.utils.clearTimeout;
	import flash.utils.clearInterval;
	import flash.display.Loader;
	import flash.net.URLRequest;
	import flash.system.LoaderContext;
	import flash.system.ApplicationDomain;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
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
	import p2p3.interfaces.ICryptoWorkerHost;
	import p2p3.PeerMessage;
	import p2p3.PeerMessageLog;	
	import flash.events.MouseEvent;	
	import org.cg.DebugView;
	import org.cg.EthereumConsoleView;
	import flash.utils.getDefinitionByName;
	import flash.ui.Keyboard;
	import flash.system.Worker;
	import flash.net.LocalConnection;
	import flash.utils.getDefinitionByName;	
	
	import org.cg.SmartContract;
		
	dynamic public class Lounge extends MovieClip implements ILounge 
	{		
		
		public static const version:String = "1.3"; //Lounge version
		private var _isChildInstance:Boolean = false; //true if this is a child instance of an existing one
		public static const resetConfig:Boolean = false; //Load default global settings data at startup?
		public static var xmlConfigFilePath:String = "./xml/settings.xml"; //Default settings file
		private var _illLog:PeerMessageLog = new PeerMessageLog();
		
		private var _leaderSet:Boolean = false; //Has game leader /dealer been established?
		private var _leaderIsMe:Boolean = false; //Am I game leader / dealer?
		private var _currentLeader:INetCliqueMember = null; //Current game leader / dealer
		private var _delayFrames:Number; //Leader start delay counter
		private var _playersReady:uint = 0; //Number of other players joined and ready to play
		
		private var _netClique:INetClique; //default clique communications handler
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
		private var _ethereum:Ethereum = null; //Ethereum library
		
		public function Lounge():void {
			
			DebugView.addText ("Lounge v" + version);
			DebugView.addText ("CPU: " + Capabilities.cpuArchitecture);
			DebugView.addText ("Runtime version: " + Capabilities.version)
			DebugView.addText ("Runtime Info:");
			DebugView.addText ("   isStandalone: " + GlobalSettings.systemSettings.isStandalone);
			DebugView.addText ("   isAIR: " + GlobalSettings.systemSettings.isAIR);
			DebugView.addText ("   isWeb: " + GlobalSettings.systemSettings.isWeb);
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
		 * Launches a new, independent Lounge instance. If the current instance is running in a browser this method will
		 * open a new browser window and load within which to load a new instance. If the current Lounge is running as a desktop
		 * or mobile application, a new native window will be launched with the new Lounge loaded within it.
		 */
		public function launchNewLounge(... args):void {
			DebugView.addText("Lounge.launchNewLounge");
			if (NativeWindow == null) {
				//runtime doesn't support NativeWindow (probably web)
				DebugView.addText ("   Launching in new browser window.");
			} else {
				//runtime supports NativeWindow
				DebugView.addText ("   Launching in new native window. ");
				var loader:Loader = new Loader();								
				var request:URLRequest = new URLRequest("./Lounge.swf");
				var context:LoaderContext = new LoaderContext();
				//use different application domain to partition instances
				context.applicationDomain = new ApplicationDomain();				
				loader.contentLoaderInfo.addEventListener(Event.COMPLETE, this.onLoadNewLounge);
				loader.load(request, context);
			}			
		}
		
		/**
		 * Event handler invoked when a new lounge instance has been successfully loaded into a new window.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		public function onLoadNewLounge(eventObj:Event):void {
			var options:*= new NativeWindowInitOptions();
			options.transparent = NativeApplication.nativeApplication.activeWindow.transparent; 
			options.minimizable = NativeApplication.nativeApplication.activeWindow.minimizable;
			options.maximizable = NativeApplication.nativeApplication.activeWindow.maximizable;
			options.resizable = NativeApplication.nativeApplication.activeWindow.resizable;
			options.systemChrome = NativeApplication.nativeApplication.activeWindow.systemChrome; 
			options.type = NativeApplication.nativeApplication.activeWindow.type; 
			var window:*= new NativeWindow(options);
			window.title = NativeApplication.nativeApplication.activeWindow.title;
			window.width = NativeApplication.nativeApplication.activeWindow.width;
			window.height = NativeApplication.nativeApplication.activeWindow.height;
			window.stage.align = StageAlign.TOP_LEFT;				
			window.stage.scaleMode = StageScaleMode.NO_SCALE;				
			window.activate();
			this.initializeChildLounge(eventObj.target.loader.content);			
			window.stage.addChild(eventObj.target.loader);
		}
		
		/**
		 * @return	True if the current Lounge instance is a child of a parent application instance, false if this is the parent or sole
		 * instance. This value will always be false for non-desktop runtimes.
		 */
		public function get isChildInstance():Boolean {
			return (this._isChildInstance);
		}
		
		/**
		 * Initializes a child Lounge instance such as when launching it in a new native window of an existing application
		 * process.
		 * 
		 * @param	loungeRef A reference to the new Lounge instance. This value is untyped since it may not match an existing
		 * Lounge or ILounge definition in the current application domain.
		 */
		public function initializeChildLounge(loungeRef:*):void {
			DebugView.addText("Lounge.initializeChildLounge");
			if (loungeRef==this) {
				this._isChildInstance = true;				
				CryptoWorkerHost.enableHostSharing(true);
			} else {
				this._isChildInstance = false;				
				CryptoWorkerHost.enableHostSharing(false);
				//initialize the child instance
				loungeRef.initializeChildLounge(loungeRef);
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
		 * Reference to the global settings handler. We return a class definition instead of a reference to an
		 * instance here since GlobalSettings is not instatiated.
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
		 * @return True if the lounge settings XML specifies that the Ethereum client interface library
		 * should be enabled. This setting does not indicate whether or not the client interface library
		 * has actually been instantiated correctly.
		 */
		public function get ethereumEnabled():Boolean {
			try {
				var ethEnabled:Boolean = GlobalSettings.toBoolean(GlobalSettings.getSetting("defaults", "ethereum").enabled);
				return (ethEnabled);
			} catch (err:*) {
				return (false);
			}
			return (false);
		}
		
		/**
		 * Reference to the active Ethereum client interface library. Null is returned if library is unavailable.
		 */
		public function get ethereum():Ethereum
		{
			if (ethereumEnabled && (_ethereum == null)) {				
				DebugView.addText("Ethereum client integration services library has not been instantiated.");
				//returns null
			}
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
				_connectView.launchNewLounge.removeEventListener(MouseEvent.CLICK, this.launchNewLounge);
				_connectView.launchNewLounge.addEventListener(MouseEvent.CLICK, this.launchNewLounge);
			} catch (err:*) {			
			}
		}
		
		/**
		 * Invoked when the Ethereum console view is fully or partially rendered to set default values and
		 * visibilities.
		 */
		public function onRenderEthereumConsole():void {
			DebugView.addText("Lounge.onRenderEthereumConsole");
			EthereumConsoleView.instance(0).attachClient(this._ethereumClient);			
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
			DebugView.addText ("   Initializing as child process? "+this.isChildInstance);
			eventObj.source.initialize(null, resetConfig, this);
		} 	
		
		override public function toString():String {
			return ("[object Lounge]");
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
			DebugView.addText ("   My peer ID: "+eventObj.target.localPeerInfo.peerID);
			_playersReady = 0;
			if (ethereum != null) {
				ethereum.mapPeerID(ethereum.account, clique.localPeerInfo.peerID);
			}
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
			infoObj.ethereumAccount = ethereum.account;			
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
						DebugView.addText ("   Peer Crypto Byte Length: " + peerMsg.data.cryptoByteLength);
						DebugView.addText ("   Peer Ethereum account address: " + peerMsg.data.ethereumAccount);
						ethereum.mapPeerID(String(peerMsg.data.ethereumAccount), String(peerMsg.getSourcePeerIDList()[0].peerID));
						if (_leaderIsMe) {					
							var peerCBL:uint = uint(peerMsg.data.cryptoByteLength);							
							var localCBL:uint = uint(GlobalSettings.getSettingData("defaults", "cryptobytelength"));
							if (peerCBL < localCBL) {
								DebugView.addText ("   Peer " + peerMsg.sourcePeerIDs + " has changed the clique Crypto Byte Length to: " + peerMsg.data.cryptoByteLength);
								GlobalSettings.setSettingData("defaults", "cryptobytelength", String(peerMsg.data.cryptoByteLength));
								GlobalSettings.saveSettings();
							}
						}
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
			//Store Ethereum credentials
			ethereum.account = _connectView.ethereumAccountField.text;
			ethereum.password = _connectView.ethereumAccountPasswordField.text;
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
			//Store Ethereum credentials
			ethereum.account = _connectView.ethereumAccountField.text;
			ethereum.password = _connectView.ethereumAccountPasswordField.text;
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
			DebugView.addText("Concurrency Settings");
			DebugView.addText("--------------------");
			CryptoWorkerHost.useConcurrency = GlobalSettings.toBoolean(GlobalSettings.getSettingData("defaults", "concurrency"));
			CryptoWorkerHost.maxConcurrentWorkers = uint(GlobalSettings.getSettingData("defaults", "maxcryptoworkers"));
			DebugView.addText("   Use concurrency if available: " + CryptoWorkerHost.useConcurrency);
			DebugView.addText("     Maximum concurrent workers: " + CryptoWorkerHost.maxConcurrentWorkers);	
			this.launchEthereum();
			_gameParameters = new GameParameters();
			_connectView = new MovieClip();
			_startView = new MovieClip();
			_gameView = new MovieClip();
			this.addChild(_connectView);
			this.addChild(_startView);
			this.addChild(_gameView);				
			ViewManager.render(GlobalSettings.getSetting("views", "connect"), _connectView, onRenderConnectView);
			ViewManager.render(GlobalSettings.getSetting("views", "debug"), this);
			if (this.ethereumEnabled) {
				ViewManager.render(GlobalSettings.getSetting("views", "ethconsole"), this, onRenderEthereumConsole);				
			}
		}	
		
		/**
		 * Launches a new Ethereum Web3 client instance using XML configuration data from GlobalSettings, or some settings from the launching URL \
		 * when running withing a web browser.
		 */
		private function launchEthereum():void {
			DebugView.addText("Lounge.launchEthereum");
			DebugView.addText("-----------------");
			DebugView.addText ("   Attempt Ethereum interface enable: " + this.ethereumEnabled);			
			if (this.ethereumEnabled) {
				//get default values from XML settings
				try {
					var clientaddress:String = String(GlobalSettings.getSetting("defaults", "ethereum").clientaddress);
				} catch (err:*) {
					clientaddress = "localhost";
				}
				try {
					var clientport:uint =  uint(GlobalSettings.getSetting("defaults", "ethereum").clientport);
				} catch (err:*) {
					clientport = 8545;
				}
				try {
					var datadirectory:String = String(GlobalSettings.getSetting("defaults", "ethereum").datadirectory);
				} catch (err:*) {
					datadirectory = "./data/";
				}
				//Both flags will be true if this is a native-installer instance
				if (GlobalSettings.systemSettings.isStandalone && GlobalSettings.systemSettings.isAIR) {
					try {
						var nativeclientfolder:String =  String(GlobalSettings.getSetting("defaults", "ethereum").nativeclientfolder);
						if (nativeclientfolder.split(" ").join("").length == 0) {
							nativeclientfolder = null;
						}
					} catch (err:*) {
						nativeclientfolder = null;
					}
					//push native client update data into EthereumWeb3Client (for all instances)
					var ethereumSettings:XML = GlobalSettings.getSetting("defaults", "ethereum");
					if (ethereumSettings != null) {
						if (ethereumSettings.clientversions != null) {							
							var clientNodes:XMLList = ethereumSettings.clientversions.child("client") as XMLList;
							if (clientNodes.length() > 0) {
								EthereumWeb3Client.nativeClientUpdates = new Vector.<Object>();
							}
							for (var count:int = 0; count < clientNodes.length(); count++) {
								var currentClientNode:XML = clientNodes[count];
								var newObj:Object = new Object();
								newObj.url = currentClientNode.url.toString();
								newObj.sha256sig = currentClientNode.sha256sig.toString();
								newObj.version = currentClientNode.version.toString();
								EthereumWeb3Client.nativeClientUpdates.push(newObj);
							}							
						}
					}
				} else {
					nativeclientfolder = null;
				}
				if (GlobalSettings.urlParameters != null) {					
					//override defaults using URL parameters, if available
					try {
						if ((GlobalSettings.urlParameters.clientaddress != undefined) && (GlobalSettings.urlParameters.clientaddress != null) && 
						(GlobalSettings.urlParameters.clientaddress != "")) {
							clientaddress = String(GlobalSettings.urlParameters.clientaddress);
						}
					} catch (err:*) {
						clientaddress = "localhost";
					}
					try {
						if ((GlobalSettings.urlParameters.clientport != undefined) && (GlobalSettings.urlParameters.clientport != null) && 
						(GlobalSettings.urlParameters.clientport != "")) {
							clientport = uint(GlobalSettings.urlParameters.clientport);
						}
					} catch (err:*) {
						clientport = 8545;
					}					
					//nativeclientfolder is not supported in web version, leave null
				}
				//if all else fails, assign internal defaults
				if ((clientaddress == "") || (clientaddress == null)) {
					clientaddress = "localhost";
				}
				if (isNaN(clientport) || (clientport <= 0)) {
					clientport = 8545;
				}
				DebugView.addText ("         Ethereum client address: " + clientaddress);
				DebugView.addText ("            Ethereum client port: " + clientport);
				DebugView.addText ("   Ethereum native client folder: " + nativeclientfolder);
				DebugView.addText ("    Active client data directory: " + datadirectory);
				_ethereumClient = new EthereumWeb3Client(clientaddress, clientport, nativeclientfolder, datadirectory);
				_ethereumClient.coopMode = true; //don't attempt to launch native client (use running one)
				_ethereumClient.addEventListener(EthereumWeb3ClientEvent.WEB3READY, onEthereumReady);
				_ethereumClient.networkID = 2;
				_ethereumClient.nativeClientNetwork = EthereumWeb3Client.CLIENTNET_TEST;
				_ethereumClient.nativeClientInitGenesis = false;
				_ethereumClient.initialize();
			}	
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
					NativeApplication.nativeApplication.exit(0);
				}
			}			
		}
		
		/**
		 * Event handler invoked when the Ethereum client library has been successfuly loaded and initialized.
		 */
		private function onEthereumReady(eventObj:Event):void
		{	
			DebugView.addText ("Lounge.onEthereumReady - Ethereum client library is ready.");
			_ethereumClient.removeEventListener(EthereumWeb3ClientEvent.WEB3READY, this.onEthereumReady);			
			_ethereum = new Ethereum(_ethereumClient);
			DebugView.addText("   CypherPoker JavaScript Ethereum Client Library version: " + _ethereumClient.lib.version);			
			try {
				DebugView.addText("   Main account: " + _ethereum.web3.eth.coinbase);
			} catch (err:*) {
				DebugView.addText("   Connection to Ethereum client failed! Check initialization settings.");	
			}		
		}
		
		/**
		 * Returns a dynamically resolved reference to a flash.display.NativeWindow class or null if the current runtime doesn't support it.
		 */
		private function get NativeWindow():Class {
			try {
				var nativeWindowClass:Class = getDefinitionByName("flash.display.NativeWindow") as Class;
				return (nativeWindowClass);
			} catch (err:*) {
			}
			return (null);
		}
		
		/**
		 * Returns a dynamically resolved reference to a flash.display.NativeWindowInitOptions class or null if the current runtime doesn't support it.
		 */
		private function get NativeWindowInitOptions():Class {
			try {
				var nativeWindowIOClass:Class = getDefinitionByName("flash.display.NativeWindowInitOptions") as Class;
				return (nativeWindowIOClass);
			} catch (err:*) {
			}
			return (null);
		}
		
		/**
		 * Returns a dynamically resolved reference to a flash.display.NativeWindowType class or null if the current runtime doesn't support it.
		 */
		private function get NativeWindowType():Class {
			try {
				var nativeWindowTypeClass:Class = getDefinitionByName("flash.display.NativeWindowType") as Class;
				return (nativeWindowTypeClass);
			} catch (err:*) {
			}
			return (null);
		}
		
		/**
		 * Returns a dynamically resolved reference to a flash.display.NativeWindowSystemChrome class or null if the current runtime doesn't support it.
		 */
		private function get NativeWindowSystemChrome():Class {
			try {
				var nativeWindowSCClass:Class = getDefinitionByName("flash.display.NativeWindowSystemChrome") as Class;
				return (nativeWindowSCClass);
			} catch (err:*) {
			}
			return (null);
		}
		
		/**
		 * Returns a dynamically resolved reference to a flash.desktop.NativeApplication class or null if the current runtime doesn't support it.
		 */
		private function get NativeApplication():Class {
			try {
				var nativeApplicationClass:Class = getDefinitionByName("flash.desktop.NativeApplication") as Class;
				return (nativeApplicationClass);
			} catch (err:*) {
			}
			return (null);
		}
		
		/**
		 * Initializes the Lounge instance when the stage exists.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function initialize(eventObj:Event = null):void 
		{
			DebugView.addText ("Lounge.initialize");	
			DebugView.addText("Player type: " + Capabilities.playerType);
			removeEventListener(Event.ADDED_TO_STAGE, initialize);		
			this.stage.align = StageAlign.TOP_LEFT;
			this.stage.scaleMode =StageScaleMode.NO_SCALE;
			if (GlobalSettings.systemSettings.isMobile) {
				stage.addEventListener(KeyboardEvent.KEY_UP, onKeyPress);
			}
			GlobalDispatcher.addEventListener(GameEngineEvent.CREATED, onGameEngineCreated);
			GlobalDispatcher.addEventListener(GameEngineEvent.READY, onGameEngineReady);
			GlobalSettings.dispatcher.addEventListener(SettingsEvent.LOAD, onLoadSettings);
			GlobalSettings.loadSettings(xmlConfigFilePath, resetConfig);
		}		
	}	
}
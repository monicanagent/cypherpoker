/**
* Main Lounge class. This class is usually extended by specific runtime implementations.
* 
* This implementation uses a simple delay timer to establish the leader/dealer role.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
		
	import feathers.FEATHERS_VERSION;
	import org.cg.StarlingViewManager;
	import feathers.controls.Alert;
	import feathers.data.ListCollection;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import org.cg.events.PlayerProfileEvent;
	import org.cg.interfaces.IRoom;
	import org.cg.interfaces.IWidget;
	import starling.core.Starling;
	import feathers.core.ToolTipManager;
	import org.cg.StarlingContainer;
	import flash.events.Event;
	import org.cg.events.LoungeEvent;
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
	import org.cg.TableManager;
	import org.cg.events.TableManagerEvent;
	import p2p3.PeerMessageHandler;
	import p2p3.events.PeerMessageHandlerEvent;
	import p2p3.Rochambeau;
	import p2p3.events.RochambeauEvent;
	import org.cg.PlayerProfile;
	import p2p3.workers.CryptoWorkerHost;
	import p2p3.interfaces.ICryptoWorkerHost;
	import p2p3.PeerMessage;
	import p2p3.PeerMessageLog;	
	import flash.events.MouseEvent;	
	import org.cg.DebugView;
	import org.cg.EthereumConsoleView;
	import flash.utils.getDefinitionByName;
	import flash.events.IOErrorEvent;
	import flash.ui.Keyboard;
	import flash.system.Worker;
	import flash.net.LocalConnection;
	import flash.utils.getDefinitionByName;	
	//Lounge widgets (must be defined below in order to be available!)
	import org.cg.widgets.*;
	PanelWidget;
	EthereumAccountWidget;
	EthereumStatusWidget;
	ConnectivitySelectorWidget;
	SmartContractManagerWidget;
	TableManagerWidget;
	EthereumMiningControlWidget;
	NewWindowWidget;
	ConnectedPeersWidget;
	PlayerProfileWidget;
		
	dynamic public class Lounge extends MovieClip implements ILounge {		
		
		public static const version:String = "2.0"; //Lounge version
		public static const resetConfig:Boolean = true; //Load default global settings data at startup?
		public static var xmlConfigFilePath:String = "./xml/settings.xml"; //Default settings file
		private var _starling:Starling; //main instance used to render Starling/Feathers elements
		private var _displayContainer:StarlingContainer; //main display container for Starling/Feathers content, set when _starling has initialized
		private var _isChildInstance:Boolean = false; //true if this is a child instance of an existing one
		private var _rochambeauEnabled:Boolean = false; //use Rochambeau to determine initial dealer otherwise assume that dealer is already set	
		private var _delayFrames:Number; //Leader start delay counter
		private var _playersReady:uint = 0; //Number of other players joined and ready to play		
		private var _netClique:INetClique; //default clique communications handler
		private var _maxCryptoByteLength:uint = 0; //maximum allowable CBL
		private var _playerProfiles:Vector.<PlayerProfile> = new Vector.<PlayerProfile>();
		private var _rochambeau:Rochambeau = null;
		private var _gameContainers:Vector.<Loader> = new Vector.<Loader>(); //Loader instances containing loaded/loading games
		private var _games:Vector.<Object> = new Vector.<Object>(); //direct references to root display objects / main classes of loaded games
		private var _gameRooms:Vector.<Object> = new Vector.<Object>(); //objects containing associated "loader" (Loader) and "room" (IRoom) instances
		private var _gameParameters:GameParameters; //startup parameters for the game	
		private var _ethereumClient:EthereumWeb3Client; //Ethereum Web3 integration library
		private var _ethereum:Ethereum = null; //Ethereum library
		private var _ethereumEnabled:Boolean = false; //Is Ethereum integration enabled? This value overrides loaded settings if updated after load.
		private var _tableManager:TableManager = null; //manages tables for the lounge, public getter is available (tableManager).
		
		public function Lounge():void {
			DebugView.addText ("---");
			DebugView.addText ("Lounge v" + version);
			DebugView.addText ("Starling v" + Starling.VERSION);
			DebugView.addText ("Feathers v" + FEATHERS_VERSION);
			var CPUType:String = Capabilities.cpuArchitecture;
			var CPUSubType:String = "supports ";
			if (Capabilities.supports32BitProcesses) {
				CPUSubType += "32-bit";	
			} 
			if (Capabilities.supports64BitProcesses) {
				if (CPUSubType != "") {
					CPUSubType += "/";
				}
				CPUSubType += "64-bit";
			}
			CPUSubType+= " processes";
			DebugView.addText ("CPU: " + CPUType+" ("+CPUSubType+")");			
			DebugView.addText ("OS: " + Capabilities.os);
			DebugView.addText ("Touchscreen type: " + Capabilities.touchscreenType);
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
		 * @return	True if the current Lounge instance is a child of a parent application instance, false if this is the parent or sole
		 * instance. This value will always be false for non-desktop runtimes.
		 */
		public function get isChildInstance():Boolean {
			return (this._isChildInstance);
		}		
		
		/**
		 * Reference to the global settings handler. We return a class definition instead of a reference to an
		 * instance here since GlobalSettings is not instatiated.
		 */
		public function get settings():Class {
			return (GlobalSettings);
		}
		
		/**
		 * Reference to the current clique connection.
		 */
		public function get clique():INetClique {			
			return (_netClique);
		}
		
		/**
		 * A reference to the currently active PlayerProfile instance.
		 */
		public function get currentPlayerProfile():PlayerProfile {
			return (this._playerProfiles[0]);
		}
		
		/**
		 * The initial parameters supplied to the currently loaded game.
		 */
		public function get gameParameters():IGameParameters {
			return (_gameParameters);
		}
		
		/**
		 * The current table manager being used by the lounge. May be null if no manager is in use.
		 */
		public function get tableManager():TableManager {
			return (this._tableManager);
		}
		
		/**
		 * References to the root display objects / main classes of all currently active loaded game instances. Index 0 is the most
		 * recently loaded game, index 1 is the previously loaded (and still active) game, etc.
		 */
		public function get games():Vector.<Object> {
			return (this._games);
		}
		
		/**
		 * The maximum Crypto Byte Length.
		 */
		public function get maxCryptoByteLength():uint {
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
			return (this._ethereumEnabled);
		}
		
		public function set ethereumEnabled(enabledSet:Boolean):void {
			this._ethereumEnabled = enabledSet;
		}
		
		/**
		 * Reference to the active Ethereum client interface library. Null is returned if library is unavailable.
		 */
		public function get ethereum():Ethereum	{
			if (ethereumEnabled && (_ethereum == null)) {				
				DebugView.addText("Ethereum client integration services library has not been instantiated.");
				//returns null
			}
			return (_ethereum);
		}
		
		public function set ethereum(ethereumSet:Ethereum):void	{
			this._ethereum = ethereumSet;
		}
		
		/**
		 * @return The main Starling view container for rendering all UI elements.
		 */
		public function get displayContainer():StarlingContainer {
			return (this._displayContainer);
		}
		
		/**
		 * The parent/launching ILounge of this instance. Null if this is the top-evel ILounge instance.
		 */
		public function get parentLounge():ILounge {
			return (this._parentLounge);
		}
		
		/**
		 * Launches a new, independent Lounge instance. If the current instance is running in a browser this method will
		 * open a new browser window and load within which to load a new instance. If the current Lounge is running as a desktop
		 * or mobile application, a new native window will be launched with the new Lounge loaded within it.
		 */
		public function launchNewLounge(... args):void {
			DebugView.addText("Lounge.launchNewLounge");
			if (!CryptoWorkerHost.hostSharingEnabled) {
				CryptoWorkerHost.enableHostSharing(this.isChildInstance);
			}
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
				context.applicationDomain = new ApplicationDomain(null);				
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
			options.renderMode = NativeWindowRenderMode.DIRECT; //required by Starling
			var window:*= new NativeWindow(options);
			window.title = NativeApplication.nativeApplication.activeWindow.title;
			window.width = NativeApplication.nativeApplication.activeWindow.width;
			window.height = NativeApplication.nativeApplication.activeWindow.height;
			window.stage.align = StageAlign.TOP_LEFT;				
			window.stage.scaleMode = StageScaleMode.NO_SCALE;			
			window.activate();
			eventObj.target.loader.content.initializeChildLounge();
			window.stage.addChild(eventObj.target.loader);
		}		
		
		/**
		 * Initializes a child Lounge instance such as when launching it in a new native window of an existing application
		 * process.
		 */
		public function initializeChildLounge():void {
			DebugView.addText("Lounge.initializeChildLounge");
			this._isChildInstance = true;
			CryptoWorkerHost.enableHostSharing(true);			
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
		public function onGameEngineReady(eventObj:GameEngineEvent):void {
			DebugView.addText ("Lounge.onGameEngineReady");
			eventObj.source.start();		
		}

		/**
		 * Invoked when the loaded game engine dispatches a CREATED event.
		 * 
		 * @param	eventObj A GameEngineEvent event object.
		 */
		public function onGameEngineCreated(eventObj:GameEngineEvent):void {
			DebugView.addText ("Lounge.onGameEngineCreated: " + eventObj.source);
			this._games.unshift(eventObj.source); //add newest game to the beginning of the vector array
			var initParams:Array = new Array();
			initParams.push(null); //param 0: game settings file path (use null for game's internal default setting)
			initParams.push(resetConfig); //param 1: reset game configuration from installation folder (same as Lounge resetConfig setting)
			initParams.push(this);
			initParams.push(this.getRoomForGame(eventObj.source));
			eventObj.source.initialize.apply(eventObj.source, initParams);
		}
		
		
		/**
		 * Returns an IRoom implementation instance being used as a clique for a specific DisplayObjectContainer instance.
		 * 
		 * @param	gameInstance The root DisplayObjectContainer object containing the game code.
		 * 
		 * @return An IRoom implementation acting as the main clique for the game instance, or null if one can't be found.
		 */
		private function getRoomForGame(gameInstance:DisplayObjectContainer):IRoom {
			for (var count:int = 0; count < this._gameRooms.length; count++) {
				var currentObj:Object = this._gameRooms[count];
				if (currentObj.loader.contains(gameInstance)) {
					return (currentObj.room);
				}
			}
			return (null);
		}
						
		/**
		 * Destroys the instance by removing any children and event listeners.
		 */
		public function destroy():void {			
			if (stage.nativeWindow != null) {
				stage.nativeWindow.removeEventListener(Event.CLOSING, this.onApplicationExit);				
			}
			if (NativeApplication != null) {
				NativeApplication.nativeApplication.exit(0);
			}
		}
		
		/**
		 * Standard toString override.
		 * 
		 * @return Returns a standard flash string representation of the object instance including version.
		 */
		override public function toString():String {
			return ("[object Lounge "+version+"]");
		}

		/**
		 * Invoked when the main Lounge clique has disconnected.
		 * 
		 * @param	eventObj A NetCliqueEvent event object.
		 */
		private function onCliqueDisconnect(eventObj:NetCliqueEvent):void {
			eventObj.target.removeEventListener(NetCliqueEvent.CLIQUE_DISCONNECT, this.onCliqueDisconnect);
			DebugView.addText ("Lounge.onCliqueDisconnect");
			var event:LoungeEvent = new LoungeEvent(LoungeEvent.DISCONNECT_CLIQUE);
			this.dispatchEvent(event);			
		}
	
		/**
		 * Invoked when the lounge's primary TableManager instance has disconnected.
		 * 
		 * @param	eventObj A TableManagerEvent event object.
		 */
		private function onTableManagerDisconnect(eventObj:TableManagerEvent):void {
			this._tableManager = null;
		}
		
		/**
		 * Invoked when a connection to a clique is established.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onCliqueConnect(eventObj:NetCliqueEvent):void {
			eventObj.target.removeEventListener(NetCliqueEvent.CLIQUE_CONNECT, this.onCliqueConnect);
			DebugView.addText ("Lounge.onCliqueConnect");
			DebugView.addText ("   New peer ID: " + eventObj.target.localPeerInfo.peerID);
			if (this._tableManager == null) {
				this._tableManager = new TableManager(this);
				this._tableManager.profile = this.currentPlayerProfile;
				this._tableManager.addEventListener(TableManagerEvent.DISCONNECT, this.onTableManagerDisconnect);
				var event:LoungeEvent = new LoungeEvent(LoungeEvent.NEW_TABLEMANAGER);
				this.dispatchEvent(event);
			} else {
				this._tableManager.clique = eventObj.target as INetClique;
			}			
			if ((eventObj.target.localPeerInfo.peerID != null) && (eventObj.target.localPeerInfo.peerID != "")) {
				DebugView.addText("      ID appears valid.");
				event = new LoungeEvent(LoungeEvent.NEW_CLIQUE);
				this.dispatchEvent(event);
			} else {
				DebugView.addText("      ID is not valid. Not connected.");
				event = new LoungeEvent(LoungeEvent.DISCONNECT_CLIQUE);
				this.dispatchEvent(event);
			}
		}
		
		
		/**
		 * Invoked when a new peer connects to a connected clique.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onPeerConnect(eventObj:NetCliqueEvent):void {
			DebugView.addText("Lounge.onPeerConnect: " + eventObj.memberInfo.peerID);			
		}
		
		/**
		 * Invoked when a peer disconnects from a connected clique.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onPeerDisconnect(eventObj:NetCliqueEvent):void {
			DebugView.addText("InstantLocalLoung.onPeerDisconnect: " + eventObj.memberInfo.peerID);			
		}
		
		/**		 
		 * Handles all incoming peer messages from the connected clique. Lounge messages are logged and processed.
		 * Non-lounge messages are discarded.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onPeerMessage(eventObj:PeerMessageHandlerEvent):void {			
		}
		
		/**
		 * If current instance is the dealer, signals to connected peers that the game should now begin and renders the main game view.
		 * 		 
		 */
		private function beginGame():void {	
			/*
			if (_leaderIsMe) {
				ViewManager.render(GlobalSettings.getSetting("views", "game"), _gameView);
				var loungeMessage:LoungeMessage = new LoungeMessage();
				loungeMessage.createLoungeMessage(LoungeMessage.GAME_START);
				_messageLog.addMessage(loungeMessage);
				_netClique.broadcast(loungeMessage);				
			}
			*/
		}		
		
		/**
		 * Loads a game into memory.
		 * 
		 * @param	gameName The name of the game to load, as specified in the "name" attribute of the associated <game> node in 
		 * the global settings data.
		 * @param   room an IRoom implementation containing a segregated clique for the loaded game to use.
		 */
		public function loadGame(gameName:String, room:IRoom):void {
			DebugView.addText("Lounge.loadGame: " + gameName);
			var gamesNode:XML = GlobalSettings.getSettingsCategory("games");
			var gameNodes:XMLList = gamesNode.children();
			var swfPath:String = "";
			for (var count:int = 0; count < gameNodes.length(); count++) {
				var currentNode:XML = gameNodes[count];
				if (currentNode.@name == gameName) {
					swfPath = new String(currentNode.children().toString());
				}
			}
			if (swfPath == "") {
				DebugView.addText("   Game can't be found in the global settings data.");
				return;
			}			
			var request:URLRequest = new URLRequest(swfPath);
			var swfLoader:Loader = new Loader();
			var roomObj:Object = new Object();
			roomObj.loader = swfLoader;
			roomObj.room = room;
			this._gameContainers.push(swfLoader);
			this._gameRooms.push(roomObj);
			this.addChild(swfLoader);
			swfLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, this.onLoadSWF);
			swfLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, this.onLoadSWFError);
			try {
				Security.allowDomain("*");
				Security.allowInsecureDomain("*");
			} catch (err:*) {			
			}
			swfLoader.load(request, new LoaderContext(false, ApplicationDomain.currentDomain));				
		}
		
		/**
		 * Attempts to destroy the current (most recently-loaded) game.
		 * 
		 * @return True if the game could be fully destroyed and removed from memory, false otherwise.
		 */
		public function destroyCurrentGame():Boolean {
			DebugView.addText ("Lounge.destroyCurrentGame (child: " + this.isChildInstance+")");
			DebugView.addText("   this._games.length=" + this._games.length);
			if (this._games.length == 0) {
				return (false);
			}
			this._games[0].removeWidgets();
			DebugView.addText ("   All contracts complete? "+this._games[0].allContractsComplete);
			if (this._games[0].allContractsComplete) {
				try {
					var room:IRoom = this._gameRooms.splice((this._gameRooms.length-1), 1)[0].room;
					room.destroy();
					this._games[0].destroy();
				} catch (err:*) {				
				}
				this._games.splice(0, 1);
			}			
			try {
				var loader:Loader = this._gameContainers.splice((this._gameContainers.length - 1), 1)[0];
				this.removeChild(loader);
			} catch (err:*) {				
			}			
			var tableManagerWidget:* = Widget.getInstanceByClass("org.cg.widgets.TableManagerWidget")[0];
			tableManagerWidget.restoreWidget();
			return (true);
		}

		/**
		 * Invoked when an external SWF is loaded.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onLoadSWF(eventObj:Event):void {
			DebugView.addText("Lounge.onLoadSWF");
			eventObj.target.removeEventListener(Event.COMPLETE, this.onLoadSWF);
			eventObj.target.removeEventListener(IOErrorEvent.IO_ERROR, this.onLoadSWFError);
		}		

		/**
		 * Invoked when an external SWF load experiences an error.
		 * 
		 * @param	eventObj an Event object.
		 */
		private function onLoadSWFError(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.COMPLETE, this.onLoadSWF);
			eventObj.target.removeEventListener(IOErrorEvent.IO_ERROR, this.onLoadSWFError);
			DebugView.addText ("Lounge.onLoadSWFError: "+eventObj);
		}
		
		/**
		 * Creates a new clique connection and a resulting INetClique implementation.
		 * 
		 * @param   cliqueID The netclique definition ID to use to create the clique. This value is passed to the NetCliqueManager.getInitializedInstance
		 * mthod.
		 * @param	options The options to include when creating the new connection. These include:
		 * 
		 * "clique" (Object) - Containing properties to pass directly the newly create clique instance.
		 * "connect" (Object) - The connections options object passed to the netclique "connect" method. Specific contents are dependent on the 
		 * implementation of the clique. If omitted this value defaults to GlobalSettings.getSettingData("defaults", "rtmfpgroup")
		 * 
		 * @return	The initialized and connecting INetClique implementation, or null if there was a problem creating one.
		 */
		public function createCliqueConnection(cliqueID:String, options:Object = null):INetClique {
			//if (_peerMessageHandler != null) {
				//_peerMessageHandler.removeEventListener(PeerMessageHandlerEvent.PEER_MSG, onPeerMessage);
				//_peerMessageHandler.removeFromClique(_netClique);
				//_peerMessageHandler = null;
			//}
			if (_netClique != null) {
				_netClique.removeEventListener(NetCliqueEvent.CLIQUE_DISCONNECT, onCliqueDisconnect);
				_netClique.removeEventListener(NetCliqueEvent.CLIQUE_CONNECT, onCliqueConnect);
				_netClique.removeEventListener(NetCliqueEvent.PEER_CONNECT, onPeerConnect);
				_netClique.removeEventListener(NetCliqueEvent.PEER_DISCONNECT, onPeerDisconnect);
				_netClique.disconnect();
				_netClique = null;
			}			
			_netClique = NetCliqueManager.getInitializedInstance(cliqueID);
			DebugView.addText("Got initialized netclique: " + _netClique);
			//_peerMessageHandler = new PeerMessageHandler(_messageLog, _errorLog);
			//_peerMessageHandler.addEventListener(PeerMessageHandlerEvent.PEER_MSG, onPeerMessage);
			//_peerMessageHandler.addToClique(_netClique);
			if (options == null) {
				options = new Object();
			}
			if ((options["clique"] != undefined) && (options["clique"] != null)) {
				for (var item:String in options.clique) {
					_netClique[item] = options.clique[item];
				}
			}
			if ((options["connect"] != undefined) && (options["connect"] != null)) {
				var connectObj:* = options["connect"];
			} else {
				connectObj = GlobalSettings.getSettingData("defaults", "rtmfpgroup");
			}
			_netClique.addEventListener(NetCliqueEvent.CLIQUE_CONNECT, onCliqueConnect);
			_netClique.addEventListener(NetCliqueEvent.CLIQUE_DISCONNECT, onCliqueDisconnect);
			_netClique.addEventListener(NetCliqueEvent.PEER_CONNECT, onPeerConnect);
			_netClique.addEventListener(NetCliqueEvent.PEER_DISCONNECT, onPeerDisconnect);
			_netClique.connect(connectObj);
			return (_netClique);
		}
		
		/**
		 * Destroys and removes the current main clique from memory. This operation does not cause a LoungeEvent.DISCONNECT_CLIQUE event
		 * but does dispatch a LoungeEvent.CLOSE_CLIQUE event. Any current TableManager instances using the connection are destroyed and nulled.
		 */
		public function removeClique():void {
			var event:LoungeEvent = new LoungeEvent(LoungeEvent.CLOSE_CLIQUE);
			this.dispatchEvent(event);
		//	if (_peerMessageHandler != null) {
			//	_peerMessageHandler.removeEventListener(PeerMessageHandlerEvent.PEER_MSG, onPeerMessage);
			//	_peerMessageHandler.removeFromClique(_netClique);
			//	_peerMessageHandler = null;
			//}
			if (_netClique != null) {
				_netClique.removeEventListener(NetCliqueEvent.CLIQUE_DISCONNECT, onCliqueDisconnect);
				_netClique.removeEventListener(NetCliqueEvent.CLIQUE_CONNECT, onCliqueConnect);
				_netClique.removeEventListener(NetCliqueEvent.PEER_CONNECT, onPeerConnect);
				_netClique.removeEventListener(NetCliqueEvent.PEER_DISCONNECT, onPeerDisconnect);
				_netClique.disconnect();
				_netClique.destroy();
				_netClique = null;
			}
			if (this._tableManager != null) {
				this._tableManager.destroy();
				this._tableManager = null;
			}
		}
		
		/**
		 * Invoked when the GlobalSettings data is loaded and parsed.
		 * 
		 * @param	eventObj A SettingsEvent object.
		 */
		private function onLoadSettings(eventObj:SettingsEvent):void {
			DebugView.addText ("Lounge.onLoadSettings");			
			DebugView.addText (GlobalSettings.data);
			DebugView.addText("Concurrency Settings");
			DebugView.addText("--------------------");
			CryptoWorkerHost.useConcurrency = GlobalSettings.toBoolean(GlobalSettings.getSettingData("defaults", "concurrency"));
			CryptoWorkerHost.maxConcurrentWorkers = uint(GlobalSettings.getSettingData("defaults", "maxcryptoworkers"));
			DebugView.addText("   Use concurrency if available: " + CryptoWorkerHost.useConcurrency);
			DebugView.addText("     Maximum concurrent workers: " + CryptoWorkerHost.maxConcurrentWorkers);	
			try {
				this._ethereumEnabled = GlobalSettings.toBoolean(GlobalSettings.getSetting("defaults", "ethereum").enabled);				
			} catch (err:*) {		
				this._ethereumEnabled = false;
			}
			this._ethereum = this.launchEthereum();
			var defaultProfile:PlayerProfile = new PlayerProfile("default");
			defaultProfile.addEventListener (PlayerProfileEvent.UPDATED, this.onPlayerProfileUpdated);
			this._playerProfiles.push(defaultProfile);
			defaultProfile.load(true);
			StarlingContainer.onInitialize = this.onStarlingReady;
			this._starling = new Starling(StarlingContainer, stage);
			this._starling.start();
			ToolTipManager.setEnabledForStage(this._starling.stage, true);
			_gameParameters = new GameParameters();				
		}
		
		private function onPlayerProfileUpdated(eventObj:PlayerProfileEvent):void {
			var event:LoungeEvent = new LoungeEvent(LoungeEvent.UPDATED_PLAYERPROFILE);
			this.dispatchEvent(event);
		}		
		
		public function onStarlingReady(containerRef:StarlingContainer):void {
			DebugView.addText("Lounge.onStarlingReady");
			this._displayContainer = containerRef;
			StarlingViewManager.setTheme("MetalWorksMobileTheme");
			StarlingViewManager.render(GlobalSettings.getSettingsCategory("views").defaultlounge[0], this); //render <defaultlounge> node
			StarlingViewManager.render(GlobalSettings.getSettingsCategory("views").panel[0], this); //render first <panel> node
			StarlingViewManager.render(GlobalSettings.getSettingsCategory("views").panel[1], this); //render second <panel> node
			StarlingViewManager.render(GlobalSettings.getSettingsCategory("views").panel[2], this); //render third <panel> node
			ViewManager.render(GlobalSettings.getSetting("views", "debug"), this);
			var alertMsg:String = "This software is an ALPHA version which means that it's intended for testing only and that bugs should be expected.\n";
			alertMsg += "It is STRONGLY advised not to use this version for any purposes where real losses may occur!";
			var alert:Alert = StarlingViewManager.alert(alertMsg, "WARNING!", new ListCollection([{label:"I Understand"}]), null, true, true);
		}		
		
		/**
		 * Creates a new Ethereum Web3 client instance using XML configuration data from GlobalSettings, or settings from the launching URL
		 * when running withing a web browser. If a launch parameters object is provided it overrides both other sources.
		 * 
		 * @param launchParams Optional launch parameters that override any default or otherwise input values. These may include:
		 * 
		 * "clientaddress" (String) - The running Ethereum client address (e.g. "localhost", "127.0.0.1", "192.168.12.200", etc.)
		 * 
		 * "clientport" (uint) - The port on which the listening Ethereum client is listening.
		 * 
		 * "networkid" (int) - The network ID to connected to. Valid values include:  0=Olympic, 1=Frontier, 2=Morden, 3=Ropsten; other IDs are considered private
		 * 
		 * "datadirectory" (String): The directory in which Ethereum client data (blockchain, etc.) is stored. Accepts (recommended) ActionScript meta-paths such as "app:/".
		 * Set to empty string ("") to disable launching the native client and only launch the integration library.
		 * 
		 * "nativeclientfolder" (String): The directory in which the native client folder is/should be installed. If possible on this runtime the existence of the client will
		 * be verifified and the native client launched. Set to empty string ("") to disable launching the native client and only launch the integration library.
		 * 
		 * "coopmode" (Boolean): If true, cooperative mode is enabled in which the first instance on the client device to connect to a valid
		 * Ethereum client will broadcast its information to all others in order to share a single running client. If false, each
		 * new Ethereum instance may be configured for independent operation with its own client. Default is true.
		 * 
		 * "nativeclientnetwork" (String): The native client netwoerk type to connect to. See EthereumWeb3Client.CLIENTNET_* constants for possible values.
		 * 
		 * "nativeclientinitgenesis" (Boolean): If a native client may be launched on this platform and this value is true a custom genesis block
		 * insertion routine will be attempted when the client is first launched. This option is useful for starting a private Ethereum net. See
		 * the EthereumWeb3Client.nativeClientGenesisBlock property for the default genesis block.
		 * 
		 * "genesisblock" (String): JSON-encoded genesis block to use if "nativeclientinitgenesis" is enabled and a custom genesis block may be inserted 
		 * (see "nativeclientinitgenesis" notes).
		 * 
		 * 
		 * @returns The newly launched or currently active (_ethereum) instance. No settings will be applied if an _ethereum instance already exists.
		 */
		public function launchEthereum(launchParams:Object = null):Ethereum {
			DebugView.addText("Lounge.launchEthereum");
			DebugView.addText("-----------------");
			if (this._ethereum != null) {
				DebugView.addText ("   Returning existing Ethereum instance.");
				return (this._ethereum);
			}			
			DebugView.addText ("   Attempt Ethereum interface enable: " + this.ethereumEnabled);			
			if (this.ethereumEnabled) {
				if (this.ethereum != null) {
					DebugView.addText("      Ethereum interface has already launched. Aborting.");
					return (this.ethereum);
				}
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
					datadirectory = "../data/";
				}
				//Both flags will be true if this is a native-installer instance
				if (GlobalSettings.systemSettings.isStandalone && GlobalSettings.systemSettings.isAIR) {
					DebugView.addText("Standalone version detected.");
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
								var runtimeStr:String = currentClientNode.runtime.toString();
								var runtime:uint = uint(runtimeStr);
								var newObj:Object = new Object();
								if (Capabilities.supports64BitProcesses) {
									if (runtime==64) {
										newObj.url = currentClientNode.url.toString();
										newObj.sha256sig = currentClientNode.sha256sig.toString();
										newObj.version = currentClientNode.version.toString();
										EthereumWeb3Client.nativeClientUpdates.push(newObj);
									}
								} else {
									if (runtime!=64) {
										newObj.url = currentClientNode.url.toString();
										newObj.sha256sig = currentClientNode.sha256sig.toString();
										newObj.version = currentClientNode.version.toString();
										EthereumWeb3Client.nativeClientUpdates.push(newObj);
									}
								}								
							}							
						}
					}
				} else {
					DebugView.addText("Non-standalone version detected.");
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
				//override eveerything else using launch parameters
				if (launchParams == null) {
					launchParams = new Object();
				} else {
					DebugView.addText("   Overriding launch parameters:");
				}
				if (launchParams["clientaddress"] != undefined) {
					DebugView.addText("      clientaddress");
					clientaddress = launchParams["clientaddress"];
				}
				if (launchParams["clientport"] != undefined) {
					DebugView.addText("      clientport");
					clientport = launchParams["clientport"];
				}
				if (launchParams["datadirectory"] != undefined) {
					DebugView.addText("      datadirectory");
					datadirectory = launchParams["datadirectory"];
				}
				if (launchParams["nativeclientfolder"] != undefined) {
					DebugView.addText("      nativeclientfolder");
					nativeclientfolder = launchParams["nativeclientfolder"];
				}
				if (launchParams["datadirectory"] == "") {
					DebugView.addText("      datadirectory");
					datadirectory = null;
				}
				if (launchParams["nativeclientfolder"] == "") {
					DebugView.addText("      nativeclientfolder");
					nativeclientfolder = null;
				}
				if (launchParams["networkid"] != undefined) {
					DebugView.addText("      networkid");
					var networkid:int = launchParams["networkid"];
				} else {
					networkid = 1; //mainnet default
				}
				if (launchParams["coopmode"] != undefined) {
					DebugView.addText("      coopmode");
					var coopmode:Boolean = launchParams["coopmode"];
				} else {
					coopmode = true; //don't attempt to launch native client (use running one)
				}
				if (launchParams["nativeclientnetwork"] != undefined) {
					DebugView.addText("      nativeclientnetwork");
					var nativeclientnetwork:String = launchParams["nativeclientnetwork"];
				} else {
					//nativeclientnetwork = EthereumWeb3Client.CLIENTNET_DEV;
					nativeclientnetwork = null; //null for mainnent
				}
				if (launchParams["nativeclientinitgenesis"] != undefined) {
					DebugView.addText("      nativeclientinitgenesis");
					var nativeclientinitgenesis:Boolean = launchParams["nativeclientinitgenesis"];
				} else {
					nativeclientinitgenesis = false;
				}
				if (launchParams["genesisblock"] != undefined) {
					DebugView.addText("      genesisblock");
					var genesisblock:String =  launchParams["genesisblock"];
				} else {
					genesisblock = null;
				}				
				DebugView.addText ("         Ethereum client address: " + clientaddress);
				DebugView.addText ("            Ethereum client port: " + clientport);
				DebugView.addText ("   Ethereum native client folder: " + nativeclientfolder);
				DebugView.addText ("    Active client data directory: " + datadirectory);
				_ethereumClient = new EthereumWeb3Client(clientaddress, clientport, nativeclientfolder, datadirectory);				
				_ethereumClient.coopMode = coopmode;
				_ethereumClient.networkID = networkid;				
				_ethereumClient.nativeClientNetwork = nativeclientnetwork;				
				_ethereumClient.nativeClientInitGenesis = nativeclientinitgenesis;
				if (genesisblock != null) {
					_ethereumClient.nativeClientGenesisBlock = new XML("<blockdata><![CDATA[" + genesisblock + "]]></blockdata>");
				}
				_ethereumClient.addEventListener(EthereumWeb3ClientEvent.WEB3READY, onEthereumReady);
				_ethereumClient.initialize();
				var returnEthereum:Ethereum = new Ethereum(_ethereumClient);				
				return (returnEthereum);
			} else {
				DebugView.addText ("   Ethereum integration is disabled in settings. Update \"ethereumEnabled\" property to override.");
			}
			return (null);
		}
		
		/**
		 * Invoked when the initial leader has been determined via Rochambeau.
		 * 
		 * @param	eventObj A RochambeauEvent object.
		 */
		private function onLeaderFound(eventObj:RochambeauEvent):void {			
			//_rochambeau.winningPeer is the winner
			_rochambeau.removeEventListener(RochambeauEvent.COMPLETE, this.onLeaderFound);			
			_rochambeau.destroy();
			if (_rochambeau.winningPeer.peerID == clique.localPeerInfo.peerID) {
				DebugView.addText("   I am the initial dealer.");
			} else {
				//normal player
				_rochambeau.destroy();
			}			
			_rochambeau = null;			
		}
		
		/**
		 * Handles keyboard and mobile system key events.
		 * 
		 * @param	eventObj Dispatched by the keyboard handler.
		 */
		private function onKeyPress(eventObj:KeyboardEvent):void {			
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
		private function onEthereumReady(eventObj:Event):void {	
			DebugView.addText ("Lounge.onEthereumReady - Ethereum client library is ready.");
			_ethereumClient.removeEventListener(EthereumWeb3ClientEvent.WEB3READY, this.onEthereumReady);
			DebugView.addText("   CypherPoker JavaScript Ethereum Client Library version: " + _ethereumClient.lib.version);	
			try {
				var event:LoungeEvent = new LoungeEvent(LoungeEvent.NEW_ETHEREUM);
				this.dispatchEvent(event);				
			} catch (err:*) {
				DebugView.addText("   Connection to Ethereum client failed! Check initialization settings.");	
			}			
		}		
		
		private function onApplicationExit(eventObj:Event):void {			
			eventObj.preventDefault();
			eventObj.stopImmediatePropagation();
			eventObj.stopPropagation();
			var activeContracts:uint = 0;
			for (var count:int = 0; count < this._gameContainers.length; count++) {
				var currentGame:* = this._gameContainers[count].content;
				try {
					if ((currentGame["smartContracts"] != null) && (currentGame["smartContracts"] != undefined)) {
						for (var count2:int = 0; count2 < currentGame.smartContracts.length; count2++) {
							var contract:SmartContract = currentGame.smartContracts[count2] as SmartContract;
							if (contract.isComplete == false) {
								activeContracts++;
							}
						}
					}
				} catch (err:*) {					
				}
			}
			if (activeContracts > 0) {
				var alertMsg:String = "There are "+String(activeContracts)+" active smart contract hands remaining to be resolved.\nYou may lose ALL game funds if you quit now!\nAre you sure you want to quit?";
				var alert:Alert = StarlingViewManager.alert(alertMsg, "Really quit?", new ListCollection([{label:"YES", quit:true}, {label:"NO", quit:false}]), null, true, true);
				alert.addEventListener(Event.CLOSE, this.onApplicationExitAlertClose);			
			} else {
				this.destroy();
			}
		}
		
		private function onApplicationExitAlertClose(eventObj:Object):void {
			eventObj.target.removeEventListener(Event.CLOSE, this.onApplicationExitAlertClose);	
			if (eventObj.data.quit) {				
				this.destroy();
			} else {
				//don't quit
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
		 * Returns a dynamically resolved reference to a flash.display.NativeWindowRenderMode class or null if the current runtime doesn't support it.
		 */
		private function get NativeWindowRenderMode():Class {
			try {
				var nativeWindowRMClass:Class = getDefinitionByName("flash.display.NativeWindowRenderMode") as Class;
				return (nativeWindowRMClass);
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
		 * Dynamically returns a referenece to the flash.events.NativeProcessExitEvent class, if available. Null is returned if the
		 * current runtime environment doesn't include NativeProcess.
		 */
		private function get NativeProcessExitEvent():Class
		{
			try {
				var nativeProcessEEClass:Class = getDefinitionByName("flash.events.NativeProcessExitEvent") as Class;
				return (nativeProcessEEClass);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Initializes the Lounge instance when the stage exists.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function initialize(eventObj:Event = null):void {
			DebugView.addText ("Lounge.initialize");				
			removeEventListener(Event.ADDED_TO_STAGE, initialize);		
			this.stage.align = StageAlign.TOP_LEFT;
			this.stage.scaleMode =StageScaleMode.NO_SCALE;
			if (GlobalSettings.systemSettings.isMobile) {
				stage.addEventListener(KeyboardEvent.KEY_UP, onKeyPress);
			}
			if (stage.nativeWindow != null) {
				stage.nativeWindow.addEventListener(Event.CLOSING, this.onApplicationExit);
			}
			GlobalDispatcher.addEventListener(GameEngineEvent.CREATED, onGameEngineCreated);
			GlobalDispatcher.addEventListener(GameEngineEvent.READY, onGameEngineReady);
			GlobalSettings.dispatcher.addEventListener(SettingsEvent.LOAD, onLoadSettings);
			GlobalSettings.loadSettings(xmlConfigFilePath, resetConfig);
		}		
	}	
}
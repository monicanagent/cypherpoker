/**
* Base (core/generic) card game implementation to be extended by a custom card game.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {		
	
	import org.cg.interfaces.IBaseCardGame;
	import events.PokerGameStatusEvent;
	import org.cg.interfaces.ILounge;
	import p2p3.interfaces.INetClique;
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.events.NetCliqueEvent;
	import org.cg.interfaces.ICardDeck;
	import org.cg.GameSettings;
	import org.cg.events.SettingsEvent;	
	import PokerBettingModule;
	import flash.display.Sprite;
	import flash.display.StageAlign;
    import flash.display.StageScaleMode;
	import flash.display.MovieClip;
	import flash.events.Event;			
	import org.cg.GlobalDispatcher;
	import org.cg.events.GameEngineEvent;		
	import org.cg.events.CardEvent;
	import flash.geom.PerspectiveProjection;
	import flash.geom.Point;
	import flash.geom.Matrix3D;	
	import flash.events.MouseEvent;
	import flash.text.TextField;	
	import org.cg.Table;
	import flash.utils.getDefinitionByName;
	import org.cg.DebugView;
			
	dynamic public class BaseCardGame extends MovieClip implements IBaseCardGame {
				
		//Constants used with SMO list operations
		public static const SMO_SHIFTSELFTOEND:int = 1; //Shift self to end of SMO list.
		public static const SMO_SHIFTSELFTOSTART:int = 2; //Shift self to start of SMO list.
		public static const SMO_REMOVESELF:int = 3; //Remove self from SMO list.
		public static const SMO_SHIFTNEXTPLAYERTOEND:int = 4; //Move next player after self to end. List is unchanged if self is not in list.
		protected var _initialized:Boolean = false; //Is game fully initialized?
		protected var _running:Boolean = false; //Is game running?
		protected var _UIEnabled:Boolean = false; //Is game UI enabled?
		protected var _gamePhase:Number = new Number(); //Current game phase.
		protected var _ethereum:Ethereum = null; //local reference to an active Ethereum instance (set to null to disable Ethereum use for the game)
		private var _settingsFilePath:String = "../BaseCardGame/xml/settings.xml";		
		private var _loungeInit:Boolean = true; //Should game wait for lounge to initialize it?
		private var _cardDecks:Vector.<CardDeck> = new Vector.<CardDeck>(); //Available CardDeck instances.
		private var _lounge:ILounge; //Current Lounge reference.		
		private var _SMOMemberList:Vector.<INetCliqueMember> = null; //Sequential Member Operation list (for multi-party operations).		
		private var _table:Table = null; //Table instance with segregated clique and player quorum received from Lounge		
					
		/**
		 * Creates a new instance.
		 */
		public function BaseCardGame():void {				
			if (stage != null) {
				setDefaults();
			} else {
				addEventListener(Event.ADDED_TO_STAGE, setDefaults);
			}
			super();
		}
		
		/**
		 * The path (URI or local file path) to the card game settings XML data.
		 */
		public function set settingsFilePath(filePathSet:String):void {
			_settingsFilePath = filePathSet;
		}
		
		public function get settingsFilePath():String {
			return (_settingsFilePath);
		}
		
		/**
		 * @return A reference to the GameSettings class.
		 */
		public function get settings():Class {
			return (GameSettings);
		}
		
		/**
		 * A reference to the current ILounge implementation.
		 */
		public function get lounge():ILounge {
			return (_lounge);
		}
		
		/**
		 * Reference to the Table instance containing a segregated clique and connected players as provided
		 * by a parent Lounge instance.
		 */
		public function get table():Table {
			return (this._table);
		}
		
		/**
		 * The clique being used for the game.
		 */
		public function get clique():INetClique {			
			return (this._table.clique);			
		}
		
		/**
		 * Local reference to an active Ethereum instance. May point to one created by the Lounge or may be null if
		 * Ethereum integration is disabled for the game.
		 */
		public function get ethereum():Ethereum {
			return (this._ethereum);
		}
		
		/**
		 * The current game phase, often used in conjuction with the "gamephases" settings data
		 * to determine the current game settings.
		 */
		public function get gamePhase():Number {
			return (_gamePhase);
		}
		
		public function set gamePhase(phaseSet:Number):void {
			_gamePhase = phaseSet;
		}
				
		/**
		 * @return An instance of the current ICardDeck implementationbeiung used, 
		 * or null if none exists.
		 */
		public function get currentDeck():ICardDeck {
			return (_cardDecks[0]);
		}
		
		/**
		 * @return The list of Sequential Member Operations member targets currently stored internally in this class.
		 */
		public function get SMOList():Vector.<INetCliqueMember> {
			var currentMembers:Vector.<INetCliqueMember> = this.table.connectedPeers;
			if (_SMOMemberList == null) {
				_SMOMemberList = new Vector.<INetCliqueMember>();
				_SMOMemberList.push(this.clique.localPeerInfo);
				copyToSMO(currentMembers);				
			}
			return (_SMOMemberList);
		}
		
		/**
		 * @return True if the base card game instance is fully initialized, including loading
		 * of settings XML data, etc.
		 */
		public function get initialized():Boolean {
			return (_initialized);
		}
		
		/**
		 * Initializes the base card game instance with defualt values and begins loading the settings XML data.
		 * 
		 * @param	... args Optional startup arguments. args[0] is a path (String) to the game's configuration XML data. 
		 * args[1] is a Boolean value that forces a load from the original installation location rather than from local stored data,
		 * args[2] is a reference to a segregated INetClique implementation for the game to use. If omitted the game defaults to the
		 * Lounge's clique reference.
		 */
		public function initialize(... args):void {
			DebugView.addText ("BaseCardGame.initialize (" + args + ")");
			try {
				var settingsXMLPath:String = args[0];
			} catch (err:*) {
				settingsXMLPath = null;
			}
			if (args == null) {
				settingsXMLPath = settingsFilePath;
			}
			if (args.length == 0) {
				settingsXMLPath = settingsFilePath;
			}
			if ((settingsXMLPath == null) || (settingsXMLPath == "")) {
				settingsXMLPath = settingsFilePath;
			}
			var resetToDefault:Boolean = true; //re-load installation config (wipe any custom settings data)
			try {
				resetToDefault = Boolean(args[1]);
			} catch (err:*) {
				resetToDefault = true;
			}
			try {
				_lounge = ILounge(args[2]);
			} catch (err:*) {				
				resetToDefault = false;
			}
			try {
				this._table = args[3] as Table;
			} catch (err:*) {				
			}
			loadSettings(settingsXMLPath, resetToDefault);
		}
		
		/**
		 * Dispatches a PokerGameStatusEvent event to notify application components of the status of the game engine.
		 * 
		 * @param	type The type of status event to dispatch. Typically this will be one of the PokerGameStatusEvent constants but may also be
		 * a custom event type. An additional, generic "STATUS" event is dispatched along with every specific event for any generic listeners.
		 * @param	source The source object dispatching the event. Listeners should use this reference instead of the standard "target" property
		 * since the target will always be this class instance.
		 * @param	infoObj An optional information object to include with the dispatched event.
		 */
		public function dispatchStatusEvent(type:String, source:*, infoObj:Object = null):void {
			//dispatch specific event
			var event:PokerGameStatusEvent = new PokerGameStatusEvent(type);
			event.source = source;
			event.info = infoObj;
			this.dispatchEvent(event);
			if (type !=  PokerGameStatusEvent.ERROR) {
				//dispatch generic event
				var genericEvent:PokerGameStatusEvent = new PokerGameStatusEvent(PokerGameStatusEvent.STATUS);
				genericEvent.eventType = type;
				genericEvent.source = source;
				genericEvent.info = infoObj;
				this.dispatchEvent(genericEvent);
			} else {
				if (infoObj["fatal"] == true) {
					this.onFatalGameError(source, infoObj);
				}
			}
		}
		
		/**
		 * Handles fatal errors dispatched by the game instance. This method is invoked directly from "dispatchStatusEvent" when the event type
		 * is PokerGameStatusEvent.ERROR and the included info object's "fatal" flag is set to true.
		 * 
		 * @param	errorSource The object instance in which the error originated.
		 * @param	infoObj The "info" object included with the error. This object will contain a "fatal" boolean value that's true and typically also
		 * includes a human-readable "description".
		 * 
		 */
		protected function onFatalGameError(errorSource:*, infoObj:Object):void {
			if (infoObj.description != null) {
				var err:Error = Error (infoObj.description);
			} else {
				err = new Error ("Fatal error in " + errorSource);
			}
			DebugView.addText(err.message);
			DebugView.addText(err.getStackTrace());
			throw(err);
		}
		
		/**
		 * Attempts to starts the card game. This function is typically overriden by custom
		 * implementations.
		 * 
		 * @param	restart If true the game is starting a new round, if false a new game
		 * (usually a new BaseCardGame instance) is starting.
		 * 
		 * @return True if the instance could be correctly started.
		 */
		public function start(restart:Boolean = false):Boolean {
			if (initialized) {
				_running = true;
				return (true);
			}
			return (false);
		}		
		
		/**
		 * Attempts to reset the card game by clearing unused memory, event handlers, etc. 
		 * This function is typically overriden by custom implementations.
		 * 		 
		 * @return True if the instance was successfully reset.
		 */
		public function reset():Boolean {
			return (true);
		}
		
		/**
		 * Attempts to disable the game's user interface. This function is typically overriden by 
		 * custom implementations.
		 * 
		 * @return True if the UI was successfullly disabled.
		 */
		public function disableUI():Boolean {
			_UIEnabled = false;
			return (true);
		}	
		
		/**
		 * Attempts to enable the game's user interface. This function is typically overriden by 
		 * custom implementations.
		 * 
		 * @return True if the UI was successfullly enabled.
		 */
		public function enableUI():Boolean {
			_UIEnabled = true;
			return (true);
		}		
		
		/**		 
		 * @return A list of current netclique members, including the local netclique member (self),
		 * for use in Sequential Member Operations (operations involving all members in a specific sequence, such
		 * as commutative encryption and decryption). This list is shifted every time this method is invoked so 
		 * that the first member becomes the last, the second becomes the first, the third becomes the second,
		 * and so on.  
		 */
		public function getSMOShiftList():Vector.<INetCliqueMember> {
			var currentMembers:Vector.<INetCliqueMember> = this.table.connectedPeers;
			if (_SMOMemberList == null) {
				_SMOMemberList = new Vector.<INetCliqueMember>();				
				copyToSMO(currentMembers);				
				_SMOMemberList.push(this.clique.localPeerInfo); //add self
			} else {				
				var member:INetCliqueMember = _SMOMemberList.shift();
				_SMOMemberList.push(member)
			}
			return (_SMOMemberList);
		}		
		
		/**
		 * Adjusts the Sequential Member Operation list.
		 * 
		 * @param	SMOList The SMO list to adjust.
		 * @param	adjustType The adjust operation to apply. Use one of the declared "SMO_" constants.
		 * 
		 * @return The adjusted SMO list, or null if an error occurred during the operation.
		 */
		public function adjustSMOList(SMOList:Vector.<INetCliqueMember>, adjustType:int = SMO_SHIFTSELFTOEND):Vector.<INetCliqueMember> {
			if (SMOList == null) {
				return (null);
			}		
			var returnList:Vector.<INetCliqueMember> = new Vector.<INetCliqueMember>();
			var selfID:String = this.clique.localPeerInfo.peerID;
			var selfPosition:int = -1;
			var nextPlayerPosition:int = -1;			
			for (var count:int = 0; count < SMOList.length; count++) {
				var currentMember:INetCliqueMember = SMOList[count];
				returnList.push(currentMember);
				if (currentMember.peerID == selfID) {
					selfPosition = count;
					nextPlayerPosition = (count + 1) % SMOList.length;					
				}
			}						
			switch (adjustType) {
				case SMO_SHIFTSELFTOEND:					
					if (selfPosition>-1) {
						var selfMember:Vector.<INetCliqueMember> = returnList.splice(selfPosition, 1);
						returnList.push(selfMember[0]);
					}
					break;
				case SMO_SHIFTSELFTOSTART:
					if (selfPosition>-1) {
						selfMember = returnList.splice(selfPosition, 1);
						returnList.unshift(selfMember[0]);
					}
					break;
				case SMO_REMOVESELF:
					if (selfPosition>-1) {
						selfMember = returnList.splice(selfPosition, 1);
					}
					break;
				case SMO_SHIFTNEXTPLAYERTOEND:
					if (nextPlayerPosition>-1) {
						var nextMember:Vector.<INetCliqueMember> = returnList.splice(nextPlayerPosition, 1);						
						returnList.push(nextMember[0]);
					}
					break;
				default: break;
			}
			return (returnList);
		}
		
		/**		 
		 * @return [NOT FULLY IMPLEMENTED] A list of current netclique members, including the local netclique member (self),
		 * for use in Sequential Member Operations (operations involving all members in a specific sequence, such
		 * as commutative encryption and decryption). This list is randomized so no specific order should be assumed.
		 * 
		 */
		public function getSMORandomList():Vector.<INetCliqueMember> {
			var currentMembers:Vector.<INetCliqueMember> = this.table.connectedPeers;
			if (_SMOMemberList == null) {
				_SMOMemberList = new Vector.<INetCliqueMember>();
				_SMOMemberList.push(this.clique.localPeerInfo);
				copyToSMO(currentMembers);				
			}
			//TODO: implement random selection
			return (_SMOMemberList);
		}	
		
		/**
		 * Destroys the card game instance by clearing unused memory, removing event listeners,
		 * etc. This function is usually called just before removing the instance from
		 * memory.
		 */
		public function destroy():void {
			GameSettings.releaseMemory();
		}
		
		/**
		 * Handler invoked when the default view is rendered. Usually overriden by custom
		 * game implementations.
		 */
		public function onRenderDefaultView():void {				
		}
				
		/**
		 * Instructs the GameSettings class to begin loading the settings XML data.
		 * 
		 * @param	xmlFilePath The URI of local file path of the settings XML data.
		 * @param	reset True if the data should be loaded from its default (installation) source,
		 * or from a dynamically saved source (settings data may differ from default).
		 */
		private function loadSettings(xmlFilePath:String, reset:Boolean = false):void {			
			DebugView.addText ("BaseCardGame.loadSettings: " + xmlFilePath);			
			GameSettings.dispatcher.addEventListener(SettingsEvent.LOAD, onLoadSettings);
			GameSettings.dispatcher.addEventListener(SettingsEvent.LOADERROR, onLoadSettingsError);
			GameSettings.loadSettings(xmlFilePath, reset, _lounge.version);
		}
		
		/**
		 * Adds core event listeners for instance.
		 */
		private function addEventListeners():void {
			this.clique.addEventListener(NetCliqueEvent.PEER_DISCONNECT, onPeerDisconnect);
		}
		
		/**
		 * Removes core event listeners for instance.
		 */
		private function removeEventListeners():void {
			this.clique.removeEventListener(NetCliqueEvent.PEER_DISCONNECT, onPeerDisconnect);
		}
		
		/**
		 * Handler for the completion of the settings XML data loading by the GameSettings class.
		 * This function renders the default view and creates the default card deck.
		 * 
		 * @param	eventObj A SettingsEvent object.
		 */
		protected function onLoadSettings(eventObj:SettingsEvent):void {
			DebugView.addText ("BaseCardGame.onLoadSettings");
			DebugView.addText (GameSettings.data);
			GameSettings.dispatcher.removeEventListener(SettingsEvent.LOAD, onLoadSettings);
			GameSettings.dispatcher.removeEventListener(SettingsEvent.LOADERROR, onLoadSettingsError);
			_cardDecks.push(new CardDeck("default", "default", onLoadDeck));
			addEventListeners();
		}		
					
		/**
		 * Calback function invoked by a CardDeck instance when it has completed
		 * initializing, loading assets, etc.
		 * 
		 * @param	deckRef A reference to the CardDeck instance reporting its status.
		 */
		protected function onLoadDeck(deckRef:CardDeck):void {
			//how best to handle more than one deck?
			_initialized = true;			
			GlobalDispatcher.dispatchEvent(new GameEngineEvent(GameEngineEvent.READY), this);
			if (!_loungeInit) {
				start();
			}
		}		
				
		/**
		 * Handler for errors experienced by the GameSettings class during a data load.
		 * 
		 * @param	eventObj A SettingsEvent object.
		 */
		private function onLoadSettingsError(eventObj:SettingsEvent):void {
			DebugView.addText ("BaseCardGame.onLoadSettingsError: " + eventObj);
			GameSettings.dispatcher.removeEventListener(SettingsEvent.LOAD, onLoadSettings);
			GameSettings.dispatcher.removeEventListener(SettingsEvent.LOADERROR, onLoadSettingsError);
		}
		
		/**
		 * Handles peer disconnection events for the clique.
		 * 
		 * @param	eventObj Event dispatched from a NetClique.
		 */
		private function onPeerDisconnect(eventObj:NetCliqueEvent):void	{
			var updatedList:Vector.<INetCliqueMember> = new Vector.<INetCliqueMember>();
			if (_SMOMemberList == null) {
				//peer disconnected before list could be established
				return;
			}
			for (var count:int = 0; count < _SMOMemberList.length; count++) {
				var currentMember:INetCliqueMember = _SMOMemberList[count];
				if (currentMember.peerID != eventObj.memberInfo.peerID) {
					updatedList.push(currentMember);					
				}
			}
			_SMOMemberList = updatedList;
		}
		
		/**
		 * Sets the perspective projection of the game instance for 3D transformations.
		 */
		private function setPerpectiveProjection():void {
			try {
				transform.perspectiveProjection.projectionCenter = new Point((stage.stageWidth / 2), (stage.stageHeight / 2));	
				transform.perspectiveProjection.fieldOfView = 20;
			} catch (err:*) {
			}
		}		
		
		/**
		 * Copies a list if INetCLiqueMember implementations into the SMO list by pushing each
		 * member to the end of the list.
		 * 
		 * @param	sourceMemberList A list of the members to push into the SMO list.
		 */
		private function copyToSMO(sourceMemberList:Vector.<INetCliqueMember>):void {			
			if (sourceMemberList == null) {
				return;
			}
			for (var count:uint = 0; count < sourceMemberList.length; count++) {
				_SMOMemberList.push(sourceMemberList[count]);
			}
		}
		
		/**
		 * Checks if a specific member is part of a member list.
		 * 
		 * @param	member The member to check for.
		 * @param	memberList The list of members within which to search.
		 * 
		 * @return True if the member appears in the supplied list.
		 */
		private function memberInList(member:INetCliqueMember, memberList:Vector.<INetCliqueMember>):Boolean {
			for (var count:int = 0; count < memberList.length; count++) {
				var currentMember:INetCliqueMember = memberList[count];	
				if (currentMember == member) {
					return (true);
				}
			}
			return (false);
		}		
		
		/**
		 * Sets default values, begins initialization of the instance, and dispatches
		 * a CREATED event.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		protected function setDefaults(eventObj:Event = null):void {
			removeEventListener(Event.ADDED_TO_STAGE, setDefaults);
			this.stage.align = StageAlign.TOP_LEFT;
			this.stage.scaleMode = StageScaleMode.NO_SCALE;
			setPerpectiveProjection();
			if (!_loungeInit) {
				initialize(settingsFilePath, true);
			}
			GlobalDispatcher.dispatchEvent(new GameEngineEvent(GameEngineEvent.CREATED), this);			
		}
	}
}
/**
* Manages player betting, game progression, and game status for an initialized PokerCardGame instance. The betting
* module's logic is modelled after a typical Texas Hold'em poker game.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package  {
	
	import crypto.interfaces.ISRAKey;	
	import interfaces.IPokerBettingModule;	
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.interfaces.IPeerMessage;
	import org.cg.interfaces.ICard;
	import interfaces.IPokerPlayerInfo;
	import interfaces.IPokerHandAnalyzer;
	import interfaces.IPokerHand;
	import flash.events.Event;
	import p2p3.events.NetCliqueEvent;
	import org.cg.events.GameTimerEvent;
	import org.cg.events.ImageButtonEvent;
	import events.PokerBettingEvent;
	import org.cg.SmartContractDeferState;
	import EthereumTransactions;
	import EthereumMessagePrefix;
	import crypto.interfaces.ISRAMultiKey;
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.display.Bitmap;
	import flash.display.Loader;
	import flash.filters.GlowFilter;	
	import org.cg.GameTimer;
	import PokerBettingSettings;
	import PokerCardGame;	
	import events.PokerGameStatusEvent;
	import org.cg.ViewManager;
	import org.cg.CurrencyFormat;	
	import org.cg.DebugView;
	import org.cg.ImageButton;
	import p2p3.PeerMessageHandler;
	import p2p3.events.PeerMessageHandlerEvent;
	import flash.utils.setTimeout;
	
	dynamic public class PokerBettingModule extends MovieClip implements IPokerBettingModule {
		
		private var _game:PokerCardGame = null; //Reference to the parent PokerCardGame instance.
		private var _peerMessageHandler:PeerMessageHandler;
		/**
		 * Betting settings as defined in global config and merged with table data.
		 */
		private var _bettingSettings:PokerBettingSettings = null;		
		/**
		 * The current local player bet for the current beting action. This is different than the local player's totalBet 
		 * value in the _players vector which is the total bet for the game.
		 */
		private var _currentPlayerBet:Number = new Number(0);
		/**
		 * The player that currently has betting control. Null if no player has control.
		 */
		private var _currentBettingPlayer:IPokerPlayerInfo = null;
		/**
		 * The required betting value at the start of the player's betting turn, usually calculated as (largestTableBet-_currentPlayerBet),
		 * or either the small or big blind value when appropriate.
		 */
		private var _startingPlayerBet:Number = new Number(0);		
		private var _roundComplete:Boolean = false; //toggles betting module into read-only mode at end of each round
		private var _bettingOrderLocked:Boolean = false; //set to true once betting order has been established or received
		private var _balance:Number = new Number(0); //the local player balance
		private var _communityPot:Number = new Number(0); //the community pot for the current round
		private var _smallBlind:Number = new Number(0); //the small blind value for the current round
		private var _bigBlind:Number = new Number(0); //the big blind value for the current round
		private var _currencyFormat:CurrencyFormat = new CurrencyFormat(); //formats base numeric values to a selected currency
		private var _lastHighestHand:IPokerHand = null; //the last highest hand for the player, usually created at the end of a round
		private var _initialPlayerBalances:Array = null; //initial player balances sent from dealer (array of objects)
		private var _bettingResumeMsg:IPeerMessage = null; //last received betting message stored until new community cards are dealt
		private var _smartContractBettingPhase:uint = 0; //betting phase (index) to use with smart contract deferred invocations		
		private var _updateSCBPAfterNextBet:Boolean = false; //if true, _smartContractBettingPhase will be incremented after next bet		
		/**
		 * An ordered list of players in their betting order, as established by the dealer.
		 */
		private var _players:Vector.<IPokerPlayerInfo> = new Vector.<IPokerPlayerInfo>();
		private var _transactions:EthereumTransactions; //manages received Ethereum transactions to be used in case of challenges		
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	gameRef A reference to an initialized PokerCardGame instance.
		 */
		public function PokerBettingModule(gameRef:PokerCardGame) {
			_game = gameRef;
			this._transactions = new EthereumTransactions();
			this._peerMessageHandler = new PeerMessageHandler(); //not logging incoming messages through handler			
			_game.addChild(this);
		}		
		
		/**
		 * The current PokerBettingSettings reference being used.
		 */
		public function get currentSettings():PokerBettingSettings {			
			return (_bettingSettings);
		}
		
		/**
		 * @return A list, in initial dealer betting order, of all players who have not folded in this round. Note that this list
		 * may not represent the current betting order as new big/small blinds are declared in each new round.
		 */
		public function get nonFoldedPlayers():Vector.<IPokerPlayerInfo> {
			var returnPlayers:Vector.<IPokerPlayerInfo> = new Vector.<IPokerPlayerInfo>();
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				if (currentPlayer.hasFolded == false) {
					returnPlayers.push(currentPlayer);
				}
			}
			return (returnPlayers);
		}
		
		/**
		 * @return A list, in current betting order, of all players who have not folded in this round. Note that this
		 * list will change between rounds as new big/small blinds are declared. Small blind is always at index 0, big blind at index 1, etc.
		 * Null is returned if no players exist in the nonFoldedPlayers array.
		 */
		public function get nonFoldedPlayersBO():Vector.<IPokerPlayerInfo> {
			DebugView.addText("Returning nonFoldedPlayersBO");
			if (this.nonFoldedPlayers == null) {
				return (null);
			}
			var returnPlayers:Vector.<IPokerPlayerInfo> = new Vector.<IPokerPlayerInfo>();
			var startingIndex:int =-1;
			var nfPlayers:Vector.<IPokerPlayerInfo> = this.nonFoldedPlayers;
			DebugView.addText ("nfPlayers.length=" + nfPlayers.length);
			for (var count:int = 0; count < nfPlayers.length; count++) {
				var currentPlayerInfo:IPokerPlayerInfo = nfPlayers[count];
				if (currentPlayerInfo.isSmallBlind) {
					startingIndex = count;
					var evaluateLength:int = nfPlayers.length + startingIndex;
					for (var count2:int = startingIndex; count2 < evaluateLength; count2++) {
						var currentIndex:int = count2 % nfPlayers.length;
						var currentPlayer:IPokerPlayerInfo = nfPlayers[currentIndex];
						DebugView.addText("Adding: " + currentPlayer.netCliqueInfo.peerID);
						returnPlayers.push (currentPlayer);
					}
					return (returnPlayers);
				}
			}
			return (null);
		}

		/**
		 * @return A list, in dealer betting order, of all players (including folded ones).
		 */
		public function get allPlayers():Vector.<IPokerPlayerInfo> {			
			return (_players);
		}		
		
		/**
		 * Returns a PokerPlayerInfo object for the local player (self).
		 */
		public function get selfPlayerInfo():IPokerPlayerInfo {		
			if (_players == null) {								
				return (null);
			}
			var selfPeerID:String = game.clique.localPeerInfo.peerID;			
			for (var count:int = 0; count < _players.length; count++) {				
				var currentPlayerInfo:IPokerPlayerInfo = _players[count];
				var currentPlayerPeerID:String = currentPlayerInfo.netCliqueInfo.peerID;				
				if (currentPlayerInfo != null) {
					//comparing objects is unreliable so use peer ID instead
					if (currentPlayerPeerID == selfPeerID) {
						return (currentPlayerInfo);
					}
				}
			}			
			return (null);
		}
		
		/**
		 * Converts an ordered list of IPokerPlayer implementations to Ethereum account addresses registered with the main Ethereum instance.
		 * Any info objects/peer IDs that haven't been mapped in the Ethereum instance will be omitted in the output.
		 * 
		 * @param	playerList An ordered list of iPokerPlayerInfo instances to convert to Ethereum account addresses.
		 * 
		 * @return An ordered list of Ethereum account addresses generated in the same order as playerList. Any peer IDs that have no
		 * associated Ethereum account addresses will not be included.
		 */
		public function toEthereumAccounts(playerList:Vector.<IPokerPlayerInfo>):Array {
			var outputArray:Array = new Array();
			for (var count:int = 0; count < playerList.length; count++) {
				var currentPlayerInfo:IPokerPlayerInfo = playerList[count];
				if (game.ethereum != null) {
					var account:String = game.ethereum.getAccountByPeerID(currentPlayerInfo.netCliqueInfo.peerID);
					if ((account != "") && (account != null)) {
						outputArray.push(account);
					}
				} else {
					//ethereum instance not available
				}
			}
			return (outputArray);
		}
		
		/**
		 * @return A reference to the parent PokerCardGame instance.
		 */
		public function get game():PokerCardGame {
			return (_game);
		}
		
		/**
		 * The next dealer (current small blind) according to the dealer betting order, or null
		 * if order hasn't been established.
		 */
		public function get nextDealer():IPokerPlayerInfo {
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				if (currentPlayer.isSmallBlind) {
					return (currentPlayer);
				}
			}
			return (null);
		}
		
		/**
		 * @return The current community pot (sum of all bets in this round).
		 */
		public function get communityPot():Number {
			return (_communityPot);
		}
		
		/**
		 * @return True if the betting for the current deal is complete and the game phase may be updated; all non-folded
		 * players must have placed a bet and must have matched table bet (highest bet).
		 */
		public function get bettingComplete():Boolean {			
			if (_roundComplete) { 				
				return (true);
			}
			var nfPlayers:Vector.<IPokerPlayerInfo> = nonFoldedPlayers;
			for (var count:int = 0; count < nfPlayers.length; count++) {
				var pokerPlayerInfo:IPokerPlayerInfo = nfPlayers[count];
				//not all players have placed initial bet
				if (!pokerPlayerInfo.hasBet) {					
					return (false);
				}				
				if (pokerPlayerInfo.isBigBlind && (pokerPlayerInfo.numBets < 2)) {
					//big blind hadn't completed their action
					return (false);
				}
			}
			for (count = 0; count < nfPlayers.length; count++) {
				pokerPlayerInfo = nfPlayers[count];				
				if (pokerPlayerInfo.lastBet == Number.NEGATIVE_INFINITY) {					
					//not all players have bet or raised this round					
					return (false);
				}
			}		
			var baseBet:Number = nfPlayers[0].totalBet;			
			for (count = 1; count < nfPlayers.length; count++) {			
				pokerPlayerInfo = nfPlayers[count];				
				if (baseBet != pokerPlayerInfo.totalBet) {					
					//not all players have matched the current table raise (or highest bet)
					return (false);
				}
			}
			return (true);
		}
		
		/**
		 * @return True if all non-folded players have matched the highest bet/raise.
		 */
		public function get allPlayerBetsAreEqual():Boolean {
			if (_players == null) {				
				return (false);
			}
			if (_players.length == 1) {				
				return (true);
			}			
			for (var count:int = 1; count < _players.length; count++) {
				if ((_players[count].hasFolded==false) && (_players[count].hasBet)) {
					var baseBet:Number = _players[count].totalBet;
					break;
				}
			}			
			var nfPlayers:Vector.<IPokerPlayerInfo> = nonFoldedPlayers;
			for (count = 0; count < nfPlayers.length; count++) {
				var currentPlayer:IPokerPlayerInfo = nfPlayers[count];				
				if (currentPlayer.hasBet) {
					if (currentPlayer.totalBet != baseBet) {
						return (false);
					}
				}
			}
			return (true);
		}
		
		/**
		 * @return The local player's (self's) balance.
		 */
		public function get balance():Number {
			return (_balance);
		}
			
		/**
		 * @return The local player's (self's) current bet.
		 */
		public function get playerBet():Number {
			return (_currentPlayerBet);
		}
		
		/**
		 * @return The INetCliqueMember implementation associated with the current dealer, or null if one can't be found.
		 */
		public function get currentDealerMember():INetCliqueMember {			
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayerInfo:IPokerPlayerInfo = _players[count];				
				if (currentPlayerInfo.isDealer) {
					return (currentPlayerInfo.netCliqueInfo);
				}
			}
			return (null);
		}		
		
		/**
		 * @return The INetCliqueMember implementation associated with the current big blind, or null if one can't be found.
		 */
		public function get currentBigBlindMember():INetCliqueMember {
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayerInfo:IPokerPlayerInfo = _players[count];
				if (currentPlayerInfo.isBigBlind) {
					return (currentPlayerInfo.netCliqueInfo);
				}
			}
			return (null);
		}
		
		/**
		 * @return The INetCliqueMember implementation associated with the current small blind, or null if one can't be found.
		 */
		public function get currentSmallBlindMember():INetCliqueMember {
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayerInfo:IPokerPlayerInfo = _players[count];
				if (currentPlayerInfo.isSmallBlind) {
					return (currentPlayerInfo.netCliqueInfo);
				}
			}
			return (null);
		}
		
		/**
		 * The current PokerPlayerInfo instance that currently has betting control, null if no player currently has control.
		 */
		public function get currentBettingPlayer():IPokerPlayerInfo {			
			return (_currentBettingPlayer);
		}
		
		/**
		 * @return The INetCliqueMember implementation associated with the current dealer, or null if one can't be found.
		 */
		public function get dealerIsSet():Boolean {
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				if (currentPlayer.isDealer) {
					return (true);
				}
			}
			return (false);
		}
		
		/**
		 * @return True if a big blind player has been flagged.
		 */
		public function get bigBlindIsSet():Boolean {
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				if (currentPlayer.isBigBlind) {
					return (true);
				}
			}
			return (false);
		}
		
		/**
		 * @return True if a small blind player has been flagged.
		 */
		public function get smallBlindIsSet():Boolean {
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				if (currentPlayer.isSmallBlind) {
					return (true);
				}
			}
			return (false);
		}		
		
		/**		 
		 * @return True if the game has ended. This game is considered ended when all but one player have 0 balances.
		 */
		public function get gameHasEnded():Boolean {
			if (_players == null) {
				return (false);
			}
			if (_roundComplete == false) {
				return (false);
			}
			var zeroBalances:int = 0;
			for (var count:int = 0; count < _players.length; count++) {				
				if (_players[count].balance == 0){
					zeroBalances++;
				}
			}
			if (zeroBalances == (_players.length - 1)) {
				return (true);
			} else {
				return (false);
			}
		}
		
		/**		 
		 * @return True when all players have reported their crypto keys and hand analysis results. This value
		 * will be reset to false at the beginning of each round or when resetAllPlayersBettingFlags(true) is invoked.
		 */
		public function get allGameResultsReceived():Boolean {
			DebugView.addText("allGameResultsReceived");
			//need all players' results, including folded ones
			if (allPlayers.length == 1) {
				return (true);
			}
			try {
				for (var count:int = 0; count < allPlayers.length; count++) {
					if (allPlayers[count].lastResultHand == null) {
						return (false);
					}
				}
				return (true);
			} catch (err:*) {
				return (false);
			}
			return (false);
		}
		
		/**
		 * @return The IPokerPlayerInfo implementation of the current winning player or null if there is
		 * currently no winning player (a round has not fully completed).
		 */
		public function get winningPlayerInfo():IPokerPlayerInfo {
			try {				
				var nfPlayers:Vector.<IPokerPlayerInfo> = nonFoldedPlayers;				
				if (nfPlayers.length < 2) {
					//all but one player have folded
					return (nfPlayers[0]);
				}
				var highestHandValue:int = int.MIN_VALUE;
				var playerRef:IPokerPlayerInfo = null;
				for (var count:int = 0; count < nfPlayers.length; count++) {
					var currentPlayer:IPokerPlayerInfo = nfPlayers[count];					
					var resultHand:IPokerHand = currentPlayer.lastResultHand;					
					if (resultHand != null) {
						if (resultHand.totalHandValue > highestHandValue) {
							highestHandValue = resultHand.totalHandValue;
							playerRef = currentPlayer;
						}
					} else {						
						//all results not yet received
						return (null);
					}
				}
				return (playerRef);
			} catch (err:*) {				
				return (null);
			}			
			return (null);
		}

		/**
		 * @return True if the betting order has been locked and may not longer be directly updated via calls to
		 * addPlayer, setDealer, setBigBlind, and setSmallBlind.
		 */
		public function get bettingOrderLocked():Boolean {
			return (_bettingOrderLocked);
		}		

		/**
		 * The current big small value (not player).
		 */
		public function set smallBlind(valueSet:Number):void {
			_smallBlind = valueSet;			
		}
		
		public function get smallBlind():Number {
			return (_smallBlind);
		}
		
		/**
		 * The current big blind value (not player).
		 */
		public function set bigBlind(valueSet:Number):void {			
			_bigBlind = valueSet;		
		}
		
		public function get bigBlind():Number {
			return (_bigBlind);
		}

		/**
		 * Initializes the new instance by resetting all values to default and rendering the default view
		 * for the module. This function should only be called once per game (before the first round).
		 */
		public function initialize():void {			
			DebugView.addText("PokeBettingModule.initialize");
			try {
				this._peerMessageHandler.addToClique(game.clique);
				/*
				var viewsCat:XML = game.settings["getSettingsCategory"]("views");
				var bettingModuleNode:XML = game.settings["getSetting"]("views", "bettingmodule");
				if (bettingModuleNode == null) {	
					return;
				}
				ViewManager.render(bettingModuleNode, this, onRenderView);				
				*/
				var gameTypeDefinitions:XML = game.settings["getSetting"]("defaults", "gametypes");				
				this._bettingSettings = new PokerBettingSettings(gameTypeDefinitions, game.table);
				disablePlayerBetting();			
				this._peerMessageHandler.removeEventListener(PeerMessageHandlerEvent.PEER_MSG, onReceivePeerMessage);
				this._peerMessageHandler.addEventListener(PeerMessageHandlerEvent.PEER_MSG, onReceivePeerMessage);
				//Status.dispatcher.removeEventListener(PokerGameStatusEvent.NEW_COMMUNITY_CARDS, onNewCommunityCards);
				//Status.dispatcher.addEventListener(PokerGameStatusEvent.NEW_COMMUNITY_CARDS, onNewCommunityCards);
			} catch (err:Error) {
				DebugView.addText (err.getStackTrace());
			}
		}
		
		/**
		 * Sets the current _bettingSettings instance based on the type attribute.
		 * 
		 * @param	type The betting settings type attribute to use as current.
		 */
		public function setSettingsByType(type:String):void {
			return;
			for (var count:uint = 0; count < _bettingSettings.length; count++) {				
				if (_bettingSettings[count].gameType == type) {
					_currentSettingsIndex = count;
					DebugView.addText ("Updating betting settings to: "+_bettingSettings[count].gameName);					
					return;
				}
			}
		}
		
		/**
		 * Returns a PokerPlayerInfo object for the supplied NetCliqueMember, or null if none exists.
		 * 
		 * @param member The INetCliqueMember implementation to return an info object for.
		 */
		public function getPlayerInfo(member:INetCliqueMember):IPokerPlayerInfo {			
			if ((_players == null) || (member==null)) {
				return (null);
			}
			for (var count:int = 0; count < _players.length; count++) {				
				var currentPlayerInfo:IPokerPlayerInfo = _players[count];				
				if (currentPlayerInfo != null) {					
					if (currentPlayerInfo.netCliqueInfo.peerID == member.peerID) {						
						return (currentPlayerInfo);
					}
				}
			}
			return (null);
		}
		
		/**
		 * Returns the betting index of a specified non-folded player as an offset from the current small blind (i.e. 0=small blind, 1=big blind...).
		 * Note that the returned value isn't necessarily the same as the index of the player within the _players or nonFoldedPlayers array as the
		 * big/small blind positions will shift after every round.
		 * 
		 * @param	playerInfo The iPokerPlayerInfo implementation instance for which to find the betting index.
		 * 
		 * @return The betting index, or offset from the small blind, for the specified player. Returns -1 if the player doesn't appear in the nonFoldedPlayers
		 * array of if the betting order hasn't been established.
		 */	
		public function getBettingIndex(playerInfo:IPokerPlayerInfo):int {
			if (this.nonFoldedPlayers == null) {
				return ( -1);
			}
			var startingIndex:int =-1;
			var indexOffset:int = 0;
			var nfPlayers:Vector.<IPokerPlayerInfo> = this.nonFoldedPlayers;
			for (var count:int = 0; count < nfPlayers.length; count++) {
				var currentPlayerInfo:IPokerPlayerInfo = nfPlayers[count];
				if (currentPlayerInfo.isSmallBlind) {
					startingIndex = count;
					var evaluateLength:int = nfPlayers.length + startingIndex;
					for (var count2:int = startingIndex; count2 < evaluateLength; count2++) {
						var currentIndex:int = count2 % nfPlayers.length;
						var currentPlayer:IPokerPlayerInfo = nfPlayers[currentIndex];
						if (currentPlayer.netCliqueInfo.peerID == playerInfo.netCliqueInfo.peerID) {
							return (indexOffset);
						}
						indexOffset++;
					}
				}
			}
			return (-1);
		}
		
		/**
		 * Pauses the betting module by disabling the user interface and pausing any game timers.
		 */
		public function pause():void {
			disablePlayerBetting();
			currentSettings.currentTimer.stopCountDown(); //just stop, don't reset
		}
		
		/**
		 * Resumes the betting module by enabling the user interface if it's the  local (self) player's turn to bet.
		 * Any paused game timers are restarted.
		 */
		public function resume():void {			
			if (_currentBettingPlayer.netCliqueInfo.peerID == game.clique.localPeerInfo.peerID) {			
				enablePlayerBetting();				
			} else {
				var truncatedPeerID:String = _currentBettingPlayer.netCliqueInfo.peerID.substr(0, 15) + "...";			
			}
			currentSettings.currentTimer.startCountDown();
		}
		
		/**
		 * Removes any players from the players list with a zero balance.
		 */
		public function removeZeroBalancePlayers():void	{
			var _orginalPlayersArray:Vector.<IPokerPlayerInfo> = new Vector.<IPokerPlayerInfo>();
			for (var count:int = 0; count < _players.length; count++) {
				_orginalPlayersArray.push(_players[count]);
			}
			for (count = 0; count < _orginalPlayersArray.length; count++) {
				if (_orginalPlayersArray[count].balance <= 0) {					
					removePlayer(_orginalPlayersArray[count], true);
				}				
			}			
		}
		
		/**
		 * Resets the betting module in preparation of a new round. All player betting flags are cleared, the user
		 * interface is reset, blinds are updated if necessary, and the betting module is fully enabled.
		 */
		public function reset():void {
			DebugView.addText("PokerBettingModule.reset");
			resetAllPlayersBettingFlags(true);
			_roundComplete = false;
			_currentPlayerBet = new Number(0);
			_startingPlayerBet = new Number(0);
			_communityPot = new Number(0);
			updateTableBet();			
			disablePlayerBetting();
			smallBlind = _bettingSettings.currentLevelSmallBlind;;
			bigBlind = _bettingSettings.currentLevelBigBlind;
			if ((bigBlind > maximumTableBet) && (maximumTableBet != Number.NEGATIVE_INFINITY)) {
				//big blind is maximum bet for at least one player
				bigBlind = maximumTableBet;
				smallBlind = (maximumTableBet / 2);
				DebugView.addText("   Setting big blind value (max. adjusted): " + bigBlind);
				DebugView.addText("   Setting small blind value (max. adjusted): " + smallBlind);
			} else {
				DebugView.addText("   Setting big blind value: " + bigBlind);
				DebugView.addText("   Setting small blind value: " + smallBlind);
			}			
		}

		/**
		 * Disables the betting module by removing event listeners and disabling the user interface.
		 */
		public function disable():void {						
			this._peerMessageHandler.removeEventListener(PeerMessageHandlerEvent.PEER_MSG, onReceivePeerMessage);
			//Status.dispatcher.removeEventListener(PokerGameStatusEvent.NEW_COMMUNITY_CARDS, onNewCommunityCards);
			disablePlayerBetting();
		}
		
		/**
		 * Enables the betting module by adding event listeners and optionally enable the user interface.
		 * 
		 * @param includeUI Should user interface also be enabled?
		 */
		public function enable(includeUI:Boolean=false):void {
			DebugView.addText("enable");
			disable(); //prevent double listeners
			this._peerMessageHandler.addEventListener(PeerMessageHandlerEvent.PEER_MSG, onReceivePeerMessage);
			//Status.dispatcher.addEventListener(PokerGameStatusEvent.NEW_COMMUNITY_CARDS, onNewCommunityCards);
			enablePlayerBetting();
		}
		
		/**
		 * Invoked by the ViewManager when the betting module view is rendered.
		 */
		public function onRenderView():void {			
		}
		
		/**
		 * Notifies the betting module that the local (self) player is committing the current bet. This action is shared among all betting-type
		 * actions that include a bet amount such as bet, raise, call, check, etc.
		 */
		public function onBetCommit():void {
			DebugView.addText ("PokerBettingModule.onBetCommit");		
			disablePlayerBetting();
			stopKeepOnTop();
			commitCurrentBet();				
		}
		
		/**
		 * @return The maximum allowable table bet defined as the minimum balance of all active, non-folded players.
		 */
		public function get maximumTableBet():Number {			
			var maximumBet:Number = Number.POSITIVE_INFINITY;
			var nfPlayers:Vector.<IPokerPlayerInfo> = nonFoldedPlayers;			
			for (var count:int = 0; count < nfPlayers.length; count++) {
				if (maximumBet > nfPlayers[count].balance) {					
					//only include balances for players that have bet this round			
					if (nfPlayers[count].lastBet != Number.NEGATIVE_INFINITY) {
						maximumBet = nfPlayers[count].balance + nfPlayers[count].lastBet;						
					} else {
						maximumBet = nfPlayers[count].balance;						
					}
					if (nfPlayers[count].balance == 0) {
						//otherwise the balance+lastBet calculation is used which won't be correct
						maximumBet = 0;
					}
				}
			}
			//if player hasn't busted...
			if (selfPlayerInfo != null) {				
				if (maximumBet > selfPlayerInfo.balance) {
					maximumBet = selfPlayerInfo.balance;
				}
			}
			maximumBet = _currencyFormat.roundToFormat(maximumBet, _bettingSettings.currencyFormat);
			return (maximumBet);
		}
		
		/**
		 * Increments the local (self) player's bet value. 
		 * 
		 * @param	incrValue The value to increment the player's bet amount by. If not supplied or set to Number.NEGATIVE_INFINITY
		 * the default small increment value from the game settings object/data is used.
		 */
		public function incrementBet(incrValue:Number = Number.NEGATIVE_INFINITY):void {
			if (incrValue > Number.NEGATIVE_INFINITY) {
				var newValue:Number = _currentPlayerBet + incrValue;
			} else {
				newValue = _currentPlayerBet + _bettingSettings.smallIncrement;
			}
			newValue = _currencyFormat.roundToFormat(newValue, _bettingSettings.currencyFormat);
			var smallestBalance:Number = maximumTableBet;			
			if (newValue > smallestBalance) {
				newValue = smallestBalance;
			}
			updatePlayerBet(newValue, true);
			enablePlayerBetting();
		}
		
		/**
		 * Decrements the local (self) player's bet value. 
		 * 
		 * @param	decrValue The value to decrement the player's bet amount by. If not supplied or set to Number.NEGATIVE_INFINITY
		 * the default, negative small increment value from the game settings object/data is used.
		 */
		public function decrementBet(decrValue:Number = Number.NEGATIVE_INFINITY):void {
			if (decrValue > Number.NEGATIVE_INFINITY) {
				var newValue:Number = _currentPlayerBet - decrValue;
			} else {
				newValue = _currentPlayerBet - _bettingSettings.smallIncrement;
			}			
			newValue = _currencyFormat.roundToFormat(newValue, _bettingSettings.currencyFormat);			
			if (newValue < 0) {
				newValue = 0;
			}			
			updatePlayerBet(newValue, true);
			enablePlayerBetting();
		}		
		
		/**
		 * Notifies the betting module that the local (self) player is folding.
		 * 
		 */
		public function onFold():void {
			DebugView.addText("   I have folded.");
			disablePlayerBetting();
			if ((game.ethereum != null) && (game.activeSmartContract != null)) {
				// begin smart contract deferred invocation: fold
				var betValueWei:String = game.ethereum.web3.toWei(_currentPlayerBet, "ether");
				var deferDataObj1:Object = new Object();
				var contractBettingPhases:String = game.activeSmartContract.getDefault("bettingphases");
				var phasesSplit:Array = contractBettingPhases.split(",");
				deferDataObj1.phases = phasesSplit[this._smartContractBettingPhase];
				deferDataObj1.account = "all"; //as specified in contract
				var defer1:SmartContractDeferState = new SmartContractDeferState(game.phaseDeferCheck, deferDataObj1, game, true);
				defer1.operationContract = game.activeSmartContract;
				var deferDataObj2:Object = new Object()
				var potValueWei:String = game.ethereum.web3.toWei(this.communityPot, "ether");
				deferDataObj2.pot = potValueWei;
				var defer2:SmartContractDeferState = new SmartContractDeferState(game.potDeferCheck, deferDataObj2, game);
				defer2.operationContract = game.activeSmartContract;
				var deferDataObj3:Object = new Object();
				deferDataObj3.position = this.getBettingIndex(this.selfPlayerInfo);
				var defer3:SmartContractDeferState = new SmartContractDeferState(game.betPositionDeferCheck, deferDataObj3, game, true);
				defer3.operationContract = game.activeSmartContract;
				var deferArray:Array = game.combineDeferStates(game.deferStates, [defer1, defer2, defer3]);			
				//game.activeSmartContract.fold().defer(deferArray).invoke({from:game.ethereumAccount, gas:150000});
				game.actionsContract.fold(game.activeSmartContract.address).defer(deferArray).invoke({from:game.ethereumAccount, gas:150000});
				// end smart contract deferred invocation: fold
			}			
			onPlayerFold(game.clique.localPeerInfo.peerID);
			var msg:PokerBettingMessage = new PokerBettingMessage();
			msg.createBettingMessage(PokerBettingMessage.PLAYER_FOLD);
			game.clique.broadcast(msg);
			updateGamePhase(null);
		}		
		
		/**
		 * Verifies the existence of a clique member within the current _players vector.
		 * 
		 * @param	member The INetCliqueMember implementation to verify.
		 * 
		 * @return True if the member exists within the _players vector, false otherwise.
		 */
		public function playerInfoExists(member:INetCliqueMember):Boolean {
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayerInfo:IPokerPlayerInfo = _players[count];
				if (currentPlayerInfo != null) {
					if (currentPlayerInfo.netCliqueInfo.peerID == member.peerID) {
						return (true);
					}
				}
			}		
			return (false);
		}
		
		/**
		 * Get the balances for the supplied list of Net Clique members. Any members that don't have
		 * a balance will have a null entry in the returned vector.
		 * 
		 * @param	members The Net Clique member list to return balances for.
		 * 
		 * @return A vector array of balances for the supplied members, in the order of the member list.
		 * Any members that don't have registered balances will have Number.NEGATIVE_INFINITY entries in their position.
		 */
		public function getPlayerBalances(members:Vector.<INetCliqueMember>):Vector.<Number> {
			if (members == null) {
				return (null);
			}
			var returnBalances:Vector.<Number> = new Vector.<Number>();
			for (var count:uint = 0; count < members.length; count++) {
				var currentMember:INetCliqueMember = members[count];
				returnBalances.push(getPlayerBalance(currentMember));				
			}
			return (returnBalances);
		}
		
		/**
		 * Sets the same balance value for all registered players and broadcasts an instruction to do the same to all 
		 * connected players.
		 * 
		 * @param	balanceVal The balance value to assign to all registered players.
		 */
		public function setAllPlayerBalances(balanceVal:Number = Number.NEGATIVE_INFINITY):void {
			if (_initialPlayerBalances != null) {
				//already set
				return;
			}
			if (balanceVal == Number.NEGATIVE_INFINITY) {
				balanceVal = _bettingSettings.startingBalance;
			}
			DebugView.addText ("PokerBettingModule.setAllPlayerBalances");			
			for (var count:int = 0; count < _players.length; count++) {
				DebugView.addText ("Setting balance for player: " + _players[count].netCliqueInfo.peerID);
				DebugView.addText ("to " + balanceVal);
				_players[count].balance = balanceVal;
			}
			game.dispatchStatusEvent(PokerGameStatusEvent.SET_BALANCES, this, {players: _players});
			/*
			//var payload:Array = new Array();
			_initialPlayerBalances = new Array();
			for (count = 0; count < _players.length; count++) {
				//this structure allows for unique per-player buy-ins
				var balanceObj:Object = new Object();
				balanceObj.balance = balanceVal;
				balanceObj.peerID = _players[count].netCliqueInfo.peerID;
				DebugView.addText ("    Peer "+balanceObj.peerID+" balance is now: " + balanceObj.balance);
				//payload.push(balanceObj);
				_initialPlayerBalances.push(balanceObj);
			}			
			//All players should now get this data from the Table reference
			
			var msg:PokerBettingMessage = new PokerBettingMessage();
			msg.createBettingMessage(PokerBettingMessage.DEALER_SET_PLAYERBALANCES, 0, payload);			
			game.clique.broadcast(msg);
			*/
		}
		
		/**
		 * Adds a player to the end of betting order if the order hasn't been locked. Should only be used by 
		 * a Dealer instance to establish the initial betting order (new game).
		 * 
		 * @return True if member was newly added, false if member previously added.
		 */
		public function addPlayer(member:INetCliqueMember):Boolean {
			if (_bettingOrderLocked)  {
				return (false);
			}
			if (playerInfoExists(member)) {				
				return (false);
			}
			var newPlayerInfo:PokerPlayerInfo = new PokerPlayerInfo(member);
			_players.push(newPlayerInfo);			
			return (true);
		}
		
		/**
		 * Removes a player from the betting order.
		 * 
		 * @param	member The member to remove. May be a string containing the peer ID of the member to
		 * remove or a reference to the member's INetCliqueMember or IPokerPlayerInfo implementation.
		 * @param	updatePlayerRoles If true players' roles are updated. For example, if the player being removed
		 * is the big blind the next player assumes the big blind role. Roles are always updated to the next player.
		 * 
		 * @return True of the matching member was removed and (optionally) roles were updated, false if the operation failed.
		 */
		public function removePlayer(member:*, updateRoles:Boolean = true):Boolean {			
			var peerID:String = new String();
			if (member is String) {
				peerID = member;
			} else if (member is INetCliqueMember) {
				peerID = INetCliqueMember(member).peerID;
			} else if (member is IPokerPlayerInfo) {
				peerID = IPokerPlayerInfo(member).netCliqueInfo.peerID;
			} else {
				return (false);
			}
			if (updateRoles) {
				//must be done first
				updatePlayerRoles(peerID);
			}
			var playerRemoved:Boolean = false;
			var newPlayersList:Vector.<IPokerPlayerInfo> = new Vector.<IPokerPlayerInfo>();
			for (var count:int = 0; count < _players.length; count++) {
				if (_players[count].netCliqueInfo.peerID != peerID) {
					newPlayersList.push(_players[count]);
				} else {
					DebugView.addText ("Peer \""+_players[count].netCliqueInfo.peerID+"\" has been removed from betting order.");
					playerRemoved = true;
				}
			}
			_players = newPlayersList;
			return (playerRemoved);
		}		
		
		/**
		 * Sets the dealer flag for an associated member if the betting order hasn't been locked. Should only be used by 
		 * a Dealer instance to establish the initial dealer (new game).
		 * 
		 * @param member The member to set the dealer flag for.
		 * @param dealerSet The value to set the dealer flag to.
		 */
		public function setDealer(member:INetCliqueMember, dealerSet:Boolean = true):void {
			if (_bettingOrderLocked)  {
				return;
			}
			var playerInfo:IPokerPlayerInfo = getPlayerInfo(member);			
			if (playerInfo != null) {				
				playerInfo.isDealer = dealerSet;
			}
		}
		
		/**
		 * Sets the big blind flag for an associated member if the betting order hasn't been locked. Should only be used by 
		 * a Dealer instance to establish the initial big blind (new game).
		 * 
		 * @param member The member to set the big blind flag for.
		 * @param dealerSet The value to set the big blind flag to.
		 */
		public function setBigBlind(member:INetCliqueMember, bbSet:Boolean = true):void {
			if (_bettingOrderLocked)  {
				return;
			}
			var playerInfo:IPokerPlayerInfo = getPlayerInfo(member);
			if (playerInfo!=null) {
				playerInfo.isBigBlind = bbSet;
			}
		}
		
		/**
		 * Sets the small blind flag for an associated member if the betting order hasn't been locked. Should only be used by 
		 * a Dealer instance to establish the initial small blind (new game).
		 * 
		 * @param member The member to set the small blind flag for.
		 * @param dealerSet The value to set the small blind flag to.
		 */
		public function setSmallBlind(member:INetCliqueMember, sbSet:Boolean = true):void {
			if (_bettingOrderLocked)  {
				return;
			}
			var playerInfo:IPokerPlayerInfo = getPlayerInfo(member);
			if (playerInfo!=null) {
				playerInfo.isSmallBlind = sbSet;			
			}				
		}
		
		/**
		 * Locks the dealer betting order. Once locked the order can't be updated by calling addPlayer, setDealer, setBigBlind, 
		 * and setSmallBlind but it is updated by the betting module during a reset.
		 */
		public function lockBettingOrder():void {
			_bettingOrderLocked = true;
		}
		
		/**
		 * Broadcasts the current betting order to the clique if the order hasn't been locked (new game). 
		 * To be invoked only by the current dealer.
		 * 
		 * @return True if the current betting order was successfully broadcast.
		 */
		public function broadcastBettingOrder():Boolean {
			/**
			 * betting order: small blind, big blind, other player(s), dealer
			 * if only two players, dealer is big blind and other player is small blind
			 */
			if (!game.table.dealerIsMe) {
				return (false);
			}
			if (_bettingOrderLocked) {
				return (false);
			}
			DebugView.addText("PokerBettingModule.broadcastBettingOrder");
			var message:PokerBettingMessage = new PokerBettingMessage();
			var bettingOrder:Array = new Array();		
			bettingOrder.push(currentSmallBlindMember.peerID);
			DebugView.addText("   Small blind: " + currentSmallBlindMember.peerID);
			bettingOrder.push(currentBigBlindMember.peerID);
			DebugView.addText("   Big blind: "+currentBigBlindMember.peerID);
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count] as IPokerPlayerInfo;
				if ((!currentPlayer.isDealer) && (!currentPlayer.isBigBlind) && (!currentPlayer.isSmallBlind)) {
					bettingOrder.push(currentPlayer.netCliqueInfo.peerID);
					DebugView.addText("   Player: "+currentPlayer.netCliqueInfo.peerID);
				}
			}
			if (currentDealerMember.peerID!=currentBigBlindMember.peerID) {
				bettingOrder.push(currentDealerMember.peerID);
				DebugView.addText("   Dealer: " + currentDealerMember.peerID);
			} else {
				DebugView.addText("   Dealer is small blind");
			}
			message.createBettingMessage(PokerBettingMessage.DEALER_SET_BETTINGORDER, Number.POSITIVE_INFINITY, bettingOrder);
			return (game.clique.broadcast(message));
		}
				
		/**
		 * Starts the next (or first) betting cycle.
		 */
		public function startNextBetting():void {
			DebugView.addText("PokerBettingModule.startNextBetting");
			keepOnTop();			
			var message:PokerBettingMessage = new PokerBettingMessage();
			message.createBettingMessage(PokerBettingMessage.DEALER_START_BLINDSTIMER);
			game.clique.broadcast(message);
			startBlindsTimer();
			passBettingControlToNextPlayer();			
		}
		
		/**
		 * Sets starting blinds values from on the game's main Table instance.
		 */
		public function setStartingBlindValues():void {
			this.bigBlind = Number(game.table.bigBlindAmount);
			this.smallBlind = Number(game.table.smallBlindAmount);
			game.dispatchStatusEvent(PokerGameStatusEvent.SET_BLINDS, this, {bigBlind:bigBlind, smallBlind:smallBlind});
			/*
			DebugView.addText("PokerBettingModule.dealerSetBlinds");
			DebugView.addText("   Current maximum table bet: " + maximumTableBet);
			if ((bigBlindVal > maximumTableBet) && (maximumTableBet != Number.NEGATIVE_INFINITY)) {
				smallBlindVal = maximumTableBet / 2;
				bigBlindVal = maximumTableBet;
				DebugView.addText("   Setting big blind value (max. adjusted):" + bigBlindVal);
				DebugView.addText("   Setting small blind value (max. adjusted): " + smallBlindVal);				
			} else {
				smallBlind = smallBlindVal;
				bigBlind = bigBlindVal;
				DebugView.addText("   Setting big blind value: " + bigBlindVal);
				DebugView.addText("   Setting small blind value: " + smallBlindVal);				
			}
			var msg:PokerBettingMessage = new PokerBettingMessage();
			var blindsObj:Object = new Object();
			blindsObj.bigBlind = bigBlindVal;
			blindsObj.smallBlind = smallBlindVal;
			msg.createBettingMessage(PokerBettingMessage.DEALER_SET_BLINDS, 0, blindsObj);
			game.clique.broadcast(msg);
			*/
		}

		/**
		 * 
		 * Attempts to start the blinds timer.
		 * 
		 * @return True if the timer could be successfully started.
		 */
		public function startBlindsTimer():Boolean {
			DebugView.addText("PokerBettingModule.startBlindsTimer");
			DebugView.addText("   Betting settings->");
			try {
				DebugView.addText("                    Name: " + currentSettings.gameName);
				DebugView.addText("          Currency units: " + currentSettings.currencyUnits);
				DebugView.addText("                   Valid: " + currentSettings.valid);			
				DebugView.addText("                   Level: " + currentSettings.currentLevel);
				DebugView.addText("               Big blind: " + currentSettings.currentLevelBigBlind);
				DebugView.addText("             Small blind: " + currentSettings.currentLevelSmallBlind);
				DebugView.addText("      Time to next level: " + currentSettings.currentTimerValue);			
				DebugView.addText("             Time format: " + currentSettings.currentTimerFormat);
				currentSettings.currentTimer.addEventListener(GameTimerEvent.COUNTDOWN_TICK, onBlindsTimerTick);
				currentSettings.currentTimer.addEventListener(GameTimerEvent.COUNTDOWN_END, onBlindsTimerComplete);
				currentSettings.currentTimer.startCountDown();				
				return (true);
			} catch (err:*) {
				DebugView.addText("PokerBettingModule.startBlindsTimer: " + err);
			}
			return (false);
		}
		
		/**
		 * Begins the betting round by passing betting control to the next player (usually the small blind). This function
		 * should only be incoked by the dealer.
		 */
		public function passBettingControlToNextPlayer():void {
			DebugView.addText("PokerBettingModule.passBettingControlToNextPlayer");			
			var msg:PokerBettingMessage = new PokerBettingMessage();
			msg.createBettingMessage(PokerBettingMessage.DEALER_START_BET);
			game.clique.broadcast(msg);
		}
		
		/**
		 * Event listener invoked when a peer message is received from the PeerMessageHandler. Processing of the message
		 * is done in the processPeerMessage function.
		 * 
		 * @param	eventObj Event dispatched by the PeerMessageHandler.
		 */
		public function onReceivePeerMessage(eventObj:PeerMessageHandlerEvent):void {
			processPeerMessage(eventObj.message);
		}

		/**
		 * Updates the established betting order such that the small blind becomes the dealer,
		 * the big blind becomes the small blind, and the next player after the new small blind
		 * becomes the big blind.
		 */
		public function updateBettingOrder():void {			
			var currentDealerMemberRef:IPokerPlayerInfo = getPlayerInfo(currentDealerMember);
			var currentBBRef:IPokerPlayerInfo = getPlayerInfo(currentBigBlindMember);
			var currentSBRef:IPokerPlayerInfo = getPlayerInfo(currentSmallBlindMember);		
			var dUpdated:Boolean = false; //these flags prevent double updates
			var bbUpdated:Boolean = false;
			var sbUpdated:Boolean = false;			
			var previousPlayer:IPokerPlayerInfo = _players[_players.length-1];
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];					
				if (currentPlayer.isDealer && (!dUpdated)) {
					previousPlayer.isDealer = true;					
					currentPlayer.isDealer = false;
					dUpdated = true;
				}
				if (currentPlayer.isBigBlind && (!bbUpdated)) {
					previousPlayer.isBigBlind = true;					
					currentPlayer.isBigBlind = false;
					bbUpdated = true;
				}
				if (currentPlayer.isSmallBlind && (!sbUpdated)) {
					previousPlayer.isSmallBlind = true;					
					currentPlayer.isSmallBlind = false;
					sbUpdated = true;
				}
				previousPlayer = currentPlayer;	
			}			
		}
		
		/**
		 * Broadcasts the local player's (self's) final game results and crypto key chain to the clique.
		 * 
		 * @param	handAnalyzer The poker hand analyzer instance containing the fully analyzed results for the current round.
		 * @param	key The key chain for the round to broadcast with the results.
		 * 
		 * @return True if the results were successfully broadcast.
		 */
		public function broadcastGameResults(handAnalyzer:IPokerHandAnalyzer, key:Vector.<ISRAMultiKey>):Boolean {			
			DebugView.addText("PokerBettingModule.broadcastGameResults");
			if ((handAnalyzer == null) || (key == null)) {			
				return (false);
			}
			if (nonFoldedPlayers.length < 2) {
				//null results already included with fold message so nothing to broadcast
				return (false);
			}
			if (selfPlayerInfo == null) {
				//busted
				return (false);
			}
			_lastHighestHand = handAnalyzer.highestHand;
			selfPlayerInfo.lastResultHand = _lastHighestHand;
			/*
			if (_lastHighestHand == null) {
				//hand couldn't be determined (probably folded before enough cards were dealt)				
				var msg:PokerBettingMessage = new PokerBettingMessage();			
				msg.createBettingMessage(PokerBettingMessage.PLAYER_RESULTS, 0);
				game.clique.broadcast(msg);
				if (allGameResultsReceived) {
					onRoundComplete();
				}
				return (true);
			}
			*/
			var payload:Object = new Object();
			payload["keys"] = new Array();			
			payload["hands"] = new Array();
			payload["hands"][0] = new Array(); //usually include only one hand but this leaves room for expansion
			//concatenate all crypto key pairs into multidimensional arrays; first level contains keys used in initial/re-keying operations,
			//second level contains sequential keys used for multiple operations
			for (var count:int = 0; count < key.length; count++) {
				var currentKeys:ISRAMultiKey = key[count];				
				var currentKeyObject:Array = new Array();
				for (var count2:int = 0; count2 < currentKeys.numKeys; count2++) {					
					var currentKey:ISRAKey = currentKeys.getKey(count2);
					var currentKeyContainer:Object = new Object();
					currentKeyContainer.encKey = currentKey.encKeyHex;
					currentKeyContainer.decKey = currentKey.decKeyHex;
					currentKeyContainer.mod = currentKey.modulusHex;
					currentKeyObject.push(currentKeyContainer);
				}
				payload["keys"].push(currentKeyObject);
			}
			payload["hands"][0].matchedCards = new Array();
			payload["hands"][0].matchedHand = new Array();
			if (_lastHighestHand != null) {
				//use try...catch since player may not have enough cards for a full hand and this will fail				
				//include matched cards in winning hand			
				try {
					for (count = 0; count < _lastHighestHand.matchedCards.length; count++) {
						var currentCard:ICard = _lastHighestHand.matchedCards[count];
						var cardMapping:String = game.currentDeck.getMappingByCard(currentCard);						
						payload["hands"][0].matchedCards[count] = new Array();				
						payload["hands"][0].matchedCards[count].mapping = cardMapping;
						payload["hands"][0].matchedCards[count].cardName = currentCard.cardName;
						payload["hands"][0].matchedCards[count].frontClassName = currentCard.frontClassName;
						payload["hands"][0].matchedCards[count].faceColor = currentCard.faceColor;
						payload["hands"][0].matchedCards[count].faceText = currentCard.faceText;
						payload["hands"][0].matchedCards[count].faceValue = currentCard.faceValue;
						payload["hands"][0].matchedCards[count].faceSuit = currentCard.faceSuit;
					}
				} catch (err:*) {				
				}
				try {
					for (count = 0; count < _lastHighestHand.matchedHand.length; count++) {
						currentCard = _lastHighestHand.matchedHand[count];
						cardMapping = game.currentDeck.getMappingByCard(currentCard);						
						payload["hands"][0].matchedHand[count] = new Array();				
						payload["hands"][0].matchedHand[count].mapping = cardMapping;
						payload["hands"][0].matchedHand[count].cardName = currentCard.cardName;
						payload["hands"][0].matchedHand[count].frontClassName = currentCard.frontClassName;
						payload["hands"][0].matchedHand[count].faceColor = currentCard.faceColor;
						payload["hands"][0].matchedHand[count].faceText = currentCard.faceText;
						payload["hands"][0].matchedHand[count].faceValue = currentCard.faceValue;
						payload["hands"][0].matchedHand[count].faceSuit = currentCard.faceSuit;
					}			
					payload["hands"][0].matchName = String(_lastHighestHand.matchedDefinition.@name);
					payload["hands"][0].rank = String(_lastHighestHand.matchedDefinition.@rank);
					payload["hands"][0].value = String(_lastHighestHand.totalHandValue);			
				} catch (err:*) {				
				}
			} else {
				payload["hands"][0].matchName = "fold";
				payload["hands"][0].rank = "0";
				payload["hands"][0].value = "0";
			}			
			game.currentGameVerifier.addPlayerResults(selfPlayerInfo.netCliqueInfo.peerID, payload);
			var msg:PokerBettingMessage = new PokerBettingMessage();			
			msg.createBettingMessage(PokerBettingMessage.PLAYER_RESULTS, 0, payload);
			msg.targetPeerIDs = "*";
			game.clique.broadcast(msg);
			//Uncomment following to display end-game message in game log:			
			if (allGameResultsReceived) {
				onRoundComplete();
			}
			return (true);
		}
		
		/**
		 * Called when the final bet in a game is committed. Betting module will be in read-only mode until the next
		 * game round is initiated.
		 */
		public function onFinalBet():void {			
			DebugView.addText("PokerBettingModule.onFinalBet");
			//usually handled in Player class which invokes broadcastGameResults below
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BETTING_FINAL_DONE);
			dispatchEvent(event);
		}
		
		/**
		 * Resets the starting player bet to 0 if the current (local) player is the small blind. This function should only be called immediately
		 * after new public/community cards have been dealt.
		 */
		public function resetStartingPlayerBet():void {
			if (smallBlindIsMe) {
				this._startingPlayerBet = 0;
				this._currentPlayerBet = 0;
				this.resetAllPlayersBettingFlags(false);
				this.updatePlayerBet(0, false);
			}
		}
		
		/**
		 * Finds the balance for a specified member.
		 * 
		 * @param	member The member for which to find a balance.
		 * 
		 * @return The member's balance or Number.NEGATIVE_INFINITY if not set.
		 */
		protected function getPlayerBalance(member:INetCliqueMember):Number {
			try {
				for (var count:uint = 0; count < _players.length; count++) {
					var currentBalanceObj:IPokerPlayerInfo = _players[count];
					if (currentBalanceObj.netCliqueInfo.peerID == member.peerID) {
						return (currentBalanceObj.balance as Number);
					}
				}				
			} catch (err:*) {
				return (Number.NEGATIVE_INFINITY);
			}
			return (Number.NEGATIVE_INFINITY);
		}
		
		/**
		 * Stored player balances stored in a peer ID/balance array to registered players in the betting module.
		 * 
		 * @param	balancesObjArray Array of objects containing "balance" and "peerID" properties used to find associated
		 * players and assign balance values in the betting module.		 
		 */
		protected function storePlayerBalances(balancesObjArray:Array):void	{
			//may be called before array exists
			if (balancesObjArray != null) {
				DebugView.addText ("PokerBettingModule.storePlayerBalances");
				for (var item:* in balancesObjArray) {
					//this structure allows for unique per-player buy-ins.
					var balanceInfoObj:Object = balancesObjArray[item];
					var targetPeer:INetCliqueMember = findMemberByID(balanceInfoObj.peerID, true);
					var targetPlayer:IPokerPlayerInfo = getPlayerInfo(targetPeer);									
					DebugView.addText("   Setting balance for peer " + balanceInfoObj.peerID + ":" + balanceInfoObj.balance);
					targetPlayer.balance = Number(balanceInfoObj.balance);
				}
			}
		}
		
		/**
		 * Processes a (usually) incoming peer message. Invalid messages are ignored.
		 * 
		 * @param	peerMessage The peer message to process.
		 */
		protected function processPeerMessage(peerMessage:IPeerMessage):void {			
			var peerMsg:PokerBettingMessage = PokerBettingMessage.validateBettingMessage(peerMessage);			
			if (peerMsg == null) {				
				//not a poker betting message
				return;
			}						
			if (peerMessage.isNextSourceID(game.clique.localPeerInfo.peerID)) {				
				//message came from us + we are the next source ID meaning no other peer has processed the message
				return;
			}			
			peerMsg.timestampReceived = peerMsg.generateTimestamp();
			try {
				//TODO: this should work with peerMsg too; some values not being properly copied
				if (peerMessage.hasTargetPeerID(game.clique.localPeerInfo.peerID)) {
					//message is either for us or whole clique (*)
					switch (peerMsg.bettingMessageType) {
						case PokerBettingMessage.DEALER_SET_PLAYERBALANCES:
							DebugView.addText("  PokerBettingMessage.DEALER_SET_PLAYERBALANCES");
							DebugView.addText("     Message is deferred. Ignoring.");
							/*
							if (_initialPlayerBalances != null) {
								DebugView.addText("     Buy-in already set. Ignoring.");
							} else {
								DebugView.addText("     Received starting player balances (buy-in) from dealer.");
								try {
									//store player balances until betting order is established
									_initialPlayerBalances = peerMsg.data;
									//process now if betting order already established
									storePlayerBalances(_initialPlayerBalances);
								} catch (err:*) {
									DebugView.addText (err);
								}
							}
							*/
							break;
						case PokerBettingMessage.PLAYER_UPDATE_BET:
							DebugView.addText("  PokerBettingMessage.PLAYER_UPDATE_BET");
							updateExternalPlayerBet(peerMsg);
							break;
						case PokerBettingMessage.PLAYER_SET_BET:
							DebugView.addText("PokerBettingMessage.PLAYER_SET_BET");
							DebugView.addText("    Bet value=" + peerMsg.value);							
							if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {	
								if (!this.verifySignedBet(peerMsg)) {
									//wait until transaction appears on the blockchain
									this.waitForContractBet(peerMsg);									
									return;
								}
								this._transactions.addTransaction(peerMsg.data.ethTransaction, peerMsg);
							}
							setExternalPlayerBet(peerMsg);						
							updateTablePot(peerMsg.value);
							updateTableBet();							
							_currentBettingPlayer = nextBettingPlayer(peerMessage.getSourcePeerIDList());							
							if (_currentBettingPlayer!=null) {
								DebugView.addText("   Peer now has betting control: " + _currentBettingPlayer.netCliqueInfo.peerID);
							} else {
								//betting order hasn't been determined yet so this message is probably out of order
								DebugView.addText("   Current betting peer can't be determined!");
							}
							var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BETTING_PLAYER);
							event.sourcePlayer = _currentBettingPlayer;
							this.dispatchEvent(event);
							updateGamePhase(peerMsg);							
							break;
						case PokerBettingMessage.DEALER_SET_BLINDS:
							DebugView.addText("  PokerBettingMessage.DEALER_SET_BLINDS");
							DebugView.addText("     Message is deferred. Ignoring.");
							//onDealerSetBlinds(peerMsg.data);
							break;
						case PokerBettingMessage.DEALER_START_BLINDSTIMER:
							DebugView.addText("  PokerBettingMessage.DEALER_START_BLINDSTIMER");
							startBlindsTimer();
							break;
						case PokerBettingMessage.DEALER_SET_BETTINGORDER:
							DebugView.addText("  PokerBettingMessage.DEALER_SET_BETTINGORDER");
							//new PokerGameStatusReport("Dealer has established betting order.").report();
							onReceiveBettingOrder(peerMsg.data);
							//Updated (v2.0): Starting balances/buy-ins and blinds are now retrieved from Table instance
							this.setAllPlayerBalances(Number(game.table.buyInAmount));
							this.setStartingBlindValues();							
							break;
						case PokerBettingMessage.DEALER_START_BET:
							DebugView.addText("  PokerBettingMessage.DEALER_START_BET");
							_currentBettingPlayer = nextBettingPlayer(peerMessage.getSourcePeerIDList());							
							onNextPlayerBet(peerMsg.getSourcePeerIDList());
							break;
						case PokerBettingMessage.PLAYER_FOLD:
							DebugView.addText("  PokerBettingMessage.PLAYER_FOLD");							
							DebugView.addText("     Source peers: "+peerMsg.sourcePeerIDs);
							onPlayerFold(peerMsg.getSourcePeerIDList()[0].peerID);
							_currentBettingPlayer = nextBettingPlayer(peerMessage.getSourcePeerIDList());
							event = new PokerBettingEvent(PokerBettingEvent.BETTING_PLAYER);
							event.sourcePlayer = _currentBettingPlayer;
							this.dispatchEvent(event);
							updateGamePhase(peerMsg);							
							break;
						case PokerBettingMessage.PLAYER_RESULTS:
							DebugView.addText("  PokerBettingMessage.PLAYER_RESULTS");
							DebugView.addText("      Received from: "+peerMsg.getSourcePeerIDList()[0].peerID);							
							var playerHand:PokerHand = new PokerHand(null, null, null);
							playerHand.generateFromPeerMessage(peerMsg, game);
							var memberInfo:INetCliqueMember = peerMsg.getSourcePeerIDList()[0];
							var playerInfo:IPokerPlayerInfo = getPlayerInfo(memberInfo);
							if (playerInfo != null) {
								DebugView.addText ("Adding results now...");
								game.currentGameVerifier.addPlayerResults(memberInfo.peerID, peerMsg.data);
								playerInfo.lastResultHand = playerHand;
							}
							if (allGameResultsReceived) {
								onRoundComplete();
							}
							break;
						default:
							DebugView.addText("  Unsupported operation "+peerMsg.bettingMessageType);
							break;
					}
				}
			} catch (err:*) {
				DebugView.addText("  Error: " + err);
			}
		}
		
		/**
		 * Starts a loop to keep the betting module on top of other visible elements in the parent container.
		 */
		private function keepOnTop():void {			
			stopKeepOnTop();
			addEventListener(Event.ENTER_FRAME, keepOnTopLoop);
		}
		
		/**
		 * ENTER_FRAME event responder that pushes the betting module instance to the top of the parent
		 * display list. Use keepOnTop to start the loop and stopKeepOnTop to stop it.
		 * 
		 * @param	eventObj
		 */
		private function keepOnTopLoop(eventObj:Event):void {
			parent.setChildIndex(this, (parent.numChildren-1));
		}
		
		/**
		 * Stops the loop to keep the betting module on top of the display list of the parent container.
		 */
		private function stopKeepOnTop():void {			
			try {
				removeEventListener(Event.ENTER_FRAME, keepOnTopLoop);
			} catch (err:*) {				
			}
		}
		
		/**
		 * Invoked when the betting order is received from the current dealer. This method populates the internal
		 * _players array which is used in numerous methods and getters/setters throughout this class. 
		 * 
		 * @param	peerIDList The ordered list of peers (usually as received in a PokerBettingMessage.DEALER_SET_BETTINGORDER 
		 * event). The order for this list is: small blind, big blind, other player(s), dealer. In a 3-player game this
		 * order is: small blind, big blind, dealer. In a 2 player game the order is: small blind, big blind & dealer (same player).
		 */
		private function onReceiveBettingOrder(peerIDList:Array):void {			
			DebugView.addText("PokerBettingModule.onReceiveBettingOrder");			
			if (bettingOrderLocked) {
				DebugView.addText("   Betting order already established. Ignoring.");	
				//already established in previous round
				return;
			}
			_players = new Vector.<IPokerPlayerInfo>();
			DebugView.addText("   Betting order established ->");
			for (var count:int = 0; count < peerIDList.length; count++) {
				var currentPeerID:String = peerIDList[count] as String;
				var ncMember:INetCliqueMember = findMemberByID(currentPeerID);
				if (ncMember != null) {
					var playerInfoObj:PokerPlayerInfo = new PokerPlayerInfo(ncMember);
					if (count == 0) {
						playerInfoObj.isSmallBlind = true;
						DebugView.addText("   #0-Small blind peer: " + playerInfoObj.netCliqueInfo.peerID);						
					} else if (count == 1) {
						playerInfoObj.isBigBlind = true;						
						DebugView.addText("   #1-Big blind peer: " + playerInfoObj.netCliqueInfo.peerID);						
					} else {
						DebugView.addText("   #" + count + "-Player peer: " + playerInfoObj.netCliqueInfo.peerID);						
					}
					if (game.clique.localPeerInfo.peerID == playerInfoObj.netCliqueInfo.peerID) {
						DebugView.addText("      (self)");
					}
					_players.push(playerInfoObj);
				}
			}
			DebugView.addText("   Dealer peer: " + playerInfoObj.netCliqueInfo.peerID);
			_players[_players.length - 1].isDealer = true; //last entry is always dealer, may also be big blind			
			lockBettingOrder();
			game.dispatchStatusEvent(PokerGameStatusEvent.DEALER_NEW_BETTING_ORDER, this, {bettingModule:this});
		}
		
		/**
		 * Update player roles of the established betting order based on a member ID that is about to be removed.
		 * 
		 * @param	removedPlayer The peer ID of the player about to be removed.
		 */
		private function updatePlayerRoles(removedPeerID:String):void {			
			DebugView.addText("PokerBettingModule.updatePlayerRoles");
			var removedPlayer:IPokerPlayerInfo = null;
			var removedPlayerIndex:int = 0;
			if (_players.length < 3) {
				DebugView.addText ("   Not enough players to update!");
				return;
			}
			if (currentBettingPlayer == null) {
				DebugView.addText ("   No current betting player!");
				return;
			}
			if (selfPlayerInfo != null) {
				DebugView.addText ("   > My peer ID: "+selfPlayerInfo.netCliqueInfo.peerID);	
			}
			var _prunedPlayers:Vector.<IPokerPlayerInfo> = new Vector.<IPokerPlayerInfo>();
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				if (currentPlayer.netCliqueInfo.peerID != removedPeerID) {
					_prunedPlayers.push(currentPlayer);
				}
			}
			//removed player must still exist in _players
			for (count = 0; count < _players.length; count++) {
				currentPlayer = _players[count];
				if (currentPlayer.netCliqueInfo.peerID == removedPeerID) {
					removedPlayerIndex = count;
					removedPlayer = currentPlayer;
					break;
				}
			}
			var originalBOLocked:Boolean = _bettingOrderLocked;
			_bettingOrderLocked = false;
			if (currentBettingPlayer.netCliqueInfo.peerID == removedPlayer.netCliqueInfo.peerID) {
				var nextPlayerIndex:int = removedPlayerIndex % _prunedPlayers.length;
				var nextPlayer:IPokerPlayerInfo = _prunedPlayers[nextPlayerIndex];
				_currentBettingPlayer = nextPlayer;
				DebugView.addText ("   Current betting peer is now: " + _currentBettingPlayer.netCliqueInfo.peerID);
			}
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BETTING_PLAYER);
			event.sourcePlayer = _currentBettingPlayer;
			this.dispatchEvent(event);
			if (removedPlayer.isBigBlind) {
				//removed player index should be the next player index in the pruned player list
				nextPlayerIndex = removedPlayerIndex % _prunedPlayers.length;
				nextPlayer = _prunedPlayers[nextPlayerIndex];
				DebugView.addText ("   New big blind peer: " + nextPlayer.netCliqueInfo.peerID);
				setBigBlind(nextPlayer.netCliqueInfo, true);
			}
			if (removedPlayer.isSmallBlind) {
				nextPlayerIndex = (removedPlayerIndex + 1) % _prunedPlayers.length;
				nextPlayer = _prunedPlayers[nextPlayerIndex];
				var bigBlindIndex:int = removedPlayerIndex % _prunedPlayers.length;
				var bigBlindPlayer:IPokerPlayerInfo = _prunedPlayers[bigBlindIndex];
				setBigBlind(bigBlindPlayer.netCliqueInfo, false);				
				DebugView.addText ("   New small blind peer: " + bigBlindPlayer.netCliqueInfo.peerID);
				DebugView.addText ("   New big blind peer: " + nextPlayer.netCliqueInfo.peerID);
				setSmallBlind(bigBlindPlayer.netCliqueInfo, true);
				setBigBlind(nextPlayer.netCliqueInfo, true);
			}
			if (removedPlayer.isDealer) {				
				nextPlayerIndex = (removedPlayerIndex + 2) % _prunedPlayers.length;
				nextPlayer = _prunedPlayers[nextPlayerIndex];
				bigBlindIndex = (removedPlayerIndex + 1) % _prunedPlayers.length;
				bigBlindPlayer = _prunedPlayers[bigBlindIndex];
				var smallBlindIndex:int = removedPlayerIndex % _prunedPlayers.length;
				var smallBlindPlayer:IPokerPlayerInfo = _prunedPlayers[smallBlindIndex];
				setBigBlind(bigBlindPlayer.netCliqueInfo, false);
				setSmallBlind(smallBlindPlayer.netCliqueInfo, false);
				DebugView.addText ("   New dealer peer: " + smallBlindPlayer.netCliqueInfo.peerID);
				DebugView.addText ("   New small blind peer: " + bigBlindPlayer.netCliqueInfo.peerID);
				DebugView.addText ("   New big blind peer: " + nextPlayer.netCliqueInfo.peerID);
				setDealer(smallBlindPlayer.netCliqueInfo, true);
				setSmallBlind(bigBlindPlayer.netCliqueInfo, true);
				setBigBlind(nextPlayer.netCliqueInfo, true);
			}
			_bettingOrderLocked = originalBOLocked;
		}
		
		/**
		 * Search for a clique member by their peer ID.
		 * 
		 * @param	peerID The peer ID to search for.
		 * @param	includeSelf Should the search include the local player (self)?
		 * 
		 * @return The INetCliqueMember implementation that matches the peer ID or null if none found.
		 */
		private function findMemberByID(peerID:String, includeSelf:Boolean = true):INetCliqueMember {
			//var peers:Vector.<INetCliqueMember> = game.clique.connectedPeers;			
			var peers:Vector.<INetCliqueMember> = game.table.connectedPeers;
			for (var count:int = 0; count < peers.length; count++) {
				var currentPeer:INetCliqueMember = peers[count];
				if (currentPeer!=null) {
					if (currentPeer.peerID == peerID) {
						return (currentPeer);
					}
				}
			}
			if (peerID == game.clique.localPeerInfo.peerID) {
				return (game.clique.localPeerInfo);//
			}
			return (null);
		}		
	
		/**
		 * Verifies that the supplied betting message has been correctly signed and that all supplied values are correct.
		 * 
		 * @param	msg A PokerBettingMessage object, usually from an external senser.
		 * 
		 * @return True if the message can be fully verified, false if there was a problem.
		 */
		private function verifySignedBet(msg:PokerBettingMessage):Boolean {
			DebugView.addText("PokerBettingModule.verifySignedBet");
			if (msg == null) {
				DebugView.addText("   No message provided.");
				return (false);
			}
			if (msg.data == null) {
				DebugView.addText("   Message has no payload data.");
				return (false);
			}			
			if (msg.value == Number.POSITIVE_INFINITY) {
				DebugView.addText("   Message has no value property.");
				return (false);
			}
			if (msg.data.ethTransaction == null) {
				DebugView.addText("   Ethereum transaction not included in payload data.");
				return (false);
			}			
			//message should have the format: "B:BET_VALUE:NONCE" where BET_VALUE should match the msg.value property, converted to wei, included in the message
			var messageSplit:Array = String(msg.data.ethTransaction.message).split(":");
			if (messageSplit[0] != EthereumMessagePrefix.BET) {
				DebugView.addText("   Message is not a betting message.");
				return (false);
			}
			//msg.value is in Ether
			var weiValue:String = String(game.ethereum.web3.toWei(String(msg.value), "ether"));			
			if (String(messageSplit[1]) != weiValue) {
				DebugView.addText("   Message value doesn't match supplied bet value.");
				DebugView.addText("      Supplied bet value (wei): " + weiValue);
				DebugView.addText("      Message bet value (wei): " + String(messageSplit[1]));
				return (false);
			}
			if (game.activeSmartContract.verifySignedTransaction(msg.data.ethTransaction, this.toEthereumAccounts(this.nonFoldedPlayers))) {				
				return (true);
			}
			return (false);
		}
		
		/**
		 * Waits a valid bet by a preceding player to appear in the Ethereum smart contract. Once the value becomes available betting is re-enabled.
		 */
		private function waitForContractBet(sourceMsg:IPeerMessage):void {
			DebugView.addText("PokerBettingModule.waitForContractBet");
			//TODO: implement contract check; when complete, update sourceMsg and call the following:
			/*
			setExternalPlayerBet(peerMsg);						
			updateTablePot(peerMsg.value);
			updateTableBet();							
			_currentBettingPlayer = nextBettingPlayer(peerMessage.getSourcePeerIDList());							
			if (_currentBettingPlayer!=null) {
				DebugView.addText("   Peer now has betting control: " + _currentBettingPlayer.netCliqueInfo.peerID);
			} else {
				//betting order hasn't been determined yet so this message is probably out of order
				DebugView.addText("   Current betting peer can't be determined!");
			}
			updateGamePhase(peerMsg);			
			*/			
		}
		
		/**
		 * All game results, player keys, etc. have been received and game is fully completed.
		 * Method may only be invoked once per round (some asynchronous messages may still be received
		 * after a round).
		 */
		private function onRoundComplete():void {
			if (_roundComplete) {
				return;
			}
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BETTING_DISABLE);
			dispatchEvent(event);			
			_roundComplete = true;	
			event = new PokerBettingEvent(PokerBettingEvent.ROUND_DONE);
			dispatchEvent(event);
		}
				
		
		/**
		 * Resets the betting flags for all players so that new betting can begin.
		 * 
		 * @param	endOfRound If true, all player flags are cleared for a new round (usually also when the game phase is reset).
		 */
		private function resetAllPlayersBettingFlags(endOfRound:Boolean=false):void {			
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				currentPlayer.lastBet = Number.NEGATIVE_INFINITY;
				if (endOfRound) {
					currentPlayer.hasFolded = false;					
					currentPlayer.lastResultHand =  null;
					currentPlayer.totalBet = Number.NEGATIVE_INFINITY;
					currentPlayer.numBets = 0;
					_currentBettingPlayer = null;
				}
			}
		}

		/**
		 * Event listener invoked when new community cards have been decrypted.
		 * 
		 * @param	eventObj A poker game status event dispatched from the central status dispatcher.
		 */
		private function onNewCommunityCards(eventObj:PokerGameStatusEvent):void {			
			if (currentDealerMember.peerID == game.clique.localPeerInfo.peerID) {
				_bettingResumeMsg = null;
			}			
		}
		
		/**
		 * Resumes or continues betting if _bettingResumeMsg has been set.		 
		 */
		private function resumeBetting():void {
			if (_bettingResumeMsg == null) {				
				return;
			}			
			var phasesNode:XML = game.settings["getSettingsCategory"]("gamephases");
			var phases:Number = Number(phasesNode.children().length());
			if (game.gamePhase <= phases) {				
				onNextPlayerBet(_bettingResumeMsg.getSourcePeerIDList());				
			} else {				
				DebugView.addText("   *******************************************");
				DebugView.addText("   All betting rounds completed - GAME IS DONE");
				DebugView.addText("   *******************************************");
				disablePlayerBetting();
				onFinalBet();
			}
			_bettingResumeMsg = null;
		}
		
		/**
		 * Updates the game phase based on the current game status and incoming peer message.
		 * 
		 * @param	peerMsg A peer message, usually incoming, to include in the evaluation.
		 * 
		 * @return True if the phase was updated (game phase incremented).
		 */
		private function updateGamePhase(peerMsg:IPeerMessage):Boolean {		
			if (_roundComplete) {
				return (false);
			}
			DebugView.addText("PokerBettingModule.updateGamePhase");
			if (nonFoldedPlayers.length < 2){
				//all but one players have folded				
				disablePlayerBetting();
				onFinalBet();
				onRoundComplete();				
				return (false);
			}			
			var phaseChanged:Boolean = false;
			var phasesNode:XML = game.settings["getSettingsCategory"]("gamephases");
			var phases:Number = Number(phasesNode.children().length());
			DebugView.addText("   Number of phases: " + phases);			
			if (bettingComplete) {				
				game.gamePhase++;
				//this._updateSCBPAfterNextBet = true;
				this._smartContractBettingPhase++;
				resetAllPlayersBettingFlags(false);
				updateTableBet();
				phaseChanged = true;
				dispatchEvent(new PokerBettingEvent(PokerBettingEvent.BETTING_DONE));
			}
			DebugView.addText("    updateGamePhase.phaseChanged=" + phaseChanged);
			//check to see if any new community cards need to be dealt now
			var currentPhaseNode:XML = phasesNode.children()[game.gamePhase] as XML;
			try {
				var cardsToDeal:Number = Number(currentPhaseNode.communitycards);
				if (isNaN(cardsToDeal)) {
					cardsToDeal = 0;
				}
			} catch (err:*) {
				cardsToDeal = 0;
			}
			DebugView.addText("Current phase: " + game.gamePhase);			
			_bettingResumeMsg = peerMsg;			
			/*
			 * resume betting immediately if no more cards are currently left to deal otherwise
			 * wait for next cards before continuing betting
			 */
			if ((cardsToDeal == 0) || (phaseChanged == false)) {
				resumeBetting();
			}
			return (phaseChanged);
		}
		
		/**
		 * Marks a specific player as having folded.
		 * 
		 * @param	peerID The peer ID of the player that has folded; may be the local player (self).
		 */
		private function onPlayerFold(peerID:String):void {
			DebugView.addText("PokerBettingModule.onPlayerFold: " + peerID);
			var truncatedPeerID:String = peerID.substr(0, 15) + "...";
		//	new PokerGameStatusReport("Peer " + truncatedPeerID + " has folded.").report();
			var ncMember:INetCliqueMember = findMemberByID(peerID, true);
			if (ncMember != null) {
				var playerInfo:IPokerPlayerInfo = getPlayerInfo(ncMember);				
				if (playerInfo != null) {
					playerInfo.hasFolded = true;										
					DebugView.addText("   Player \"" + ncMember.peerID + "\" has folded");					
				} else {
					DebugView.addText("   Error: playerInfo is null for peer \""+ncMember.peerID+"\"");
				}
				var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BET_FOLD);
				event.sourcePlayer = playerInfo;
				this.dispatchEvent(event);
			} else {
				DebugView.addText("   Error: NetCliqueMember implementation not found by peer ID \""+peerID+"\"");
			}
		}
		
		/**
		 * DEFERRED
		 * 
		 * Handler for PokerBettingMessage.DEALER_SET_BLINDS event. Data may be transformed, if necessary,
		 * before the blinds are updated.
		 * 
		 * @param	blindsData An object containing the Numbers "smallBlind" and "bigBlind".
		 */
		private function onDealerSetBlinds(blindsData:Object):void {
			DebugView.addText("PokerBettingModule.onDealerSetBlinds");			
			return;
			//do we need to adjust blinds values based on all players' maximum balances?
			if ((maximumTableBet < blindsData.bigBlind) && (maximumTableBet != Number.NEGATIVE_INFINITY)) {				
				smallBlind = maximumTableBet / 2;
				bigBlind = maximumTableBet;
				DebugView.addText("   Setting big blind value (max. adjusted): " + bigBlind);
				DebugView.addText("   Setting small blind value (max. adjusted): "+smallBlind);				
			} else {
				smallBlind = blindsData.smallBlind;
				bigBlind = blindsData.bigBlind;
				DebugView.addText("   Setting big blind value: " + bigBlind);
				DebugView.addText("   Setting small blid value: "+smallBlind);				
			}
		}
		
		/**
		 * The current table bet as established by the last highest betting player.
		 */
		public function get currentTableBet():Number {
			var highestValue:Number = 0;			
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				if (currentPlayer.lastBet > highestValue) {
					highestValue = currentPlayer.lastBet;
				}
			}
			highestValue = _currencyFormat.roundToFormat(highestValue, _bettingSettings.currencyFormat);
			return (highestValue);
		}
		
		/**
		 * The current table bet as established by the highest total player bet value.
		 */
		public function get largestTableBet():Number {
			var highestValue:Number = 0;			
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				if (currentPlayer.totalBet > highestValue) {
					highestValue = currentPlayer.totalBet;
				}
			}
			highestValue = _currencyFormat.roundToFormat(highestValue, _bettingSettings.currencyFormat);
			return (highestValue);
		}		
		
		/**
		 * Enables the player betting UI. Button visibility is dependent on current bets and other
		 * conditions.
		 */
		public function enablePlayerBetting():void	{
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BETTING_ENABLE);
			event.minimumAmount = _startingPlayerBet;
			event.maximumAmount = maximumTableBet;
			event.amount = _currentPlayerBet;
			event.sourcePlayer = this.selfPlayerInfo;
			this.dispatchEvent(event);
			/*
			var enableDecrementButtons:Boolean = false;
			try {
				foldButton.disabled = false;
				foldButton.show();
			} catch (err:*) {				
			}			
			try {
				if (_currentPlayerBet <= _startingPlayerBet) {
					betButton.show();
					raiseButton.hide();
					callButton.hide();
					betButton.disabled = false;
					enableDecrementButtons = false;
				} else {
					betButton.hide();
				}
			} catch (err:*) {				
			}			
			try {
				if (_currentPlayerBet > _startingPlayerBet) {
					if ((_startingPlayerBet == 0) && (bigBlindIsMe)) {
						betButton.show();
						raiseButton.hide();
						callButton.hide();
						betButton.disabled = false;
						enableDecrementButtons = false;
					} else {
						raiseButton.show();
						betButton.hide();
						callButton.hide();
						raiseButton.disabled = false;
					}
					enableDecrementButtons = true;
				} else {
					raiseButton.hide();
				}
			} catch (err:*) {				
			}
			try {
				if (_currentPlayerBet == 0) {
					callButton.show();
					raiseButton.hide();
					betButton.hide();
					callButton.disabled = false;
					enableDecrementButtons = false;
				} else {
					callButton.hide();
				}
			} catch (err:*) {
			}
			var enableIncrementButtons:Boolean = false;			
			if (_currentPlayerBet < maximumTableBet) {
				enableIncrementButtons = true;
			}
			try {
				incLargeButton.show();	
				if (enableIncrementButtons) {
					incLargeButton.disabled = false;					
				} else {
					incLargeButton.disabled = true;					
				}
			} catch (err:*) {
			}
			try {
				incSmallButton.show();				
				if (enableIncrementButtons) {
					incSmallButton.disabled = false;					
				} else {
					incSmallButton.disabled = true;					
				}
			} catch (err:*) {				
			}
			try {
				decLargeButton.show();
				if (enableDecrementButtons) {
					decLargeButton.disabled = false;
				} else {
					decLargeButton.disabled = true;
				}
			} catch (err:*) {
			}
			try {
				decSmallButton.show();
				if (enableDecrementButtons) {
					decSmallButton.disabled = false;
				} else {
					decSmallButton.disabled = true;
				}
			} catch (err:*) {
			}
			*/
		}
		
		/**
		 * Diables the player betting UI by hiding all elements.
		 */
		public function disablePlayerBetting():void {	
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BETTING_DISABLE);
			event.sourcePlayer = this.selfPlayerInfo;
			this.dispatchEvent(event);
			/*
			try {
				betButton.hide();
			} catch (err:*) {				
			}
			try {
				raiseButton.hide();
			} catch (err:*) {				
			}
			try {
				foldButton.hide();
			} catch (err:*) {				
			}
			try {
				callButton.hide();
			} catch (err:*) {				
			}
			try {
				incLargeButton.hide();
			} catch (err:*) {				
			}
			try {
				incSmallButton.hide();
			} catch (err:*) {				
			}
			try {
				decLargeButton.hide();
			} catch (err:*) {				
			}
			try {
				decSmallButton.hide();
			} catch (err:*) {				
			}
			*/
		}
		
		/**
		 * The main handler for starting the "next" player betting action (control has just been passed from previous player).
		 * 
		 * @param	sourcePeers An ordered list of peers as received.
		 */
		private function onNextPlayerBet(sourcePeers:Vector.<INetCliqueMember>):void {
			DebugView.addText("PokerBettingModule.onNextPlayerBet");			
			if (selfPlayerInfo == null) {
				//in spectator mode
				return;
			}
			if (selfPlayerInfo.totalBet!=Number.NEGATIVE_INFINITY) {
				_currentPlayerBet = selfPlayerInfo.totalBet;
			}			
			if (!currentBettingPlayerIsMe(sourcePeers)) {
				var truncatedPeerID:String = nextBettingPlayer(sourcePeers).netCliqueInfo.peerID.substr(0, 15) + "...";			
				var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BETTING_PLAYER);
				event.sourcePlayer = nextBettingPlayer(sourcePeers);
				this.dispatchEvent(event);
				DebugView.addText("   I am not the next betting player according to dealer betting order so ignoring.");
				return;
			}			
			DebugView.addText("   I am the next betting player according to dealer betting order.");
			_currentBettingPlayer = selfPlayerInfo;
			event = new PokerBettingEvent(PokerBettingEvent.BETTING_PLAYER);
			event.sourcePlayer = _currentBettingPlayer;
			this.dispatchEvent(event);
			var diffValue:Number = largestTableBet - _currentPlayerBet;	
			diffValue = _currencyFormat.roundToFormat(diffValue, _bettingSettings.currencyFormat);			
			if ((maximumTableBet == 0) && (diffValue == 0)) {
				//a player has gone all-in and all players have matched the bet
				DebugView.addText("   Maximum table bet is 0 so auto-commiting bet of 0.");
				updatePlayerBet(0, true);
				_startingPlayerBet = 0;
				commitCurrentBet();
				return;
			}			
			if (smallBlindIsMe) {
				DebugView.addText("   I am the small blind.");
				DebugView.addText("   Have all players bet? "+allPlayersHaveBet)
				if (!allPlayersHaveBet) {					
					updatePlayerBet(_smallBlind, true);
					_startingPlayerBet = _smallBlind;
					commitCurrentBet();
					return;
				} else {					
					updatePlayerBet(diffValue);
					_startingPlayerBet = diffValue;
					enablePlayerBetting();
					return;
				}
			} else if (bigBlindIsMe) {
				DebugView.addText("   I am the big blind.");
				if (selfPlayerInfo.numBets == 1) {					
					updatePlayerBet(diffValue);
					_startingPlayerBet = diffValue;
					enablePlayerBetting();							
					return;
				}
				if (!dealerIsMe) {
					DebugView.addText("   I am not the dealer.");
					if (!playerCanCheck) {
						DebugView.addText("   I can't check / call.");						
						if (allPlayersHaveBet) {
							updatePlayerBet(diffValue);
							_startingPlayerBet = diffValue;
							enablePlayerBetting();							
							return;
						} else {
							updatePlayerBet(_bigBlind, true);
							_startingPlayerBet = _bigBlind;
							commitCurrentBet();
							return;
						}
						return;
					} else {
						DebugView.addText("   I can check / call.");
						DebugView.addText("   Have all players bet? " + allPlayersHaveBet);
						if (allPlayersHaveBet) {
							updatePlayerBet(diffValue);
							_startingPlayerBet = diffValue;
							enablePlayerBetting();							
							return;
						} else {
							updatePlayerBet(_bigBlind, true);
							_startingPlayerBet = _bigBlind;
							commitCurrentBet();							
							return;
						}
					}
				} else {					
					DebugView.addText("   I am also the dealer.");
					if (allPlayersHaveBet) {						
						updatePlayerBet(diffValue);
						_startingPlayerBet = diffValue;
						enablePlayerBetting();							
						return;
					} else {						
						updatePlayerBet(_bigBlind, true);
						_startingPlayerBet = _bigBlind;
						commitCurrentBet();
					}
					return;					
				}				
			} else if (dealerIsMe) {				
				DebugView.addText("   I am the dealer.");
				updatePlayerBet(diffValue);
				_startingPlayerBet = diffValue;
				enablePlayerBetting();				
			} else {
				DebugView.addText("   I am a standard player (non-dealer, non-blind).");
				updatePlayerBet(diffValue);
				_startingPlayerBet = diffValue;
				enablePlayerBetting();
			}			
		}
		
		/**
		 * Returns the next betting player based on a supplied list of source peers of a betting completed message.
		 * This function may also be used to query the next player for a specific peer.
		 * 
		 * @param	sourcePeers The ordered source member list of a betting completed peer message. Only the 
		 * peer at index 0 (most recent) is considered.
		 * 
		 * @return The next player based on the supplied source peer list or null if the next player can't be determined.
		 */
		public function nextBettingPlayer(sourcePeers:Vector.<INetCliqueMember>):IPokerPlayerInfo {			
			if (sourcePeers == null) {
				return (null);
			}
			if (sourcePeers.length == 0) {
				return (null);
			}
			if (_players == null) {				
				return (null);
			}
			if (_players.length == 0) {
				return (null);
			}
			var previousPlayer:IPokerPlayerInfo = getPlayerInfo(sourcePeers[0]);
			if (previousPlayer == null) {				
				return (null);
			}
			var nextPlayerIndex:int = 0;
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				if (currentPlayer.netCliqueInfo.peerID==previousPlayer.netCliqueInfo.peerID) {
					nextPlayerIndex = (count + 1) % _players.length;
					return (_players[nextPlayerIndex]);					
				}
			}
			//this shouldn't happen; throw an error here?			
			return (null);
		}
	
		/**
		 * Verifies if the local player (self) is the next betting player according to the dealer betting order and
		 * (usually) received peer list.
		 * 
		 * @param	sourcePeers The ordered source member list of the peer message 
		 * 
		 * @return True is the next betting player is me.
		 */
		private function currentBettingPlayerIsMe(sourcePeers:Vector.<INetCliqueMember>):Boolean {			
			if (sourcePeers == null) {
				return (false);
			}
			if (sourcePeers.length == 0) {
				return (false);
			}
			if (_players == null) {
				return (false);
			}
			var indexVal:int;
			//first find source peer index
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				if (currentPlayer.netCliqueInfo.peerID == sourcePeers[0].peerID) {					
					indexVal = count;
					break;
				}
			}
			var startIndex:int = indexVal;			
			//then find previous peer based on supplied peer ID
			while (true) {
				indexVal++;
				if (indexVal >= _players.length) {
					indexVal = 0;
				}
				if (indexVal == startIndex) {
					//back where we started
					return (false);
				}
				currentPlayer = _players[indexVal];
				//skip folded players
				if (currentPlayer.hasFolded==false) {
					if (currentPlayer.netCliqueInfo.peerID == game.clique.localPeerInfo.peerID) {						
						return (true);
					} else {						
						return (false);
					}
				}
			}
			return (false);
		}
		
		/**		 
		 * @return True if the local player's (self's) bet is larger than or equal to all other player's current bets. 
		 * This indicates that the player may bet 0 (check or call).
		 */
		public function get playerCanCheck():Boolean {
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];				
				if (selfPlayerInfo.totalBet < currentPlayer.totalBet) {
					return (false);
				}
			}
			return (true);
		}
		
		/**
		 * @return True if all players have placed an initial bet during the current round.
		 */
		public function get allPlayersHaveBet():Boolean {
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];				
				if ((!currentPlayer.hasBet) && (!currentPlayer.hasFolded)) {
					return (false);
				}				
			}
			return (true);
		}
		
		/**
		 * @return True if the local player (self) is flagged as the current small blind.
		 */
		public function get smallBlindIsMe():Boolean {
			if (currentSmallBlindMember.peerID == game.clique.localPeerInfo.peerID) {
				return (true);
			}
			return (false);
		}
		
		/**
		 * @return True if the local player (self) is flagged as the current big blind.
		 */
		public function get bigBlindIsMe():Boolean {
			if (currentBigBlindMember.peerID == game.clique.localPeerInfo.peerID) {
				return (true);
			}
			return (false);
		}
		
		/**
		 * @return True if the local player (me) is currently flagged as the dealer according to the lounge.
		 */
		public function get dealerIsMe():Boolean {
			return (game.table.dealerIsMe);
			//return (game.lounge.leaderIsMe);
		}
		
		/**
		 * Handler for PokerBettingMessage.PLAYER_UPDATE_BET event. Typically this will update the associated player's
		 * bet in the user interface.
		 * 
		 * @param	peerMsg The PokerBettingMessage containing a value property for the associated player.
		 */
		private function updateExternalPlayerBet(peerMsg:PokerBettingMessage):void {
			DebugView.addText("PokerBettingModule.updateExternalPlayerBet");
			DebugView.addText("   Peer ID: " + peerMsg.getSourcePeerIDList()[0].peerID);
			DebugView.addText("   Player has bet: " + peerMsg.value);
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BET_UPDATE);
			event.amount =  Number(peerMsg.value);
			event.denom = _bettingSettings.currencyUnits;
			event.sourcePlayer = this.getPlayerInfo(peerMsg.getSourcePeerIDList()[0]);
			this.dispatchEvent(event);
		}
		
		/**
		 * Handler for PokerBettingMessage.PLAYER_SET_BET event. This will update the associated player's bet by
		 * adding the new bet to their existing bet.
		 * 
		 * @param	peerMsg The PokerBettingMessage containing a new bet value for the associated player.
		 */
		private function setExternalPlayerBet(peerMsg:PokerBettingMessage):void {
			peerMsg.value = _currencyFormat.roundToFormat(peerMsg.value, _bettingSettings.currencyFormat);
			DebugView.addText("PokerBettingModule.updateExternalPlayerBet: " + peerMsg.value);
			var truncatedPeerID:String = peerMsg.getSourcePeerIDList()[0].peerID.substr(0, 15) + "...";
			_currencyFormat.setValue(peerMsg.value);		
			var playerInfo:IPokerPlayerInfo = getPlayerInfo(peerMsg.getSourcePeerIDList()[0]);
			if (playerInfo.totalBet == Number.NEGATIVE_INFINITY) {
				playerInfo.totalBet = 0;
			}			
			playerInfo.totalBet += peerMsg.value;
			playerInfo.balance -= peerMsg.value;
			playerInfo.lastBet = peerMsg.value;
			playerInfo.totalBet = _currencyFormat.roundToFormat(playerInfo.totalBet, _bettingSettings.currencyFormat);
			playerInfo.balance = _currencyFormat.roundToFormat(playerInfo.balance, _bettingSettings.currencyFormat);
			playerInfo.lastBet = _currencyFormat.roundToFormat(playerInfo.lastBet, _bettingSettings.currencyFormat);
			playerInfo.numBets++;
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BET_COMMIT);
			event.amount = Number(peerMsg.value);
			event.denom = _bettingSettings.currencyUnits;
			event.sourcePlayer = playerInfo;
			this.dispatchEvent(event);
		}
		
		/**
		 * Updates the current table bet (the largest curent bet or raise).
		 */
		private function updateTableBet():void {
			DebugView.addText("PokerBettingModule.updateTableBet");
			var largestValue:Number = Number.NEGATIVE_INFINITY;			
			for (var count:int = 0; count < _players.length; count++) {				
				if (_players[count]!=null) {
					if (!_players[count].hasFolded) {						
						if (_players[count].lastBet > largestValue) {
							largestValue = _players[count].lastBet;
						}
					}
				}
			}
			if (largestValue == Number.NEGATIVE_INFINITY) {
				largestValue = 0;
			}
			if (_currencyFormat == null) {
				_currencyFormat = new CurrencyFormat(largestValue);
			} else {
				_currencyFormat.setValue(largestValue);
			}			
	//		DebugView.addText("   -> updated to: " + _currencyFormat.getString(_bettingSettings.currencyFormat));
		//	currentTableBetValue.text = "Current table bet: " + _currencyFormat.getString(_bettingSettings.currencyFormat);
		}
		
		/**
		 * Updates the current "table" pot (total of all players' bets).
		 * 
		 * @param	updateValue The new value to add to (or subtract from), the current table pot.
		 */
		private function updateTablePot(updateValue:Number):void {
			DebugView.addText("PokerBettingModule.updateTablePot: " + updateValue);					
			updateValue = _currencyFormat.roundToFormat(updateValue, _bettingSettings.currencyFormat);
			_communityPot += updateValue;
			_communityPot = _currencyFormat.roundToFormat(_communityPot, _bettingSettings.currencyFormat);
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.POT_UPDATE);
			event.amount = _communityPot;
			event.denom = _bettingSettings.currencyUnits;
			this.dispatchEvent(event);
		}
		
		/**
		 * Updates the local player's (self's) current non-committed bet value in the UI, optionally broadcasting the update to the clique.
		 * 
		 * @param	newBetValue The new bet value to update to.
		 * @param	updateOtherPlayers If true, broadcast the non-committed value to the clique.
		 */
		private function updatePlayerBet(newBetValue:Number, updateOtherPlayers:Boolean = true):void {			
			newBetValue = _currencyFormat.roundToFormat(newBetValue, _bettingSettings.currencyFormat);			
			_currencyFormat.setValue(newBetValue);			
			//betValue.text = _currencyFormat.getString(_bettingSettings.currencyFormat);			
			var newCurrencyFormat:CurrencyFormat = new CurrencyFormat();			
			newCurrencyFormat.setValue(selfPlayerInfo.balance);						
			//betValue.appendText(" of " + newCurrencyFormat.getString(_bettingSettings.currencyFormat));			
			_currentPlayerBet = newBetValue;
			_currentPlayerBet = _currencyFormat.roundToFormat(_currentPlayerBet, _bettingSettings.currencyFormat);
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BET_UPDATE);
			event.amount = _currentPlayerBet;
			event.denom = _bettingSettings.currencyUnits;
			event.sourcePlayer = this.selfPlayerInfo;
			this.dispatchEvent(event);
			if (updateOtherPlayers) {
				broadcastPlayerBetUpdate(_currentPlayerBet);
			}			
		}
		
		/**
		 * Commits the local player's (self's) bet. If the player is the dealer and all player bets are equal,
		 * a PokerBettingEvent.BETTING_DONE event is dispatched.
		 */
		private function commitCurrentBet():void {
			DebugView.addText("PokerBettingModule.commitCurrentBet: " + _currentPlayerBet);	
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BETTING_DISABLE);			
			event.sourcePlayer = this.selfPlayerInfo;
			this.dispatchEvent(event);
			if (selfPlayerInfo.totalBet == Number.NEGATIVE_INFINITY) {
				selfPlayerInfo.totalBet = 0;
			}
			selfPlayerInfo.lastBet = _currentPlayerBet;
			selfPlayerInfo.totalBet += _currentPlayerBet;
			selfPlayerInfo.balance -= _currentPlayerBet;
			selfPlayerInfo.lastBet = _currencyFormat.roundToFormat(selfPlayerInfo.lastBet, _bettingSettings.currencyFormat);
			selfPlayerInfo.totalBet = _currencyFormat.roundToFormat(selfPlayerInfo.totalBet, _bettingSettings.currencyFormat);
			selfPlayerInfo.balance = _currencyFormat.roundToFormat(selfPlayerInfo.balance, _bettingSettings.currencyFormat);
			selfPlayerInfo.numBets++;
			if ((game.ethereum != null) && (game.activeSmartContract != null)) {
				// begin smart contract deferred invocation: storeBet
				var betValueWei:String = game.ethereum.web3.toWei(_currentPlayerBet, "ether");			
				var deferDataObj1:Object = new Object();
				var contractBettingPhases:String = game.activeSmartContract.getDefault("bettingphases");			
				var phasesSplit:Array = contractBettingPhases.split(",");
				deferDataObj1.phases = phasesSplit[this._smartContractBettingPhase];
				deferDataObj1.account = "all"; //as specified in contract
				var defer1:SmartContractDeferState = new SmartContractDeferState(game.phaseDeferCheck, deferDataObj1, game, true);
				defer1.operationContract = game.activeSmartContract;
				var deferDataObj2:Object = new Object()
				var potValueWei:String = game.ethereum.web3.toWei(this.communityPot, "ether");
				deferDataObj2.pot = potValueWei;			
				var defer2:SmartContractDeferState = new SmartContractDeferState(game.potDeferCheck, deferDataObj2, game);
				defer2.operationContract = game.activeSmartContract;
				var deferDataObj3:Object = new Object();
				deferDataObj3.position = this.getBettingIndex(this.selfPlayerInfo);			
				var defer3:SmartContractDeferState = new SmartContractDeferState(game.betPositionDeferCheck, deferDataObj3, game, true);
				defer3.operationContract = game.activeSmartContract;
				var deferArray:Array = game.combineDeferStates(game.deferStates, [defer1, defer2, defer3]);			
				//game.activeSmartContract.storeBet(betValueWei).defer(deferArray).invoke({from:game.ethereumAccount, gas:150000});
				game.actionsContract.storeBet(game.activeSmartContract.address, betValueWei).defer(deferArray).invoke({from:game.ethereumAccount, gas:150000});
				// end smart contract deferred invocation: storeBet
			}
			updateTableBet();
			updateTablePot(_currentPlayerBet);
			broadcastPlayerBetSet(_currentPlayerBet);
			updatePlayerBet(_currentPlayerBet, false); //ensures that balance information is updated in UI
			var sourcePeers:Vector.<INetCliqueMember> = new Vector.<INetCliqueMember>();
			sourcePeers.push(game.clique.localPeerInfo);
			_currentBettingPlayer = nextBettingPlayer(sourcePeers);			
			var truncatedPeerID:String = _currentBettingPlayer.netCliqueInfo.peerID.substr(0, 15) + "...";			
			event = new PokerBettingEvent(PokerBettingEvent.BET_COMMIT);
			event.amount = _currentPlayerBet;
			event.denom = _bettingSettings.currencyUnits;
			event.sourcePlayer = this.selfPlayerInfo;
			this.dispatchEvent(event);
			event = new PokerBettingEvent(PokerBettingEvent.BETTING_PLAYER);
			event.sourcePlayer = _currentBettingPlayer;
			this.dispatchEvent(event);
			if (bettingComplete) {
				resetAllPlayersBettingFlags(false);
				this._smartContractBettingPhase++
				updateTableBet();				
				game.gamePhase++;
				dispatchEvent(new PokerBettingEvent(PokerBettingEvent.BETTING_DONE));				
			}
		}		
		
		/**
		 * Checks if an IPokerPlayerInfo implementation is contained in a list of IPokerPlayerInfo implementations.
		 * 
		 * @param	playerRef The implementation to check for the existence of.
		 * @param	playerList The list within which to search for playerRef.
		 * 
		 * @return True if the implementation appears in the list.
		 */
		private function playerIsInList(playerRef:IPokerPlayerInfo, playerList:Vector.<IPokerPlayerInfo>):Boolean {
			if ((playerRef == null) || (playerList == null)) {
				return (false);
			}
			for (var count:int = 0; count < playerList.length; count++) {
				var currentPlayer:IPokerPlayerInfo = playerList[count];
				if (currentPlayer == playerRef) {
					return (true);
				}
			}
			return (false);
		}
		
		public function get blindsTimer():GameTimer {
			return (currentSettings.currentTimer);
		}
		
		/**
		 * Handles blinds timer timer tick events and updates the user interface.
		 * 
		 * @param	eventObj Event dispatched from a GameTimer instance.
		 */
		private function onBlindsTimerTick(eventObj:GameTimerEvent):void {			
			var timerObj:GameTimer = GameTimer(eventObj.target);
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BLINDS_TIMER);						
			if (timerObj.totalSeconds <= 0) {
				timerObj.stopCountDown();				
			}
			event.blindsTime = timerObj.getTimeString(currentSettings.currentTimerFormat);
			this.dispatchEvent(event);
		}
		
		/**
		 * Handles blinds timer timer complete events.
		 * 
		 * @param	eventObj Event dispatched from a GameTimer instance.
		 */
		private function onBlindsTimerComplete(eventObj:GameTimerEvent):void {			
			DebugView.addText("PokerBettingModule.onBlindsTimerComplete"); 	
			currentSettings.currentTimer.removeEventListener(GameTimerEvent.COUNTDOWN_TICK, onBlindsTimerTick);
			currentSettings.currentTimer.removeEventListener(GameTimerEvent.COUNTDOWN_END, onBlindsTimerComplete);
			currentSettings.clearCurrentTimer();
			blindsTimerComplete();
		}
		
		/**
		 * Increments the settings level in the default PokerBettingSettings value.
		 */
		private function blindsTimerComplete():void {
			_bettingSettings.currentLevel++;
			startBlindsTimer();
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BETTING_NEW_BLINDS);
			this.dispatchEvent(event);
		}
		
		/**
		 * Broadcasts the current bet value to participating players.
		 * 
		 * @param	newValue Numeric base value (such as CurrencyFormat.getValue) to send
		 * to participating players. Value is usually sent as-is (toString) so that
		 * participants may correctly format the data locally.
		 */
		private function broadcastPlayerBetUpdate(newValue:Number):void {
			var newMessage:PokerBettingMessage = new PokerBettingMessage();
			newMessage.createBettingMessage(PokerBettingMessage.PLAYER_UPDATE_BET, newValue);			
			game.clique.broadcast(newMessage);
		}
		
		/**
		 * Broadcasts the set (commited) bet value to participating players.
		 * 
		 * @param	newValue Numeric base value (such as CurrencyFormat.getValue) to send
		 * to participating players. Value is usually sent as-is (toString) so that
		 * participants may correctly format the data locally.
		 */
		private function broadcastPlayerBetSet(newValue:Number):void {
			DebugView.addText("PokerBettingModule.broadcastPlayerBetSet: " + newValue);
			var newMessage:PokerBettingMessage = new PokerBettingMessage();
			var payload:Object = new Object();
			//convert to Wei from Ether before sending			
			payload.ethTransaction = new Object();			
			if ((game.ethereum != null) && (game.activeSmartContract != null) && (game.txSigningEnabled)) {
				payload.value = game.ethereum.web3.toWei(String(newValue), "ether");	
				payload.ethTransaction = game.ethereum.sign([EthereumMessagePrefix.BET, String(payload.value)]);
				DebugView.addText("   Betting transaction to broadcast:");
				DebugView.addText("      message => " + payload.ethTransaction.message);
				DebugView.addText("      account => " + payload.ethTransaction.account);				
				DebugView.addText("      nonce => " + payload.ethTransaction.nonce);				
				DebugView.addText("      hash => " + payload.ethTransaction.hash);				
				DebugView.addText("      signature => " + payload.ethTransaction.signature);
			}
			newMessage.createBettingMessage(PokerBettingMessage.PLAYER_SET_BET, newValue, payload);			
			game.clique.broadcast(newMessage);			
		}
	}
}
/**
* Manages player betting, game progression, and game status for an initialized PokerCardGame instance. The betting
* module's logic is modelled after a typical Texas Hold'em poker game.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package  
{
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
	import crypto.interfaces.ISRAKey;
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.display.Bitmap;
	import flash.display.Loader;
	import flash.filters.GlowFilter;	
	import flash.text.TextField;
	import org.cg.GameTimer;
	import PokerBettingSettings;
	import PokerCardGame;
	import org.cg.ViewManager;
	import org.cg.CurrencyFormat;	
	import org.cg.DebugView;
	import org.cg.ImageButton;
	import flash.utils.setTimeout;
	
	dynamic public class PokerBettingModule extends MovieClip implements IPokerBettingModule {
		
		private var _game:PokerCardGame = null; //Reference to the parent PokerCardGame instance.
		/**
		 * Usually we will use _bettingSettings[0] to access the default PokerBettingSettings reference but others
		 * may be available in future revisions.
		 */
		private var _bettingSettings:Vector.<PokerBettingSettings> = new Vector.<PokerBettingSettings>();
		/**
		 * The current local player bet for the current beting action. This is different than the local player's totalBet 
		 * value in the _players vector which is the total bet for the game.
		 */
		private var _currentPlayerBet:Number = new Number(0);
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
		private var _currencyFormat:CurrencyFormat = new CurrencyFormat(); //formats base numeric values to a se;ected currency
		private var _lastHighestHand:IPokerHand = null; //the last highest hand for the player, usually created at the end of a round
		/**
		 * An ordered list of players in their betting order, as established by the dealer.
		 */
		private var _players:Vector.<IPokerPlayerInfo> = new Vector.<IPokerPlayerInfo>();		
		public var betValue:TextField; //used to display the current, formatted, local player bet value		
		public var blindsTimerValue:TextField; //used to display the formatted blinds timer
		public var currentTableBetValue:TextField; //used to display the current, formatted, table (highest) bet value
		public var currentTablePotValue:TextField; //used to display the total, formatted, pot value for the round
		
		public var betButton:ImageButton; //"Bet" button
		public var raiseButton:ImageButton; //"Raise" button
		public var callButton:ImageButton; //"Call" button
		public var foldButton:ImageButton; //"Fold" button
		public var incLargeButton:ImageButton; //Large increment button
		public var incSmallButton:ImageButton; //Small increment button
		public var decLargeButton:ImageButton; //Large decrement button
		public var decSmallButton:ImageButton; //Small decrement button
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	gameRef A reference to an initialized PokerCardGame instance.
		 */
		public function PokerBettingModule(gameRef:PokerCardGame) 
		{
			_game = gameRef;			
			_game.addChild(this);
		}		
		
		/**
		 * The current PokerBettingSettings reference being used.
		 */
		public function get currentSettings():PokerBettingSettings 
		{			
			return (_bettingSettings[0]);
		}
		
		/**
		 * @return A list, in dealer betting order, of all players who have not folded in this round.
		 */
		public function get nonFoldedPlayers():Vector.<IPokerPlayerInfo>
		{
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
		 * Returns a PokerPlayerInfo object for the local player (self).
		 */
		public function get selfPlayerInfo():IPokerPlayerInfo 
		{		
			if (_players == null) {								
				return (null);
			}
			var selfPeerID:String = game.lounge.clique.localPeerInfo.peerID;			
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
		 * @return A reference to the parent PokerCardGame instance.
		 */
		public function get game():PokerCardGame 
		{
			return (_game);
		}
		
		/**
		 * The next dealer (current small blind) according to the dealer betting order, or null
		 * if order hasn't been established.
		 */
		public function get nextDealer():IPokerPlayerInfo 
		{
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
		public function get communityPot():Number 
		{
			return (_communityPot);
		}
		
		/**
		 * @return True if the betting for the current deal is complete and the game phase may be updated; all non-folded
		 * players must have placed a bet and must have matched table bet (highest bet).
		 */
		public function get bettingComplete():Boolean 
		{
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
			}
			for (count = 0; count < nfPlayers.length; count++) {
				pokerPlayerInfo = nfPlayers[count];								
				if (pokerPlayerInfo.lastBet == Number.NEGATIVE_INFINITY) {					
					//not all players have bet or raised this round					
					return (false);
				}
			}
			var baseBet:Number = nfPlayers[0].totalBet;			
			for (count = 0; count < nfPlayers.length; count++) {
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
		public function get allPlayerBetsAreEqual():Boolean 
		{
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
		public function get balance():Number 
		{
			return (_balance);
		}
			
		/**
		 * @return The local player's (self's) current bet.
		 */
		public function get playerBet():Number 
		{
			return (_currentPlayerBet);
		}
		
		/**
		 * @return The INetCliqueMember implementation associated with the current dealer, or null if one can't be found.
		 */
		public function get currentDealerMember():INetCliqueMember 
		{			
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
		public function get currentBigBlindMember():INetCliqueMember 
		{
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
		public function get currentSmallBlindMember():INetCliqueMember 
		{
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayerInfo:IPokerPlayerInfo = _players[count];
				if (currentPlayerInfo.isSmallBlind) {
					return (currentPlayerInfo.netCliqueInfo);
				}
			}
			return (null);
		}
		
		/**
		 * @return The INetCliqueMember implementation associated with the current dealer, or null if one can't be found.
		 */
		public function get dealerIsSet():Boolean 
		{
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
		public function get bigBlindIsSet():Boolean 
		{
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
		public function get smallBlindIsSet():Boolean 
		{
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				if (currentPlayer.isSmallBlind) {
					return (true);
				}
			}
			return (false);
		}		
		
		/**
		 * Returns a PokerPlayerInfo object for the supplied NetCliqueMember, or null if none exists.
		 * 
		 * @param member The INetCliqueMember implementation to return an info object for.
		 */
		public function getPlayerInfo(member:INetCliqueMember):IPokerPlayerInfo 
		{
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
		 * @return True when all non-folded players have reported their crypto keys and hand analysis results. This value
		 * will be reset to false at the beginning of each round or when resetAllPlayersBettingFlags(true) is invoked.
		 */
		public function get allGameResultsReceived():Boolean 
		{
			var nfPlayers:Vector.<IPokerPlayerInfo> = nonFoldedPlayers;	
			if (nfPlayers.length == 1) {				
				return (true);
			}
			try {
				for (var count:int = 0; count < nfPlayers.length; count++) {
					if (nfPlayers[count].lastResultHand == null) {
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
		public function get winningPlayerInfo():IPokerPlayerInfo 
		{
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
		public function get bettingOrderLocked():Boolean 
		{
			return (_bettingOrderLocked);
		}		

		/**
		 * The current big small value (not player).
		 */
		public function set smallBlind(valueSet:Number):void 
		{
			_smallBlind = valueSet;			
		}
		
		public function get smallBlind():Number {
			return (_smallBlind);
		}
		
		/**
		 * The current big blind value (not player).
		 */
		public function set bigBlind(valueSet:Number):void 
		{			
			_bigBlind = valueSet;		
		}
		
		public function get bigBlind():Number 
		{
			return (_bigBlind);
		}	

		/**
		 * Initializes the new instance by resetting all values to default and rendering the default view
		 * for the module. This function should only be called once per game (before the first round).
		 */
		public function initialize():void 
		{			
			DebugView.addText("PokeBettingModule.initialize");
			try {
				var viewsCat:XML = game.settings["getSettingsCategory"]("views");
				var bettingModuleNode:XML = game.settings["getSetting"]("views", "bettingmodule");
				if (bettingModuleNode == null) {	
					return;
				}
				ViewManager.render(bettingModuleNode, this, onRenderView);				
				var gameTypeDefinitions:XML = game.settings["getSetting"]("defaults", "gametypes");
				var gameTypes:XMLList = gameTypeDefinitions.child("gametype") as XMLList;
				for (var count:int = 0; count < gameTypes.length(); count++) {
					var currentGameType:XML = gameTypes[count];
					if (currentGameType != null) {
						var newSettings:PokerBettingSettings = new PokerBettingSettings(currentGameType);
						if (newSettings.valid) {
							_bettingSettings.push(newSettings);
						}
					}
				}
			} catch (err:Error) {
				DebugView.addText (err.getStackTrace());
			}
		}
		
		/**
		 * Resets the betting module in preparation of a new round. All player betting flags are cleared, the user
		 * interface is reset, blinds are updated if necessary, and the betting module is fully enabled.
		 */
		public function reset():void 
		{
			resetAllPlayersBettingFlags(true);
			_roundComplete = false;
			_currentPlayerBet = new Number(0);
			_startingPlayerBet = new Number(0);
			_communityPot = new Number(0);
			updateTableBet();			
			disablePlayerBetting();
			smallBlind = _bettingSettings[0].currentLevelSmallBlind;;
			bigBlind = _bettingSettings[0].currentLevelBigBlind;
		}

		/**
		 * Disables the betting module by removing event listeners and disabling the user interface.
		 */
		public function disable():void 
		{			
			game.lounge.clique.removeEventListener(NetCliqueEvent.PEER_MSG, onReceivePeerMessage);
			disablePlayerBetting();
		}
		
		/**
		 * Enables the betting module by adding event listeners and optionally enable the user interface.
		 * 
		 * @param includeUI Should user interface also be enabled?
		 */
		public function enable(includeUI:Boolean=false):void 
		{
			disable(); //prevent double listeners
			game.lounge.clique.addEventListener(NetCliqueEvent.PEER_MSG, onReceivePeerMessage);
			enablePlayerBetting();
		}
		
		/**
		 * Invoked by the ViewManager when the betting module view is rendered.
		 */
		public function onRenderView():void 
		{
			keepOnTop();
			DebugView.addText ("PokerBettingModule.onRenderView");
			var filtersArr:Array = [new GlowFilter(0x000000, 1, 5, 5, 6, 1, false, false)];
			try {				
				betValue.text = _currencyFormat.getString(CurrencyFormat.default_format);				
				betValue.filters = filtersArr;
			} catch (err:*) {				
			}			
			try {				
				blindsTimerValue.filters = filtersArr;
			} catch (err:*) {
			}
			try {				
				currentTableBetValue.filters = filtersArr;
			} catch (err:*) {
			}
			try {				
				currentTablePotValue.filters = filtersArr;
			} catch (err:*) {
			}
			try {
				betButton.addEventListener(ImageButtonEvent.CLICKED, onBetButtonClick);				
			} catch (err:*) {					
			}
			try {
				raiseButton.addEventListener(ImageButtonEvent.CLICKED, onRaiseClick);				
			} catch (err:*) {					
			}
			try {
				callButton.addEventListener(ImageButtonEvent.CLICKED, onCallClick);				
			} catch (err:*) {					
			}
			try {
				foldButton.addEventListener(ImageButtonEvent.CLICKED, onFoldClick);				
			} catch (err:*) {					
			}			
			try {
				incLargeButton.addEventListener(ImageButtonEvent.CLICKED, onLargeIncrementClick);				
			} catch (err:*) {					
			}
			try {
				incSmallButton.addEventListener(ImageButtonEvent.CLICKED, onSmallIncrementClick);				
			} catch (err:*) {					
			}
			try {
				decLargeButton.addEventListener(ImageButtonEvent.CLICKED, onLargeDecrementClick);
			} catch (err:*) {					
			}
			try {
				decSmallButton.addEventListener(ImageButtonEvent.CLICKED, onSmallDecrementClick);				
			} catch (err:*) {					
			}			
			disablePlayerBetting();
			game.lounge.clique.removeEventListener(NetCliqueEvent.PEER_MSG, onReceivePeerMessage);
			game.lounge.clique.addEventListener(NetCliqueEvent.PEER_MSG, onReceivePeerMessage);
		}
		
		/**
		 * Handles click/tap events on the "Bet" button.
		 * 
		 * @param	eventObj An ImageButtonEvent.CLICKED event object.
		 */
		public function onBetButtonClick(eventObj:ImageButtonEvent):void 
		{
			DebugView.addText ("PokerBettingModule.onBetButtonClick");		
			disablePlayerBetting();
			stopKeepOnTop();
			commitCurrentBet();				
		}
		
		/**
		 * Handles click/tap events on the small increment button.
		 * 
		 * @param	eventObj An ImageButtonEvent.CLICKED event object.
		 */
		public function onSmallIncrementClick(eventObj:ImageButtonEvent):void 
		{
			var newValue:Number = _currentPlayerBet + 0.10;						
			updatePlayerBet(newValue, true);
			enablePlayerBetting();
		}
		
		/**
		 * Handles click/tap events on the large increment button.
		 * 
		 * @param	eventObj An ImageButtonEvent.CLICKED event object.
		 */
		public function onLargeIncrementClick(eventObj:ImageButtonEvent):void 
		{
			var newValue:Number = _currentPlayerBet + 1;			
			updatePlayerBet(newValue, true);
			enablePlayerBetting();
		}
		
		/**
		 * Handles click/tap events on the small decrement button.
		 * 
		 * @param	eventObj An ImageButtonEvent.CLICKED event object.
		 */
		public function onSmallDecrementClick(eventObj:ImageButtonEvent):void 
		{
			var newValue:Number = _currentPlayerBet - 0.10;
			if (newValue < 0) {
				newValue = 0;
			}			
			updatePlayerBet(newValue, true);
			enablePlayerBetting();
		}
		
		/**
		 * Handles click/tap events on the large decrement button.
		 * 
		 * @param	eventObj An ImageButtonEvent.CLICKED event object.
		 */
		public function onLargeDecrementClick(eventObj:ImageButtonEvent):void 
		{
			var newValue:Number = _currentPlayerBet - 1;
			if (newValue < 0) {
				newValue = 0;
			}			
			updatePlayerBet(newValue, true);
			enablePlayerBetting();
		}
		
		/**
		 * Handles click/tap events on the "Fold" button.
		 * 
		 * @param	eventObj An ImageButtonEvent.CLICKED event object.
		 */
		public function onFoldClick(eventObj:ImageButtonEvent):void 
		{
			DebugView.addText("   I have folded.");
			disablePlayerBetting();
			onPlayerFold(game.lounge.clique.localPeerInfo.peerID);
			var msg:PokerBettingMessage = new PokerBettingMessage();
			msg.createBettingMessage(PokerBettingMessage.PLAYER_FOLD);
			game.lounge.clique.broadcast(msg);
			updateGamePhase(null);
		}
		
		/**
		 * Handles click/tap events on the "Raise" button.
		 * 
		 * @param	eventObj An ImageButtonEvent.CLICKED event object.
		 */
		public function onRaiseClick(eventObj:ImageButtonEvent):void 
		{			
			onBetButtonClick(eventObj);
		}
		
		/**
		 * Handles click/tap events on the "Call" or "Check" button.
		 * 
		 * @param	eventObj An ImageButtonEvent.CLICKED event object.
		 */
		public function onCallClick(eventObj:ImageButtonEvent):void 
		{
			onBetButtonClick(eventObj);
		}
		
		/**
		 * Verifies the existence of a clique member within the current _players vector.
		 * 
		 * @param	member The INetCliqueMember implementation to verify.
		 * 
		 * @return True if the member exists within the _players vector, false otherwise.
		 */
		public function playerInfoExists(member:INetCliqueMember):Boolean 
		{
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
		public function getPlayerBalances(members:Vector.<INetCliqueMember>):Vector.<Number> 
		{
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
		 * Finds the balance for a specified member.
		 * 
		 * @param	member The member for which to find a balance.
		 * 
		 * @return The member's balance or Number.NEGATIVE_INFINITY if not set.
		 */
		protected function getPlayerBalance(member:INetCliqueMember):Number 
		{
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
		 * Adds a player to the end of betting order if the order hasn't been locked. Should only be used by 
		 * a Dealer instance to establish the initial betting order (new game).
		 * 
		 * @return True if member was newly added, false if member previously added.
		 */
		public function addPlayer(member:INetCliqueMember):Boolean 
		{
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
		 * Sets the dealer flag for an associated member if the betting order hasn't been locked. Should only be used by 
		 * a Dealer instance to establish the initial dealer (new game).
		 * 
		 * @param member The member to set the dealer flag for.
		 * @param dealerSet The value to set the dealer flag to.
		 */
		public function setDealer(member:INetCliqueMember, dealerSet:Boolean = true):void 
		{
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
		public function setBigBlind(member:INetCliqueMember, bbSet:Boolean = true):void 
		{
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
		public function setSmallBlind(member:INetCliqueMember, sbSet:Boolean = true):void 
		{
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
		public function lockBettingOrder():void 
		{
			_bettingOrderLocked = true;
		}
		
		/**
		 * Broadcasts the current betting order to the clique if the order hasn't been locked (new game). 
		 * To be invoked only by the current dealer.
		 * 
		 * @return True if the current betting order was successfully broadcast.
		 */
		public function broadcastBettingOrder():Boolean 
		{
			/**
			 * betting order: small blind, big blind, other player(s), dealer
			 * if only two players, dealer is big blind and other player is small blind
			 */			
			if (!game.lounge.leaderIsMe) {				
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
			return (game.lounge.clique.broadcast(message));
		}
				
		/**
		 * Starts the next (or first) betting cycle.
		 */
		public function startNextBetting():void 
		{
			DebugView.addText("PokerBettingModule.startNextBetting");
			keepOnTop();			
			var message:PokerBettingMessage = new PokerBettingMessage();
			message.createBettingMessage(PokerBettingMessage.DEALER_START_BLINDSTIMER);
			game.lounge.clique.broadcast(message);
			startBlindsTimer();
			passBettingControlToNextPlayer();			
		}
		
		/**
		 * Sets blinds values, usually as established by the dealer.
		 * 
		 * @param	smallBlindValue The small blind value to set.
		 * @param	bigBlindValue The big blind value to set.
		 */
		public function dealerSetBlinds(smallBlindVal:Number, bigBlindVal:Number):void 
		{
			DebugView.addText("PokerBettingModule.dealerSetBlinds");
			DebugView.addText("   Small: " + smallBlindVal);
			DebugView.addText("   Big:" + bigBlindVal);
			//TODO: add checks; this should not be allowed until the dealer has switched (or first dealer).
			smallBlind = smallBlindVal;
			bigBlind = bigBlindVal;
			var msg:PokerBettingMessage = new PokerBettingMessage();
			var blindsObj:Object = new Object();
			blindsObj.bigBlind = bigBlindVal;
			blindsObj.smallBlind = smallBlindVal;
			msg.createBettingMessage(PokerBettingMessage.DEALER_SET_BLINDS, 0, blindsObj);
			game.lounge.clique.broadcast(msg);
		}

		/**
		 * 
		 * Attempts to start the blinds timer.
		 * 
		 * @return True if the timer could be successfully started.
		 */
		public function startBlindsTimer():Boolean 
		{
			DebugView.addText("PokerBettingModule.startBlindsTimer");
			DebugView.addText("   Betting settings->");
			try {
				DebugView.addText("                    Name: " + currentSettings.gameName);
				DebugView.addText("                    Type: " + currentSettings.gameType);
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
		public function passBettingControlToNextPlayer():void 
		{
			DebugView.addText("PokerBettingModule.passBettingControlToNextPlayer");			
			var msg:PokerBettingMessage = new PokerBettingMessage();
			msg.createBettingMessage(PokerBettingMessage.DEALER_START_BET);
			game.lounge.clique.broadcast(msg);
		}
		
		/**
		 * Event listener invoked when a peer message is received from the clique. Processing of the message
		 * is done in the processPeerMessage function.
		 * 
		 * @param	eventObj Event dispatched by the clique.
		 */
		public function onReceivePeerMessage(eventObj:NetCliqueEvent):void 
		{
			processPeerMessage(eventObj.message);
		}

		/**
		 * Updates the established betting order such that the small blind becomes the dealer,
		 * the big blind becomes the small blind, and the next player after the new small blind
		 * becomes the big blind.
		 */
		public function updateBettingOrder():void
		{			
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
		public function broadcastGameResults(handAnalyzer:IPokerHandAnalyzer, key:Vector.<ISRAKey>):Boolean 
		{			
			DebugView.addText("PokerBettingModule.broadcastGameResults");
			if ((handAnalyzer == null) || (key == null)) {			
				return (false);
			}
			if (nonFoldedPlayers.length < 2) {
				//null results already included with fold message so nothing to broadcast
				return (false);
			}
			_lastHighestHand = handAnalyzer.highestHand;
			selfPlayerInfo.lastResultHand = _lastHighestHand;
			if (_lastHighestHand == null) {
				//hand couldn't be determined (probably folded before enough cards were dealt)				
				var msg:PokerBettingMessage = new PokerBettingMessage();			
				msg.createBettingMessage(PokerBettingMessage.PLAYER_RESULTS, 0);
				game.lounge.clique.broadcast(msg);
				if (allGameResultsReceived) {
					onRoundComplete();
				}
				return (true);
			}
			var payload:Object = new Object();
			payload["keys"] = new Array();
			payload["keys"][0] = new Object();
			payload["hands"] = new Array();
			payload["hands"][0] = new Array(); //usually include only one hand but this leaves room for expansion
			payload["keys"][0].encKey = key[0].encKeyHex; //for future drop-out support
			payload["keys"][0].decKey = key[0].decKeyHex
			payload["keys"][0].mod = key[0].modulusHex;		
			payload["hands"][0].fullHand = new Array();
			//use try...catch since player may not have enough cards for a full hand and this will fail
			try  {
				//include all cards in winning hand...
				for (var count:int = 0; count < _lastHighestHand.matchedHand.length; count++) {
					var currentCard:ICard = _lastHighestHand.matchedHand[count];
					var cardMapping:String = game.currentDeck.getMappingByCard(currentCard);
					payload["hands"][0].fullHand[count] = new Array();				
					payload["hands"][0].fullHand[count].mapping = cardMapping;
					payload["hands"][0].fullHand[count].cardName = currentCard.cardName;
					payload["hands"][0].fullHand[count].frontClassName = currentCard.frontClassName;
					payload["hands"][0].fullHand[count].faceColor = currentCard.faceColor;
					payload["hands"][0].fullHand[count].faceText = currentCard.faceText;
					payload["hands"][0].fullHand[count].faceValue = currentCard.faceValue;
					payload["hands"][0].fullHand[count].faceSuit = currentCard.faceSuit;
				}
			} catch (err:*) {				
			}
			//include matched cards in winning hand
			payload["hands"][0].matchedCards = new Array();			
			try {
				for (count = 0; count < _lastHighestHand.matchedCards.length; count++) {
					currentCard = _lastHighestHand.matchedCards[count];
					cardMapping = game.currentDeck.getMappingByCard(currentCard);
					payload["hands"][0].matchedCards[count] = new Array();				
					payload["hands"][0].matchedCards[count].mapping = cardMapping;
					payload["hands"][0].matchedCards[count].cardName = currentCard.cardName;
					payload["hands"][0].matchedCards[count].frontClassName = currentCard.frontClassName;
					payload["hands"][0].matchedCards[count].faceColor = currentCard.faceColor;
					payload["hands"][0].matchedCards[count].faceText = currentCard.faceText;
					payload["hands"][0].matchedCards[count].faceValue = currentCard.faceValue;
					payload["hands"][0].matchedCards[count].faceSuit = currentCard.faceSuit;
				}			
				payload["hands"][0].matchName = String(_lastHighestHand.matchedDefinition.@name);
				payload["hands"][0].rank = String(_lastHighestHand.matchedDefinition.@rank);
				payload["hands"][0].value = String(_lastHighestHand.totalHandValue);			
			} catch (err:*) {				
			}
			msg = new PokerBettingMessage();			
			msg.createBettingMessage(PokerBettingMessage.PLAYER_RESULTS, 0, payload);			
			game.lounge.clique.broadcast(msg);
			if (allGameResultsReceived) {
				onRoundComplete();
			}
			return (true);
		}
		
		/**
		 * Called when the final bet in a game is committed. Betting module will be in read-only mode until the next
		 * game round is initiated. Call with caution.
		 */
		public function onFinalBet():void 
		{			
			DebugView.addText("PokerBettingModule.onFinalBet");
			//usually handled in Player class which invokes broadcastGameResults below
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.BETTING_FINAL_DONE);
			dispatchEvent(event);
		}
		
		/**
		 * Starts a loop to keep the betting module on top of other visible elements in the parent container.
		 */
		private function keepOnTop():void 
		{			
			stopKeepOnTop();
			addEventListener(Event.ENTER_FRAME, keepOnTopLoop);
		}
		
		/**
		 * ENTER_FRAME event responder that pushes the betting module instance to the top of the parent
		 * display list. Use keepOnTop to start the loop and stopKeepOnTop to stop it.
		 * 
		 * @param	eventObj
		 */
		private function keepOnTopLoop(eventObj:Event):void 
		{
			parent.setChildIndex(this, (parent.numChildren-1));
		}
		
		/**
		 * Stops the loop to keep the betting module on top of the display list of the parent container.
		 */
		private function stopKeepOnTop():void 
		{			
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
		private function onReceiveBettingOrder(peerIDList:Array):void 
		{			
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
					if (game.lounge.clique.localPeerInfo.peerID == playerInfoObj.netCliqueInfo.peerID) {
						DebugView.addText("      (self)");
					}
					_players.push(playerInfoObj);
				}
			}
			DebugView.addText("   Dealer peer: " + playerInfoObj.netCliqueInfo.peerID);
			_players[_players.length - 1].isDealer = true; //last entry is always dealer, may also be big blind
			lockBettingOrder();
		}
		
		/**
		 * Search for a clique member by their peer ID.
		 * 
		 * @param	peerID The peer ID to search for.
		 * @param	includeSelf Should the search include the local player (self)?
		 * 
		 * @return The INetCliqueMember implementation that matches the peer ID or null if none found.
		 */
		private function findMemberByID(peerID:String, includeSelf:Boolean = true):INetCliqueMember 
		{
			var peers:Vector.<INetCliqueMember> = game.lounge.clique.connectedPeers;
			for (var count:int = 0; count < peers.length; count++) {
				var currentPeer:INetCliqueMember = peers[count];
				if (currentPeer!=null) {
					if (currentPeer.peerID == peerID) {
						return (currentPeer);
					}
				}
			}
			if (peerID == game.lounge.clique.localPeerInfo.peerID) {
				return (game.lounge.clique.localPeerInfo);//
			}
			return (null);
		}		
		
		/**
		 * Processes a (usually) incoming peer message. Invalid messages are ignored.
		 * 
		 * @param	peerMessage The peer message to process.
		 */
		protected function processPeerMessage(peerMessage:IPeerMessage):void 
		{
			var peerMsg:PokerBettingMessage = PokerBettingMessage.validateBettingMessage(peerMessage);			
			if (peerMsg == null) {				
				//not a poker betting message
				return;
			}			
			DebugView.addText("PokerBettingModule.processPeerMessage:");
			DebugView.addText(peerMsg);
			if (peerMessage.isNextSourceID(game.lounge.clique.localPeerInfo.peerID)) {		
				DebugView.addText  ("-- message came from us...skipping.");
				//message came from us + we are the next source ID meaning no other peer has processed the message
				return;
			}			
			peerMsg.timestampReceived = peerMsg.generateTimestamp();			
			try {				
				//TODO: this should work with peerMsg too; some values not being properly copied
				if (peerMessage.hasTargetPeerID(game.lounge.clique.localPeerInfo.peerID)) {					
					//message is either for us or whole clique (*)
					switch (peerMsg.bettingMessageType) {
						case PokerBettingMessage.DEALER_SET_PLAYERBALANCES: 
							DebugView.addText("  Dealer is attempting unsupported operation \"DEALER_SET_PLAYERBALANCES\" with value: " + peerMsg.value);
							break;
						case PokerBettingMessage.PLAYER_UPDATE_BET:
							DebugView.addText("  PokerBettingMessage.PLAYER_UPDATE_BET");							
							updateExternalPlayerBet(peerMsg);
							break;
						case PokerBettingMessage.PLAYER_SET_BET:
							DebugView.addText("  PokerBettingMessage.PLAYER_SET_BET");
							DebugView.addText("       Value=" + peerMsg.value);					
							setExternalPlayerBet(peerMsg);						
							updateTablePot(peerMsg.value);
							updateTableBet();
							updateGamePhase(peerMsg);							
							break;
						case PokerBettingMessage.DEALER_SET_BLINDS:
							DebugView.addText("  PokerBettingMessage.DEALER_SET_BLINDS");
							onDealerSetBlinds(peerMessage.data.payload);
							break;
						case PokerBettingMessage.DEALER_START_BLINDSTIMER:
							DebugView.addText("  PokerBettingMessage.DEALER_START_BLINDSTIMER");
							startBlindsTimer();
							break;
						case PokerBettingMessage.DEALER_SET_BETTINGORDER:
							DebugView.addText("  PokerBettingMessage.DEALER_SET_BETTINGORDER");							
							onReceiveBettingOrder(peerMsg.data);
							break;
						case PokerBettingMessage.DEALER_START_BET:
							DebugView.addText("  PokerBettingMessage.PLAYER_NEXT_BET");
							onNextPlayerBet(peerMsg.getSourcePeerIDList());
							break;
						case PokerBettingMessage.PLAYER_FOLD:
							DebugView.addText("  PokerBettingMessage.PLAYER_FOLD");
							DebugView.addText("     Source peers: "+peerMsg.sourcePeerIDs);
							onPlayerFold(peerMsg.getSourcePeerIDList()[0].peerID);
							updateGamePhase(peerMsg);							
							break;
						case PokerBettingMessage.PLAYER_RESULTS:
							DebugView.addText("  PokerBettingMessage.PLAYER_RESULTS");
							var playerHand:PokerHand = new PokerHand(null, null, null);
							playerHand.generateFromPeerMessage(peerMsg, game);
							var memberInfo:INetCliqueMember = peerMsg.getSourcePeerIDList()[0];
							var playerInfo:IPokerPlayerInfo = getPlayerInfo(memberInfo);
							if (playerInfo != null) {
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
		 * All game results, player keys, etc. have been received and game is fully completed.
		 * Method may only be invoked once per round (some asynchronous messages may still be received
		 * after a round).
		 */
		private function onRoundComplete():void {
			if (_roundComplete) {
				return;
			}
			_roundComplete = true;
			DebugView.addText("----------------------------------------------------------");
			DebugView.addText("   GAME IS COMPLETE");			
			DebugView.addText(" ");
			var winningPlayer:IPokerPlayerInfo = winningPlayerInfo;			
			if (winningPlayer == selfPlayerInfo) {
				DebugView.addText("   I won!");
			} else {
				DebugView.addText("   Peer \""+winningPlayer.netCliqueInfo.peerID+"\" won.");				
			}
			DebugView.addText ("   Winning hand: ");
			DebugView.addText (winningPlayer.lastResultHand);			
			var event:PokerBettingEvent = new PokerBettingEvent(PokerBettingEvent.GAME_DONE);
			dispatchEvent(event);
		}
		
		/**
		 * Resets the betting flags for all players so that new betting can begin.
		 * 
		 * @param	endOfRound If true, all player flags are cleared for a new round (usually also when the game phase is reset).
		 */
		private function resetAllPlayersBettingFlags(endOfRound:Boolean=false):void 
		{			
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				currentPlayer.lastBet = Number.NEGATIVE_INFINITY;
				if (endOfRound) {
					currentPlayer.hasFolded = false;					
					currentPlayer.lastResultHand =  null;
					currentPlayer.totalBet = Number.NEGATIVE_INFINITY;
				}
			}
		}
		
		/**
		 * Updates the game phase based on the current game status and incoming peer message.
		 * 
		 * @param	peerMsg A peer message, usually incoming, to include in the evaluation.
		 * 
		 * @return True if the phase was updated (game phase incremented).
		 */
		private function updateGamePhase(peerMsg:IPeerMessage):Boolean 
		{
			DebugView.addText("PokerBettingModule.updateGamePhase");
			if (nonFoldedPlayers.length < 2) {
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
				resetAllPlayersBettingFlags(false);
				updateTableBet();
				phaseChanged = true;
				dispatchEvent(new PokerBettingEvent(PokerBettingEvent.BETTING_DONE));
			}
			DebugView.addText("Current phase: " + game.gamePhase);
			if (game.gamePhase <= phases) {
				if (peerMsg!=null) {
					onNextPlayerBet(peerMsg.getSourcePeerIDList());
				} else {					
				}
			} else {				
				DebugView.addText("   *******************************************");
				DebugView.addText("   All betting rounds completed - GAME IS DONE");
				DebugView.addText("   *******************************************");
				disablePlayerBetting();
				onFinalBet();
			}						
			return (phaseChanged);
		}
		
		/**
		 * Marks a specific player as having folded.
		 * 
		 * @param	peerID The peer ID of the player that has folded; may be the local player (self).
		 */
		private function onPlayerFold(peerID:String):void 
		{
			DebugView.addText("PokerBettingModule.onPlayerFold: " + peerID);
			var ncMember:INetCliqueMember = findMemberByID(peerID, true);
			if (ncMember != null) {
				var playerInfo:IPokerPlayerInfo = getPlayerInfo(ncMember);				
				if (playerInfo != null) {
					playerInfo.hasFolded = true;										
					DebugView.addText("   Player \"" + ncMember.peerID + "\" has folded");					
				} else {
					DebugView.addText("   Error: playerInfo is null for peer \""+ncMember.peerID+"\"");
				}
			} else {
				DebugView.addText("   Error: NetCliqueMember implementation not found by peer ID \""+peerID+"\"");
			}
		}
		
		/**
		 * Handler for PokerBettingMessage.DEALER_SET_BLINDS event. Data may be transformed, if necessary,
		 * before the blinds are updated.
		 * 
		 * @param	blindsData An object containing the Numbers "smallBlind" and "bigBlind".
		 */
		private function onDealerSetBlinds(blindsData:Object):void 
		{
			DebugView.addText("PokerBettingModule.onDealerSetBlinds");
			DebugView.addText("   Small: "+blindsData.smallBlind);
			DebugView.addText("   Big: " + blindsData.bigBlind);
			smallBlind = blindsData.smallBlind;
			bigBlind = blindsData.bigBlind;
		}
		
		/**
		 * The current table bet as established by the last highest betting player.
		 */
		private function get currentTableBet():Number 
		{
			var highestValue:Number = 0;			
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				if (currentPlayer.lastBet > highestValue) {
					highestValue = currentPlayer.lastBet;
				}
			}			
			return (highestValue);
		}
		
		/**
		 * The current table bet as established by the highest total player bet value.
		 */
		private function get largestTableBet():Number 
		{
			var highestValue:Number = 0;			
			for (var count:int = 0; count < _players.length; count++) {
				var currentPlayer:IPokerPlayerInfo = _players[count];
				if (currentPlayer.totalBet > highestValue) {
					highestValue = currentPlayer.totalBet;
				}
			}			
			return (highestValue);
		}
		
		/**
		 * Enables the player betting UI. Button visibility is dependent on current bets and other
		 * conditions.
		 */
		private function enablePlayerBetting():void
		{			
			DebugView.addText("PokerBettingModule.enablePlayerBetting");
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
			try {
				incLargeButton.disabled = false;
				incLargeButton.show();
			} catch (err:*) {
			}
			try {
				incSmallButton.disabled = false;
				incSmallButton.show();
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
		}
		
		/**
		 * Diables the player betting UI by hiding all elements.
		 */
		private function disablePlayerBetting():void
		{
			DebugView.addText("PokerBettingModule.disablePlayerBetting");
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
		}
		
		/**
		 * The main handler for starting the "next" player betting action (control has just been passed from previous player).
		 * 
		 * @param	sourcePeers An ordered list of peers as received.
		 */
		private function onNextPlayerBet(sourcePeers:Vector.<INetCliqueMember>):void 
		{
			DebugView.addText("PokerBettingModule.onNextPlayerBet");
			DebugView.addText("Source peer ID : " + sourcePeers[0].peerID);			
			DebugView.addText("My peer ID     :" + game.lounge.clique.localPeerInfo.peerID);			
			if (selfPlayerInfo.totalBet!=Number.NEGATIVE_INFINITY) {
				_currentPlayerBet = selfPlayerInfo.totalBet;
			}			
			if (!currentBettingPlayerIsMe(sourcePeers)) {
				DebugView.addText("   I am not the next betting player according to dealer betting order so ignoring.");
				return;
			}
			DebugView.addText("   I am the next betting player according to dealer betting order.");
			var diffValue:Number = largestTableBet - _currentPlayerBet;			
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
		 * Verifies if the local player (self) is the next betting player according to the dealer betting order and
		 * (usually) received peer list.
		 * 
		 * @param	sourcePeers The ordered source member list of the peer message 
		 * @return
		 */
		private function currentBettingPlayerIsMe(sourcePeers:Vector.<INetCliqueMember>):Boolean 
		{			
			if (sourcePeers == null) {
				return (false);
			}
			if (sourcePeers.length == 0) {
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
					if (currentPlayer.netCliqueInfo.peerID == game.lounge.clique.localPeerInfo.peerID) {						
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
		private function get playerCanCheck():Boolean 
		{
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
		private function get allPlayersHaveBet():Boolean 
		{
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
		private function get smallBlindIsMe():Boolean 
		{
			if (currentSmallBlindMember.peerID == game.lounge.clique.localPeerInfo.peerID) {
				return (true);
			}
			return (false);
		}
		
		/**
		 * @return True if the local player (self) is flagged as the current big blind.
		 */
		private function get bigBlindIsMe():Boolean 
		{
			if (currentBigBlindMember.peerID == game.lounge.clique.localPeerInfo.peerID) {
				return (true);
			}
			return (false);
		}
		
		private function get dealerIsMe():Boolean {
			return (game.lounge.leaderIsMe);
		}
		
		/**
		 * Handler for PokerBettingMessage.PLAYER_UPDATE_BET event. Typically this will update the associated player's
		 * bet in the user interface.
		 * 
		 * @param	peerMsg The PokerBettingMessage containing a value property for the associated player.
		 */
		private function updateExternalPlayerBet(peerMsg:PokerBettingMessage):void 
		{
			DebugView.addText("PokerBettingModule.updateExternalPlayerBet: " + peerMsg.value);			
			//update player's UI here
		}
		
		/**
		 * Handler for PokerBettingMessage.PLAYER_SET_BET event. This will update the associated player's bet by
		 * adding the new bet to their existing bet.
		 * 
		 * @param	peerMsg The PokerBettingMessage containing a new bet value for the associated player.
		 */
		private function setExternalPlayerBet(peerMsg:PokerBettingMessage):void 
		{
			DebugView.addText("PokerBettingModule.updateExternalPlayerBet: " + peerMsg.value);
			var playerInfo:IPokerPlayerInfo = getPlayerInfo(peerMsg.getSourcePeerIDList()[0]);
			if (playerInfo.totalBet == Number.NEGATIVE_INFINITY) {
				playerInfo.totalBet = 0;
			}							
			playerInfo.totalBet += peerMsg.value;			
			playerInfo.lastBet = peerMsg.value;			
		}
		
		/**
		 * Updates the current table bet (the largest curent bet or raise).
		 */
		private function updateTableBet():void 
		{
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
			DebugView.addText("   -> updated to: " + _currencyFormat.getString(CurrencyFormat.default_format));
			currentTableBetValue.text = "Current table bet: " + _currencyFormat.getString(CurrencyFormat.default_format);
		}
		
		/**
		 * Updates the current "table" pot (total of all players' bets).
		 * 
		 * @param	updateValue The new value to add to (or subtract from), the current table pot.
		 */
		private function updateTablePot(updateValue:Number):void 
		{
			DebugView.addText("PokerBettingModule.updateTablePot: " + updateValue);			
			_communityPot += updateValue;			
			_currencyFormat.setValue(_communityPot);
			currentTablePotValue.text = "Current table pot: " + _currencyFormat.getString(CurrencyFormat.default_format);
		}
		
		/**
		 * Updates the local player's (self's) current non-committed bet value in the UI, optionally broadcasting the update to the clique.
		 * 
		 * @param	newBetValue The new bet value to update to.
		 * @param	updateOtherPlayers If true, broadcast the non-committed value to the clique.
		 */
		private function updatePlayerBet(newBetValue:Number, updateOtherPlayers:Boolean = true):void 
		{
			newBetValue=_currencyFormat.roundToFormat(newBetValue, CurrencyFormat.default_format);			
			_currencyFormat.setValue(newBetValue);			
			betValue.text = _currencyFormat.getString(CurrencyFormat.default_format);
			_currentPlayerBet = newBetValue;
			if (updateOtherPlayers) {
				broadcastPlayerBetUpdate(_currentPlayerBet);
			}			
		}
		
		/**
		 * Commits the local player's (self's) bet. If the player is the dealer and all player bets are equal,
		 * a PokerBettingEvent.BETTING_DONE event is dispatched.
		 */
		private function commitCurrentBet():void 
		{
			DebugView.addText("PokerBettingModule.commitCurrentBet: " + _currentPlayerBet);			
			if (selfPlayerInfo.totalBet == Number.NEGATIVE_INFINITY) {
				selfPlayerInfo.totalBet = 0;
			}
			selfPlayerInfo.lastBet = _currentPlayerBet;
			selfPlayerInfo.totalBet += _currentPlayerBet;
			updateTableBet();
			updateTablePot(_currentPlayerBet);
			broadcastPlayerBetSet(_currentPlayerBet);
			if (bettingComplete) {
				resetAllPlayersBettingFlags(false);
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
		private function playerIsInList(playerRef:IPokerPlayerInfo, playerList:Vector.<IPokerPlayerInfo>):Boolean 
		{
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
		
		/**
		 * Handles blinds timer timer tick events and updates the user interface.
		 * 
		 * @param	eventObj Event dispatched from a GameTimer instance.
		 */
		private function onBlindsTimerTick(eventObj:GameTimerEvent):void 
		{			
			var timerObj:GameTimer = GameTimer(eventObj.target);
			blindsTimerValue.text = timerObj.getTimeString(currentSettings.currentTimerFormat);			
			if (timerObj.totalSeconds <= 0) {
				timerObj.stopCountDown();				
			}
		}
		
		/**
		 * Handles blinds timer timer complete events.
		 * 
		 * @param	eventObj Event dispatched from a GameTimer instance.
		 */
		private function onBlindsTimerComplete(eventObj:GameTimerEvent):void 
		{			
			DebugView.addText("PokerBettingModule.onBlindsTimerComplete"); 	
			currentSettings.currentTimer.removeEventListener(GameTimerEvent.COUNTDOWN_TICK, onBlindsTimerTick);
			currentSettings.currentTimer.removeEventListener(GameTimerEvent.COUNTDOWN_END, onBlindsTimerComplete);
			currentSettings.clearCurrentTimer();
			blindsTimerComplete();
		}
		
		/**
		 * Increments the settings level in the default PokerBettingSettings value.
		 */
		private function blindsTimerComplete():void 
		{
			_bettingSettings[0].currentLevel++;				
			startBlindsTimer();
		}
		
		/**
		 * Broadcasts the current bet value to participating players.
		 * 
		 * @param	newValue Numeric base value (such as CurrencyFormat.getValue) to send
		 * to participating players. Value is usually sent as-is (toString) so that
		 * participants may correctly format the data locally.
		 */
		private function broadcastPlayerBetUpdate(newValue:Number):void 
		{
			var newMessage:PokerBettingMessage = new PokerBettingMessage();
			newMessage.createBettingMessage(PokerBettingMessage.PLAYER_UPDATE_BET, newValue);			
			game.lounge.clique.broadcast(newMessage);
		}
		
		/**
		 * Broadcasts the set (commited) bet value to participating players.
		 * 
		 * @param	newValue Numeric base value (such as CurrencyFormat.getValue) to send
		 * to participating players. Value is usually sent as-is (toString) so that
		 * participants may correctly format the data locally.
		 */
		private function broadcastPlayerBetSet(newValue:Number):void 
		{
			DebugView.addText("PokerBettingmodule.broadcastPlayerBetSet: " + newValue);
			var newMessage:PokerBettingMessage = new PokerBettingMessage();
			newMessage.createBettingMessage(PokerBettingMessage.PLAYER_SET_BET, newValue);			
			game.lounge.clique.broadcast(newMessage);			
		}
	}
}
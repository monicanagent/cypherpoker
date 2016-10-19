/**
* Main poker card game. Implements IBaseCardGame and makes extensive use of PokerBettingModule, Player, and Dealer.
*
* (C)opyright 2015, 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package 
{
	import events.PokerGameStatusEvent;
	import flash.events.KeyboardEvent;	
	import flash.text.TextField;
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.ICard;
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.interfaces.IPeerMessageLog;	
	import interfaces.IPlayer;
	import interfaces.IPokerPlayerInfo;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import org.cg.Status;
	import PokerGameStatusReport;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import events.PokerBettingEvent;
	import org.cg.Card;
	import org.cg.CurrencyFormat;	
	import org.cg.ImageButton;	
	import org.cg.BaseCardGame;
	import org.cg.GameSettings;	
	import org.cg.GlobalSettings;;
	import p2p3.PeerMessageLog;
	import org.cg.DebugView;
	import flash.display.Bitmap;
	import flash.utils.setTimeout;
	import flash.utils.clearTimeout;
	import events.EthereumWeb3ClientEvent;
	import p2p3.PeerMessage;
	
	dynamic public class PokerCardGame extends BaseCardGame 
	{
				
		private var _player:IPlayer; //may be a Player or Dealer instance depending on this round of play
		private static var _gameLog:PeerMessageLog = new PeerMessageLog(); //main message log for peer messages
		private var _bettingModule:PokerBettingModule; //texas hold'em game betting logic
		private var _communityCards:Vector.<ICard> = null; //current community/public cards		
		private var _playerCards:Vector.<ICard> = null; //current player/private cards
		private var _commCardsContainer:MovieClip = null; //community cards display container
		private var _playerCardsContainer:MovieClip = null; //player cards display container
		private var _lastWinningPlayer:IPokerPlayerInfo = null; //available at end of every round, before a new round begins
		private var _gameStatusLocked:Boolean = false; //should status updates be locked?
		private var _gameStatusLockTimeoutID:uint = 0; //timer ID of current status updates lock
		public var gameStatus:TextField; //dynamically generated		
		
		public function PokerCardGame():void 
		{			
			if (GlobalSettings.systemSettings.isWeb) {
				super.settingsFilePath = "./PokerCardGame/xml/settings.xml";
			} else {
				super.settingsFilePath = "../PokerCardGame/xml/settings.xml";
			}
			_bettingModule = new PokerBettingModule(this);
			_bettingModule.addEventListener(PokerBettingEvent.ROUND_DONE, onRoundDone);
			Status.dispatcher.addEventListener(PokerGameStatusEvent.STATUS, onGameStatus);
			Status.dispatcher.addEventListener(PokerGameStatusEvent.WIN, onGameStatus);
			Status.dispatcher.addEventListener(PokerGameStatusEvent.GAME_WIN, onGameStatus);
			DebugView.addText  ("PokerCardGame instantiated.");
		}		
		
		/**
		 * @return The main poker card game peer message log instance.
		 */
		public function get log():IPeerMessageLog 
		{
			return (_gameLog as IPeerMessageLog);
		}
		
		/**
		 * Sets default values for the poker card game and invokes the setDefaults function in the super class.
		 * 
		 * @param	eventObj An Event.ADDED_TO_STAGE event object.
		 */
		override protected function setDefaults(eventObj:Event = null):void 
		{
			DebugView.addText  ("PokerCardGame.setDefaults");			
			super.setDefaults(eventObj);			
		}		
		
		/**
		 * @return The current PokerBettingModule instance being used by the game.
		 */
		public function get bettingModule():PokerBettingModule 
		{
			return (_bettingModule);
		}		
		
		/**
		 * @return A list of the local player's (self's) current private cards, or null if none have been dealt.
		 */
		public function get playerCards():Vector.<ICard> 
		{
			return (_playerCards);
		}
		
		/**
		 * @return A list of the current community/public cards, or null if none have been dealt.
		 */
		public function get communityCards():Vector.<ICard> 
		{
			return (_communityCards);
		}
		
		/**
		 * Attempts to start (new game) or restart (new round) the poker card game. Poker card game instance must be
		 * fully initialized before calling this function.
		 * 
		 * @param	restart True if the game is being restarted for a new round, false if the game is being started 
		 * for the first time.
		 * 
		 * @return True if the game could be successfully started or restarted.
		 */
		override public function start(restart:Boolean=false):Boolean
		{
			DebugView.addText ("PokerCardGame.start");			
			if ((lounge is ILounge) == false) {
				DebugView.addText  ("   Parent container is not an org.cg.interfaces.ILounge implementation. Can't start game.");
				return (false);
			}			
			if (restart == false) {
				new PokerGameStatusReport("Starting new game.", PokerGameStatusEvent.ROUNDSTART).report();
				bettingModule.initialize();
			} else {
				new PokerGameStatusReport("Starting new round.", PokerGameStatusEvent.ROUNDSTART).report();
			}
			if (lounge.leaderIsMe) {
				DebugView.addText  ("Assuming dealer role (Dealer type).");
				new PokerGameStatusReport("I'm the dealer. Sending start game message.").report();
				//initialize shift list for Sequential Member Operations...
				var shiftList:Vector.<INetCliqueMember> = super.getSMOShiftList();
				_player = new Dealer(this); //Dealer is a type of Player so this is valid
				var pcgMessage:PokerCardGameMessage = new PokerCardGameMessage();
				pcgMessage.createPokerMessage(PokerCardGameMessage.GAME_START);
				lounge.clique.broadcast(pcgMessage);
				_gameLog.addMessage(pcgMessage);
			} else {
				DebugView.addText  ("Assuming player role (Player type).");
				new PokerGameStatusReport("I'm a player.").report();
				_player = new Player(this);				
			}
			_player.start();
			return (super.start());
		}
		
		/**
		 * Attempts to retrieve information about an already deployed contract from the GlobalSettings object.
		 * 
		 * @param	contractName The contract name for which to retrieve a descriptor.
		 * @param	contractState The state that the returned contract must be flagged as. Valid states include
		 * 		"new" (deployed but not yet used), "active" (in use), and "complete" (fully completed but remaining on
		 * 		the blockchain).
		 * 
		 * @return A matching contract info descriptor, or null if none can be found.
		 */
		public function getDeployedContractInfo(contractName:String, contractState:String="new"):XML {
			var ethereumContractsNode:XML = lounge.settings.getSetting("smartcontracts", "ethereum");			
			if (ethereumContractsNode.children().length() == 0) {
				return (null);
			}
			var infoNodes:XMLList = ethereumContractsNode.children();
			for (var count:int = 0; count < infoNodes.length(); count++) {
				var currentInfoNode:XML = infoNodes[count] as XML;
				if (currentInfoNode.localName() == contractName) {
					if (String(currentInfoNode.@state) == contractState) {
						return (currentInfoNode);
					}
				}
			}
			return (null);
		}
		
		private function deployPokerHandContract():void {
			//lounge.ethereum.web3.miner.start(2);	
			lounge.ethereum.client.removeEventListener(EthereumWeb3ClientEvent.SOLCOMPILED, this.onCompilePokerHandContract);
			lounge.ethereum.client.addEventListener(EthereumWeb3ClientEvent.SOLCOMPILED, this.onCompilePokerHandContract);
			lounge.ethereum.client.compileSolidityFile("./ethereum/solidity/PokerHandBI.sol");
		}
		
		private function onCompilePokerHandContract(eventObj:EthereumWeb3ClientEvent):void {
			DebugView.addText ("Compiled:");
			DebugView.addText(eventObj.compiledRaw);
		}
		
		/**
		 * Callback function invoked by the ViewManager when the default view has been rendered.
		 */
		override public function onRenderDefaultView():void 
		{
			try {
				//not all elements may be available so use try..catch				
			} catch (err:*) {				
			}
		}
		
		/**
		 * Destroys the game instance by removing event listeners and clearing unused memory. This is usually
		 * the last function to be called before the game is removed from memory.
		 */
		override public function destroy():void
		{			
			_bettingModule.removeEventListener(PokerBettingEvent.ROUND_DONE, onRoundDone);
			Status.dispatcher.removeEventListener(PokerGameStatusEvent.STATUS, onGameStatus);
			Status.dispatcher.removeEventListener(PokerGameStatusEvent.WIN, onGameStatus);
			Status.dispatcher.removeEventListener(PokerGameStatusEvent.GAME_WIN, onGameStatus);
			if (_player!=null) {
				_player.destroy(true);
			}
			_player = null;
			_bettingModule = null;
			reset();
			super.destroy();
		}
		
		/**
		 * Adds one or more cards to the current list of community/public cards.
		 * 
		 * @param	cards The card(s) to add to the community card list.
		 */
		public function addToCommunityCards(cards:Vector.<ICard>):void 
		{
			if (_communityCards == null) {
				_communityCards = new Vector.<ICard>();
			}
			for (var count:uint = 0; count < cards.length; count++) {
				createCommunityCard(cards[count]);
			}
		}
		
		/**
		 * Adds one or more cards to the current list of player/private cards.
		 * 
		 * @param	cards The card(s) to add to the player card list.
		 */
		public function addToPlayerCards(cards:Vector.<ICard>):void 
		{
			if (_playerCards == null) {
				_playerCards = new Vector.<ICard>();
			}
			for (var count:uint = 0; count < cards.length; count++) {
				createPlayerCard(cards[count]);
			}
		}
		
		/**
		 * Clears the current list of community/public cards from the display list and flips them face down for re-use.
		 */
		public function clearCommunityCards():void 
		{
			if (_communityCards == null) {
				return;
			}
			for (var count:uint = 0; count < _communityCards.length; count++) {
				var currentCard:Card = _communityCards[count] as Card;
				//make sure card is face down for next time it's used
				currentCard.flip(false, 0, 0, false, 0);
				try {
					_commCardsContainer.removeChild(currentCard);
				} catch (err:*) {
				}
			}
			_communityCards = new Vector.<ICard>();
		}
		
		/**
		 * Clears the current list of player/private cards from the display list and flips them face down for re-use.
		 */
		public function clearPlayerCards():void 
		{
			if (_playerCards == null) {
				return;
			}
			for (var count:uint = 0; count < _playerCards.length; count++) {
				var currentCard:Card = _playerCards[count] as Card;
				currentCard.flip(false, 0, 0, false, 0);				
				try {
					_playerCardsContainer.removeChild(currentCard);					
				} catch (err:*) {					
				}
			}			
			_playerCards = new Vector.<ICard>();	
		}
		
		/**
		 * Changes the current Player instance to a Dealer instance and initializes it, usually mid-round as
		 * part of a drop-out/re-keyeing operation.
		 * 
		 * @param	initObject An object containing name-matched initialization data to provide to the new Dealer instance.
		 * @param	invokeAfterInitialize An optional named public function to invoke in the new Dealer instance.
		 * 
		 * @return True if the existing Player was successfully re-instantiated as a Dealer, false if player was already
		 * a Dealer.
		 */
		public function changePlayerToDealer(initObject:Object, invokeAfterInitialize:String = null):Boolean
		{
			if (_player is Dealer) {
				return (false);
			}
			new PokerGameStatusReport("Changing from player to dealer.").report();
			var newDealer:Dealer = new Dealer(this, initObject);			
			_player.destroy(true);
			_player = null;
			_player = newDealer;
			if (invokeAfterInitialize != null) {
				try {
					_player[invokeAfterInitialize]();
				} catch (err:*) {
					DebugView.addText("PokerCardGame.changePlayerToDealer - "+err);
				}
			}			
			return (true);
		}		
		
		/**
		 * A simple game status event handler to display game progress to the player.
		 * 
		 * @param eventObj A status event object.
		 * 
		 */
		protected function onGameStatus(eventObj:PokerGameStatusEvent):void
		{
			if (_gameStatusLocked) {
				return;
			}
			switch (eventObj.type) {				
				case PokerGameStatusEvent.STATUS:
					try {
						gameStatus.text = eventObj.sourceStatusReport.message;
					} catch (err:*) {						
					}
					break;
				case PokerGameStatusEvent.WIN:
					try {
						clearTimeout(_gameStatusLockTimeoutID);						
					} catch (err:*) {						
					}
					try {						
						gameStatus.text = eventObj.sourceStatusReport.message;
						_gameStatusLocked = true;
						_gameStatusLockTimeoutID=setTimeout(unlockGameStatus, 3000);
					} catch (err:*) {						
					}
					break;
				case PokerGameStatusEvent.GAME_WIN:
					try {
						clearTimeout(_gameStatusLockTimeoutID);						
					} catch (err:*) {						
					}
					try {						
						gameStatus.text = eventObj.sourceStatusReport.message;
						_gameStatusLocked = true; //end of game, locked permanently
					} catch (err:*) {						
					}
					break;
				default: break;
			}			
		}		
		
		/**
		 * Attempts to create a community/public card by adding it to the display container and showing it.
		 * 
		 * @param	cardRef The commuity card to create within the display container.
		 * 
		 * @return True if the card could be created, false if creation failed or if the card has already been created.
		 */
		protected function createCommunityCard(cardRef:ICard):Boolean 
		{
			if (cardRef == null) {
				return (false);
			}
			if (_commCardsContainer == null) {
				_commCardsContainer = new MovieClip();
				addChild(_commCardsContainer);
				var _x:Number = 0;
				var _y:Number = 0;
				var _scaleX:Number = 0;
				var _scaleY:Number = 0;
				try {
					_x = Number(GameSettings.getSetting("defaults", "display").publiccards.x);
					if (isNaN(_x)) {
						_x = 0;
					}
				} catch (err:*) {
					_x = 0;
				}
				try {
					_y = Number(GameSettings.getSetting("defaults", "display").publiccards.y);
					if (isNaN(_y)) {
						_y = 0;
					}
				} catch (err:*) {
					_y = 0;
				}
				try {
					_scaleX = Number(GameSettings.getSetting("defaults", "display").publiccards.scalex);
					if (isNaN(_scaleX)) {
						_scaleX = 1;
					}
				} catch (err:*) {
					_scaleX = 1;
				}
				try {
					_scaleY = Number(GameSettings.getSetting("defaults", "display").publiccards.scaley);
					if (isNaN(_scaleY)) {
						_scaleY = 1;
					}
				} catch (err:*) {
					_scaleY = 1;
				}
				_commCardsContainer.x = _x;
				_commCardsContainer.y = _y;
				_commCardsContainer.scaleX = _scaleX;
				_commCardsContainer.scaleY = _scaleY;				
			}
			for (var count:uint = 0; count < _communityCards.length; count++) {
				var currentCard:Card = _communityCards as Card;
				if (currentCard == (cardRef as Card)) {			
					return (false);
				}
			}
			_communityCards.push(cardRef);
			var cardItem:Card = cardRef as Card;
			_commCardsContainer.addChild(cardRef as Card);
			cardItem.x = cardItem.width * (_communityCards.length-1)+(10*(_communityCards.length-1));			
			cardItem.y = 0;
			cardItem.fadeIn(1);
			cardItem.flip(true, 1, 0, true, _communityCards.length*500);			
			return (true);
		}
		
		/**	
		 * Attempts to create a player/private card by adding it to the display container and showing it.
		 * 
		 * @param	cardRef The player card to create within the display container.
		 * 
		 * @return True if the card could be created, false if creation failed or if the card has already been created.
		 */
		protected function createPlayerCard(cardRef:ICard):Boolean 
		{
			if (cardRef == null) {
				return (false);
			}
			if (_playerCardsContainer == null) {
				_playerCardsContainer = new MovieClip();
				addChild(_playerCardsContainer);
				var _x:Number = 0;
				var _y:Number = 0;
				var _scaleX:Number = 0;
				var _scaleY:Number = 0;
				try {
					_x = Number(GameSettings.getSetting("defaults", "display").privatecards.x);
					if (isNaN(_x)) {
						_x = 0;
					}
				} catch (err:*) {
					_x = 0;
				}
				try {
					_y = Number(GameSettings.getSetting("defaults", "display").privatecards.y);
					if (isNaN(_y)) {
						_y = 0;
					}
				} catch (err:*) {
					_y = 0;
				}
				try {
					_scaleX = Number(GameSettings.getSetting("defaults", "display").privatecards.scalex);
					if (isNaN(_scaleX)) {
						_scaleX = 1;
					}
				} catch (err:*) {
					_scaleX = 1;
				}
				try {
					_scaleY = Number(GameSettings.getSetting("defaults", "display").privatecards.scaley);
					if (isNaN(_scaleY)) {
						_scaleY = 1;
					}
				} catch (err:*) {
					_scaleY = 1;
				}
				_playerCardsContainer.x = _x;
				_playerCardsContainer.y = _y;
				_playerCardsContainer.scaleX = _scaleX;
				_playerCardsContainer.scaleY = _scaleY;
			}
			for (var count:uint = 0; count < _playerCards.length; count++) {
				var currentCard:Card = _playerCards as Card;
				if (currentCard == (cardRef as Card)) {			
					return (false);
				}
			}
			_playerCards.push(cardRef);
			var cardItem:Card = cardRef as Card;
			_playerCardsContainer.addChild(cardRef as Card);
			cardItem.x = cardItem.width * (_playerCards.length-1)+(10*(_playerCards.length-1));			
			cardItem.y = 0;
			cardItem.fadeIn(1);
			cardItem.flip(true, 1, 0, true, _playerCards.length*500);			
			return (true);
		}		
		
		/**
		 * Event handler for PokerBettingEvent.ROUND_DONE events dispatched from the current PokerBettingModule
		 * instance. This event is usually dispatched when a round has fully completed and all results and crypto
		 * keys are available.
		 * 
		 * @param	eventObj A PokerBettingEvent.ROUND_DONE event object.
		 */
		private function onRoundDone(eventObj:PokerBettingEvent):void 
		{			
			DebugView.addText("PokerCardGame.onRoundDone");
			new PokerGameStatusReport("Round has ended.", PokerGameStatusEvent.ROUNDEND).report();
			//any cleanup required before processing game results should go here
			processRoundResults();						
		}		
		
		/**
		 * Processes the results of the currently completed round of play.
		 */
		private function processRoundResults():void
		{			
			DebugView.addText("PokerCardGame.processRoundResults");
			var statusText:String = new String();
			_lastWinningPlayer = bettingModule.winningPlayerInfo;			
			_lastWinningPlayer.balance += bettingModule.communityPot;			
			var currencyFormat:CurrencyFormat = new CurrencyFormat();
			currencyFormat.setValue(_lastWinningPlayer.balance);
			currencyFormat.roundToFormat(_lastWinningPlayer.balance, CurrencyFormat.default_format);
			//don't use selfPlayerInfo from betting module in case we've been removed (busted)
			if (_lastWinningPlayer.netCliqueInfo.peerID == lounge.clique.localPeerInfo.peerID) {
				if (_lastWinningPlayer.lastResultHand!=null) {
					statusText = "I won with " + _lastWinningPlayer.lastResultHand.matchedDefinition.@name+": ";
				} else {
					statusText = "I won. All other players have folded.";
				}			
			} else {
				var truncatedPeerID:String = _lastWinningPlayer.netCliqueInfo.peerID;
				truncatedPeerID = truncatedPeerID.substr(0, 15) + "...";
				if (_lastWinningPlayer.lastResultHand!=null) {
					statusText = "Peer " + truncatedPeerID + " won with " + _lastWinningPlayer.lastResultHand.matchedDefinition.@name+": ";	
				} else {
					statusText = "Peer " + truncatedPeerID + " won. All other players have folded.";	
				}
			}
			if (_lastWinningPlayer.lastResultHand!=null) {
				for (var count:int = 0; count < _lastWinningPlayer.lastResultHand.matchedCards.length; count++) {
					var currentCard:ICard = _lastWinningPlayer.lastResultHand.matchedCards[count];
					if (currentCard!=null) {
						statusText += currentCard.cardName+",";
					}
				}
			}
			statusText = statusText.slice(0, statusText.length - 1);
			statusText += " - Winning player balance: " + currencyFormat.getString(CurrencyFormat.default_format);
			new PokerGameStatusReport(statusText, PokerGameStatusEvent.WIN, _lastWinningPlayer).report();
			//other UI elements may be updated here before continuing
			onProcessRoundResults();
		}
		
		/**
		 * Called when the round results have been fully processed and the next round is ready to begin. Round data are
		 * cleared and a final GAME_WIN event may be dispatched at this point.
		 */
		private function onProcessRoundResults():void
		{
			DebugView.addText("PokerCardGame.onProcessRoundResults");
			resetGame();
			var playersWithBalance:uint = 0;
			//must be done after a reset			
			for (var count:int = 0; count < _bettingModule.allPlayers.length; count++) {
				if (_bettingModule.allPlayers[count].balance > 0) {
					playersWithBalance++;
				}
			}			
			if (playersWithBalance > 1) {
				startNextRound();
			} else {
				bettingModule.currentSettings.clearCurrentTimer();				
				//don't use selfPlayerInfo from betting module in case we've been removed
				if (_lastWinningPlayer.netCliqueInfo.peerID == lounge.clique.localPeerInfo.peerID) {
					var statusText:String = "I won the pot! Total winnings: " + _lastWinningPlayer.balance;
				} else {
					statusText = "Player "+_lastWinningPlayer.netCliqueInfo.peerID+" won the pot. Total winnings: " + _lastWinningPlayer.balance;
				}
				_gameStatusLocked = false; //one final update to the status regardless of what's being displayed
				new PokerGameStatusReport(statusText, PokerGameStatusEvent.GAME_WIN, _lastWinningPlayer).report();
				//game has fully ended
			}
		}
		
		/**
		 * Unlocks the game status display to continue displaying new messages.
		 */
		protected function unlockGameStatus():void
		{
			_gameStatusLocked = false;
		}
		
		/**
		 * Resets the poker card game by clearing current community and player cards, resetting current card mappings,
		 * and cleaning up the current Player or Dealer instance.
		 * 
		 * @param	... args None currently used.
		 */
		private function resetGame(... args):void 
		{
			DebugView.addText("PokerCardGame.resetGame");
			clearPlayerCards();
			clearCommunityCards();
			bettingModule.removeZeroBalancePlayers();
			bettingModule.reset();			
			super.currentDeck.resetCardMappings();
			if (_player!=null) {
				_player.destroy();
			}
			_player = null;
		}
		
		/**
		 * Starts the next poker card game round or new game. The instance must be fully initialized or reset prior
		 * to calling this function.
		 */
		private function startNextRound():void 
		{
			DebugView.addText("PokerCardGame.startNextRound");
			bettingModule.updateBettingOrder();
			lounge.currentLeader = bettingModule.currentDealerMember;
			//comparing objects is unreliable so use peer ID instead
			if (lounge.currentLeader.peerID == lounge.clique.localPeerInfo.peerID) {
				DebugView.addText("   I am the new dealer.");
				lounge.leaderIsMe = true;
			} else {				
				lounge.leaderIsMe = false;
			}
			gamePhase = 1;
			start(true);
		}		
	}
}
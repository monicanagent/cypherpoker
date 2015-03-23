/**
* Main poker card game. Implements IBaseCardGame and makes extensive use of PokerBettingModule, Player, and Dealer.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package 
{
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.ICard;
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.interfaces.IPeerMessageLog;
	import interfaces.IPlayer;
	import flash.display.Loader;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import events.PokerBettingEvent;	
	import org.cg.Card;
	import org.cg.CurrencyFormat;	
	import org.cg.ImageButton;	
	import org.cg.BaseCardGame;
	import org.cg.GameSettings;	
	import p2p3.PeerMessageLog;
	import org.cg.DebugView;
	import flash.display.Bitmap;	
	import flash.utils.setTimeout;
	
	dynamic public class PokerCardGame extends BaseCardGame 
	{
				
		private var _player:IPlayer; //may be a Player or Dealer instance depending on this round of play
		private static var _gameLog:PeerMessageLog = new PeerMessageLog(); //main message log for peer messages
		private var _bettingModule:PokerBettingModule; //texas hold'em game betting logic
		private var _communityCards:Vector.<ICard> = null; //current community/public cards		
		private var _playerCards:Vector.<ICard> = null; //current player/private cards
		private var _commCardsContainer:MovieClip = null; //community cards display container
		private var _playerCardsContainer:MovieClip = null; //player cards display container		
		
		public function PokerCardGame():void 
		{
			//web
			//super.settingsFilePath = "./PokerCardGame/xml/settings.xml";
			//desktop - android
			super.settingsFilePath = "../PokerCardGame/xml/settings.xml";
			_bettingModule = new PokerBettingModule(this);
			_bettingModule.addEventListener(PokerBettingEvent.GAME_DONE, onGameDone);
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
				DebugView.addText  ("Parent container is not an org.cg.interfaces.ILounge implementation. Can't start game.");
				return (false);
			}			
			if (restart == false) {
				bettingModule.initialize();
			}
			if (lounge.leaderIsMe) {
				DebugView.addText  ("Assuming dealer role (Dealer type).");
				//initialize shift list for Sequential Member Operations...
				var shiftList:Vector.<INetCliqueMember> = super.getSMOShiftList();
				_player = new Dealer(this); //Dealer is a type of Player so this is valid
				var pcgMessage:PokerCardGameMessage = new PokerCardGameMessage();
				pcgMessage.createPokerMessage(PokerCardGameMessage.GAME_START);
				lounge.clique.broadcast(pcgMessage);
				_gameLog.addMessage(pcgMessage);
			} else {
				DebugView.addText  ("Assuming player role (Player type).");
				_player = new Player(this);				
			}
			_player.start();
			return (super.start());			
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
				_commCardsContainer.scaleX = 0.8;
				_commCardsContainer.scaleY = 0.8;
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
			cardItem.y = 350;
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
		 * Event handler for PokerBettingEvent.GAME_DONE events dispatched from the current PokerBettingModule
		 * instance. This event is usually dispatched when a game has fully completed and all results and crypto
		 * keys are available.
		 * 
		 * @param	eventObj A PokerBettingEvent.GAME_DONE event object.
		 */
		private function onGameDone(eventObj:PokerBettingEvent):void 
		{			
			DebugView.addText("PokerCardGame.onGameDone");			
			//display results, submit to Verity, etc., and then...
			resetGame();
			startNextGame();
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
			bettingModule.reset();			
			super.currentDeck.resetCardMappings();
			_player.destroy();
			_player = null;
		}
		
		/**
		 * Starts the next poker card game round or new game. The instance must be fully initialized or reset prior
		 * to calling this function.
		 */
		private function startNextGame():void 
		{
			DebugView.addText("PokerCardGame.startNextGame");
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
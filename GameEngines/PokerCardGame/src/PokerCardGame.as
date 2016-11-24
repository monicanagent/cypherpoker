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
	import org.cg.SmartContractDeferState;
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
	import org.cg.SmartContract;
	import org.cg.events.SmartContractEvent;
	import org.cg.CurrencyFormat;
	
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
		private var _activeSmartContracts:Vector.<SmartContract> = new Vector.<SmartContract>(); //currently active smart contracts
		private var _gameType:String = "ether"; //the game settings to use, as specified by the "type" attribute of the settings gametype nodes.
		protected var _deferStates:Array = new Array(); //smart contract defer states used regularly throughout a hand/round
		public var gameStatus:TextField; //dynamically generated
		
		//Default buy-in value for a new smart contract, in wei. May be overriden by existing smart contract buy-in. The value below represents 1 Ether.
		private var _smartContractBuyIn:String = "1000000000000000000";
		private var _smartContractTimeout:uint = 0; //timeout value, in seconds,
		
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
			DebugView.addText ("PokerCardGame instantiated.");			
		}		
		
		/**
		 * @return The main poker card game peer message log instance.
		 */
		public function get log():IPeerMessageLog 
		{
			return (_gameLog as IPeerMessageLog);
		}
		
		/**
		 * Instances of SmartContractDeferState instances used regularly throughout a hand/round (for example, those used to verify the
		 * existence of encrypted decks or selected cards). Temporary defer states should be appended to this array using the combineDeferStates method.
		 */
		public function get deferStates():Array {
			return (this._deferStates);
		}
		
		public function set deferStates(statesSet:Array):void {
			this._deferStates = statesSet;
		}
		
		/**
		 * Combines any number of defer state arrays into a single new state array. This is useful when checking for states that are
		 * not expected to change regularly (such as _deferStates), and more temporary smart contract state checks such as bet or pot values.
		 * 
		 * @param	args Any number of arrays to be combined into a new output array. The original arrays are not altered.
		 * 
		 * @return A new array containing a combination of the provided arrays.
		 */
		public function combineDeferStates(... args):Array {
			var returnArray:Array = new Array();
			if (args == null) {
				return (returnArray);
			}
			for (var count:int = 0; count < args.length; count++) {
				try {
					var currentArray:Array = args[count];
					for (var count2:int = 0; count2 < currentArray.length; count2++) {
						returnArray.push(currentArray[count2]);
					}
				} catch (err:*) {					
				}
			}
			return (returnArray);
		}
		
		/**
		 * Checks the deferred invocation state for smart contract initialiazation.
		 * 
		 * @param	deferObj A reference to the SmartContractDeferState instance containing the details of state to verify.
		 * 
		 * @return True if all required values are present, false otherwise.
		 */
		public function initializeDeferCheck (deferObj:SmartContractDeferState):Boolean {			
			var pass:Boolean = true;
			var primeVal:String = deferObj.smartContract.toHex.prime();
			var players:Array = new Array();
			var counter:uint = 0;
			var currentPlayer:String = deferObj.smartContract.players(counter);	
			//populate "players" array with addresses from current contract
			while (currentPlayer != "0x") {
				players.push(currentPlayer);
				counter++;
				currentPlayer = deferObj.smartContract.players(counter);
			}			
			if (players.length != deferObj.data.requiredPlayers.length) {
				return (false);
			}
			var baseCard:String = deferObj.smartContract.toHex.baseCard();			
			if (primeVal.toLowerCase() != deferObj.data.modulus.toLowerCase()) {				
				return (false)
			}
			if (baseCard.toLowerCase() != deferObj.data.baseCard.toLowerCase()) {				
				return (false)
			}			
			//ensure players match in order specified
			for (var count:int = 0; count < deferObj.data.requiredPlayers.length; count++) {
				if (deferObj.data.requiredPlayers[count] != players[count]) {
					return (false);
				}
			}			
			return (true);			
		}
		
		/**
		 * Performs a deferred invocation check on a smart contract to determine if specified player(s) have agreed to it.
		 * 
		 * @param	deferObj A reference to the defer state object containing a list of player(s) to check for agreement and a reference
		 * to the associated smart contract.
		 * 
		 * @return True of the included player(s) have agreed to the smart contract, false otherwise.
		 */
		public function agreeDeferCheck(deferObj:SmartContractDeferState):Boolean {
			for (var count:int = 0; count < deferObj.data.agreedPlayers.length; count++) {
				var currentPlayerAddress:String = deferObj.data.agreedPlayers[count];
				if (deferObj.smartContract.toBoolean.agreed(currentPlayerAddress) == false) {					
					return (false);
				}
			}			
			return (true);
		}

		/**
		 * Performs a deferred invocation check on a smart contract to determine if player(s) are at specific phase(s).
		 * 
		 * @param	deferObj A reference to the defer state object containing the player(s) and phase(s) to verify.
		 * 
		 * @return True of the included player(s) are at the specified game phase(s).
		 */
		public function phaseDeferCheck(deferObj:SmartContractDeferState):Boolean {	
		//	DebugView.addText ("phaseDeferCheck");
			var requiredPhases:Array = new Array();
			if ((deferObj.data.phases is Number) || (deferObj.data.phases is uint) || (deferObj.data.phases is int)) {
				//only one phase defined
				requiredPhases.push(uint(deferObj.data.phases));
			} else if (deferObj.data.phases is String) {
				//parse as string
				var phasesSplit:Array = deferObj.data.phases.split(",");
				for (var count:int = 0; count < phasesSplit.length; count++) {
					requiredPhases.push(uint(phasesSplit[count]));
				}
			} else {
				//assume it's an array
			 	requiredPhases = deferObj.data.phases;				
			}
			//DebugView.addText ("   Required Phases: " + requiredPhases);			
			if (deferObj.data.account == "all") {
				var phaseFound:Boolean = false;
				var playerInfoList:Vector.<IPokerPlayerInfo> = bettingModule.nonFoldedPlayers;
				for (count = 0; count < playerInfoList.length; count++) {
					phaseFound = false;
					var currentPeerID:String = playerInfoList[count].netCliqueInfo.peerID;
					var account:String = lounge.ethereum.getAccountByPeerID(currentPeerID);					
					var phaseString:String = deferObj.smartContract.toString.phases(account);
					var phase:uint = uint(phaseString);
					//DebugView.addText ("Phase for account "+account+": " + phase);
					for (var count2:int = 0; count2 < requiredPhases.length; count2++) {
						var currentPhase:uint = uint(requiredPhases[count2]);
						if (currentPhase == phase) {
							//DebugView.addText ("    required phase " + phase+" found!");
							phaseFound = true;
						}
					}
					if (phaseFound == false) {
					//	DebugView.addText ("   account " + account + " is not ar required phase");
						return (false);
					}
				}
				//DebugView.addText ("   All players are at required phase.");
				return (true);
			} else {				
				phaseString = deferObj.smartContract.toString.phases(deferObj.data.account);				
				phase = uint(phaseString);
				//DebugView.addText ("Phase for account "+deferObj.data.account+": " + phase);
				for (count2 = 0; count2 < requiredPhases.length; count2++) {
					currentPhase = uint(requiredPhases[count2]);
					if (currentPhase == phase) {
						//DebugView.addText ("    required phase " + phase+" found!");
						return (true);
					}
				}
			}
			return (false);
		}
		
		/**
		 * Performs a deferred invocation check on a smart contract's pot value.
		 * 
		 * @param	deferObj A reference to the defer state object containing the expected pot value (in wei).
		 * 
		 * @return True if the smart contract pot value matches the expected value.
		 */
		public function potDeferCheck(deferObj:SmartContractDeferState):Boolean {	
			//DebugView.addText ("potDeferCheck");
			var currentPotValue:String = deferObj.smartContract.toString.pot();
			//DebugView.addText ("Current pot value: " + currentPotValue);
			//DebugView.addText ("Expected pot value: " + deferObj.data.pot);
			if (currentPotValue == deferObj.data.pot) {
				return (true);
			} else {
				return (false);
			}
		}
		
		/**
		 * Performs a deferred invocation check on a smart contract's betting position value.
		 * 
		 * @param	deferObj A reference to the defer state object containing the expected position.
		 * 
		 * @return True if the smart contract bet position matches the expected value.
		 */
		public function betPositionCheck(deferObj:SmartContractDeferState):Boolean {	
		//	DebugView.addText ("betPositionCheck for: "+this.ethereumAccount);
			var currentPositionValue:int = int(deferObj.smartContract.toString.betPosition());
			//DebugView.addText ("Current bet position: " + currentPositionValue);
		//	DebugView.addText ("Expected bet position: " + deferObj.data.position);
			if (currentPositionValue == deferObj.data.position) {
				return (true);
			} else {
				return (false);
			}
		}
		
		/**
		 * Performs a deferred invocation check on a smart contract to determine if specified encrypted cards have been stored.
		 * 
		 * @param	deferObj A reference to the defer state object containing a list of cards ("cards" property) to check and the storage variable
		 * ("storageVariable" property) that should contain them.
		 * 
		 * @return True of the specified encrypted cards have been stored in the contract, false otherwise.
		 */
		public function encryptedCardsDeferCheck(deferObj:SmartContractDeferState):Boolean {
		//	DebugView.addText ("encryptedCardsDeferCheck");
		//	DebugView.addText ("Checking for encrypted cards in: " + deferObj.data.storageVariable);
	//		DebugView.addText ("Expecting cards: " + deferObj.data.cards);
			var storedCards:Array = new Array();
			if (deferObj.data.storageVariable == "encryptedDeck") {				
				var numCards:int = 52;
			} else if (deferObj.data.storageVariable == "privateCards") {				
				numCards = 2;
			} else {
				numCards = 5; //public cards
			}
			var exactLength:Boolean = false;
			if (deferObj.data["exactLength"] != undefined) {
				exactLength = deferObj.data.exactLength;
			}
			//DebugView.addText ("Using exact length: " + exactLength);
			//DebugView.addText("Checking number of cards: " + numCards);
			for (var count:int = 0; count < numCards; count++) {
				var storedCard:String;
				switch (deferObj.data.storageVariable) {
					case "encryptedDeck" : 						
						storedCard = deferObj.smartContract.toHex.encryptedDeck(deferObj.data.fromAddress, count);
						break;
					case "privateCards" : 
						storedCard = deferObj.smartContract.toHex.privateCards(deferObj.data.fromAddress, count);						
						break;
					case "publicCards" : 
						storedCard = deferObj.smartContract.toHex.publicCards(count);						
						break;
					case "publicDecryptCards" : 
						storedCard = deferObj.smartContract.toHex.publicDecryptCards(deferObj.data.fromAddress, count);						
						break;
					default: 
						DebugView.addText ("Unsupported smart contract storage variable \"" + deferObj.data.storageVariable+"\"");
						break;
				}								
				storedCards.push(storedCard);				
			}	
		//	DebugView.addText ("Stored cards for address \""+deferObj.data["fromAddress"]+"\": " + storedCards);
			if ((deferObj.data.cards.length != storedCards.length) && (exactLength)) {
			//	DebugView.addText ("Exact length mismatch");
				return (false);
			}
		//	DebugView.addText ("Comparing to: " + deferObj.data.cards);
			for (count = 0; count < deferObj.data.cards.length; count++) {
				var found:Boolean = false;
				var currentCard:String = deferObj.data.cards[count];
				currentCard=currentCard.toLowerCase();				
				for (var count2:int = 0; count2 < storedCards.length; count2++) {					
					var compareCard:String = storedCards[count2];					
					compareCard.toLowerCase();				
					if (compareCard == currentCard) {					
						found = true;
					}
				}
				if (found == false) {
				//	DebugView.addText("Card not found: " + currentCard);
					return (false);
				}
			}
			return (true);
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
		 * The currently active Ethereum smart contract being used for game play. 
		 */
		public function get activeSmartContract():SmartContract {
			return (this._activeSmartContracts[0]);
		}
		
		public function set activeSmartContract(contractSet:SmartContract):void {
			if (contractSet != null) {
				this._activeSmartContracts.unshift(contractSet);
			}
		}
		
		/**
		 * The default smart contract action timeout, in blocks, as set in the settings data. The Dealer class instance uses this value to
		 * initialize new / available contracts. Each new block is equivalent to approximately 12 seconds but may be longer so blocks are used instead of
		 * time offsets or increments.
		 * 
		 * The timeout value set in a specific contract may be retrieved through: web3.contract.timeoutBlocks(). The game must interact with the smart contract within this
		 * time limit otherwise it will be considered to have timed / dropped out and will suffer any associated penalties. Currently, smart contracts
		 * impose a minimum value of 2 blocks for the timeout but it's advisable to use a higher number.
		 */
		public function get smartContractActionTimeout():uint {
			if (this._smartContractTimeout == 0) {
				var timeoutStr:String = GameSettings.getSetting("defaults", "smartcontracttimeout").children().toString();
				this._smartContractTimeout = uint(timeoutStr);
			}
			return (this._smartContractTimeout);
		}
		
		public function set smartContractActionTimeout(timeoutSet:uint):void {
			this._smartContractTimeout = timeoutSet;
		}

		/**
		 * The smart contract buy-in value to use when initializing or agreeing to a new contract. This may already be a part of the contract or
		 * may be set prior to initialization. May not apply to all contract types.
		 */
		public function get smartContractBuyIn():String {
			return (this._smartContractBuyIn);
		}
		
		public function set smartContractBuyIn(buyInSet:String):void {
			this._smartContractBuyIn = buyInSet;
		}
		
		/**
		 * The current account being used to interact with Ethereum. This account must have a sufficient balance for the various interactions
		 * that may happen during game play.
		 */
		public function get ethereumAccount():String {
			return (lounge.ethereum.account);
		}
		
		/**
		 * The password associated with "ethereumAccount". If this value is null or an empty string a dialog box or other type of prompt
		 * should be displayed to the player with a password input field.
		 */
		public function get ethereumPassword():String {
			return (lounge.ethereum.password);
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
			SmartContract.ethereum = lounge.ethereum;
			if (restart == false) {
				new PokerGameStatusReport("Starting new game.", PokerGameStatusEvent.ROUNDSTART).report();
				bettingModule.initialize();
				bettingModule.setSettingsByType(this._gameType);
			} else {
				new PokerGameStatusReport("Starting new round.", PokerGameStatusEvent.ROUNDSTART).report();
			}			
			if (lounge.leaderIsMe) {
				DebugView.addText  ("Assuming dealer role (Dealer type).");				
				this.deployNewHandContract();				
			} else {
				DebugView.addText  ("Assuming player role (Player type).");				
				new PokerGameStatusReport("I'm a player.").report();				
				_player = new Player(this);	
				_player.start();
			}			
			return (super.start());			
		}	
		
		/**
		 * Deploys a new poker hand contract to the Ethereum blockchain.
		 * 
		 * @param	contractName The name of the contract to deploy. Default is "PokerHandBI".
		 */
		public function deployNewHandContract(contractName:String = "PokerHandBI"):void {
			var contractDesc:XML = SmartContract.getValidatedDescriptor(contractName, "ethereum", lounge.ethereum.client.networkID, "new", true);
			if (contractDesc != null) {
				//available unused smart contract exists
				this._activeSmartContracts.unshift(new SmartContract(contractName, this.ethereumAccount, this.ethereumPassword, contractDesc));
			} else {
				//new smart contract must be deployed
				this._activeSmartContracts.unshift(new SmartContract(contractName, this.ethereumAccount, this.ethereumPassword));
			}			
			this.activeSmartContract.addEventListener(SmartContractEvent.READY, this.onSmartContractReady);
			this.activeSmartContract.networkID = lounge.ethereum.client.networkID; //use whatever network ID is currently being used by client
			this.activeSmartContract.create();
		}
		
		/**
		 * Event listener invoked when an available smart contract has been deployed and/or verified and is ready for use.
		 * 
		 * @param	eventObj A SmartContractEvent object.
		 */
		private function onSmartContractReady(eventObj:SmartContractEvent):void {
			this.activeSmartContract.removeEventListener(SmartContractEvent.READY, this.onSmartContractReady);
			DebugView.addText("PokerCardGame.onSmartContractReady");
			DebugView.addText("Descriptor: " + eventObj.descriptor);
			var buyInVal:String = this.activeSmartContract.toString.buyIn();
			if (buyInVal == "0") {
				DebugView.addText ("Contract buy-in no specified. Using default value.");
			} else {
				DebugView.addText ("Contract buy-in set to: " + buyInVal);
				this.smartContractBuyIn = buyInVal;				
			}
			var buyInNode:XML = new XML("<buyin>"+this.smartContractBuyIn+"</buyin>");
			eventObj.descriptor.appendChild(buyInNode);
			new PokerGameStatusReport("I'm the dealer. Sending start game message.").report();
			//initialize shift list for Sequential Member Operations...
			var shiftList:Vector.<INetCliqueMember> = super.getSMOShiftList();
			_player = new Dealer(this); //Dealer is a type of Player so this is valid
			_player.start();
			var pcgMessage:PokerCardGameMessage = new PokerCardGameMessage();
			pcgMessage.createPokerMessage(PokerCardGameMessage.GAME_START, eventObj.descriptor.toXMLString());
			lounge.clique.broadcast(pcgMessage);
			_gameLog.addMessage(pcgMessage);
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
		
		override public function initialize(... args):void {
			DebugView.addText("PokerCardGame.initialize");			
			super.initialize.apply(super, args);
			SmartContract.ethereum = lounge.ethereum;
		}
	}
}
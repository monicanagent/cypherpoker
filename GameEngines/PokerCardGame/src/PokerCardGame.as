/**
* Main poker card game. Implements IBaseCardGame and makes extensive use of PokerBettingModule, Player, and Dealer.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package {
	
	import com.bit101.components.List;
	import events.PokerGameStatusEvent;
	import events.PokerGameVerifierEvent;
	import feathers.controls.Alert;
	import feathers.data.ListCollection;
	import org.cg.Table;
	import org.cg.events.SettingsEvent;
	import flash.events.KeyboardEvent;
	import org.cg.StarlingViewManager;
	import flash.text.TextField;
	import org.cg.SmartContractDeferState;
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.ICard;
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.interfaces.IPeerMessageLog;	
	import interfaces.IPlayer;
	import interfaces.IPokerPlayerInfo;	
	import org.cg.StarlingContainer;
	import starling.display.Sprite;
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
	import PokerGameVerifier;
	//Poker card game widgets (must be defined below in order to be available at runtime!)
	import org.cg.widgets.*;
	CardsDisplayWidget;
	BettingControlsWidget;
	BettingInfoWidget;
	PlayerInfoBarWidget;
	GameStatusWidget;
	
	dynamic public class PokerCardGame extends BaseCardGame {
		
		//Constants used with SMO list operations
		public static const SMO_SHIFTSELFTOEND:int = 1; //Shift self to end of SMO list.
		public static const SMO_SHIFTSELFTOSTART:int = 2; //Shift self to start of SMO list.
		public static const SMO_REMOVESELF:int = 3; //Remove self from SMO list.
		public static const SMO_SHIFTNEXTPLAYERTOEND:int = 4; //Move next player after self to end. List is unchanged if self is not in list.
		//public var gameStatus:TextField; //dynamically generated
		private static var _gameLog:PeerMessageLog = new PeerMessageLog(); //main message log for peer messages
		protected var _deferStates:Array = new Array(); //smart contract defer states used regularly throughout a hand/round		
		private var _player:IPlayer; //may be a Player or Dealer instance depending on this round of play		
		private var _bettingModule:PokerBettingModule; //texas hold'em game betting logic
		private var _communityCards:Vector.<ICard> = null; //current community/public cards		
		private var _playerCards:Vector.<ICard> = null; //current player/private cards
		private var _commCardsContainer:Sprite = null; //community cards display container
		private var _playerCardsContainer:Sprite = null; //player cards display container
		private var _lastWinningPlayer:IPokerPlayerInfo = null; //available at end of every round, before a new round begins
		//private var _gameStatusLocked:Boolean = false; //should status updates be locked?
		//private var _gameStatusLockTimeoutID:uint = 0; //timer ID of current status updates lock
		private var _activeSmartContracts:Vector.<SmartContract> = new Vector.<SmartContract>(); //currently active smart contracts ([0] is the most current)
		private var _activeGameVerifiers:Vector.<PokerGameVerifier> = new Vector.<PokerGameVerifier>(); //currently active local game verifiers ([0] is the most current)
		//Control/judge contracts athorized to interact with the currently active (data) contract; getters available for all:
		private var _validatorContract:SmartContract = null; //PokerHandValidator
		private var _startupContract:SmartContract = null; //PokerHandStartup
		private var _actionsContract:SmartContract = null; //PokerHandActions
		private var _resolutionsContract:SmartContract = null; //PokerHandResolutions
		//private var _gameType:String = "ether"; //the game settings to use, as specified by the "type" attribute of the settings gametype nodes.		
		//Default buy-in value for a new smart contract, in wei. May be overriden by existing smart contract buy-in. The value below represents 1 Ether.
		private var _smartContractBuyIn:String = "1000000000000000000";
		private var _smartContractTimeout:uint = 0; //timeout value, in seconds,
		private var _txSigningEnabled:Boolean = false; //is Ethereum transaction signing/verification enabled?
		
		public function PokerCardGame():void {			
			if (GlobalSettings.systemSettings.isWeb) {
				super.settingsFilePath = "./PokerCardGame/xml/settings.xml";
			} else {
				super.settingsFilePath = "../PokerCardGame/xml/settings.xml";
			}
			_bettingModule = new PokerBettingModule(this);
			_bettingModule.addEventListener(PokerBettingEvent.ROUND_DONE, onRoundDone);
			DebugView.addText ("PokerCardGame instantiated.");
		}		
		
		/**
		 * @return The main poker card game peer message log instance.
		 */
		public function get log():IPeerMessageLog {
			return (_gameLog as IPeerMessageLog);
		}
		
		/**
		 * Instances of SmartContractDeferState instances used regularly throughout a hand/round (for example, those used to verify the
		 * existence of encrypted decks or selected cards). Temporary defer states should be appended to this array using the combineDeferStates method.
		 */
		public function get deferStates():Array {
			if (this._deferStates == null) {
				this._deferStates = new Array();
			}
			return (this._deferStates);
		}
		
		public function set deferStates(statesSet:Array):void {
			this._deferStates = statesSet;
		}
		
		/**
		 * If true, transaction signing and verification are enabled otherwise no transactions are signed or verified
		 * even when Ethereum is enabled and being used.
		 */
		public function get txSigningEnabled():Boolean {
			return (this._txSigningEnabled);
		}
		
		public function set txSigningEnabled(signingSet:Boolean):void {		
			this._txSigningEnabled = signingSet;
		}
		
		/**
		 * Initializes the instance.
		 * 
		 * @param	... args Any arguments passed by the parent Lounge instance with which to initialize the game.
		 */
		override public function initialize(... args):void {
			DebugView.addText("PokerCardGame.initialize");			
			super.initialize.apply(super, args);
			if ((table.smartContractAddress != "") && (table.smartContractAddress != null)) {
				SmartContract.ethereum = lounge.ethereum;
				super._ethereum = lounge.ethereum;
				for (var count:int = 0; count < this.table.playersInfo.length; count++) {
					this.ethereum.mapPeerID(this.table.playersInfo[count].ethereumAccount, this.table.playersInfo[count].peerID);
				}
			} else {
				//don't use Ethereum even if enabled since no smart contract address is provided
				SmartContract.ethereum = null;
				super._ethereum = null;
			}
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
			DebugView.addText ("initializeDeferCheck");
			var pass:Boolean = true;
			var primeVal:String = deferObj.operationContract.toHex.prime();
			var players:Array = new Array();
			var counter:uint = 0;
			var currentPlayer:String = deferObj.operationContract.players(counter);
			var matchingAuthContracts:uint = 0;
			DebugView.addText ("this.startupContract.address=" + this.startupContract.address);
			for (var count:int = 0; count < int(deferObj.operationContract.numAuthorizedContracts()); count++) {
				DebugView.addText ("   Checking: " + deferObj.operationContract.authorizedGameContracts(count));
				if (deferObj.operationContract.authorizedGameContracts(count) == this.startupContract.address) {
					matchingAuthContracts++;
				} else if (deferObj.operationContract.authorizedGameContracts(count) == this.actionsContract.address) {
					matchingAuthContracts++;
				} else if (deferObj.operationContract.authorizedGameContracts(count) == this.resolutionsContract.address) {
					matchingAuthContracts++;
				} else if (deferObj.operationContract.authorizedGameContracts(count) == this.validatorContract.address) {
					matchingAuthContracts++;
				} else {
					//no match
				}
			}
			if ((matchingAuthContracts != 4) || (int(deferObj.operationContract.numAuthorizedContracts()) != 4 )) {
				DebugView.addText ("   Failed due to authorized contract check. This could indicate a serious security problem.");
				return (false);
			}
			//check for uniqueness
			for (count = 0; count < int(deferObj.operationContract.numAuthorizedContracts()); count++) {
				var currentContract:String = String (deferObj.operationContract.authorizedGameContracts(count));
				for (var count2:int = count+1; count2 < int(deferObj.operationContract.numAuthorizedContracts()); count2++) {
					var compareContract:String = String (deferObj.operationContract.authorizedGameContracts(count2));
					if (currentContract == compareContract) {
						DebugView.addText ("   Failed due to duplication of contract: " + currentContract);
						return (false);
					}
				}
				
			}
			//populate "players" array with addresses from current contract
			while (currentPlayer != "0x") {
				players.push(currentPlayer);
				counter++;
				currentPlayer = deferObj.operationContract.players(counter);
			}			
			if (players.length != deferObj.data.requiredPlayers.length) {
				DebugView.addText ("wrong length");
				DebugView.addText ("players.length="+players.length);
				DebugView.addText ("deferObj.data.requiredPlayers.length="+deferObj.data.requiredPlayers.length);
				return (false);
			}
			var baseCard:String = deferObj.operationContract.toHex.baseCard();			
			if (primeVal.toLowerCase() != deferObj.data.modulus.toLowerCase()) {				
				DebugView.addText ("wrong modulus");
				DebugView.addText ("primeVal.toLowerCase()=" + primeVal.toLowerCase());
				DebugView.addText ("deferObj.data.modulus.toLowerCase()="+deferObj.data.modulus.toLowerCase());
				return (false)
			}
			if (baseCard.toLowerCase() != deferObj.data.baseCard.toLowerCase()) {	
				DebugView.addText ("wrong base card");
				DebugView.addText ("baseCard.toLowerCase()=" + baseCard.toLowerCase());
				DebugView.addText ("deferObj.data.baseCard.toLowerCase()="+deferObj.data.baseCard.toLowerCase());
				return (false)
			}			
			//ensure players match in order specified
			for (count = 0; count < deferObj.data.requiredPlayers.length; count++) {
				if (deferObj.data.requiredPlayers[count] != players[count]) {
					DebugView.addText ("wrong player order");
					DebugView.addText("players=" + players);
					DebugView.addText("deferObj.data.requiredPlayers=" + deferObj.data.requiredPlayers);
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
				if (deferObj.operationContract.toBoolean.agreed(currentPlayerAddress) == false) {					
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
		 * @return True if the included player(s) are at the specified game phase(s).
		 */
		public function phaseDeferCheck(deferObj:SmartContractDeferState):Boolean {			
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
			if (deferObj.data.account == "all") {
				var phaseFound:Boolean = false;
				var playerInfoList:Vector.<IPokerPlayerInfo> = bettingModule.nonFoldedPlayers;
				for (count = 0; count < playerInfoList.length; count++) {
					phaseFound = false;
					var currentPeerID:String = playerInfoList[count].netCliqueInfo.peerID;
					if (ethereum != null) {
						var account:String = ethereum.getAccountByPeerID(currentPeerID);
					} else {
						account = "0x"; //null
					}
					var phaseString:String = deferObj.operationContract.toString.phases(account);
					var phase:uint = uint(phaseString);					
					if ((requiredPhases == null) || (requiredPhases["length"] == undefined) || (requiredPhases["length"] == null)) {
						return (false);
					}
					for (var count2:int = 0; count2 < requiredPhases.length; count2++) {
						var currentPhase:uint = uint(requiredPhases[count2]);
						if (currentPhase == phase) {							
							phaseFound = true;
						}
					}
					if (phaseFound == false) {					
						return (false);
					}
				}				
				return (true);
			} else {				
				phaseString = deferObj.operationContract.toString.phases(deferObj.data.account);				
				phase = uint(phaseString);				
				for (count2 = 0; count2 < requiredPhases.length; count2++) {
					currentPhase = uint(requiredPhases[count2]);
					if (currentPhase == phase) {						
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
			var currentPotValue:String = deferObj.operationContract.toString.pot();			
			if (currentPotValue == deferObj.data.pot) {
				return (true);
			} else {
				return (false);
			}
		}		
		
		/**
		 * Performs a deferred invocation check on a smart contract's hasTimedOut value via an external
		 * accessor (PokerHandResolutions).
		 * 
		 * @param	deferObj A reference to the defer state object. The accessor hasTimedOut function
		 * is invoked by the "operationContract" and the "dataContract" is used as the data contract address
		 * paramater (dataAddr).
		 * 
		 * @return True if the smart contract has timed out, false otherwise.
		 */
		public function timeoutDeferCheck(deferObj:SmartContractDeferState):Boolean {
			return(deferObj.operationContract.toBool.hasTimedOut(deferObj.dataContract.address));			
		}
		
		/**
		 * Performs a deferred invocation check on a smart contract's betting position value.
		 * 
		 * @param	deferObj A reference to the defer state object containing the expected position.
		 * 
		 * @return True if the smart contract bet position matches the expected value.
		 */
		public function betPositionDeferCheck(deferObj:SmartContractDeferState):Boolean {			
			var currentPositionValue:int = int(deferObj.operationContract.toString.betPosition());		
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
			for (var count:int = 0; count < numCards; count++) {
				var storedCard:String;
				switch (deferObj.data.storageVariable) {
					case "encryptedDeck" : 						
						storedCard = deferObj.operationContract.toHex.encryptedDeck(deferObj.data.fromAddress, count);
						break;
					case "privateCards" : 
						storedCard = deferObj.operationContract.toHex.privateCards(deferObj.data.fromAddress, count);						
						break;
					case "publicCards" : 
						storedCard = deferObj.operationContract.toHex.publicCards(count);						
						break;
					case "publicDecryptCards" : 
						storedCard = deferObj.operationContract.toHex.publicDecryptCards(deferObj.data.fromAddress, count);						
						break;
					default: 
						DebugView.addText ("Unsupported smart contract storage variable \"" + deferObj.data.storageVariable+"\"");
						break;
				}								
				storedCards.push(storedCard);				
			}			
			if ((deferObj.data.cards.length != storedCards.length) && (exactLength)) {			
				return (false);
			}		
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
					return (false);
				}
			}
			return (true);
		}
		
		
		/**
		 * @return The current PokerBettingModule instance being used by the game.
		 */
		public function get bettingModule():PokerBettingModule {
			return (_bettingModule);
		}
		
		/**
		 * Gets the current game verifier (index 0), from the _activeGameVerifiers vector array.
		 */
		public function get currentGameVerifier():PokerGameVerifier {
			return (this._activeGameVerifiers[0]);
		}
		
		/**
		 * @return A list of the local player's (self's) current private cards, or null if none have been dealt.
		 */
		public function get playerCards():Vector.<ICard> {
			return (_playerCards);
		}
		
		/**
		 * @return A list of the current community/public cards, or null if none have been dealt.
		 */
		public function get communityCards():Vector.<ICard> {
			return (_communityCards);
		}
		
		/**
		 * The currently active Ethereum smart contract (PokerHandData) being used for game play. 
		 */
		public function get activeSmartContract():SmartContract {
			if (this._activeSmartContracts == null) {
				return (null);
			}
			if (this._activeSmartContracts.length == 0) {
				return (null);
			}
			return (this._activeSmartContracts[0]);
		}
		
		public function set activeSmartContract(contractSet:SmartContract):void {
			if (contractSet != null) {
				this._activeSmartContracts.unshift(contractSet);
				super.dispatchStatusEvent(PokerGameStatusEvent.NEW_CONTRACT, this, {contract:contractSet});
			}
		}
		
		/**
		 * All SmartContract PokerHandData instances being tracked by the game. Not all contracts may be in use or valid.
		 */
		public function get smartContracts():Vector.<SmartContract> {
			return (this._activeSmartContracts);
		}		
		
		/**
		 * The current PokerHandActions contract in use. If one doesn't exist then it is created using global
		 * (Lounge) settings data for the current network. If Ethereum is not available, or no validator contract
		 * exists and can't be created, then null is returned.
		 */
		public function get resolutionsContract():SmartContract {			
			if (this._resolutionsContract != null) {
				return (this._resolutionsContract);
			}
			if (lounge.ethereum == null) {
				return (null);
			}
			var descriptor:XML = SmartContract.getValidatedDescriptor("PokerHandResolutions", "ethereum", lounge.ethereum.client.networkID, "*", "library", false);
			if (descriptor != null) {
				this._resolutionsContract = new SmartContract("PokerHandResolutions", ethereumAccount, ethereumPassword, descriptor);
			}
			return (this._resolutionsContract);
		}
		
		/**
		 * The current PokerHandActions contract in use. If one doesn't exist then it is created using global
		 * (Lounge) settings data for the current network. If Ethereum is not available, or no validator contract
		 * exists and can't be created, then null is returned.
		 */
		public function get actionsContract():SmartContract {			
			if (this._actionsContract != null) {
				return (this._actionsContract);
			}
			if (lounge.ethereum == null) {
				return (null);
			}
			var descriptor:XML = SmartContract.getValidatedDescriptor("PokerHandActions", "ethereum", lounge.ethereum.client.networkID, "*", "library", false);
			if (descriptor != null) {
				this._actionsContract = new SmartContract("PokerHandActions", ethereumAccount, ethereumPassword, descriptor);
			}
			return (this._actionsContract);
		}
		
		/**
		 * The current PokerHandStartup contract in use. If one doesn't exist then it is created using global
		 * (Lounge) settings data for the current network. If Ethereum is not available, or no validator contract
		 * exists and can't be created, then null is returned.
		 */
		public function get startupContract():SmartContract {			
			if (this._startupContract != null) {
				return (this._startupContract);
			}
			if (lounge.ethereum == null) {
				return (null);
			}
			var descriptor:XML = SmartContract.getValidatedDescriptor("PokerHandStartup", "ethereum", lounge.ethereum.client.networkID, "*", "library", false);
			if (descriptor != null) {
				this._startupContract = new SmartContract("PokerHandStartup", ethereumAccount, ethereumPassword, descriptor);
			}
			return (this._startupContract);
		}
		
		/**
		 * The current PokerHandValidator contract in use. If one doesn't exist then it is created using global
		 * (Lounge) settings data for the current network. If Ethereum is not available, or no validator contract
		 * exists and can't be created, then null is returned.
		 */
		public function get validatorContract():SmartContract {			
			if (this._validatorContract != null) {
				return (this._validatorContract);
			}
			if (lounge.ethereum == null) {
				return (null);
			}
			var descriptor:XML = SmartContract.getValidatedDescriptor("PokerHandValidator", "ethereum", lounge.ethereum.client.networkID, "*", "library", false);
			if (descriptor != null) {
				this._validatorContract = new SmartContract("PokerHandValidator", ethereumAccount, ethereumPassword, descriptor);
			}
			return (this._validatorContract);
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
			if (ethereum != null) {
				return (ethereum.account);
			} else {
				return ("0x");
			}
		}
		
		/**
		 * The password associated with "ethereumAccount". If this value is null or an empty string a dialog box or other type of prompt
		 * should be displayed to the player with a password input field.
		 */
		public function get ethereumPassword():String {
			if (ethereum != null) {
				return (ethereum.password);
			} else {
				return ("");
			}
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
		override public function start(restart:Boolean=false):Boolean {
			DebugView.addText ("PokerCardGame.start");			
			if ((lounge is ILounge) == false) {
				DebugView.addText  ("   Parent container is not an org.cg.interfaces.ILounge implementation. Can't start game.");
				return (false);
			}
			SmartContract.ethereum = lounge.ethereum; //may be null!			
			if (restart == false) {
				bettingModule.initialize();
				//bettingModule.setSettingsByType(this._gameType);
			} 	
			if (table.dealerIsMe) {
				DebugView.addText  ("   Assuming dealer role (Dealer type).");							
				this.onSmartContractReady(null);				
			} else {
				DebugView.addText  ("   Assuming player role (Player type).");			
				_player = new Player(this);	
				_player.start();
			}
			this._activeGameVerifiers.unshift(new PokerGameVerifier());
			return (super.start());			
		}
		
		/**
		 * Callback function invoked by the StarlingViewManager when the default view has been rendered.
		 */
		override public function onRenderDefaultView():void {
			try {
				//not all elements may be available so use try..catch				
			} catch (err:*) {				
			}
		}
		
		/**
		 * Destroys the game instance by removing event listeners and clearing unused memory. This is usually
		 * the last function to be called before the game is removed from memory.
		 */
		override public function destroy():void	{
			this.dispatchStatusEvent(PokerGameStatusEvent.DESTROY, this);
			_bettingModule.removeEventListener(PokerBettingEvent.ROUND_DONE, onRoundDone);			
			if (_player!=null) {
				_player.destroy(true);
			}
			_player = null;
			_bettingModule = null;
			reset();
			super.destroy();
		}
		
		/**
		 * Deploys a new poker hand contract to the Ethereum blockchain.
		 * 
		 * @param	contractName The name of the contract to deploy. Default is "PokerHandData".
		 */
		public function deployNewHandContract(contractName:String = "PokerHandData"):void {
			DebugView.addText("PokerCardGame.deployNewHandContract: " + contractName);
			var contractDesc:XML = SmartContract.getValidatedDescriptor(contractName, "ethereum", lounge.ethereum.client.networkID, "new", "contract", true);
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
		 * Adds one or more cards to the current list of community/public cards.
		 * 
		 * @param	cards The card(s) to add to the community card list.
		 */
		public function addToCommunityCards(cards:Vector.<ICard>):void {
			if (_communityCards == null) {
				_communityCards = new Vector.<ICard>();
			}
			var existingCards:Vector.<ICard> = new Vector.<ICard>();
			var mappings:Vector.<String> = new Vector.<String>();
			for (var count:uint = 0; count < _communityCards.length; count++) {
				existingCards.push(_communityCards[count]);
			}
			for (count = 0; count < cards.length; count++) {
				_communityCards.push(cards[count]);
				mappings.push(currentDeck.getMappingByCard(cards[count]));
			}
			this.dispatchStatusEvent(PokerGameStatusEvent.DECRYPTED_PUBLIC_CARDS, this, {cards:cards, mappings:mappings, existingCards:existingCards});			
		}
		
		/**
		 * Adds one or more cards to the current list of player/private cards.
		 * 
		 * @param	cards The card(s) to add to the player card list.
		 */
		public function addToPlayerCards(cards:Vector.<ICard>):void {
			if (_playerCards == null) {
				_playerCards = new Vector.<ICard>();
			}
			var mappings:Vector.<String> = new Vector.<String>(); 
			for (var count:uint = 0; count < cards.length; count++) {
				_playerCards.push (cards[count]);
				mappings.push(currentDeck.getMappingByCard(cards[count]));
			}
			this.dispatchStatusEvent(PokerGameStatusEvent.DECRYPTED_PRIVATE_CARDS, this, {cards:_playerCards, mappings:mappings});
		}
		
		/**
		 * Clears the current list of community/public cards from the display list and flips them face down for re-use.
		 */
		public function clearCommunityCards():void {
			this.dispatchStatusEvent(PokerGameStatusEvent.CLEAR_CARDS, this, {community:true});
			if (_communityCards == null) {
				return;
			}			
			_communityCards = new Vector.<ICard>();
		}
		
		/**
		 * Clears the current list of player/private cards from the display list and flips them face down for re-use.
		 */
		public function clearPlayerCards():void {
			this.dispatchStatusEvent(PokerGameStatusEvent.CLEAR_CARDS, this, {hole:true});
			if (_playerCards == null) {
				return;
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
		public function changePlayerToDealer(initObject:Object, invokeAfterInitialize:String = null):Boolean {
			if (_player is Dealer) {
				return (false);
			}
			//new PokerGameStatusReport("Changing from player to dealer.").report();
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
		 * Sets default values for the poker card game and invokes the setDefaults function in the super class.
		 * 
		 * @param	eventObj An Event.ADDED_TO_STAGE event object.
		 */
		override protected function setDefaults(eventObj:Event = null):void {
			DebugView.addText  ("PokerCardGame.setDefaults");			
			super.setDefaults(eventObj);			
		}
		
		override protected function onLoadSettings(eventObj:SettingsEvent):void {
			DebugView.addText ("PokerCardGame.onLoadSettings");
			var defaultGameView:XML = GameSettings.getSetting("views", "defaultgame");
			var defaultGameViewItems:XMLList = defaultGameView.children();
			for (var count:int = 0; count < defaultGameViewItems.length(); count++) {
				var currentViewItem:XML = defaultGameViewItems[count];
				StarlingViewManager.render(currentViewItem, this.lounge);
			}			
			super.onLoadSettings(eventObj);
		}
		
		override protected function onFatalGameError(errorSource:*, infoObj:Object):void {
			var alert:Alert = StarlingViewManager.alert(infoObj.description, "Fatal game engine error!", new ListCollection([{label:"OK"}]), null, true, true);
			alert.height = 500;
		}
		
		/**
		 * A simple game status event handler to display game progress to the player.
		 * 
		 * @param eventObj A status event object.
		 * 
		 */
		protected function onGameStatus(eventObj:PokerGameStatusEvent):void	{
			/*
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
			*/
		}		
		
		/**
		 * Attempts to create a community/public card by adding it to the display container and showing it.
		 * 
		 * @param	cardRef The commuity card to create within the display container.
		 * 
		 * @return True if the card could be created, false if creation failed or if the card has already been created.
		 */
		protected function createCommunityCard(cardRef:ICard):Boolean {
			/*
			if (cardRef == null) {
				return (false);
			}
			if (_commCardsContainer == null) {
				_commCardsContainer = new Sprite();	
				StarlingContainer.instance.addChild(_commCardsContainer);
				//addChild(_commCardsContainer);
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
			cardItem.flip(true, 0.5, 0.5, _communityCards.length*500);			
			return (true);
			*/
			return (false);
		}
		
		/**	
		 * Attempts to create a player/private card by adding it to the display container and showing it.
		 * 
		 * @param	cardRef The player card to create within the display container.
		 * 
		 * @return True if the card could be created, false if creation failed or if the card has already been created.
		 */
		protected function createPlayerCard(cardRef:ICard):Boolean {
			if (cardRef == null) {
				return (false);
			}
			if (_playerCardsContainer == null) {
				_playerCardsContainer = new Sprite();
				StarlingContainer.instance.addChild(_playerCardsContainer);
				//addChild(_playerCardsContainer);
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
			cardItem.flip(true, 0.5, 0.5, _playerCards.length*500);			
			return (true);
		}
		
		/**
		 * Unlocks the game status display to continue displaying new messages.
		 */
		protected function unlockGameStatus():void	{
		}
		
		/**
		 * Event listener invoked when an available smart contract has been deployed and/or verified and is ready for use.
		 * 
		 * @param	eventObj A SmartContractEvent object.
		 */
		private function onSmartContractReady(eventObj:SmartContractEvent):void {			
			if (ethereum != null) {
				var descriptor:XML = SmartContract.findDescriptorByAddress(this.table.smartContractAddress, "ethereum", this.ethereum.client.networkID);
				//CONTINUE: Contract may not be available if switching from player role (store and use temporary contract from last session).
				//Don't launch this function until verification for previous round has concluded.
				DebugView.addText("Using smart contract: "+descriptor.toXMLString());
				this.smartContractBuyIn = ethereum.web3.toWei(this.table.buyInAmount, "ether");
				var contractName:String = descriptor.localName();
				var contract:SmartContract = new SmartContract(contractName, ethereumAccount, ethereumPassword, descriptor);
				contract.create();
				activeSmartContract = contract;
			} else {
				descriptor = null;
			}
			//initialize shift list for Sequential Member Operations...
			var shiftList:Vector.<INetCliqueMember> = super.getSMOShiftList();
			_player = new Dealer(this); //Dealer is a type of Player so this is valid
			_player.start();
			var pcgMessage:PokerCardGameMessage = new PokerCardGameMessage();
			if (descriptor != null) {
				pcgMessage.createPokerMessage(PokerCardGameMessage.GAME_START, descriptor);
			} else {
				pcgMessage.createPokerMessage(PokerCardGameMessage.GAME_START);
			}
			this.clique.broadcast(pcgMessage);
			_gameLog.addMessage(pcgMessage);
		}
		
		/**
		 * Event handler for PokerBettingEvent.ROUND_DONE events dispatched from the current PokerBettingModule
		 * instance. This event is usually dispatched when a round has fully completed and all results and crypto
		 * keys are available.
		 * 
		 * @param	eventObj A PokerBettingEvent.ROUND_DONE event object.
		 */
		private function onRoundDone(eventObj:PokerBettingEvent):void {			
			DebugView.addText("PokerCardGame.onRoundDone");		
			//any cleanup required before processing game results should go here
			processRoundResults();						
		}		
		
		/**
		 * Processes the results of the currently completed round of play.
		 */
		private function processRoundResults():void {			
			DebugView.addText("PokerCardGame.processRoundResults");			
			var statusText:String = new String();			
			if (bettingModule.nonFoldedPlayers.length == 1) {
				onRoundVerifySuccess(null);
			} else {
				currentGameVerifier.setAllData(this);
				currentGameVerifier.addEventListener(PokerGameVerifierEvent.SUCCESS, this.onRoundVerifySuccess);
				currentGameVerifier.addEventListener(PokerGameVerifierEvent.FAIL, this.onRoundVerifyFail);
				var alert:Alert = StarlingViewManager.alert("Starting verification of hand #" + currentGameVerifier.instanceNum +".", 
						"Verifying hand" , new ListCollection([{label:"OK"}]), null, true, true);
				currentGameVerifier.verify();
			}
		}
			
		private function onRoundVerifyFail(eventObj:PokerGameVerifierEvent):void {
			eventObj.target.removeEventListener(PokerGameVerifierEvent.SUCCESS, this.onRoundVerifySuccess);
			eventObj.target.removeEventListener(PokerGameVerifierEvent.FAIL, this.onRoundVerifyFail);
			var verifier:PokerGameVerifier = eventObj.target as PokerGameVerifier;	
			var dialogMsg:String = "Verification for the hand has failed!.\n";
			dialogMsg += "It is highly recommended that you discontinue this game.\n";
			if ((ethereum != null) && (this.activeSmartContract != null)) {			
				dialogMsg += "Validation for contract " + verifier.contract.address +" has been started.\n";
			}			
			var alert:Alert = StarlingViewManager.alert(dialogMsg, "Hand #" + verifier.instanceNum + " verification failed", 
						new ListCollection([{label:"STOP PLAYING", continuePlay:false}, {label:"KEEP PLAYING", continuePlay:true}]), null, true, true);
			alert.addEventListener(Event.CLOSE, this.onRoundVerifyFailAlertClose);
		
		}
		
		private function onRoundVerifyFailAlertClose(eventObj:Object):void {
			eventObj.target.removeEventListener(Event.CLOSE, this.onRoundVerifyFailAlertClose);
			if (eventObj.data.continuePlay) {
				this.onProcessRoundResults();
			} else {
				lounge.destroyCurrentGame();
			}
		}
		
		private function onRoundVerifySuccess(eventObj:PokerGameVerifierEvent):void {
			if (eventObj != null) {
				eventObj.target.removeEventListener(PokerGameVerifierEvent.SUCCESS, this.onRoundVerifySuccess);
				eventObj.target.removeEventListener(PokerGameVerifierEvent.FAIL, this.onRoundVerifyFail);
			}
			if (bettingModule.nonFoldedPlayers.length == 1) {
				var dialogMsg:String = "Player " + table.getInfoForPeer(bettingModule.winningPlayerInfo.netCliqueInfo.peerID).handle+ " has won the hand.\n";
				dialogMsg += "All other players have folded.";
				bettingModule.winningPlayerInfo.balance += bettingModule.communityPot;
				this.dispatchStatusEvent(PokerGameStatusEvent.UPDATE_BALANCES, this, {players:bettingModule.allPlayers});
				var alert:Alert = StarlingViewManager.alert(dialogMsg, "Hand #" + currentGameVerifier.instanceNum + " winner verified", new ListCollection([{label:"OK"}]), null, true, true);	
				alert.height = 200;
				onProcessRoundResults();
				return;
			}
			var verifier:PokerGameVerifier = eventObj.target as PokerGameVerifier;
			var winnerAnalyzer:PokerHandAnalyzer = verifier.getAnalyzer(verifier.winner);
			if (eventObj.conditional) {
				dialogMsg = "Player " + table.getInfoForPeer(verifier.winner).handle+" has won the hand but reported an incorrect hand score.\n";
				dialogMsg += "Player's reported hand score was " + verifier.getReportedResult(verifier.winner).value+" but calculated hand score was " + verifier.winningScore + ".\n";
			} else {
				dialogMsg = "Player \"" + table.getInfoForPeer(verifier.winner).handle+"\" has won the hand.\n";
				dialogMsg += "Player's verified hand score:\n    " + verifier.winningScore + ".\n";			
			}
			dialogMsg += "Winning hand combination:\n   " + winnerAnalyzer.highestHand.matchedDefinition.@name + "\n";
			dialogMsg += "Cards in winning hand:\n   ";
			for (var count:int = 0; count < winnerAnalyzer.highestHand.matchedCards.length; count++) {
				var card:ICard = winnerAnalyzer.highestHand.matchedCards[count];
				dialogMsg += " " + card.cardName+",";
			}			
			dialogMsg = dialogMsg.substr(0, dialogMsg.length - 2);
			alert = StarlingViewManager.alert(dialogMsg, "Hand #" + verifier.instanceNum + " winner verified", new ListCollection([{label:"OK"}]), null, true, true);	
			alert.height = 400;
			bettingModule.winningPlayerInfo.balance += bettingModule.communityPot;
			this.dispatchStatusEvent(PokerGameStatusEvent.UPDATE_BALANCES, this, {players:bettingModule.allPlayers});
			if ((ethereum != null) && (this.activeSmartContract != null)) {
				//this.activeSmartContract.resolveWinner(verifier.winner).invoke({from:this.ethereumAccount, gas:150000});
				this.resolutionsContract.resolveWinner(this.activeSmartContract.address).invoke({from:this.ethereumAccount, gas:150000});
				return;
			}
			//don't use selfPlayerInfo from betting module in case we've been removed (busted)
			if (verifier.winner == this.clique.localPeerInfo.peerID) {
				if ((ethereum != null) && (this.activeSmartContract != null)) {
					// begin smart contract deferred invocation: declareWinner
					//TODO: If no contract interactions (other than initialize & agree) and all signed transactions okay then declare winner
					//with no defers, otherwise:
					var deferDataObj1:Object = new Object();
					deferDataObj1.phases = 14;				
					deferDataObj1.account = "all";					
					var defer1:SmartContractDeferState = new SmartContractDeferState(this.phaseDeferCheck, deferDataObj1, this, true);
					defer1.operationContract = this.activeSmartContract;
					var deferArray1:Array = this.combineDeferStates(this.deferStates, [defer1]);			
					//this.activeSmartContract.declareWinner(verifier.winner).defer(deferArray1).invoke({from:this.ethereumAccount, gas:150000});
					this.actionsContract.declareWinner(this.activeSmartContract.address, verifier.winner).defer(deferArray1).invoke({from:this.ethereumAccount, gas:150000});
					// end smart contract deferred invocation: declareWinner					
					// begin smart contract deferred invocation: resolveWinner
					var deferDataObj2:Object = new Object();
					deferDataObj2.dataContract = this.activeSmartContract;
					var deferDataObj3:Object = new Object();
					deferDataObj3.phases = [14,16,18]; //we can trigger resolution on a timeout at any of these phases
					deferDataObj3.account = "all"; //as specified in contract					
					var defer2:SmartContractDeferState = new SmartContractDeferState(this.timeoutDeferCheck, deferDataObj2, this, true);
					defer2.operationContract = this.resolutionsContract; //timeoutDeferCheck uses an external accessor
					defer2.dataContract = this.activeSmartContract;
					var defer3:SmartContractDeferState = new SmartContractDeferState(this.phaseDeferCheck, deferDataObj3, this, true);
					defer3.operationContract = this.activeSmartContract;
					var deferArray2:Array = this.combineDeferStates(this.deferStates, [defer2, defer3]);
					//this.activeSmartContract.resolveWinner().defer(deferArray2).invoke({from:this.ethereumAccount, gas:150000});
					this.resolutionsContract.resolveWinner(this.activeSmartContract.address).defer(deferArray2).invoke({from:this.ethereumAccount, gas:150000});
					// end smart contract deferred invocation: resolveWinner					
				}
			} else {
				if ((ethereum != null) && (this.activeSmartContract != null)) {
					//TODO: If no contract interactions (other than initialize & agree) and all signed transactions okay then declare winner
					//with no defers -- as above, otherwise:
					deferDataObj1 = new Object();
					deferDataObj1.phases = 14;				
					deferDataObj1.account = "all";					
					defer1 = new SmartContractDeferState(this.phaseDeferCheck, deferDataObj1, this, true);
					defer1.operationContract = this.activeSmartContract;
					deferArray1 = this.combineDeferStates(this.deferStates, [defer1]);			
					//this.activeSmartContract.declareWinner(verifier.winner).defer(deferArray1).invoke({from:this.ethereumAccount, gas:150000});
					this.actionsContract.declareWinner(this.activeSmartContract.address, verifier.winner).defer(deferArray1).invoke({from:this.ethereumAccount, gas:150000});
				}
			}
			onProcessRoundResults();
		}
		
		/**
		 * Called when the round results have been fully processed and the next round is ready to begin. Round data are
		 * cleared and a final GAME_WIN event may be dispatched at this point.
		 */
		private function onProcessRoundResults():void {
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
			//	if (_lastWinningPlayer.netCliqueInfo.peerID == this.clique.localPeerInfo.peerID) {
			//		var statusText:String = "I won the pot! Total winnings: " + _lastWinningPlayer.balance;
			//	} else {
			//		statusText = "Player "+_lastWinningPlayer.netCliqueInfo.peerID+" won the pot. Total winnings: " + _lastWinningPlayer.balance;
			//	}
			//	_gameStatusLocked = false; //one final update to the status regardless of what's being displayed				
				//game has fully ended
			}
		}		
		
		/**
		 * Resets the poker card game by clearing current community and player cards, resetting current card mappings,
		 * and cleaning up the current Player or Dealer instance.
		 * 
		 * @param	... args None currently used.
		 */
		private function resetGame(... args):void {
			DebugView.addText("PokerCardGame.resetGame");
			clearPlayerCards();
			clearCommunityCards();
			bettingModule.removeZeroBalancePlayers();
			bettingModule.reset();
			this._deferStates = new Array();
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
		private function startNextRound():void {
			DebugView.addText("PokerCardGame.startNextRound");
			bettingModule.updateBettingOrder();
			//lounge.currentLeader = bettingModule.currentDealerMember;
			table.currentDealerPeerID = bettingModule.currentDealerMember.peerID;
			if (table.dealerIsMe) {
				DebugView.addText("I am now the dealer.");
			} else {
				DebugView.addText("I am now a player.");
			}
			/*			
			if (lounge.currentLeader.peerID == this.clique.localPeerInfo.peerID) {
				DebugView.addText("   I am the new dealer.");
				lounge.leaderIsMe = true;
			} else {				
				lounge.leaderIsMe = false;
			}
			*/
			gamePhase = 1;
			start(true);
		}		
	}
}
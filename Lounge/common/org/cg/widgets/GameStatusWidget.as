/**
* Widget that tracks the internal status and progress of the poker game engine. This widget is typically added and removed dynamically
* by the game engine instance and is not intended as a general lounge widget.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
	
	import events.PokerGameStatusEvent;
	import feathers.controls.ToggleSwitch;
	import interfaces.IPokerPlayerInfo;
	import org.cg.SmartContract;
	import org.cg.SmartContractFunction;
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.IPanelWidget;
	import org.cg.SlidingPanel;
	import feathers.controls.List;
	import feathers.controls.renderers.IListItemRenderer;
	import feathers.data.ListCollection;
	import org.cg.widgets.GameStatusItemRenderer;
	import org.cg.events.SmartContractEvent;
	import events.PokerGameStatusEvent;
	import events.PokerBettingEvent;
	import PokerCardGame;
	import org.cg.DebugView;
	
	public class GameStatusWidget extends PanelWidget implements IPanelWidget {
		
		//UI components rendered by StarlingViewManager:
		public var statusList:List;
		public var scrollLockToggleSwitch:ToggleSwitch;
		private var _game:PokerCardGame = null;	//reference to the current active game instance
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	loungeRef A reference to the main ILounge implementation instance.
		 * @param	container The widget's parent panel or display object container.
		 * @param	widgetData The widget's configuration XML data, usually from the global settings data.
		 */
		public function GameStatusWidget(loungeRef:ILounge, panelRef:SlidingPanel, widgetData:XML) {			
			DebugView.addText ("GameStatusWidget created");
			DebugView.addText ("widgetData=" + widgetData);
			this._game = loungeRef.games[0] as PokerCardGame;
			super(loungeRef, panelRef, widgetData);
		}
		
		/**
		 * Initalizes the instance after it's been added to the display list and all child components have been rendered.
		 */
		override public function initialize():void {
			DebugView.addText ("GameStatusWidget initialize");
			var listItemDefinition:XML = null;
			var dataChildren:XMLList = this._widgetData.children();
			for (var count:int = 0; count < dataChildren.length(); count++) {
				var currentNode:XML = dataChildren[count];
				if ((currentNode.localName() == "list") && (currentNode.@instance == "statusList")) {
					listItemDefinition = currentNode.child("listitem")[0];
					break;
				}
			}
			this.statusList.itemRendererFactory = function():IListItemRenderer {
				var renderer:GameStatusItemRenderer = new GameStatusItemRenderer(listItemDefinition, lounge, onListItemSelect);
				return renderer;
			}
			this.statusList.dataProvider = new ListCollection();
			if (this._game.activeSmartContract != null) {				
				this._game.activeSmartContract.addEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
				this._game.activeSmartContract.addEventListener(SmartContractEvent.FUNCTION_CREATE, this.onContractFunctionCreated);
				this._game.activeSmartContract.addEventListener(SmartContractEvent.DESTROY, this.onSmartContractDestroy);
			}
			this._game.addEventListener(PokerGameStatusEvent.STATUS, this.onGameEngineStatus);
			this._game.bettingModule.addEventListener(PokerBettingEvent.BETTING_PLAYER, this.onBettingEvent);
			this._game.bettingModule.addEventListener(PokerBettingEvent.BET_COMMIT, this.onBettingEvent);
			this._game.bettingModule.addEventListener(PokerBettingEvent.BET_FOLD, this.onBettingEvent);
			this._game.bettingModule.addEventListener(PokerBettingEvent.BETTING_NEW_BLINDS, this.onBettingEvent);
			this._game.bettingModule.addEventListener(PokerBettingEvent.ROUND_DONE, this.onBettingEvent);
			this._game.bettingModule.addEventListener(PokerBettingEvent.BETTING_FINAL_DONE, this.onBettingEvent);
			this._game.bettingModule.addEventListener(PokerBettingEvent.BETTING_DONE, this.onBettingEvent);
			this._game.bettingModule.addEventListener(PokerBettingEvent.BETTING_STARTED, this.onBettingEvent);
			this._game.bettingModule.addEventListener(PokerBettingEvent.POT_UPDATE, this.onBettingEvent);
			this._game.addEventListener(PokerGameStatusEvent.DESTROY, this.onGameDestroy);
			this.statusList.dataProvider.addItem({itemHeader:"Status widget initialized."});
			this.statusList.invalidate();
		}
		
		/**
		 * Prepares the instance for removal from memory by removing event listeners, destroying the list and its items, and removing any
		 * references.
		 */
		override public function destroy():void {
			this.statusList.dataProvider.removeAll();
			this.statusList.dispose();
			this._game.removeEventListener(PokerGameStatusEvent.DESTROY, this.onGameDestroy);
			this._game.removeEventListener(PokerGameStatusEvent.STATUS, this.onGameEngineStatus);
			this._game.bettingModule.removeEventListener(PokerBettingEvent.BETTING_PLAYER, this.onBettingEvent);
			this._game.bettingModule.removeEventListener(PokerBettingEvent.BET_COMMIT, this.onBettingEvent);
			this._game.bettingModule.removeEventListener(PokerBettingEvent.BET_FOLD, this.onBettingEvent);
			this._game.bettingModule.removeEventListener(PokerBettingEvent.BETTING_NEW_BLINDS, this.onBettingEvent);
			this._game.bettingModule.removeEventListener(PokerBettingEvent.ROUND_DONE, this.onBettingEvent);
			this._game.bettingModule.removeEventListener(PokerBettingEvent.BETTING_FINAL_DONE, this.onBettingEvent);
			this._game.bettingModule.removeEventListener(PokerBettingEvent.BETTING_DONE, this.onBettingEvent);
			this._game.bettingModule.removeEventListener(PokerBettingEvent.BETTING_STARTED, this.onBettingEvent);
			this._game.bettingModule.removeEventListener(PokerBettingEvent.POT_UPDATE, this.onBettingEvent);			
			if (this._game.activeSmartContract != null) {
				this._game.activeSmartContract.removeEventListener(SmartContractEvent.DESTROY, this.onSmartContractDestroy);				
				this._game.activeSmartContract.removeEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
				this._game.activeSmartContract.removeEventListener(SmartContractEvent.FUNCTION_CREATE, this.onContractFunctionCreated);
			}
			super.destroy();
		}
		
		/**
		 * Callback function invoked when a list item has been selected.
		 * 
		 * @param	selectedData The data object associated with the selected item renderer instance.
		 * @param	selectedItem A reference to the selected item renderer instance.
		 */
		public function onListItemSelect(selectedData:Object, selectedItem:IListItemRenderer):void {
		}
		
		/**
		 * @return The current system time stamp with enclosing brackets and preceding space.
		 */
		private function get timestamp():String {
			var ts:String = new String();
			ts = " (";
			var dateObj:Date = new Date();
			if (dateObj.getHours() < 10) {
				ts += "0";
			}
			ts += dateObj.getHours() + ":";
			if (dateObj.getMinutes() < 10) {
				ts += "0";
			}
			ts += dateObj.getMinutes() + ":";
			if (dateObj.getSeconds() < 10) {
				ts += "0";
			}
			ts += dateObj.getSeconds() + ":";
			if (dateObj.getMilliseconds() < 10) {
				ts += "0";
			}
			ts += dateObj.getMilliseconds();		
			ts += ")";
			return (ts);
		}
		
		/**
		 * Event listener invoked when the currently active game engine dispatches any status updates. The updates may
		 * originate from any part of the game engine (reference by eventObj.source), and are aggregated and dispatched
		 * by the game engine. A new action+status item, including details, is added to the status list on any recognized
		 * update.
		 * 
		 * @param	eventObj A PokerGameStatusEvent object.
		 */
		private function onGameEngineStatus(eventObj:PokerGameStatusEvent):void {
			var itemData:Object = new Object();			
			itemData.itemHeader = eventObj.eventType + this.timestamp;
			itemData.actionStatus = "none";
			itemData.itemType = "gameengine";
			switch (eventObj.eventType) {
				case PokerGameStatusEvent.START:
					itemData.itemDetails = "Dealer has broadcast start game message.";
					break;
				case PokerGameStatusEvent.SET_BLINDS:
					itemData.itemDetails = "Blinds values have been set.\n\n";
					itemData.itemDetails += "Big blind: " + eventObj.info.bigBlind + "\n";
					itemData.itemDetails += "Small blind: " + eventObj.info.smallBlind+"\n";
					break;
				case PokerGameStatusEvent.DEALER_NEW_BETTING_ORDER:
					itemData.itemDetails = "Dealer has established a new betting order.\n";					
					var bettingModule:PokerBettingModule = eventObj.info.bettingModule;
					for (var count:uint = 0; count < bettingModule.allPlayers.length; count++) {
						var player:IPokerPlayerInfo = bettingModule.allPlayers[count];
						itemData.itemDetails += String(count) + "."
						var peerID:String = player.netCliqueInfo.peerID;
						var playerHandle:String = this._game.table.getInfoForPeer(peerID).handle;
						if (lounge.ethereum != null) {
							var ethAccount:String = lounge.ethereum.getAccountByPeerID(peerID);
						} else {
							ethAccount = "none";
						}
						itemData.itemDetails += "Player: "+ playerHandle + "\n";
						itemData.itemDetails += "Peer ID: "+ peerID + "\n";
						itemData.itemDetails += "Ethereum account: " + ethAccount + "\n";							
						itemData.itemDetails += "Role: ";
						if (player.isBigBlind) {
							itemData.itemDetails += "Big blind";
							if (player.isDealer) {
								itemData.itemDetails += " / Dealer";
							}
						} else if (player.isSmallBlind) {
							itemData.itemDetails += "Small blind";
						} else if (player.isDealer) {
							itemData.itemDetails += "Dealer";
						} else {
							itemData.itemDetails += "Player";
						}						
					}					
					break;
				case PokerGameStatusEvent.DEALER_GEN_MODULUS:
					itemData.itemDetails = "Generating a new shared modulus.";
					itemData.actionStatus = "waiting";
					break;
				case PokerGameStatusEvent.DEALER_NEW_MODULUS:
					itemData.itemDetails = "Dealer has established a new shared modulus:\n";
					itemData.itemDetails += eventObj.info.modulus;
					break;
				case PokerGameStatusEvent.SET_BALANCES:
					itemData.itemDetails = "Starting balances for players have been set.\n";
					for (count = 0; count < eventObj.info.players.length; count++) {
						player = eventObj.info.players[count];
						peerID = player.netCliqueInfo.peerID;
						playerHandle = this._game.table.getInfoForPeer(peerID).handle;
						if (lounge.ethereum != null) {
							ethAccount = lounge.ethereum.getAccountByPeerID(peerID);
						} else {
							ethAccount = "none";
						}
						itemData.itemDetails += "Player: "+ playerHandle + "(";
						itemData.itemDetails +=  peerID + ")\n";
						itemData.itemDetails += "Ethereum account: "+ethAccount + "\n";
						itemData.itemDetails += "Balance: " + player.balance + "\n";						
					}
					break;
				case PokerGameStatusEvent.GEN_DECK:
					itemData.itemDetails = "Generating the card deck.";
					itemData.actionStatus = "waiting";
					break;
				case PokerGameStatusEvent.NEW_DECK:
					itemData.itemDetails = "New card deck has been generated.";
					break;
				case PokerGameStatusEvent.NEW_CONTRACT:
					itemData.itemDetails = "Smart contract has been linked.\n";
					var contract:SmartContract = eventObj.info.contract;
					itemData.itemDetails += "Contract type: " + contract.contractName+"\n";
					itemData.itemDetails += "Address: " + contract.address;
					itemData.itemType = "smartcontract";					
					try {
						lounge.games[0].startupContract.removeEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
						lounge.games[0].startupContract.removeEventListener(SmartContractEvent.FUNCTION_CREATE, this.onContractFunctionInvoked);
						lounge.games[0].startupContract.removeEventListener(SmartContractEvent.DESTROY, this.onSmartContractDestroy);
						lounge.games[0].startupContract.addEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
						lounge.games[0].startupContract.addEventListener(SmartContractEvent.FUNCTION_CREATE, this.onContractFunctionInvoked);
						lounge.games[0].startupContract.addEventListener(SmartContractEvent.DESTROY, this.onSmartContractDestroy);
					} catch (err:*) {
					}
					try {
						lounge.games[0].actionsContract.removeEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
						lounge.games[0].actionsContract.removeEventListener(SmartContractEvent.FUNCTION_CREATE, this.onContractFunctionInvoked);
						lounge.games[0].actionsContract.removeEventListener(SmartContractEvent.DESTROY, this.onSmartContractDestroy);
						lounge.games[0].actionsContract.addEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
						lounge.games[0].actionsContract.addEventListener(SmartContractEvent.FUNCTION_CREATE, this.onContractFunctionInvoked);
						lounge.games[0].actionsContract.addEventListener(SmartContractEvent.DESTROY, this.onSmartContractDestroy);
					} catch (err:*) {
					}					
					try {
						lounge.games[0].resolutionsContract.removeEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
						lounge.games[0].resolutionsContract.removeEventListener(SmartContractEvent.FUNCTION_CREATE, this.onContractFunctionInvoked);
						lounge.games[0].resolutionsContract.removeEventListener(SmartContractEvent.DESTROY, this.onSmartContractDestroy);
						lounge.games[0].resolutionsContract.addEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
						lounge.games[0].resolutionsContract.addEventListener(SmartContractEvent.FUNCTION_CREATE, this.onContractFunctionInvoked);
						lounge.games[0].resolutionsContract.addEventListener(SmartContractEvent.DESTROY, this.onSmartContractDestroy);
					} catch (err:*) {
					}
					try {
						lounge.games[0].validatorContract.removeEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
						lounge.games[0].validatorContract.removeEventListener(SmartContractEvent.FUNCTION_CREATE, this.onContractFunctionInvoked);
						lounge.games[0].validatorContract.removeEventListener(SmartContractEvent.DESTROY, this.onSmartContractDestroy);
						lounge.games[0].validatorContract.addEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
						lounge.games[0].validatorContract.addEventListener(SmartContractEvent.FUNCTION_CREATE, this.onContractFunctionInvoked);
						lounge.games[0].validatorContract.addEventListener(SmartContractEvent.DESTROY, this.onSmartContractDestroy);
					} catch (err:*) {
					}
					contract.removeEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
					contract.removeEventListener(SmartContractEvent.FUNCTION_CREATE, this.onContractFunctionCreated);
					contract.removeEventListener(SmartContractEvent.DESTROY, this.onSmartContractDestroy);
					contract.addEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
					contract.addEventListener(SmartContractEvent.FUNCTION_CREATE, this.onContractFunctionCreated);
					contract.addEventListener(SmartContractEvent.DESTROY, this.onSmartContractDestroy);
					break;
				case PokerGameStatusEvent.GEN_KEYS:
					itemData.itemDetails = "Generating "+eventObj.info.numKeys+" crypto keypairs.";
					itemData.actionStatus = "waiting";
					break;
				case PokerGameStatusEvent.NEW_KEYS:
					itemData.itemDetails = "New crypto keypairs have been generated.";
					itemData.actionStatus = "done";
					break;
				case PokerGameStatusEvent.ROUNDSTART:
					itemData.itemDetails = "Starting new hand/round.";
					break;
				case PokerGameStatusEvent.ROUNDEND:
					itemData.itemDetails = "The hand/round has ended.";
					break;
				case PokerGameStatusEvent.SHUFFLE_DECK:
					itemData.itemDetails = "Now shuffling the encrypted deck "+eventObj.info.shuffleCount+" times.";
					break;
				case PokerGameStatusEvent.ENCRYPT_CARD:
					itemData.itemDetails = "Encrypting card value: \n\n";
					itemData.itemDetails += eventObj.info.card;
					itemData.actionStatus = "waiting";
					break;
				case PokerGameStatusEvent.ENCRYPTED_CARD:
					itemData.itemDetails = "Card value encrypted: \n\n";
					itemData.itemDetails += eventObj.info.card;
					itemData.actionStatus = "done";
					break;
				case PokerGameStatusEvent.DECRYPT_PRIVATE_CARDS:
					itemData.itemDetails = "Private card currently being decrypted.\n";
					if (eventObj.info.decryptor != null) {
						peerID = eventObj.info.decryptor.netCliqueInfo.peerID;
						playerHandle = this._game.table.getInfoForPeer(peerID).handle;
						if (lounge.ethereum != null) {
							ethAccount = lounge.ethereum.getAccountByPeerID(peerID);
						} else {
							ethAccount = "none";
						}
						itemData.itemDetails += "By player: " + playerHandle + "\n";
						itemData.itemDetails += "Peer ID: " + peerID + "\n";
						itemData.itemDetails += "Ethereum account: "+ ethAccount + "\n";
					}
					if (eventObj.info.player != null) {
						peerID = eventObj.info.player.netCliqueInfo.peerID;
						playerHandle = this._game.table.getInfoForPeer(peerID).handle;
						if (lounge.ethereum != null) {
							ethAccount = lounge.ethereum.getAccountByPeerID(peerID);
						} else {
							ethAccount = "none";
						}
						itemData.itemDetails += "Owner: " + playerHandle + "\n";
						itemData.itemDetails += "Peer ID: " + peerID + "\n";
						itemData.itemDetails += "Ethereum account: "+ ethAccount;
					}
					itemData.actionStatus = "waiting";
					break;
				case PokerGameStatusEvent.DECRYPTED_PRIVATE_CARDS:
					itemData.itemDetails = "Own private/hole cards fully decrypted.\n";					
					itemData.actionStatus = "done";
					break;
				case PokerGameStatusEvent.DECRYPT_PUBLIC_CARDS:
					itemData.itemDetails = "Public card(s) currently being decrypted.\n";					
					itemData.itemDetails += "By peer ID: " + IPokerPlayerInfo(eventObj.info.decryptor).netCliqueInfo.peerID;
					itemData.actionStatus = "waiting";
					break;				
				case PokerGameStatusEvent.DECRYPTED_PUBLIC_CARDS:
					itemData.itemDetails = "Public card(s) fully decrypted.";					
					itemData.actionStatus = "done";
					break;
				case PokerGameStatusEvent.WIN:
					var winners:Vector.<IPokerPlayerInfo> = eventObj.info.player;
					itemData.itemDetails = "Hand/round has been won by:";
					for (count = 0; count <winners.length; count++) {
						player = winners[count];
						peerID = player.netCliqueInfo.peerID;
						playerHandle = this._game.table.getInfoForPeer(peerID).handle;
						if (lounge.ethereum != null) {
							ethAccount = lounge.ethereum.getAccountByPeerID(peerID);
						} else {
							ethAccount = "none";
						}
						itemData.itemDetails += "Player: " + playerHandle + "\n";
						itemData.itemDetails += "Peer ID: "+peerID + "\n";
						itemData.itemDetails += "Ethereum account: "+ethAccount + "\n";
						itemData.itemDetails += "Balance: " + player.balance + "\n";
						itemData.itemDetails += "Winning hand: " + player.lastResultHand.matchedDefinition.@name + "\n";
						itemData.itemDetails += "\n";
					}
					itemData.actionStatus = "done";
					break;
				case PokerGameStatusEvent.GAME_WIN:
					var winner:IPokerPlayerInfo = eventObj.info.player;
					peerID = winner.netCliqueInfo.peerID;
					playerHandle = this._game.table.getInfoForPeer(peerID).handle;
					itemData.itemDetails = "Game has been won by player \""+playerHandle+"\"";
					itemData.itemDetails += "Peer ID: "+winner.netCliqueInfo.peerID + "\n";
					itemData.itemDetails += "Balance: " + winner.balance + "\n";
					itemData.itemDetails += "Winning hand: " + winner.lastResultHand.matchedDefinition.@name + "\n";
					itemData.actionStatus = "done";
					break;
				default:
					return;
					break;
			}
			this.statusList.dataProvider.addItem(itemData);
			this.statusList.invalidate();
			if (this.scrollLockToggleSwitch.isSelected) {
				this.statusList.scrollToDisplayIndex((this.statusList.dataProvider.length-1), 0.5);
			}
		}
		
		/**
		 * Event listener invoked when a SmartContractFunction instance is created on a known (by this instance) SmartContract
		 * instance. A new item is added to the status list when a recognized event is received.
		 * 
		 * @param	eventObj A SmartContractEvent object.
		 */
		private function onContractFunctionCreated(eventObj:SmartContractEvent):void {
			var functionRef:SmartContractFunction = eventObj.contractFunction;
			var itemData:Object = new Object();
			itemData.smartContractFunction = functionRef;			
			itemData.itemHeader = "Contract invocation: " + functionRef.functionName + this.timestamp;
			itemData.itemDetails = "Contract type: " + eventObj.target.contract.contractName+"\n";
			itemData.itemDetails += "Address: " + eventObj.target.contract.address + "\n\n";
			itemData.itemDetails += "Deferring invocation.";			
			itemData.actionStatus = "waiting";			
			itemData.itemType = "smartcontract";
			this.statusList.dataProvider.addItem(itemData);
			this.statusList.invalidate();
			if (this.scrollLockToggleSwitch.isSelected) {
				this.statusList.scrollToDisplayIndex((this.statusList.dataProvider.length-1), 0.5);
			}
		}
		
		/**
		 * Event listener invoked when a known (by this instance) smart contract function is successfully invoked. 
		 * A new item is added to the status list when a recognized event is received.
		 * 
		 * @param	eventObj A SmartContractEvent object.
		 */
		private function onContractFunctionInvoked(eventObj:SmartContractEvent):void {
			if (this.statusList == null) {
				eventObj.target.contract.removeEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
				this.destroy();
			}
			var functionRef:SmartContractFunction = eventObj.contractFunction;
			var itemData:Object = new Object();
			itemData.smartContractFunction = functionRef;			
			itemData.itemHeader = "Contract invocation: " + functionRef.functionName + this.timestamp;
			itemData.itemDetails = "Contract type: " + eventObj.target.contract.contractName+"\n";
			itemData.itemDetails += "Address: " + eventObj.target.contract.address + "\n\n";
			itemData.itemDetails += "Transaction hash: " + functionRef.result + "\n\n";
			itemData.itemDetails += "Invocation complete.";
			itemData.actionStatus = "done";			
			itemData.itemType = "smartcontract";
			if (this.statusList.dataProvider == null) {
				this.statusList.dataProvider = new ListCollection();
			}
			this.statusList.dataProvider.addItem(itemData);
			this.statusList.invalidate();
			if (this.scrollLockToggleSwitch.isSelected) {
				this.statusList.scrollToDisplayIndex((this.statusList.dataProvider.length-1), 0.5);
			}			
		}
		
		/**
		 * Event listener invoked when a known (by this instance) SmartContract instance is about to be destroyed. A new item is added to 
		 * the status list when a recognized event is received.
		 * 
		 * @param	eventObj A SmartContractEvent object.
		 */
		private function onSmartContractDestroy(eventObj:SmartContractEvent):void {
			eventObj.target.contract.removeEventListener(SmartContractEvent.DESTROY, this.onSmartContractDestroy);			
			eventObj.target.contract.removeEventListener(SmartContractEvent.FUNCTION_INVOKED, this.onContractFunctionInvoked);
			eventObj.target.contract.removeEventListener(SmartContractEvent.FUNCTION_CREATE, this.onContractFunctionCreated);
			var contract:SmartContract = eventObj.target.contract as SmartContract;
			var itemData:Object = new Object();
			itemData.itemHeader = "Contract link removed" + this.timestamp;
			itemData.itemDetails = "Contract type: " + contract.contractName+"\n";
			itemData.itemDetails += "Address: " + contract.address + "\n";			
			this.statusList.dataProvider.addItem(itemData);
			this.statusList.invalidate();
			if (this.scrollLockToggleSwitch.isSelected) {
				this.statusList.scrollToDisplayIndex((this.statusList.dataProvider.length-1), 0.5);
			}
		}
		
		/**
		 * Event listener invoked when a betting action event is dispatched from the current game's betting module. A new
		 * item is added to the status list if the event is recognized.
		 * 
		 * @param	eventObj A PokerBettingEvent object.
		 */
		private function onBettingEvent(eventObj:PokerBettingEvent):void {
			var itemData:Object = new Object();			
			itemData.actionStatus = "none";
			itemData.itemType = "clique";
			switch (eventObj.type) {
				case PokerBettingEvent.BETTING_PLAYER:
					var player:IPokerPlayerInfo = eventObj.sourcePlayer;
					var peerID:String = player.netCliqueInfo.peerID;
					var playerHandle:String = this._game.table.getInfoForPeer(peerID).handle;
					if (lounge.ethereum != null) {
						var ethAccount:String = lounge.ethereum.getAccountByPeerID(peerID);
					} else {
						ethAccount = "none";
					}
					itemData.itemHeader = "Player \""+playerHandle+"\" now betting" + this.timestamp;
					itemData.itemDetails = "Peer ID: "+ peerID + "\n";
					itemData.itemDetails += "Ethereum account: " + ethAccount + "\n";
					itemData.itemDetails += "Balance: " + player.balance + "\n";					
					itemData.actionStatus = "waiting";
					break;
				case PokerBettingEvent.BET_COMMIT:
					player = eventObj.sourcePlayer;
					peerID = player.netCliqueInfo.peerID;
					playerHandle = this._game.table.getInfoForPeer(peerID).handle;
					if (lounge.ethereum != null) {
						ethAccount = lounge.ethereum.getAccountByPeerID(peerID);
					} else {
						ethAccount = "none";
					}
					itemData.itemHeader = "Player \""+playerHandle+"\" has bet." + this.timestamp;
					itemData.itemDetails = "Peer ID: " + peerID + "\n";
					itemData.itemDetails += "Ethereum account: " + ethAccount + "\n";
					itemData.itemDetails += "Bet amount: " + eventObj.amount + "\n";
					itemData.itemDetails += "Balance: " + player.balance + "\n";					
					itemData.actionStatus = "done";
					break;
				case PokerBettingEvent.BET_FOLD:
					player = eventObj.sourcePlayer;
					peerID = player.netCliqueInfo.peerID;
					playerHandle = this._game.table.getInfoForPeer(peerID).handle;
					if (lounge.ethereum != null) {
						ethAccount = lounge.ethereum.getAccountByPeerID(peerID);
					} else {
						ethAccount = "none";
					}
					itemData.itemHeader = "Player \""+playerHandle+"\" has folded." + this.timestamp;
					itemData.itemDetails = "Peer ID: " + peerID + "\n";
					itemData.itemDetails += "Ethereum account: " + ethAccount + "\n";					
					itemData.itemDetails += "Balance: " + player.balance + "\n";
					break;
				case PokerBettingEvent.BETTING_NEW_BLINDS:					
					var bettingModule:PokerBettingModule = eventObj.target as PokerBettingModule;
					itemData.itemHeader = "Blinds timer has expired"+ this.timestamp;
					itemData.itemDetails = "New big blind value: " + bettingModule.currentSettings.currentLevelBigBlind +"\n";
					itemData.itemDetails += "New small blind value: " + bettingModule.currentSettings.currentLevelSmallBlind +"\n";
					itemData.itemDetails += "Values are in: " + bettingModule.currentSettings.currencyUnits + "\n";
					itemData.itemDetails += "New blinds time: " + bettingModule.currentSettings.currentTimer.getTimeString();
					itemData.itemType = "gameengine";
					itemData.actionStatus = "done";
					break;
				default: 
					return;
					break;
			}			
			this.statusList.dataProvider.addItem(itemData);
			this.statusList.invalidate();
			if (this.scrollLockToggleSwitch.isSelected) {
				this.statusList.scrollToDisplayIndex((this.statusList.dataProvider.length-1), 0.5);
			}
		}
		
		/**
		 * Event listener invoked when a current game instance is about to be destroyed. This invoked the 'destroy'
		 * method.
		 * 
		 * @param	eventObj A PokerGameStatusEvent object.
		 */
		private function onGameDestroy(eventObj:PokerGameStatusEvent):void {
			this.destroy();
		}
	}
}
/**
* Provides access to player profile information stored in the global settings data. Global settings data must be fully loaded and parsed
* prior to instantiating this class.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
	
	import feathers.controls.Label;
	import flash.events.EventPhase;
	import org.cg.SmartContract;
	import org.cg.events.LoungeEvent;
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.IWidget;
	import org.cg.interfaces.IPanelWidget;
	import org.cg.SlidingPanel;
	import feathers.controls.Button;
	import feathers.controls.PickerList;
	import feathers.controls.TextInput;
	import net.kawa.tween.KTween;
	import net.kawa.tween.easing.Quad;
	import starling.events.Event;
	import org.cg.events.EthereumEvent;
	import events.EthereumWeb3ClientEvent;
	import feathers.controls.Alert;
	import org.cg.StarlingViewManager;
	import org.cg.DebugView;
	import org.cg.GlobalSettings;
	import feathers.data.ListCollection;
	
	public class SmartContractManagerWidget extends PanelWidget implements IPanelWidget {
		
		public var contractAddressInput:TextInput
		public var contractsList:PickerList;
		public var addNewContractButton:Button;
		public var deployContractButton:Button;
		public var deleteContractButton:Button;
		public var addContractButton:Button;
		public var cancelAddContractButton:Button;
		public var deployStatusText:Label;
		
		public function SmartContractManagerWidget(loungeRef:ILounge, panelRef:SlidingPanel, widgetData:XML) {
			super(loungeRef, panelRef, widgetData);
			
		}
		
		private function addNewContract():void {		
			if (lounge.ethereum == null) {
				this.onEthereumDisabled(null);
				return;
			}
			var contractNodeStr:String = "<PokerHandData type=\"contract\" status=\"available\">";
			contractNodeStr += "<address>"+this.contractAddressInput.text+"</address>";
			contractNodeStr += "<txhash/>";
			contractNodeStr += "<interface>";
			//this is not future-friendly! Get from config?
			contractNodeStr += "<interface><![CDATA[[{\"constant\":true,\"inputs\":[],\"name\":\"baseCard\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"num_PublicCards\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"validationIndex\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"},{\"name\":\"cards\",\"type\":\"uint256[]\"}],\"name\":\"set_publicDecryptCards\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"target\",\"type\":\"address\"}],\"name\":\"num_PlayerCards\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"},{\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"playerKeys\",\"outputs\":[{\"name\":\"encKey\",\"type\":\"uint256\"},{\"name\":\"decKey\",\"type\":\"uint256\"},{\"name\":\"prime\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"winner\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"bigBlindHasBet\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"clear_winner\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"challengerAddr\",\"type\":\"address\"}],\"name\":\"set_challenger\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"},{\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"playerBestHands\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"playerChips\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"},{\"name\":\"betVal\",\"type\":\"uint256\"}],\"name\":\"set_playerBets\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"timeoutBlocks\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"initReady\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"sourceAddr\",\"type\":\"address\"},{\"name\":\"targetAddr\",\"type\":\"address\"}],\"name\":\"privateDecryptCardsIndex\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"},{\"name\":\"agreedVal\",\"type\":\"bool\"}],\"name\":\"set_agreed\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"reusable\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"},{\"name\":\"phaseNum\",\"type\":\"uint8\"}],\"name\":\"set_phase\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"num_winner\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"pot\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"targetAddr\",\"type\":\"address\"}],\"name\":\"num_PrivateCards\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"playerAddress\",\"type\":\"address\"},{\"name\":\"result\",\"type\":\"uint256\"}],\"name\":\"set_result\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"num_Players\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"complete\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"challenger\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"buyIn\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"playerHasBet\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"initBlock\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"primeVal\",\"type\":\"uint256\"},{\"name\":\"baseCardVal\",\"type\":\"uint256\"},{\"name\":\"buyInVal\",\"type\":\"uint256\"},{\"name\":\"timeoutBlocksVal\",\"type\":\"uint256\"}],\"name\":\"initialize\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"},{\"name\":\"cards\",\"type\":\"uint256[]\"}],\"name\":\"set_privateCards\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"blockNum\",\"type\":\"uint256\"}],\"name\":\"set_lastActionBlock\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"reusableSet\",\"type\":\"bool\"}],\"name\":\"set_reusable\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"},{\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"privateCards\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"}],\"name\":\"remove_playerKeys\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"sourceAddr\",\"type\":\"address\"},{\"name\":\"targetAddr\",\"type\":\"address\"}],\"name\":\"num_PrivateDecryptCards\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"target\",\"type\":\"address\"}],\"name\":\"num_Keys\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"completeSet\",\"type\":\"bool\"}],\"name\":\"set_complete\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"nonces\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"potVal\",\"type\":\"uint256\"}],\"name\":\"set_pot\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"},{\"name\":\"winnerAddr\",\"type\":\"address\"}],\"name\":\"add_declaredWinner\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"},{\"name\":\"cards\",\"type\":\"uint256[]\"}],\"name\":\"set_encryptedDeck\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"},{\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"publicDecryptCards\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"owner\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"},{\"name\":\"cards\",\"type\":\"uint256[]\"}],\"name\":\"set_publicCards\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"publicDecryptCardsInfo\",\"outputs\":[{\"name\":\"maxLength\",\"type\":\"uint256\"},{\"name\":\"playersAtMaxLength\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"bigBlindHasBetVal\",\"type\":\"bool\"}],\"name\":\"set_bigBlindHasBet\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"phaseNum\",\"type\":\"uint256\"}],\"name\":\"allPlayersAtPhase\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"newPlayers\",\"type\":\"address[]\"}],\"name\":\"new_players\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"playerAddress\",\"type\":\"address\"},{\"name\":\"index\",\"type\":\"uint256\"}],\"name\":\"set_validationIndex\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"agreed\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"betPositionVal\",\"type\":\"uint256\"}],\"name\":\"set_betPosition\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"lastActionBlock\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"playerAddress\",\"type\":\"address\"},{\"name\":\"index\",\"type\":\"uint256\"},{\"name\":\"suit\",\"type\":\"uint256\"},{\"name\":\"value\",\"type\":\"uint256\"}],\"name\":\"add_playerCard\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"betPosition\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"}],\"name\":\"length_encryptedDeck\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"},{\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"playerCards\",\"outputs\":[{\"name\":\"index\",\"type\":\"uint256\"},{\"name\":\"suit\",\"type\":\"uint256\"},{\"name\":\"value\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"},{\"name\":\"numChips\",\"type\":\"uint256\"}],\"name\":\"set_playerChips\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"playerAddress\",\"type\":\"address\"},{\"name\":\"cardIndex\",\"type\":\"uint256\"},{\"name\":\"index\",\"type\":\"uint256\"},{\"name\":\"suit\",\"type\":\"uint256\"},{\"name\":\"value\",\"type\":\"uint256\"}],\"name\":\"update_playerCard\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"numAuthorizedContracts\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"privateDecryptCards\",\"outputs\":[{\"name\":\"sourceAddr\",\"type\":\"address\"},{\"name\":\"targetAddr\",\"type\":\"address\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"},{\"name\":\"encKeys\",\"type\":\"uint256[]\"},{\"name\":\"decKeys\",\"type\":\"uint256[]\"}],\"name\":\"add_playerKeys\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"toAddr\",\"type\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"pay\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"authorizedGameContracts\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"playerBets\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"prime\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"card\",\"type\":\"uint256\"},{\"name\":\"index\",\"type\":\"uint256\"}],\"name\":\"set_publicCard\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"phases\",\"outputs\":[{\"name\":\"\",\"type\":\"uint8\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"declaredWinner\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"sourceAddr\",\"type\":\"address\"},{\"name\":\"targetAddr\",\"type\":\"address\"},{\"name\":\"cardIndex\",\"type\":\"uint256\"}],\"name\":\"getPrivateDecryptCard\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"},{\"name\":\"cards\",\"type\":\"uint256[]\"},{\"name\":\"targetAddr\",\"type\":\"address\"}],\"name\":\"set_privateDecryptCards\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"contractAddresses\",\"type\":\"address[]\"}],\"name\":\"setAuthorizedGameContracts\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"},{\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"encryptedDeck\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"winnerAddress\",\"type\":\"address\"}],\"name\":\"add_winner\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"nonce\",\"type\":\"uint256\"}],\"name\":\"agreeToContract\",\"outputs\":[],\"payable\":true,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"},{\"name\":\"hasBet\",\"type\":\"bool\"}],\"name\":\"set_playerHasBet\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"playerPhases\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"fromAddr\",\"type\":\"address\"},{\"name\":\"cardIndex\",\"type\":\"uint256\"},{\"name\":\"card\",\"type\":\"uint256\"}],\"name\":\"set_playerBestHands\",\"outputs\":[],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"results\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"players\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"publicCards\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"type\":\"function\"},{\"inputs\":[],\"payable\":false,\"type\":\"constructor\"},{\"payable\":false,\"type\":\"fallback\"}]]]></interface>";
			contractNodeStr += "</interface>";
			contractNodeStr += "</PokerHandData>";
			var newContractNode:XML = new XML(contractNodeStr);
			var smartContractsNode:XML = GlobalSettings.getSettingsCategory("smartcontracts");
			var ethereumNode:XML = smartContractsNode.child("ethereum")[0];
			var networkNodes:XMLList = ethereumNode.children();
			for (var count:int = 0; count < networkNodes.length(); count++) {
				var currentNetworkNode:XML = networkNodes[count];
				if ((currentNetworkNode.localName() == "network") && (currentNetworkNode.@id == lounge.ethereum.client.networkID)) {					
					currentNetworkNode.appendChild(newContractNode);
					GlobalSettings.saveSettings();
					return;
				}
			}
		}
		
		private function deployNewContract():void {
			
		}
		
		private function onAddNewContractClick(eventObj:Event):void {
			this.contractsList.isEnabled = false;
			this.contractsList.visible = false;
			this.contractAddressInput.text = "";
			this.contractAddressInput.isEnabled = true;
			this.contractAddressInput.visible = true;
			this.showAddContractButtons();
		}
		
		private function onAddContractClick(eventObj:Event):void {
			this.addNewContract();			
			this.contractAddressInput.isEnabled = false;
			this.contractAddressInput.visible = false;
			this.contractsList.isEnabled = true;
			this.contractsList.visible = true;
			this.contractsList.dataProvider.addItem({text:this.contractAddressInput.text, descriptor:null});
			this.contractsList.selectedIndex = this.contractsList.dataProvider.length - 1;
			this.hideAddContractButtons();
		}
		
		private function onCancelAddContractClick(eventObj:Event):void {
			this.contractAddressInput.isEnabled = false;
			this.contractAddressInput.visible = false;
			if (this.contractsList.dataProvider.length == 0) {
				this.contractsList.isEnabled = false;
				this.contractsList.prompt = "no contracts found";
			} else {
				this.contractsList.isEnabled = true;
			}
			this.contractsList.visible = true;
			this.hideAddContractButtons();
		}
		
		private function onNoEthereumAlertClose(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.CLOSE, this.onNoEthereumAlertClose);
			if (eventObj.data.enableEthereum) {
				try {
					var ethereumWidget:IWidget = getInstanceByClass("org.cg.widgets.EthereumEnableWidget")[0];
					ethereumWidget.activate(true);
				} catch (err:*) {
					DebugView.addText ("   Couldn't find registered widget instance from class  \"org.cg.widgets.EthereumEnableWidget\"");
				}
			} else {
				
			}
		}
		
		private function onNoAccountAlertClose(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.CLOSE, this.onNoAccountAlertClose);
			if (eventObj.data.setAccountDetails) {
				try {
					var accountWidget:IWidget = getInstanceByClass("org.cg.widgets.EthereumAccountWidget")[0];
					accountWidget.activate(true);
				} catch (err:*) {
					DebugView.addText ("   Couldn't find registered widget instance from class  \"org.cg.widgets.EthereumAccountWidget\"");
				}
			} else {
				
			}
		}
		
		private function onDeleteAlertClose(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.CLOSE, this.onDeleteAlertClose);
			if (eventObj.data.removeContract) {	
				DebugView.addText ("Deleting: " + this.contractsList.selectedItem.descriptor);
				var ethereumNode:XML = GlobalSettings.getSetting("smartcontracts", "ethereum");
				var networkNodes:XMLList = ethereumNode.child("network") as XMLList;				
				for (var count:int = 0; count < networkNodes.length(); count++) {
					var currentNetworkNode:XML = networkNodes[count] as XML;
					var currentNetworkID:int = int(currentNetworkNode.@id);
					if (currentNetworkID == lounge.ethereum.client.networkID) {
						for (var count2:int = 0; count2 < currentNetworkNode.children().length(); count2++) {
							if (currentNetworkNode.children()[count2] == this.contractsList.selectedItem.descriptor) {
								delete currentNetworkNode.children()[count2];
								break;
							}
						}
						break;
					}
				}
				this.contractsList.dataProvider.removeItemAt(this.contractsList.selectedIndex);
				if (this.contractsList.dataProvider.length < 1) {
					this.contractsList.isEnabled = false;
					this.deleteContractButton.isEnabled = false;
				} else {
					this.contractsList.selectedIndex = 0;
				}
				this.contractsList.invalidate();
				GlobalSettings.saveSettings();
			}
		}
		
		private function onDeployContractClick(eventObj:Event):void {			
			if (lounge.ethereum == null) {
				var alert:Alert=StarlingViewManager.alert("Ethereum integration must be enabled in order to deploy a contract. Would you like to enable it now?", "Ethereum not available", new ListCollection([{label:"YES", enableEthereum:true}, {label:"NO", enableEthereum:false}]), null, true, true);
				alert.addEventListener(Event.CLOSE, this.onNoEthereumAlertClose);
				return;
			}			
			if ((lounge.ethereum.account == null) || (lounge.ethereum.account == "") || (lounge.ethereum.password == null) || (lounge.ethereum.password == "")) {
				alert=StarlingViewManager.alert("Ethereum account and password must be set in order to deploy a contract. Set them now?", "No account or password", new ListCollection([{label:"YES", setAccountDetails:true}, {label:"NO", setAccountDetails:false}]), null, true, true);
				alert.addEventListener(Event.CLOSE, this.onNoAccountAlertClose);
				return;
			}
			this.contractsList.isEnabled = false;
			this.addNewContractButton.isEnabled = false;
			this.deployContractButton.isEnabled = false;
			this.deleteContractButton.isEnabled = false;			
			//the should be in its own widget
			lounge.ethereum.client.addEventListener(EthereumWeb3ClientEvent.SOLCOMPILED, this.onCompileContract);
			lounge.ethereum.client.compileSolidityFile();			
		}
		
		private function onDeleteContractClick(eventObj:Event):void {
			var alert:Alert=StarlingViewManager.alert("Are you sure you want to remove the selected contract information?", "Remove contract information", new ListCollection([{label:"YES", removeContract:true}, {label:"NO", removeContract:false}]), null, true, true);
			alert.addEventListener(Event.CLOSE, this.onDeleteAlertClose);
			return;
		}
		
		private function onCompileContract(eventObj:EthereumWeb3ClientEvent):void {
			DebugView.addText("SmartContractManagerWidget.onCompileContract");
			DebugView.addText(eventObj.compiledRaw);
			this.addNewContractButton.visible = false;
			this.deployContractButton.visible = false;
			this.deleteContractButton.visible = false;	
			this.deployStatusText.text = "Compiling contract data...";
			var deployedContractsObj:Object = lounge.ethereum.generateDeployedLibsObj("ethereum", lounge.ethereum.client.networkID);
			lounge.ethereum.addEventListener(EthereumEvent.CONTRACTSDEPLOYED, this.onDeployContract);
			lounge.ethereum.addEventListener(EthereumEvent.CONTRACTDEPLOYING, this.onDeployContractStatus);
			lounge.ethereum.deployLinkedContracts(eventObj.compiledData, [], lounge.ethereum.account, lounge.ethereum.password, deployedContractsObj);
			lounge.ethereum.startMining(2);
		}
		
		private function onDeployContractStatus(eventObj:EthereumEvent):void {
			this.deployStatusText.text = "Contract waiting to be mined.\nTxHash: "+eventObj.txhash;
		}
		
		private function onDeployContract(eventObj:EthereumEvent):void {
			DebugView.addText("SmartContractManagerWidget.onDeployContract");
			this.addNewContractButton.visible = true;
			this.deployContractButton.visible = true;
			this.deleteContractButton.visible = true;	
			this.deployStatusText.text = "";
			lounge.ethereum.removeEventListener(EthereumEvent.CONTRACTSDEPLOYED, this.onDeployContract);
			lounge.ethereum.removeEventListener(EthereumEvent.CONTRACTDEPLOYING, this.onDeployContractStatus);
			//lounge.ethereum.stopMining();
			var contractNodeStr:String = "<"+eventObj.contractName+" type=\"contract\" status=\"new\">";
			contractNodeStr += "<address> " + eventObj.contractAddress + "</address>";
			contractNodeStr += "<txhash>"+eventObj.txhash+"</txhash>";
			contractNodeStr	+= "<interface>"+eventObj.contractInterface+"</interface>";
			contractNodeStr	+= "</"+eventObj.contractName+">";
			var contractNode:XML = new XML(contractNodeStr);
			var ethereumNode:XML = GlobalSettings.getSetting("smartcontracts", "ethereum");
			var networkNodes:XMLList = ethereumNode.child("network") as XMLList;				
			for (var count:int = 0; count < networkNodes.length(); count++) {
				var currentNetworkNode:XML = networkNodes[count] as XML;
				var currentNetworkID:int = int(currentNetworkNode.@id);
				if (currentNetworkID == lounge.ethereum.client.networkID) {
					currentNetworkNode.appendChild(contractNode);
					GlobalSettings.saveSettings();
					break;
				}
			}
			lounge.ethereum.unlockAccount();
			SmartContract.ethereum = lounge.ethereum; //in case it's not set or set to a dead instance
			//Set validated addresses of: PokerHandValidator, PokerHandStartup, PokerHandActions, PokerHandResolutions
			DebugView.addText("lounge.ethereum.client.networkID=" + lounge.ethereum.client.networkID);
			var descriptor:XML = SmartContract.getValidatedDescriptor("PokerHandValidator", "ethereum", lounge.ethereum.client.networkID, "*", "library", false);
			var contract:SmartContract = new SmartContract("PokerHandValidator", lounge.ethereum.account, lounge.ethereum.password, descriptor);
			var contractsArray:Array = [contract.address];			
			descriptor = SmartContract.getValidatedDescriptor("PokerHandStartup", "ethereum", lounge.ethereum.client.networkID, "*", "library", false);
			contract = new SmartContract("PokerHandStartup", lounge.ethereum.account, lounge.ethereum.password, descriptor);
			contractsArray.push(contract.address);			
			descriptor = SmartContract.getValidatedDescriptor("PokerHandActions", "ethereum", lounge.ethereum.client.networkID, "*", "library", false);
			contract = new SmartContract("PokerHandActions", lounge.ethereum.account, lounge.ethereum.password, descriptor);
			contractsArray.push(contract.address);
			descriptor = SmartContract.getValidatedDescriptor("PokerHandSignedActions", "ethereum", lounge.ethereum.client.networkID, "*", "library", false);
			contract = new SmartContract("PokerHandSignedActions", lounge.ethereum.account, lounge.ethereum.password, descriptor);
			contractsArray.push(contract.address);
			descriptor = SmartContract.getValidatedDescriptor("PokerHandResolutions", "ethereum", lounge.ethereum.client.networkID, "*", "library", false);
			contract = new SmartContract("PokerHandResolutions", lounge.ethereum.account, lounge.ethereum.password, descriptor);
			contractsArray.push(contract.address);
			//set initial authorized game contracts in data	
			contract = new SmartContract("PokerHandData", lounge.ethereum.account, lounge.ethereum.password, contractNode);
			DebugView.addText ("contractsArray=" + contractsArray);
			contract.setAuthorizedGameContracts(contractsArray).invoke({from:lounge.ethereum.account, gas:2000000});
			this.contractsList.dataProvider.addItem({text:eventObj.contractAddress, descriptor:contractNode});
			this.contractsList.selectedIndex = this.contractsList.dataProvider.length - 1;
			this.contractsList.isEnabled = true;
			this.addNewContractButton.isEnabled = true;
			this.deployContractButton.isEnabled = true;
			this.deleteContractButton.isEnabled = true;	
		}
		
		private function hideAddContractButtons(viewInit:Boolean = false):void {
			if (lounge.ethereum != null) {
				this.addNewContractButton.isEnabled = true;
				this.deployContractButton.isEnabled = true;
			}
			this.addNewContractButton.visible = true;
			this.deployContractButton.visible = true;
			this.deleteContractButton.visible = true;
			this.addContractButton.isEnabled = false;
			this.cancelAddContractButton.isEnabled = false;
			if (this.contractsList.dataProvider != null) {
				if (this.contractsList.dataProvider.length > 0) {
					this.deleteContractButton.isEnabled = true;
				}
			}
			KTween.to(this.addNewContractButton, 0.3, {alpha:1}, Quad.easeInOut);
			KTween.to(this.deployContractButton, 0.3, {alpha:1}, Quad.easeInOut);
			KTween.to(this.deleteContractButton, 0.3, {alpha:1}, Quad.easeInOut);
			KTween.to(this.addContractButton, 0.3, {alpha:0}, Quad.easeInOut, function():void{addContractButton.visible = false;});
			KTween.to(this.cancelAddContractButton, 0.3, {alpha:0}, Quad.easeInOut, function():void{cancelAddContractButton.visible = false;});
		}
		
		private function showAddContractButtons():void {
			this.addContractButton.isEnabled = true;
			this.cancelAddContractButton.isEnabled = true;
			this.addContractButton.visible = true;
			this.cancelAddContractButton.visible = true;
			this.addNewContractButton.isEnabled = false;
			this.deployContractButton.isEnabled = false;
			this.deleteContractButton.isEnabled = false;
			KTween.to(this.addNewContractButton, 0.3, {alpha:0}, Quad.easeInOut, function():void{addNewContractButton.visible = false;});
			KTween.to(this.deployContractButton, 0.3, {alpha:0}, Quad.easeInOut, function():void{deployContractButton.visible = false; });
			KTween.to(this.deleteContractButton, 0.3, {alpha:0}, Quad.easeInOut, function():void{deleteContractButton.visible = false;});
			KTween.to(this.addContractButton, 0.3, {alpha:1}, Quad.easeInOut);
			KTween.to(this.cancelAddContractButton, 0.3, {alpha:1}, Quad.easeInOut);
		}
		
		private function populateContractsList():void {			
			if (lounge.ethereum == null) {
				this.onEthereumDisabled(null);
				return;
			}
			this.contractsList.dataProvider = new ListCollection();
			this.contractsList.isEnabled = true;
			this.addContractButton.isEnabled = true;
			this.deployContractButton.isEnabled = true;
			var smartContractsNode:XML = GlobalSettings.getSettingsCategory("smartcontracts");
			var ethereumNode:XML = smartContractsNode.child("ethereum")[0];
			var networkNodes:XMLList = ethereumNode.children();
			for (var count:int = 0; count < networkNodes.length(); count++) {
				var currentNetworkNode:XML = networkNodes[count];				
				if ((currentNetworkNode.localName() == "network") && (int(currentNetworkNode.@id) == lounge.ethereum.client.networkID)) {					
					var contractNodes:XMLList = currentNetworkNode.children();					
					for (var count2:int = 0; count2 < contractNodes.length(); count2++) {
						var currentContractNode:XML = contractNodes[count2];						
						var contractName:String = currentContractNode.localName();
						var contractType:String = String(currentContractNode.@type);
						var contractStatus:String = String(currentContractNode.@status);
						var contractAddress:String = currentContractNode.child("address")[0].toString();
						if ((contractType == "contract") && ((contractStatus == "new") || (contractStatus == "available"))) {							
							this.contractsList.dataProvider.addItem({text: contractAddress, descriptor:currentContractNode});							
						}
					}					
					if (this.contractsList.dataProvider.length < 1) {
						this.contractsList.isEnabled = false;
						this.deleteContractButton.isEnabled = false;
						this.contractsList.prompt = "no contracts found";
					} else {
						this.deleteContractButton.isEnabled = true;
						this.contractsList.selectedIndex = 0;
					}
					return;
				}
			}
		}
		
		private function onEthereumEnabled(eventObj:LoungeEvent):void {
			DebugView.addText ("SmartContractManagerWidget.onEthereumEnabled");
			this.contractsList.isEnabled = true;
			this.populateContractsList();			
			this.addNewContractButton.isEnabled = true;
			this.deployContractButton.isEnabled = true;
			lounge.ethereum.addEventListener(EthereumEvent.DESTROY, this.onEthereumDisabled);
		}
		
		private function onEthereumDisabled(eventObj:EthereumEvent):void {
			if (lounge.ethereum!=null) {
				lounge.ethereum.removeEventListener(EthereumEvent.DESTROY, this.onEthereumDisabled);
			}
			this.hideAddContractButtons();
			if (this.contractsList.dataProvider != null) {
				this.contractsList.dataProvider.removeAll();
				this.contractsList.dataProvider = null;
				this.contractsList.prompt = "Ethereum is disabled";
			}
			this.contractsList.isEnabled = false;
			this.addNewContractButton.isEnabled = false;
			this.deployContractButton.isEnabled = false;
			this.deleteContractButton.isEnabled = false;
		}
		
		override public function initialize():void {
			DebugView.addText ("SmartContractManagerWidget.initialize");
			lounge.addEventListener(LoungeEvent.NEW_ETHEREUM, this.onEthereumEnabled);
			this.populateContractsList();
			this.hideAddContractButtons();
			this.addNewContractButton.addEventListener(Event.TRIGGERED, this.onAddNewContractClick);
			this.deployContractButton.addEventListener(Event.TRIGGERED, this.onDeployContractClick);
			this.addContractButton.addEventListener(Event.TRIGGERED, this.onAddContractClick);
			this.cancelAddContractButton.addEventListener(Event.TRIGGERED, this.onCancelAddContractClick);
			this.deleteContractButton.addEventListener(Event.TRIGGERED, this.onDeleteContractClick);
		}
		
	}

}
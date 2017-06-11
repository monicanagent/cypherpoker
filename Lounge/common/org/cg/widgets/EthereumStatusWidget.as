/**
* Widget to control main Ethereum connetcion and configuration.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
	
	import com.bit101.components.List;
	import events.EthereumWeb3ClientEvent;
	import feathers.controls.Alert;
	import feathers.controls.Button;
	import feathers.controls.Check;
	import feathers.controls.Label;
	import feathers.controls.PickerList;
	import feathers.controls.TextInput;
	import feathers.controls.ToggleSwitch;
	import feathers.data.ListCollection;
	import feathers.data.XMLListListCollectionDataDescriptor;	
	import feathers.events.FeathersEventType;
	import flash.geom.Point;
	import org.cg.interfaces.IPanelWidget;
	import org.cg.Lounge;
	import org.cg.GlobalSettings;
	import org.cg.SlidingPanel;
	import org.cg.events.SlidingPanelEvent;
	import org.cg.DebugView;
	import org.cg.StarlingViewManager;
	import feathers.controls.ToggleButton;
	import org.cg.events.EthereumEvent;
	import EthereumClientTunnel;
	import org.cg.events.LoungeEvent;
	import p2p3.interfaces.INetClique;
	import starling.events.Event;
	import net.kawa.tween.KTween;
	import net.kawa.tween.easing.Quad;
	import flash.utils.getDefinitionByName;
	
	public class EthereumStatusWidget extends PanelWidget implements IPanelWidget {
		
		//UI components and data rendered by StarlingViewManager:
		public var toggle:ToggleButton;	
		public var enableautolaunch:Check;
		public var statusText:Label;
		public var networkList:PickerList;
		public var dataDirectoryPrompt:Label;
		public var selectDataDirButton:Button;
		public var showSettingsButton:Button;
		public var networkListPrompt:Label;
		public var clientAddressPrompt:Label;
		public var clientAddressInput:TextInput;
		public var clientPortPrompt:Label;
		public var clientPortInput:TextInput;
		public var launchClientPrompt:Label;
		public var launchClientProcessToggle:ToggleSwitch;
		public var enablemessage:String = "Enable Ethereum Integration";
		public var enablingmessage:String = "Enabling Ethereum Integration..."; 
		public var enabledmessage:String = "Disable Ethereum Integration";		
		private var _clientTunnel:EthereumClientTunnel = null; //Ethereum client connectivity assist tunnel (not currently used)
		private var _dirFile:*; //File instance used to select the Ethereum client's data directory
		//Origin (starting) points for UI components:
		private var _launchClientToggleOrigin:Point;
		private var _enableAutoLaunchOrigin:Point;
		private var _selectDaraDirOrigin:Point;
		private var _showSettingsOrigin:Point;
		private var _networkListOrigin:Point;	
		private var _networkListPromptOrigin:Point;
		private var _launchClientPromptOrigin:Point;
		private var _dataDirectoryPromptOrigin:Point;
		private var _clientAddrPromptOrigin:Point;
		private var _clientAddrInputOrigin:Point;
		private var _clientPortPromptOrigin:Point;
		private var _clientPortInputOrigin:Point;		
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	loungeRef A reference to the main ILounge implementation instance.
		 * @param	container The widget's parent panel or display object container.
		 * @param	widgetData The widget's configuration XML data, usually from the global settings data.
		 */
		public function EthereumStatusWidget(loungeRef:Lounge, panelRef:SlidingPanel, widgetData:XML) {
			DebugView.addText("EthereumStatusWidget widget created.");
			super (loungeRef, panelRef,	widgetData)			
		}
		
		/**		 
		 * Initializes the widget after it's been added to the display list and all child components have been created.
		 */
		override public function initialize():void {
			DebugView.addText("EthereumStatusWidget initialize");
			try {
				var ethereumEnabled:Boolean = GlobalSettings.toBoolean(GlobalSettings.getSetting("defaults", "ethereum").enabled);				
			} catch (err:*) {		
				ethereumEnabled = false;
			}
			this.toggle.addEventListener(Event.CHANGE, this.onToggleClick);			
			if (ethereumEnabled == true) {
				this.enableautolaunch.isSelected = true;
				this.enableautolaunch.invalidate();
			}
			var networkListData:ListCollection = new ListCollection();
			networkListData.addItem({text:"Mainnet", id:1, network:null});
			//networkListData.addItem({text:"Kovan Testnet", id:42, network:EthereumWeb3Client.CLIENTNET_KOVAN});
			networkListData.addItem({text:"Ropsten Testnet", id:3, network:EthereumWeb3Client.CLIENTNET_ROPSTEN});
			networkListData.addItem({text:"Private Devnet", id:4, network:EthereumWeb3Client.CLIENTNET_DEV});
			this.networkList.dataProvider = networkListData;
			this.networkList.selectedIndex = 0;
			/*
			//set network selection if already connected
			if (lounge.parentLounge != null) {
				if (lounge.parentLounge.ethereum != null) {				
					switch (lounge.parentLounge.ethereum.client.networkID) {
						case 1 : this.networkList.selectedIndex = 0; break;
						case 3 : this.networkList.selectedIndex = 1; break;
						case 4 : this.networkList.selectedIndex = 2; break;
						default: this.networkList.selectedIndex = 0; break;
					}
				}
			}
			*/
			this.updateDataDirButton();
			if (lounge.isChildInstance) {				
				this.selectDataDirButton.isEnabled = false;
				this.launchClientProcessToggle.isEnabled = false;
			}
			this._showSettingsOrigin = new Point(this.showSettingsButton.x, this.showSettingsButton.y);
			this._enableAutoLaunchOrigin = new Point(this.enableautolaunch.x, this.enableautolaunch.y);
			this._selectDaraDirOrigin = new Point(this.selectDataDirButton.x, this.selectDataDirButton.y);			
			this._launchClientToggleOrigin = new Point(this.launchClientProcessToggle.x, this.launchClientProcessToggle.y);
			this._networkListPromptOrigin = new Point(this.networkListPrompt.x, this.networkListPrompt.y);			
			this._networkListOrigin = new Point(this.networkList.x, this.networkList.y);
			this._clientAddrPromptOrigin = new Point(this.clientAddressPrompt.x, this.clientAddressPrompt.y);
			this._clientPortPromptOrigin = new Point(this.clientPortPrompt.x, this.clientPortPrompt.y);
			this._launchClientPromptOrigin = new Point(this.launchClientPrompt.x, this.launchClientPrompt.y);
			this._dataDirectoryPromptOrigin = new Point(this.selectDataDirButton.x, this.selectDataDirButton.y);
			this._clientAddrInputOrigin = new Point(this.clientAddressInput.x, this.clientAddressInput.y);
			this._clientPortInputOrigin = new Point(this.clientPortInput.x, this.clientPortInput.y);					
			if ((GlobalSettings.systemSettings.isStandalone == false) || (GlobalSettings.systemSettings.isAIR == false)) {
				//not supported by runtime
				this.launchClientProcessToggle.isEnabled = false;
			} else if (!lounge.isChildInstance) {
				this.launchClientProcessToggle.isSelected = true;
			}
			//add listener only after updating!		
			this.enableautolaunch.addEventListener(Event.CHANGE, this.onAutoLaunchClick);
			this.selectDataDirButton.addEventListener(Event.TRIGGERED, this.onSelectDataDirClick);
			this.launchClientProcessToggle.addEventListener(Event.CHANGE, this.onLaunchClientProcessToggle);
			this.showSettingsButton.addEventListener(Event.TRIGGERED, this.onShowSettingsClick);
			lounge.addEventListener(LoungeEvent.NEW_ETHEREUM, this.onEthereumEnabled);
			this.panel.addEventListener(SlidingPanelEvent.CLOSE, this.onCloseParentPanel);
			this.udpateAddressPortInputs();
			this.clientAddressInput.addEventListener(FeathersEventType.FOCUS_OUT, this.onClientAddressPortUpdate);
			this.clientPortInput.addEventListener(FeathersEventType.FOCUS_OUT, this.onClientAddressPortUpdate);
			super.initialize();
			this.hideSettings();
		}
		
		override public function get width():Number {
			if (this._showSettingsOrigin != null) {
				if (this.showSettingsButton.x == this._showSettingsOrigin.x) {
					return (this.showSettingsButton.x + this.showSettingsButton.width + 20);
				} else {
					return (super.width);
				}
			}
			return (super.width);
		}
		
		/**
		 * Updates the visibility of settings components, usually when a tween has completed.
		 */
		public function updateSettingsVisibility():void {
			if (this.launchClientProcessToggle.alpha == 0) {
				this.launchClientProcessToggle.visible = false;
			}
			if (this.selectDataDirButton.alpha == 0) {
				this.selectDataDirButton.visible = false;
			}
			if (this.enableautolaunch.alpha == 0) {
				this.enableautolaunch.visible = false;
			}
			if (this.showSettingsButton.alpha == 0) {
				this.showSettingsButton.visible = false;
			}
			if (this.networkList.alpha == 0) {
				this.networkList.visible = false;
			}
			if (this.clientPortInput.alpha == 0) {
				this.clientPortInput.visible = false;
			}
			if (this.clientAddressInput.alpha == 0) {
				this.clientAddressInput.visible = false;
			}
		}
		
		/**
		 * @return A reference to the "flash.filesystem.File" class if available in the current runtime, or null if unavailable.
		 */
		private static function get File():Class {
			try {
				var fileClass:Class = getDefinitionByName("flash.filesystem.File") as Class;
				return (fileClass);
			} catch (err:*) {				
			}
			return (null);
		}
		
		/**
		 * Updates the client address and port input components with values from the global settings data.
		 */
		private function udpateAddressPortInputs():void {
			try {
				var ethereumSettings:XML = GlobalSettings.getSetting("defaults", "ethereum");
				var addressNode:XML = ethereumSettings.child("clientaddress")[0];
				var portNode:XML = ethereumSettings.child("clientport")[0];
				this.clientAddressInput.text = addressNode.children().toString();
				this.clientPortInput.text = portNode.children().toString();
			} catch (err:*) {				
			}
		}
		
		/**
		 * Hides the client settings components such as host address, port, data directory, and launch native client toggle.
		 */
		private function hideSettings():void {
			this.showSettingsButton.visible = true;
			this.showSettingsButton.isEnabled = true;
			KTween.to (this.launchClientPrompt, 0.5, {x:0, alpha:0}, Quad.easeIn);
			KTween.to (this.launchClientProcessToggle, 0.5, {x:0, alpha:0}, Quad.easeIn, this.updateSettingsVisibility);
			KTween.to (this.dataDirectoryPrompt, 0.5, {x:0, alpha:0}, Quad.easeIn);
			KTween.to (this.selectDataDirButton, 0.5, {x:0, alpha:0}, Quad.easeIn, this.updateSettingsVisibility);
			KTween.to (this.enableautolaunch, 0.5, {x:0, alpha:0}, Quad.easeIn, this.updateSettingsVisibility);
			KTween.to (this.networkList, 0.5, {x:0, alpha:0}, Quad.easeIn, this.updateSettingsVisibility);
			KTween.to (this.networkListPrompt, 0.5, {x:0, alpha:0}, Quad.easeOut);
			KTween.to (this.clientAddressPrompt, 0.5, {x:0, alpha:0}, Quad.easeOut);
			KTween.to (this.clientAddressInput, 0.5, {x:0, alpha:0}, Quad.easeIn, this.updateSettingsVisibility);			
			KTween.to (this.clientPortPrompt, 0.5, {x:0, alpha:0}, Quad.easeOut);
			KTween.to (this.clientPortInput, 0.5, {x:0, alpha:0}, Quad.easeIn, this.updateSettingsVisibility);
			KTween.to (this.showSettingsButton, 0.5, {x:this._showSettingsOrigin.x, alpha:1}, Quad.easeOut);
		}
		
		/**
		 * Shows the client settings components such as host address, port, data directory, and launch native client toggle.
		 */
		private function showSettings():void {
			this.showSettingsButton.isEnabled = false;
			this.launchClientProcessToggle.visible = true;
			this.selectDataDirButton.visible = true;
			this.enableautolaunch.visible = true;
			this.networkList.visible = true;
			this.clientAddressInput.visible = true;
			this.clientPortInput.visible = true;
			this.clientAddressInput.isEnabled = true;
			this.clientPortInput.isEnabled = true;
			KTween.to (this.launchClientPrompt, 0.5, {x:this._launchClientPromptOrigin.x, alpha:1}, Quad.easeOut);
			KTween.to (this.launchClientProcessToggle, 0.5, {x:this._launchClientToggleOrigin.x, alpha:1}, Quad.easeOut);
			KTween.to (this.dataDirectoryPrompt, 0.5, {x:this._dataDirectoryPromptOrigin.x, alpha:1}, Quad.easeOut);
			KTween.to (this.selectDataDirButton, 0.5, {x:this._selectDaraDirOrigin.x, alpha:1}, Quad.easeOut);
			KTween.to (this.enableautolaunch, 0.5, {x:this._enableAutoLaunchOrigin.x, alpha:1}, Quad.easeOut);
			KTween.to (this.networkListPrompt, 0.5, {x:this._networkListPromptOrigin.x, alpha:1}, Quad.easeOut);
			KTween.to (this.networkList, 0.5, {x:this._networkListOrigin.x, alpha:1}, Quad.easeOut);
			KTween.to (this.clientAddressPrompt, 0.5, {x:this._clientAddrPromptOrigin.x, alpha:1}, Quad.easeOut);
			KTween.to (this.clientPortPrompt, 0.5, {x:this._clientPortPromptOrigin.x, alpha:1}, Quad.easeOut);
			KTween.to (this.clientAddressInput, 0.5, {x:this._clientAddrInputOrigin.x, alpha:1}, Quad.easeOut);
			KTween.to (this.clientPortInput, 0.5, {x:this._clientPortInputOrigin.x, alpha:1}, Quad.easeOut);			
			KTween.to (this.showSettingsButton, 0.5, {x:0, alpha:0}, Quad.easeIn, this.updateSettingsVisibility);
		}
		
		/**
		 * Event listener incoked when either the client or port input components have lost focus.
		 * 
		 * @param	eventObj A Starling Event object.
		 */
		private function onClientAddressPortUpdate(eventObj:Event):void {
			if (this.clientAddressInput.text == "") {
				StarlingViewManager.alert("Enter a valid address for the Ethereum client RPC-API.", "Invalid RPC-API Address", new ListCollection([{label:"OK"}]), null, true, true);
				return;
			}
			if ((this.clientPortInput.text == "") || (this.clientPortInput.text == "0")) {
				StarlingViewManager.alert("Enter a valid port number for the Ethereum client RPC-API.", "Invalid RPC-API Port Value", new ListCollection([{label:"OK"}]), null, true, true);
				return;
			}
			var ethereumSettings:XML = GlobalSettings.getSetting("defaults", "ethereum");
			var addressNode:XML = ethereumSettings.child("clientaddress")[0];
			var portNode:XML = ethereumSettings.child("clientport")[0];
			addressNode.replace("*", new XML("<![CDATA[" + this.clientAddressInput.text + "]]>"));
			portNode.replace("*", new XML(this.clientPortInput.text));
			GlobalSettings.saveSettings();
		}
		
		/**
		 * Event listener invoked when parent SlidingPanel dispatches a SlidingPanelEvent.CLOSE event.
		 * 
		 * @param	eventObj A SlidingPanelEvent object.
		 */
		private function onCloseParentPanel(eventObj:SlidingPanelEvent):void {
			if (this.showSettingsButton.visible == false) {
				this.hideSettings();
			}
		}
		
		/**
		 * Event listener invoked when the "show settings" button is clicked.
		 * 
		 * @param	eventObj A Starling Event object.
		 */
		private function onShowSettingsClick(eventObj:Event):void {
			this.showSettings();
		}
		
		/**
		 * Event listener invoked when the Ethereum "enable/disable" button is clicked.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onToggleClick(eventObj:Event):void {			
			if (this.toggle.isSelected) {
				this.hideSettings();
				this.toggle.label = this.enablingmessage;
				this.toggle.isEnabled = false;				
				this.enableEthereumIntegration();
			} else {
				this.disableEthereumIntegration();
				this.toggle.label = this.enablemessage;
			}
		}
		
		/**
		 * Event listener invoked when the "auto launch Ethereum" checkbox is clicked.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onAutoLaunchClick(eventObj:Event):void {			
			var ethereumNode:XML = GlobalSettings.getSetting("defaults", "ethereum");
			if (ethereumNode.child("enabled").length() < 1) {
				var enabledNode:XML = ethereumNode.appendChild(new XML("<enabled />"));	
			} else {
				enabledNode = ethereumNode.child("enabled")[0];	
			}
			if (this.enableautolaunch.isSelected) {				
				enabledNode.replace("*", new XML("true"));
			} else {
				enabledNode.replace("*", new XML("false"));				
			}
			GlobalSettings.saveSettings();
		}
		
		/**
		 * Enables Ethereum integration using the current settings via the main lounge instance's Ethereum object. An event listener is added to
		 * track the synchronization status of the client using the 'onClientSyncProgress' method. If the "launch client process" toggle is enabled
		 * and the local Ethereum client installation can't be found an Alert is displayed to ask the user if they want to download and install
		 * the latest client specified in the global settings data.
		 */
		private function enableEthereumIntegration():void {
			this.disableEthereumIntegration();
			var clientAddress:String = null;
			var clientPort:uint = 0;
			try {
				var ethereumSettings:XML = GlobalSettings.getSetting("defaults", "ethereum");
				var addressNode:XML = ethereumSettings.child("clientaddress")[0];
				var portNode:XML = ethereumSettings.child("clientport")[0];
				clientAddress = addressNode.children().toString();
				clientPort = uint(portNode.children().toString());
			} catch (err:*) {
				clientAddress = null;
				clientPort = 0;
			}
			if (isNaN(clientPort)) {
				clientPort = 0;
			}
			if ((clientAddress == null) || (clientPort == 0)) {
				this.showSettings();
				StarlingViewManager.alert ("The Ethereum client RPC-API settings are invalid. Please update.", "Invalid RPC-API Settings", new ListCollection([{label:"OK"}]), null, true, true);
				return;
			}
			this.showSettingsButton.isEnabled = false;
			this.networkList.isEnabled = false;
			this.selectDataDirButton.isEnabled = false;
			this.launchClientProcessToggle.isEnabled = false;			
			this.clientAddressInput.isEditable = false;
			this.clientPortInput.isEditable = false;
			this.lounge.ethereumEnabled = true; //must set to true to enable launch functionality
			var launchInfo:Object = new Object();
			launchInfo.clientaddress = clientAddress;
			launchInfo.clientPort = clientPort;
			launchInfo.networkid = int(this.networkList.selectedItem.id);
			launchInfo.nativeclientnetwork = this.networkList.selectedItem.network;
			if (this.launchClientProcessToggle.isSelected == false) {
				launchInfo.datadirectory = "";
				launchInfo.nativeclientfolder = "";				
			}
			this.lounge.ethereum = this.lounge.launchEthereum(launchInfo);
			if ((lounge.isChildInstance) || (this.launchClientProcessToggle.isSelected == false)) {
				this.lounge.ethereum.addEventListener(EthereumEvent.CLIENTSYNCEVENT, this.onClientSyncProgress);
				this.lounge.ethereum.startMonitorSyncStatus();
			} else {
				if (this.lounge.ethereum.client.nativeClientInstalled) {
					this.lounge.ethereum.client.loadNativeClient();
					this.lounge.ethereum.addEventListener(EthereumEvent.CLIENTSYNCEVENT, this.onClientSyncProgress);
					this.lounge.ethereum.startMonitorSyncStatus();
				} else {
					var alert:Alert = StarlingViewManager.alert("Ethereum client not found. Do you want to download and install a new version?", "Ethereum Client Not Found", new ListCollection([{label:"Yes", download:true}, {label:"No", download:false}]), null, true, true);
					alert.addEventListener(Event.CLOSE, this.onInstallEthereumAlertClose);
				}
			}
		}
		
		/**
		 * Event listener invoked when the "download and install Ethereum client" Alert dialog is closed. If the "install" option is selected the
		 * latest client, as specified in the global settings data, is downloaded and installed.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onInstallEthereumAlertClose(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.CLOSE, this.onInstallEthereumAlertClose);
			if (eventObj.data.download) {
				this.toggle.isEnabled = false;
				this.lounge.ethereum.client.addEventListener(EthereumWeb3ClientEvent.CLIENT_INSTALL, this.onClientInstallProgress);
				this.lounge.ethereum.client.loadNativeClient();
			} 
		}
		
		/**
		 * Event listener invoked periodically while the Ethereum client is being downloaded and installed. This event is dispatched from the main Ethereum
		 * object's EthereumWeb3Client instance which performs the download and installation operations. When the installation has fully completed
		 * a synchronization progress monitor event listener is created.
		 * 
		 * @param	eventObj An EthereumWeb3ClientEvent object.
		 */
		private function onClientInstallProgress(eventObj:EthereumWeb3ClientEvent):void {
			if (eventObj.downloadPercent < 0) {
				this.lounge.ethereum.client.removeEventListener(EthereumWeb3ClientEvent.CLIENT_INSTALL, this.onClientInstallProgress);
				var alert:Alert = StarlingViewManager.alert("There was a problem downloading the Ethereum client software. Please check your network connection and try again.", "Can't Download Ethereum Client", new ListCollection([{label:"OK"}]), null, true, true);
				this.disableEthereumIntegration();
				this.toggle.label = this.enablemessage;
				this.statusText.text = "";
				this.toggle.isEnabled = true;
				return;
			}
			if (eventObj.downloadPercent < 100) {
				this.statusText.text = "Downloading: " + eventObj.downloadPercent + "% complete";
			}
			if ((eventObj.downloadPercent == 100) && (eventObj.installPercent < 100)) {
				this.statusText.text = "Installing: " + eventObj.downloadPercent + "% complete";
			}
			if ((eventObj.downloadPercent == 100) && (eventObj.installPercent == 100)) {
				this.lounge.ethereum.client.removeEventListener(EthereumWeb3ClientEvent.CLIENT_INSTALL, this.onClientInstallProgress);
				this.toggle.label = this.enabledmessage;
				this.statusText.text = "Starting sync with network...";
				this.toggle.isEnabled = true;
				this.lounge.ethereum.addEventListener(EthereumEvent.CLIENTSYNCEVENT, this.onClientSyncProgress);
				this.lounge.ethereum.startMonitorSyncStatus();
			}
		}
		
		/**
		 * Event listener invoked periodically while the main Ethereum client is synchronizing the blockchain of the selected network. The user interface
		 * is updated with the sync status information.
		 * 
		 * @param	eventObj An EthereumEvent object.
		 */
		private function onClientSyncProgress(eventObj:EthereumEvent):void {
			if (eventObj.syncInfo.status == -3) {
				this.toggle.label = this.enablingmessage;
				this.statusText.text ="Connecting...";
			} else if (eventObj.syncInfo.status == -2) {
				this.toggle.label = this.enabledmessage;
				this.statusText.text ="Waiting for peer connection(s)...";
			} else if (eventObj.syncInfo.status == -1) {
				this.toggle.label = this.enabledmessage;
				this.statusText.text ="Waiting for block data...";
			} else {
				if (eventObj.syncInfo.currentBlock == "undefined") {
					eventObj.syncInfo.currentBlock = "?";
				}
				if (eventObj.syncInfo.highestBlock == "undefined") {
					eventObj.syncInfo.highestBlock = "?";
				}
				this.toggle.label = this.enabledmessage;
				this.statusText.text = eventObj.syncInfo.currentBlock + " of " + eventObj.syncInfo.highestBlock + " blocks received.\n";
				var percentRounded:Number = Math.round(eventObj.syncInfo.percentComplete * 1000) / 1000;
				this.statusText.text += percentRounded+" % complete";
			}
		}
		
		/**
		 * Disables the main Ethereum client integration. Any active event listeners are removed and the lounge's Ethereum instance is removed from 
		 * application memory. The Ethereum instance must be re-created prior to attempting any future calls on the object otherwise a runtime error
		 * will be thrown.
		 */
		private function disableEthereumIntegration():void {
			if (this.lounge.ethereum != null) {
				this.lounge.ethereum.removeEventListener(EthereumEvent.CLIENTSYNCEVENT, this.onClientSyncProgress);
				this.lounge.ethereum.destroy();
				this.lounge.ethereum = null;
			}
			this.statusText.text = "";
			this.showSettingsButton.isEnabled = true;
			this.networkList.isEnabled = true;
			this.selectDataDirButton.isEnabled = true;
			this.showSettingsButton.isEnabled = true;
			this.clientAddressInput.isEditable = true;
			this.clientPortInput.isEditable = true;
			if ((lounge.isChildInstance) || (GlobalSettings.systemSettings.isStandalone == false) || (GlobalSettings.systemSettings.isAIR == false)) {
				this.launchClientProcessToggle.isEnabled = false;
			} else {
				this.launchClientProcessToggle.isEnabled = true;
			}
		}

		
		/**
		 * Event listener invoked when the main Ethereum instance has been enabled. This event is dispatched from the main lounge instance
		 * because it's responsible for managing Ethereum instances. Additional bootstrapping functionality may be called depending on the
		 * network selected.
		 * 
		 * @param	eventObj A LoungeEvent object.
		 */
		private function onEthereumEnabled(eventObj:LoungeEvent):void {
			try {
				var sync:* = lounge.ethereum.web3.eth.syncing;
			} catch (err:*) {
				StarlingViewManager.alert ("Failed to connect to Ethereum client. Check the RPC-API address and port settings.", "Failed Client RPC-API Connection", new ListCollection([{label:"OK"}]), null, true, true);
				this.disableEthereumIntegration();
				this.toggle.isEnabled = true;
				this.toggle.isSelected = false;
				this.toggle.label = this.enablemessage;
				this.showSettings();
				return;
			}
			this.toggle.label = this.enabledmessage;
			this.toggle.isEnabled = true;
			this.launchClientProcessToggle.isEnabled = false;
			this.toggle.removeEventListener(Event.CHANGE, this.onToggleClick);
			if (!this.toggle.isSelected) {
				this.toggle.isSelected = true;
			}
			this.toggle.addEventListener(Event.CHANGE, this.onToggleClick);
			if (lounge.isChildInstance) {
				//this.networkList.isEnabled = false;
				this.selectDataDirButton.isEnabled = false;
			}
			if (this.lounge.ethereum.client.nativeClientNetwork == EthereumWeb3Client.CLIENTNET_ROPSTEN) {
				//bootstrap Ropsten client connectivity using known good nodes
				this.lounge.ethereum.web3.admin.addPeer("enode://20c9ad97c081d63397d7b685a412227a40e23c8bdc6688c6f37e97cfbc22d2b4d1db1510d8f61e6a8866ad7f0e17c02b14182d37ea7c3c8b9c2683aeb6b733a1@52.169.14.227:30303");
				this.lounge.ethereum.web3.admin.addPeer("enode://21d1375c40936084f4e6715d474e0197ecb5b9aba1c7678bd5d416501561901b131c44dab8e1f3abdf10972449657b86f97ba56bbc62c6fec4b497a72a5713df@54.82.119.92:30303");
				this.lounge.ethereum.web3.admin.addPeer("enode://5e67f18abd0e0807b8d51b07bf105b6bf59891af5b377069fe45907eee6ba11fbcce8747f07d8d6ad529f9a9e7ec92e5b0b70763d0974a6e618c55eb7626f8d7@138.68.85.172:30303");
				this.lounge.ethereum.web3.admin.addPeer("enode://7338744a381746f633e0f1f7f9483e65090556f9117d891eef89a0e01eb6624a9d1f5aeca4f9415b7fae759127bf2348ce28c3dd5e0ac347b667322da02dd73e@149.56.240.75:20202");
				this.lounge.ethereum.web3.admin.addPeer("enode://7715db2c79c78776e35e4f4cda935c4d2c0ceed6c3335ccb02c2287a8d83a94957650b26c2755feecd9685cacbda34dee058098a2f38b7571270a52442c61b38@52.160.105.175:30303");
				this.lounge.ethereum.web3.admin.addPeer("enode://9d87377a0732c41a27a3724b6d6ea804d5fc3e734e3bf2ac30e66f18b74dfabc3f37eda480499eafd19a2d7dcb62430b11e56c2c73b9a97de55c8ed13f2cb532@51.255.33.36:30303");
				this.lounge.ethereum.web3.admin.addPeer("enode://b5d9bdbd364ff4247a85a3f1ec7be4ce0967d0b7f6940da18ce0665aa20c6bbf1ed2cda10eb2c3e1438ac20478402808d58144a16d18eae8d21cce37fa55660c@217.120.243.243:30303");
				this.lounge.ethereum.web3.admin.addPeer("enode://b7cbba7f60dfd46670da08336377b93625798f7cfe2b99c34d749b4529164c62dcb6485b0a2cfa2fc78f4a13a96478a08734b31a2b9cc7f8967e28c54321f836@217.182.120.2:30302");
				this.lounge.ethereum.web3.admin.addPeer("enode://cd70cf73989c93057d8f16231b35d76bb6579d80e75b04081a4d26c2469884457fcb57d76f4cd23df1e0608de56b5a351f3951f853520119553b38cce0fd3630@192.167.144.165:30303");
				this.lounge.ethereum.web3.admin.addPeer("enode://6ce05930c72abc632c58e2e4324f7c7ea478cec0ed4fa2528982cf34483094e9cbc9216e7aa349691242576d552a2a56aaeae426c5303ded677ce455ba1acd9d@13.84.180.240:30303");
			}
			/*
			//Tunnel functionality not ready
			var cliqueOptions:Object = new Object();
			cliqueOptions.groupName = "EthereumClientTunnel";
			if (lounge.isChildInstance) {
				this._clientTunnel = new EthereumClientTunnel("127.0.0.1", 30307);
			} else {
				this._clientTunnel = new EthereumClientTunnel("127.0.0.1", 30306);
			}
			var tunnelClique:INetClique = lounge.clique.newRoom(cliqueOptions);
			this._clientTunnel.bind(tunnelClique);
			*/
		}
		
		/**
		 * Updates the Ethereum client data directory button with the default or selected directory path, or "[shared]" if the lounge is a
		 * secondary or shared instance.
		 */
		private function updateDataDirButton():void {
			if (lounge.isChildInstance) {
				this.selectDataDirButton.label = "[shared]";
				return;
			}
			try {
				this.selectDataDirButton.label = String(GlobalSettings.getSetting("defaults", "ethereum").datadirectory);
			} catch (err:*) {
				this.selectDataDirButton.label = "../data/";
			}
		}		
		
		/**
		 * Event listener invoked when the Ethereum data directory button is clicked which opens a directory selection dialog.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onSelectDataDirClick(eventObj:Event):void {
			this._dirFile = File.applicationStorageDirectory;
			this._dirFile.browseForDirectory("Select Ethereum client data directory");
			this._dirFile.addEventListener("select", this.onNewDataDir);
		}
		
		/**
		 * Event listener invoked when a new Ethereum data directory has been selected via the 'onSelectDataDirClick' method, updating the 
		 * user interface with the updated data directory path.
		 * 
		 * @param	eventObj A Flash Event object, untyped to prevent conflicts with the Starling Event type.
		 */
		private function onNewDataDir(eventObj:Object):void {
			this._dirFile.removeEventListener("select", this.onNewDataDir);			
			GlobalSettings.getSetting("defaults", "ethereum").replace("datadirectory", new XML("<datadirectory><![CDATA[" + this._dirFile.nativePath + "]]></datadirectory>"));
			GlobalSettings.saveSettings();
			this.updateDataDirButton();
		}
			
		/**
		 * Event listener invoked when the "launch client process" toggle switch is clicked.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onLaunchClientProcessToggle(eventObj:Event):void {
			if (this.launchClientProcessToggle.isSelected) {
				if ((GlobalSettings.systemSettings.isStandalone) && (GlobalSettings.systemSettings.isAIR) && (!lounge.isChildInstance)) {
					this.networkList.isEnabled = true;
					this.selectDataDirButton.isEnabled = true;
				}
			} else {
				this.networkList.isEnabled = false;
				this.selectDataDirButton.isEnabled = false;
			}
		}
	}
}
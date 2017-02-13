/**
* Widget to control main Lounge Ethereum configuration and availability.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
	
	import events.EthereumWeb3ClientEvent;
	import feathers.controls.Alert;
	import feathers.controls.Button;
	import feathers.controls.Check;
	import feathers.controls.Label;
	import feathers.controls.PickerList;
	import feathers.controls.ToggleSwitch;
	import feathers.data.ListCollection;
	import feathers.data.XMLListListCollectionDataDescriptor;
	import flash.filesystem.File;
	import org.cg.interfaces.IPanelWidget;
	import org.cg.Lounge;
	import org.cg.GlobalSettings;
	import org.cg.SlidingPanel;
	import org.cg.DebugView;
	import org.cg.StarlingViewManager;
	import feathers.controls.ToggleButton;
	import org.cg.events.EthereumEvent;
	import org.cg.events.LoungeEvent;
	import starling.events.Event;	
	
	public class EthereumStatusWidget extends PanelWidget implements IPanelWidget {
		
		public var toggle:ToggleButton;	
		public var enableautolaunch:Check;
		public var statusText:Label;
		public var networkList:PickerList;
		public var selectDataDirButton:Button;
		public var launchClientProcessToggle:ToggleSwitch;
		public var enablemessage:String = "Enable Ethereum Integration";
		public var enablingmessage:String = "Enabling Ethereum Integration..."; 
		public var enabledmessage:String = "Disable Ethereum Integration";
		
		public function EthereumStatusWidget(loungeRef:Lounge, panelRef:SlidingPanel, widgetData:XML) {
			DebugView.addText("EthereumEnableWidget widget created.");
			super (loungeRef, panelRef,	widgetData)			
		}
		
		private function onToggleClick(eventObj:Event):void {			
			if (this.toggle.isSelected) {
				this.toggle.label = this.enablingmessage;
				this.toggle.isEnabled = false;
				this.enableEthereumIntegration();
			} else {
				this.disableEthereumIntegration();
				this.toggle.label = this.enablemessage;
			}
		}
		
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
			DebugView.addText("EthereumEnableWidget.onAutoLaunchClick: Saving global settings.");
			GlobalSettings.saveSettings();
		}
		
		private function enableEthereumIntegration():void {
			this.disableEthereumIntegration();
			this.networkList.isEnabled = false;
			this.selectDataDirButton.isEnabled = false;
			this.launchClientProcessToggle.isEnabled = false;
			this.lounge.ethereumEnabled = true; //must set to true to enable launch functionality
			var launchInfo:Object = new Object();
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
					var alert:Alert = StarlingViewManager.alert("Ethereum client not found. Do you want to download and install a new version?", "Ethereum client can't be found", new ListCollection([{label:"Yes", download:true}, {label:"No", download:false}]), null, true, true);
					alert.addEventListener(Event.CLOSE, this.onInstallEthereumAlertClose);
				}
			}
		}
		
		private function onInstallEthereumAlertClose(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.CLOSE, this.onInstallEthereumAlertClose);
			if (eventObj.data.download) {
				this.toggle.isEnabled = false;
				this.lounge.ethereum.client.addEventListener(EthereumWeb3ClientEvent.CLIENT_INSTALL, this.onClientInstallProgress);
				this.lounge.ethereum.client.loadNativeClient();
			} 
		}
		
		private function onClientInstallProgress(eventObj:EthereumWeb3ClientEvent):void {
			if (eventObj.downloadPercent < 0) {
				this.lounge.ethereum.client.removeEventListener(EthereumWeb3ClientEvent.CLIENT_INSTALL, this.onClientInstallProgress);
				var alert:Alert = StarlingViewManager.alert("There was a problem downloading the Ethereum client software. Please check your network connection and try again.", "Can't download Ethereum client", new ListCollection([{label:"OK"}]), null, true, true);
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
		
		private function onClientSyncProgress(eventObj:EthereumEvent):void {
			if (eventObj.syncInfo.status == -3) {
				this.toggle.label = this.enablingmessage;
				this.statusText.text ="Sync waiting for client to connect...";
			} else if (eventObj.syncInfo.status == -2) {
				this.toggle.label = this.enabledmessage;
				this.statusText.text ="Sync waiting for peer connections...";
			} else if (eventObj.syncInfo.status == -1) {
				this.toggle.label = this.enabledmessage;
				this.statusText.text ="Sync waiting for block data...";
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
		
		private function disableEthereumIntegration():void {
			DebugView.addText("EthereumEnableWidget.disableEthereumIntegration");		
			if (this.lounge.ethereum != null) {
				this.lounge.ethereum.removeEventListener(EthereumEvent.CLIENTSYNCEVENT, this.onClientSyncProgress);
				this.lounge.ethereum.destroy();
				this.lounge.ethereum = null;
			}
			this.statusText.text = "";
			this.networkList.isEnabled = true;
			this.selectDataDirButton.isEnabled = true;
			if ((lounge.isChildInstance) || (GlobalSettings.systemSettings.isStandalone == false) || (GlobalSettings.systemSettings.isAIR == false)) {
				this.launchClientProcessToggle.isEnabled = false;
			} else {
				this.launchClientProcessToggle.isEnabled = true;
			}
		}
				
		
		private function onEthereumEnabled(eventObj:LoungeEvent):void {
			DebugView.addText("EthereumEnableWidget.onEthereumEnabled");
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
		}
		
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
		
		private var _dirFile:File;
		
		private function onSelectDataDirClick(eventObj:Event):void {
			this._dirFile = File.applicationStorageDirectory;
			this._dirFile.browseForDirectory("Select Ethereum client data directory");
			this._dirFile.addEventListener("select", this.onNewDataDir);
		}
		
		private function onNewDataDir(eventObj:Object):void {
			this._dirFile.removeEventListener("select", this.onNewDataDir);
			//this.selectDataDirButton.label = this._dirFile.nativePath;
			GlobalSettings.getSetting("defaults", "ethereum").replace("datadirectory", new XML("<datadirectory><![CDATA[" + this._dirFile.nativePath + "]]></datadirectory>"));
			GlobalSettings.saveSettings();
			this.updateDataDirButton();
		}
			
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
		
		override public function initialize():void {
			DebugView.addText("EthereumEnableWidget initialize");			
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
			networkListData.addItem({text:"Ropsten Testnet", id:3, network:EthereumWeb3Client.CLIENTNET_ROPSTEN});
			networkListData.addItem({text:"Private Devnet", id:4, network:EthereumWeb3Client.CLIENTNET_DEV});
			this.networkList.dataProvider = networkListData;
			this.networkList.selectedIndex = 0;
			/*
			DebugView.addText ("   lounge.parentLounge=" + lounge.parentLounge);
			if (lounge.parentLounge != null) {
				if (lounge.parentLounge.ethereum != null) {
					DebugView.addText ("   lounge.parentLounge.ethereum=" + lounge.parentLounge.ethereum);
					DebugView.addText ("lounge.parentLounge.ethereum.client.networkID=" + lounge.parentLounge.ethereum.client.networkID);
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
				//this.networkList.isEnabled = false;
				this.selectDataDirButton.isEnabled = false;
				this.launchClientProcessToggle.isEnabled = false;
			}
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
			lounge.addEventListener(LoungeEvent.NEW_ETHEREUM, this.onEthereumEnabled);	
			super.initialize();
		}
	}
}
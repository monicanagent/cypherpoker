/**
* Widget used to select and connect to the various, available clique connection types.
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
	
	import feathers.controls.ImageLoader;
	import feathers.controls.Label;
	import feathers.controls.TextInput;
	import feathers.controls.ToggleSwitch;
	import feathers.data.ListCollection;
	import org.cg.interfaces.IPanelWidget;	
	import starling.events.Event;
	import org.cg.Lounge;
	import org.cg.events.LoungeEvent;
	import org.cg.SlidingPanel;
	import feathers.controls.PickerList;
	import org.cg.GlobalSettings;
	import org.cg.DebugView;
	import flash.utils.setTimeout;
	
	public class ConnectivitySelectorWidget extends PanelWidget implements IPanelWidget {
		
		//UI components rendered by StarlingViewManager:
		public var connectivityTypePicker:PickerList;
		public var connectToggle:ToggleSwitch;
		public var disconnectedIcon:ImageLoader;
		public var connectingIcon:ImageLoader;
		public var connectedIcon:ImageLoader;
		public var connectionProblemIcon:ImageLoader;
		public var connectedPeerID:TextInput;		
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	loungeRef A reference to the main ILounge implementation instance.
		 * @param	panelRef The widget's parent panel or display object container.
		 * @param	widgetData The widget's configuration XML data, usually from the global settings data.
		 */
		public function ConnectivitySelectorWidget(loungeRef:Lounge, panelRef:SlidingPanel, widgetData:XML) {
			super(loungeRef, panelRef, widgetData);			
		}
		
		/**
		 * Initializes the widget after it's been added to the display list and all child components have been created.
		 */
		override public function initialize():void {
			DebugView.addText("ConnectivitySelectorWidget.initialize");
			lounge.addEventListener(LoungeEvent.NEW_CLIQUE, this.onCliqueConnect);
			lounge.addEventListener(LoungeEvent.CLOSE_CLIQUE, this.onCliqueDisconnect);
			lounge.addEventListener(LoungeEvent.DISCONNECT_CLIQUE, this.onCliqueConnectProblem);
			this.connectivityTypePicker.dataProvider = new ListCollection();
			var netCliquesNode:XML = GlobalSettings.getSettingsCategory("netcliques");			
			var cliqueNodes:XMLList = netCliquesNode.children();
			for (var count:int = 0; count < cliqueNodes.length(); count++) {
				var currentNode:XML = cliqueNodes[count] as XML;				
				try {
					var dataItem:Object = new Object();
					dataItem.text = currentNode.child("name")[0].toString();
					dataItem.labelText = dataItem.text;
					dataItem.definition = currentNode;
					this.connectivityTypePicker.dataProvider.addItem(dataItem);
					this.connectivityTypePicker.dataProvider.getItemIndex(dataItem);					
				} catch (err:*) {					
				}
			}
			if (netCliquesNode.child("selected").length() > 0) {				
				var selectedConnection:String = netCliquesNode.child("selected")[0].toString();
				for (count = 0; count < this.connectivityTypePicker.dataProvider.length; count++) {
					if (this.connectivityTypePicker.dataProvider.getItemAt(count).text == selectedConnection) {
						this.connectivityTypePicker.selectedIndex = count;
						break;
					}
				}
			} else {
				this.connectivityTypePicker.selectedIndex = 0;
			}
			this.connectivityTypePicker.addEventListener(Event.CHANGE, this.onConnectivityPickerSelect);
			this.connectivityTypePicker.invalidate();
			this.connectivityTypePicker.isEnabled = true;
			this.connectToggle.addEventListener(Event.CHANGE, this.onConnectTogglelick);
			this.disconnectedIcon.visible = true;
			this.connectingIcon.visible = false;
			this.connectedIcon.visible = false;
			this.connectionProblemIcon.visible = false;
			//this is not a good way to do this...can we update the icon position in the view manager maybe (when loaded)?
			setTimeout(this.clearPeerIDIcon, 1000);			
		}
				
		/**
		 * Clears / resets the peer ID icon in the 'connectedPeerID' field in order to fix misalignment issues.
		 */
		public function clearPeerIDIcon():void {
			this.connectedPeerID.showFocus();			
			this.connectedPeerID.text = "--";
			this.connectedPeerID.text = "";	
			this.connectedPeerID.hideFocus();
			this.connectedPeerID.invalidate();
			super.initialize();
		}
		
		/**
		 * Event listener invoked when the connect toggle switch is clicked, causing the currently selected clique to attempt to connect via
		 * the current lounge instance or, if currently connected, disconnects the clique and resets the interface.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onConnectTogglelick(eventObj:Event):void {
			var selectedNode:XML = this.connectivityTypePicker.selectedItem.definition;
			var selectedID:String = selectedNode.@id;
			this.connectionProblemIcon.visible = false;
			if (this.connectToggle.isSelected) {
				this.connectivityTypePicker.isEnabled = false;
				this.connectedPeerID.text = "";
				this.disconnectedIcon.visible = false;
				this.connectingIcon.visible = true;
				this.connectedIcon.visible = false;
				var options:Object = new Object();
				lounge.createCliqueConnection(selectedID, options);
			} else {							
				lounge.removeClique();
			}
		}
		
		/**
		 * Event listener invoked when the connectivity type picker selection changes. The current selection is saved to the global
		 * settings data so that it can be recalled next time the application is started.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onConnectivityPickerSelect(eventObj:Event):void {			
			var netCliquesNode:XML = GlobalSettings.getSettingsCategory("netcliques");
			if (netCliquesNode.selected.length() == 0) {				
				//would it be better to do this as an index?
				netCliquesNode.appendChild(new XML("<selected>"+this.connectivityTypePicker.selectedItem.text+"</selected>"));
			} else {				
				netCliquesNode.child("selected")[0].replace("*", this.connectivityTypePicker.selectedItem.text);
			}			
			GlobalSettings.saveSettings();
		}
		
		/**
		 * Event listener invoked when the currently selected clique successfully connects causing the interface to be updated
		 * to reflect the new status. This event is dispatched from the main lounge instance since it's responsible for managing
		 * clique connectivity.
		 * 
		 * @param	eventObj A LoungeEvent object.
		 */
		private function onCliqueConnect(eventObj:LoungeEvent):void {
			this.connectedIcon.visible = true;
			this.connectingIcon.visible = false;
			this.disconnectedIcon.visible = false;
			this.connectionProblemIcon.visible = false;
			this.connectToggle.removeEventListener(Event.CHANGE, this.onConnectTogglelick);
			this.connectToggle.isSelected = true;
			this.connectToggle.addEventListener(Event.CHANGE, this.onConnectTogglelick);
			this.connectedPeerID.text = lounge.clique.localPeerInfo.peerID;			
		}
		
		/**
		 * Event listener invoked when the currently active main clique connection disconnects causing the interface to be updated
		 * to reflect the new status. This event is dispatched from the main lounge instance since it's responsible for managing
		 * clique connectivity.
		 * 
		 * @param	eventObj A LoungeEvent object.
		 */
		private function onCliqueDisconnect(eventObj:LoungeEvent):void {
			this.connectedIcon.visible = false;
			this.connectingIcon.visible = false;
			this.disconnectedIcon.visible = true;
			this.connectionProblemIcon.visible = false;
			this.connectivityTypePicker.isEnabled = true;
			this.connectedPeerID.text = "";
			this.connectToggle.removeEventListener(Event.CHANGE, this.onConnectTogglelick);
			this.connectToggle.isSelected = false;
			this.connectToggle.addEventListener(Event.CHANGE, this.onConnectTogglelick);
		}
		
		/**
		 * Event listener invoked when the currently active main clique connection attempt has experienced a problem, causing the interface to 
		 * be updated to reflect the status. This event is dispatched from the main lounge instance since it's responsible for managing
		 * clique connectivity.
		 * 
		 * @param	eventObj A LoungeEvent object.
		 */
		private function onCliqueConnectProblem(eventObj:LoungeEvent):void {
			this.connectedIcon.visible = false;
			this.connectingIcon.visible = false;
			this.disconnectedIcon.visible = false;
			this.connectionProblemIcon.visible = true;
			this.connectivityTypePicker.isEnabled = false;
			this.connectToggle.removeEventListener(Event.CHANGE, this.onConnectTogglelick);
			this.connectToggle.isSelected = false;
			this.connectToggle.addEventListener(Event.CHANGE, this.onConnectTogglelick);
		}
	}
}
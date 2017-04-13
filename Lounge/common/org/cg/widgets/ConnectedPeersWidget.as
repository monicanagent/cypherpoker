/**
* Displays the number of peers connected to the main lounge clique.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
	
	import feathers.controls.Label;
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.IPanelWidget;
	import org.cg.SlidingPanel;
	import org.cg.events.LoungeEvent;
	import p2p3.events.NetCliqueEvent;	
	import p2p3.interfaces.INetClique;
	
	public class ConnectedPeersWidget extends PanelWidget implements IPanelWidget {
		
		private var _numPeers:Number = 0; //number of currently connected peers
		private var _currentCliqueConnection:INetClique; //main lounge clique reference		
		//UI components rendered by StarlingViewManager:
		public var connectedPeerCount:Label;		
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	loungeRef A reference to the main ILounge implementation instance.
		 * @param	panelRef The widget's parent panel or display object container.
		 * @param	widgetData The widget's configuration XML data, usually from the global settings data.
		 */
		public function ConnectedPeersWidget(loungeRef:ILounge, panelRef:SlidingPanel, widgetData:XML) {
			super(loungeRef, panelRef, widgetData);
		}
		
		/**
		 * Initializes the widget after it's been added to the display list and all child components have been created.
		 */
		override public function initialize():void {
			lounge.addEventListener(LoungeEvent.NEW_CLIQUE, this.onCliqueConnect);
			if (lounge.clique != null) {
				this._currentCliqueConnection = lounge.clique;
				this._currentCliqueConnection.addEventListener(NetCliqueEvent.CLIQUE_DISCONNECT, this.onCliqueDisconnect);
				this._currentCliqueConnection.addEventListener(NetCliqueEvent.PEER_CONNECT, this.onPeerConnect);
				this._currentCliqueConnection.addEventListener(NetCliqueEvent.PEER_DISCONNECT, this.onPeerDisconnect);
			}
		}
		
		/**
		 * Event listener invoked when the main lounge clique connection is established. This event is dispatched by the main
		 * lounge instance since it's responsible for managing its own clique connections.
		 * 
		 * @param	eventObj A LoungeEvent object.
		 */
		private function onCliqueConnect(eventObj:LoungeEvent):void {
			if (this._currentCliqueConnection != null) {
				this._currentCliqueConnection.removeEventListener(NetCliqueEvent.CLIQUE_DISCONNECT, this.onCliqueDisconnect);
				this._currentCliqueConnection.removeEventListener(NetCliqueEvent.PEER_CONNECT, this.onPeerConnect);
				this._currentCliqueConnection.removeEventListener(NetCliqueEvent.PEER_DISCONNECT, this.onPeerDisconnect);
			}
			this._currentCliqueConnection = lounge.clique;
			this._currentCliqueConnection.addEventListener(NetCliqueEvent.CLIQUE_DISCONNECT, this.onCliqueDisconnect);
			this._currentCliqueConnection.addEventListener(NetCliqueEvent.PEER_CONNECT, this.onPeerConnect);
			this._currentCliqueConnection.addEventListener(NetCliqueEvent.PEER_DISCONNECT, this.onPeerDisconnect);
			this._numPeers = 1; //just the self
			this.updatePeerCount();			
		}
		
		/**
		 * Event listener invoked when the main lounge clique connection disconnects. This event is dispatched directly
		 * from the clique instance itself.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onCliqueDisconnect(eventObj:NetCliqueEvent):void {
			this._numPeers = 0;
			this.updatePeerCount();
		}
		
		/**
		 * Event listener invoked when a new peer connects to the main lounge clique.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onPeerConnect(eventObj:NetCliqueEvent):void {
			this._numPeers++;
			this.updatePeerCount();
		}
		
		/**
		 * Event listener invoked when a peer disconnects from the main lounge clique.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onPeerDisconnect(eventObj:NetCliqueEvent):void {
			this._numPeers--;
			this.updatePeerCount();
		}
		
		/**
		 * Updates the interface with the currently connected peer count.
		 */
		private function updatePeerCount():void {
			this.connectedPeerCount.text = String(this._numPeers);
		}
	}
}
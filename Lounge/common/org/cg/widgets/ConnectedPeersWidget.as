/**
* Used to track and inspect connected peers.
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
		
		public var connectedPeerCount:Label;
		private var _numPeers:Number = 0;
		private var _currentCliqueConnection:INetClique;
		
		public function ConnectedPeersWidget(loungeRef:ILounge, panelRef:SlidingPanel, widgetData:XML) {
			super(loungeRef, panelRef, widgetData);
			
		}	
		
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
		
		private function onCliqueDisconnect(eventObj:NetCliqueEvent):void {
			this._numPeers = 0;
			this.updatePeerCount();
		}
		
		private function onPeerConnect(eventObj:NetCliqueEvent):void {
			this._numPeers++;
			this.updatePeerCount();
		}
		
		private function onPeerDisconnect(eventObj:NetCliqueEvent):void {
			this._numPeers--;
			this.updatePeerCount();
		}
		
		private function updatePeerCount():void {
			this.connectedPeerCount.text = String(this._numPeers);
		}
		
		override public function initialize():void {
			lounge.addEventListener(LoungeEvent.NEW_CLIQUE, this.onCliqueConnect);
			if (lounge.clique != null) {
				this._currentCliqueConnection = lounge.clique;
				this._currentCliqueConnection.addEventListener(NetCliqueEvent.CLIQUE_DISCONNECT, this.onCliqueDisconnect);
				this._currentCliqueConnection.addEventListener(NetCliqueEvent.PEER_CONNECT, this.onPeerConnect);
				this._currentCliqueConnection.addEventListener(NetCliqueEvent.PEER_DISCONNECT, this.onPeerDisconnect);
			}
		}
	}
}
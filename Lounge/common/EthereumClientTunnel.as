/**
* Provides TCP and UDP tunneling services for native Ethereum clients in order to bypass limitations
* imposed by firewalls, routers, and other intermediaries.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package {
	
	import flash.utils.getDefinitionByName;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.ProgressEvent;
	import p2p3.interfaces.INetClique;
	import p2p3.events.NetCliqueEvent;
	import p2p3.PeerMessage;
	import org.cg.DebugView;
	
	public class EthereumClientTunnel {
		
		private var _clientAddress:String = null;
		private var _clientPort:int = -1; //both TCP and UDP sockets are currently assumed to be on the same port
		private var _clique:INetClique = null;		
		private var _clientComm:Socket = null; //Sending & Receiving TCP Socket instance
		private var _clientDisc:* = null; //Discovery UDP DatagramSocket instance
		private var _clientCommBuffer:String = new String(); //data buffer for sending to the _clientComm socket
		
		public function EthereumClientTunnel(clientAddress:String = "127.0.0.1", clientPort:int = 30303) {
			this._clientAddress = clientAddress;
			this._clientPort = clientPort;
		}
		
		public function bind(tunnelClique:INetClique, clientAddress:String = null, clientPort:int = -1):Boolean {
			if (tunnelClique == null) {
				return (false);
			}
			if (clientAddress != null) {
				this._clientAddress = clientAddress;
			}
			if (clientPort > -1) {
				this._clientPort = clientPort;
			}
			this._clique = tunnelClique;
			this._clientComm = new Socket(this._clientAddress, this._clientPort);
			this._clientDisc = new DatagramSocket();
			this.addListeners();
			this._clientDisc.receive();
			this._clientComm.connect(this._clientAddress, this._clientPort);
			return (true);
		}
		
		/**
		 * Receive from client discovery connection (UDP) and send through clique to remote peer(s).
		 * 
		 * @param	eventObj
		 */
		private function onDiscoveryDataReceived(eventObj:Object):void {			
			var recvData:String = eventObj.data.readUTFBytes(eventObj.data.bytesAvailable);
			DebugView.addText("onDiscoveryDataReceived: " + recvData);
			var dataObj:Object = new Object();
			dataObj.type = "discovery";
			dataObj.data = recvData;
			var msg:PeerMessage = new PeerMessage();			
			msg.data = dataObj;
			this._clique.broadcast(msg);
		}
		
		private function onCommDataReceived(eventObj:ProgressEvent):void {
			DebugView.addText("onCommDataReceived: " + eventObj);
			var recvData:String = this._clientComm.readUTFBytes(this._clientComm.bytesAvailable);
			var dataObj:Object = new Object();
			dataObj.type = "comm";
			dataObj.data = recvData;
			var msg:PeerMessage = new PeerMessage();			
			msg.data = dataObj;
			this._clique.broadcast(msg);
		}
		
		/**
		 * Send data to client discovery connection (UDP).
		 * 
		 * @param	data
		 */
		private function sendDiscoveryData(data:String):void {
			var sendData:ByteArray = new ByteArray();
            sendData.writeUTFBytes(data);
			try  {
                this._clientDisc.send(sendData, 0, 0, this._clientAddress, this._clientPort);                 
            } catch (error:Error) {
                DebugView.addText(error);
            }
		}
		
		/**
		 * Send data to client communication connection (TCP).
		 * 
		 * @param	data
		 */
		private function sendCommData(data:String):void {
			this._clientCommBuffer += data;
			if (this._clientCommBuffer.length == 0) {
				return;
			}
			if (this._clientComm.connected == false) {
				this._clientComm.connect(this._clientAddress, this._clientPort);
			} else {
				this._clientComm.writeUTFBytes(this._clientCommBuffer);
				this._clientComm.flush();
				this._clientCommBuffer = "";
			}
		}
		
		private function onCliqueMsg(eventObj:NetCliqueEvent):void {
			DebugView.addText("onCliqueMsg");
		}
		
		private function commCloseHandler(event:Event):void {
			DebugView.addText("commCloseHandler: " + event);			
		}

		private function commConnectHandler(event:Event):void {
			DebugView.addText("commConnectHandler: " + event);
			this.sendCommData(String.fromCharCode(2));
			//this.sendCommData(this._clientCommBuffer);
		}

		private function commIOErrorHandler(event:IOErrorEvent):void {
			DebugView.addText("commIOErrorHandler: " + event);
		}

		private function commSecurityErrorHandler(event:SecurityErrorEvent):void {
			DebugView.addText("commSecurityErrorHandler: " + event);
		}	
		
		private function addListeners():void {
			this._clientDisc.addEventListener(DatagramSocketDataEvent.DATA, this.onDiscoveryDataReceived);
			this._clientComm.addEventListener(Event.CLOSE, this.commCloseHandler);
			this._clientComm.addEventListener(Event.CONNECT, this.commConnectHandler);
			this._clientComm.addEventListener(IOErrorEvent.IO_ERROR, this.commIOErrorHandler);
			this._clientComm.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.commSecurityErrorHandler);
			this._clientComm.addEventListener(ProgressEvent.SOCKET_DATA, this.onCommDataReceived);
			this._clique.addEventListener(NetCliqueEvent.PEER_MSG, this.onCliqueMsg);
		}
				
		private static function get DatagramSocket():Class {			
			return (getDefinitionByName("flash.net.DatagramSocket") as Class);
		}
		
		private static function get DatagramSocketDataEvent():Class {			
			return (getDefinitionByName("flash.events.DatagramSocketDataEvent") as Class);
		}		
	}
}
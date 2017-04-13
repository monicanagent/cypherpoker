/**
* Provides TCP and UDP tunneling services for native Ethereum clients in order to bypass limitations
* imposed by firewalls, routers, and other intermediaries.
* 
* DOES NOT CURRENTLY WORK AS EXPECTED!
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
		
		private var _clientAddress:String = null; //native client listening address
		private var _clientPort:int = -1; //both TCP and UDP sockets are currently assumed to be on the same port
		private var _clique:INetClique = null;//clique to use to tunnel data	
		private var _clientComm:Socket = null; //Sending & Receiving TCP Socket instance
		private var _clientDisc:* = null; //Discovery UDP DatagramSocket instance
		private var _clientCommBuffer:String = new String(); //data buffer for sending to the _clientComm socket
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	clientAddress The address of the native client.
		 * @param	clientPort The listening port of the native client.
		 */
		public function EthereumClientTunnel(clientAddress:String = "127.0.0.1", clientPort:int = 30303) {
			this._clientAddress = clientAddress;
			this._clientPort = clientPort;
		}
		
		/**
		 * Binds the tunnel clique to the native client connection.
		 * 
		 * @param	tunnelClique The segregated clique to be used to transport tunneled data.
		 * @param	clientAddress The address of the native client.
		 * @param	clientPort The communication port of the native client.
		 * 
		 * @return true if the tunne could be successfully bound, false otherwise.
		 */
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
		 * Event listener to receive data from the client discovery connection (UDP) and send through clique to remote peer(s).
		 * 
		 * @param	eventObj A DatagramSocketDataEvent object.
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
		
		/**
		 * Event listener to receive data from the client data connection (TCP) and send through clique to remote peer(s).
		 * 
		 * @param	eventObj A ProgressEvent object
		 */
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
		 * @param	data The data to sent.
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
		 * @param	data The data to send.
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
		
		/**
		 * Event listener invoked when data has been received from the segregated clique connection.
		 * 
		 * @param	eventObj A NetCliqueEvent object.
		 */
		private function onCliqueMsg(eventObj:NetCliqueEvent):void {
			DebugView.addText("onCliqueMsg");
		}
		
		/**
		 * Event handler invoked when the client communication connection (TCP) has been closed.
		 * 
		 * @param	event A standard Event object.
		 */
		private function commCloseHandler(event:Event):void {
			DebugView.addText("commCloseHandler: " + event);			
		}

		/**
		 * Event handler invoked when data has been received from the client communication connection (TCP).
		 * 
		 * @param	event A standard Event object.
		 */
		private function commConnectHandler(event:Event):void {
			DebugView.addText("commConnectHandler: " + event);
			this.sendCommData(String.fromCharCode(2));
			//this.sendCommData(this._clientCommBuffer);
		}

		/**
		 * Event handler invoked when an IO error event is dispatched from the client communication connection (TCP).
		 * 		 
		 * @param	event An IOErrorEvent object.
		 */
		private function commIOErrorHandler(event:IOErrorEvent):void {
			DebugView.addText("commIOErrorHandler: " + event);
		}

		/**
		 * Event handler invoked when security error event is dispatched from the client communication connection (TCP).
		 * 		 
		 * @param	event A SecurityErrorEvent object.
		 */
		private function commSecurityErrorHandler(event:SecurityErrorEvent):void {
			DebugView.addText("commSecurityErrorHandler: " + event);
		}	
		
		/**
		 * Adds event listeners to client discovery, client communication, and clique connections.
		 */
		private function addListeners():void {
			this._clientDisc.addEventListener(DatagramSocketDataEvent.DATA, this.onDiscoveryDataReceived);
			this._clientComm.addEventListener(Event.CLOSE, this.commCloseHandler);
			this._clientComm.addEventListener(Event.CONNECT, this.commConnectHandler);
			this._clientComm.addEventListener(IOErrorEvent.IO_ERROR, this.commIOErrorHandler);
			this._clientComm.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.commSecurityErrorHandler);
			this._clientComm.addEventListener(ProgressEvent.SOCKET_DATA, this.onCommDataReceived);
			this._clique.addEventListener(NetCliqueEvent.PEER_MSG, this.onCliqueMsg);
		}
				
		/**
		 * @return A reference to the standard "flash.net.DatagramSocket" class or null if not supported in this runtime.
		 */
		private static function get DatagramSocket():Class {			
			return (getDefinitionByName("flash.net.DatagramSocket") as Class);
		}
		
		/**
		 * @return A reference to the standard "flash.events.DatagramSocketDataEvent" class or null if not supported in this runtime.
		 */
		private static function get DatagramSocketDataEvent():Class {			
			return (getDefinitionByName("flash.events.DatagramSocketDataEvent") as Class);
		}		
	}
}
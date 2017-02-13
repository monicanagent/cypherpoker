/**
* Peer message intended to be processed by TableManager instances.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
	
	import p2p3.interfaces.IPeerMessage;
	import p2p3.PeerMessage;
	
	
	public class TableManagerMessage extends PeerMessage implements IPeerMessage {
		
		//A remote player has created a new public table.
		public static const NEW_TABLE:String = "PeerMessage.TableManagerMessage.NEW_TABLE";
		
		private static const version:String = "2.0"; //included with each message for future compatibility
		private static const messageHeader:String = "TableManagerMessage"; //default message header/identifier		
		private var _tableManagerMessageType:String; //parsed message type
		
		public function TableManagerMessage(incomingMessage:*=null) {
			super(incomingMessage);
		}
		
		/** 
		 * Creates a table manager message (for sending) encapsulated within a standard peer message.
		 * 
		 * @param	messageType The type of table manager message to create, usually one of the defined class constants.		 
		 * @param	payload An optional payload to include with the message.
		 */
		public function createTableManagerMessage(messageType:String, payload:Object = null):void {
			var dataObj:Object = new Object();
			dataObj.type = messageHeader + "/" + version + "/" + messageType;
			_tableManagerMessageType = messageType;
			dataObj.payload = payload;
			super.data = dataObj;
		}		
		
		/**
		 * Validates a (usually incoming) peer message as a valid table manager message.
		 * 
		 * @param	peerMessage The peer message to validate.
		 * 
		 * @return A new instance containing all of the data of the source peer message, or null if the source peer message can't be 
		 * validated as a table manager message.
		 */
		public static function validateTableManagerMessage(peerMessage:IPeerMessage):TableManagerMessage {			
			if (peerMessage == null) {				
				return (null);
			}
			try {
				//must match structure in createTableManagerMessage...				
				var messageType:String = peerMessage.data.type;					
				var messageSplit:Array = messageType.split("/");				
				var headerStr:String = messageSplit[0] as String;				
				var versionStr:String = messageSplit[1] as String;				
				var messageTypeStr:String = messageSplit[2] as String;					
				if (headerStr != messageHeader) {					
					return (null);
				}
				if (versionStr != version) {					
					return (null);
				}
				var TMMessage:TableManagerMessage = new TableManagerMessage(peerMessage);
				TMMessage.tableManagerMessageType = messageTypeStr;				
				if ((peerMessage.data["payload"] != undefined) && (peerMessage.data["payload"] != null)) {
					TMMessage.data = peerMessage.data["payload"];
				}				
				TMMessage.timestampGenerated = peerMessage.timestampGenerated;
				TMMessage.timestampSent = peerMessage.timestampSent;
				TMMessage.timestampReceived = peerMessage.timestampReceived;				
				return (TMMessage);
			} catch (err:*) {				
				return (null);
			}
			return (null);			
		}
		
		/**
		 * The message type of this instance, usually one of the defined class constants.
		 */
		public function set tableManagerMessageType(typeSet:String):void {
			this._tableManagerMessageType = typeSet;
		}
		
		public function get tableManagerMessageType():String {
			return (this._tableManagerMessageType);
		}
		
	}

}
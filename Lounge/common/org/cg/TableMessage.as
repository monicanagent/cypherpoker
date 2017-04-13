/**
* An extended PeerMessage intended to be processed by Table instances.
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
	
	
	public class TableMessage extends PeerMessage implements IPeerMessage {
		
		//A remote player has connected to the table. Message payload may include additional information such as the player's handle, icon, etc.
		public static const HELLO:String = "PeerMessage.TableMessage.HELLO";
		
		private static const version:String = "2.0"; //included with each message for future compatibility
		private static const messageHeader:String = "TableMessage"; //default message header/identifier		
		private var _tableMessageType:String; //parsed message type
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	incomingMessage Populates the new instance with the properties of the incoming message object in order to validate them. If
		 * null the TableMessage instance is a new message.
		 */
		public function TableMessage(incomingMessage:*=null) {
			super(incomingMessage);
		}
		
		/**
		 * Validates a (usually incoming) peer message as a valid table message.
		 * 
		 * @param	peerMessage The peer message to validate.
		 * 
		 * @return A new instance containing all of the data of the source peer message, or null if the source peer message can't be 
		 * validated as a table message.
		 */
		public static function validateTableMessage(peerMessage:IPeerMessage):TableMessage {			
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
				var tableMessage:TableMessage = new TableMessage(peerMessage);
				tableMessage.tableMessageType = messageTypeStr;				
				if ((peerMessage.data["payload"] != undefined) && (peerMessage.data["payload"] != null)) {
					tableMessage.data = peerMessage.data["payload"];
				}				
				tableMessage.timestampGenerated = peerMessage.timestampGenerated;
				tableMessage.timestampSent = peerMessage.timestampSent;
				tableMessage.timestampReceived = peerMessage.timestampReceived;				
				return (tableMessage);
			} catch (err:*) {				
				return (null);
			}
			return (null);			
		}
		
		/**
		 * The message type of this instance, usually one of the defined class constants.
		 */
		public function set tableMessageType(typeSet:String):void {
			this._tableMessageType = typeSet;
		}
		
		public function get tableMessageType():String {
			return (this._tableMessageType);
		}
		
		/** 
		 * Creates a table message (for sending) encapsulated within a standard peer message.
		 * 
		 * @param	messageType The type of table message to create, usually one of the defined class constants.		 
		 * @param	payload An optional payload to include with the message.
		 */
		public function createTableMessage(messageType:String, payload:Object = null):void {
			var dataObj:Object = new Object();
			dataObj.type = messageHeader + "/" + version + "/" + messageType;
			_tableMessageType = messageType;
			dataObj.payload = payload;
			super.data = dataObj;
		}		
	}
}
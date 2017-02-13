/**
* Handles a single Rochambeau message and associated data; usually sent and received by the Rochambeau class.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3 {
	
	import flash.utils.ByteArray;
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.interfaces.IPeerMessage;
		
	public class RochambeauMessage extends PeerMessage {
		
		//Asynchronously starts the protocol. The currently connected number of peers is 
		//considered the required number of peers unless protocol has already been started.
		public static const START:String = "PeerMessage.RochambeauMessage.START";
		//Sends selections to the next player to encrypt.
		public static const ENCRYPT:String = "PeerMessage.RochambeauMessage.ENCRYPT";			
		//Sends remaining encrypted selections to next peer for selection.
		public static const SELECT:String = "PeerMessage.RochambeauMessage.SELECT";	
		//Includes the crypto keys used in the final (decryption) phase of the protocol
		public static const DECRYPT:String = "PeerMessage.RochambeauMessage.DECRYPT";		
		private static const version:String = "2.0"; //included with each message for future compatibility
		private static const messageHeader:String = "RochambeauMessage"; //default message header/identifier		
		private var _rochambeauMessageType:String; //parsed message type
		
		/**
		 * Creates a new RochambeauMessage instance.
		 * 
		 * @param	incomingMessage An incoming peer message to parse into this instance.
		 */
		public function RochambeauMessage(incomingMessage:*= null) {
			super(incomingMessage);			
		}
		
		/** 
		 * Creates a rochambeau message (for sending) encapsulated within a standard peer message.
		 * 
		 * @param	messageType The type of rochambeau message to create, usually one of the defined class constants.		 
		 * @param	payload An optional payload to include with the message.
		 */
		public function createRochMessage(messageType:String, payload:Object = null):void {
			var dataObj:Object = new Object();
			dataObj.type = messageHeader + "/" + version + "/" + messageType;
			_rochambeauMessageType = messageType;
			dataObj.payload = payload;
			super.data = dataObj;
		}		
		
		/**
		 * Validates a (usually incoming) peer message as a valid rochambeau message.
		 * 
		 * @param	peerMessage The peer message to validate.
		 * 
		 * @return A new instance containing all of the data of the source peer message, or null
		 * if the source peer message can't be validated as a rochambeau message.
		 */
		public static function validateRochMessage(peerMessage:IPeerMessage):RochambeauMessage {			
			if (peerMessage == null) {				
				return (null);
			}
			try {
				//must match structure in createRochMessage...				
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
				var rochMessage:RochambeauMessage = new RochambeauMessage(peerMessage);
				rochMessage.rochambeauMessageType = messageTypeStr;				
				if ((peerMessage.data["payload"] != undefined) && (peerMessage.data["payload"] != null)) {
					rochMessage.data = peerMessage.data["payload"];
				}				
				rochMessage.timestampGenerated = peerMessage.timestampGenerated;
				rochMessage.timestampSent = peerMessage.timestampSent;
				rochMessage.timestampReceived = peerMessage.timestampReceived;				
				return (rochMessage);
			} catch (err:*) {				
				return (null);
			}
			return (null);			
		}
		
		/**
		 * The message type of this instance, usually one of the defined class constants.
		 */
		public function set rochambeauMessageType(typeSet:String):void {
			this._rochambeauMessageType = typeSet;
		}
		
		public function get rochambeauMessageType():String {
			return (this._rochambeauMessageType);
		}
	}
}
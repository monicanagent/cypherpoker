/**
* Peer message exchanged by Lounge implementations.
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package  
{
	
	import p2p3.PeerMessage;
	import p2p3.interfaces.IPeerMessage;	
	
	public class InstantLoungeMessage extends PeerMessage 
	{
				
		private static const version:String = "1.0"; //for future compatibility
		private static const messageHeader:String = "InstantLoungeMessage";
		
		//Assume dealer role.
		public static const ASSUME_DEALER:String = "PeerMessage.InstantLoungeMessage.ASSUME_DEALER";
		//Game is about to start, prep local UI, etc.
		public static const GAME_START:String = "PeerMessage.InstantLoungeMessage.GAME_START";
		//Player is ready. When all players in game broadcast this message, game can begin. This allows game UI loading, etc. prior to game start.
		public static const PLAYER_READY:String = "PeerMessage.InstantLoungeMessage.PLAYER_READY";
		//Share player data like the max bit length, in-game portrait (maybe?), etc. This event should never appear after a GAME_START.
		public static const PLAYER_INFO:String = "PeerMessage.InstantLoungeMessage.PLAYER_INFO";
		
		private var _loungeMessageType:String;
		
		/**
		 * Creates an ILL message instance.
		 * 
		 * @param	incomingMessage An incoming message object to verify and parse into this instance.
		 * If not specified, the instance is created with default or empty values.
		 */
		public function InstantLoungeMessage(incomingMessage:*= null) 
		{
			super(incomingMessage);
		}
		
		/**
		 * Generates a new Lounge message in the current instance (should not be used if
		 * an incoming message was specified).
		 * 
		 * @param	messageType A message type to generate (see static type definitions for this class).
		 * @param	payload Additional optional payload data to include with the Lounge message.
		 */
		public function createLoungeMessage(messageType:String, payload:*= null):void 
		{
			var dataObj:Object = new Object();
			dataObj.type = messageHeader+"/" + version + "/" + messageType;			
			if (payload != null) {
				dataObj.payload = payload;
			}
			super.data = dataObj;
		}
		
		/**
		 * The Lounge message type, usually one of the static types defined for this class.
		 */
		public function set loungeMessageType(typeSet:String):void 
		{
			_loungeMessageType = typeSet;
		}
		
		public function get loungeMessageType():String {
			return (_loungeMessageType);
		}
		
		/**
		 * Creates a new Lounge message out of a valid Lounge message.
		 * 
		 * @param	peerMessage The IPeerMessage implementation to validate and parse.
		 * 
		 * @return A new Lounge message containing the validated and parsed properties of the input
		 * message. Null is returned if an error occurs during validation or parsing.
		 */
		public static function validateLoungeMessage(peerMessage:IPeerMessage):InstantLoungeMessage 
		{			
			if (peerMessage == null) {
				return (null);
			}
			try {
				//must match structure in createLoungeMessage()
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
				var ilMessage:InstantLoungeMessage = new InstantLoungeMessage(peerMessage);
				ilMessage.loungeMessageType = messageTypeStr;				
				if ((peerMessage.data["payload"] != undefined) && (peerMessage.data["payload"] != null)) {
					ilMessage.data = peerMessage.data["payload"];
				}				
				return (ilMessage);
			} catch (err:*) {					
				return (null);
			}
			return (null);			
		}		
	}
}
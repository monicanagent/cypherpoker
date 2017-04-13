/**
* Peer message sent and received by PokerBettingModule and related instances.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package {
	
	import p2p3.interfaces.IPeerMessage;
	import p2p3.PeerMessage;
	
	public class PokerBettingMessage extends PeerMessage {
		
		private static const version:String = "2.0"; //included with each message for future compatibility
		private static const messageHeader:String = "PokerBettingMessage";
		
		//Sets each player's balance; used only in play-for-fun scenarios where everyone can have the same starting balance
		public static const DEALER_SET_PLAYERBALANCES:String = "PeerMessage.PokerBettingMessage.DEALER_SET_PLAYERBALANCES";
		//Sets the initial betting order (should only ever be received once per game)
		public static const DEALER_SET_BETTINGORDER:String = "PeerMessage.PokerBettingMessage.DEALER_SET_BETTINGORDER";
		//Sets the current blinds values (broadcast by dealer)
		public static const DEALER_SET_BLINDS:String = "PeerMessage.PokerBettingMessage.DEALER_SET_BLINDS";
		//Starts the blinds timer (broadcast by dealer)
		public static const DEALER_START_BLINDSTIMER:String = "PeerMessage.PokerBettingMessage.DEALER_START_BLINDSTIMER";
		//Starts the betting round by passing control to the small blind.
		public static const DEALER_START_BET:String = "PeerMessage.PokerBettingMessage.PLAYER_NEXT_BET"
		//Updates the current player's bet when they have control
		public static const PLAYER_UPDATE_BET:String = "PeerMessage.PokerBettingMessage.PLAYER_UPDATE_BET";	
		//Commits the current player's bet and passes control to next player in betting order.
		public static const PLAYER_SET_BET:String = "PeerMessage.PokerBettingMessage.PLAYER_SET_BET";
		//Folds the player's hand and passes control to next player in betting order.
		public static const PLAYER_FOLD:String = "PeerMessage.PokerBettingMessage.PLAYER_FOLD";			
		//Final message in a game. Includes player's highest hand, decryption keys, etc.
		public static const PLAYER_RESULTS:String = "PeerMessage.PokerBettingMessage.PLAYER_RESULTS";	
				
		private var _bettingMessageType:String;	
		private var _value:Number=Number.POSITIVE_INFINITY;
		
		/**
		 * Creates a PokerBettingMessage.
		 * 
		 * @param	incomingMessage An optional incoming message to attempt to consume into this instance. If
		 * null or not supplied the "createBettingMessage" function should be called to populate the instance's data.
		 */
		public function PokerBettingMessage(incomingMessage:*= null) {
			super(incomingMessage);			
		}
		
		/**
		 * The value (as can be expressed in whatever chosen currency or units), associated with the betting message. May
		 * be null or 0 for control or fold messages.
		 */
		public function get value():Number {
			return (this._value);
		}
		
		public function set value(valSet:Number):void {
			this._value = valSet;
		}
		
		/**
		 * The message type of this instance, usually one of the defined class constants.
		 */
		public function set bettingMessageType(typeSet:String):void {
			this._bettingMessageType = typeSet;
		}
		
		public function get bettingMessageType():String {
			return (this._bettingMessageType);
		}
		
		/**
		 * Validates a (usually incoming) peer message as a valild poker betting message.
		 * 
		 * @param	peerMessage The peer message to validate.
		 * 
		 * @return A new instance containing all of the data of the source peer message, or null
		 * if the source peer message can't be validated as a poker betting message.
		 */
		public static function validateBettingMessage(peerMessage:IPeerMessage):PokerBettingMessage {
			if (peerMessage == null) {
				return (null);
			}
			try {
				//must match structure in createBettingMessage...				
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
				var pbMessage:PokerBettingMessage = new PokerBettingMessage(peerMessage);
				pbMessage.bettingMessageType = messageTypeStr;				
				if ((peerMessage.data["value"] != undefined) && (peerMessage.data["value"] != null)) {
					pbMessage.value = Number(peerMessage.data["value"]);
				}
				if ((peerMessage.data["payload"] != undefined) && (peerMessage.data["payload"] != null)) {
					pbMessage.data = peerMessage.data["payload"];
				}				
				pbMessage.timestampGenerated = peerMessage.timestampGenerated;
				pbMessage.timestampSent = peerMessage.timestampSent;
				pbMessage.timestampReceived = peerMessage.timestampReceived;
				return (pbMessage);
			} catch (err:*) {				
				return (null);
			}
			return (null);			
		}
		
		/** 
		 * Creates a betting message (for sending) encapsulated within a standard peer message.
		 * 
		 * @param	messageType The type of betting message to create, usually one of the defined class constants.
		 * @param	valueSet The value to use with the message. If null, the internal value property will be used.
		 * @param	payload An optional payload to include with the message.
		 */
		public function createBettingMessage(messageType:String, valueSet:Number = Number.POSITIVE_INFINITY, payload:Object = null):void {
			var dataObj:Object = new Object();
			dataObj.type = messageHeader + "/" + version + "/" + messageType;	
			if (valueSet!=Number.POSITIVE_INFINITY) {
				dataObj.value = valueSet;
			} else {
				dataObj.value = this.value;
			}
			dataObj.payload = payload;
			super.data = dataObj;
		}
	}
}
/**
* Defines events and associated data dispatched by a PeerMessageHandler instance.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.events {
	
	import flash.events.Event;
	import p2p3.interfaces.IPeerMessage;

	public class PeerMessageHandlerEvent extends Event {
		
		//Dispatched when a valid peer message has been received.			
		public static const PEER_MSG:String = "Events.PeerMessageHandlerEvent.PEER_MSG";
		//Dispatched when a valid peer message is logged
		public static const PEER_LOG:String = "Events.PeerMessageHandlerEvent.PEER_LOG";
		//Dispatched when a peer message is incorrect, badly formatted, etc.
		public static const PEER_ERROR:String = "Events.PeerMessageHandlerEvent.PEER_ERROR";
		
		//IPeerMessage implementation associated with the message.
		public var message:IPeerMessage;
		
		public function PeerMessageHandlerEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false) {
			super(type, bubbles, cancelable);
		}		
	}
}
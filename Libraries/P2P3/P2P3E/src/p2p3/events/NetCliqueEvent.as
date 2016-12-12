/**
* Defines events dispatched by a NetClique.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.events {
	
	import flash.events.Event;	
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.interfaces.IPeerMessage;
	import p2p3.events.NetCliqueEvent;
	
	public class NetCliqueEvent extends Event {
		
		//Connected to new or existing clique.
		public static const CLIQUE_CONNECT:String = "Event.NetCliqueEvent.CLIQUE_CONNECT";		
		//Disconnected from clique.
		public static const CLIQUE_DISCONNECT:String = "Event.NetCliqueEvent.CLIQUE_DISCONNECT";
		//An attempt to connect to or create a clique failed.
		public static const CLIQUE_ERROR:String = "Event.NetCliqueEvent.CLIQUE_ERROR";
		//A peer has connected to the clique.
		public static const PEER_CONNECT:String = "Event.NetCliqueEvent.PEER_CONNECT";
		//A peer has disconnected from the clique.
		public static const PEER_DISCONNECT:String = "Event.NetCliqueEvent.PEER_DISCONNECT";		
		//A complete message has been received from a peer. The raw message data is stored in the "raw_message" property of the message.
		public static const PEER_MSG:String = "Event.NetCliqueEvent.PEER_MSG";	
		
		public var memberInfo:INetCliqueMember = null; //Only with PEER_* events
		public var message:IPeerMessage = null; //Only with PEER_MSG event
		public var nativeEvent:Event = null; //Optional native or preceeding event type
		
		public function NetCliqueEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false) {
			super(type, bubbles, cancelable);
		}		
	}
}
/**
* Defines events broadcast by Lounge instances.
* 
* The latest standalone Solidity compiler can be found here: https://github.com/ethereum/solidity/releases
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events {
	
	import flash.events.Event;
	
	public class LoungeEvent extends Event {
				
		//A new clique (INetClique implementation) has been succesfully created and connected.
		public static const NEW_CLIQUE:String = "Events.LoungeEvent.NEW_CLIQUE";
		//The clique instance managed by the Lounge is about to close.
		public static const CLOSE_CLIQUE:String = "Events.LoungeEvent.CLOSE_CLIQUE";
		//The clique has become unexpectedly disconnected or failed to connect.
		public static const DISCONNECT_CLIQUE:String = "Events.LoungeEvent.DISCONNECT_CLIQUE";
		//A new Ethereum instance has been succesfully created and initialized.
		public static const NEW_ETHEREUM:String = "Events.LoungeEvent.NEW_ETHEREUM";
		//A new TableManager instance has been succesfully created and initialized.
		public static const NEW_TABLEMANAGER:String = "Events.LoungeEvent.NEW_TABLEMANAGER";
		//The current PlayerProfile instance has been fully updated.
		public static const UPDATED_PLAYERPROFILE:String = "Events.LoungeEvent.UPDATED_PLAYERPROFILE";
		
		public function LoungeEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) { 
			super(type, bubbles, cancelable);
		} 
		
		public override function clone():Event { 
			return new LoungeEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String { 
			return formatToString("LoungeEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}
	}
}
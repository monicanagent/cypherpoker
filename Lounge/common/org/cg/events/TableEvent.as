/**
* Events dispatched from Table instances.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
package org.cg.events {
	
	import flash.events.Event;
	import p2p3.interfaces.INetCliqueMember;
		
	public class TableEvent extends Event {
		
		//The required number of peers/players has joined the table.
		public static const QUORUM:String = "Events.TableEvent.QUORUM";
		//A required player, other than the local player (self), has left the table. The player's clique information is included in the 
		//"memberInfo" property.
		public static const PLAYER_LEAVE:String = "Events.TableEvent.PLAYER_LEAVE";	
		//The local player (self) has disconnected from the table.
		public static const LEFT:String = "Events.TableEvent.LEFT";			
		//The table is about to be destroyed.
		public static const DESTROY:String = "Events.TableEvent.DESTROY";			
		
		public var memberInfo:INetCliqueMember = null; 
		
		public function TableEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) { 
			super(type, bubbles, cancelable);			
		} 
		
		public override function clone():Event 	{ 
			return new TableEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String { 
			return formatToString("TableEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}		
	}	
}
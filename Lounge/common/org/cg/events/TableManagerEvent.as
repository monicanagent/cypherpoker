/**
* Events dispatched from TableManager instances.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events {
	
	import flash.events.Event;
	import org.cg.Table;
	
	public class TableManagerEvent extends Event {
		
		//Valid table information has been received by the TableManager instance. A new or existing (if previously received) "table" instance is included 
		//along with the received table "info".
		public static const TABLE_RECEIVED:String = "Event.TableManagerEvent.TABLE_RECEIVED";
		//A new Table instance has been created (may not be connected). The "table" property references the instance.
		public static const NEW_TABLE:String = "Event.TableManagerEvent.NEW_TABLE";
		//The table manage has disconnected from its clique connection. All tables are also automatically disconnected.
		public static const DISCONNECT:String = "Event.TableManagerEvent.DISCONNECT";
		
		public var info:Object = null; //used with any events that include information
		public var table:Table = null; //used with events that include a Table instance
		
		public function TableManagerEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) { 
			super(type, bubbles, cancelable);			
		} 
		
		public override function clone():Event { 
			return new TableEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String { 
			return formatToString("TableEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}
	}
}
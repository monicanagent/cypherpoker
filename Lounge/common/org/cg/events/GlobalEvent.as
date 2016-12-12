/**
* Event encapsulation class for GlobalDispatcher events.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events {
	
	import org.cg.interfaces.IGlobalEvent;
	
	public class GlobalEvent implements IGlobalEvent {
		
		private var _source:*= null;
		private var _type:*= null;
		private var _method:*= null;
		
		public function GlobalEvent(eventType:String = null) {
			type=eventType;
		}
				
		/**
		 * The source or sender of the global event.
		 */
		public function get source():* {
			return (_source);
		}
		
		public function set source(value:*):void {
			_source = value;
		}
		
		/**
		 * The event type (same a standard Event type property).
		 */
		public function get type():String {
			return (_type);
		}
		
		public function set type(typeSet:String):void {
			_type = typeSet;
		}
		
		/**
		 * The method to ivoke when the event is dispatched.
		 */
		public function get method():Function {
			return (_method);
		}
		
		public function set method(mSet:*):void {
			_method = mSet;
		}
	}
}
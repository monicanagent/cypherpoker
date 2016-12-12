/**
* A global game status processor and dispatcher.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
	
	import org.cg.interfaces.IStatusEvent;
	import org.cg.interfaces.IStatusReport;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import org.cg.DebugView;
	
	public class Status extends EventDispatcher {
		
		private	static var _instance:Status = null; //the only current processing instance
		
		public function Status() {
			super();
		}
		
		/**
		 * @return The instance of the Status object to be used to bind or unbind events.
		 */
		public static function get dispatcher():Status {
			checkInstance();
			return (_instance);
		}
		
		/**
		 * Dispatches a report event.
		 * 
		 * @param	reportObject The source IStatusReport implementation containing the status data and event type
		 * to dispatch.
		 */
		public static function report(reportObject:IStatusReport):void {
			checkInstance();
			try {
				var event:*= reportObject.createEvent(); //this should be an Event type
				_instance.dispatchEvent(event);				
			} catch (err:*) {				
			}
		}
		
		/**
		 * Checks for the existance of the internal _instance reference and sets it if it's null.
		 */
		private static function checkInstance():void {
			if (_instance == null) {
				_instance = new Status();
			}
		}		
	}
}
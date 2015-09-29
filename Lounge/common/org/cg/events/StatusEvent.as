/**
* A centralized status event object.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events 
{
	import flash.events.Event;
	import org.cg.interfaces.IStatusEvent;
	import org.cg.interfaces.IStatusReport;
	
	public class StatusEvent extends Event implements IStatusEvent
	{
		
		private var _sourceStatusReport:IStatusReport = null; //the source report for this event
		
		/**		 
		 * Creates a new status event.
		 * 
		 * @param	type The "type" property for an Event constructor.
		 * @param	bubbles The "bubbles" property for an Event constructor.
		 * @param	cancelable The "cancelable" property for an Event constructor.
		 */
		public function StatusEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
		{			
			super(type, bubbles, cancelable);
		}
		
		/**
		 * The status report instance associated with this event.
		 */
		public function get sourceStatusReport():IStatusReport
		{
			return (_sourceStatusReport);
		}
		
		public function set sourceStatusReport(sourceSet:IStatusReport):void
		{
			//set only once
			if (_sourceStatusReport == null) {
				_sourceStatusReport = sourceSet;
			}
		}
	}
}
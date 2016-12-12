/**
* A poker game status object used to centrally report game progress and other live statuses.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package {
	
	import org.cg.interfaces.IStatusEvent;
	import org.cg.interfaces.IStatusReport;
	import events.PokerGameStatusEvent;
	import org.cg.Status;

	public class PokerGameStatusReport implements IStatusReport {
				
		private var _message:String = new String();
		private var _data:* = null;
		private var _eventType:String = PokerGameStatusEvent.STATUS;
		
		/**
		 * Creates a new poker game status report object.
		 * 
		 * @param	message The human-readable message of the status report.
		 * @param	eventType The event type of the output of the createEvent output. 
		 * @param	dataObj Optional data to be included with the event.
		 */
		public function PokerGameStatusReport(message:String, eventType:String=PokerGameStatusEvent.STATUS, dataObj:*=null) {
			_message = message;			
			_eventType = eventType;
			_data = dataObj;
		}		
		
		/**
		 * @return The human-readable message of the status report.
		 */
		public function get message():String {
			return (_message);
		}
		
		/**
		 * @return Data included with the status report instance. Default is null.
		 */
		public function get data():* {
			return (_data);
		}
		
		/**
		 * @return The event type to dispatch this status report instance with.
		 */
		public function get eventType():String {
			return (_eventType);
		}
		
		/**
		 * @return A new PokerGameStatusEvent instance.
		 */
		public function createEvent():IStatusEvent {
			var newEvent:PokerGameStatusEvent = new PokerGameStatusEvent(eventType);
			newEvent.sourceStatusReport = this;
			return (newEvent);
		}
		
		/**
		 * Reports this instance by invoking the "report" function in the Status class.
		 */
		public function report():void {
			Status.report(this);
		}
	}
}
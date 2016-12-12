/**
* Events dispatched by the Rochambeau class.
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.events {
	
	import flash.events.Event;
	
	public class RochambeauEvent extends Event {
		
		//Rochambeau protocol has started (externally or locally)
		public static const START:String = "Event.RochambeauEvent.START";
		//All active games have completed a phase of the Rochambeau game process
		public static const PHASE_CHANGE:String = "Event.RochambeauEvent.PHASE_CHANGE";
		//The Rochambeau process is complete and a single winner has been found. The winning peer may now assume the leader role.
		public static const COMPLETE:String = "Event.RochambeauEvent.COMPLETE";
		
		public function RochambeauEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) {
			super(type, bubbles, cancelable);			
		}		
	}
}
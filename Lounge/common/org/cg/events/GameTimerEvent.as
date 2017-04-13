/**
* Events dispatched by a GameTimer instance.
* 
* Adapted from the SWAG ActionScript toolkit: https://code.google.com/p/swag-as/
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events {
	
	import flash.events.Event;
	
	public class GameTimerEvent extends Event {
		
		//Timer has started counting down
		public static const COUNTDOWN_START:String = "Event.GameTimerEvent.COUNTDOWNSTART";
		//Timer has started counting up
		public static const COUNTUP_START:String = "Event.GameTimerEvent.COUNTUPSTART";
		//Timer has finished counting down (remaining time is 0)
		public static const COUNTDOWN_END:String = "Event.GameTimerEvent.COUNTDOWNEND";
		//Timer has finished counting up. Usually this means that the timer has been stopped manually.
		public static const COUNTUP_END:String = "Event.GameTimerEvent.COUNTUPEND";
		//Countdown timer has been reset.
		public static const COUNTDOWN_RESET:String = "Event.GameTimerEvent.COUNTDOWNRESET";
		//Countup timer has been reset.
		public static const COUNTUP_RESET:String = "Event.GameTimerEvent.COUNTUPRESET";
		//The countdown timer has changed (clock tick).
		public static const COUNTDOWN_TICK:String = "Event.GameTimerEvent.COUNTDOWNTICK";
		//The countup timer has changed (clock tick).
		public static const COUNTUP_TICK:String = "Event.GameTimerEvent.COUNTUPTICK";
		
		public function GameTimerEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false) {
			super(type, bubbles, cancelable);			
		}
	}
}
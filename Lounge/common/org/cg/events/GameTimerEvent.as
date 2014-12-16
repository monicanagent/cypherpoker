/**
* Events dispatched by a GameTimer instance.
* 
* Adapted from the SWAG ActionScript toolkit: https://code.google.com/p/swag-as/
* 
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events 
{
	
	import flash.events.Event;
	
	public class GameTimerEvent extends Event 
	{
		
		public static const COUNTDOWN_START:String = "Event.GameTimerEvent.COUNTDOWNSTART";
		public static const COUNTUP_START:String = "Event.GameTimerEvent.COUNTUPSTART";
		public static const COUNTDOWN_END:String = "Event.GameTimerEvent.COUNTDOWNEND";
		public static const COUNTUP_END:String = "Event.GameTimerEvent.COUNTUPEND";
		public static const COUNTDOWN_RESET:String = "Event.GameTimerEvent.COUNTDOWNRESET";
		public static const COUNTUP_RESET:String = "Event.GameTimerEvent.COUNTUPRESET";
		public static const COUNTDOWN_TICK:String = "Event.GameTimerEvent.COUNTDOWNTICK";
		public static const COUNTUP_TICK:String = "Event.GameTimerEvent.COUNTUPTICK";
		
		public function GameTimerEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false) 
		{
			super(type, bubbles, cancelable);			
		}
	}
}
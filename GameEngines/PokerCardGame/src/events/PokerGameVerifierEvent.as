/**
* Events broadcast by PokerGameVerifier instances.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/


package events {
	
	import flash.events.Event;
	

	public class PokerGameVerifierEvent extends Event {
		
		//Game verification successfully completed
		public static const SUCCESS:String = "Event.PokerGameVerifierEvent.SUCCESS";
		//Game verification failed
		public static const FAIL:String = "Event.PokerGameVerifierEvent.FAIL";
		
		public function PokerGameVerifierEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) { 
			super(type, bubbles, cancelable);			
		}		
	}	
}
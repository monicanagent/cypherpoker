/**
* Events broadcast by PokerBettingModule instances.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package events 
{	
	import flash.events.Event;
	
	public class PokerBettingEvent extends Event 
	{
		
		//A new betting round has started.
		public static var BETTING_STARTED:String = "Event.PokerBettingEvent.BETTING_STARTED";
		//The current betting cycle has ended.
		public static var BETTING_DONE:String = "Event.PokerBettingEvent.BETTING_DONE";
		//The final bet of the game has been committed.
		public static var BETTING_FINAL_DONE:String = "Event.PokerBettingEvent.BETTING_FINAL_DONE";
		//Round has completed (all players have broadcast crypto keys and game results -- new dealer may now be assumed).
		public static var ROUND_DONE:String = "Event.PokerBettingEvent.ROUND_DONE";
		
		public function PokerBettingEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false) 
		{
			super(type, bubbles, cancelable);			
		}
	}
}
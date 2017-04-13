/**
* Events dispatched from the PlayerProfile instances
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events {
	
	import flash.events.Event;	
	
	public class PlayerProfileEvent extends Event {
		
		//The PlayerProfile instance has been fully updated (external data such as icon has been fully loaded and parsed).
		public static const UPDATED:String = "Event.PlayerProfileEvent.UPDATED";
		
		public function PlayerProfileEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) {
			super(type, bubbles, cancelable);
		}		
	}
}
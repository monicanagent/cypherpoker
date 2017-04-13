/**
* Events dispatched from ICard implementations.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events {
	
	import flash.events.Event;
	import org.cg.interfaces.ICard;
	
	public class CardEvent extends Event {
		
		//The card has completed its "flip" animation and is ready for further interaction.
		public static const ONFLIP:String = "Events.CardEvent.ONFLIP";
		
		public var sourceCard:ICard=null; //reference to dispatching or event source instance
		
		public function CardEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false) {
			super(type, bubbles, cancelable);			
		}		
	}
}
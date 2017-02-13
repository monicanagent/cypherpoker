/**
* Defines events dispatched from SlidingPanel instances.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events {
	
	import starling.events.Event;
	
	public class SlidingPanelEvent extends Event {
		
		//Panel is about to close.
		public static const CLOSE:String = "Event.SlidingPanelEvent.CLOSE";
		//Panel is about to opn.
		public static const OPEN:String = "Event.SlidingPanelEvent.OPEN";
		
		public function SlidingPanelEvent(type:String, bubbles:Boolean=false, data:Object=null) { 
			super(type, bubbles, data);
			
		}
	}	
}
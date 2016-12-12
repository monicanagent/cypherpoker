/**
* Events dispatched from the GlobalSettings and GameSettings classes.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events  {	
	
	import flash.events.Event;

	public class SettingsEvent extends Event {
		
		public static const LOAD:String = "Event.SettingsEvent.LOAD"; //data has been fully loaded and parsed		
		public static const LOADERROR:String = "Event.SettingsEvent.LOADERROR"; //data didn't load or was formatted wrong		
		public static const SAVE:String = "Event.SettingsEvent.SAVE"; //data has completed saving
		
		public function SettingsEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false) {
			super(type, bubbles, cancelable);			
		}
	}
}
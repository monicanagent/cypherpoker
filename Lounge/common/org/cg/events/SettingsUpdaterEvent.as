/**
* Events dispatched from SettingsUpdater instances.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events {
	
	import flash.events.Event;
	
	public class SettingsUpdaterEvent extends Event {
		
		public static const START:String = "Event.SettingsUpdaterEvent.START"; //data update operation has started
		public static const PROGRESS:String = "Event.SettingsUpdaterEvent.PROGRESS"; //data update operation has made progress
		public static const COMPLETE:String = "Event.SettingsUpdaterEvent.COMPLETE"; //data update operation has completed
		public static const FAIL:String = "Event.SettingsUpdaterEvent.FAIL"; //data update operation has failed
		
		public var percent:Number = -1; //percent completed, included with PROGRESS event
		public var statusInfo:String = null; //information text, included with PROGRESS and FAIL events
		
		public function SettingsUpdaterEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) { 
			super(type, bubbles, cancelable);
		}
	}
}
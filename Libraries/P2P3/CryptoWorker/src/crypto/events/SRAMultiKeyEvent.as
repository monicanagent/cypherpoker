/**
* Events associated with asynchronous operations of the SRAMultiKey class.
*
* (C)opyright 2014 to 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package crypto.events 
{
	import flash.events.Event;
	
	
	public class SRAMultiKeyEvent extends Event 
	{
		
		//Generation of multiple SRA keys has been successfully completed.
		public static const ONGENERATEKEYS:String = "Event.SRAMultiKeyEvent.ONGENERATEKEYS";
		//There was an error whille attempting to generate multiple SRA keys.
		public static const ONGENERATEERROR:String = "Event.SRAMultiKeyEvent.ONGENERATEERROR";
		
		public function SRAMultiKeyEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
		{ 
			super(type, bubbles, cancelable);
			
		} 
		
		public override function clone():Event 
		{ 
			return new SRAMultiKeyEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String 
		{ 
			return formatToString("SRAMultiKeyEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}
		
	}
	
}
/**
* Events dispatched from SmartContractFunction instances.
* 
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events  {
	
	import flash.events.Event;
	
	public class SmartContractFunctionEvent extends Event {
		
		//Dispatched when a function invocation is being deferred because one or more defer states have not been fulfilled.
		public static const DEFER:String = "Event.SmartContractFunctionEvent.DEFER";
		//Dispatched when a function invocation is about to occur.
		public static const INVOKE:String = "Event.SmartContractFunctionEvent.INVOKE";
		//Dispatched when a function invocation is has completed.
		public static const ONINVOKE:String = "Event.SmartContractFunctionEvent.ONINVOKE";
		
		public function SmartContractFunctionEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) { 
			super(type, bubbles, cancelable);	
		} 
		
		public override function clone():Event { 
			return new SmartContractFunctionEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String { 
			return formatToString("SmartContractFunctionEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}
	}
}
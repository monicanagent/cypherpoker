/**
* Events dispatched from the SmartContract instances.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events {
	
	import flash.events.Event;
	
	
	public class SmartContractEvent extends Event 	{
		
		//Dispatched when the smart contract is ready for use (has been successfully deployed to the blockchain and initialized).
		public static const READY:String = "Event.SmartContractEvent.READY";
		
		
		public function SmartContractEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
		{ 
			super(type, bubbles, cancelable);
			
		} 
		
		public override function clone():Event 
		{ 
			return new SmartContractEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String 
		{ 
			return formatToString("SmartContractEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}
		
	}
	
}
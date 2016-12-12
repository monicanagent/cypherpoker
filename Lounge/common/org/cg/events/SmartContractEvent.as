/**
* Events dispatched from SmartContract instances. Because events of this type are proxied, use the event.target.contract property to
* refer to the originating (dispatching) contract.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events {
	
	import flash.events.Event;
	import org.cg.SmartContractFunction;
	
	public class SmartContractEvent extends Event 	{
		
		//Dispatched when the smart contract is ready for use (has been successfully deployed to the blockchain and initialized).
		public static const READY:String = "Event.SmartContractEvent.READY";
		
		public var descriptor:XML = null; //generated XML descriptor for the contract
		
		public function SmartContractEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) { 
			super(type, bubbles, cancelable);
			
		} 
		
		public override function clone():Event { 
			return new SmartContractEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String { 
			return formatToString("SmartContractEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}
	}	
}
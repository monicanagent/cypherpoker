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
		//Deferred invocation checking for the smart contract instance is about to be started.
		public static const DEFER_CHECK_START:String = "Event.SmartContractEvent.DEFER_CHECK_START";
		//Deferred invocation checking for the smart contract instance has been stopped.
		public static const DEFER_CHECK_STOP:String = "Event.SmartContractEvent.DEFER_CHECK_STOP";
		//Deferred invocation functions associated with the smart contract instance are about to be checked.
		public static const DEFER_CHECK:String = "Event.SmartContractEvent.DEFER_CHECK";
		//A new SmartContractFunction instance associated with the smart contract has been created. The "contractFunction" reference is included
		//with this event.
		public static const FUNCTION_CREATE:String = "Event.SmartContractEvent.FUNCTION_CREATE";
		//A SmartContractFunction associated with the smart contract has been successfully invoked and is about to removed
		//from the SmartContract instance's internal functions list. The "contractFunction" reference is included with this event. Alternatively,
		//a listened may be added to the SmartContractFunction's "SmartContractFunctionEvent.ONINVOKE" event which will be dispatched prior to
		//this one.
		public static const FUNCTION_INVOKED:String = "Event.SmartContractEvent.FUNCTION_INVOKED";
		//The smart contract instance is about to be destroyed.
		public static const DESTROY:String = "Event.SmartContractEvent.DESTROY";
		
		public var descriptor:XML = null; //generated XML descriptor for the contract
		public var contractFunction:SmartContractFunction = null;
		
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
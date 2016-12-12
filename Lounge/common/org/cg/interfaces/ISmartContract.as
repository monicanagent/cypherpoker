/**
* Interface for smart contract functionality implementation.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
package org.cg.interfaces {
	
	import flash.events.Event;
	
	public interface ISmartContract {
		
		function create(... args):void; //create the implementation instance
		function get contractName():String; //the name of the contract
		function set descriptor(descSet:XML):void; //the XML descriptor of the contract
		function get descriptor():XML;
		function get abiString():String; //the JSON-encoded ABO string of the contract
		function get abi():Array; //the contract's ABI parsed into a native array
		function get address():String;	//the contract's address
		function get account():String;	//the account to use when interacting with the contract
		function get password():String;	 //the password to use when interacting with the contract
		function set clientType(typeSet:String):void; //the client type (e.g. "ethereum")
		function get clientType():String;		
		function set networkID(IDSet:uint):void; //the network ID on which the contract is deployed
		function get networkID():uint;						
		//Gets a default value defined in the global settings data (<smartcontracts>..<ethereum>..<defaults>).
		function getDefault(defaultName:String):String;		
		//Must match IEventDispatcher implementation:		
		function addEventListener(type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false):void;		
		function removeEventListener(type:String, listener:Function, useCapture:Boolean = false):void;		
		function hasEventListener(type:String):Boolean;		
		function willTrigger(type:String):Boolean;		
		function dispatchEvent (event:Event) : Boolean;
	}	
}
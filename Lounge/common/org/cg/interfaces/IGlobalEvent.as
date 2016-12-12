/**
* Interface for a GlobalEvent implementation.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {
	
	public interface IGlobalEvent {
		
		function get source():*; //event source or sender
		function set source(sourceSet:*):void;
		function get type():String; //event type (same as standard Event type)
		function set type(typeSet:String):void;
		function get method():Function; //method to invoke when method is dispatched
		function set method(mSet:*):void;		
	}
}
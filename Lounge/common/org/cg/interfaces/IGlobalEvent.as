/**
* Interface for a GlobalEvent implementation.
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {
	
	public interface IGlobalEvent {
		
		function get source():*;
		function set source(sourceSet:*):void;
		function get type():String;
		function set type(typeSet:String):void;
		function get method():Function;
		function set method(mSet:*):void;		
	}
}
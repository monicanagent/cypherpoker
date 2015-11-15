/**
* Interface for a single-instance Rochambeau game implementation.
* 
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.interfaces {
	
	import crypto.interfaces.ISRAKey;
	
	public interface IRochambeauGame 
	{
	
		function initialize():void;
		function start(requiredSelections:int):Boolean;
		function get gameIsBusy():Boolean;
		function set gameIsBusy(busySet:Boolean):void;
		function get key():ISRAKey;
		function get selections():Vector.<String>;
		function get encSelections():Vector.<String>;
		function get sourcePeerID():String;
	}	
}
/**
* Interface for a single-instance Rochambeau game implementation.
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.interfaces {
	
	import crypto.interfaces.ISRAKey;
	
	public interface IRochambeauGame {
	
		function initialize():void; //initialize the implementation instance
		function start(requiredSelections:int):Boolean; //start the implementation instance when the required number of peers (minus self) is ready
		function get gameIsBusy():Boolean; //is current implementation instance busy?
		function set gameIsBusy(busySet:Boolean):void;
		function get key():ISRAKey; //the current ISRAKey implementation being used with the implementing instance
		function get selections():Vector.<String>; //current plaintext selections
		function get encSelections():Vector.<String>; //current encrypted selections
		function get sourcePeerID():String; //the source of owning peer ID of the instance implementation
	}	
}
/**
* Interface for a BaseCardGame implementation.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {		
	
	import p2p3.interfaces.INetClique;
	import org.cg.Table;
	
	public interface IBaseCardGame {
				
		//Initialize the base card game implementation (load setup data, etc.)		 		 
		function initialize(... args):void;
		//Dispatches a specific game engine status event followed by a generic game engine status event.
		function dispatchStatusEvent(type:String, source:*, infoObj:Object = null):void;
		//The Table instance being used for the game (typically contains the segregrated clique instance)
		function get table():Table;
		//The clique being used for the game
		function get clique():INetClique;
		 //True if the base card game implementation is initialized.		 
		function get initialized():Boolean;		
		 //Attempt to start or (new round) restart the card game engine.		 
		function start(restart:Boolean = false):Boolean;
		//Attempt to reset the base card game engine to its initial state, including its user interface.
		function reset():Boolean;		
		 //Attempt to disable the base card game engine's user interface.		 
		function disableUI():Boolean;		
		 //Attempt to enable the base card game engine's user interface.
		function enableUI():Boolean;		
		 //Default handler invoked when the default view is rendered,
		function onRenderDefaultView():void;
		//Reference to the settings class.
		function get settings():Class;
		//Reference to the current deck being used.
		function get currentDeck():ICardDeck;			
		//Cleans up the implementation's memory, event listeners, etc. usually prior to being removed from memory.
		function destroy():void;
	}	
}
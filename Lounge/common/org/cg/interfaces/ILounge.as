/**
* Interface for a generic Lounge implementation.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {
	
	import org.cg.PlayerProfile;
	import p2p3.interfaces.INetClique;
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.workers.CryptoWorkerHost;	
	import p2p3.interfaces.ICryptoWorkerHost;
	import org.cg.TableManager;
	import org.cg.GlobalSettings;
	import flash.events.Event;
	import flash.display.DisplayObjectContainer;
	import Ethereum;
	
	public interface ILounge {
		
		//Launches a new lounge instance
		function launchNewLounge(... args):void;
		//Initilizes a new child lounge reference such as when launching a new native window in the same application instance
		function initializeChildLounge():void;
		//is the Lounge instance a child of an existing process window?
		function get isChildInstance():Boolean;		
		//Create a new default clique connection for the Lounge with the specified ID and optional options
		function createCliqueConnection(cliqueID:String, options:Object = null):INetClique;
		//Remove the current default Lounge clique connection
		function removeClique():void;
		//The currently active clique instance
		function get clique():INetClique;
		//The currently active player profile for the local (self) player.
		function get currentPlayerProfile():PlayerProfile;
		//Reference to an active Ethereum interface library.
		function get ethereum():Ethereum;
		function set ethereum(ethereumSet:Ethereum):void;
		//The parent/launching ILounge implementation, if any.
		function get parentLounge():ILounge
		//True if Ethereum functionality is enabled. This setting does not reflect the readiness or availability of an Ethereum instance.
		function get ethereumEnabled():Boolean;		
		function set ethereumEnabled(ethEnabled:Boolean):void; 
		//Attempt to launch a new Ethereum instance with optional launch parameters
		function launchEthereum(launchParams:Object = null):Ethereum;
		//Reference to the current TableManager instance 
		function get tableManager():TableManager
		//Reference to the current game parameters implementation
		function get gameParameters():IGameParameters
		//Direct references to the root display objects / main classes of currently loaded games. Index 0 is the most recently loaded game.
		function get games():Vector.<Object>;
		//Reference to the global settings object
		function get settings():Class;
		//Load an external game using global settings data
		 function loadGame(gameName:String, room:IRoom):void;
		//Attempts to destroy the current, most recently-loaded game and returns true if successful.
		 function destroyCurrentGame():Boolean;
		//The maximum CBL as defined in the settings
		function get maxCryptoByteLength():uint;
		function set maxCryptoByteLength(mcblSet:uint):void;		
		//Standard EventDispatcher methods:
		function addEventListener (type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false) : void;
		function dispatchEvent (event:Event) : Boolean;
		function hasEventListener (type:String) : Boolean;
		function removeEventListener (type:String, listener:Function, useCapture:Boolean = false) : void;
		function willTrigger (type:String) : Boolean;
	}	
}
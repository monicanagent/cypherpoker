/**
* Interface for Player or related type implementations.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package interfaces 
{
	import crypto.interfaces.ISRAKey;
	import crypto.interfaces.ISRAMultiKey;
	
	public interface IPlayer 
	{
		//Start the implementation's functionality (instance should be fully initialized at this point).
		function start():void;
		//Enable event responders to various game events.
		function enableGameMessaging():void;
		//Disable event responders to various game events.
		function disableGameMessaging():void;
		//The current crypto keys set being used by the player.
		function set key(keySet:ISRAMultiKey):void;
		function get key():ISRAMultiKey;
		//Cleans the instance in preparation for removal from memory.Values are not scrubbed if transferring to a new Dealer instance.
		function destroy(transferToDealer:Boolean=false):void;
	}	
}
/**
* Interface for a PeerMessageHandler implementation.
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.interfaces 
{
	
	import p2p3.interfaces.INetClique;
	import p2p3.interfaces.IPeerMessage;
	
	public interface IPeerMessageHandler 
	{
		
		/**
		 * The message handler attaches itself to the associated netclique to handle messages.
		 */
		function addToClique(targetClique:INetClique = null):Boolean;
		/**
		 * The message handler removes itself from the associated netclique to stop handling messages.
		 */
		function removeFromClique(targetClique:INetClique = null):Boolean;
		/**
		 * Blocks message events from being dispatched; messages are stored and forwarded when unblocked.
		 */		
		function block():void;
		/**
		 * Unblocks message events to allow them to be broadcast. Any queued (blocked) messages are dispatched first, in order of receipt.
		 */
		function unblock():void;
		
	}
	
}
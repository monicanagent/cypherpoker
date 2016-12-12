/**
* Interface for a PeerMessageLog implementation.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.interfaces {
		
	import p2p3.interfaces.IPeerMessage;
	
	public interface IPeerMessageLog {
		
		/**
		 * Add a peer message to the log.
		 */
		function addMessage(peerMessage:IPeerMessage):void;
		/**
		 * Export the log in a specified format.		 
		 */
		function export(formatType:*):*;
		/**
		 * Free any memory being used by the message log and dremove any external references.
		 */
		function destroy():void;		
	}	
}
/**
* Interface for a NetClique implementation.
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.interfaces 
{
		
	import flash.events.IEventDispatcher;
	import p2p3.events.NetCliqueEvent;
	import p2p3.interfaces.IPeerMessage;
	import p2p3.interfaces.INetCliqueMember;
	
	public interface INetClique extends IEventDispatcher 
	{
				
		/**
		 * Sends data to a specific clique member.
		 * 
		 * @param	peer The INetCliqueMember implementation containing the target peer ID (format and
		 * contents of this ID are determined by the specific INetClique implementation).
		 * @param	msgObj The IPeerMessage instance to send to the peer.
		 * 
		 * @return True if the send was successful, false otherwise.
		 */
		function sendToPeer(peer:INetCliqueMember, msgObj:IPeerMessage):Boolean;
		/**
		 * Sends data to a list of specific clique members.
		 * 
		 * @param	peers A vector array if INetCliqueMember implementations to send to.
		 * @param	msgObj  The IPeerMessage instance to send to the peers.
		 * 
		 * @return A vector array of successes (true or false), of the send operations for the listed
		 * peers. Each success entry corresponds to the INetCliqueMember instance in the supplied
		 * peers vector (peer[0]=send success[0], peer[1]=send success[1], etc.
		 */
		function sendToPeers(peers:Vector.<INetCliqueMember>, msgObj:IPeerMessage):Vector.<Boolean>;
		/**
		 * Sends data to all connected peers (use with caution and smaller groups).
		 * 
		 * @param	msgObj The IPeerMessage instance to send to all connected peers.
		 * 
		 * @return True if the message was sent (note there is no guarantee of receipt), false otherwise.
		 */
		function broadcast(msgObj:IPeerMessage):Boolean;
		/**
		 * Connects to the NetClique either by creating it if it doesn't exist or joining it if possible.
		 * 
		 * Connection arguments (args) should be presented in the same order as the NetClique's connection implementation.
		 * 
		 * @return True if the NetClique implementation has started to connect, false otherwise (for
		 * example, already connected, not properly initialized, etc.).
		 */
		function connect(... args):Boolean;
		/**
		 * Disconnects from the NetClique.
		 * 
		 * @return True if the NetClique could be successfully disconnected.
		 */
		function disconnect():Boolean;
		/**
		 * True if the clique is connected. Because some cliques may require additional login
		 * information or connection steps, this flag only specifies the status of the network connection,
		 * not if it is ready for use (use the "ready" property for that).
		 */
		function get connected():Boolean;		
		/**
		 * A vector array of INetCliqueMember instances connected to the clique. This list will
		 * vary as members join or leave the clique.
		 */
		function get connectedPeers():Vector.<INetCliqueMember>;
		/**
		 * A INetCliqueMember containing the local peer info of the currently running NetClique node (ourselves).
		 */
		function get localPeerInfo():INetCliqueMember;
		
	}
	
}
/**
* Peer to peer networking clique implementation via Adobe's RTMFP.
* 
* Adapted from the SWAG ActionScript toolkit: https://code.google.com/p/swag-as/
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.netcliques 
{
	
	import p2p3.interfaces.INetCliqueMember;
	
	public class NetCliqueMember implements INetCliqueMember 
	{
		
		private var _peerID:String = null;
		
		/**
		 * Instantiates the NetCliqueMember.
		 * 
		 * @param	initPeerID An initial peer ID to assign to the instance.
		 */
		public function NetCliqueMember(initPeerID:String = null) 
		{
			if (initPeerID != null) {
				_peerID = initPeerID;
			}
		}
		
		/**
		 * The peer ID associated with the instance.
		 */
		public function get peerID():String 
		{
			return (_peerID);
		}
		
		public function set peerID(value:String):void 
		{
			_peerID = value;
		}		
	}
}
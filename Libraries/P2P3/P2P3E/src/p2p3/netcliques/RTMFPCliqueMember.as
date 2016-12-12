/**
* Stores and processes RTMFP clique member information.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.netcliques 
{

	import p2p3.netcliques.NetCliqueMember;
	
	public class RTMFPCliqueMember extends NetCliqueMember 
	{		
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	initPeerID The peer ID to assign to the new instance.
		 */
		public function RTMFPCliqueMember(initPeerID:String = null) 
		{
			super (initPeerID);
		}
		
		public function toString():String 
		{
			return ("RTMFPCliqueMember: " + super.peerID);
		}
		
	}

}
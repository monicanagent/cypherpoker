/**
* Interface for NetCliquemember implementation.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.interfaces {
	
	public interface INetCliqueMember {
		
		//The peer ID of the member.
		function get peerID():String;
		function set peerID(idSet:String):void;		
	}	
}
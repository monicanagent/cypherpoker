/**
* Interface for a generic Lounge implementation.
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {
		
	import p2p3.interfaces.INetClique;
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.workers.CryptoWorkerHost;
	
	public interface ILounge 
	{
		
		function get leaderSet():Boolean;		
		function get leaderIsMe():Boolean;
		function get currentLeader():INetCliqueMember;
		function set currentLeader(leaderSet:INetCliqueMember):void;
		function get clique():INetClique;
		function get settings():Class;
		function get nextAvailableCryptoWorker():CryptoWorkerHost;
		function get maxCryptoByteLength():uint;
		function set maxCryptoByteLength(mcblSet:uint):void;
		
	}	
}
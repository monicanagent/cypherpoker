/**
* Interface for a generic Lounge implementation.
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces 
{
	import p2p3.interfaces.INetClique;
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.workers.CryptoWorkerHost;
	import Ethereum;
	
	public interface ILounge 
	{
		//Has the leader role been set yet?
		function get leaderSet():Boolean;
		//Am I the current activity leader?
		function get leaderIsMe():Boolean;
		function set leaderIsMe(leaderSet:Boolean):void;
		//The INetCliqueMember implementation of the current activity leader
		function get currentLeader():INetCliqueMember;
		function set currentLeader(leaderSet:INetCliqueMember):void;
		//The currently active clique instance
		function get clique():INetClique;
		//The active Ethereum integration library
		function get ethereum():Ethereum;
		//Reference to the current game parameters implementation
		function get gameParameters():IGameParameters;
		//Reference to the settings object
		function get settings():Class;
		//A reference to the next available CryptoWorkerHost instance
		function get nextAvailableCryptoWorker():CryptoWorkerHost;
		//The maximum CBL as defined in the settings
		function get maxCryptoByteLength():uint;
		function set maxCryptoByteLength(mcblSet:uint):void;
		
	}	
}
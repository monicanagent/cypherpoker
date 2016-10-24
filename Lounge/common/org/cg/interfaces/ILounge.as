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
	import p2p3.interfaces.ICryptoWorkerHost;
	import org.cg.GlobalSettings;
	import Ethereum;
	
	public interface ILounge 
	{
		//Launches a new lounge instance
		function launchNewLounge(... args):void;
		//Initilizes a new child lounge reference such as when launching a new native window in the same application instance
		function initializeChildLounge(childRef:*):void;
		//is the Lounge instance a child of an existing process window?
		function get isChildInstance():Boolean;
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
		//Reference to an active Ethereum interface library.
		function get ethereum():Ethereum;
		//Reference to the current game parameters implementation
		function get gameParameters():IGameParameters
		//Reference to the global settings object
		function get settings():Class;		
		//The maximum CBL as defined in the settings
		function get maxCryptoByteLength():uint;
		function set maxCryptoByteLength(mcblSet:uint):void;		
	}	
}
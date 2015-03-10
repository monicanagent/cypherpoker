/**
* Interface for PokerBettingModule and related instances.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package interfaces 
{	
	import PokerCardGame;
	import p2p3.interfaces.INetCliqueMember;
	
	public interface IPokerBettingModule 
	{
		
		//A reference to the parent PokerCardGame instance
		function get game():PokerCardGame;
		//Initializes the implementation (usually at the start of the game or round).
		function initialize():void;
		//Resets the implementation so that a new round can be started.
		function reset():void;
		//Starts the next (or first) cycle of betting (usually invoked by the dealer).
		function startNextBetting():void;
		//The current player balance.
		function get balance():Number;
		//The current community pot balance.
		function get communityPot():Number;
		//Returns an ordered Vector array of balances for the supplied member list.
		function getPlayerBalances(members:Vector.<INetCliqueMember>):Vector.<Number>;		
	}	
}
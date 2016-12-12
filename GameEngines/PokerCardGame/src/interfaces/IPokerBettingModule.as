/**
* Interface for PokerBettingModule and related instances.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package interfaces {	
	
	import PokerCardGame;
	import interfaces.IPokerPlayerInfo;
	import p2p3.interfaces.INetCliqueMember;
	
	public interface IPokerBettingModule {
		
		//A reference to the parent PokerCardGame instance
		function get game():PokerCardGame;
		//Initializes the implementation (usually at the start of the game or round).
		function initialize():void;
		//Pauses the implementation by disabling the user interface.
		function pause():void;
		//Resumes the implementation by enabling the user interface if
		function resume():void;		
		//Resets the implementation so that a new round can be started.
		function reset():void;
		//Starts the next (or first) cycle of betting (usually invoked by the dealer).
		function startNextBetting():void;
		//The current player balance.
		function get balance():Number;
		//All active players, includes folded players.
		function get allPlayers():Vector.<IPokerPlayerInfo>;
		//All active players, includes folded players.
		function get nonFoldedPlayers():Vector.<IPokerPlayerInfo>;
		//Self (local) player info.
		function get selfPlayerInfo():IPokerPlayerInfo;
		//Get the player info object for a specific clique memmber.
		function getPlayerInfo(member:INetCliqueMember):IPokerPlayerInfo;
		//Returns true if the game has ended (all but one player have 0 balances.
		function get gameHasEnded():Boolean;
		//Current clique member acting as dealer.
		function get currentDealerMember():INetCliqueMember;
		//Current clique member acting as big blind.
		function get currentBigBlindMember():INetCliqueMember;
		//Current clique member acting as small blind.
		function get currentSmallBlindMember():INetCliqueMember;
		//Current poker player actively betting (has betting control). Null if no player currently has control.
		function get currentBettingPlayer():IPokerPlayerInfo;
		//Adds a clique member to the end of the player betting order.
		function addPlayer(member:INetCliqueMember):Boolean 
		//Removes a clique member from the players list and optionally updates roles if necessary.
		function removePlayer(member:*, updateRoles:Boolean = true):Boolean		
		//The current community pot balance.
		function get communityPot():Number;
		//Returns an ordered Vector array of balances for the supplied member list.
		function getPlayerBalances(members:Vector.<INetCliqueMember>):Vector.<Number>;		
	}	
}
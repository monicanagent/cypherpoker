/**
* Interface for PokerPlayerInfo and related instances.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package interfaces 
{
	import p2p3.interfaces.INetCliqueMember;
	import interfaces.IPokerHand;
	
	public interface IPokerPlayerInfo 
	{
		//A reference to the INetCliqueMember implementation associated with the player.
		function get netCliqueInfo():INetCliqueMember;
		//The last bet committed by the player, or Number.NEGATIVE_INFINITY if one hasn't been committed yet.
		function get lastBet():Number;
		function set lastBet(valueSet:Number):void;
		//The total bet committed by the player during this round, or Number.NEGATIVE_INFINITY if no bets have been committed yet.
		function get totalBet():Number; 
		function set totalBet(valueSet:Number):void;
		//The player balance, if shared. Number.NEGATIVE_INFINITY by default.
		function get balance():Number;
		function set balance(valueSet:Number):void;
		//True if the player is currently flagged as the dealer.
		function get isDealer():Boolean;
		function set isDealer(valueSet:Boolean):void;		
		//True if the player is currently flagged as the big blind.
		function get isBigBlind():Boolean;
		function set isBigBlind(valueSet:Boolean):void;
		//True if the player is currently flagged as the small blind.
		function get isSmallBlind():Boolean;
		function set isSmallBlind(valueSet:Boolean):void;
		//True if the player has folded during this round.
		function get hasFolded():Boolean;
		function set hasFolded(valueSet:Boolean):void;
		//True if the player has placed a bet this round (totalBet!=Number.NEGATIVE_INFINITY)
		function get hasBet():Boolean;
		//The number of bets committed by the player for the hand
		function get numBets():uint;				
		function set numBets(valueSet:uint):void;
		//A reference to the last analyzed result hand for the player, cleared each round.
		function get lastResultHand():IPokerHand;
		function set lastResultHand(handSet:IPokerHand):void;
		//A reference to the last fully re-keyed comparison deck as initiated by this player.
		function get comparisonDeck():Vector.<String>;
		function set comparisonDeck(deckSet:Vector.<String>):void;		
	}	
}
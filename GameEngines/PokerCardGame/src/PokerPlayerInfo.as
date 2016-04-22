/**
* Stores information such as betting flags, values, and clique membership for a single player.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package  
{	
	import interfaces.IPokerPlayerInfo;
	import interfaces.IPokerHand;
	import p2p3.interfaces.INetCliqueMember;
	import org.cg.DebugView;	

	public class PokerPlayerInfo implements IPokerPlayerInfo
	{
		
		private var _balance:Number = Number.NEGATIVE_INFINITY;	//default balance
		private var _totalBet:Number = Number.NEGATIVE_INFINITY; //default total bet (per round)
		private var _lastBet:Number = Number.NEGATIVE_INFINITY;	 //default last bet
		private var _netCliqueInfo:INetCliqueMember = null; //associated member reference
		private var _isDealer:Boolean = false; //is player the current dealer?
		private var _isBigBlind:Boolean = false; //is player the current big blind?
		private var _isSmallBlind:Boolean = false; //is player the current small blind?
		private var _hasBet:Boolean = false; //has the player placed an initial bet?
		private var _numBets:uint = 0; //the number of bets placed by the player so far in this round
		private var _hasFolded:Boolean = false; //has the player folded?
		private var _lastResult:IPokerHand = null; //the last highest result hand, available at end of round and cleared on new one
		private var _comparisonDeck:Vector.<String> = null; //last fully re-keyed comparison deck as initiated by this player.
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	ncMember The member reference to associate with the new instance.
		 */
		public function PokerPlayerInfo(ncMember:INetCliqueMember) 
		{
			_netCliqueInfo = ncMember;
		}
		
		/**
		 * @return The clique member info associated with the player.
		 */
		public function get netCliqueInfo():INetCliqueMember 
		{
			return (_netCliqueInfo);
		}
		
		/**
		 * The player's balance.
		 */
		public function get balance():Number 
		{
			return (_balance);
		}
		
		public function set balance(valueSet:Number):void 
		{
			_balance = valueSet;
		}
		
		/**
		 * The player's total bet for the current round. If none was placed the total bet will be Number.NEGATIVE_INFINITY.
		 */
		public function get totalBet():Number 
		{
			return (_totalBet);
		}
		
		public function set totalBet(valueSet:Number):void 
		{			
			_totalBet = valueSet;
		}
		
		/**
		 * The player's last committed bet for the current betting cycle. If was none placed the last bet will be Number.NEGATIVE_INFINITY.
		 */
		public function get lastBet():Number 
		{
			return (_lastBet);
		}
		
		public function set lastBet(valueSet:Number):void 
		{
			_lastBet = valueSet;
		}
		
		/**
		 * True if the player is flagged as the current dealer.
		 */
		public function get isDealer():Boolean 
		{
			return (_isDealer);
		}
		
		public function set isDealer(valueSet:Boolean):void 
		{
			_isDealer = valueSet;
		}
		
		/**
		 * True if the player is flagged as the current big blind.
		 */
		public function get isBigBlind():Boolean 
		{
			return (_isBigBlind);
		}
		
		public function set isBigBlind(valueSet:Boolean):void 
		{
			_isBigBlind = valueSet;
		}
		
		/**
		 * True if the player is flagged as the current small blind.
		 */
		public function get isSmallBlind():Boolean 
		{
			return (_isSmallBlind);
		}
		
		public function set isSmallBlind(valueSet:Boolean):void 
		{
			_isSmallBlind = valueSet;
		}		
		
		/**
		 * True if the player has folded during the current round.
		 */
		public function get hasFolded():Boolean 
		{
			return (_hasFolded);
		}
		
		public function set hasFolded(valueSet:Boolean):void {
			_hasFolded = valueSet;
		}		
		
		/**
		 * True if player has committed a bet in this round of betting.
		 */
		public function get hasBet():Boolean 
		{			
			if (totalBet == Number.NEGATIVE_INFINITY) {
				return (false);
			}
			//are negative bets okay?
			return (true);
		}
		
		/**
		 * The number of bets committed by the player during the hand (usually updated by the poker
		 * betting module.
		 */
		public function get numBets():uint
		{
			return (_numBets);
		}
		
		public function set numBets(valueSet:uint):void
		{
			_numBets = valueSet;
		}
		
		/**
		 * The last highest result hand received from the player. This value is set at the end of a round and reset
		 * to null at the start of a new round.
		 */
		public function get lastResultHand():IPokerHand 
		{
			return (_lastResult);
		}
		
		public function set lastResultHand(resultSet:IPokerHand):void 
		{
			_lastResult = resultSet;
		}	
		
		/**
		 * The last received, fully encrypted comparison deck initiated (started) by this player during a re-keying
		 * operation.
		 */
		public function get comparisonDeck():Vector.<String> 
		{
			return (_comparisonDeck);
		}
		
		public function set comparisonDeck(deckSet:Vector.<String>):void
		{
			_comparisonDeck = deckSet;
		}
	}
}
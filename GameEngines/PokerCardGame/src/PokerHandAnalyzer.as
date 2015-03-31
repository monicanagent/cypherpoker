/**
* Analyzes 2 player/private + 5 (or fewer) community/public cards using supplied hand definitions.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package
{
	import interfaces.IPokerHand;
	import interfaces.IPokerHandAnalyzer;
	import org.cg.DebugView;
	import org.cg.interfaces.ICard;	
		
	public class PokerHandAnalyzer implements IPokerHandAnalyzer 
	{		
		private var _communityCards:Vector.<ICard>; //created in constructor
		private var _privateCards:Vector.<ICard>; //created in constructor
		private var _handDefinitions:XML; //created in constructor
		private var _hands:Vector.<IPokerHand> = new Vector.<IPokerHand>(); //list of hands, one per permutation
		//5 community cards hand permutations
		private static const _cPerms:Array = [[0, 1, 2],[1, 2, 3],[2, 3, 4],[0, 2, 3],[0, 3, 4],[1, 3, 4],[0, 1, 3],[0, 1, 4],[0, 2, 4]];
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	privateCards The private cards to include in the analysis.
		 * @param	communityCards The community cards to include in the analysis. 
		 * @param   handDefinitions XML data defining the hand combinations.
		 */
		public function PokerHandAnalyzer(privateCards:Vector.<ICard>, communityCards:Vector.<ICard>, handDefinitions:XML) 
		{
			_privateCards = privateCards;
			_communityCards = communityCards;
			_handDefinitions = handDefinitions;
			analyze();
		}
		
		/**
		 * A list of all of the analyzed 5-card hand combinations.
		 */
		public function get hands():Vector.<IPokerHand>
		{
			return (_hands);
		}
		
		/**
		 * The highest-ranking hand from all of the analyzed hands.
		 */
		public function get highestHand():IPokerHand 
		{
			var highestValue:int = int.MIN_VALUE;
			var highestHandFound:IPokerHand = null;
			for (var count:int = 0;  count < _hands.length; count++) {
				var currentHand:IPokerHand = _hands[count];				
				if (highestValue < currentHand.totalHandValue) {
					highestValue = currentHand.totalHandValue;
					highestHandFound = currentHand;
				}
			}
			return (highestHandFound);
		}		
		
		/**
		 * Analyzes the player+community cards using the supplied hand definitions.
		 */
		private function analyze():void 
		{
			if (_communityCards != null) {
				//create all permutations
				for (var count:int = 0; count < _cPerms.length; count++) {
					var currentPerm:Array = _cPerms[count] as Array;
					var newCommunitySet:Vector.<ICard> = new Vector.<ICard>();
					for (var count2:int = 0; count2 < currentPerm.length; count2++) {
						try {
							var currentCCard:ICard = _communityCards[currentPerm[count2] as Number]
							if (currentCCard!=null) {
								newCommunitySet.push(currentCCard);
							}
						} catch (err:*) {							
						}
					}
					_hands.push(new PokerHand(_privateCards, newCommunitySet, _handDefinitions));
				}
			}
			cleanup();
		}
		
		/**
		 * Cleans up the instance by clearing unused references.
		 */
		private function cleanup():void 
		{
			_privateCards = null;
			_communityCards = null;
		}
	}
}
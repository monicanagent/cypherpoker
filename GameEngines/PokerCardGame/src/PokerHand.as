/**
* Analyzes a sequence of 2 player/private cards and 3 community/public cards for the highest poker hand combination.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package  
{	
	import com.hurlant.crypto.symmetric.ICipher;
	import interfaces.IPokerHand;
	import org.cg.interfaces.ICard;
	import org.cg.DebugView;
	import p2p3.interfaces.IPeerMessage;

	public class PokerHand implements IPokerHand 
	{
		
		private static const _handPointsMultiplier:int = 1000000; //multiplies the points (in definition) when calculating totalHandValue
		private static const _matchMultiplier:int = 1000; //multiplies matched cards values when calculating totalHandValue
		private static const _noHandHighCardMultiplier:int = 20; //multiplies the highest private card when no matching hand includes private cards
		
		private var _privateCards:Vector.<ICard>; //set at instantiation in the constructor
		private var _communityCards:Vector.<ICard>; //set at instantiation in the constructor
		private var _handDefinitions:XML; //set at instantiation in the constructor
		private var _matchedHand:Vector.<ICard> = null; //entire matched hand
		private var _matchedDefinition:XML = null; //matched definition
		private var _matchedCards:Vector.<ICard> = null; //pattern match cards (others are high)
		private var _precomputedHandValue:int = int.MIN_VALUE; //stores the computed hand value once fully analyzed
		
		/**
		 * Creates a poker hand analysis instance.
		 * 
		 * @param	privateCards The private cards to include with the analysis.
		 * @param	communityCards The community cards, maximum 3, to include with the analysis.
		 * @param   handDefinitions XML settings data defining the possible hand combinations.
		 */
		public function PokerHand(privateCards:Vector.<ICard>, communityCards:Vector.<ICard>, handDefinitions:XML) 
		{
			if (communityCards != null) {
				if (communityCards.length > 3) {
					throw (new Error("Only 3 community cards allowed in constructor."));
				}
			}
			if ((privateCards!=null) && (communityCards!=null) && (handDefinitions!=null)) {
				_privateCards = privateCards;
				_communityCards = communityCards;
				_handDefinitions = handDefinitions;
				analyze();
			}
		}
		
		/**
		 * All the cards in the matched hand. A subset of these will be present in the matchedCards vector array.
		 */
		public function get matchedHand():Vector.<ICard>
		{
			return (_matchedHand);
		}
				
		/**
		 * All cards matching a multi-card group pattern. For example, if the winning hand was a three of a kind,
		 * the three matching cards are in this vector array. Only the highest card from the player's private 
		 * cards is included if no matches are found.
		 */
		public function get matchedCards():Vector.<ICard>
		{
			return (_matchedCards);
		}
		
		/**
		 * The XML definition for the matched hand.
		 */
		public function get matchedDefinition():XML
		{
			return (_matchedDefinition);
		}
		
		/**
		 * @return The points value defined for the matched definition, or int.MIN_VALUE if no match exists.
		 */
		public function get matchedHandPoints():int 
		{
			try {
				var pointVal:int = int(matchedDefinition.@points);
			} catch (err:*) {
				return (int.MIN_VALUE);
			}
			return (pointVal);
		}
		
		/**		 
		 * @return The total hand ranking value, calculated as:
		 *  (matched hand points * _handPointsMultiplier) + (matched card facevalue * _matchMultiplier) + card facevalue ...
		 *     If no private cards are matched, the lower of the two is subtracted.
		 *     This produces a ranking value that can be compared to other hands (larger hand values are more valuable).
		 */
		public function get totalHandValue():int 
		{
			if (_precomputedHandValue > int.MIN_VALUE) {
				return (_precomputedHandValue);
			}		
			if ((matchedHand == null) || (matchedHandPoints == int.MIN_VALUE)) {
				return (int.MIN_VALUE);
			}
			var returnValue:int = matchedHandPoints * _handPointsMultiplier;			
			var matchMultiplier:int = 1;
			for (var count:int = 0; count < matchedHand.length; count++) {
				var currentCard:ICard = matchedHand[count];
				if (isMatchedCard(currentCard)) {					
					matchMultiplier = _matchMultiplier;					
				} else {					
					matchMultiplier = 1;					
				}
				if (acesAreHigh && (currentCard.faceText == "ace") && isMatchedCard(currentCard)) {										
					returnValue+= (currentCard.faceValueHigh * matchMultiplier);										
				} else {					
					returnValue+= (currentCard.faceValue * matchMultiplier);					
				}
			}
			//assuming only two private cards
			if ((!isMatchedCard(_privateCards[0])) && (!isMatchedCard(_privateCards[1]))) {
				//no private cards were included in a match (highest hand is all public cards)
				if (_privateCards[0].faceValue > _privateCards[1].faceValue) {					
					returnValue += (_privateCards[0].faceValue * _noHandHighCardMultiplier) + _privateCards[1].faceValue;
				} else {
					returnValue += (_privateCards[1].faceValue * _noHandHighCardMultiplier) + _privateCards[0].faceValue;
				}				
			}
			_precomputedHandValue = returnValue;
			return (returnValue);
		}
		
		/**
		 * @return True if aces are scored using high point values (faceValueHigh) rather than normal 
		 * point values (faceValue). Default is false.
		 */
		public function get acesAreHigh():Boolean 
		{
			if (matchedDefinition == null) {
				return (false);
			}
			try {
				var highSetting:String = String(matchedDefinition.@aces);
				if ((highSetting == null) || (highSetting == "")) {
					return (false);
				} else {
					highSetting = highSetting.toLowerCase();
					highSetting = highSetting.split(" ").join("");
					if ((highSetting == "high") || (highSetting == "h")) {
						return (true);
					}
				}
			} catch (err:*) {
				return (false);	
			}
			return (false);
		}
		
		/**
		 * Populates the instance with data from a (usually) incoming peer message. Any existing data is overwritten.
		 * 
		 * @param	peerMessage The peer message to apply to the current instance, if valid.
		 * @param	gameRef A reference to the parent PokerCardGame instance.
		 */
		public function generateFromPeerMessage(peerMessage:IPeerMessage, gameRef:PokerCardGame):void 
		{
			/*
			 * peerMessage payload data:
			 * 
			 * Player's key chain:
			 * (keys array will grow every time a re-keying operation is completed) 
			 * 
			 * payload["keys"][#].encKey = key.encKeyHex;
			 * payload["keys"][#].decKey = key.decKeyHex
			 * payload["keys"][#].mod = key.modulusHex;							 
			 * 
			 * Player's highest hand (all cards):
			 * (hands array usually only has one element (index 0), but may contain other hand combinations in the future)
			 * 
			 * payload["hands"][#].fullHand[#].mapping -- the mapping (usually hex) string of the associated card. This is the plain text, "face up" value after decryption.
			 * payload["hands"][#].fullHand[#].cardName -- the human-friendly name of the card
			 * payload["hands"][#].fullHand[#].frontClassName -- the class name of the card face in the loaded card deck SWF (AceOfSpades, etc.)
			 * payload["hands"][#].fullHand[#].faceColor -- the card color name (red, black)
			 * payload["hands"][#].fullHand[#].faceText -- the card face text (nine, queen, etc.)
			 * payload["hands"][#].fullHand[#].faceValue -- the card face value (1 to 13)
			 * payload["hands"][#].fullHand[#].faceSuit -- the card face suit (spades, clubs, diamonds, hearts)
			 * 
			 * Player's highest hand (all cards within fullHand that match a winning pattern):								 
			 * 
			 * payload["hands"][#].matchedCards[#].mapping -- the mapping (usually hex) string of the associated card. This is the plain text, "face up" value after decryption.
			 * payload["hands"][#].matchedCards[#].cardName -- the human-friendly name of the card
			 * payload["hands"][#].matchedCards[#].frontClassName -- the class name of the card face in the loaded card deck SWF (AceOfSpades, etc.)
			 * payload["hands"][#].matchedCards[#].faceColor -- the card color name (red, black)
			 * payload["hands"][#].matchedCards[#].faceText -- the card face text (nine, queen, etc.)
			 * payload["hands"][#].matchedCards[#].faceValue -- the card face value (1 to 13)
			 * payload["hands"][#].matchedCards[#].faceSuit -- the card face suit (spades, clubs, diamonds, hearts)
			 * 
			 * Player's highest hand statistics:
			 * 
			 * payload["hands"][#].matchName -- The name of the player's highest hand
			 * payload["hands"][#].value -- The value of the player's highest hand (String)
			 * payload["hands"][#].rank -- The rank (as per XML data) of the player's highest hand (String)
			*/
			if ((peerMessage.data == null) || (peerMessage.data == "")) {
				return;
			}
			_handDefinitions = gameRef.settings["getSettingsCategory"]("hands");			
			var fullHand:Array = peerMessage.data.hands[0].fullHand;
			var matchedCards:Array = peerMessage.data.hands[0].matchedCards;			
			var handValue:int = int(peerMessage.data.hands[0].value);
			var handRank:int = int(peerMessage.data.hands[0].rank);
			_matchedHand = new Vector.<ICard>();
			for (var count:uint = 0; count < fullHand.length; count++) {
				var currentMapping:String =	String(fullHand[count].mapping);
				var cardRef:ICard = gameRef.currentDeck.getCardByMapping(currentMapping);
				_matchedHand.push(cardRef);
			}
			_matchedCards = new Vector.<ICard>();
			for (count = 0; count < matchedCards.length; count++) {
				currentMapping =	String(matchedCards[count].mapping);
				cardRef = gameRef.currentDeck.getCardByMapping(currentMapping);
				_matchedCards.push(cardRef);
			}
			_precomputedHandValue = handValue;
			_matchedDefinition=getHandDefByRank(handRank);
		}		
		
		/**
		 * Produces a human-readable summary of the analyzed and ranked hand.
		 * 
		 * @return A human-readable hand summary.
		 */
		public function toString():String 
		{
			var returnString:String = new String();
			try {
				returnString = "Highest hand : " + matchedDefinition.@name+"\n";
				returnString += "Matching cards in hand : ";
				returnString = returnString.substr(0, returnString.length - 1);
				for (var count:int = 0; count < matchedCards.length; count++) {
					var currentCard:ICard = matchedCards[count];
					returnString += currentCard.cardName+",";
				}
				returnString = returnString.substr(0, returnString.length - 1);
				returnString += "\n";
				returnString += "All cards in hand : ";
				for (count = 0; count < matchedHand.length; count++) {
					currentCard = matchedHand[count];
					returnString += currentCard.cardName+",";
				}
				returnString = returnString.substr(0, returnString.length - 1);
				returnString += "\n";
				returnString += "Total hand value: " + totalHandValue;
			} catch (err:*) {
				returnString = "Poker hand not yet analyzed or there was an error during analysis.";				
			} finally {
				return (returnString);
			}
		}
		
		/**
		 * @return The highest rank value found in the XML definition.
		 */
		private function get highestRank():int 
		{
			var rankNodes:XMLList = _handDefinitions.children();
			var highestRank:int = int.MIN_VALUE;
			for (var count:int = 0; count < rankNodes.length(); count++) {
				var currentNode:XML = rankNodes[count];
				try {
					var rankValue:int = int(currentNode.@rank);
					if (rankValue > highestRank) {
						highestRank = rankValue;
					}
				} catch (err:*) {
				}
			}
			return (highestRank);
		}
		
		/**
		 * Analyzes and ranks the supplied cards against the supplied definition.
		 */
		private function analyze():void
		{			
			//try the highest ranked definitions first
			var currentRank:int = highestRank;
			var handDefinition:XML = getHandDefByRank(currentRank);
			//internal data is assigned during analysis so not much need to happen here
			if (handMatchesDefinition(handDefinition)) {								
				return;
			}
			while (currentRank > 0) {
				currentRank--;
				handDefinition = getHandDefByRank(currentRank);				
				if (handDefinition != null) {					
					if (handMatchesDefinition(handDefinition)) {						
						return;
					}
				}
			}
			DebugView.addText("No hand found. Something went wrong :(");
		}		
		
		/**
		 * Verifies if the supplied card is a matched card (in the matchedCards array).
		 * 
		 * @param	cardRef The ICard implementation to check.
		 * 
		 * @return True if the supplied card is a matched card.
		 */
		private function isMatchedCard(cardRef:ICard):Boolean 
		{			
			for (var count:int = 0; count < matchedCards.length; count++) {
				if (cardRef == matchedCards[count]) {
					return (true);
				}
			}
			return (false);
		}				
		
		/**
		 * Checks if the current player+community cards match a supplied <hand> definition.
		 * 
		 * @param	def The <hand> node to check against.
		 * 
		 * @return True if the current player+community cards match the definition.
		 */
		protected function handMatchesDefinition(def:XML):Boolean 
		{
			var workCards:Vector.<ICard> = new Vector.<ICard>();
			for (var count:int = 0; count < _privateCards.length; count++) {
				workCards.push(_privateCards[count]);
			}
			for (count = 0; count < _communityCards.length; count++) {
				workCards.push(_communityCards[count]);
			}
			try {
				var sortByDef:String = String(def.@sort);
				if ((sortByDef == null) || (sortByDef == "")) {
					sortByDef = "no";
				}
			} catch (err:*) {
				sortByDef = "no";
			}			
			workCards = sortBy(sortByDef, workCards);			
			var initialGroupby:String = String(def.@groupby);
			var resultGroups:Array = groupBy(initialGroupby, workCards); //would an object return be better?			
			var match:String = String(def.@match);
			_matchedHand = combineGroups(resultGroups);	
			_matchedDefinition = def;
			_matchedCards = filterMatchedCards(resultGroups);
			if (match == "*") {
				return (true);
			}			
			if (matchesPattern(match, resultGroups)) {				
				return (true);
			}
			_matchedHand = null;
			_matchedDefinition = null;	
			_matchedCards = null;
			return (false);
		}
		
		/**
		 * Produces a vector array out of a multi-dimensional matched card groups object.
		 * 
		 * @param	groups A multi-dimensional matched card groups object as created by a groupBy operation.
		 * 
		 * @return A Vector array containing only the matched hand cards.
		 */
		protected function filterMatchedCards(groups:Array):Vector.<ICard> 
		{
			if (groups == null) {
				return(null);
			}
			var returnCards:Vector.<ICard> = new Vector.<ICard>();
			var totalLength:int = _communityCards.length + _privateCards.length;
			//a 5-length group (flush, for example) will have only 1 element so this evaluation is true on high cards (lowest rank)
			if (lengthOf(groups) == totalLength) {
				//high card (no pattern)
				var highestValue:int=int.MIN_VALUE;
				var highestReturnCard:ICard = null;
				for (var count:int = 0; count < _privateCards.length; count++) {
					var currentCard:ICard = _privateCards[count];
					//defaults to faceValue if not defined so it can be used safely
					if (currentCard.faceValueHigh > highestValue) {
						highestValue = currentCard.faceValueHigh;
						highestReturnCard = currentCard;
					}
				}				
				returnCards.push(highestReturnCard);	
			} else {
				//include only cards in groups of 2 or more (matched)
				for (var item:* in groups) {
					var currentGroup:Array = groups[item] as Array;
					if (lengthOf(currentGroup)>1) {
						for (var item2:* in currentGroup) {						
							returnCards.push(currentGroup[item2] as ICard);	
						}
					}
				}
			}
			return (returnCards);	
		}
		
		/**
		 * Checks if a supplied multi-dimensional matched card groups object matches a specific multi-match pattern.
		 * 
		 * @param	match A pattern against which to verify, such as the "match" attribute of a <hand> node. Individual
		 * match specifications are separated by ";".
		 * @param	cardGroups A multi-dimensional card group object such as created by the groupBy function.
		 * 
		 * @return True if the matched card groups object matches the supplied multi-match pattern.
		 */
		protected function matchesPattern(match:String, cardGroups:Array):Boolean 
		{			
			var matchGroups:Array = match.split(";");
			var matchCount:int = 0;
			for (var item:* in cardGroups) {
				var matchGroup:String = matchGroups[matchCount] as String;
				var cardGroup:Array = cardGroups[item] as Array;				
				if (!matchesGroup(matchGroup, cardGroup)) {
					return (false);
				}
				matchCount++;
			}
			return (true);
		}
		
		/**
		 * Used by matchesPattern to determine if a match group (separated by ";") matches a single card group.
		 * 
		 * @param	matchPattern The individual pattern to match against.
		 * @param	cardGroup The individual card group to match with.
		 * 
		 * @return True if the group matches the supplied pattern.
		 */
		protected function matchesGroup(matchPattern:String, cardGroup:Array):Boolean 
		{
			if ((matchPattern == null) || (cardGroup == null)) {
				return (false);
			}
			var patternSplit:Array = matchPattern.split(":");
			var groupByParam:String = patternSplit[0] as String;
			groupByParam = groupByParam.toLowerCase();
			var groupByFilter:String = patternSplit[1] as String;
			var groupByFilterItems:Array = groupByFilter.split(",");
			var groupByFilterCount:int = 0;
			for (var item:* in cardGroup) {
				var currentCard:ICard = cardGroup[item] as ICard;				
				var currentFilterItem:String = groupByFilterItems[groupByFilterCount] as String;				
				switch (groupByParam) {
					case "facetext":
						if ((currentCard.faceText != currentFilterItem) && (currentFilterItem != "*")) {
							return (false);
						}
						break;
					default:
						break;
				}				
				groupByFilterCount++;
			}
			return (true);
		}
		
		/**
		 * Sorts a list of cards by a specified sort type based on their faceValue.
		 * 
		 * @param	sortByType The sort by operation type to use, either "asc" for ascending or "des" for descending.
		 * @param	workCards The cards to sort.
		 * 
		 * @return A faceValue-sorted list of cards. The original workCards list is unaffected.
		 */
		protected function sortBy(sortByType:String, workCards:Vector.<ICard>):Vector.<ICard> 
		{			
			sortByType = sortByType.toLowerCase();			
			var returnCards:Vector.<ICard> = new Vector.<ICard>();
			switch (sortByType) {
				case "asc" :
					for (var count:Number = 1; count <= 13; count++) {
						for (var count2:int = 0; count2 < workCards.length; count2++) {
							var currentCard:ICard = workCards[count2];							
							if (currentCard.faceValue == count) {
								returnCards.push(currentCard);
							}							
						}						
					}					
					return (returnCards);
					break;
				case "des" :
					for (count = 13; count >= 1; count--) {
						for (count2 = 0; count2 < workCards.length; count2++) {
							currentCard = workCards[count2];
							if (currentCard.faceValue == count) {
								returnCards.push(currentCard);
							}							
						}						
					}
					return (returnCards);
					break;
				default:
					for (count = 0; count < workCards.length; count++) {
						returnCards.push(workCards[count]);
					}
					return (returnCards);
					break;
			}
			return (returnCards);
		}
		
		/**
		 * Combines the cards in a multi-dimensional groups object into a single Vector array of cards.
		 * 
		 * @param	groups The mutli-dimensional matched groups object, such as created by groupBy, to combine.
		 * 
		 * @return The combined list of cards.
		 */
		protected function combineGroups(groups:Array):Vector.<ICard>
		{
			var returnCards:Vector.<ICard> = new Vector.<ICard>();
			//card groups are not numerically indexed
			for (var item:* in groups) {
				var currentGroup:Array = groups[item] as Array;								
				for (var item2:* in currentGroup) {
					returnCards.push(currentGroup[item2] as ICard);					
				}				
			}			
			return (returnCards);
		}		
		
		/**
		 * Creates a multi-dimensional object of grouped cards from a list of cards and a grouping definition.
		 * 
		 * @param	groupByType The type of grouping to apply to the work cards. Current types include "suit",
		 * "facevalue", "facetext", "color", "class", and "name" (the attributes defined in each card's node).
		 * @param	workCards The work cards to group.
		 * 
		 * @return A multi-dimensional object containing the grouped cards.
		 */
		protected function groupBy(groupByType:String, workCards:Vector.<ICard>):Array 
		{
			groupByType = groupByType.toLowerCase();			
			switch (groupByType) {
				case "suit":
					var groups:Array = new Array();
					for (var count:int = 0; count < workCards.length; count++) {
						var currentCard:ICard = workCards[count];
						var currentSuit:String = currentCard.faceSuit;
						if ((groups[currentSuit] == null) || (groups[currentSuit] == undefined) || (groups[currentSuit] == "")) {
							groups[currentSuit] = new Array();							
						}						
						groups[currentSuit].push(currentCard);
					}					
					return (groups);
					break;
				case "facevalue":
					groups = new Array();
					for (count = 0; count < workCards.length; count++) {
						currentCard = workCards[count];
						var currentFaceValue:String = String(currentCard.faceValue); //better to treat as string index
						if ((groups[currentFaceValue] == null) || (groups[currentFaceValue] == undefined) || (groups[currentFaceValue] == "")) {
							groups[currentFaceValue] = new Array();							
						}
						groups[currentFaceValue].push(currentCard);
					}					
					return (groups);
					break;					
				case "facetext":
					groups = new Array();
					for (count = 0; count < workCards.length; count++) {
						currentCard = workCards[count];
						var currentFaceText:String = currentCard.faceText;
						if ((groups[currentFaceText] == null) || (groups[currentFaceText] == undefined) || (groups[currentFaceText] == "")) {
							groups[currentFaceText] = new Array();							
						}
						groups[currentFaceText].push(currentCard);
					}					
					return (groups);
					break;
				case "color":
					groups = new Array();
					for (count = 0; count < workCards.length; count++) {
						currentCard = workCards[count];
						var currentFaceColor:String = currentCard.faceColor;
						if ((groups[currentFaceColor] == null) || (groups[currentFaceColor] == undefined) || (groups[currentFaceColor] == "")) {
							groups[currentFaceColor] = new Array();							
						}
						groups[currentFaceColor].push(currentCard);
					}					
					return (groups);
					break;
				case "class":
					groups = new Array();
					for (count = 0; count < workCards.length; count++) {
						currentCard = workCards[count];
						var currentClassName:String = currentCard.frontClassName;
						if ((groups[currentClassName] == null) || (groups[currentClassName] == undefined) || (groups[currentClassName] == "")) {
							groups[currentClassName] = new Array();							
						}
						groups[currentClassName].push(currentCard);
					}					
					return (groups);
					break;
				case "name":
					groups = new Array();
					for (count = 0; count < workCards.length; count++) {
						currentCard = workCards[count];
						var currentCardName:String = currentCard.cardName;
						if ((groups[currentCardName] == null) || (groups[currentCardName] == undefined) || (groups[currentCardName] == "")) {
							groups[currentCardName] = new Array();							
						}
						groups[currentCardName].push(currentCard);
					}					
					return (groups);
					break;
				case "*":
					groups = new Array();
					groups["0"] = new Array();
					for (count = 0; count < workCards.length; count++) {
						currentCard = workCards[count];
						groups["0"].push(currentCard);
					}					
					return (groups);
					break;
				default:
					groups = new Array();					
					for (count = 0; count < workCards.length; count++) {
						groups[String(count)] = new Array();
						groups[String(count)].push(workCards[count]);
					}
					return (groups);
					break;										
			}
			return (null);
		}		
		
		/**
		 * Returns a hand definition based on a specified rank value.
		 * 
		 * @param	rank The rank value for which to retrieve the matching hand definition.
		 * 
		 * @return The matching hand definition or null if none can be found.
		 */
		protected function getHandDefByRank(rank:int):XML 
		{
			var definitions:XMLList = _handDefinitions.children();			
			for (var count:int = 0; count < definitions.length(); count++) {
				var currentDef:XML = definitions[count] as XML;
				try {
					var rankValue:int = int(currentDef.@rank);
				} catch (err:*) {
					rankValue = -1;
				}
				if (rankValue == rank) {
					return (currentDef);
				}
			}
			return (null);
		}
		
		/**
		 * Returns the length of any array or object type.
		 * 
		 * @param	arrayVal Any array or object type.
		 * 
		 * @return The number of enumerable top-level properties of the array or object.
		 */
		protected static function lengthOf(arrayVal:Object):int 
		{
			var count:int = 0;
			for (var item:* in arrayVal) 
				count++;
			return (count);
		}		
	}
}
/**
* Interface for PokerHand and related instances.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
package interfaces {
	
	import org.cg.interfaces.ICard;
	
	public interface IPokerHand {
		//All of the cards in the poker hand. Not all produce a match.
		function get matchedHand():Vector.<ICard>;
		//The cards that match a pattern definition to produce a point score.
		function get matchedCards():Vector.<ICard>;
		//The XML definition for the matched pattern.
		function get matchedDefinition():XML;
		//The points defined in the XML data for the pattern match.
		function get matchedHandPoints():int;
		//True if aces are considered high for point scoring, otherwise their defined low value is used.
		function get acesAreHigh():Boolean;
		//The total point score generated for the matched pattern based on definition and card data.
		function get totalHandValue():int;
	}	
}
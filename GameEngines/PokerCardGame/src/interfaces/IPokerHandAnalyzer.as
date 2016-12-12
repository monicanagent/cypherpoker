/**
* Interface for PokerHandAnalyzer and related instances.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package interfaces {	
	
	import interfaces.IPokerHand;
	
	public interface IPokerHandAnalyzer {
		//A list of all the hand combinations analyzed by the instance.
		function get hands():Vector.<IPokerHand>
		//The highest poker hand found by the instance.
		function get highestHand():IPokerHand;
	}	
}
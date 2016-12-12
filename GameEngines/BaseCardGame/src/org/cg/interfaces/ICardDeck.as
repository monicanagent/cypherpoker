/**
* Interface for a card deck implementation.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {	
	
	import org.cg.interfaces.ICard;
	
	public interface ICardDeck 	{
		
		//True if deck data has been parsed, all assets loaded, and deck is ready for use.
		function get ready():Boolean;
		//Retrieves an ICard implementation by an index value, as specidied in the XML configuration data.
		function getCardByIndex(index:uint):ICard;
		//Retrieves an ICard implementation by a class name, as specidied in the XML configuration data.
		function getCardByClass(className:String):ICard;
		//Retrieves an ICard implementation by a plaintext mapping (the value which is encrypted during card operations).
		function getCardByMapping(mapping:String):ICard;
		//Retrieves a plaintext mapping by an ICard implementation.
		function getMappingByCard(cardRef:ICard):String;
		//Maps a plaintext value to a specified ICard implementation.
		function mapCard(mapping:String, cardRef:ICard):void;
		//The class used as the card back for all cards in the deck (must instantiate to a DisplayObject).
		function get cardBackClass():Class;
		//Returns a duplicate of the mappings data of the current deck. Each object should contain a plaintext "mapping" property and a reference
		//to a matching ICard implementation.
		function duplicateCardMap():Vector.<Object>;
		//Resets all card mappings. Other card properties remain untouched.
		function resetCardMappings():void;
		//Returns all the cards instantiated by the implementation.
		function get allCards():Vector.<ICard>;
		//The number of cards defined for the deck.
		function get size():uint;
	}
}
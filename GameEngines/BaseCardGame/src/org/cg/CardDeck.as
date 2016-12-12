/**
* Manages and manipulates a card deck (instances of ICard implementations).
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {	
	
	import org.cg.interfaces.ICardDeck;
	import org.cg.interfaces.ICard;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.system.LoaderContext;
	import org.cg.GameSettings;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.net.URLRequest;	
	import flash.system.Security;
	import flash.system.ApplicationDomain
	import flash.events.IOErrorEvent;
	import flash.events.Event;
	import flash.utils.getDefinitionByName;
	import flash.filters.DropShadowFilter;	
	
	public class CardDeck implements ICardDeck 	{
		
		private var _deckLoader:Loader; //loads the card faces as a SWF
		private var _deckDefinition:XML; //the XML definition of the card deck
		private var _deckName:String = null; //descriptive name of the deck
		private var _cardBackName:String = null; //name of the card back class
		private var _cardBackClass:Class = null; //card back class
		private var _onCreateCB:Function; //callback invoked when card back is created
		private var _ready:Boolean = false; //true when deck has been loaded and initialized
		private var _cards:Vector.<ICard> = new Vector.<ICard>(); //generated cards
		private var _cardMap:Vector.<Object> = new Vector.<Object>(); //card mappings (contains .mapping and .card values)
				
		/**
		 * Create an instance of CardDeck.
		 * 
		 * @param	gameSettingsDeckName The deck name, as specified in the settings, to generate.
		 * @param	cardBackName The name of the card back definition to use when generating the deck.
		 * @param	onCreateCB Callback function to invoke when deck has been loaded and initialized.
		 */
		public function CardDeck(gameSettingsDeckName:String, cardBackName:String, onCreateCB:Function) {			
			_deckName = gameSettingsDeckName;
			_cardBackName = cardBackName;
			_onCreateCB = onCreateCB;
			loadDeck(gameSettingsDeckName);			
		}
				
		/**
		 * @return True if the deck has been fully loaded and initialized.
		 */
		public function get ready():Boolean {
			return (_ready);
		}
		
		/**
		 * Retrieves a card by its index in the generated cards Vector array.
		 * 
		 * @param	index The index of the card instance to retrieve.
		 * 
		 * @return The retrieved card instance or null if none exists.
		 */
		public function getCardByIndex(index:uint):ICard {
			try {
				var rCard:ICard = _cards[index];
				return (rCard);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Finds a card instance by a specified front face class name.
		 * 
		 * @param className The card front face class name to find.
		 * 
		 * @return A card instance or null if no matching card was found.
		 */
		public function getCardByClass(className:String):ICard {
			for (var count:uint = 0; count < _cards.length; count++) {
				var currentCard:ICard = _cards[count];				
				if (currentCard.frontClassName == className) {
					return (currentCard);
				}
			}
			return (null);
		}
		
		/**
		 * Finds a card instance by a specified plaintext mapping.
		 * 
		 * @param mapping A plaintext mapping (the value that's encrypted), to find a matching card for.
		 * 
		 * @return A card instance or null if no matching card was found.
		 */
		public function getCardByMapping(mapping:String):ICard {			
			for (var count:uint = 0; count < _cardMap.length; count++) {
				var ccObject:Object = _cardMap[count];				
				if (ccObject.mapping == mapping) {
					return (ccObject.card as ICard);
				}
			}
			return (null);
		}
		
		/**
		 * Finds a plaintext card mapping (the value that's encrypted) by a specified card instance.
		 * 
		 * @param	cardRef The card instance to find a plaintext card mapping for.
		 * 
		 * @return The card mapping for the instance or null if no match can be found.
		 */
		public function getMappingByCard(cardRef:ICard):String {
			for (var count:uint = 0; count < _cardMap.length; count++) {
				var ccObject:Object = _cardMap[count];				
				if (ccObject.card == cardRef) {
					return (ccObject.mapping);
				}
			}
			return (null);
		}
		
		/**
		 * Associates a card instance with a plaintext mapping value. Any existing mapping will be overwritten.
		 * 
		 * @param	mapping A plaintext mapping (the value that's encypted) to associate with the card instance.
		 * @param	cardRef A card instance to associate with the plaintext mapping.
		 */
		public function mapCard(mapping:String, cardRef:ICard):void {
			if ((mapping == null) || (cardRef == null)) {
				return;
			}
			for (var count:uint = 0; count < _cardMap.length; count++) {
				var ccObject:Object = _cardMap[count];				
				if (ccObject.card == cardRef) {
					ccObject.mapping = mapping;
					return;
				}
			}
			var newCCObject:Object = new Object();
			newCCObject.mapping = mapping;
			newCCObject.card = cardRef;
			_cardMap.push(newCCObject);
		}		
		
		/**
		 * Resets the plaintext card mappings for the deck. Other card data is maintained.
		 */
		public function resetCardMappings():void {
			_cardMap = new Vector.<Object>();
		}
		
		/**
		 * Duplicates the current card deck, including all of the card values and mappings. Each object
		 * in the vector array contains a plaintext "mapping" property along with an associated "card"
		 * reference which points to an ICard implementation.
		 */
		public function duplicateCardMap():Vector.<Object> {
			var returnMap:Vector.<Object> = new Vector.<Object>();
			for (var count:int = 0; count < this._cardMap.length; count++) {
				returnMap.push(_cardMap[count]);
			}
			return (returnMap);
		}
		
		/**
		 * @return A DisplayObject type class to use for each card's back face, as specified in the settings.
		 */
		public function get cardBackClass():Class {
			if (_cardBackClass==null) {			
				var backsNode:XML = GameSettings.getSettingsCategory("cardbacks");
				var backsList:XMLList = backsNode.children();
				for (var count:uint = 0; count < backsList.length(); count++) {
					var currentNode:XML = backsList[count] as XML;
					var currentName:String = new String(currentNode.@name);					
					if (_cardBackName == currentName) {
						var currentClassName:String = new String(currentNode.attribute("class")[0]);					
						try {
							_cardBackClass = getDefinitionByName(currentClassName) as Class;							
						} catch (err:*) {							
						}
					}
				}
			}
			return (_cardBackClass);
		}	
		
		/**
		 * @return The size of the generated deck. May not necessairly match the definition.
		 */
		public function get size():uint {
			return (_cards.length);
		}
		
		/**
		 * @return Returns a vector array of all the cards defined for this deck instance.
		 */
		public function get allCards():Vector.<ICard> {
			return (_cards);
		}
		
		/**
		 * Generates the card instances once all assets have been loaded and initialized.
		 */
		private function generateCards():void {	
			trace ("CardDeck.generateCards");
			var cardList:XMLList = _deckDefinition.children();
			for (var count:uint = 0; count < cardList.length(); count++) {
				var currentCardDef:XML = cardList[count] as XML;
				var cardFrontClassName:String = currentCardDef.attribute("class")[0];				
				try {
					var cardFront:Class = getDefinitionByName(cardFrontClassName) as Class;
					var cardBack:Class = cardBackClass;					
					var newCard:Card = new Card(cardFront, cardBack, currentCardDef);
					_cards.push(newCard);
				} catch (err:*) {
					DebugView.addText(err);
				}
			}
		}
		
		/**
		 * Handles a successful deck assets load operation.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private function onLoadDeck(eventObj:Event):void {			
			_deckLoader.contentLoaderInfo.removeEventListener(Event.COMPLETE, onLoadDeck);
			_deckLoader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onLoadDeckError);
			generateCards();
			_ready = true;
			_onCreateCB(this);	
			_onCreateCB = null;
		}
		
		/**
		 * Handles IOErrorEvent events during a deck assets load operation.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private function onLoadDeckError(eventObj:IOErrorEvent):void {
			DebugView.addText ("CardDeck.onLoadDeckError: " + eventObj.toString());
			_deckLoader.contentLoaderInfo.removeEventListener(Event.COMPLETE, onLoadDeck);
			_deckLoader.contentLoaderInfo.removeEventListener(IOErrorEvent.IO_ERROR, onLoadDeckError);			
		}
		
		/**
		 * Begins loading of a specified deck.
		 * 
		 * @param	deckName The name of the deck as specified in the definition data.
		 */
		private function loadDeck(deckName:String):void {	
			DebugView.addText ("CardDeck.loadDeck: "+deckName);
			var deckDef:XML = GameSettings.getSettingsCategory("cards");						
			var deckDefinitions:XMLList = deckDef.children();			
			var foundDef:XML = null;
			for (var count:uint = 0; count < deckDefinitions.length(); count++) {
				var currentDef:XML = deckDefinitions[count] as XML;
				var currentName:String = String(currentDef.@name);
				if (currentName == deckName) {
					foundDef = currentDef;
					break;
				}
			}			
			if (foundDef == null) {
				return;
			}
			_deckDefinition = foundDef;
			var deckFilePath:String = new String(_deckDefinition.@src);
			DebugView.addText ("   Deck path: "+deckFilePath);
			var request:URLRequest = new URLRequest(deckFilePath);
			try {
				Security.allowDomain("*");
				Security.allowInsecureDomain("*");
			} catch (err:*) {				
			}
			_deckLoader = new Loader();
			_deckLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadDeck);
			_deckLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onLoadDeckError);
			_deckLoader.load(request, new LoaderContext(false, ApplicationDomain.currentDomain));
		}
	}
}
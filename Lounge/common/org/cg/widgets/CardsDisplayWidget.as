/**
* Manages the main display of card within the game.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
	
	import org.cg.interfaces.ICard;
	import org.cg.Card;
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.IWidget;
	import org.cg.StarlingContainer;
	import events.PokerGameStatusEvent;
	import starling.display.Sprite;
	import org.cg.DebugView;
	
	public class CardsDisplayWidget extends Widget implements IWidget {
		
		
		public var publicX:Number = 0;
		public var publicY:Number = 0;
		public var privateX:Number = 0;
		public var privateY:Number = 200;
		public var privateScale:Number = 1;
		public var publicScale:Number = 0.8;
		public var publicAlign:String = "horizontal"; //or "vertical"
		public var privateAlign:String = "horizontal"; //or "vertical"
		public var publicSpacing:Number = 20; //space between cards, in pixels
		public var privateSpacing:Number = 20;
		public var fadeInSpeed:Number = 1; //how quickly to fade in a card when it's first shown, in seconds
		public var flipSpeed:Number = 1; //how quickly to play the card's "flip" animation after showing it
		public var revealDelay:Number = 500; //delay when revealing successive cards in groups, in milliseconds
		
		private var _publicCardContainer:Sprite;
		private var _privateCardContainer:Sprite;
		private var _privateCards:Vector.<Card> = new Vector.<Card>();
		private var _publicCards:Vector.<Card> = new Vector.<Card>();
		
		public function CardsDisplayWidget(loungeRef:ILounge, containerRef:*, widgetData:XML) {
			DebugView.addText ("CardsDisplayWidget created.");
			super(loungeRef, containerRef, widgetData);
			
		}
		
		private function get privateCardsWidth():Number {
			var returnWidth:Number = 0;
			for (var count:int = 0; count < this._privateCards.length; count++) {
				returnWidth += this._privateCards[count].width + privateSpacing;
				var spaceAdjust:Number = (this._privateCards[count].width * privateScale) - this._privateCards[count].width;
				returnWidth += spaceAdjust;
			}
			return (returnWidth);
		}
		
		private function get privateCardsHeight():Number {
			var returnHeight:Number = 0;
			for (var count:int = 0; count < this._privateCards.length; count++) {
				returnHeight += this._privateCards[count].height + privateSpacing;
				var spaceAdjust:Number = (this._privateCards[count].width * privateScale) - this._privateCards[count].width;
				returnHeight += spaceAdjust;
			}
			return (returnHeight);
		}
		
		private function get publicCardsWidth():Number {
			var returnWidth:Number = 0;
			for (var count:int = 0; count < this._publicCards.length; count++) {
				returnWidth += this._publicCards[count].width + publicSpacing;
				var spaceAdjust:Number = (this._publicCards[count].width * publicScale) - this._publicCards[count].width ;
				returnWidth += spaceAdjust;
			}
			return (returnWidth);
		}
		
		private function get publicCardsHeight():Number {
			var returnHeight:Number = 0;
			for (var count:int = 0; count < this._publicCards.length; count++) {
				returnHeight += this._publicCards[count].height + (publicSpacing * publicScale);
				var spaceAdjust:Number = (this._publicCards[count].width * publicScale) - this._publicCards[count].width ;
				returnHeight += spaceAdjust;
			}
			return (returnHeight);
		}
		
		private function showNewPrivateCards(eventObj:PokerGameStatusEvent):void {			
			for (var count:int = 0; count < eventObj.info.cards.length; count++) {
				var newCard:Card = eventObj.info.cards[count] as Card;
				this._privateCardContainer.addChild(newCard);
				if (privateAlign.toLowerCase() == "vertical") {
					newCard.y = privateCardsHeight;
				} else {
					newCard.x = privateCardsWidth;
				}
				newCard.scale = privateScale;				
				newCard.fadeIn(fadeInSpeed);
				newCard.flip(true, flipSpeed/2, flipSpeed/2, count * revealDelay);
				this._privateCards.push(newCard);
			}
		}
		
		private function showNewPublicCards(eventObj:PokerGameStatusEvent):void {
			DebugView.addText ("showNewPublicCards");
			for (var count:int = 0; count < eventObj.info.cards.length; count++) {
				var newCard:Card = eventObj.info.cards[count] as Card;
				this._publicCardContainer.addChild(newCard);
				if (publicAlign.toLowerCase() == "vertical") {
					newCard.y = publicCardsHeight;
				} else {
					newCard.x = publicCardsWidth;
				}
				newCard.scale = publicScale;
				newCard.fadeIn(fadeInSpeed);
				newCard.flip(true, flipSpeed/2, flipSpeed/2, count * revealDelay);
				this._publicCards.push(newCard);
			}
		}
		
		private function onClearCards(eventObj:PokerGameStatusEvent):void {
			if (eventObj == null) {
				eventObj = new PokerGameStatusEvent(PokerGameStatusEvent.CLEAR_CARDS);
				eventObj.info = new Object();
				eventObj.info.hole = true;
				eventObj.info.community = true;
			}
			if (eventObj.info.hole) {
				for (var count:int = 0; count < this._privateCards.length; count++) {
					var card:Card = this._privateCards[count];
					this._privateCardContainer.removeChild(card);
				}
				this._privateCards = new Vector.<Card>();
			}
			if (eventObj.info.community) {
				for (count = 0; count < this._publicCards.length; count++) {
					card = this._publicCards[count];
					this._publicCardContainer.removeChild(card);
				}
				this._publicCards = new Vector.<Card>();
			}
		}
		
		private function onGameDestroy(eventObj:PokerGameStatusEvent):void {				
			this.destroy();
		}
		
		override public function destroy():void {
			this.lounge.games[0].removeEventListener(PokerGameStatusEvent.DECRYPTED_PRIVATE_CARDS, this.showNewPrivateCards);
			this.lounge.games[0].removeEventListener(PokerGameStatusEvent.DECRYPTED_PUBLIC_CARDS, this.showNewPublicCards);
			this.lounge.games[0].removeEventListener(PokerGameStatusEvent.CLEAR_CARDS, this.onClearCards);
			this.lounge.games[0].removeEventListener(PokerGameStatusEvent.DESTROY, this.onGameDestroy);
			this.onClearCards(null);
			this.removeChild(this._privateCardContainer);
			this.removeChild(this._publicCardContainer);
			this._privateCards = null;
			this._publicCards = null;
			super.destroy();
		}
		
		override public function initialize():void {
			DebugView.addText ("CardsDisplayWidget initialize.");
			this._publicCardContainer = new Sprite();
			this._privateCardContainer = new Sprite();
			StarlingContainer.instance.addChild(this._publicCardContainer);
			StarlingContainer.instance.addChild(this._privateCardContainer);
			this._publicCardContainer.x = publicX;
			this._publicCardContainer.y = publicY;
			this._privateCardContainer.x = privateX;
			this._privateCardContainer.y = privateY;			
			this.lounge.games[0].addEventListener(PokerGameStatusEvent.DECRYPTED_PRIVATE_CARDS, this.showNewPrivateCards);
			this.lounge.games[0].addEventListener(PokerGameStatusEvent.DECRYPTED_PUBLIC_CARDS, this.showNewPublicCards);
			this.lounge.games[0].addEventListener(PokerGameStatusEvent.CLEAR_CARDS, this.onClearCards);
			this.lounge.games[0].addEventListener(PokerGameStatusEvent.DESTROY, this.onGameDestroy);
			super.initialize();
		}
	}
}
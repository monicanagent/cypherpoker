/**
* Manages a single card instance. Usually instantiated by a CardDeck instance.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg 
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.net.URLRequest;	
	import org.cg.interfaces.ICard;
	import flash.display.MovieClip;	
	import flash.display.Sprite;
	import flash.display.Loader;
	import flash.display.DisplayObject;
	import flash.geom.Point;
	import flash.events.Event;	
	import org.cg.events.CardEvent;
	import flash.utils.getQualifiedClassName;	
	import flash.utils.getDefinitionByName;	
	import flash.utils.Timer;
	import flash.events.TimerEvent;
	import flash.utils.setTimeout;	
	
	dynamic public class Card extends MovieClip implements ICard 
	{
		
		protected var _cardFront:Class; //A DisplayObject descendant used for the card front face.
		protected var _cardBack:Class; //A DisplayObject descendant used for the card front face.		
		protected var _cardContainer:MovieClip; //Container for the card faces.		
		protected var _cardDefinition:XML; //XML definition for the card.
		protected var _cardFrontSprite:Sprite; //Instantiated from _cardFront
		protected var _cardBackSprite:Sprite; //Instantiated from _cardBack
		protected var _faceUp:Boolean = false; //Is card face-up?
		protected var _fadeTimer:Timer; //Used during fade-up/down operations.
		private var _flipTimer:Timer; //Used during card "flip" operations.
		private var _flipAlphaInc:Number; //alpha increment value to use during flip fade in
		private var _flipAlphaDec:Number; //alpha decrement value to use during flip fade out
		private var _flipFadeOut:Boolean = true; //"flip" animation is currently fading out if true, fading in if false
		protected var _fadeInc:Number; //Current fade increment value based on desired duration.
		protected var _fadeUp:Boolean; //True=up, false=down.
		protected var _flipFaceUp:Boolean; //True=face up, false=face down.
	
		
		/**
		 * Creates a Card instance.
		 * 
		 * @param	cardFront A DisplayObject descendant to instantiate and use for the card front.
		 * @param	cardBack A DisplayObject descendant to instantiate and use for the card back.
		 * @param	definition The XML definition for the card.
		 */
		public function Card (cardFront:Class, cardBack:Class, definition:XML) 
		{
			_cardFront = cardFront;			
			_cardBack = cardBack;			
			_cardDefinition = definition;
			refreshCard();
			addEventListener(Event.ADDED_TO_STAGE, initialize);
		}
		
		/**
		 * Attempts to refresh the card UI by re-instantiating and re-attaching
		 * the front and back class instances. Typically this is not necessary unless
		 * the card faces or definition have changed.
		 * 
		 * @return False if the operation couldn't be carried out successfully.
		 */
		public function refreshCard():Boolean 
		{
			if (_cardContainer == null) {
				_cardContainer = new MovieClip();
				addChild(_cardContainer);
			}
			if (_cardFrontSprite != null) {
				try {
					_cardContainer.removeChild(_cardFrontSprite);
				} catch (err:*) {	
				}
			}
			if (_cardBackSprite != null) {
				try {
					_cardContainer.removeChild(_cardBackSprite);
				} catch (err:*) {				
				}
			}
			//use carry-through boolean to try to attach either face (more dynamic this way)
			var returnVal:Boolean = true;
			try {
				_cardFrontSprite = new Sprite();				
				var bitmapData:BitmapData = (new _cardFront() as Bitmap).bitmapData;				
				var frontSprite:Bitmap = new Bitmap(bitmapData);					
				_cardFrontSprite.addChild(frontSprite);				
				_cardContainer.addChild(_cardFrontSprite);
				if (_faceUp) {
					_cardFrontSprite.visible = true;					
				} else {
					_cardFrontSprite.visible = false;				
				}
				_cardFrontSprite.x -= _cardFrontSprite.width/2;
				_cardFrontSprite.y -= _cardFrontSprite.height/2;
			} catch (err:*) {					
				returnVal = false;
			}
			try {
				_cardBackSprite = new Sprite();				
				bitmapData = (new _cardBack() as Bitmap).bitmapData;
				var backSprite:Bitmap = new Bitmap(bitmapData);					
				_cardBackSprite.addChild(backSprite);
				_cardContainer.addChild(_cardBackSprite);
				if (_faceUp) {
					_cardBackSprite.visible = false;
				} else {
					_cardBackSprite.visible = true;									
				}
				_cardBackSprite.x -= _cardBackSprite.width/2;
				_cardBackSprite.y -= _cardBackSprite.height/2;
			} catch (err:*) {						
				returnVal = false;
			}			
			alpha = 0;			
			return (returnVal);
		}		
		
		/**
		 * @return True if the card is currently facing up (front face is visible).
		 */
		public function get faceUp():Boolean 
		{
			return (_faceUp);
		}
				
		
		/**
		 * @return The fully qualified name of the card front class.
		 */
		public function get frontClassName():String 
		{
			try {
				var frontName:String = getQualifiedClassName(_cardFront);	
			} catch (err:*) {
				return ("");
			}
			return (frontName);
		}

		/**
		 * @return A reference to the card front class. Must be a DisplayObject descendant.
		 */
		public function get frontClass():Class 
		{
			return (_cardFront);
		}
				
		public function set frontClass(classSet:Class):void 
		{
			_cardFront = classSet;
		}
		
		/**
		 * @return The fully qualified name of the card back class.
		 */
		public function get backClassName():String 
		{
			try {
				var backName:String = getQualifiedClassName(_cardBack);			
			} catch (err:*) {
				return ("");
			}
			return (backName);
		}		
		
		/**
		 * @return A reference to the card back class. Must be a DisplayObject descendant.
		 */
		public function get backClass():Class
		{
			return (_cardBack);
		}
		
		public function set backClass(classSet:Class):void 
		{
			_cardBack = classSet;
		}
		
		/**
		 * Immediately shows the card user interface.
		 */
		public function show():void 
		{
			visible = true;
			alpha = 1;
		}
		
		/**
		 * Immediately hides the card user interface.
		 */
		public function hide():void 
		{	
			visible = false;
			alpha = 0;
		}
		
		/**
		 * @return The numeric low or standard face value of the card as defined in the settings data.
		 */
		public function get faceValue():int 
		{
			var valueDef:String = String(_cardDefinition.@facevalue);
			if (valueDef.indexOf(";") < 0) {
				return (int(valueDef));
			}
			var defs:Array = valueDef.split(";"); //may not exist		
			return (int(defs[0]));
		}
		
		/**
		 * The numeric high face value of the card (usually an ace). If not defined, the faceValue is returned.
		 */
		public function get faceValueHigh():int 
		{
			var valueDef:String = String(_cardDefinition.@facevalue);
			if (valueDef.indexOf(";") < 0) {
				return (faceValue);
			}
			var defs:Array = valueDef.split(";");			
			return (int(defs[1]));
		}
		
		/**
		 * The textual (short) name of the card as defined in the settings data.
		 */
		public function get faceText():String 
		{
			return (String(_cardDefinition.@facetext));
		}
		
		/**
		 * The textual color name of the card as defined in the settings data.
		 */
		public function get faceColor():String 
		{
			return (String(_cardDefinition.@color));
		}
		
		/**
		 * The name of the card suit as defined in the settings data.
		 */
		public function get faceSuit():String 
		{
			return (String(_cardDefinition.@suit));
		}
		
		/**
		 * The long textual name of the card as defined in the settings data.
		 */
		public function get cardName():String 
		{
			return (String(_cardDefinition.@name));
		}
		
		/**
		 * Fades the card to alpha 1.
		 * 
		 * @param	duration The duration, in seconds, over which to fade the card in by.
		 */
		public function fadeIn(duration:Number = 1):void 
		{
			stopFadeTransition();
			_fadeUp = true;			
			var loops:int = (int(duration * 1000000) * 50) / 1000000;			
			_fadeInc = 1 / loops;
			if (_fadeInc < 0.01) {
				_fadeInc = 0.01;
			}		
			_fadeTimer = new Timer(10, loops);			
			_fadeTimer.addEventListener(TimerEvent.TIMER_COMPLETE, onFadeDone);
			_fadeTimer.addEventListener(TimerEvent.TIMER, onFadeTimer);
			_fadeTimer.start();
		}
		
		/**
		 * Fades the card to alpha 0.
		 * 
		 * @param	duration The duration, in seconds, over which to fade the card out by.
		 */
		public function fadeOut(durationVal:uint = 1):void 
		{
			stopFadeTransition();
			_fadeUp = false;
			_fadeTimer.addEventListener(TimerEvent.TIMER_COMPLETE, onFadeDone);
			_fadeTimer.addEventListener(TimerEvent.TIMER, onFadeTimer);
		}			
		
		/**
		 * Animates a card "flip" to a specified face.
		 * 
		 * @param	toFaceUp Flip the card to its face-up side (true), or face-down side (false). If already on this side the
		 * function exits immediately with no animations.
		 * @param	fadeOutSpeed The speed at which to fade the current face out, in milliseconds.
		 * @param	fadeInSpeed The speed at which to fade the new face in, in milliseconds.
		 * @param	delay An optional delay, in milliseconds, before starting the animation.
		 */
		public function flip(toFaceUp:Boolean, fadeOutSpeed:Number = 1, fadeInSpeed:Number = 0, delay:Number = 0 ):void 
		{
			if (toFaceUp == _faceUp) {					
				return;
			}			
			if (delay>0) {
				setTimeout(function():void {flip(toFaceUp, fadeOutSpeed, fadeInSpeed, 0);}, delay);
				return;
			}			
			this.visible = true;
			this._cardContainer.visible = true;	
			this._cardContainer.alpha = 1;
			this.alpha = 1;
			if ((fadeOutSpeed == 0) && (fadeInSpeed == 0)) {
				this.swapFaceVisibility();				
				this._faceUp = toFaceUp;
				return;
			}
			var loops:int = (int(fadeOutSpeed * 1000000) * 50) / 1000000;			
			_flipAlphaDec = 1 / loops;
			if (_flipAlphaDec < 0.01) {
				_flipAlphaDec = 0.01;
			}
			loops = (int(fadeInSpeed * 1000000) * 50) / 1000000;			
			_flipAlphaInc = 1 / loops;
			if (_flipAlphaInc < 0.01) {
				_flipAlphaInc = 0.01;
			}
			_flipFaceUp = toFaceUp;
			this.clearFlipTimer();
			this._flipFadeOut = true;
			this._flipTimer = new Timer(10);
			this._flipTimer.addEventListener(TimerEvent.TIMER, this.onFlipTimer);
			this._flipTimer.start();
		}
		
		/**
		 * Animates a card "flip" to its opposite face (if up then down, if down then up).
		 * 		 
		 * @param	fadeOutSpeed The speed at which to flip the card over on its X axis.
		 * @param	fadeInSpeed The speed at which to flip the card over on its Y axis.		 
		 * @param	delay An optional delay, in milliseconds, before starting the animation.
		 */
		public function flipOver(flipYSpeed:Number = 1, flipXSpeed:Number = 0, delay:Number = 0):void 
		{
			flip(!faceUp, flipYSpeed, flipXSpeed, delay);
		}
		
		private function clearFlipTimer():void {
			if (this._flipTimer != null) {
				this._flipTimer.stop();
				this._flipTimer.removeEventListener(TimerEvent.TIMER, this.onFlipTimer);
			}
		}
		
		private function onFlipTimer(eventObj:TimerEvent):void {
			if (this._flipFadeOut) {				
				this._cardContainer.alpha -= this._flipAlphaDec;
				if (this._cardContainer.alpha <= 0) {					
					this.swapFaceVisibility();
					this._flipFadeOut = false;
				}
			} else {
				this._cardContainer.alpha += this._flipAlphaDec;				
				if (this._cardContainer.alpha >= 1) {					
					this._cardContainer.alpha = 1;
					this.clearFlipTimer();
					this._faceUp = this._flipFaceUp;
				}
			}			
		}
		
		private function swapFaceVisibility():void {
			if (this._cardFrontSprite.visible) {				
				this._cardFrontSprite.visible = false;
				this._cardBackSprite.visible = true;
			} else {				
				this._cardFrontSprite.visible = true;
				this._cardBackSprite.visible = false;
			}
		}
		
		/**
		 * The X position of the card adjusting for a registration point offset (used to center the card).
		 */
		override public function set x(xVal:Number):void 
		{			
			super.x = xVal + (width / 2);
		}
		
		override public function get x():Number 
		{
			return (super.x-(width/2));
		}
		
		/**
		 * The Y position of the card adjusting for a registration point offset (used to center the card).
		 */
		override public function set y(yVal:Number):void 
		{			
			super.y = yVal + (height/2);
		}
		
		override public function get y():Number 
		{
			return (super.y - (height/2));
		}
		
		/**
		 * Scales the card (both faces) to the target width Value.
		 * 
		 * @param	widthVal The target width value to scale the card faces to.
		 */
		public function scaleToWidth(widthVal:Number):void 
		{
			var scaleVal:Number = widthVal / width;
			height *= scaleVal;
			width = widthVal;
		}
		
		/**
		 * Scales the card (both faces) to the target height Value.
		 * 
		 * @param	widthVal The target height value to scale the card faces to.
		 */
		public function scaleToHeight(heightVal:Number):void 
		{
			var scaleVal:Number = heightVal / height;
			width *= scaleVal;
			height = heightVal;
		}
		
		/**
		 * @return The width of the card as an average of the widths of the front and back faces.
		 */
		override public function get width(): Number 
		{			
			return ((_cardBackSprite.width+_cardFrontSprite.width)/2);
		}
		
		/**
		 * @return The height of the card as an average of the heights of the front and back faces.
		 */
		override public function get height(): Number 
		{
			return ((_cardBackSprite.height+_cardFrontSprite.height)/2);
		}
		
		/**
		 * Stops any currently active fade animation and clears the timer.
		 */
		protected function stopFadeTransition():void 
		{
			if (_fadeTimer != null) {
				_fadeTimer.stop();
				_fadeTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, onFadeDone);
				_fadeTimer.removeEventListener(TimerEvent.TIMER, onFadeTimer);
				_fadeTimer = null;
			}
		}		
		
		/**
		 * Handles a fade timer's completion event.
		 * 
		 * @param	eventObj A standard TimerEvent object.
		 */
		protected function onFadeDone(eventObj:TimerEvent):void 
		{
			if (_fadeUp) {
				alpha = 1;
			} else {
				alpha = 0;
			}
			stopFadeTransition();
		}
		
		/**
		 * Handles a fade timer's tick (TIMER) events.
		 * 
		 * @param	eventObj A standard TimerEvent object.
		 */
		protected function onFadeTimer(eventObj:TimerEvent):void 
		{
			if (_fadeUp) {
				alpha+=_fadeInc ;
			} else {
				alpha-=_fadeInc ;
			}
		}				

		/**
		 * Initializes the card instance when it's been added to the stage.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		protected function initialize(eventObj:Event):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, initialize);
			mouseChildren = false;
		}
	}
}
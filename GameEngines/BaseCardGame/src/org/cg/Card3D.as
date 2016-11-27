/**
* An extended Card type that used 3D effects for display. Usually instantiated by a CardDeck instance.
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
	import net.kawa.tween.KTween;
	import net.kawa.tween.KTJob;
	import net.kawa.tween.KTManager;	
	import net.kawa.tween.easing.Expo;
	import net.kawa.tween.easing.Quad;
	import flash.filters.DropShadowFilter;
		
	public class Card3D extends Card implements ICard {
		
		private var _liftDistance:Number = -200; //Distance to "lift" card during a lift operation.		
		private var _activeTweens:Vector.<KTJob> = new Vector.<KTJob>(); //All currently active tweens		
		//Following values are used in calculation to determine which direction card is facing.
		private var p1:Point;
		private var p2:Point;
		private var p3:Point;         
		private var p1_:Point = new Point(0, 0);
		private var p2_:Point = new Point(100, 0);
		private var p3_:Point = new Point(0, 100);
		
		public function Card3D(cardFront:Class, cardBack:Class, definition:XML) 
		{
			super(cardFront, cardBack, definition);			
		}
		
		/**
		 * Attempts to refresh the card UI by re-instantiating and re-attaching
		 * the front and back class instances. Typically this is not necessary unless
		 * the card faces or definition have changed.
		 * 
		 * @return False if the operation couldn't be carried out successfully.
		 */
		override public function refreshCard():Boolean 
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
					frontSprite.scaleX = -1;
					frontSprite.x += frontSprite.width;				
				}
			} catch (err:*) {					
				returnVal = false;
			}
			try {
				_cardBackSprite = new Sprite();				
				var bitmapData:BitmapData = (new _cardBack() as Bitmap).bitmapData;
				var backSprite:Bitmap = new Bitmap(bitmapData);					
				_cardBackSprite.addChild(backSprite);
				_cardContainer.addChild(_cardBackSprite);
				if (_faceUp) {
					_cardBackSprite.visible = false;
				} else {
					_cardBackSprite.visible = true;
					backSprite.scaleX = -1;
					backSprite.x += backSprite.width;
				}
			} catch (err:*) {						
				returnVal = false;
			}			
			alpha = 0;
			alignCard();
			return (returnVal);
		}
		
		/**
		 * @return True if the card is currently animating.
		 */
		public function get animating():Boolean 
		{
			try {
				if (_activeTweens.length > 0) {
					return (true);
				}
			} catch (err:*) {
				return (false);
			}
			return (false);
		}
		
		/**
		 * The distance used during card "lift" animations.
		 */
		public function get liftDistance():Number 
		{
			return (_liftDistance);
		}
		
		public function set liftDistance(distanceSet:Number):void 
		{
			_liftDistance = distanceSet;
		}
		
		/**
		 * Animates a card "lift" from the background surface.
		 * 
		 * @param liftSpeed The speed at which to lift the card at.
		 * @param dropOnLoft If true a "drop" operation is queued immediately upon completion of the "lift" using the liftSpeed
		 * parameter as the drop speed.
		 */
		public function lift(liftSpeed:Number, dropOnLift:Boolean = false):void 
		{
			var tweenJob:KTJob = KTween.to(_cardContainer, liftSpeed, { z:liftDistance }, Quad.easeOut, onLiftDone);
			tweenJob.onChange = onLiftTweenUpdate;
			tweenJob.onChangeParams = [tweenJob];
			tweenJob.onCloseParams = [tweenJob, dropOnLift];
			_activeTweens.push(tweenJob);
		}
		
		/**
		 * Animates a card "drop" to the background surface.
		 * 
		 * @param	dropSpeed The speed at which to drop the card at.
		 */
		public function drop(dropSpeed:Number):void 
		{
			var tweenJob:KTJob = KTween.to(_cardContainer, dropSpeed, { z:0 }, Quad.easeIn, onDropDone);	
			tweenJob.onChange = onLiftTweenUpdate;
			tweenJob.onChangeParams = [tweenJob];
			tweenJob.onCloseParams = [tweenJob];
			_activeTweens.push(tweenJob);
		}
		
		/**
		 * Animates a card "flip" to a specified side with an optional "lift".
		 * 
		 * @param	toFaceUp Flip the card to its face-up side (true), or face-down side (false). If already on this side the
		 * function exits immediately with no animations.
		 * @param	flipYSpeed The speed at which to flip the card over on its X axis.
		 * @param	flipXSpeed The speed at which to flip the card over on its Y axis.
		 * @param	useLift If true, a "lift" animation is queued up before the flip.
		 * @param	delay An optional delay, in milliseconds, before starting the animation.
		 */
		override public function flip(toFaceUp:Boolean, flipYSpeed:Number = 1, flipXSpeed:Number = 0, useLift:Boolean = true, delay:Number = 0 ):void 
		{
			if (toFaceUp == _faceUp) {				
				return;
			}
			if (animating) {				
				return;
			}
			if (delay>0) {
				setTimeout(function():void { flip(toFaceUp, flipYSpeed, flipXSpeed, useLift, 0); }, delay);
				return;
			}
			_flipFaceUp = toFaceUp;
			if (_flipFaceUp) {
				var targetXRotation:Number = 180;
				var targetYRotation:Number = 180;				
			} else {
				targetXRotation = 0;
				targetYRotation = 0;				
			}
			if (flipXSpeed < 0) {
				targetXRotation *= -1;
			}
			if (flipYSpeed < 0) {
				targetYRotation *= -1;
			}	
			flipXSpeed = Math.abs(flipXSpeed);
			flipYSpeed = Math.abs(flipYSpeed);			
			if ((flipYSpeed == 0) && (flipXSpeed != 0)) {
				if (useLift) { lift((flipXSpeed / 2), true); }
				var tweenJob:KTJob = KTween.to(_cardContainer, flipXSpeed, { rotationX:targetXRotation }, Expo.easeInOut, onTweenDone);
				tweenJob.onChangeParams = [tweenJob];
				tweenJob.onCloseParams = [tweenJob];
				tweenJob.onChange = onFlipTweenUpdate;					
				_activeTweens.push(tweenJob);
			} else if ((flipXSpeed == 0) && (flipYSpeed != 0)) {
				if (useLift) { lift((flipYSpeed / 2), true); }
				tweenJob = KTween.to(_cardContainer, flipYSpeed, { rotationY:targetYRotation }, Expo.easeInOut, onTweenDone);
				tweenJob.onChangeParams = [tweenJob];
				tweenJob.onCloseParams = [tweenJob];
				tweenJob.onChange = onFlipTweenUpdate;				
				_activeTweens.push(tweenJob);
			} else {
				if (flipXSpeed > flipYSpeed) {
					if (useLift) { 
						lift((flipXSpeed / 2), true); 
					}
					tweenJob = KTween.to(_cardContainer, flipXSpeed, { rotationX:(targetXRotation*2) }, Expo.easeInOut, onTweenDone);
					var tweenJob2:KTJob = KTween.to(_cardContainer, flipYSpeed, { rotationY:targetYRotation }, Expo.easeInOut, onTweenDone);
					tweenJob.onChange = onFlipTweenUpdate;	
					tweenJob2.onChange = onFlipTweenUpdate;
					tweenJob.onChangeParams = [tweenJob];
					tweenJob.onCloseParams = [tweenJob];
					tweenJob2.onChangeParams = [tweenJob2];
					tweenJob2.onCloseParams = [tweenJob2];
					_activeTweens.push(tweenJob);
					_activeTweens.push(tweenJob2);
				} else {
					if (useLift) { 
						lift((flipYSpeed / 2), true); 
					}
					tweenJob = KTween.to(_cardContainer, flipXSpeed, { rotationX:targetXRotation }, Expo.easeInOut, onTweenDone);
					tweenJob2 = KTween.to(_cardContainer, flipYSpeed, { rotationY:(targetYRotation * 2) }, Expo.easeInOut, onTweenDone);
					tweenJob.onChange = onFlipTweenUpdate;	
					tweenJob2.onChange = onFlipTweenUpdate;	
					tweenJob.onChangeParams = [tweenJob];
					tweenJob.onCloseParams = [tweenJob];
					tweenJob2.onChangeParams = [tweenJob2];
					tweenJob2.onCloseParams = [tweenJob2];
					_activeTweens.push(tweenJob);
					_activeTweens.push(tweenJob2);
				}
			}	
			var ktm:KTManager = new KTManager();
			ktm.resume();
		}
				
		/**
		 * Animates a card "flip" to its opposite face (if up then down, if down then up) with an optional "lift".
		 * 		 
		 * @param	flipYSpeed The speed at which to flip the card over on its X axis.
		 * @param	flipXSpeed The speed at which to flip the card over on its Y axis.
		 * @param	useLift If true, a "lift" animation is queued up before the flip.
		 * @param	delay An optional delay, in milliseconds, before starting the animation.
		 */
		override public function flipOver(flipYSpeed:Number = 1, flipXSpeed:Number = 0, useLift:Boolean = true, delay:Number = 0):void 
		{
			flip(!faceUp, flipYSpeed, flipXSpeed, useLift, delay);
		}
		
		/**
		 * Callback handler invoked by the KTJob instance when a tween has completed.
		 * 
		 * @param	jobRef A KTJob instance.
		 */
		private function onTweenDone(jobRef:KTJob):void 
		{					
			var compTweens:Vector.<KTJob> = new Vector.<KTJob>();
			for (var count:uint = 0; count < _activeTweens.length; count++) {
				var currentTweenJob:KTJob = _activeTweens[count];
				if (currentTweenJob != jobRef) {
					compTweens.push(currentTweenJob);
				}
			}
			_activeTweens = compTweens;
			if (_activeTweens.length == 0) {
				_faceUp = _flipFaceUp;				
				var event:CardEvent = new CardEvent(CardEvent.ONFLIP);
				event.sourceCard = this;
				dispatchEvent(event);				
			}
		}
		
		/**
		 * Callback handler invoked by the KTJob instance when a "flip" tween is running.
		 * 
		 * @param	jobRef A KTJob instance.
		 */
		private function onFlipTweenUpdate(jobRef:KTJob):void 
		{					
			if (isFrontFacing(_cardBackSprite)) {
				_cardBackSprite.visible = true;
				_cardFrontSprite.visible = false;
			} else {
				_cardBackSprite.visible = false;
				_cardFrontSprite.visible = true;
			}				
		}
		
		/**
		 * Callback handler invoked by the KTJob instance when a "lift" animation is done.
		 * 
		 * @param	jobRef A KTJob instance.
		 * @param dropOnLift If true, a drop animation is started immediately.
		 */
		private function onLiftDone(jobRef:KTJob, dropOnLift:Boolean):void 
		{
			if (dropOnLift) {
				drop(Number(jobRef.duration));
			}
			onTweenDone(jobRef);
		}
		
		/**
		 * Callback handler invoked by the KTJob instance when a "drop" animation is done.
		 * 
		 * @param	jobRef A KTJob instance.
		 */
		private function onDropDone(jobRef:KTJob):void 
		{
			rotationX = 0;
			rotationY = 0;
			cacheAsBitmap = false;
			filters = [];
			onTweenDone(jobRef);
		}
		
		/**
		 * Callback handler invoked by the KTJob instance when a "lift" tween is running.
		 * 
		 * @param	jobRef A KTJob instance.
		 */
		private function onLiftTweenUpdate(jobRef:KTJob):void 
		{
			if (filters == null) {
				filters = [];
			}
			if (filters.length == 0) {
				var dsFilter:DropShadowFilter = new DropShadowFilter(0, -135, 0, 0.25, 10, 10, 1, 4, false, false, false);
			} else {
				dsFilter = filters[0] as DropShadowFilter;
			}
			dsFilter.distance = (_cardContainer.z / 6);		
			filters = [dsFilter];
		}
		
		/**
		 * Aligns the card faces around the registration point for correct rotations.
		 */
		private function alignCard():void 
		{			
			try {				
				if (_cardFrontSprite) {
					_cardFrontSprite.getChildAt(0).x = (_cardFrontSprite.getChildAt(0).width / -2);
					_cardFrontSprite.x = _cardFrontSprite.width;
					_cardFrontSprite.getChildAt(0).y = (_cardFrontSprite.getChildAt(0).height / 2);						
					_cardFrontSprite.y = _cardFrontSprite.height*-1;					
				}				
				if (_cardBackSprite) {
					_cardBackSprite.getChildAt(0).x = (_cardBackSprite.getChildAt(0).width / -2);
					_cardBackSprite.x = _cardBackSprite.width;
					_cardBackSprite.getChildAt(0).y = (_cardBackSprite.getChildAt(0).height / 2);
					_cardBackSprite.y = _cardBackSprite.height*-1;
				}	
				_cardBackSprite.cacheAsBitmap = false;				
				_cardFrontSprite.cacheAsBitmap = false;				
			} catch (err:*) {	
				trace (err);
			}			
		}
		
		/**
		 * Evaluates whether or not a 3D-transormed DisplayObject is facing the viewer
		 * or away from them. Typically used to determine face culling.
		 * 
		 * @param	displayObject The DisplayObject descendant to evaluate.
		 * 
		 * @return True if the display object is facing the viewer, false otherwise.
		 */
		private function isFrontFacing(displayObject:DisplayObject):Boolean 
		{    
			p1 = displayObject.localToGlobal(p1_);
			p2 = displayObject.localToGlobal(p2_);
			p3 = displayObject.localToGlobal(p3_);
			return Boolean((p2.x-p1.x)*(p3.y-p1.y) - (p2.y-p1.y)*(p3.x-p1.x) > 0);
		}		
		
	}

}
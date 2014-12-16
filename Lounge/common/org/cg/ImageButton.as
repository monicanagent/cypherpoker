/**
* A multi-state image button component.
* 
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/ 

package org.cg 
{
	
	import flash.display.DisplayObject;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.MovieClip;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;	
	import flash.net.URLRequest;
	import flash.system.LoaderContext;	
	import flash.system.ApplicationDomain;
	import org.cg.events.ImageButtonEvent;	
	
	public class ImageButton extends MovieClip 
	{
		
		private var _upImage:Loader = new Loader();
		private var _downImage:Loader = new Loader();
		private var _overImage:Loader = new Loader();
		private var _disabledImage:Loader = new Loader();
		
		private var _over:Boolean = false;
		private var _down:Boolean = false;
		private var _disabled:Boolean = false;
		
		private var _overFacePath:String = null;
		private var _upFacePath:String = null;
		private var _downFacePath:String = null;
		private var _disabledFacePath:String = null;
		
		
		public function ImageButton() 
		{			
			addEventListener(Event.ADDED_TO_STAGE, initialize);
			super();
		}
		
		/**
		 * Current mouse down state.
		 */
		public function get down():Boolean 
		{
			return (_down);
		}
		
		/**
		 * Current mouse over state.
		 */
		public function get over():Boolean 
		{
			return (_over);
		}
		
		/**
		 * Current disabled state ("enabled" is reserved).
		 */
		public function get disabled():Boolean 
		{
			return (_disabled);
		}
		
		public function set disabled(disabledSet:Boolean):void 
		{		
			_disabled = disabledSet;			
			updateUI();			
		}
		
		/**
		 * The path to the over state image. Setting this value causes the image to be immediately loaded.
		 */
		public function set overFacePath(pathSet:String):void 
		{						
			_overFacePath = pathSet;
			_overImage = new Loader();			
			_overImage.contentLoaderInfo.addEventListener(Event.COMPLETE, onOverFaceLoad);
			_overImage.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onOverFaceLoad);
			var request:URLRequest = new URLRequest(pathSet);
			var context:LoaderContext = new LoaderContext(false, ApplicationDomain.currentDomain);
			_overImage.load(request, context);			
			addChild(_overImage);
		}
		
		public function get overFacePath():String 
		{
			return (_overFacePath);
		}				
		
		/**
		 * The path to the up state image. Setting this value causes the image to be immediately loaded.
		 */
		public function set upFacePath(pathSet:String):void 
		{			
			_overFacePath = pathSet;
			_upImage = new Loader();			
			_upImage.contentLoaderInfo.addEventListener(Event.COMPLETE, onUpFaceLoad);
			_upImage.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onUpFaceLoad);
			var request:URLRequest = new URLRequest(pathSet);
			var context:LoaderContext = new LoaderContext(false, ApplicationDomain.currentDomain);
			_upImage.visible = false;
			_upImage.load(request, context);
			addChild(_upImage);
		}
		
		public function get upFacePath():String 
		{
			return (_upFacePath);
		}	
		
		/**
		 * The path to the down state image. Setting this value causes the image to be immediately loaded.
		 */
		public function set downFacePath(pathSet:String):void 
		{			
			_downFacePath = pathSet;
			_downImage = new Loader();			
			_downImage.contentLoaderInfo.addEventListener(Event.COMPLETE, onDownFaceLoad);
			_downImage.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onDownFaceLoad);
			var request:URLRequest = new URLRequest(pathSet);
			var context:LoaderContext = new LoaderContext(false, ApplicationDomain.currentDomain);
			_downImage.visible = false;
			_downImage.load(request, context);
			addChild(_downImage);
		}
		
		public function get downFacePath():String 
		{
			return (_downFacePath);
		}
		
		/**
		 * The path to the disabled state image. Setting this value causes the image to be immediately loaded.
		 */
		public function set disabledFacePath(pathSet:String):void 
		{			
			_disabledFacePath = pathSet;
			_disabledImage = new Loader();			
			_disabledImage.contentLoaderInfo.addEventListener(Event.COMPLETE, onDisabledFaceLoad);
			_disabledImage.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onDisabledFaceLoad);
			var request:URLRequest = new URLRequest(pathSet);
			var context:LoaderContext = new LoaderContext(false, ApplicationDomain.currentDomain);
			_disabledImage.visible = false;
			_disabledImage.load(request, context);
			addChild(_disabledImage);
		}
		
		public function get disabledFacePath():String 
		{
			return (_disabledFacePath);
		}
		
		/**
		 * Immediately hides the button UI.
		 */
		public function hide():void 
		{			
			visible = false;	
		}
		
		/**
		 * Immediately shows the button UI.
		 */
		public function show():void 
		{
			visible = true;
		}
		
		/**
		 * Handler for over state image load completion.
		 * 
		 * @param	eventObj
		 */
		private function onOverFaceLoad(eventObj:*):void 
		{
			_overImage.name = "_overImage";
			eventObj.target.removeEventListener(Event.COMPLETE, onOverFaceLoad);
			eventObj.target.removeEventListener(IOErrorEvent.IO_ERROR, onOverFaceLoad);			
			updateUI();
		}
		
		/**
		 * Handler for up state image load completion.
		 * 
		 * @param	eventObj
		 */
		private function onUpFaceLoad(eventObj:*):void 
		{	
			_upImage.name = "_upImage";
			eventObj.target.removeEventListener(Event.COMPLETE, onUpFaceLoad);
			eventObj.target.removeEventListener(IOErrorEvent.IO_ERROR, onUpFaceLoad);			
			updateUI();
		}
		
		/**
		 * Handler for down state image load completion.
		 * 
		 * @param	eventObj
		 */
		private function onDownFaceLoad(eventObj:*):void 
		{
			_downImage.name = "_downImage";
			eventObj.target.removeEventListener(Event.COMPLETE, onDownFaceLoad);
			eventObj.target.removeEventListener(IOErrorEvent.IO_ERROR, onDownFaceLoad);			
			updateUI();
		}
		
		/**
		 * Handler for disabled state image load completion.
		 * 
		 * @param	eventObj
		 */
		private function onDisabledFaceLoad(eventObj:*):void 
		{
			_disabledImage.name = "_disabledImage";
			eventObj.target.removeEventListener(Event.COMPLETE, onDisabledFaceLoad);
			eventObj.target.removeEventListener(IOErrorEvent.IO_ERROR, onDisabledFaceLoad);			
			updateUI();
		}
		
		/**
		 * Handles mouse down events.
		 * 
		 * @param	eventObj A MouseEvent object.
		 */
		private function mouseDownHandler(eventObj:MouseEvent):void 
		{
			if (_disabled) {
				return;
			}			
			_down = true;
			updateUI();			
		}
		
		/**
		 * Handles mouse up events.
		 * 
		 * @param	eventObj A MouseEvent object.
		 */
		private function mouseUpHandler(eventObj:MouseEvent):void 
		{
			if (_disabled) {
				return;
			}
			_down = false;
			updateUI();			
			if (_over && visible) {				
				var event:ImageButtonEvent = new ImageButtonEvent(ImageButtonEvent.CLICKED);
				dispatchEvent(event);
			}
		}
		
		/**
		 * Handles mouse move events.
		 * 
		 * @param	eventObj A MouseEvent object.
		 */
		private function mouseMoveHandler(eventObj:MouseEvent):void 
		{			
			var preOver:Boolean = _over;
			if (hitTestPoint(eventObj.stageX, eventObj.stageY, true) || _down) {				
				_over = true;
			} else {				
				_over = false;
			}
			if (preOver!=_over) {
				updateUI();
			}
		}
		
		/**
		 * Sets display visibility for a target display object. Allow extra "hide" effects to be added.
		 * 
		 * @param	displayObj The target display object to update visibility on.
		 * @param	visibility The visibility setting for the target display object.
		 */
		private function setDisplayVisible(displayObj:DisplayObject, visibility:Boolean):void 
		{			
			displayObj.visible = visibility;			
		}
		
		/**
		 * Updates the visible UI based on the current state of the button.
		 */
		private function updateUI():void 
		{		
			try {				
				if (_disabled) {						
					setDisplayVisible(_disabledImage, true);
					setDisplayVisible(_downImage, false);
					setDisplayVisible(_upImage, false);
					setDisplayVisible(_overImage, false);
					return;
				}
				if (_over && _down) {
					setDisplayVisible(_downImage, true);
					setDisplayVisible(_disabledImage, false);					
					setDisplayVisible(_upImage, false);
					setDisplayVisible(_overImage, false);
				} else if (_over  && (!_down)) {
					setDisplayVisible(_overImage, true);
					setDisplayVisible(_disabledImage, false);
					setDisplayVisible(_downImage, false);
					setDisplayVisible(_upImage, false);					
				} else {
					setDisplayVisible(_upImage, true);
					setDisplayVisible(_disabledImage, false);
					setDisplayVisible(_downImage, false);					
					setDisplayVisible(_overImage, false);
				}
			} catch (err:*) {				
			}			
		}
		
		/**
		 * Adds event listeners for the button.
		 */
		private function addListeners():void 
		{			
			addEventListener(MouseEvent.MOUSE_DOWN, mouseDownHandler);			
			stage.addEventListener(MouseEvent.MOUSE_UP, mouseUpHandler);
			stage.addEventListener(MouseEvent.MOUSE_MOVE, mouseMoveHandler);
			useHandCursor = true;			
			mouseChildren = false;
			mouseEnabled = true;
		}
		
		/**
		 * Removes event listeners from the button.
		 */
		private function removeListeners():void 
		{			
			removeEventListener(MouseEvent.MOUSE_DOWN, mouseDownHandler);			
			stage.removeEventListener(MouseEvent.MOUSE_UP, mouseUpHandler);
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, mouseMoveHandler);
			useHandCursor = false;			
			mouseEnabled = false;
		}
		
		/**
		 * Initializes the instance.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function initialize(eventObj:Event):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, initialize);
			addListeners();
		}
	}
}
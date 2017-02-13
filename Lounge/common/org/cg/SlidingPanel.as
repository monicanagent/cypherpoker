package org.cg {
		
	import feathers.controls.Button;
	import org.cg.interfaces.IWidget;
	import starling.display.Image;
	import starling.textures.Texture;
	import flash.ui.Mouse;
	import flash.ui.MouseCursor;
	import flash.ui.MouseCursorData;
	import flash.geom.Point;
	import org.cg.interfaces.ISlidingPanel;
	import org.cg.interfaces.IPanelLeaf;
	import org.cg.events.SlidingPanelEvent;
	import flash.display.BitmapData;
	import flash.display.Shape;
	import starling.display.Sprite;
	import starling.events.Event;	
	import starling.events.Touch;
	import starling.events.TouchEvent;
	import starling.events.TouchPhase;
	import org.cg.interfaces.IPanelWidget;
	import feathers.layout.HorizontalLayout;
	import org.cg.Lounge;	
	import org.cg.interfaces.ILounge;
	import org.cg.DebugView;
	import net.kawa.tween.KTween;
	import net.kawa.tween.KTJob;	
	import net.kawa.tween.easing.Quad;
	import flash.utils.setTimeout;
	import flash.utils.setInterval;
	import flash.utils.clearInterval;	
	
	public class SlidingPanel extends Sprite implements ISlidingPanel {
		
		public static var defaultWidth:Number = Number.NEGATIVE_INFINITY;
		public static var defaultHeight:Number = Number.NEGATIVE_INFINITY;
		public static var panelOrigin:Point = new Point(0, 0); //the point at which a panel is considered open
		public static var mainDisplayDims:Point = new Point(800, 600); //dimensions of the main display extents (offset from panelOrigin)
		private static var _panels:Vector.<ISlidingPanel> = new Vector.<ISlidingPanel>();
		
		public var openButton:Button; //open and closed buttons are separated so that they may be styled individually
		public var closeButton:Button;
		public var bgcolor:int = 0x0A0A0A;	
		public var bgalpha:Number = 1;
		protected var _width:Number;
		protected var _height:Number;
		protected var _lounge:ILounge = null; //reference to parent lounge
		protected var _panelData:XML;
		protected var _position:String;		
		protected var _widgets:Vector.<IPanelWidget> = new Vector.<IPanelWidget>();
		protected var _panelLeaves:Vector.<IPanelLeaf> = new Vector.<IPanelLeaf>();
		protected var _open:Boolean = true;
		protected var _opening:Boolean = false;
		protected var _openButtonOriginPoint:Point;
		protected var _closeButtonOriginPoint:Point;
		private var _elasticSnapTween:KTJob;	
		private var _panelSlideTween:KTJob;	
		private var _openButtonTween:KTJob;
		private var _closeButtonTween:KTJob;
		private var _scrolling:Boolean = false;
		private var _dragStartPoint:Point = new Point(0, 0);		
		private var _revealFrameCounter:uint = 0;
		private var _bgImage:Image = null;
		
		public function SlidingPanel(loungeRef:ILounge, panelData:XML) {
			_panels.push (this);
			this.visible = false;
			this._lounge = loungeRef;
			this._panelData = panelData;
		}	
		
		override public function get width():Number {
			try {
				var widthVal:Number = new Number(this._panelData.@width);
				if (isNaN(widthVal) == false) {
					return (widthVal);
				}
			} catch (err:*) {				
			}
			if (defaultWidth != Number.NEGATIVE_INFINITY) {
				return (defaultWidth);
			}
			return (super.width);
		}
		
		override public function get height():Number {
			try {
				var heightVal:Number = new Number(this._panelData.@height);
				if (isNaN(heightVal) == false) {
					return (heightVal);
				}
			} catch (err:*) {				
			}
			if (defaultHeight != Number.NEGATIVE_INFINITY) {
				return (defaultHeight);
			}
			return (super.height);
		}
		
		public function get isOpen():Boolean {
			return (this._open);
		}
		
		public function get isOpening():Boolean {
			return (this._opening);
		}
		
		public function get position():String {
			try {
				var positionStr:String = String(this._panelData.@position);
				return (positionStr.toLowerCase());
			} catch (err:*) {				
			}
			return ("none");
		}
		
		public function set position(value:String):void {
			value = value.split(" ").join("");
			this._panelData.@position = value.toLowerCase();
		}
		
		public function addWidget(widget:IPanelWidget):void {						
			this.addChild(widget as Sprite);			
			this._widgets.push(widget);
			if (this._widgets.length > 1) {					
				widget.previousWidget = this._widgets[this._widgets.length - 2];
				widget.alignToPrevious();
			}
		}	
		
		public static function get panels():Vector.<ISlidingPanel> {
			return (_panels);
		}
		
		public function addPanelLeaf(leafRef:IPanelLeaf):void {			
			this._panelLeaves.push(leafRef);
			leafRef.panel = this;
		}
		
		public function removePanelLeaf(leafRef:IPanelLeaf):void {
			for (var count:int = 0; count < this._panelLeaves.length; count++) {
				if (this._panelLeaves[count] == leafRef) {
					this._panelLeaves.splice(count, 1);
					break;
				}
			}
			leafRef.destroy();
			leafRef.panel = null;
			this._panelLeaves.push(leafRef);
		}
		
		public function get panelLeaves():Vector.<IPanelLeaf> {
			return (this._panelLeaves);
		}
		
		public function setIsClosed():void {
			this._open = false;
			this.updateLeaves();
		}
		
		public function setIsOpen():void {
			this._open = true;
			this.updateLeaves();
		}
		
		public function closePanel():void {
			this.cancelCurrentTween();
			this.buttonsToClosedPosition();
			if (this.position == "right") {
				if (this.x != mainDisplayDims.x) {
					var event:SlidingPanelEvent = new SlidingPanelEvent(SlidingPanelEvent.CLOSE);
					this.dispatchEvent(event);
					this._panelSlideTween = KTween.to(this, 0.5, { x:mainDisplayDims.x, y:0 }, Quad.easeInOut, this.setIsClosed);			
					this._panelSlideTween.onChange = this.updateLeaves;
				}
			}
			if (this.position == "bottom") {
				if (this.y != mainDisplayDims.y) {
					event = new SlidingPanelEvent(SlidingPanelEvent.CLOSE);
					this.dispatchEvent(event);
					this._panelSlideTween = KTween.to(this, 0.5, { y:mainDisplayDims.y }, Quad.easeInOut, this.setIsClosed);
					this._panelSlideTween.onChange = this.updateLeaves;
				}
			}
			if (this.position == "left") {
				if (this.x != (mainDisplayDims.x * -1)) {
					event = new SlidingPanelEvent(SlidingPanelEvent.CLOSE);
					this.dispatchEvent(event);
					this._panelSlideTween = KTween.to(this, 0.5, { x: (mainDisplayDims.x * -1), y:0 }, Quad.easeInOut, this.setIsClosed);
					this._panelSlideTween.onChange = this.updateLeaves;
				}
			}
			this._opening = false;			
		}
		
		public function openPanel():void {
			this.cancelCurrentTween();
			this.buttonsToOpenedPosition();
			if (this.parent.getChildIndex(this) < (this.parent.numChildren - 1)) {
				//esnure panel is on top of display list
				this.parent.swapChildrenAt(this.parent.getChildIndex(this), (this.parent.numChildren - 1));
			}
			if (this.position == "right") {
				if (this.x != panelOrigin.x) {
					var event:SlidingPanelEvent = new SlidingPanelEvent(SlidingPanelEvent.OPEN);
					this.dispatchEvent(event);
					this._panelSlideTween = KTween.to(this, 0.5, { x:panelOrigin.x, y:panelOrigin.y }, Quad.easeInOut, this.setIsOpen);
					this._panelSlideTween.onChange = this.updateLeaves;
				}
			}
			if (this.position == "bottom") {
				if (this.y != panelOrigin.y) {
					event = new SlidingPanelEvent(SlidingPanelEvent.OPEN);
					this.dispatchEvent(event);
					this._panelSlideTween = KTween.to(this, 0.5, { x:panelOrigin.x, y:panelOrigin.y}, Quad.easeInOut, this.setIsOpen);
					this._panelSlideTween.onChange = this.updateLeaves;
				}
			}
			if (this.position == "left") {
				//this could be merged with "right" panel above
				if (this.x != panelOrigin.x) {
					event = new SlidingPanelEvent(SlidingPanelEvent.OPEN);
					this.dispatchEvent(event);
					this._panelSlideTween = KTween.to(this, 0.5, { x:panelOrigin.x, y:panelOrigin.y }, Quad.easeInOut, this.setIsOpen);
					this._panelSlideTween.onChange = this.updateLeaves;
				}
			}
			this._opening = true;
		}
		
		public function scrollTo(widget:IWidget):void {
			if (widget == null) {
				return;
			}
			for (var count:int = 0; count < this._widgets.length; count++) {
				if (this._widgets[count] == widget) {
					this._elasticSnapTween = KTween.to(this, 0.5, { y: (widget.y * -1) }, Quad.easeInOut);
					//do we need to update leaves when scrolling?
					//this._openCloseButtonTween = KTween.to(this.openCloseButton, 0.5, { y:widget.y }, Quad.easeInOut, this.onScrollTo);
					this._openButtonTween = KTween.to(this.openButton, 0.5, { y:widget.y }, Quad.easeInOut, this.onScrollTo);					
					this._closeButtonTween = KTween.to(this.closeButton, 0.5, { y:widget.y }, Quad.easeInOut, this.onScrollTo);					
					return;
				}
			}
		}
		
		public function onScrollTo():void {
			if ((this.y + this.height) < mainDisplayDims.y) {
				this._elasticSnapTween = KTween.to (this, 0.2, {y:(mainDisplayDims.y - this.height)}, Quad.easeInOut);
				//do we need to update leaves when scrolling?
				this._openButtonTween = KTween.to (this.openButton, 0.2, {y:((mainDisplayDims.y - this.height) *-1)}, Quad.easeInOut);
				this._closeButtonTween = KTween.to (this.closeButton, 0.2, {y:((mainDisplayDims.y - this.height)*-1)}, Quad.easeInOut);
			}
		}
		
		private function updateLeaves():void {
			for (var count:int = 0; count < this._panelLeaves.length; count++) {
				this._panelLeaves[count].onPanelUpdate();
			}
		}
		
		private function cancelCurrentTween():void {
			if (this._panelSlideTween != null) {
				this._panelSlideTween.cancel();
				this._panelSlideTween.close();
			}
			this._panelSlideTween = null;
		}
		
		public function get widgets():Vector.<IPanelWidget> {
			return (this._widgets);
		}
		
		public function getWidgetAfter(thisWidget:IPanelWidget):IPanelWidget {			
			for (var count:int = 0; count < this._widgets.length; count++) {
				var currentWidget:IPanelWidget = this._widgets[count];
				if (currentWidget == thisWidget) {
					if ((count + 1) >= this._widgets.length) {						
						return (null);
					} else {						
						return (this._widgets[count + 1]);
					}
				}
			}
			return (null);
		}
		
		private function onStageInteract(eventObj:TouchEvent):void {
			if (this._scrolling) {				
				var move:Touch = eventObj.getTouch(this.stage, TouchPhase.MOVED);
				var up:Touch = eventObj.getTouch(this.stage, TouchPhase.ENDED);
				if (move) {
					var movedLocationPoint:Point =  move.getLocation(this.stage);
					this.y = movedLocationPoint.y - this._dragStartPoint.y;
					this.openButton.y = (this.y * -1) + this._openButtonOriginPoint.y;					
					this.closeButton.y = (this.y * -1) + this._closeButtonOriginPoint.y;	
				}
				if (up)	{					
					this._scrolling = false;
					if ((this.y + this.height) < mainDisplayDims.y) {
						this._elasticSnapTween = KTween.to (this, 0.2, {y:(mainDisplayDims.y - this.height)}, Quad.easeInOut);
						this._openButtonTween = KTween.to (this.openButton, 0.2, {y:((mainDisplayDims.y - this.height) *-1)}, Quad.easeInOut);
						this._closeButtonTween = KTween.to (this.closeButton, 0.2, {y:((mainDisplayDims.y - this.height)*-1)}, Quad.easeInOut);
					}
					if (this.y > 0) {
						this._elasticSnapTween = KTween.to (this, 0.2, {y:0}, Quad.easeInOut);
						this._openButtonTween = KTween.to (this.openButton, 0.2, {y:0}, Quad.easeInOut);
						this._closeButtonTween = KTween.to (this.closeButton, 0.2, {y:0}, Quad.easeInOut);
					}
				}				
			} else {
				var down:Touch = eventObj.getTouch(this.stage, TouchPhase.BEGAN);			
				if (down)	{				
					if ((eventObj.target == this.openButton) || (eventObj.target == this.closeButton)) {
						return;
					}
					for (var count:int = 0; count < this._widgets.length; count++) {
						if (eventObj.target == this._widgets[count]) {
							return;
						}
					}
					var localPos:Point = down.getLocation(this);
					if ((localPos.x < 0) || (localPos.x > this.width) || (localPos.y < 0) || (localPos.y > this.height)) {
						return;
					}					
					var stagePos:Point = down.getLocation(this.stage);				
					this._dragStartPoint = new Point(stagePos.x, (stagePos.y - this.y));
					this._scrolling = true;
				}
			}
		}
		
		private function onOpenCloseButtonClick(eventObj:Event):void {
			if (this.isOpen) {								
				this.closePanel();
			} else {			
				this.openPanel();
			}
		}
		
		public function onButtonTweenComplete():void {			
			if (this.openButton.alpha == 0) {
				this.openButton.visible = false;
				this.openButton.removeEventListener(Event.TRIGGERED, this.onOpenCloseButtonClick);
				this.closeButton.removeEventListener(Event.TRIGGERED, this.onOpenCloseButtonClick);
				this.closeButton.addEventListener(Event.TRIGGERED, this.onOpenCloseButtonClick);
			}
			if (this.closeButton.alpha == 0) {
				this.closeButton.visible = false;
				this.closeButton.removeEventListener(Event.TRIGGERED, this.onOpenCloseButtonClick);
				this.openButton.removeEventListener(Event.TRIGGERED, this.onOpenCloseButtonClick);
				this.openButton.addEventListener(Event.TRIGGERED, this.onOpenCloseButtonClick);
			}
		}
		
		private function buttonsToClosedPosition():void {
			this.openButton.alpha = 0;
			this.openButton.visible = true;
			if (this.position == "right") {
				this._openButtonTween = KTween.to(this.openButton, 0.5, { x: this.openButton.width * -1, y:this._openButtonOriginPoint.y, alpha:1 }, Quad.easeInOut, this.onButtonTweenComplete);
				this._closeButtonTween = KTween.to(this.closeButton, 0.5, { x: this.closeButton.width * -1, y:this._closeButtonOriginPoint.y, alpha:0 }, Quad.easeInOut, this.onButtonTweenComplete);
			}
			if (this.position == "bottom") {
				this._openButtonTween = KTween.to(this.openButton, 0.5, { x:this._openButtonOriginPoint.x, y: this.openButton.height * -1, alpha:1 }, Quad.easeInOut, this.onButtonTweenComplete);
				this._closeButtonTween = KTween.to(this.closeButton, 0.5, { x:this._closeButtonOriginPoint.x, y: this.closeButton.height * -1, alpha:0 }, Quad.easeInOut, this.onButtonTweenComplete);
			}
			if (this.position == "left") {					
				this._openButtonTween = KTween.to(this.openButton, 0.5, { x: this.width, y:this._openButtonOriginPoint.y, alpha:1 }, Quad.easeInOut, this.onButtonTweenComplete);
				this._closeButtonTween = KTween.to(this.closeButton, 0.5, { x: this.width, y:this._closeButtonOriginPoint.y, alpha:0 }, Quad.easeInOut, this.onButtonTweenComplete);
			}
		}
		
		private function buttonsToOpenedPosition():void {
			this.closeButton.alpha = 0;
			this.closeButton.visible = true;
			if (this.position == "right") {
				this._openButtonTween = KTween.to(this.openButton, 0.5, { x: 0, y:this._openButtonOriginPoint.y, alpha:0}, Quad.easeInOut, this.onButtonTweenComplete);
				this._closeButtonTween = KTween.to(this.closeButton, 0.5, { x: 0, y:this._closeButtonOriginPoint.y, alpha:1}, Quad.easeInOut, this.onButtonTweenComplete);
			}
			if (this.position == "bottom") {
				this._openButtonTween = KTween.to(this.openButton, 0.5, { x:this._openButtonOriginPoint.x, y:0, alpha:0}, Quad.easeInOut, this.onButtonTweenComplete);
				this._closeButtonTween = KTween.to(this.closeButton, 0.5, { x:this._closeButtonOriginPoint.x, y:0, alpha:1}, Quad.easeInOut, this.onButtonTweenComplete);
			}
			if (this.position == "left") {
				this._openButtonTween = KTween.to(this.openButton, 0.5, { x:0, y:this._openButtonOriginPoint.y, alpha:0}, Quad.easeInOut, this.onButtonTweenComplete);
				this._closeButtonTween = KTween.to(this.closeButton, 0.5, { x:0, y:this._closeButtonOriginPoint.y, alpha:1}, Quad.easeInOut, this.onButtonTweenComplete);
			}
		}		
		
		private function revealPanel(eventObj:Event):void {
			this._revealFrameCounter++;
			this.openButton.invalidate();
			this.closeButton.invalidate();
			this.openButton.x = this._openButtonOriginPoint.x;
			this.openButton.y = this._openButtonOriginPoint.y;
			this.closeButton.x = this._closeButtonOriginPoint.x;
			this.closeButton.y = this._closeButtonOriginPoint.y;
			if (this._revealFrameCounter < 10) {				
				return;
			}
			this.openButton.invalidate();
			this.closeButton.invalidate();
			this.removeEventListener(Event.ENTER_FRAME, this.revealPanel);
			this.visible = true;
			this.closePanel();			
		}
		
		private function drawPanelBackground():void {			
			var bgTexture:Texture = Texture.fromColor(this.width, this.height, this.bgcolor, this.bgalpha);
			this._bgImage = new Image(bgTexture);
			this.addChild(this._bgImage);
			if (this.getChildIndex(this._bgImage) != 0) {
				this.setChildIndex(this._bgImage, 0);
			}
		}
		
		public function update(panelData:XML):void {
			if ((panelData.@width != undefined) && (panelData.@width != null) && (panelData.@width != "") && (panelData.@width != "0")) {
				this._panelData.@widh = panelData.@width;
			}
			if ((panelData.@height != undefined) && (panelData.@height != null) && (panelData.@height != "") && (panelData.@height != "0")) {
				this._panelData.@height = panelData.@height;
			}
			this.removeChild(this._bgImage);
			this.drawPanelBackground();
		}
		
		public function initialize():void {
			DebugView.addText("SlidingPanel.initialize");
			this.stage.addEventListener(TouchEvent.TOUCH, this.onStageInteract);
			this.openButton.useHandCursor = true;
			this.closeButton.useHandCursor = true;
			this.openButton.addEventListener(Event.TRIGGERED, this.onOpenCloseButtonClick);
			this.closeButton.addEventListener(Event.TRIGGERED, this.onOpenCloseButtonClick);
			this._openButtonOriginPoint = new Point(this.openButton.x, this.openButton.y);
			this._closeButtonOriginPoint = new Point(this.closeButton.x, this.closeButton.y);
			this.addEventListener(Event.ENTER_FRAME, this.revealPanel);	
			this.drawPanelBackground();
		}
		
		public function destroy():void {
			this.stage.removeEventListener(TouchEvent.TOUCH, this.onStageInteract);
			this.openButton.removeEventListener(Event.TRIGGERED, this.onOpenCloseButtonClick);
			this.closeButton.removeEventListener(Event.TRIGGERED, this.onOpenCloseButtonClick);
			this.stage.removeEventListener(TouchEvent.TOUCH, this.onStageInteract);
			this.removeEventListener(Event.ENTER_FRAME, this.revealPanel);
			this._openButtonOriginPoint = null;
			this._closeButtonOriginPoint = null;
			if (this._panelSlideTween != null) {
				this._panelSlideTween.close();
				this._panelSlideTween = null;
			}
			if (this._elasticSnapTween != null) {
				this._elasticSnapTween.close();
				this._elasticSnapTween = null;
			}
			if (this._openButtonTween != null) {
				this._openButtonTween.close();
				this._openButtonTween = null;
			}
			if (this._closeButtonTween != null) {
				this._closeButtonTween.close();
				this._closeButtonTween = null;
			}
			for (var count:int = 0; count < this._widgets.length; count++) {
				this._widgets[count].destroy();
				this.removeChild(this._widgets[count] as Sprite);
			}
			this._widgets = null;
			this.removeChild(this.openButton, true);
			this.removeChild(this.closeButton, true);
			this.openButton = null;			
			this.closeButton = null;	
			this._scrolling = false;
			for (count = 0; count < _panels.length; count++) {
				if (_panels[count] == this) {
					_panels.splice(count, 1);
					break;
				}
			}
		}
	}
}
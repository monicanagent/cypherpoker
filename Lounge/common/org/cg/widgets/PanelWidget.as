/**
* Generic panel widget implementation to be extended by custom panel widgets.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
	
	import flash.geom.Point;
	import org.cg.widgets.Widget;
	import starling.display.Sprite;
	import starling.display.DisplayObject;
	import org.cg.interfaces.IPanelWidget;	
	import starling.events.Event;
	import org.cg.SlidingPanel;
	import org.cg.interfaces.ILounge;
	import org.cg.DebugView;
	import net.kawa.tween.KTween;
	import net.kawa.tween.KTJob;	
	import net.kawa.tween.easing.Quad;
	import flash.utils.setTimeout;
	
	public class PanelWidget extends Widget implements IPanelWidget {
				
		private static var _instances:uint = 0; //incrementing instance counter (not reset until application restart)
		private var _instance:uint = 0; //the unique instance number of the current instance, set to the '_instances' value at instantiation time
		private var _panelRef:SlidingPanel; //reference to the parent/containing sliding panel instance
		private var _previousWidget:IPanelWidget = null; //reference to the widget previously added to the parent/containing sliding panel
		private var _currentWidgetDims:Point = new Point(0, 0); //current widget dimensions (upper-left corner is assumed to be at 0,0)
		private var _dimsSampleRate:uint = 1; //frames between widget dimension samples; lower numbers mean smoother animation but slower performance
		private var _dimsCurrentSample:uint = 0; //current sample count
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	loungeRef A reference to the main ILounge implementation instance.
		 * @param	panelRef A reference to the parent or containing SlidingPanel instance.
		 * @param	widgetData The widget's configuration XML data, usually from the global configuration data.
		 */
		public function PanelWidget(loungeRef:ILounge, panelRef:SlidingPanel, widgetData:XML) {
			_instances++;
			this._instance = _instances;
			this._lounge = loungeRef;
			this._panelRef = panelRef;
			this._widgetData = widgetData;
			this.addEventListener(Event.ADDED_TO_STAGE, this.onWidgetAddedToStage);
			super (this._lounge, this._panelRef, widgetData);
		}
		
		/**
		 * @return The X position of the widget adjusted for horizontal padding, as defined by the configuration XML data, or 
		 * the dynamic padding-adjusted X position if not defined in the configuration.
		 */
		override public function get x():Number {
			if ((this._widgetData.@x != undefined) && (this._widgetData.@x != null) &&  (this._widgetData.@x != "")) {
				return (Number(this._widgetData.@x) + this.hPadding);
			}
			return (super.x - this.hPadding);
		}
		
		/**
		 * @return The Y position of the widget adjusted for vertical padding, as defined by the configuration XML data, or 
		 * the dynamic padding-adjusted Y position if not defined in the configuration.
		 */
		override public function get y():Number {
			if ((this._widgetData.@x != undefined) && (this._widgetData.@x != null) &&  (this._widgetData.@x != "")) {
				return (Number(this._widgetData.@x) + this.vPadding);
			}
			return (super.y - this.vPadding);
		}
		
		/**
		 * @return The width of the widget adjusted for horizontal padding (x2), as defined by the configuration XML data, or 
		 * the dynamic padding-adjusted width if not defined in the configuration.
		 */
		override public function get width():Number {
			if ((this._widgetData.@width != null) && (this._widgetData.@width != "") && (this._widgetData.@width != undefined)) {				
				return (Number (this._widgetData.@width) + (this.hPadding*2));
			} else {				
				return (super.width + (this.hPadding*2));
			}
		}
		
		/**
		 * @return The height of the widget adjusted for vertical padding (x2), as defined by the configuration XML data, or 
		 * the dynamic padding-adjusted height if not defined in the configuration.
		 */
		override public function get height():Number {
			if ((this._widgetData.@height != null) && (this._widgetData.@height != "") && (this._widgetData.@height != undefined)) {				
				return (Number (this._widgetData.@height) + (this.vPadding*2));
			} else {
				return (super.height + (this.vPadding*2));
			}
		}
			
		/**
		 * @return The horizontal padding as defined by the configuration XML data or 0 if none is defined.		 
		 */
		public function get hPadding():Number {
			if ((this._widgetData.@hpadding != null) && (this._widgetData.@hpadding != "") && (this._widgetData.@hpadding != undefined)) {				
				return (Number (this._widgetData.@hpadding));
			} else {
				return (0);
			}
		}
		
		/**
		 * @return The vertical padding as defined by the configuration XML data or 0 if none is defined.		 
		 */
		public function get vPadding():Number {
			if ((this._widgetData.@vpadding != null) && (this._widgetData.@vpadding != "") && (this._widgetData.@vpadding != undefined)) {				
				return (Number (this._widgetData.@vpadding));
			} else {
				return (0);
			}
		}
		
		/**
		 * @return The left offset position as defined by the configuration XML data or 0 if none is defined.		 
		 */
		public function get left():Number {
			if ((this._widgetData.@left != null) && (this._widgetData.@left != "") && (this._widgetData.@left != undefined)) {				
				return (Number (this._widgetData.@left));
			} else {
				return (0);
			}
		}
		
		/**
		 * @return The top offset position as defined by the configuration XML data or 0 if none is defined.		 
		 */
		public function get top():Number {
			if ((this._widgetData.@top != null) && (this._widgetData.@top != "") && (this._widgetData.@top != undefined)) {				
				return (Number (this._widgetData.@top));
			} else {
				return (0);
			}
		}
		
		/**
		 * @return A reference to the parent or containing SlidingPanel instance.
		 */
		public function get panel():SlidingPanel {
			return (this._panelRef);
		}
				
		/**
		 * A reference to the previously added widget instance in the parent 'panel', or null if this is the first added widget.
		 */
		public function set previousWidget(widgetSet:IPanelWidget):void {
			this._previousWidget = widgetSet;
		}
		
		public function get previousWidget():IPanelWidget {
			return (this._previousWidget);
		}
		
		/**
		 * Initializes the panel widget after it's been added to the display list and all configuration data/components have been added.
		 */
		override public function initialize():void {
			super.initialize();
		}
		
		/**
		 * Activates the widget by opening the parent panel and scrolling it to the position of this widget.
		 * 
		 * @param	includeParent True if any parent panels or components should also be activated.
		 */
		override public function activate(includeParent:Boolean = true):void {
			this.panel.openPanel();
			this.panel.scrollTo(this);
		}
		
		/**
		 * Aligns this widget to the previous widget added to the parent panel. If this is the first widget in the parent panel it is aligned
		 * to the configured top/left position. All following widgets are aligned to this widget via their 'alignToPrevious' methods.
		 */
		public function alignToPrevious():void {
			if (this._previousWidget == null) {
				return;
			}
			var bottomPosition:Number = Number.NEGATIVE_INFINITY;			
			var previousWidgetRef:IPanelWidget = this._previousWidget;	
			var nextWidget:IPanelWidget = this.panel.getWidgetAfter(this);
			if (previousWidgetRef == null) {
				//don't align first widget (may be sliding panel control button)
				if (nextWidget != null) {
					//a delay could be added here for a nice effect
					nextWidget.alignToPrevious();	
				}
				return;			
			}
			while (previousWidgetRef != null) {
				if (bottomPosition < (previousWidgetRef.y + previousWidgetRef.height)) {
					bottomPosition = previousWidgetRef.y + previousWidgetRef.height;					
				}
				previousWidgetRef = previousWidgetRef.previousWidget;
			} 
			if ((this._previousWidget.x + this._previousWidget.width + this.width + this.hPadding + this.left) > this._panelRef.width) {				
				this.x = this._previousWidget.x + this.hPadding;				
				if ((this.x + this.width + this.hPadding + this.left) > this._panelRef.width) {
					this.x = this.hPadding + this.left;
					this.y = bottomPosition + this.vPadding + this.top;					
				} else {										
					this.x = this.hPadding + this.left;
					this.y = this._previousWidget.y + this._previousWidget.height + this.vPadding + this.top;										
				}
			} else {				
				this.x = this._previousWidget.x + this._previousWidget.width + this.hPadding + this.left;
				this.y = this._previousWidget.y + this.vPadding + this.top;
			}						
			//it would be more efficient to add a reference at instantiation time			
			if (nextWidget != null) {
				//a delay could be added here for a nice effect
				nextWidget.alignToPrevious();	
			}			
		}
		
		/**
		 * Prepares the widget for removal from memory by removing any event listeners, clearing references, and calling 'destroy' in the super
		 * class.
		 */
		override public function destroy():void {
			this.removeEventListener(Event.ENTER_FRAME, this.checkWidgetDims);
			this._currentWidgetDims = null;
			this._panelRef.removeWidget(this);
			this._panelRef = null;			
			super.destroy();
		}
		
		/**
		 * Event listener invoked when the widget has been added to the display list. A widget dimensions check ('startCheckWidgetDims') is started
		 * in order to capture the widget's dimensions if any children have not yet been fully constructed.
		 * 
		 * @param	eventObj An Event object.
		 */
		protected function onWidgetAddedToStage(eventObj:Event):void {			
			eventObj.target.removeEventListener(Event.ADDED_TO_STAGE, this.onWidgetAddedToStage);
			super.x = this.hPadding + this.left;
			super.y = this.vPadding + this.top;
			this._dimsCurrentSample = 0;
			this.startCheckWidgetDims();
		}
		
		/**
		 * Stops checking for changes in the widget's dimensions.
		 */
		protected function stopCheckWidgetDims():void {
			this.removeEventListener(Event.ENTER_FRAME, this.checkWidgetDims);
		}
		
		/**
		 * Begins checking for changes in the widget's dimenions by calling 'checkWidgetDims' on each frame.
		 */
		protected function startCheckWidgetDims():void {
			this.stopCheckWidgetDims();
			this.addEventListener(Event.ENTER_FRAME, this.checkWidgetDims);
		}
		
		/**
		 * Event listener called on each frame to check for changes in the widget's dimensions. Whenever the dimensions change
		 * all of the following widgets' 'alignToPrevious' methods are called to align them to this widget.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function checkWidgetDims(eventObj:Event):void {
			this._dimsCurrentSample++;
			if (this._dimsCurrentSample < this._dimsSampleRate) {
				return;
			}
			if ((this.width != this._currentWidgetDims.x) || (this.height != this._currentWidgetDims.y)) {
				var nextWidget:IPanelWidget = this.panel.getWidgetAfter(this);
				if (nextWidget != null) {
					nextWidget.alignToPrevious();
				}
				this._currentWidgetDims.x = this.width;
				this._currentWidgetDims.y = this.height;				
			}
			this._dimsCurrentSample = 0;
			var myIndex:int = this.parent.getChildIndex(this);
			var lastIndex:int = this.parent.getChildIndex(this.panel.widgets[this.panel.widgets.length - 1] as Sprite);
			if (myIndex < lastIndex) {
				this.parent.swapChildrenAt(myIndex, lastIndex);
			}
		}
	}
}
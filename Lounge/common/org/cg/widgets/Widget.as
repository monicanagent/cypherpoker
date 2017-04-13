/**
* Basic widget implementation intended to be added to any Starling display list, panel, or panel leaf.
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
		
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.IWidget;
	import starling.display.Sprite;
	import org.cg.DebugView;
	import flash.utils.getQualifiedClassName;

	public class Widget extends Sprite implements IWidget {
		
		protected var _lounge:ILounge = null; //reference to the main lounge instance
		protected var _container:* = null; //reference to the parent display container of the widget
		protected var _widgetData:XML = null; //widget configuration data, usually from global settings
		protected static var _widgets:Vector.<IWidget> = new Vector.<IWidget>(); //all currently active widget instances
		
		/**
		 * Create a new instance.
		 * 
		 * @param	loungeRef A reference the main ILounge implementation instance.
		 * @param	containerRef A reference to the widget's container display object.
		 * @param	widgetData The widget's configuration data, usually from the global settings data.
		 */
		public function Widget(loungeRef:ILounge, containerRef:*, widgetData:XML) {
			_widgets.push(this);
			this._lounge = loungeRef;
			this._container = containerRef;
			this._widgetData = widgetData;
		}
		
		/**
		 * @return A reference fo the main ILounge implementation instance.
		 */
		public function get lounge():ILounge {
			return (this._lounge);
		}
		
		/**
		 * @return A reference to the widget's container display object.
		 */
		public function get container():* {
			return (this._container);
		}
		
		/**
		 * @return The widget's configuration XML data, usually from the global settings XML data.
		 */
		public function get widgetData():XML {
			return (this._widgetData);
		}
		
		/**
		 * Returns all active instances of a specific widget matching a fully qualified class name.
		 * 
		 * @param	findClassName The fully qualified class name of the widget instance(s) to find.
		 * 
		 * @return A vector array of all currently active widgets matching the 'findClassName' parameter.
		 */
		public static function getInstanceByClass(findClassName:String):Vector.<IWidget> {
			var returnWidgets:Vector.<IWidget> =  new Vector.<IWidget>();
			if ((findClassName == null) || (findClassName == "")) {
				return (returnWidgets);
			}
			for (var count:int = 0; count < _widgets.length; count++) {
				var currentClassName:String = getQualifiedClassName(_widgets[count]);
				currentClassName = currentClassName.split("::").join("."); //convert to standard dot notation
				if (currentClassName == findClassName) {
					returnWidgets.push(_widgets[count]);
				}
			}
			return (returnWidgets);
		}
		
		/**
		 * Initializes the newly created widget instance. It is up to the extending object to implement this method but it should
		 * be assumed that the widget has already been added to the display list and that any properties that will be populated
		 * by classes such as the StarlingViewManager will be ready prior to calling this method.
		 */
		public function initialize():void {
		}
		
		/**
		 * Activates / puts focus on the widget. It is up to the extending object to decide how a widget activation is implemented.
		 * 
		 * @param	includeParent If true the widget's parent container is also activated, if false only the widget is activated. The extending
		 * object specifies how this behaviour is implemented.
		 */
		public function activate(includeParent:Boolean = true):void {
		}
		
		/**
		 * Removes the widget from memory and the display list by removing it from its parent display object. Extending objects should
		 * always invoke this method via a 'super' call after performing their own cleanup.
		 */
		public function destroy():void {
			this._lounge = null;
			this._container = null;
			this._widgetData = null;
			var count:int = 0;
			var widgetInst:IWidget = _widgets[count];
			while (widgetInst != null) {
				if (widgetInst == this) {
					_widgets.splice(count, 1);
				}
				count++;
				if (count < _widgets.length) {
					widgetInst = _widgets[count];
				} else {
					widgetInst = null;
				}
			}
			this.removeFromParent(true);
		}
	}
}
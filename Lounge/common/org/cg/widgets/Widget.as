/**
* Basic widget implementation intended to be added to any Starling display list
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
	import flash.utils.getQualifiedClassName;

	public class Widget extends Sprite implements IWidget {
		
		protected var _lounge:ILounge = null;
		protected var _container:* = null;
		protected var _widgetData:XML = null;
		protected static var _widgets:Vector.<IWidget> = new Vector.<IWidget>(); //all properly instantiated widget instances
		
		public function Widget(loungeRef:ILounge, containerRef:*, widgetData:XML) {
			_widgets.push(this);
			this._lounge = loungeRef;
			this._container = containerRef;
			this._widgetData = widgetData;
		}
		
		public function get lounge():ILounge {
			return (this._lounge);
		}
		
		public function get container():* {
			return (this._container);
		}
		
		public function get widgetData():XML 		{
			return (this._widgetData);
		}
		
		public function activate(includeParent:Boolean = true):void {
		}
		
		public function initialize():void {
		}
		
		public function getInstanceByClass(findClassName:String):Vector.<IWidget> {
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
		
		public function destroy():void 	{
			this._lounge = null;
			this._container = null;
			this._widgetData = null;
		}
		
	}

}
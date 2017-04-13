/**
* Used to launch a new application window with its own, isolated lounge.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
package org.cg.widgets {
	
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.IPanelWidget;
	import org.cg.SlidingPanel;
	import starling.events.Event;
	import feathers.controls.Button;
	import org.cg.DebugView;

	public class NewWindowWidget extends PanelWidget implements IPanelWidget {
		
		//UI rendered by StarlingViewManager:
		public var openNewWindowButton:Button;
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	loungeRef A reference to the main ILounge implementation instance.
		 * @param	panelRef The widget's parent panel or display object container.
		 * @param	widgetData The widget's configuration XML data, usually from the global settings data.
		 */
		public function NewWindowWidget(loungeRef:ILounge, panelRef:SlidingPanel, widgetData:XML) {
			DebugView.addText("NewWindowWidget created");
			super(loungeRef, panelRef, widgetData);
		}
		
		/**
		 * Initializes the widget after it's been added to the display list and when its components have been rendered.
		 */
		override public function initialize():void {
			DebugView.addText("NewWindowWidget.initialize");
			this.openNewWindowButton.addEventListener(Event.TRIGGERED, this.onOpenNewWindowClick);
			super.initialize();
		}
		
		/**
		 * Event listener invoked when the "open new window" button is clicked. This opens a new application window
		 * using the main lounge's 'launchNewLounge' method.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onOpenNewWindowClick(eventObj:Event):void {
			lounge.launchNewLounge();
		}		
	}
}
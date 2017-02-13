/**
* Used to launch a new window instance with a unique and isolated lounge.
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
		
		public var openNewWindowButton:Button;
		
		public function NewWindowWidget(loungeRef:ILounge, panelRef:SlidingPanel, widgetData:XML) {
			DebugView.addText("NewWindowWindget created");
			super(loungeRef, panelRef, widgetData);
		}
		
		private function onOpenNewWindowClick(eventObj:Event):void {
			DebugView.addText("NewWindowWidget.onOpenNewWindowClick");
			lounge.launchNewLounge();
		}
		
		override public function initialize():void {
			DebugView.addText("NewWindowWindget.initialize");
			this.openNewWindowButton.addEventListener(Event.TRIGGERED, this.onOpenNewWindowClick);
			super.initialize();
		}
	}
}
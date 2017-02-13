/**
* Interface for a dynamic panel widget implementation.
* 
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {
	
	import org.cg.interfaces.ILounge;
	import org.cg.SlidingPanel;
	import org.cg.interfaces.IWidget;
	
	public interface IPanelWidget extends IWidget {
				
		function get panel():SlidingPanel; //the parent SlidingPanel instance
		function get hPadding():Number; //horizontal padding of widget
		function get vPadding():Number; //vertical padding of widget
		function set previousWidget(widgetSet:IPanelWidget):void; //previous panel reference (used for alignment)
		function get previousWidget():IPanelWidget;
		function alignToPrevious():void; //align widget to previous widget within the available space of the parent sliding panel				
	}
}
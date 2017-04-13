/**
* Interface for dynamic panel leaf that may be appended to an existing panel (for example, a SlidingPanel instance).
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {	
	
	public interface IPanelLeaf {
		
		function set panel(panelSet:ISlidingPanel):void; //reference to the parent / controlling panel instance
		function get panel():ISlidingPanel;
		function get position():String; //leaf position according to definition XML data (should match parent panel's position property).		
		//Offset from associated sliding panel, in pixels
		function get hOffset():Number;
		function get vOffset():Number;
		function onPanelUpdate():void; //invoked by parent panel whenever its position/size/visibility/etc. have changed
		function initialize():void; //called by the view manager when all UI components and leaf data are ready
		function destroy():void; //prepares the IPanelLeaf instance for removal from application memory
		//Standard display object properties:
		function get width():Number;
		function get height():Number;
	}
}
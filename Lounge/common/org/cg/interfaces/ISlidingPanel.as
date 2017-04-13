/**
* Interface for dynamic sliding panel container.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {
	
	import org.cg.interfaces.IPanelWidget;
	import org.cg.interfaces.IPanelLeaf;
	
	public interface ISlidingPanel {

		function get position():String; //"left", "right", or "bottom"
		function set position(posSet:String):void;
		function get isOpen():Boolean; //is panel currently open?
		function get isOpening():Boolean; //is panel currently opening?
		function get widgets():Vector.<IPanelWidget>;
		function openPanel():void; //begin open animation
		function closePanel():void; //begin closing animation
		function scrollTo(widget:IWidget):void; //scroll the panel to the specified widget		
		function addPanelLeaf(leafRef:IPanelLeaf):void; //add a new IPanelLeaf implementation to the ISlidingPanel implementation
		function removePanelLeaf(leafRef:IPanelLeaf):void; //remve an IPanelLeaf implementation from the ISlidingPanel implementation
		function get panelLeaves():Vector.<IPanelLeaf>; //all IPanelLeaf implementations associated with the ISlidingPanel implementation
		function initialize():void; //called by view manager when view has been initialized (all UI components created and data initialized)
		function update(panelData:XML):void; //update the panel's base settings, such as width and height, using the supplied panel data
		function destroy():void; //prepare the panel for removal from application memory
		//Standard display object properties:
		function get width():Number;
		function get height():Number;
		function get x():Number;
		function get y():Number;
		function set x(xSet:Number):void;
		function set y(ySet:Number):void;
	}	
}
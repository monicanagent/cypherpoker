/**
* Interface for a generic widget that may be added to any Starling display list.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/


package org.cg.interfaces {
	
	import org.cg.interfaces.ILounge;			
	
	public interface IWidget {
		
		function get lounge():ILounge; //the current Lounge instance
		function get container():*; //the container, usually a display object of some sort
		function get widgetData():XML; //the assigned widget descriptor
		function activate(includeParent:Boolean = true):void; //activate the widget, optionally activating any parent container as well		
		function initialize():void; //called by view manager when all components and data have been initialized
		function destroy():void; //clean up in preparation for removal from memory
		//Standard display object properties
		function get y():Number;
		function get x():Number;
		function get width():Number;
		function get height():Number;
		function get alpha():Number;
		function get visible():Boolean;
		function set y(ySet:Number):void;
		function set x(ySet:Number):void;
		function set width(widthSet:Number):void;
		function set height(heightSet:Number):void;
		function set alpha(alphaSet:Number):void;
		function set visible(visibleSet:Boolean):void;
	}	
}
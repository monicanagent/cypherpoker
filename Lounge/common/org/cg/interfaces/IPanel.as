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
		
	public interface IPanel {
		
		function get position():String; //"left", "right", or "bottom"
		function set position(posSet:String):void;
		function render():void; //render the panel contents using ViewManager		
	}	
}
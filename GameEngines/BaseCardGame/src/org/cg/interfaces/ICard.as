/**
* Interface for a Card implementation.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces 
{
	
	public interface ICard 
	{
		//Refreshes the implementation's graphical elements
		function refreshCard():Boolean;
		//Scales the card faces to the target width value.
		function scaleToWidth(widthVal:Number):void;		
		//Scales the card faces to the target height value.
		function scaleToHeight(heightVal:Number):void;
		//True if the card is currently facing up.
		function get faceUp():Boolean;		
		//The low or standard value of the card as defined in the settings data.
		function get faceValue():int;
		//The high value of the card as defined in the settings data. If not defined, faceValue is returned.
		function get faceValueHigh():int;
		//The textual name of the card as defined in the settings data.
		function get faceText():String;		
		//The textual name of the card color as defined in the settings data.
		function get faceColor():String;
		//The name of the card suit as defined in the settings data.
		function get faceSuit():String;
		//The descriptive name of the card as defined in the settings data.
		function get cardName():String;
		//The fully qualified class name used to instantiate the card's front face.
		function get frontClassName():String;
		//The fully qualified class name used to instantiate the card's back face.
		function get backClassName():String;
		//The class to be instantiated for the front face. Must be instantiable to a DisplayObject type.
		function get frontClass():Class;
		function set frontClass(classSet:Class):void;
		//The class to be instantiated for the back face. Must be instantiable to a DisplayObject type.
		function get backClass():Class;
		function set backClass(classSet:Class):void;
		//Fade the card to alpha 1.
		function fadeIn(duration:Number = 1):void;		
	}
}
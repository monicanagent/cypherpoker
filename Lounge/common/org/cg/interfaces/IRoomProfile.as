/**
* Interface for a room profile implementation that supplies information such as the user handle and icon.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {
		
	import flash.display.BitmapData;
	import flash.utils.ByteArray;
	import starling.textures.Texture;
	import starling.display.Image;
	
	public interface IRoomProfile 	{
		
		function get profileData():XML; //reference to the profile data XML in the global settings data
		function get profileHandle():String; //the user handle		
		function get iconPath():String; //path to the user icon on disk or remote server
		function get iconData():BitmapData; //loaded BitmapData of user icon, usually scaled
		function get newIconTexture():Texture; //Feathers Texture of loaded user icon, usually scaled
		function get newIconImage():Image; //Feathers Image of loaded user icon, usually scaled
		function get newIconByteArray():ByteArray; //ByteArray data of loaded user icon, usually scaled
		function get iconLoaded():Boolean; //is user icon loaded?		
		function load(createIfMissing:Boolean = true):void; //load or reload profile data from global settings data, optionally creating required nodes if missing
	}	
}
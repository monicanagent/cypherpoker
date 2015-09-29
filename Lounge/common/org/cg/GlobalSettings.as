/**
* A singleton that manages global XML settings for the application.
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg 
{
	
	import flash.events.EventDispatcher;
	import org.cg.events.SettingsEvent;	
	import flash.net.SharedObject;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.events.Event;
	import flash.events.IOErrorEvent;	
	import flash.system.Capabilities;
		
	public class GlobalSettings 
	{
						
		private static var _settingsLoader:URLLoader;
		private static var _settingsFilePath:String = "xml/settings.xml"; //relative location of default settings file
		private static var _settingsData:XML;		
		private static const _SOName:String = "CypherPoker"; //Local Shared Object name
		private static var _isDynamic:Boolean = true;
		private static var _dispatcher:EventDispatcher = new EventDispatcher(); //So that the singleton can dispatch events
		private static var _systemSettings:Object=null; //Populated with discovered system settings
		private static const _mobileOS:Array=["AND", "iPhone", "Windows SmartPhone", "Windows PocketPC", "Windows CEPC", "Windows Mobile"];
		
		/**
		 * The default settings file path specified in the class.
		 */
		public static function get defaultSettingsFilePath():String 
		{
			return (_settingsFilePath);
		}
		
		/**
		 * An EventDisatcher instance used by this singleton to broadcast events. Add SettingsEvent
		 * listeners to this instance to receive dispatched from the GlobalSettings class.
		 */
		public static function get dispatcher():EventDispatcher 
		{
			return (_dispatcher);
		}
		
		/**
		 * An object containing host environment data.
		 */
		public static function get systemSettings():Object 
		{			
			if (_systemSettings==null) {
				updateSystemSettingsObject();
			}
			return (_systemSettings);
		}
		/**
		 * The entire XML settings data object.
		 */
		public static function get data():XML 
		{
			if (_settingsData == null) {				
				return (null);
			}			
			return (_settingsData);
		}

		/**
		 * If true, data assigned to the GlobalSettings data will be created if it doesn't
		 * already exist. If false and the data doesn't already exist, the operation will
		 * fail.
		 */
		public static function set isDynamic(dynamicSet:Boolean):void 
		{
			_isDynamic = dynamicSet;
		}
		
		public static function get isDynamic():Boolean 
		{
			return (_isDynamic);
		}
		
		/**
		 * Updates the internal system settings object with discovered environment data. 
		 * Adapted from the SWAG ActionScript toolkit: https://code.google.com/p/swag-as/
		 */
		private static function updateSystemSettingsObject():void {					
			_systemSettings=new Object();				
			_systemSettings.os = Capabilities.os;
			var environStr:String = new String(_systemSettings.os);
			environStr = environStr.toLowerCase();
			if (environStr.indexOf("windows")>-1) {
				_systemSettings.environment = "win";
			}//if			
			if (environStr.indexOf("mac os")>-1) {
				_systemSettings.environment = "macos";
			}//if
			if (environStr.indexOf("android")>-1) {
				_systemSettings.environment = "android";
			}//if
			if (environStr.indexOf("iphone")>-1) {
				_systemSettings.environment = "iphone";
			}//if	
			if (environStr.indexOf("linux")>-1) {
				_systemSettings.environment = "linux";
			}//if
			//Now add custom settings properties...
			_systemSettings.isAIR=new Boolean();
			_systemSettings.isWeb=new Boolean();
			_systemSettings.isStandalone=new Boolean();
			_systemSettings.isMobile=new Boolean();			
			if ((Capabilities.playerType=="ActiveX") || (Capabilities.playerType=="PlugIn")) {
				_systemSettings.isAIR=false;
				_systemSettings.isWeb=true;
				_systemSettings.isStandalone=false;
			}//if
			if (Capabilities.playerType=="Desktop") {
				_systemSettings.isAIR=true;
				_systemSettings.isWeb=false;
				_systemSettings.isStandalone=false;
			}//if
			if ((Capabilities.playerType=="External") || (Capabilities.playerType=="StandAlone")) {
				_systemSettings.isAIR=false;
				_systemSettings.isWeb=false;
				_systemSettings.isStandalone=true;
			}//if
			_systemSettings.isMobile=false;
			if (stringContains(_mobileOS, Capabilities.os, false)) {
				_systemSettings.isMobile=true;
			}//if
			if (stringContains(_mobileOS, Capabilities.version, false)) {
				//Detects "AND" (Android)
				_systemSettings.isMobile=true;
			}//if
			if (Capabilities.cpuArchitecture=="ARM") {
				_systemSettings.isMobile=true;
			}//if			
		}
		
		/**
		 * Scans a source string for occurances of a search string.
		 * Adapted from the SWAG ActionScript toolkit: https://code.google.com/p/swag-as/
		 * 
		 * @param	sourceString The string, array of strings, or XML document to search through.
		 * @param	searchString The string to find within the source,
		 * @param	caseSensitive Is search case sensitive?
		 * 
		 * @return True if the source string contains the search string, false otherwise.
		 */
		private static function stringContains(sourceString:*, searchString:String, caseSensitive:Boolean=true):Boolean {
			if ((sourceString==null) || (searchString==null)) {
				return (false);
			}//if			
			if (sourceString is String) {
				var localSourceString:String=new String(sourceString);
				var localSearchString:String=new String(searchString);
				if (!caseSensitive) {
					localSourceString=localSourceString.toLowerCase();
					localSearchString=localSearchString.toLowerCase();
				}//if
				if (localSourceString.indexOf(localSearchString)>-1) {
					return (true);
				} else {
					return (false);
				}//else
			} else if (sourceString is Array) {
				localSearchString=new String(searchString);
				if (!caseSensitive) {					
					localSearchString=localSearchString.toLowerCase();
				}//if
				for (var count:uint=0; count<sourceString.length; count++) {
					localSourceString=new String(sourceString[count] as String);
					if (!caseSensitive) {
						localSourceString=localSourceString.toLowerCase();						
					}//if
					if (localSourceString.indexOf(localSearchString)>-1) {
						return (true);
					} else {
						return (false);
					}//else
				}//for			
			} else {
				return (false);
			}//else
			return (false);
		}//stringContains
		
		/**
		 * Converts an input value to a native Boolean value.		 
		 * 
		 * @param inputVal The input value to convert to a native Boolean. Valid input values
		 * include the all numeric and string types matching stringified values: "true",
		 * "false", "t", "f", "1", "0", "on", "off", "enable", "disable", "enabled", "disabled".		 
		 * 
		 * @return A native Boolean representation of the input value. False is returned as default
		 * if the input value can't be converted or is invalid.
		 */
		public static function toBoolean(inputVal:*):Boolean 
		{
			try {
				var boolStr:String = new String(inputVal);
				boolStr = boolStr.toLowerCase();
				boolStr = boolStr.split(String.fromCharCode(32)).join("");
				switch (boolStr) {
					case "true" : return (true); break;
					case "false" : return (false); break;
					case "t" : return (true); break;
					case "f" : return (false); break;
					case "1" : return (true); break;
					case "0" : return (false); break;
					case "on" : return (true); break;
					case "off" : return (false); break;
					case "enable" : return (true); break;
					case "disable" : return (false); break;
					case "enabled" : return (true); break;
					case "disabled" : return (false); break;
					default : return (Boolean(String(inputVal))); break;
				}
			} catch (err:*) {
				return (false);
			}
			return (false);
		}
		
		/**
		 * Load settings data from an external XML file.
		 * 
		 * @param	filePath The path of the XML file to load. If null or blank the default file path will
		 * be used.
		 * @param   reset If true the default settings data will be loaded and will replace any saved settings data.
		 * If false saved settings data will be loaded unless it doesn't exist in which case default data will be
		 * loaded.
		 */
		public static function loadSettings(filePath:String = null, reset:Boolean = false):void 
		{
			if ((filePath == null) || (filePath == "")) {
				filePath = _settingsFilePath;
			}
			_settingsFilePath = filePath;
			if (_settingsLoader != null) {
				_settingsLoader.removeEventListener(Event.COMPLETE, onLoadSettings);
				_settingsLoader.removeEventListener(IOErrorEvent.IO_ERROR, onLoadSettingsError);
				_settingsLoader = null;
			}
			if (!reset) {
				try {
					var sharedObject:SharedObject = SharedObject.getLocal(_SOName);
					_settingsData = sharedObject.data.settings;
					if ((_settingsData == null) || (_settingsData.toString == "")) {						
						reset = true;
					} else {
						_settingsData.@reset = "false";						
						dispatchLoadComplete();
						return;
					}
				} catch (err:*) {
					reset = true;
				}
			}
			if (reset) {				
				var request:URLRequest = new URLRequest(filePath);
				_settingsLoader = new URLLoader();
				_settingsLoader.dataFormat = URLLoaderDataFormat.TEXT;
				_settingsLoader.addEventListener(Event.COMPLETE, onLoadSettings);
				_settingsLoader.addEventListener(IOErrorEvent.IO_ERROR, onLoadSettingsError);
				_settingsLoader.load(request);				
			}
		}
		
		/**
		 * Forces the current XML settings data to be saved to the local shared object.
		 * 
		 * @return True if the settings could be successfully saved and false otherwise.
		 */
		public static function saveSettings():Boolean 
		{
			try {
				var sharedObject:SharedObject = SharedObject.getLocal(_SOName);
				sharedObject.data.settings = _settingsData;				
				sharedObject.flush();
			} catch (err:*) {
				return (false);
			}
			return (false);
		}		
		
		/**
		 * Returns asettings category node from the loaded XML settings.
		 
		 * @param	categoryName The settings category node to retrieve.
		 * 
		 * @return The first found XML settings node or null.
		 */
		public static function getSettingsCategory(categoryName:String):XML 
		{
			try {
				var childNodes:XMLList = data.child(categoryName);
				if (childNodes.length() < 1) {
					return (null);
				} else {
					return (childNodes[0] as XML);
				}
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Returns the XML contants of a settings node within a specified category.
		 * 
		 * @param	categoryName The name of the settings category to find.
		 * @param	settingName The setting name within the category to find.
		 * 
		 * @return The XML node containing the specified setting data or null.
		 */
		public static function getSetting(categoryName:String, settingName:String):XML 
		{
			try {
				var categoryNode:XML = getSettingsCategory(categoryName);
				if (categoryNode == null) {
					return (null);
				}
				var childNodes:XMLList = categoryNode.child(settingName);
				if (childNodes.length() < 1) {
					return (null);
				} else {
					return (childNodes[0] as XML);
				}
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Returns the string contants of a settings node within a specified category.
		 * 
		 * @param	categoryName The name of the settings category to find.
		 * @param	settingName The setting name within the category to find.
		 * 
		 * @return The string content of the first matching node or null.
		 */
		public static function getSettingData(categoryName:String, settingName:String):String 
		{
			try {
				var categoryNode:XML = getSettingsCategory(categoryName);
				if (categoryNode == null) {
					return (null);
				}
				if ((categoryNode == "") || (settingName=="")) {
					return (null);
				}
				var childNodes:XMLList = categoryNode.child(settingName);
				if (childNodes.length() < 1) {
					return (null);
				} else {
					var currentChild:XML = childNodes[0] as XML;
					var childData:String = new String(currentChild.children().toString());
					return (childData);
				}
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Sets a setting within the Settings data. If a category or setting name dosn't exist
		 * they will be created.
		 * 
		 * @param	categoryName The settings category node to update.
		 * @param	settingName The setting to update.
		 * @param 	data The data to assign to the target setting.
		 * 
		 * @return An updated or new settings node, or null if an error occurred.
		 */
		public static function setSettingData(categoryName:String, settingName:String, settingData:String):XML 
		{
			if ((categoryName == null) || (settingName == null)) {
				return (null);
			}
			try {				
				var categoryNode:XML = getSettingsCategory(categoryName);
				if (categoryNode == null) {
					if (isDynamic) {						
						var newNodeStr:String = "<" + categoryName + " />";
						categoryNode = new XML(newNodeStr);
						data.appendChild(categoryNode);
					} else {
						return (null);
					}
				}
				var childNodes:XMLList = categoryNode.child(settingName);
				if (childNodes.length() < 1) {
					if (isDynamic) {						
						newNodeStr = "<" + settingName + " />";
						var currentChild:XML = new XML(newNodeStr);
						categoryNode.appendChild(currentChild);																		
					} else {
						return (null);
					}					
				} else {
					currentChild = childNodes[0] as XML;						
				}
				if (settingData != null) {
					var childData:String = "<![CDATA[" + settingData + "]]>";
					var dataNode:XML = new XML(childData);
					currentChild.setChildren(dataNode);		
				}				
				return (currentChild);
			} catch (err:*) {
				return (null);
			}	
			return (null);
		}
		
		/**
		 * Dispatches a SettingsEvent.LOAD event upon successful completion of
		 * settings data loading and parsing.
		 */
		private static function dispatchLoadComplete():void 
		{			
			var event:SettingsEvent = new SettingsEvent(SettingsEvent.LOAD);
			_dispatcher.dispatchEvent(event);
		}
		
		/**
		 * Dispatches a SettingsEvent.LOADERROR event when a settings load operation
		 * has failed.
		 */
		private static function dispatchLoadError():void 
		{
			var event:SettingsEvent = new SettingsEvent(SettingsEvent.LOADERROR);
			_dispatcher.dispatchEvent(event);
		}
		
		/**
		 * Invoked when settings data has been loaded.
		 * 
		 * @param	eventObj An Event bject.
		 */
		private static function onLoadSettings(eventObj:Event):void 
		{			
			_settingsLoader.removeEventListener(Event.COMPLETE, onLoadSettings);
			_settingsLoader.removeEventListener(IOErrorEvent.IO_ERROR, onLoadSettingsError);
			try {
				_settingsData = new XML(String(_settingsLoader.data));				
				_settingsData.@reset = "true";
				_settingsLoader = null;			
				dispatchLoadComplete();
			} catch (err:*) {				
				dispatchLoadError();
			}
		}
		
		/**
		 * Invoked when settings data has failed to load.
		 * 
		 * @param	eventObj
		 */
		private static function onLoadSettingsError(eventObj:Event):void 
		{				
			_settingsLoader.removeEventListener(Event.COMPLETE, onLoadSettings);
			_settingsLoader.removeEventListener(IOErrorEvent.IO_ERROR, onLoadSettingsError);
			_settingsData = null;
			dispatchLoadError();			
		}
		
		/**
		 * Creates a native variable from a XML data definition. 
		 * Used in conjunction with the createVarNode function.
		 * 
		 * @param	sourceNode The XML node containing the data definition.
		 * 
		 * @return The native value created from the source data definition or null if
		 * an error occurred.
		 */
		private static function createVariable(sourceNode:XML):* 
		{
			var varType:String = sourceNode.@type;
			switch (varType) {
				case "Number" :
					return (Number(sourceNode.children().toString()));
					break;
				case "String" :
					return (String(sourceNode.children().toString()));
					break;
				case "Boolean" :
					return (Boolean(sourceNode.children().toString()));
					break;
				case "XML" :
					return (new XML(sourceNode.children().toString()));
					break;
				case "XMLList" :
					return (new XMLList(sourceNode.children().toString()));
					break;					
				case "int" :
					return (int(sourceNode.children().toString()));
					break;
				case "uint" :
					return (uint(sourceNode.children().toString()));
					break;
				default:
					return (null);
					break;
			}
			return (null);
		}
		
		/**
		 * Creates a variable XML node in the settings data. Used in conjunction with createVariable
		 * function.
		 * 
		 * @param	varName The variable name to create in the settings data.
		 * @param	varType The variable type to include with the settings data.
		 * @param	varData The data to store with the settings data.
		 * 
		 * @return The new variable XML node or null if an error occurred.
		 */
		private static function createVarNode(varName:String, varType:String, varData:String):XML 
		{
			var varNode:XML = new XML("<" + varName + " />");
			varNode.@type = varType;
			var dataNode:XML = new XML("<![CDATA[" + varData + "]]>");
			varNode.appendChild(dataNode);			
			return (varNode);
		}
		
		/**
		 * Checks if a data type can be converted to a string and stored in a save state operation.
		 * 
		 * @param	typeDef The data type to test.
		 * 
		 * @return True if the type can be stringified and saved.
		 */
		private static function isValidSaveStateType(typeDef:String):Boolean 
		{
			switch (typeDef) {				
				case "Number" :
					return (true);
					break;
				case "String" :
					return (true);
					break;
				case "Boolean" :
					return (true);
					break;
				case "XML" :
					return (true);
					break;
				case "XMLList" :
					return (true);
					break;					
				case "int" :
					return (true);
					break;
				case "uint" :
					return (true);
					break;
				default:
					return (false);
					break;
			}
			return (false);
		}	
		
		/**
		 * Clears and nulls GlobalSettings' memory.
		 */
		public static function releaseMemory():void 
		{
			if (_settingsLoader != null) {
				_settingsLoader.removeEventListener(Event.COMPLETE, onLoadSettings);
				_settingsLoader.removeEventListener(IOErrorEvent.IO_ERROR, onLoadSettingsError);
				_settingsLoader = null;
			}
			_settingsData = null;
		}
	}
}
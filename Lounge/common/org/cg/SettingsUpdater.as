/**
* Updates settings XML data such as global and game settings.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
	
	import flash.events.EventDispatcher;
	import org.cg.events.SettingsUpdaterEvent;
	import flash.net.SharedObject;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import org.cg.DebugView;
	
	public class SettingsUpdater extends EventDispatcher {
		
		public static const updateActionAttribute:String = "update_action"; //name of update attribute in update manifest XML
		public static var _defaultManifestURL:String = "xml/updatemanifest.xml"; //relative location of update manifest file		
		private var _manifestURL:String = null; //URL / path to the update manifest XML file
		private var _SOName:String = null; //local shared object name
		private var _manifestLoader:URLLoader; //loader used to load update manifest data
		private var _settingsData:XML = null; //current stored settings data
		private var _manifestData:XML = null; //loaded update manifest data
		private var _targetVersionObj:Object = null; //parsed target client version object, as created by the 'createVersionObject' method
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	updateManifestURL URL / path to the update manifest XML file.
		 * @param 	SOName The name of the local shared object in which the current settings are stored.
		 */
		public function SettingsUpdater(updateManifestURL:String, SOName:String) {
			if (updateManifestURL == null) {
				updateManifestURL = _defaultManifestURL;
			}
			this._manifestURL = updateManifestURL;
			this._SOName = SOName;
			super(this);
		}
		
		/**
		 * Begins the update process using the current update manifest URL and local share object name settings.
		 * 
		 * @param targetVersion The target version to update the settings data to, if it exists.
		 */
		public function update(targetVersion:String):void {
			DebugView.addText ("SettingsUpdater.update to version " + targetVersion);
			DebugView.addText ("   Loading stored data from shared object: \"" + _SOName+"\"");
			DebugView.addText ("   Update manifest file: "+this._manifestURL);
			var dataExists:Boolean = false;
			try {
				var sharedObject:SharedObject = SharedObject.getLocal(_SOName);
				this._settingsData = sharedObject.data.settings;
				if ((this._settingsData != null) && (this._settingsData.toString() != "")) {
					dataExists = true;
				}
			} catch (err:*) {
			}
			if (!dataExists) {
				//data hasn't been stored in local shared object yet
				var event:SettingsUpdaterEvent = new SettingsUpdaterEvent(SettingsUpdaterEvent.COMPLETE);
				event.statusInfo = "No stored settings data to update.";
				this.dispatchEvent(event);
				return;
			}			
			DebugView.addText ("   Current settings version: " + this.currentSettingsVersion);
			var settingsVersionObj:Object = this.createVersionObject(this.currentSettingsVersion);
			this._targetVersionObj = this.createVersionObject(targetVersion);
			var newer:uint = this.newerVersion(settingsVersionObj, this._targetVersionObj);						
            if (newer == 0) {
				//current and target versions are the same -- nothing to do
				event = new SettingsUpdaterEvent(SettingsUpdaterEvent.COMPLETE);
				this.dispatchEvent(event);
			} else if (newer == 1) {
				//using older client version with newer settings (downgrade)
				event = new SettingsUpdaterEvent(SettingsUpdaterEvent.FAIL);
				event.statusInfo = "Settings version ("+this.currentSettingsVersion+") is newer than target version ("+targetVersion+")!";
				this.dispatchEvent(event);
			} else if (newer == 3) {
				event = new SettingsUpdaterEvent(SettingsUpdaterEvent.FAIL);
				event.statusInfo = "Problem parsing settings version ("+this.currentSettingsVersion+") or target version ("+targetVersion+")!";
				this.dispatchEvent(event);
			} else {
				//settings can be updated
				this.loadUpdateManifest(this._manifestURL);
			}			
		}
		
		/**
		 * Begins loading the update manifest XML data.
		 * 
		 * @param	manifestURL URL / path to the update manifest XML file.
		 */
		private function loadUpdateManifest(manifestURL:String):void {
			var request:URLRequest = new URLRequest(manifestURL);
			this._manifestLoader = new URLLoader();
			this._manifestLoader.dataFormat = URLLoaderDataFormat.TEXT;
			this._manifestLoader.addEventListener(Event.COMPLETE, this.onLoadUpdateManifest);
			this._manifestLoader.addEventListener(IOErrorEvent.IO_ERROR, this.onLoadUpdateManifestError);
			this._manifestLoader.load(request);	
		}
		
		/**
		 * Event listener invoked when the update manifest XML data has been successfully loaded.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onLoadUpdateManifest(eventObj:Event):void {			
			this._manifestLoader.removeEventListener(Event.COMPLETE, this.onLoadUpdateManifest);
			this._manifestLoader.removeEventListener(IOErrorEvent.IO_ERROR, this.onLoadUpdateManifestError);
			this._manifestData = new XML(this._manifestLoader.data);
			var event:SettingsUpdaterEvent = new SettingsUpdaterEvent(SettingsUpdaterEvent.PROGRESS);
			event.statusInfo = "Successfully loaded update manifest XML data.";
			this.dispatchEvent(event);
			this.beginUpdates();
		}
		
		/**
		 * Event listener invoked when the update manifest XML data has failed to load.
		 * 
		 * @param	eventObj An IOErrorEvent object.
		 */
		private function onLoadUpdateManifestError(eventObj:IOErrorEvent):void {			
			this._manifestLoader.removeEventListener(Event.COMPLETE, this.onLoadUpdateManifest);
			this._manifestLoader.removeEventListener(IOErrorEvent.IO_ERROR, this.onLoadUpdateManifestError);
			var event:SettingsUpdaterEvent = new SettingsUpdaterEvent(SettingsUpdaterEvent.FAIL);
			event.statusInfo = "Couldn't load update manifest XML data at: " + this._manifestURL;
			this.dispatchEvent(event);
		}
		
		/**
		 * Main function invoked when the update manifest file has been fully loaded and parsed, and the update process may
		 * begin.
		 */
		private function beginUpdates():void {			
			var updatesFound:Boolean = false;
			try {
				var updateNodes:XMLList = this._manifestData.child("update");
				if (updateNodes.length() > 0) {
					updatesFound = true;
				}
			} catch (err:*) {				
			}
			if (updatesFound == false) {				
				var event:SettingsUpdaterEvent = new SettingsUpdaterEvent(SettingsUpdaterEvent.FAIL);
				event.statusInfo = "No <update> nodes found in loaded manifest data.";
				this.dispatchEvent(event);
				return;
			}
			for (var count:int = 0; count < updateNodes.length(); count++) {
				var currentUpdateNode:XML = updateNodes[count] as XML;
				this.applyNextUpdate(currentUpdateNode);
			}
			var event:SettingsUpdaterEvent = new SettingsUpdaterEvent(SettingsUpdaterEvent.COMPLETE);
			event.statusInfo = "Successfully completed update.";
			this.dispatchEvent(event);
		}
		
		/**
		 * Applies the updates for a specific version, as specified within an <update> node in the manifest data.
		 * 
		 * @param	updateNode An <update> node containing the update(s) to apply.
		 * 
		 * @return True if an update could be applied, false if no updates could be made; for example, if the 'updateNode' parameter is
		 * null, if the version specified in the update node is newer than the current client version, or if the node contains an invalid
		 * "version" attribute.
		 */		
		private function applyNextUpdate(updateNode:XML):Boolean {
			if (updateNode == null) {
				return (false);
			}
			var updateVersionStr:String = new String("0");
			try {
				updateVersionStr = new String(updateNode.@version);
				if ((updateVersionStr == null) || (updateVersionStr == "")) {
					updateVersionStr = "0";
				}
			} catch (err:*) {
				updateVersionStr = "0";
			}
			if (updateVersionStr == "0") {
				return (false);
			}
			var updateVersionObj:Object = this.createVersionObject(updateVersionStr);
			var newer:uint = this.newerVersion(updateVersionObj, this._targetVersionObj);
			if ((newer == 1) || (newer == 3)) {				
				//update node is for a newer version than target version or version string is invalid
				return (false);
			}			
			for (var count:int = 0; count < updateNode.children().length(); count++) {				
				this.updateSetting(updateNode.children()[count]);
			}
			return (true);
		}
		
		/**
		 * Updates a setting topic node containing child update nodes.
		 * 
		 * @param	settingUpdateNode The update node containing update children to apply to 'settingNode'.
		 * @param	settingsNode The global setting node to which updates withing 'settingUpdateNode' will be applied. If null,
		 * the top level global settings node is assumed.
		 */
		private function updateSetting(settingUpdateNode:XML, settingsNode:XML = null):void {
			for (var count:int = 0; count < settingUpdateNode.children().length(); count++) {
				var currentUpdateNode:XML = settingUpdateNode.children()[count];
				var updateNodeType:String = currentUpdateNode.parent().localName();
				if (settingsNode == null) {
					settingsNode = this.findSettingsNode(currentUpdateNode.parent());
				}
				switch (updateNodeType) {
					case "views":
						for (var count2:int = 0; count2 < currentUpdateNode.children().length(); count2++) {
							var viewUpdateNode:XML = currentUpdateNode.children()[count2];
							var savedSettingsNode:XML = settingsNode;
							settingsNode = this.findWidgetNode(viewUpdateNode, settingsNode);
							if (settingsNode == null) {
								this.applyUpdate(viewUpdateNode, savedSettingsNode.parent());
							} else {
								this.updateSetting(viewUpdateNode.parent(), settingsNode.parent());
							}
						}
						break;
					default: 						
						this.applyUpdate(currentUpdateNode, settingsNode);
						break;
				}
			}
		}
		
		/**
		 * Applies an update to a global settings node.
		 * 
		 * @param	updateNode The update node to apply to the global 'settingsNode'.
		 * @param	settingsNode The global settings node to which 'updateNode' will be applied.
		 */
		private function applyUpdate(updateNode:XML, settingsNode:XML):void {					
			if (settingsNode == null) {
				return;
			}
			try {
				var updateType:String = updateNode.attribute(updateActionAttribute)[0].toString();
				var nodeToUpdate:XML = this.findUpdateNode(updateNode, settingsNode);
				delete updateNode.attribute(updateActionAttribute)[0];
				updateType = updateType.toLowerCase();
				switch (updateType) {
					case "replace": 
						var siblingNodes:XMLList = nodeToUpdate.parent().children();
						var replaceNode:XML =  new XML(updateNode.toXMLString());
						var parents:XML = nodeToUpdate.parent();
						nodeToUpdate.parent().insertChildBefore(nodeToUpdate, replaceNode);										
						for (var count:int = 0; count < siblingNodes.length(); count++) {
							if (siblingNodes[count] == nodeToUpdate) {
								delete siblingNodes[count];
							}
						}
						break;
					case "insert":
						var addNode:XML = new XML(updateNode.toXMLString());
						settingsNode.appendChild(addNode);					
						break;
					default: break;
				}
			} catch (err:*) {
				DebugView.addText ("SettingsUpdater.applyUpdate error: " + err.getStackTrace());
				DebugView.addText (" ");
				DebugView.addText ("While attempting to process:");
				DebugView.addText (updateNode);
				DebugView.addText (" ");
				DebugView.addText ("Target node:");
				DebugView.addText (settingsNode);
			}
		}
		
		/**
		 * Finds a global settings node that matches an update node.
		 * 
		 * @param	updateNode The update node to compare to.
		 * @param	settingsNode The global settings node that should match 'updateNode'.
		 * 
		 * @return True if the specified global settings node node matches the update node, false otherwise.
		 */
		private function findSettingsNode(updateNode:XML, settingsData:XML = null):XML {
			if (settingsData == null) {
				settingsData = this._settingsData;
			}
			var childSettingsNodes:XMLList = settingsData.child(updateNode.localName());
			if (childSettingsNodes.length() > 0) {
				return (childSettingsNodes[0]);
			}
			return (null);
		}
		
		/**
		 * Finds an update node that matches a global settings node.
		 * 
		 * @param	updateNode The update node to check for a match.
		 * @param	settingsNode The global settings node that should match 'updateNode'.
		 * 
		 * @return True if the specified update node matches the global settings node, false otherwise.
		 */
		private function findUpdateNode(updateNode:XML, settingsNode:XML):XML {
			for (var count:int = 0; count < settingsNode.children().length(); count++) {				
				if (this.nodesMatch(settingsNode.children()[count], updateNode)) {
					return (settingsNode.children()[count]);
				}
			}
			return (null);
		}
		
		/**
		 * Finds a specific widget node within the children of a <views> node.
		 * 
		 * @param	updateNode The update widget node to find.		
		 * @param	viewsNode The <views> node of the global settings data.
		 * 
		 * @return The matching widget node of 'updateNode' within the global settings <views> node, or null if no match can be found.
		 */
		private function findWidgetNode(updateNode:XML, viewsNode:XML):XML {
			var returnNode:XML = null;
			for (var count1:int = 0; count1 < viewsNode.children().length(); count1++) {
				var currentViewNode:XML = viewsNode.children()[count1];
				for (var count2:int = 0; count2 < currentViewNode.children().length(); count2++) {
					var currentWidgetNode:XML = currentViewNode.children()[count2];
					if (this.nodesMatch(currentWidgetNode, updateNode)) {
						return (currentWidgetNode);
					}
				}
			}
			return (returnNode);
		}
		
		/**
		 * Checks if a specified node is an update node (has a `updateActionAttribute` attribute).
		 * 
		 * @param	node The node to check.
		 * 
		 * @return True if the specified node is an update node, false otherwise.
		 */
		private function isUpdateNode(node:XML):Boolean {
			var matchingAttributes:XMLList = node.attribute(updateActionAttribute);
			if (matchingAttributes.length() > 0) {
				return (true);
			}
			return (false);
		}
		
		/**
		 * Compares an update XML node and a global settings XML node to see if they match. Matching nodes must have the same
		 * name and matching attributes/attribute data, except for the update action attribute specified in the class
		 * header (updateActionAttribute).
		 * 
		 * @param	settingsNode The settings node to compare to the updateNode.
		 * @param	updateNode The update node to compare to the settingsNode.
		 * 
		 * @return True if both nodes match, false otherwise.
		 */
		private function nodesMatch (settingsNode:XML, updateNode:XML):Boolean {
			if (updateNode.localName() != settingsNode.localName()) {
				return (false);
			}
			var node1Attributes:XMLList = updateNode.attributes();
			var node2Attributes:XMLList = settingsNode.attributes();
			var nonMatchCount:int = node2Attributes.length(); //number of attributes that don't match between comparison nodes
			for (var count1:int = 0; count1 < node1Attributes.length(); count1++) {				
				var currentAttrName:String = node1Attributes[count1].name();
				var currentAttrContent:String = updateNode.attribute(currentAttrName).toString();
				for (var count2:int = 0; count2 < node2Attributes.length(); count2++) {
					var matchAttrName:String = node2Attributes[count2].name();
					var matchAttrContent:String = settingsNode.attribute(matchAttrName).toString();					
					if ((currentAttrName != updateActionAttribute) && (matchAttrName != updateActionAttribute)) {
						//check only attributes that aren't the designated update action ones
						if ((currentAttrName == matchAttrName) && (currentAttrContent == matchAttrContent)) {
							nonMatchCount--;
						}
					} else {
						nonMatchCount--;
					}
				}				
			}
			//different non-match tolerance can be set here
			if (nonMatchCount > 0) {
				return (false);
			}
			return (true);
		}
		
		/**
		 * Compares two version objects, such as those generated by the 'createVersionObject' method, to determine which is newer.
		 * 
		 * @param	versionObj1 The first version object to compare.
		 * @param	versionObj2 The second version object to compare.
		 * 
		 * @return A 1 if versionObj1 is newer than versionObj2, a 2 if versionObj2 is newer than versionObj1, and 0 if they're both
		 * the same. A 3 is returned if the comparison can't be performed.
		 */
		private function newerVersion(versionObj1:Object, versionObj2:Object):uint {
			if ((versionObj1 == null) || (versionObj2 == null)) {
				return (3);
			}			
			try {
				if (versionObj1.major > versionObj2.major) {
					return (1);
				}
				if (versionObj1.major < versionObj2.major) {
					return (2);
				}
				if (versionObj1.minor > versionObj2.minor) {
					return (1);
				}
				if (versionObj1.minor < versionObj2.minor) {
					return (2);
				}
				if (versionObj1.build > versionObj2.build) {
					return (1);
				}
				if (versionObj1.build < versionObj2.build) {
					return (2);
				}
				if (versionObj1.status.toLowerCase().charCodeAt(0) > versionObj2.status.toLowerCase().charCodeAt(0)) {
					return (1);
				}
				if (versionObj1.status.toLowerCase().charCodeAt(0) < versionObj2.status.toLowerCase().charCodeAt(0)) {
					return (2);
				}
			} catch (err:*) {
				return (3);
			}
			return (0);
		}
		
		/**
		 * Creates an object of parsed version information from a supplied version string.
		 * 
		 * @param	versionString The version string to parse. This should be in the format "major.minor[.build]" and an optional status designation
		 * letter such as "a" for alpha or "b" for beta. The build portion of the version is optional.
		 * 
		 * @return An object containing the properties "major" (uint), "minor" (uint), "build" (uint) and "status" (String). If not supplied,
		 * "build" will default to 0 and "status" to an empty string. If there was a problem parsing the input version string, null is returned.
		 */
		private function createVersionObject(versionString:String):Object {
			if (versionString == null) {
				return (null);
			}
			if (versionString.length == 0) {
				return (null);
			}
			var returnObj:Object = new Object();
			returnObj.status = "";
			versionString = versionString.split(" ").join("");
			var versionParts:Array = versionString.split(".");
			returnObj.major = "0";
			returnObj.minor = "0";
			returnObj.build = "0";
			if (versionParts.length > 2) {
				for (var count:int = 0; count < versionParts[2].length; count++) {
					var currentChar:String = versionParts[2].substr(count, 1);					
					if ((currentChar.charCodeAt(0) > 64) && (currentChar.charCodeAt(0) < 123)) {
						returnObj.status += currentChar;
					} else {
						returnObj.build += currentChar;
					}
				}
				returnObj.major = uint(versionParts[0]);
				returnObj.minor = uint(versionParts[1]);
				returnObj.build = uint(returnObj.build);
			} else if (versionParts.length == 2) {				
				for (count = 0; count < versionParts[1].length; count++) {
					currentChar = versionParts[1].substr(count, 1);					
					if ((currentChar.charCodeAt(0) > 64) && (currentChar.charCodeAt(0) < 123)) {
						returnObj.status += currentChar;
					} else {
						returnObj.minor += currentChar;
					}
				}
				returnObj.major = uint(versionParts[0]);
				returnObj.minor = uint(returnObj.minor);
				returnObj.build = uint(0);
			} else {				
				for (count = 0; count < versionParts[0].length; count++) {
					currentChar = versionParts[0].substr(count, 1);					
					if ((currentChar.charCodeAt(0) > 64) && (currentChar.charCodeAt(0) < 123)) {
						returnObj.status += currentChar;
					} else {
						returnObj.major += currentChar;
					}
				}
				returnObj.major = uint(returnObj.major);
				returnObj.minor = uint(0);
				returnObj.build = uint(0);
			}
			return (returnObj);
		}
		
		/**
		 * @return Version of the currently stored settings. If no version can be found in stored settings data, "2.0a" is returned as the earliest
		 * updateable version number. If no settings data has been stored, null is returned.
		 */
		private function get currentSettingsVersion():String {
			if (this._settingsData == null) {
				return (null);
			}
			try {
				if ((this._settingsData.@version == "") || (this._settingsData.@version == null) || (this._settingsData.@version == undefined)) {
					return ("0.0.0");
				}
			} catch (err:*) {
				return ("0.0.0");
			}
			return (new String(this._settingsData.@version));
		}
	}
}
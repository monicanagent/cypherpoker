/**
* Manages NetCliques for the Lounge. Include new INetClique implementations here.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
	
	import org.cg.GlobalSettings;
	import p2p3.interfaces.INetClique;	
	import flash.utils.getDefinitionByName;
		
	import p2p3.netcliques.*;
	//Force compiler to include:
	RTMFP;
	MultiInstance;
	
	public class NetCliqueManager {
		
		/**
		 * Returns the XML definition for the specified NetClique from the loaded
		 * Settings data.
		 * 
		 * @param	defRef The string corresponding to the "id" attribute, or the numeric index (starting with 0), of the definition to return.
		 * 
		 * @return The XML definition specified by the defRef parameter, or null a matching one can't be found.
		 */
		public static function getXMLDefinition(defRef:*):XML {			
			try {
				var ncNode:XML = GlobalSettings.getSettingsCategory("netcliques");
				var definitions:XMLList = ncNode.children();
				if (defRef is String) {
					for (var count:uint = 0; count < definitions.length(); count++) {
						var currentDef:XML = definitions[count] as XML;
						if (defRef == String(currentDef.@id)) {
							return (currentDef);
						}
					}				
				} else if ((defRef is Number) || (defRef is uint) || (defRef is int)) {
					return (definitions[defRef] as XML);
				} else {
					return (null);
				}				
			} catch (err:*){				
			}
			return (null);
		}
		
		/**
		 * Returns the class definition for the specified NetClique definition. Note that only those class definitions included at runtime will be available.
		 * 
		 * @param	defRef The string corresponding to the "id" attribute, or the numeric index (starting with 0), of the definition to find the class for.
		 * 
		 * @return The class definition of the specified NetClique, or null if none can be found.
		 */
		public static function getClassDefinition(defRef:*):Class {
			var xmlDef:XML = getXMLDefinition(defRef);
			if (xmlDef == null) {
				return (null);
			}
			try {
				if ((xmlDef.attribute("class") == null) || (xmlDef.attribute("class") == "")) {
					return (null);
				}
				var classDefStr:String = String(xmlDef.attribute("class"));				
				return (getDefinitionByName(classDefStr) as Class);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Returns an uninitialized class instance for the specified NetClique definition. Note that only those class definitions included at runtime will be available.
		 * 
		 * @param	defRef The string corresponding to the "id" attribute, or the numeric index (starting with 0), of the definition to attempt to instantiate.
		 * @param   args Optional arguments to pass directly to the new instance's constructor. Up to 10 parameters are supported.
		 * 
		 * @return The instance of an INetClique implementation, or null if no matching implementation could be found.
		 */
		public static function getInstance(defRef:*, ... args):INetClique {			
			var classDef:Class = getClassDefinition(defRef);
			if (classDef == null) {
				return (null);
			}
			try {				
				var inst:INetClique = new classDef();				
				return (inst);
			} catch (err:*) {				
				return (null);
			}
			return (null);
		}
		
		/**
		 * Returns an initialized class instance for the specified NetClique definition. Only those class definitions included at compile-time will be available.
		 * 
		 * @param	defRef The string corresponding to the "id" attribute, or the numeric index (starting with 0), of the definition to attempt to instantiate
		 * and initialize.
		 * @param parameterSet The set of child parameters (contained in <parameters> nodes) to use to initialize the instance with. All child nodes are
		 * mapped directly to instance properties (so spelling/captilization are important). Data types are determined automatically based on the target (instance)
		 * data types. If this is a string, it is matched against the parameters nodes' "id" attributes, otherwise it is assumed to be an index value (starting at 0)
		 * of the parameters set to use.
		 * @param args Optional parameters to pass directly to the constructor of the new instance. Up to 10 parameters are supported.
		 * 
		 * @return The instance of an INetClique implementation, initialized with  or null if no matching implementation could be found.
		 */
		public static function getInitializedInstance(defRef:*, parameterSet:*= 0, ... args):INetClique {
			var classDefXML:XML = getXMLDefinition(defRef);
			var inst:INetClique = getInstance(defRef, args);
			DebugView.addText("Created clique: " + inst);
			if ((classDefXML == null) || ((inst == null))) {
				return (null);
			}
			try {				
				var initNode:XML = classDefXML.init[0] as XML;
				var parameters:XMLList = initNode.parameters;
				var parametersNode:XML = null;
				if ((parameterSet is Number) || (parameterSet is uint) || (parameterSet is int)) {
					parametersNode = parameters[parameterSet] as XML;
				} else if (parameterSet is String) {
					for (var count:uint = 0; count < parameters.length(); count++) {
						var currentParamNode:XML = parameters[count] as XML;
						if (String(currentParamNode.@id) == parameterSet) {
							parametersNode = currentParamNode;
						}
					}
				}
				if (parametersNode == null) {
					return (null);
				}
				var paramsList:XMLList = parametersNode.children();
				for (count = 0; count < paramsList.length(); count++) {
					currentParamNode = paramsList[count] as XML;
					var varName:String = currentParamNode.localName();
					var varValue:String = String(currentParamNode.children().toString());					
					applyToInstance(varName, varValue, inst);					
				}
				return (inst);
			} catch (err:*) {
				return (null);
			}			
			return (null);
		}
		
		/**
		 * Attempts to apply a value to a named variable in a target.
		 * 
		 * @param	varName The variable name in the target to apply the value to.
		 * @param	value The value to apply to the named variable in the target.
		 * @param	target The target to apply the value to.
		 */
		private static function applyToInstance(varName:String, value:*, target:*):void {			
			if ( (varName == null) || (varName == "")) {
				return;
			}
			if ((target == null) || (target == "")) {
				return;
			}
			try {
				if (target[varName] is String) {
					target[varName] = String(value);					
				} else if (target[varName] is Number) {
					target[varName] = Number(value);
				} else if (target[varName] is uint) {
					target[varName] = uint(value);
				} else if (target[varName] is int) {
					target[varName] = int(value);
				} else if (target[varName] is XML) {
					target[varName] = new XML(String(value));
				} else {
					trace ("NetCliqueManager: couldn't set initialization variable \""+varName+"\" in object "+target+": unsupported data type");
				}
			} catch (err:*) {				
			}
		}
	}
}
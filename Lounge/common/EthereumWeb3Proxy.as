/**
* Proxies JavaScript methods and properties for the EthereumWeb3Client class when running in a browser via ExternalInterface.
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
package {
	
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;	
	import flash.external.ExternalInterface;
	import flash.system.Security;	
	import flash.system.ApplicationDomain;	
	import org.cg.DebugView;
		
	dynamic public class EthereumWeb3Proxy extends Proxy {
				
		private var _proxyName:String = null; //current instance's proxy object name, as accessible through a parent object
		private var _parentRef:EthereumWeb3Proxy = null; //reference to the EthereumWeb3Proxy instance
		private var _childObjects:Array = new Array(); //child EthereumWeb3Proxy objects
		
		/**
		 * Creates a new instance of EthereumWeb3Proxy.
		 * 
		 * @param	parentRef The parent EthereumWeb3Proxy instance, or null if this is the top-most object.
		 * @param	proxyName The object name assigned to the current instance by which it will be accessible.
		 */
		public function EthereumWeb3Proxy(parentRef:EthereumWeb3Proxy=null, proxyName:String = null) {			
			if (ExternalInterface.available) {				
				_proxyName = proxyName;
				_parentRef = parentRef;				
				if (_parentRef == null) {
					//generate root object
					Security.allowDomain(ApplicationDomain.currentDomain);
					_childObjects["window"] =  new EthereumWeb3Proxy(this, "window");				
				} else {
					if (proxyName!="window") {
						refreshObjectMap();
					}
				}
			}
			super();
		}		
		
		/**
		 * Rebuilds the list of child objects contained within the current instance.
		 */
		public function refreshObjectMap():void {
			if (ExternalInterface.available == false) {
				var err:Error = new Error("EthereumWeb3Proxy.refreshObjectMap: ExternalInterface is not available.");
				throw (err);
			}						
			if (_proxyName == null) {
				//this is the main container - don't evaluate all children!
				_childObjects["window"].refreshObjectMap();
				return;
			}			
			if (_proxyName == "window") {
				//this is the window object - don't evaluate the whole thing!				
				_childObjects["web3"] =  new EthereumWeb3Proxy(this, "web3");
				return;
			}
			var objMapStr:String = ExternalInterface.call("stringifyObject", _proxyName);
			var objMap:Object = JSON.parse(objMapStr);			
			for (var itemName:* in objMap) {				
				if (objMap[itemName] is Object) {
					_childObjects[itemName] = new EthereumWeb3Proxy(this, _proxyName+"."+itemName);
				}
			}			
		}
		
		/**
		 * Call property override handler.
		 * 
		 * @param	name The call property being handled.
		 * @param	...args The optional arguments being passed to the invocation. Up to 14 arguments are supported.
		 * 
		 * @return An optional return value from the invoked call property, if available.
		 */
		override flash_proxy function callProperty(name:*, ...args):* {
			try {
				if (ExternalInterface.available == false) {
					var err:Error = new Error("EthereumWeb3Proxy.callProperty: ExternalInterface is not available.");
					throw (err);
				}
				if (_proxyName!="window") {
					var callProxy:String = _proxyName+"." + name;
				} else {
					callProxy = name;
				}
				//Currently supports up to 12 paramaters
				switch (args.length) {
					case 0:
						return (ExternalInterface.call(callProxy));
						break;
					case 1:
						return (ExternalInterface.call(callProxy, args[0]));
						break;
					case 2:
						return (ExternalInterface.call(callProxy, args[0], args[1]));
						break;
					case 3:
						return (ExternalInterface.call(callProxy, args[0], args[1], args[2]));
						break;
					case 4:
						return (ExternalInterface.call(callProxy, args[0], args[1], args[2], args[3]));
						break;
					case 5:
						return (ExternalInterface.call(callProxy, args[0], args[1], args[2], args[3], args[4]));
						break;
					case 6:
						return (ExternalInterface.call(callProxy, args[0], args[1], args[2], args[3], args[4], args[5]));
						break;
					case 7:
						return (ExternalInterface.call(callProxy, args[0], args[1], args[2], args[3], args[4], args[5], args[6]));
						break;
					case 8:
						return (ExternalInterface.call(callProxy, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]));
						break;
					case 9:
						return (ExternalInterface.call(callProxy, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]));
						break;
					case 10:
						return (ExternalInterface.call(callProxy, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]));
						break;
					case 12:
						return (ExternalInterface.call(callProxy, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10]));
						break;
					case 13:
						return (ExternalInterface.call(callProxy, args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11]));
						break;					
					default: break;						
				}
			}	catch (e:Error) {				
			}	
		}
		
		/**
		 * Property getter override handler.
		 * 
		 * @param	name The property being accessed.		 
		 * 
		 * @return The return value if the property if it exists, or null otherwise.
		 */
		override flash_proxy function getProperty(name:*):* {			
			if (ExternalInterface.available == false) {
				var err:Error = new Error("EthereumWeb3Proxy.getProperty: ExternalInterface is not available.");
				throw (err);
			}
			if ((_childObjects[String(name)] != null) && (_childObjects[String(name)] != undefined)) {
				return (_childObjects[String(name)]);
			} else {
				var returnProp:*= ExternalInterface.call("eval", String(_proxyName+"." + name));
				if (returnProp == null) {
					return ("[function]");
				} else {
					return (returnProp);	
				}				
			}
		}

		/**
		 * Property setter override handler.
		 * 
		 * @param	name The property being set.		 
		 * @param 	value The value to apply to the property being set.
		 * 		
		 */
		override flash_proxy function setProperty(name:*, value:*):void {			
			if (ExternalInterface.available == false) {
				var err:Error = new Error("EthereumWeb3Proxy.setProperty: ExternalInterface is not available.");
				throw (err);
			}
			ExternalInterface.call("eval", _proxyName+"." + name+"=" + JSON.stringify(value)+";"); //JSON.stringify converts to native JS data type
		}
		
		override flash_proxy function hasProperty(name:*):Boolean {	
			return (true);
		}
		
		override flash_proxy function nextNameIndex (index:int) : int {
			return (0);
		}

		/**		 
		 * @return The string representation of the class instance.
		 */
		public function toString():String {
			return ("[object EthereumWeb3Proxy -> \""+_proxyName+"\"]");
		}
	}
}
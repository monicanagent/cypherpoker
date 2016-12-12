/**
* Provides JSON-RPC v1.0 data handling and remote invocation / result functionality.
* 
* Remote methods may be invoked directly on this proxy class. Use the onComplete method to set success and error callbacks.
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package {	
	
	import flash.events.EventDispatcher;
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLVariables;
	import flash.net.URLRequest;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.events.*;	
	import com.hurlant.util.Base64;
	
	dynamic public class JSONRPC extends Proxy	{
		
		private static const jsonrpc_v1:String = "1.0"; //default JSON-RPC version to include with calls
				
		public var defaultIdleTimeout:Number = 60000; //default timeout period, in milliseconds, to wait for RPC responses
		
		private var _rpcURL:String = null; //RPC URL
		private var _rpcUsername:String = null; //RPC username
		private var _rpcPassword:String = null; //RPC password
		private var _urlLoader:URLLoader = null; //loader that actually invokes the call
		private var _sourceTXID:String = new String(); //source (calling) transaction ID, unique to this invocation
		private var _result:Object = null; //RPC result object
		private var _onComplete:Function = null; //callback invoked when RPC result is received
		private var _onError:Function = null; //callback invoked when RPC error is received
		
		/**
		 * Creates an instance of JSONRPC.
		 * 
		 * @param	rpcURL The main URL on which to invoke remote procedures.
		 * @param	username The authentication username to use with remote procedure calls.
		 * @param	password The authentication password to use with remote procedure calls.
		 */
		public function JSONRPC(rpcURL:String, username:String, password:String) {			
			_rpcURL = rpcURL;
			_rpcUsername = username;
			_rpcPassword = password;
			
		}			
		
		/**
		 * The unique source transaction ID generated for this invocation. This value will be null until the RPC invocation
		 * is attempted
		 */
		public function get sourceTXID():String	{
			return(_sourceTXID);
		}
		
		/**
		 * The RPC result object, or null if no result has been received or parsed yet.
		 */
		public function get result():Object	{
			return (_result);
		}		
		
		/**
		 * Sets the result and error callbacks for this instance.
		 * 
		 * @param	funcSet The result callback function to invoke when the RPC invocation is complete.
		 * @param	onError The error callback function to invoke when RPC invocation experiences an error.
		 */
		public function onComplete(funcSet:Function, onError:Function=null):void {
			_onComplete = funcSet;		
			_onError = onError;
		}
		
		/**
		 * Generic function handler that bundles up and dispatches a JSON-RPC invocation.
		 * 
		 * @param	name The locally-mapped remote function name to invoke.
		 * @param	... args The arguments to pass to the remote function invocation.
		 * 
		 * @return Nothing.
		 */
		override flash_proxy function callProperty(name:*, ... args):*	{
			var request:URLRequest = new URLRequest(_rpcURL);
			var requestData:Object = new Object();
			requestData.jsonrpc = jsonrpc_v1;
			_sourceTXID = generateTransactionID();
			requestData.id = _sourceTXID;
			requestData.method = String(name);
			requestData.params = args;			
			var jsonRequestData:String = JSON.stringify(requestData);
			request.data = jsonRequestData;
			request.idleTimeout = defaultIdleTimeout;
			request.method = URLRequestMethod.POST;			
			_urlLoader = new URLLoader();
			_urlLoader.dataFormat = URLLoaderDataFormat.TEXT;
			_urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onRequestError);
			_urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onRequestError);
			_urlLoader.addEventListener(Event.COMPLETE, onRequestResult);
			//add basic authorization header		
			request.requestHeaders.push(createBasicAuthHeader(_rpcUsername, _rpcPassword));
			_urlLoader.load(request);			
		}
		
		/**
		 * Generic property getter. Currently unused.
		 * 
		 * @param	name
		 * @return
		 */
		override flash_proxy function getProperty(name:*):* {
		}

		/**
		 * Generic property setter. Currently unused.
		 * 
		 * @param	name
		 * @return
		 */
		override flash_proxy function setProperty(name:*, value:*):void {
		}
		
		/**		 
		 * Default stringifier for the class instance.
		 * 
		 * @return String representation of this instance.
		 */
		public function toString():String {
			return ("[object JSONRPC]");
		}
		
		/**
		 * Generates a unique transaction ID for this instance.
		 * 
		 * @return A unique transaction ID based on the system date, time, and a unique pseudo-random value.
		 */
		private function generateTransactionID():String {
			var returnID:String = new String();
			var dateObj:Date = new Date();
			returnID = String(dateObj.getFullYear()) + String(dateObj.getMonth()) + String(dateObj.getDate()) +
			String(dateObj.getHours()) + String(dateObj.getMinutes()) + String(dateObj.getSeconds()) +
			String(dateObj.getMilliseconds()) + String(Math.random());
			return (returnID);
		}

		/**
		 * Event handler invoked when the instance receives a result from the RPC host.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onRequestResult(eventObj:Event):void {
			_result = JSON.parse(String(_urlLoader.data));
			try {				
				_onComplete(this);				
			} catch (err:*) {				
			} finally {
				_urlLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onRequestError);
				_urlLoader.removeEventListener(IOErrorEvent.IO_ERROR, onRequestError);
				_urlLoader.removeEventListener(Event.COMPLETE, onRequestResult);
				eventObj.target.removeEventListener(eventObj.type, onRequestResult);
			}
		}

		/**
		 * Event handler invoked when the instance encounters an error while invoking the remote procedure call.
		 * 
		 * @param	eventObj
		 */
		private function onRequestError(eventObj:*):void {			
			_result = JSON.parse(String(_urlLoader.data));
			try {
				_onError(this);
			} catch (err:*) {				
			} finally {
				_urlLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onRequestError);
				_urlLoader.removeEventListener(IOErrorEvent.IO_ERROR, onRequestError);
				_urlLoader.removeEventListener(Event.COMPLETE, onRequestResult);
				eventObj.target.removeEventListener(eventObj.type, onRequestResult);
			}			
		}
		
		/**
		 * Creates a basic, BASE64-encoded authentication header to send with the remote procedure call.
		 * 
		 * @param	username The username to use with the authentication.
		 * @param	password The password to use with the authentication.
		 * 
		 * @return A URLRequestHeader instance to use with a URLRequest.requestHeaders property.
		 */
		private function createBasicAuthHeader(username:String, password:String):URLRequestHeader {
			var authorization:URLRequestHeader = new URLRequestHeader("Authorization", "Basic " + Base64.encode(username+":" + password));
			return (authorization);
		}		
	}
}
/**
* Provides JSON-RPC v1.0 data handling and remote invokation / result functionality.
* 
* Remote methods may be invoked directly on this proxy class. Use the onComplete method to set success and error callbacks.
* 
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package 
{	
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
	
	dynamic public class JSONRPC extends Proxy
	{
		private static const jsonrpc_v1:String = "1.0";
				
		public var defaultIdleTimeout:Number = 60000;
		
		private var _rpcURL:String = null;
		private var _rpcUsername:String = null;
		private var _rpcPassword:String = null;
		private var _urlLoader:URLLoader = null;
		private var _sourceTXID:String = new String();
		private var _result:Object = null;		
		private var _onComplete:Function = null;
		private var _onError:Function = null;
		
		public function JSONRPC(rpcURL:String, username:String, password:String) 
		{			
			_rpcURL = rpcURL;
			_rpcUsername = username;
			_rpcPassword = password;
			
		}		
		
		public function onComplete(funcSet:Function, onError:Function=null):void
		{
			_onComplete = funcSet;		
			_onError = onError;
		}
		
		public function get sourceTXID():String
		{
			return(_sourceTXID);
		}
		
		public function get result():Object
		{
			return (_result);
		}
		
		public function toString():String
		{
			return ("[object JSONRPC]");
		}		
		
		private function generateTransactionID():String
		{
			var returnID:String = new String();
			var dateObj:Date = new Date();
			returnID = String(dateObj.getFullYear()) + String(dateObj.getMonth()) + String(dateObj.getDate()) +
			String(dateObj.getHours()) + String(dateObj.getMinutes()) + String(dateObj.getSeconds()) +
			String(dateObj.getMilliseconds()) + String(Math.random());
			return (returnID);
		}

		private function onRequestResult(eventObj:Event):void
		{
			_result = JSON.parse(String(_urlLoader.data));
			try {				
				_onComplete(this);				
			} catch (err:*) {				
			} finally {
				eventObj.target.removeEventListener(eventObj.type, onRequestResult);
			}
		}

		private function onRequestError(eventObj:*):void
		{			
			_result = JSON.parse(String(_urlLoader.data));
			try {
				_onError(this);
			} catch (err:*) {				
			} finally {
				eventObj.target.removeEventListener(eventObj.type, onRequestResult);
			}			
		}
		
		private function createBasicAuthHeader(username:String, password:String):URLRequestHeader
		{
			var authorization:URLRequestHeader = new URLRequestHeader("Authorization", "Basic " + Base64.encode(username+":" + password));
			return (authorization);
		}

		override flash_proxy function callProperty(name:*, ... args):*
		{
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
		
		override flash_proxy function getProperty(name:*):* 
		{
		}

		override flash_proxy function setProperty(name:*, value:*):void 
		{
		}
	}
}
/**
* Provides Ethereum client API services integration via the Web3.js library.
* 
* (C)opyright 2014-2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package 
{		
	import flash.events.Event;
	import flash.net.URLRequest;
	import flash.system.ApplicationDomain;
	import flash.events.EventDispatcher;
	import flash.utils.setTimeout;
	import flash.external.ExternalInterface;
	import flash.utils.getDefinitionByName;
	import EthereumWeb3Proxy;
	import flash.utils.setTimeout;
	import org.cg.DebugView;
	
	public class EthereumWeb3Client extends EventDispatcher
	{

		private var _web3Container:* = null; //Web3 client container
		private var _clientAddress:String = null; //client address (e.g. "127.0.0.1")
		private var _clientPort:uint = 0; //client port (eg. 8545)
		private var _ready:Boolean = false; //is client initialized?
		
		/**
		 * Creates a new instance.
		 * 
		 */
		public function EthereumWeb3Client(clientAddress:String="localhost", clientPort:uint=8545) 
		{
			DebugView.addText("EthereumWeb3Client created.");
			DebugView.addText("   Client address: " + clientAddress);
			DebugView.addText("      Client port: " + clientPort);
			_clientAddress = clientAddress;
			_clientPort = clientPort;
			initialize();
			super();
		}
		
		/**
		 * A reference to the Ethereum Web3 object.
		 */
		public function get web3():Object
		{
			return (_web3Container.window.web3);
		}
		
		/**
		 * A reference to the CypherPoker JavaScript integration library object (usually the "window")
		 */
		public function get lib():Object
		{
			return (_web3Container.window);
		}
				
		/**
		 * JavaScript-acccessible function to provide in0game trace services.
		 * 
		 * @param	traceObj
		 */
		public function flashTrace(traceObj:*):void
		{
			DebugView.addText(traceObj);
		}
		
		/**
		 * Eevent handler invoked when the Web3.js library had been loaded and initialized.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private function onWeb3Load(eventObj:Event):void
		{				
			try {
				if ((_web3Container is EthereumWeb3Proxy)==false) {
					_web3Container.removeEventListener(Event.COMPLETE, onWeb3Load);
					_web3Container.window.flashTrace = this.flashTrace;
				}
				if (_web3Container.window.connect(this._clientAddress, this._clientPort)) {	
					if (_web3Container is EthereumWeb3Proxy) {
						_web3Container.refreshObjectMap();
					}
					_ready = true;
					var event:Event = new Event(Event.CONNECT);
					setTimeout(dispatchEvent, 150, event); //extra time to allow listener(s) to be set when using proxy
				}				
			} catch (err:*) {
				DebugView.addText (err);
			}
		}
		
		/**
		 * Dynamically returns a referenece to the flash.html.HTMLLoader class, if available. Null is returned if the
		 * current runtime environment doesn't include HTMLLoader.
		 */
		private function get HTMLLoader():Class
		{
			try {
				var htmlLoaderClass:Class = getDefinitionByName("flash.html.HTMLLoader") as Class;
				return (htmlLoaderClass);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Initializes the new instance
		 */
		private function initialize():void 
		{
			if (HTMLLoader!=null) {
				if (HTMLLoader.isSupported) {
					_web3Container = new HTMLLoader();
					_web3Container.runtimeApplicationDomain = ApplicationDomain.currentDomain;
					_web3Container.useCache = false;				
					_web3Container.addEventListener(Event.COMPLETE, onWeb3Load);
					var request:URLRequest = new URLRequest("./ethereum/web3.js.html");
					_web3Container.load(request);				
				}
			} else {
				var web3Obj:Object = null;
				if (ExternalInterface.available) {						
					_web3Container = new EthereumWeb3Proxy();
					ExternalInterface.addCallback("flashTrace", flashTrace);
					onWeb3Load(null);
				}
			}
		}		
	}
}
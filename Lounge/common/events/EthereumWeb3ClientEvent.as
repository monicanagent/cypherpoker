/**
* Events dispatched by EthereumWeb3Client instances.
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package events 
{
	import flash.events.Event;
	
	public class EthereumWeb3ClientEvent extends Event 	{
		
		//The Web3 object is available and accessible through "web3" and "lib" references.
		public static const WEB3READY:String = "Event.EthereumWeb3ClientEvent.WEB3READY";
		//A Solidity source code compilation request has completed.
		public static const SOLCOMPILED:String = "Event.EthereumWeb3ClientEvent.SOLCOMPILED";
		
		//Parsed and raw (unparsed) compiled Solidity data. Only inluded with the SOLCOMPILED event.
		public var compiledData:Object = null;
		public var compiledRaw:String = null;
		
		public function EthereumWeb3ClientEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
		{ 
			super(type, bubbles, cancelable);
			
		} 	
		
	}
	
}
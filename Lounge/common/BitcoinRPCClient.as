/**
* Provides Bitcoin client API services integration via JSON-RPC interface.
* For use with the Bitcoin command-line client (bitcoind) available from: https://bitcoin.org/bin/
* 
* A full list of Bitcoin client API calls may be found at: https://en.bitcoin.it/wiki/Original_Bitcoin_client/API_calls_list
* Additional details may be found at: https://en.bitcoin.it/wiki/Elis-API
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
	import flash.events.*;
	import JSONRPC;

	public class BitcoinRPCClient extends EventDispatcher
	{
				
		public static const default_server_address:String = "127.0.0.1"; //default server address
		public static const default_mainnet_port:uint = 8332; //default Bitcoin RPC port (main)
		public static const default_testnet_port:uint = 18332; //default Bitcoin Testnet RPC port
		private static const rpcUsername:String = "rpcdefaultuser"; //default RPC username
		private static const rpcPassword:String = "rpcdefaultpassword"; //default RPC password
						
		private var _useTestnet:Boolean = false; //should instance use Bitcoin Testnet RPC?
		private var _rpcAddress:String = null; //current RPC server address
		private var _rpcPort:uint = 0; //current RPC server port
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	rpcAddress The Bitcoin client APIRPC server address.
		 * @param	rpcPort The Bitcoin client API RPC server port.
		 */
		public function BitcoinRPCClient(rpcAddress:String=default_server_address, rpcPort:uint=default_mainnet_port) 
		{	
			if (rpcAddress == null) {
				rpcAddress = default_server_address;
			}
			//strip out protocol if it was added so that it's not added twice
			var addressStr:String = rpcAddress.toLowerCase();
			var protocolIndex:int = addressStr.indexOf("http://");
			if (protocolIndex > -1) {
				rpcAddress = rpcAddress.substr(protocolIndex, 7);
			}
			_rpcAddress = rpcAddress;
			_rpcPort = rpcPort;
			super();
		}	
		
		/**
		 * The full Bitcoin client API RPC URL, including port.
		 */
		private function get requestURL():String 
		{			
			return ("http://" + _rpcAddress + ":" + String(_rpcPort));
		}
		
		/**
		 * Enables Bitcoin testnet instead of mainnet for any subsequent calls.
		 */
		public function useTestnet():void
		{
			_rpcPort = default_testnet_port;			
		}
		
		/**
		 * - Bitcoin Client API Calls -
		 * 
		 *      Refer to https://en.bitcoin.it/wiki/Elis-API for parameters and implementation details.
		 * 
		 */
		
		public function getaccountaddress(account:String=""):JSONRPC
		{
			var newRequest:JSONRPC = new JSONRPC(requestURL, rpcUsername, rpcPassword);		
			newRequest.getaccountaddress(account);
			return (newRequest);
		}
		
		public function getaccount(address:String=""):JSONRPC
		{
			var newRequest:JSONRPC = new JSONRPC(requestURL, rpcUsername, rpcPassword);		
			newRequest.getaccount(address);
			return (newRequest);
		}
		
		public function getnewaddress(account:String=""):JSONRPC
		{
			var newRequest:JSONRPC = new JSONRPC(requestURL, rpcUsername, rpcPassword);		
			newRequest.getnewaddress(account);
			return (newRequest);
		}
		
		public function getbalance(account:String = "*", confirmations:int = 1, includeWatchOnly:Boolean = false):JSONRPC
		{
			var newRequest:JSONRPC = new JSONRPC(requestURL, rpcUsername, rpcPassword);		
			newRequest.getbalance(account, confirmations, includeWatchOnly);
			return (newRequest);
		}
		
		public function listunspent(minimumConfirmations:int = 1, maximumConfirmations:int = 9999999, addresses:Array = null):JSONRPC
		{
			if (addresses == null) {
				addresses = [];
			}
			var newRequest:JSONRPC = new JSONRPC(requestURL, rpcUsername, rpcPassword);		
			newRequest.listunspent(minimumConfirmations, maximumConfirmations, addresses);
			return (newRequest);
		}
		
		public function sendfrom(fromAccount:String, toAddress:String, amount:Number, confirmations:int = 1):JSONRPC
		{
			var newRequest:JSONRPC = new JSONRPC(requestURL, rpcUsername, rpcPassword);		
			newRequest.sendfrom(fromAccount, toAddress, amount, confirmations);
			return (newRequest);
		}
		
		public function sendtoaddress(toAddress:String, number:Number, comment:String = null, commentTo:String = null):JSONRPC
		{
			var newRequest:JSONRPC = new JSONRPC(requestURL, rpcUsername, rpcPassword);		
			newRequest.sendtoaddress(toAddress, number, comment, commentTo);
			return (newRequest);
		}
		
		public function setgenerate(enable:Boolean, numberOfProcessors:int):JSONRPC
		{
			var newRequest:JSONRPC = new JSONRPC(requestURL, rpcUsername, rpcPassword);		
			newRequest.setgenerate(enable, numberOfProcessors);
			return (newRequest);
		}
	}
}
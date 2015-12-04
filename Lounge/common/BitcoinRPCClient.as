package 
{
	import flash.events.EventDispatcher;	
	import flash.events.*;
	import JSONRPC;

	public class BitcoinRPCClient extends EventDispatcher
	{
				
		public static const default_server_address:String = "127.0.0.1";
		public static const default_mainnet_port:uint = 8332;
		public static const default_testnet_port:uint = 18332;
		private static const rpcUsername:String = "rpcdefaultuser";
		private static const rpcPassword:String = "rpcdefaultpassword";
						
		private var _useTestnet:Boolean = false;
		private var _rpcAddress:String = null;
		private var _rpcPort:uint = 0;		
		
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
		
		private function get requestURL():String 
		{			
			return ("http://" + _rpcAddress + ":" + String(_rpcPort));
		}
		
		public function useTestnet():void
		{
			_rpcPort = default_testnet_port;			
		}
		
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
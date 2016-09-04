/**
* Main Ethereum client services integration class.
* 
* (C)opyright 2014-2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package 
{

	import EthereumWeb3Client;
	import flash.external.ExternalInterface;
	import org.cg.DebugView;
	
	public class Ethereum {
		
		private var _ethereumClient:EthereumWeb3Client = null;
		private var _ethAddrMap:Array = new Array(); //.ethAddr, .peerID
		
		/**
		 * Creates a new instance of the Ethereum class.
		 * 
		 * @param	clientRef A reference to an active EthereumWeb3Client instance.
		 */
		public function Ethereum(clientRef:EthereumWeb3Client) 
		{
			_ethereumClient = clientRef;
		}
		
		/**
		 * A reference to the exposed Ethereum Web3 object.
		 */
		public function get web3():Object 
		{
			return (_ethereumClient.web3);
		}
		
		/**
		 * A reference to the Ethereum library container (usually "window")
		 */
		public function get client():EthereumWeb3Client 
		{
			return (_ethereumClient);
		}		
		
		/**
		 * Deploys a new "PokerHand" contract to the Ethereum blockchain.
		 * 
		 * @param	playerAddresses The required players for the new contract.
		 * @param	callBack A callback function to invoke when contract-related events are raised.
		 */
		public function deployPokerHandContract(playerAddresses:Array, callBack:Function):void
		{
			DebugView.addText("Ethereum.deployPokerHandContract");	
			try {
				if (ExternalInterface.available) {
					ExternalInterface.addCallback("onDeployPokerHandContract", callBack);
				}
				_ethereumClient.lib.deployPokerHandContract(playerAddresses, "onDeployPokerHandContract");
			} catch (err:*) {
				DebugView.addText ("Attempt to access Ethereum client library failed: " + err);
			}
		}
		
		/**
		 * Callback invoked when a new "PokerHand" contract triggers a deployment event.
		 * 
		 * @param	err The error, if any, that was sent with the callback.
		 * @param	contract The contract information, if any, that was send with the callback.
		 */
		public function onDeployPokerHandContract(err:*= null, contract:*=null):void {
			if (contract == null) {
				DebugView.addText("onDeployPokerHandContract error --- "+err);
				for (var item:* in err) {
					DebugView.addText(item+"="+err);
				}
				return;
			}
			if (contract.address != undefined) {
				DebugView.addText ("PokerHand contract has been mined.");
				DebugView.addText ("   Address=" + contract.address);
				DebugView.addText ("   Cost=" + _ethereumClient.web3.eth.getBlock(_ethereumClient.web3.eth.getTransaction(contract.transactionHash).blockNumber).gasUsed);
				DebugView.addText ("   TXHash=" + contract.transactionHash);
			} else {
				DebugView.addText ("PokerHand contract has been created.");
				DebugView.addText ("   TXHash=" + contract.transactionHash);
			}			
		}
		
		/**
		 * Returns the balance of an Ethereum account associated with a specific peer ID.
		 * 
		 * @param	peerID The peer ID associated with the Ethereum account.
		 * @param	denomination The denomination in which to return the balance, if available.
		 * 
		 * @return The Ethereum account balance of the associated peer ID or null.
		 */
		public function getPeerBalance(peerID:String, denomination:String="ether"):String 
		{						
			var ethAddr:String = getEthereumAddress(peerID);						
			if (ethAddr!=null) {
				try {
					var balance:String = client.lib.getBalance(ethAddr, denomination);					
					return (balance);					
				} catch (err:*) {
					return (null);
				}
			}
			return (null);
		}
		
		/**
		 * Maps a CypherPoker peer ID to an Ethereum address.
		 * 
		 * @param	peerID The CypherPoker peer ID to associate with an Ethereum address.
		 * @param	ethAddr The Ethereum address to associate with the CypherPoker peer ID.
		 * 
		 * @return True if the mapping was successfully completed.
		 */
		public function mapPeerIDToEthAddr(peerID:String, ethAddr:String):Boolean 
		{
			var mapObj:Object = new Object();
			mapObj.peerID = peerID;
			mapObj.ethAddr = ethAddr;
			_ethAddrMap.push(mapObj);
			DebugView.addText ("Ethereum.mapPeerIDToEthAddr: " + peerID + " -> " + ethAddr);
			return (true);
		}
		
		/**
		 * An array of all currently mapped Ethereum addresses.
		 */
		public function get allRegAddresses():Array {
			var returnArray:Array = new Array();
			for (var count:uint = 0; count < _ethAddrMap.length; count++) {
				returnArray.push(_ethAddrMap[count].ethAddr);
			}
			return (returnArray);
		}
		
		/**
		 * Finds a specific Ethereum address based on a CypherPoker peer ID.
		 * 
		 * @param	peerID The CypherPoker peer ID for which to find an associated Etherem address.
		 *
		 * @return The Ethereum address associated with the peer ID or null if none can be found.
		 */
		public function getEthereumAddress(peerID:String):String
		{
			for (var count:uint = 0; count < _ethAddrMap.length; count++) {
				if (_ethAddrMap[count].peerID == peerID) {
					return (_ethAddrMap[count].ethAddr);
				}
			}
			return (null);
		}
		
		/**
		 * Deploys all poker lib contracts to the current blockchain. The created addresses are NOT reflected in the
		 * pokerhand contract (it must be re-compiled and updated in web3.js.html)
		 */
		public function deployPokerLibContracts():void
		{
			deployCryptoCardsContract();
			deployGamePhaseContract();
			deployPokerBettingContract();
			deployPHAContract();			
		}
		
		/**
		 * Deploys a new "CryptoCards" contract to the Ethereum blockchain.		
		 */
		public function deployCryptoCardsContract():void
		{
			if (ExternalInterface.available) {
				ExternalInterface.addCallback("onDeployCryptoCardsContract", onDeployCryptoCardsContract);
			}
			_ethereumClient.lib.deployCryptoCardsContract("onDeployCryptoCardsContract");
		}		
		
		/**
		 * Callback invoked when a new "CryptoCards" contract triggers a deployment event.
		 * 
		 * @param	err The error, if any, that was sent with the callback.
		 * @param	contract The contract information, if any, that was send with the callback.
		 */
		public function onDeployCryptoCardsContract(err:*= null, contract:*=null):void {
			if (contract == null) {
				DebugView.addText("onDeployCryptoCardsContract error --- "+err);
				for (var item:* in err) {
					DebugView.addText(item+"="+err);
				}
				return;
			}
			if (contract.address != undefined) {
				DebugView.addText ("CryptoCards contract has been mined.");
				DebugView.addText ("   Address=" + contract.address);
				DebugView.addText ("   Cost=" + _ethereumClient.web3.eth.getBlock(_ethereumClient.web3.eth.getTransaction(contract.transactionHash).blockNumber).gasUsed);
				DebugView.addText ("   TXHash=" + contract.transactionHash);
			} else {
				DebugView.addText ("CryptoCards contract has been created.");
				DebugView.addText ("   TXHash=" + contract.transactionHash);
			}			
		}
		
		/**
		 * Deploys a new "GamePhase" contract to the Ethereum blockchain.		
		 */
		public function deployGamePhaseContract():void
		{
			if (ExternalInterface.available) {
				ExternalInterface.addCallback("onDeployGamePhaseContract", onDeployGamePhaseContract);
			}
			_ethereumClient.lib.deployGamePhaseContract("onDeployGamePhaseContract");	
		}
		
		/**
		 * Callback invoked when a new "GamePhase" contract triggers a deployment event.
		 * 
		 * @param	err The error, if any, that was sent with the callback.
		 * @param	contract The contract information, if any, that was send with the callback.
		 */
		public function onDeployGamePhaseContract(err:*, contract:*=null):void {
			if (contract == null) {
				DebugView.addText(err);
				return;
			}
			if (contract.address != undefined) {
				DebugView.addText ("GamePhase contract has been mined.");
				DebugView.addText ("   Address=" + contract.address);
				DebugView.addText ("   Cost=" + _ethereumClient.web3.eth.getBlock(_ethereumClient.web3.eth.getTransaction(contract.transactionHash).blockNumber).gasUsed);
				DebugView.addText ("   TXHash=" + contract.transactionHash);
			} else {
				DebugView.addText ("GamePhase contract has been created.");
				DebugView.addText ("   TXHash=" + contract.transactionHash);
			}
		}		
		
		/**
		 * Deploys a new "PokerBetting" contract to the Ethereum blockchain.		
		 */
		public function deployPokerBettingContract():void
		{		
			if (ExternalInterface.available) {
				ExternalInterface.addCallback("onDeployPokerBettingContract", onDeployPokerBettingContract);
			}
			_ethereumClient.lib.deployPokerBettingContract("onDeployPokerBettingContract");	
		}
		
		/**
		 * Callback invoked when a new "PokerBetting" contract triggers a deployment event.
		 * 
		 * @param	err The error, if any, that was sent with the callback.
		 * @param	contract The contract information, if any, that was send with the callback.
		 */
		public function onDeployPokerBettingContract(err:*, contract:*=null):void {
			if (contract == null) {
				DebugView.addText(err);
				return;
			}
			if (contract.address != undefined) {
				DebugView.addText ("PokerBetting contract has been mined.");
				DebugView.addText ("   Address=" + contract.address);
				DebugView.addText ("   Cost=" + _ethereumClient.web3.eth.getBlock(_ethereumClient.web3.eth.getTransaction(contract.transactionHash).blockNumber).gasUsed);
				DebugView.addText ("   TXHash=" + contract.transactionHash);
			} else {
				DebugView.addText ("PokerBetting contract has been created.");
				DebugView.addText ("   TXHash=" + contract.transactionHash);
			}
		}
		
		/**
		 * Deploys a new "PHA" (Poker Hand Analyzer) contract to the Ethereum blockchain.		
		 */
		public function deployPHAContract():void
		{
			if (ExternalInterface.available) {
				ExternalInterface.addCallback("onDeployPHAContract", onDeployPHAContract);
			}
			_ethereumClient.lib.deployPHAContract("onDeployPHAContract");	
		}
		
		/**
		 * Callback invoked when a new "PHA" (Poker Hand Analyzer) contract triggers a deployment event.
		 * 
		 * @param	err The error, if any, that was sent with the callback.
		 * @param	contract The contract information, if any, that was send with the callback.
		 */
		public function onDeployPHAContract(err:*, contract:*=null):void {
			if (contract == null) {
				DebugView.addText(err);
				return;
			}
			if (contract.address != undefined) {
				DebugView.addText ("PHA (Poker Hand Analyzer) contract has been mined.");
				DebugView.addText ("   Address=" + contract.address);
				DebugView.addText ("   Cost=" + _ethereumClient.web3.eth.getBlock(_ethereumClient.web3.eth.getTransaction(contract.transactionHash).blockNumber).gasUsed);
				DebugView.addText ("   TXHash=" + contract.transactionHash);
			} else {
				DebugView.addText ("PHA (Poker Hand Analyzer) contract has been created.");
				DebugView.addText ("   TXHash=" + contract.transactionHash);
			}
		}
	}
}
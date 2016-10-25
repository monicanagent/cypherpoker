/**
* Manages the creation of, and interaction with, a single smart contract.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
	
	import org.cg.interfaces.ISmartContract;	
	import org.cg.events.SmartContractEvent;
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;
	import org.cg.GlobalSettings;
	import Ethereum;
	import events.EthereumWeb3ClientEvent;
	
	/*
	var requiredPlayers =[] ;
var keepGameOnBlockchain = false ;
var pokerhandbiContract = web3.eth.contract([{"inputs":[{"name":"requiredPlayers","type":"address[]"},{"name":"keepGameOnBlockchain","type":"bool"}],"type":"constructor"}]);
var pokerhandbi = pokerhandbiContract.new(
   requiredPlayers,
   keepGameOnBlockchain,
   {
     from: web3.eth.accounts[0], 
     data: '606060405260405160463803806046833981016040528080518201919060200180519060200190919050505b5b5050600c80603a6000396000f360606040526008565b600256', 
     gas: 4700000
   }, function (e, contract){
    console.log(e, contract);
    if (typeof contract.address !== 'undefined') {
         console.log('Contract mined! address: ' + contract.address + ' transactionHash: ' + contract.transactionHash);
    }
 })
 */
	
	public class SmartContract extends Proxy implements ISmartContract {
		
		public static var ethereum:Ethereum = null; //reference to an active and initialized Ethereum instance		
		
		private var _contractName:String; //The base name of the contract
		private var _contractInfo:XML = null; //Reference to contract information node in the global settings data
		private var _clientType:String = "ethereum"; //The client or VM type for which the smart contract exists or should exist
		private var _networkID:uint = 1; //The network on which the smart contract is or should be deployed on
		private var _account:String; //The base user account to be used to invoke and pay for contract interactions
		private var _password:String; //The password for the base user account
		private var _abi:Object = null; //The contract interface
		private var  _initializeParams:Object = null; //Contains parameters (within a property matching the contract name) used to initialize a new contract instance
		
		/**
		 * Creates a new instance of SmartContract.
		 * 
		 * @param	contractName The base name of the contract to associate with this instance. 
		 * @param	account The account to use to pay for interactions with the contract. This value may be set to
		 * null or an empty string ("") if the the contract's functions are not going to be invoked.
		 * @param	password The password for the included account parameter. This value may be set to
		 * null or an empty string ("") if the the contract's functions are not going to be invoked.
		 * @param	contractInfo XML node containing information about the deployed contract to associate with this instance. If null,
		 * no contract instance is assumed to exist on the blockchain.
		 */
		public function SmartContract(contractName:String, account:String, password:String, contractInfo:XML=null) {
			this._contractName = contractName;
			this._contractInfo = contractInfo;
			this._account = account;
			this._password = password;
			if (contractInfo != null) {
				//get additional details from supplied contract information
				this._clientType = String(contractInfo.@clientType);
				this._networkID = uint(contractInfo.@networkID);
			}
		}
		
		public function set contractInfo(infoSet:XML):void {
			this._contractInfo = infoSet;
		}
		
		public function get contractInfo():XML {
			return (this._contractInfo);
		}
		
		public function set clientType(typeSet:String):void {
			this._clientType = typeSet;
		}
		
		public function get clientType():String {
			return (this._clientType);
		}
		
		public function set networkID(IDSet:uint):void {
			this._networkID = IDSet;
		}
		
		public function get networkID():uint {
			return (this._networkID);
		}
		
		/**
		 * Attempts to retrieve information about any already deployed contracts (not libraries), from the GlobalSettings object.
		 * 			 
		 * @param	contractName The name of contract(s) to find within the global settings data.
		 * @param	clientType The type of client/VM to which the matched contract(s) should belong. Default is "ethereum".
		 * @param	networkID The network ID on which the matched contract(s) reside. Default is 1 (Ethereum mainnet);
		 * @param	contractStatus The status or state that the returned contract must be flagged as. Valid states include
		 * 		"new" (deployed but not yet used), "active" (in use), and "complete" (fully completed but remaining on the blockchain).
		 * 
		 * @return A vector array of all contracts found in the global settings data that match the specified parameters.
		 */
		public static function findInfo(contractName:String, clientType:String="ethereum", networkID:uint=1, contractStatus:String = "new"):Vector.<XML> {			
			var clientContractsNode:XML = GlobalSettings.getSetting("smartcontracts", clientType);	
			var returnContracts:Vector.<XML> = new Vector.<XML>();
			if (clientContractsNode.children().length() == 0) {
				return (returnContracts);
			}
			var networkNodes:XMLList = clientContractsNode.children();
			for (var count:int = 0; count < networkNodes.length(); count++) {				
				if (String(networkNodes[count].@id) == String(networkID)) {					
					var infoNodes:XMLList = networkNodes[count].children();
					for (var count2:int = 0; count2 < infoNodes.length(); count2++) {						
						var currentInfoNode:XML = infoNodes[count2] as XML;
						if (String(currentInfoNode.localName()) == contractName) {							
							if ((String(currentInfoNode.@status) == contractStatus) && (String(currentInfoNode.@type) == "contract")) {	
								currentInfoNode.@networkID = String(networkID); //copy this data into node attributes for easy access
								currentInfoNode.@clientType = String(clientType);
								returnContracts.push(currentInfoNode);
							}
						}
					}
				}
			}
			return (returnContracts);
		}
		
		/**
		 * Initializes the smart contract. If the supplied contract info is supplied then the contract is assumed to exist on the blockchain
		 * and is used as-is, otherwise the contract is compiled and deployed.
		 * 
		 * @param	... args	Optional instantiation parameters to pass to the Ethereum contract (new) constructor. The final account/gas/value object
		 * will automatically be appended so it shouldn't be included.
		 */
		public function initialize(... args):void {
			DebugView.addText("SmartContract.initialize: " + this._contractName);
			this._initializeParams = new Object();
			this._initializeParams[this._contractName] = args;			
			if (this._contractInfo == null) {
				DebugView.addText ("   Supplied contract information is null. Deploying new contract.");
				this.__compile();
			}
		}
		
		/**
		 * Call property override handler.
		 * 
		 * @param	name The call property (function) being handled.
		 * @param	...args The optional argument(s) being passed to the invocation.
		 * 
		 * @return An optional return value from the invoked call property, if available.
		 */
		override flash_proxy function callProperty(name:*, ...args):* {			
		}
		
		/**
		 * Property getter override handler.
		 * 
		 * @param	name The property being accessed.		 
		 * 
		 * @return The return value if the property if it exists, or null otherwise.
		 */
		override flash_proxy function getProperty(name:*):* {
			
		}
		
		/**
		 * Property setter override handler.
		 * 
		 * @param	name The property being set.		 
		 * @param 	value The value to apply to the property being set.
		 * 		
		 */
		override flash_proxy function setProperty(name:*, value:*):void {			
		}
		
		
		
		/**
		 * Adds information about a newly deployed/mined contract to the global settings data.
		 * 
		 * @param	address The address at which the contract has been deployed/mined.
		 * @param	txhash The hash of the transaction in which the contract was deployed/mined.
		 * @param	ABI The interface definition of the contract, as a string.
		 * 
		 * @return	A reference to the newly created XML node within the global settings data.
		 */
		private function __addDeployedContractInfo(address:String, txhash:String, ABI:String):XML {
			return (null);
		}
		
		/**
		 * Compiles a Solidity smart contract stored in the installation folder (with ethereum/solidity), of the currently running application.
		 * 
		 * @param containingFolder	The folder containing the evaluated Solidity file (contractName+".sol"). Default is "app:/ethereum/solidity/".
		 */
		private function __compile(containingFolder:String = "app:/ethereum/solidity/"):void {
			ethereum.client.removeEventListener(EthereumWeb3ClientEvent.SOLCOMPILED, this.__onCompileContract);
			ethereum.client.addEventListener(EthereumWeb3ClientEvent.SOLCOMPILED, this.__onCompileContract);
			ethereum.client.compileSolidityFile(containingFolder+this._contractName+".sol");
		}
		
		private function __onCompileContract(eventObj:EthereumWeb3ClientEvent):void {			
			DebugView.addText ("Compiled:");
			DebugView.addText(eventObj.compiledRaw);
			ethereum.client.removeEventListener(EthereumWeb3ClientEvent.SOLCOMPILED, this.__onCompileContract);			
			if (eventObj.compiledRaw != "") {
				var libsObj:Object = ethereum.generateDeployedLibsObj(this.clientType, this.networkID);				
				ethereum.deployLinkedContracts(eventObj.compiledData, this._initializeParams, this._account, this._password, libsObj);
			}
		}
		
		/**
		 * Callback function invoked during various stages of the contract deployment.
		 * 
		 * @param	err A contract mining error object, if an error occured.
		 * @param	contract An object containing information about the newly mined contract.
		 */
		public function __onDeployContract(err:*, contract:*=null):void 
		{
			DebugView.addText ("SmartContract.__onDeplyContract");
			DebugView.addText ("err=" + err);
			DebugView.addText ("contract=" + contract);
			if (contract == null) {
				//probably not enough gas
				return;
			}
			if ((contract["address"] != undefined) && (contract["address"] != null) && (contract["address"] != "")) {
				//contract deployed
			} else {
				//not yet deployed
			}
		}
	}
}
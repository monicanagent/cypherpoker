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
	import flash.events.EventDispatcher;
	import org.cg.events.SmartContractEvent;
	import org.cg.events.EthereumEvent;
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
		
		public var useGlobalSettings:Boolean = true; //If true, this contract instance will manage (add/remove/update) itself within the GlobalSettings XML data.
		
		private var _contractName:String; //The base name of the contract
		private var _eventDispatcher:EventDispatcher;
		private var _contractInfo:XML = null; //Reference to contract information node in the global settings data
		private var _clientType:String = "ethereum"; //The client or VM type for which the smart contract exists or should exist
		private var _networkID:uint = 1; //The network on which the smart contract is or should be deployed on
		private var _account:String; //The base user account to be used to invoke and pay for contract interactions
		private var _password:String; //The password for the base user account
		private var _abiString:String = null; //JSON string representation of the contract interface
		private var _abi:Object = null; //The parsed contract interface
		private var  _initializeParams:Object = null; //Contains parameters (within a property matching the contract name) used to initialize a new contract instance
		
		/**
		 * Creates a new instance of SmartContract.
		 * 
		 * @param	contractName The base name of the contract to associate with this instance. 
		 * @param	account The account to use to pay for interactions with the contract. This value may be set to
		 * null or an empty string ("") if the the contract's functions are not going to be invoked.
		 * @param	password The password for the included account parameter. This value may be set to
		 * null or an empty string ("") if the the contract's functions are not going to be invoked.
		 * @param	contractInfo Optional XML node containing information about the deployed contract to associate with this instance.
		 */
		public function SmartContract(contractName:String, account:String, password:String, contractInfo:XML = null) {
			this._eventDispatcher = new EventDispatcher();
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
		
		public function addEventListener(type:String, listener:Function, useCapture:Boolean=false, priority:int=0, useWeakReference:Boolean=false):void {
			this._eventDispatcher.addEventListener(type, listener, useCapture, priority, useWeakReference);
		}
		
		public function removeEventListener(type:String, listener:Function, useCapture:Boolean=false):void {
			this._eventDispatcher.removeEventListener(type, listener, useCapture);
		}
		
		public function hasEventListener(type:String):Boolean {
			return(this._eventDispatcher.hasEventListener(type));
		}
		
		public function willTrigger(type:String):Boolean {
			return(this._eventDispatcher.willTrigger(type));
		}
		
		/**
		 * Attempts to retrieve information about any already deployed contracts (not libraries), from the GlobalSettings object. The
		 * referenced contract should not be assumed to exist on the blockchain.
		 * 			 
		 * @param	contractName The name of contract(s) to find within the global settings data.
		 * @param	clientType The type of client/VM to which the matched contract(s) should belong. Default is "ethereum".
		 * @param	networkID The network ID on which the matched contract(s) reside. Default is 1 (Ethereum mainnet);
		 * @param	contractStatus The status or state that the returned contract must be flagged as. Valid states include
		 * 		"new" (deployed but not yet used), "active" (in use), and "complete" (fully completed but remaining on the blockchain).
		 * 
		 * @return A vector array of all contract descriptors found in the global settings data that match the specified parameters.
		 */
		public static function findDescriptor(contractName:String, clientType:String="ethereum", networkID:uint=1, contractStatus:String = "new"):Vector.<XML> {
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
		 * Returns the first validated (checked for existence on blockchain), of a matching smart contract descriptor.
		 * 			 
		 * @param	contractName The name of contract(s) to find within the global settings data.
		 * @param	clientType The type of client/VM to which the matched contract(s) should belong. Default is "ethereum".
		 * @param	networkID The network ID on which the matched contract(s) reside. Default is 1 (Ethereum mainnet);
		 * @param	contractStatus The status or state that the returned contract must be flagged as. Valid states include
		 * 		"new" (deployed but not yet used), "active" (in use), and "complete" (fully completed but remaining on the blockchain).
		 * @param	removeFailed If true (default), any descriptors found that can't be validated are automatically removed from the global
		 * 		settings data.
		 * 
		 * @return A descriptor for a validated contract, or null if either no descriptor exists or any matching contracts failed validation.
		 */
		public static function getValidatedDescriptor(contractName:String, clientType:String = "ethereum", networkID:uint = 1, contractStatus:String = "new", removeFailed:Boolean = true):XML {
			var descriptors:Vector.<XML> = findDescriptor(contractName, clientType, networkID, contractStatus);
			if (descriptors == null) {
				return (null);
			}
			if (descriptors.length == 0) {
				return (null);
			}
			for (var count:int = 0; count < descriptors.length; count++) {
				var currentDescriptor:XML = descriptors[count];
				if (validateContract(currentDescriptor, removeFailed)) {
					return (currentDescriptor);
				}
			}
			return (null);
		}
		
		/**
		 * Validates that a specific smart contract exists on the blockchain and optionally updates global settings XML
		 * data if it doesn't.
		 * 
		 * @param	contractInfo An XML descriptor node for the contract.
		 * @param	updateGlobalSettings If true, the global settings XML data will be updated if the contract can't be
		 * found on the blockchain.
		 * 
		 * @return True if the smart contract exists on the blockchain, false otherwise.
		 */
		public static function validateContract(contractInfo:XML, updateGlobalSettings:Boolean = true):Boolean {
			if (contractInfo == null) {
				return (false);
			}
			try {				
				if (contractInfo.child("address")[0].toString() == "") {
					if (updateGlobalSettings) {
						__removeGlobalDescriptor(contractInfo);
					}
					return (false);
				}
				//the transaction hash might not be necessary but currently it should be included
				if (contractInfo.child("txhash")[0].toString() == "") {	
					if (updateGlobalSettings) {
						__removeGlobalDescriptor(contractInfo);
					}
					return (false);
				}
				if (contractInfo.child("interface")[0].toString() == "") {
					if (updateGlobalSettings) {
						__removeGlobalDescriptor(contractInfo);
					}
					return (false);
				}
			} catch (err:*) {
				if (updateGlobalSettings) {
					__removeGlobalDescriptor(contractInfo);
				}
				return (false);
			}
			//now check if the contract exists on the blockchain
			var address:String = contractInfo.child("address")[0].toString();
			var abiStr:String = contractInfo.child("interface")[0].toString();
			if (!ethereum.client.lib.checkContractExists(address, abiStr, "owner", "0x", false)) {	
				if (updateGlobalSettings) {
					__removeGlobalDescriptor(contractInfo);
				}
				return (false);
			}
			return (true);
		}
		
		/**
		 * Removes a supplied XML contract descriptor from the global settings data. The supplied data may be a linked reference to
		 * an existing node in the global settings data or an independent node.
		 * 
		 * @param	descriptorNode The XML descriptor of the smart contract to remove from global settings data.
		 */
		private static function __removeGlobalDescriptor(descriptorNode:XML):void {
			DebugView.addText ("Removing :" + descriptorNode);			
			var clientContractsNode:XML = GlobalSettings.getSetting("smartcontracts", descriptorNode.@clientType);	
			var returnContracts:Vector.<XML> = new Vector.<XML>();
			if (clientContractsNode.children().length() == 0) {
				return;
			}						
			var networkNodes:XMLList = clientContractsNode.children();
			for (var count:int = 0; count < networkNodes.length(); count++) {				
				if (String(networkNodes[count].@id) == String(descriptorNode.@networkID)) {					
					var infoNodes:XMLList = networkNodes[count].children();
					for (var count2:int = 0; count2 < infoNodes.length(); count2++) {						
						var currentNode:XML = infoNodes[count2] as XML;						
						//the following two attributes may not be present
						currentNode.@networkID = descriptorNode.@networkID;
						currentNode.@clientType = descriptorNode.@clientType;
						if (currentNode.toString() == descriptorNode.toString()) {
							delete infoNodes[count2];
							GlobalSettings.saveSettings();
						}
					}
				}
			}			
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
			} else {
				DebugView.addText ("   Using existing smart contract.");
				DebugView.addText ("      Address: " + this._contractInfo.child("address")[0].toString());
				DebugView.addText ("       TxHash: " + this._contractInfo.child("txhash")[0].toString());
				DebugView.addText ("          ABI: "+this._contractInfo.child("interface")[0].toString());
				var event:SmartContractEvent = new SmartContractEvent(SmartContractEvent.READY);
				this._abiString = this._contractInfo.child("interface")[0].toString();				
				this._abi = JSON.parse(this._abiString);
				event.descriptor = this._contractInfo;
				event.target = this;
				this._eventDispatcher.dispatchEvent(event);
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
		 * Generates an XML descriptor about a newly deployed/mined contract. The ABI (interface) definition of the contract 
		 * should already exist at this point.
		 * 
		 * @param	address The address at which the contract has been deployed/mined.
		 * @param	txhash The hash of the transaction in which the contract was deployed/mined.
		 * 
		 * @return	The newly created XML descriptor for the contract;
		 */
		private function __generateDescriptor(address:String, txhash:String):XML {
			var descriptorNode:XML = new XML("<" + this._contractName+" type=\"contract\" status=\"new\" />");
			var addressNode:XML = new XML("<address>" + address + "</address>");
			var txhashNode:XML = new XML("<txhash>" + txhash + "</txhash>");
			var abiNode:XML = new XML("<interface><![CDATA[" + this._abiString + "]]></interface>");
			descriptorNode.appendChild(addressNode);
			descriptorNode.appendChild(txhashNode);
			descriptorNode.appendChild(abiNode);
			return (descriptorNode);
		}
		
		/**
		 * Finds the ABI (interface) of the contract in the supplied solc-compiled contract(s) data. This data is typically supplied
		 * by an external source such as the solc compiler.
		 * 
		 * @param	deployData The JSON string representation of the single or multiple contract(s) data.
		 * 
		 * @return The JSON formatted ABI (interface) of the contract, or null if one can't be found.
		 */
		private function __findABIFromDeployData(deployData:String):String {
			DebugView.addText ("Attempting to find deploy data for contract: " + this._contractName);
			DebugView.addText(deployData);
			var parsedData:Object = JSON.parse(deployData);
			try {
				for (var contractName:String in parsedData.contracts) {
					if (contractName == this._contractName) {
						return (parsedData.contracts[contractName].abi);
					}
				}
			} catch (err:*) {
			}
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
			DebugView.addText ("SmartContract.__onCompileContract: "+this._contractName);			
			ethereum.client.removeEventListener(EthereumWeb3ClientEvent.SOLCOMPILED, this.__onCompileContract);			
			if (eventObj.compiledRaw != "") {
				var libsObj:Object = ethereum.generateDeployedLibsObj(this.clientType, this.networkID);
				ethereum.addEventListener(EthereumEvent.CONTRACTSDEPLOYED, this.__onDeployContract);
				ethereum.deployLinkedContracts(eventObj.compiledData, this._initializeParams, this._account, this._password, libsObj);
			}
		}
		
		/**
		 * Event listener function invoked during various stages of the contract deployment.
		 * 
		 * @param	err A contract mining error object, if an error occured.
		 * @param	contract An object containing information about the newly mined contract.
		 */
		private function __onDeployContract(eventObj:EthereumEvent):void 
		{
			DebugView.addText ("SmartContract.__onDeplyContract");
			DebugView.addText ("   Address: " + eventObj.contractAddress);
			DebugView.addText ("    TxHash:" + eventObj.txhash);			
			var event:SmartContractEvent = new SmartContractEvent(SmartContractEvent.READY);
			this._abiString = this.__findABIFromDeployData(eventObj.deployData);
			DebugView.addText ("       ABI:" + this._abiString);
			this._abi = JSON.parse(this._abiString);
			this._contractInfo = this.__generateDescriptor(eventObj.contractAddress, eventObj.txhash);
			DebugView.addText("Descriptor: " + this._contractInfo.toXMLString());
			if (useGlobalSettings) {
				var clientContractsNode:XML = GlobalSettings.getSetting("smartcontracts", "ethereum");
				var networkID:int = ethereum.client.networkID; //use current network ID
				var networkNodes:XMLList = clientContractsNode.children();
				for (var count:int = 0; count < networkNodes.length(); count++) {				
					if (String(networkNodes[count].@id) == String(networkID)) {					
						networkNodes[count].appendChild(this._contractInfo);
					}
				}
				GlobalSettings.saveSettings();
			}
			event.descriptor = this._contractInfo;
			event.target = this;
			this._eventDispatcher.dispatchEvent(event);
		}
	}
}
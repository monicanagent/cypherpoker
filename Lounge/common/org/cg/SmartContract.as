/**
* Manages the creation of, and interaction with, a single smart contract.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
	
	import org.cg.interfaces.ISmartContract;
	import flash.events.IEventDispatcher;
	import org.cg.events.SmartContractEvent;
	import flash.events.Event;
	import org.cg.SmartContractEventDispatcher;
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;
	import flash.utils.getDefinitionByName;;
	import org.cg.GlobalSettings;
	import flash.events.EventDispatcher;
	import org.cg.events.SmartContractEvent;
	import org.cg.events.EthereumEvent;
	import Ethereum;
	import events.EthereumWeb3ClientEvent;	
	
	
	dynamic public class SmartContract extends Proxy implements ISmartContract, IEventDispatcher {
		
		public static var deferStateCheckInterval:Number = 14000; //defines how often a deferred function should check the state of the smart contract, in milliseconds.		
		public static var ethereum:Ethereum = null; //reference to an active and initialized Ethereum instance		
		public var useGlobalSettings:Boolean = true; //If true, this contract instance will manage (add/remove/update) itself within the GlobalSettings XML data.
		private var _contractName:String; //The base name of the contract
		private var _eventDispatcher:SmartContractEventDispatcher;
		private var _descriptor:XML = null; //Reference to contract information node in the global settings data
		private var _clientType:String = "ethereum"; //The client or VM type for which the smart contract exists or should exist
		private var _networkID:uint = 1; //The network on which the smart contract is or should be deployed on
		private var _account:String; //The base user account to be used to invoke and pay for contract interactions
		private var _password:String; //The password for the base user account
		private var _abiString:String = null; //JSON string representation of the contract interface
		private var _abi:Array = null; //The parsed contract interface (ABI)
		private var _resultFormatter:String = null; //format to apply to next function invocation after which it's reset back to null; set in property getter so that it can be chained
		private var  _initializeParams:Object = null; //Contains parameters (within a property matching the contract name) used to initialize a new contract instance
		private var _deferStateCheckInterval:Number = -1; //overrides the validation interval, in milliseconds, for the current instance if larger than 0				
		private var _activeFunctions:Vector.<SmartContractFunction> = new Vector.<SmartContractFunction>(); //all currently active/deferred functions for this instance
		
		/**
		 * Creates a new instance of SmartContract.
		 * 
		 * @param	contractName The base name of the contract to associate with this instance. 
		 * @param	account The account to use to pay for interactions with the contract. This value may be set to
		 * null or an empty string ("") if the the contract's functions are not going to be invoked.
		 * @param	password The password for the included account parameter. This value may be set to
		 * null or an empty string ("") if the the contract's functions are not going to be invoked.
		 * @param	contractDescriptor Optional XML node containing information about the deployed contract to associate with this instance.		 
		 */
		public function SmartContract(contractName:String, account:String, password:String, contractDescriptor:XML = null) {
			this._eventDispatcher = new SmartContractEventDispatcher(this);
			this._contractName = contractName;
			this._descriptor = contractDescriptor;
			this._account = account;
			this._password = password;			
			if (contractDescriptor != null) {
				//get additional details from supplied contract information
				if ((contractDescriptor.@clientType!=null) && (contractDescriptor.@clientType!=undefined) && (contractDescriptor.@clientType!="")) {
					this._clientType = String(contractDescriptor.@clientType);
				}
				if ((contractDescriptor.@networkID!=null) && (contractDescriptor.@networkID!=undefined) && (contractDescriptor.@networkID!="")) {
					this._networkID = uint(contractDescriptor.@networkID);
				}
				this._abiString = contractDescriptor.child("interface")[0].toString();				
				this._abi = JSON.parse(this._abiString) as Array;
			}
		}
		
		/**
		 * The name of the associated smart contract. This is typically the same as the class name of the source Solidity file.
		 */
		public function get contractName():String {
			return (this._contractName);
		}
		
		/**
		 * An XML node containing a descriptor for the contract. Usually it will contain an <address> node with the contract's address
		 * on the blockchain, a <txhash> node containing the hash of the transaction used to create the contract, an <interface> node containing
		 * the JSON-encoded ABI of the contract, and a "type" attribute describing the contract type ("new", "active", or "library"). Other non-standard
		 * data may also be included.
		 */
		public function set descriptor(descSet:XML):void {
			this._descriptor = descSet;
		}
		
		public function get descriptor():XML {
			return (this._descriptor);
		}
		
		/**
		 * The JSON-string encoded ABI or interface of the contract. This is usually parsed into the "abi" array.
		 */
		public function get abiString():String {
			return (this._abiString);
		}
		
		/**
		 * The parsed contract abiString listing all of the contract's publicly available functions and variables.
		 */
		public function get abi():Array {
			return (this._abi);
		}
		
		/**
		 * The address of the contract on the blockchain as found in the descriptor's <address> node.
		 */
		public function get address():String {
			if (this._descriptor == null) {
				return (null);
			}
			try {
				return (this._descriptor.child("address")[0].toString());
			} catch (err:*) {				
			}
			return (null);
		}
		
		/**
		 * The account to use in combination with the "password" when interacting with the smart contract. This account will be debited or credited accordingly.
		 */
		public function get account():String {
			return (this._account);
		}
		
		/**
		 * The password to use in combination with the "account" when interacting with the smart contract.
		 */
		public function get password():String {
			return (this._password);
		}
		
		/**
		 * The type of client with which this smart contract is associated. The only currently valid client type is "ethereum".
		 */
		public function set clientType(typeSet:String):void {
			this._clientType = typeSet;
		}
		
		public function get clientType():String {
			return (this._clientType);
		}
		
		/**
		 * The network ID on which this contract exists. This value may not be used with all client types but with type "ethereum" valid client
		 * IDs may be found in the EthereumWeb3Client class (see "CLIENTNET_" constants in the header definition).
		 */
		public function set networkID(IDSet:uint):void {
			this._networkID = IDSet;
		}
		
		public function get networkID():uint {
			return (this._networkID);
		}	
		
		/**
		 * Interval time, in milliseconds, to delay between successive deferred contract invocation states. If this value isn't explicitly set
		 * it defaults to the "deferStateCheckInterval" value.
		 */
		public function set deferInterval(intervalSet:Number):void {
			this._deferStateCheckInterval = intervalSet;
		}		
				
		public function get deferInterval():Number {
			if (this._deferStateCheckInterval < 0) {
				this._deferStateCheckInterval = deferStateCheckInterval;
			}
			return (this._deferStateCheckInterval);
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
		 * @param	contractDescriptor An XML descriptor node for the contract.
		 * @param	updateGlobalSettings If true, the global settings XML data will be updated if the contract can't be
		 * found on the blockchain.
		 * 
		 * @return True if the smart contract exists on the blockchain, false otherwise.
		 */
		public static function validateContract(contractDescriptor:XML, updateGlobalSettings:Boolean = true):Boolean {
			if (contractDescriptor == null) {
				return (false);
			}
			try {				
				if (contractDescriptor.child("address")[0].toString() == "") {
					if (updateGlobalSettings) {
						__removeGlobalDescriptor(contractDescriptor);
					}
					return (false);
				}
				//the transaction hash might not be necessary but currently it should be included
				if (contractDescriptor.child("txhash")[0].toString() == "") {	
					if (updateGlobalSettings) {
						__removeGlobalDescriptor(contractDescriptor);
					}
					return (false);
				}
				if (contractDescriptor.child("interface")[0].toString() == "") {
					if (updateGlobalSettings) {
						__removeGlobalDescriptor(contractDescriptor);
					}
					return (false);
				}
			} catch (err:*) {
				if (updateGlobalSettings) {
					__removeGlobalDescriptor(contractDescriptor);
				}
				return (false);
			}
			//now check if the contract exists on the blockchain
			var address:String = contractDescriptor.child("address")[0].toString();
			var abiStr:String = contractDescriptor.child("interface")[0].toString();
			if (!ethereum.client.lib.checkContractExists(address, abiStr, "owner", "0x", false)) {	
				if (updateGlobalSettings) {
					__removeGlobalDescriptor(contractDescriptor);
				}
				return (false);
			}
			return (true);
		}
		
		/**
		 * Get property override handler used to retrieve a smart contract value.
		 * 
		 * @param	name The property being accessed.		 
		 * 
		 * @return The return value if the property if it exists, or null otherwise.
		 */
		override flash_proxy function getProperty(name:*):* {						
			switch (name.toString()) {
				case "toHex" : 
					this._resultFormatter = "hex";
					break;
				case "toString16" : 
					this._resultFormatter = "hex";
					break;
				case "toString" : 
					this._resultFormatter = "string";
					break;
				case "toInt" : 
					this._resultFormatter = "int";
					break;
				case "toNumber" : 
					this._resultFormatter = "int";
					break;
				case "toBool" : 
					this._resultFormatter = "boolean";
					break;
				case "toBoolean" : 
					this._resultFormatter = "boolean";
					break;
				default: break;					
			}
			return (this);
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
		 * Gets a default value defined in the global settings data (<smartcontracts>..<ethereum>..<defaults>), for the contract type associated with
		 * this class instance.
		 * 
		 * @param	defaultName The name of the node within the <defaults> node to retreieve.
		 * 
		 * @return The data contained in the specified node, or null if none can be found.
		 */
		public function getDefault(defaultName:String):String {
			var ethereumNode:XML = GlobalSettings.getSetting("smartcontracts", this._clientType);
			try {
				var defaultsNode:XML = ethereumNode.child("defaults")[0];
				var contractDefaultsNode:XML = defaultsNode.child(this._contractName)[0];
				var targetNode:XML = contractDefaultsNode.child(defaultName)[0];
				return (targetNode.children().toString());
			} catch (err:*) {
			}
			return (null);
		}

		/**
		 * Creates the smart contract. If the supplied contract info is supplied then the contract is assumed to exist on the blockchain
		 * and is used as-is, otherwise the contract is compiled and deployed.
		 * 
		 * @param	... args	Optional instantiation parameters to pass to the Ethereum contract (new) constructor. The final account/gas/value object
		 * will automatically be appended so it shouldn't be included.
		 */
		public function create(... args):void {
			DebugView.addText("SmartContract.create: " + this._contractName);
			this._initializeParams = new Object();
			this._initializeParams[this._contractName] = args;			
			if (this._descriptor == null) {
				DebugView.addText ("   Supplied contract information is null. Deploying new contract.");
				this.__compile();
			} else {
				DebugView.addText ("   Using existing smart contract.");
				DebugView.addText ("      Address: " + this._descriptor.child("address")[0].toString());
				DebugView.addText ("       TxHash: " + this._descriptor.child("txhash")[0].toString());
				var event:SmartContractEvent = new SmartContractEvent(SmartContractEvent.READY);
				event.descriptor = this._descriptor;
				this.dispatchEvent(event);
			}
		}
		
		/**
		 * Callback function invoked when an associated smart contract function has been successfully invoked. The reference to the function
		 * is removed from the internal _activeFunctions array.
		 * 
		 * @param	fRef A reference to the source SmartContractFunction instance.
		 */
		public function onInvoke(fRef:SmartContractFunction):void {
			for (var count:int = 0; count < this._activeFunctions.length; count++) {
				if (this._activeFunctions[count] == fRef) {
					this._activeFunctions.splice(count, 1);
					return;
				}
			}
		}
		
		/**
		 * Call property override handler used to invoke a smart contract function.
		 * 
		 * @param	name The call property (smart contract function) being handled.
		 * @param	...args The optional argument(s) being passed to the invocation.
		 * 
		 * @return The value of the storage variable if the property being called is not an invocable function, a reference to a SmartContractFunction 
		 * instance if the funciton is invocable, or null no such property exists.
		 */
		override flash_proxy function callProperty(name:*, ...args):* {
			if (name.toString() == "toString") {
				return ("[object SmartContract "+this._contractName+"]");
			}
			if (name.toString() == "valueOf") {
				return ("[object SmartContract]");
			}
			var functionABI:Object = this.__getFunctionABI(name);
			if (functionABI == null) {
				DebugView.addText ("Function \"" + name+"\" could not be found in interface (ABI) for contract \"" + this._contractName+"\"");
				return (null);
			}
			var newFunction:SmartContractFunction = new SmartContractFunction(this, ethereum, functionABI, args);
			newFunction.resultFormatter = this._resultFormatter;
			this._resultFormatter = null; //only valid for one function call
			if (newFunction.isFunction == false) {
				//this is an accessor / storage variable (not an invocable function), so return result right away				
				return (newFunction.invoke());
			} else {
				this._activeFunctions.push(newFunction);
				return (newFunction);
			}
			return (null);
		}
		
		//IEventDispatcher implementation
		
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
		
		public function dispatchEvent (event:Event) : Boolean {
			return (this._eventDispatcher.dispatchEvent(event));
		}
		
		/**
		 * Removes a supplied XML contract descriptor from the global settings data. The supplied data may be a linked reference to
		 * an existing node in the global settings data or an independent node.
		 * 
		 * @param	contractDescriptor The XML descriptor of the smart contract to remove from global settings data.
		 */
		private static function __removeGlobalDescriptor(contractDescriptor:XML):void {
			DebugView.addText ("Contract could not be found. Removing :" + contractDescriptor);			
			var clientContractsNode:XML = GlobalSettings.getSetting("smartcontracts", contractDescriptor.@clientType);	
			var returnContracts:Vector.<XML> = new Vector.<XML>();
			if (clientContractsNode.children().length() == 0) {
				return;
			}						
			var networkNodes:XMLList = clientContractsNode.children();
			for (var count:int = 0; count < networkNodes.length(); count++) {				
				if (String(networkNodes[count].@id) == String(contractDescriptor.@networkID)) {					
					var infoNodes:XMLList = networkNodes[count].children();
					for (var count2:int = 0; count2 < infoNodes.length(); count2++) {						
						var currentNode:XML = infoNodes[count2] as XML;						
						//the following two attributes may not be present
						currentNode.@networkID = contractDescriptor.@networkID;
						currentNode.@clientType = contractDescriptor.@clientType;
						if (currentNode.toString() == contractDescriptor.toString()) {
							delete infoNodes[count2];
							GlobalSettings.saveSettings();
						}
					}
				}
			}			
		}
		
		/**
		 * Returns the interface (ABI) of a single function from the smart contract's overall interface (ABI). 
		 * 
		 * @param	functionName The function name for which to retrieve an interface definition.
		 * 
		 * @return An object containing the interface definition (ABI) of the specified function, or null if no such function can be
		 * found in the smart contract's interface.
		 */
		private function __getFunctionABI (functionName:String):Object {			
			if (this._abi == null) {
				return (null);
			}			
			for (var count:int = 0; count < this._abi.length; count++) {
				var currentFunctionObj:Object = this._abi[count];
				if (currentFunctionObj.name == functionName) {
					return (currentFunctionObj);
				}
			}
			return (null);
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
			DebugView.addText ("SmartContract.__onDeployContract");
			DebugView.addText ("   Address: " + eventObj.contractAddress);
			DebugView.addText ("    TxHash:" + eventObj.txhash);			
			var event:SmartContractEvent = new SmartContractEvent(SmartContractEvent.READY);
			this._abiString = this.__findABIFromDeployData(eventObj.deployData);			
			this._abi = JSON.parse(this._abiString) as Array;
			this._descriptor = this.__generateDescriptor(eventObj.contractAddress, eventObj.txhash);
			if (useGlobalSettings) {
				var clientContractsNode:XML = GlobalSettings.getSetting("smartcontracts", "ethereum");
				var networkID:int = ethereum.client.networkID; //use current network ID
				var networkNodes:XMLList = clientContractsNode.children();
				for (var count:int = 0; count < networkNodes.length(); count++) {				
					if (String(networkNodes[count].@id) == String(networkID)) {					
						networkNodes[count].appendChild(this._descriptor);
					}
				}
				GlobalSettings.saveSettings();
			}
			event.descriptor = this._descriptor;
			this.dispatchEvent(event);			
		}
		
		/**
		 * Verifies a signed transaction object.
		 * 
		 * @param	transactionObj A transaction object containing a plaintext input "message" property, its cryptographic "signature", SHA3 "hash" output of "data", 
		 * a "nonce" value, and "delimiter". Optionally a "hashInput" and originating "account" property may also be included.
		 * @param	validAccounts A list of Ethereum accounts that are considered valid sources for the signed message.
		 * @param	checkHash It true the "hash" property of the transaction object is checked against the generated hash (default).
		 * 
		 * @return True if the message signature can be verified.
		 */
		public function verifySignedTransaction(transactionObj:Object, validAccounts:Array, checkHash:Boolean = true):Boolean {
			DebugView.addText("SmartContract.verifySignedTransaction");
			if (transactionObj == null) {
				DebugView.addText("   Transaction is null.");
				return (false);
			}			
			var signatureInfo:Object = this.getSigningInfo(transactionObj);
			if (checkHash) {
				if (signatureInfo.hash != transactionObj.hash) {
					//we may choose to ignore this
					DebugView.addText ("   SHA3/Keccak hash of value does not match provided hash.");							
					return (false);				
				}
			}
			var signatureAccount:String = signatureInfo.account;						
			for (var count:int = 0; count < validAccounts.length; count++) {				
				var currentAccount:String = validAccounts[count];
				if (currentAccount == signatureAccount) {					
					//do we want to check transactionObj.account for a match too?
					return (true);
				}
			}			
			return (false);
		}
		
		/**
		 * Returns the Ethereum signing information for specified signed input. The smart contract must support the "verifySignature" function
		 * which must be specified as a constant.
		 * 
		 * @param	input An input object, such as is generated by the Ethereum.sign method, containing the signed data for which to produce a signing signature. 
		 * The object must contain an input composite "message" property (see Etherum.sign method for the format), a "signature", SHA3/Keccak "hash" output of "message",
		 * a "nonce", and "delimiter".
		 * 
		 * @return An object containing the signing "account" (empty if none could be determined), original composite "message", the SHA3/Keccak "hash" generated from "message",
		 * and the original "signature".
		 */
		public function getSigningInfo(input:Object):Object {
			var outputObj:Object = new Object();
			outputObj.account = "";
			outputObj.hash = "";			
			outputObj.message = "";
			outputObj.signature = "";
			if (input == null) {
				return (outputObj);
			}
			try {
				outputObj.message = input.message;				
				outputObj.hash = this.addHexPrefix(ethereum.web3.sha3(input.message)); //requires "0x" prefix!
				outputObj.signature = input.signature;
				var signature:String = input.signature;
				if (signature.length < 66) {
					DebugView.addText ("SmartContract.getSigningInfo: provided signature is too short -- must be at least 66 characters.");
					return (outputObj);
					return (false);
				}
				signature = signature.split(" ").join("");
				if (signature.indexOf("0x") > -1) {
					signature = signature.substr(2);
				}
				var r:String = this.addHexPrefix(signature.substr(0, 64));
				var s:String = this.addHexPrefix(signature.substr(64, 64));
				var v:Number = Number(signature.substr(128, 2)) + 27;				
				outputObj.account = this.addHexPrefix(this.toString.verifySignature (outputObj.hash, v, r, s));
			} catch (err:*) {	
				outputObj.account = "";
				outputObj.hash = "";
				outputObj.message = "";
				outputObj.signature = "";
			}
			return (outputObj);
		}
		
		/**
		 * Adds hexadecimal data notation to a numeric string if the string doesn't have one. If the string already has "0x" notation then
		 * the input is returned as is.
		 * 
		 * @param	inputValue The hexadecimal numeric string to prepend with "0x" if this notation doesn't exist.
		 * 
		 * @return A copy of inputValue with the hexadecimal "0x" notation prepended.
		 */
		private function addHexPrefix(inputValue:String):String {			
			if (inputValue.indexOf("0x") > -1) {
				return (inputValue);
			}
			inputValue = inputValue.split(" ").join("");
			return ("0x" + inputValue);
		}
	}
}
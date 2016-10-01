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
		 * Deploys a single or multiple compiled contract(s) that may require linking. Non-linking contracts and libraries are deployed first and 
		 * subsequent contracts are dynamically linked as required.
		 * 
		 * @param	contractsData Compiled contract(s) data as would be created by utilities such as the solc compiler. The top-level object must be named
		 * "contracts" and child contracts are stored in name-value pairs within it. Each child contract object must contain an "abi" string definition and
		 * "bin" string with compiled binary contract data. A "deployedAt" property will be added to each child contract object as the deployed
		 * contract address is determined; this property will be used to link dependent contracts.	
		 * @param 	account The account to use/debit to deploy the contract(s).
		 * @param	password The password to use to unlock the deploying account.
		 * @param   deployedContracts Optional name-value pairs of existing contract/library addresses (e.g deployedContracts.myContract="0x90a901..."). 
		 * Any deployed contracts within contractsData are assumed to already exist on the target blockchain (i.e. they will not be deployed), 
		 * and their associated "deployedAt" property will be set.
		 * 
		 */
		public function deployLinkedContracts(contractsData:Object, account:String, password:String, deployedContracts:Object = null):void {
			DebugView.addText("Ethereum.deployLinkedContracts");
			//link already deployed contracts first
			if (deployedContracts != null) {
				DebugView.addText("   Linking existing contract/library addresses...");
				for (var deployedContract:String in deployedContracts) {
					for (var currentContract:String in contractsData.contracts) {
						if (currentContract == deployedContract) {
							contractsData.contracts[currentContract].deployedAt = deployedContracts[deployedContract];	
							this.linkContract(currentContract, deployedContracts[deployedContract], contractsData);
						}
					}
				}
			}
			contractsData.account = account;
			contractsData.password = password;
			for (currentContract in contractsData.contracts) {
				var currentContractObj:Object = contractsData.contracts[currentContract];				
				if (this.contractDeployable(currentContractObj)) {
					var linkName:String = this.contractLinkName(currentContract);
					var deployObj:Object = this.deployContract(JSON.stringify(contractsData), currentContract, currentContractObj.abi, currentContractObj.bin, contractsData.account, contractsData.password, this.onDeployContract);
				}
			}
		}
		
		/**
		 * Links a deployed contract/library within binary data of other contracts that specify it.
		 * 
		 * @param	contractName The name of the deployed contract being linked as it appears in the compiled contract data.
		 * @param	address The deployed address of the contract being linked.
		 * @param	contractsData Compiled contract(s) data as would be created by utilities such as the solc compiler, containing contracts
		 * that may require linking to the current contract.
		 */
		private function linkContract(contractName:String, address:String, contractsData:Object):void {
			var linkName:String = contractLinkName(contractName);
			address = address.split("0x").join(""); //strip leading "0x" if included
			for (var contract:String in contractsData.contracts) {
				var currentContract:Object = contractsData.contracts[contract];
				if (!this.contractDeployed(currentContract)) {
					DebugView.addText ("   Linking contract/library \"" + contractName+"\" at " + address + " in contract \""+contract+"\".");
					currentContract.bin=currentContract.bin.split(linkName).join(address);
				}
			}
		}
		
		/**
		 * Determines whether or not a specified contract object is deployable. A non-deployable contract is one that includes link
		 * identifiers that have not yet been substituted with deployed contract/library addresses, or one that has already been deployed
		 * (includes a valid "deployedAt" property).
		 * 		 
		 * @param	contractRef The compiled contract object to check for deployability.
		 * @param	padChar The standard padding character used when generating dynamic link identifiers.
		 * 
		 * @return True if the contract contains no dynamic link identifiers or deployedAt address and therefore may be deployed.
		 */
		private function contractDeployable(contractRef:Object, padChar:String = "_"):Boolean {
			if (contractRef.bin.indexOf(padChar) >-1) {
				return (false);
			}
			if ((contractRef["deployedAt"]!=undefined) && (contractRef["deployedAt"]!=null) && (contractRef["deployedAt"]!="")) {
				return (false);
			}
			return (true);
		}
		
		/**
		 * Determines whether a current contract object, as compiled by a utility such as solc, has already been deployed by
		 * checking its "deployedAt" property.
		 * 
		 * @param	contractRef The contract object to analyze.
		 * 
		 * @return True of the contract has already been deployed (has a valid Ethereum address).
		 */
		private function contractDeployed(contractRef:Object):Boolean {
			//should we also check for length?
			if ((contractRef["deployedAt"] != undefined) && (contractRef["deployedAt"] != null) && (contractRef["deployedAt"] != "")) {
				return (true);
			}
			return (false);
		}
		
		/**
		 * Produces an padded dynamic link name for a contract. The padded link name is usually used to dynamically link deployed contracts and libraries
		 * within other contracts.
		 * 
		 * @param	contractName The contract name for which to produce a link name.
		 * @param	linkLength The length of the output paddded link string.
		 * @param	padChar The padding character to use to produce the output link string.
		 * 
		 * @return The contract link name that may be used to search and replace dynamic contract/library addresses within compiled contract data.
		 */
		private function contractLinkName(contractName:String, linkLength:Number=40, padChar:String="_"):String {
			var returnName:String = padChar+padChar+contractName;
			for (var count:int = returnName.length; count < linkLength; count++) {
				returnName+= padChar;
			}
			return (returnName);
		}
		
		/**
		 * Deploys a compiled contract to the current Ethereum blockchain.
		 * 
		 * @param	A JSON-encoded string representing the compiled contract(s) currently being processed. This data will be returned in the callback
		 * so that subsequent processing can take place.
		 * @param	contractName The name of the contract to be deployed. This information will be included with the parameters in the callback.
		 * @param	abiStr The contract's JSON-encoded interface (ABI).
		 * @param	bytecode The contract's bytecode. Ensure that any libraries have been linked prior to including this data.
		 * @param	account The account from which to public the contract.
		 * @param	password The password to use to unlock the publishing account.
		 * @param	callback An optional callback function that is invoked during various stages of the deployment.
		 * @param	gas An optional gas amount to use to publish the contract with. If omitted or 0, the default gas amount is used (specified in the cypherpokerlib.js file).
		 * 
		 * @return An immediate return object containing the hash and address of the (as yet non-deployed) contract. Null is returned if there was a problem
		 * during deployment.
		 */
		public function deployContract (contractsData:String, contractName:String, abiStr:String, bytecode:String, account:String, password: String, callback:Function = null, gas:uint = 0):Object {	
			try {
				return (_ethereumClient.lib.deployContract(contractsData, contractName, abiStr, bytecode, account, password, callback, gas));
			} catch (err:*) {				
			}
			return (null);
		}
		
		/**
		 * Callback function invoked by the CypherPoker JavaScript Ethereum library during a contract deployment operation. This function may be invoked
		 * multiple times for a single contract during deployment.
		 * 
		 * @param	contractsData JSON-encoded contract(s) data containing deployment state(s) and addresses.
		 * @param	contractName The name of the contract that was just deployed.
		 * @param	error An error associated with the contract deployment (will be null if no error occured).
		 * @param	contract An object containing the contract data ("address" property will be undefined if contract has yet to be mined).
		 */
		public function onDeployContract(contractsData:String, contractName:String, error:Object=null, contract:Object=null):void {
			DebugView.addText ("Ethereum.onDeployContract: " + contractName);
			if (error != null) {
				DebugView.addText ("   ERROR: " + error);
				return;
			}
			if ((contract["address"] != undefined) && (contract["address"] != null) && (contract["address"] != "")) {
				DebugView.addText("   Contract address: " + String(contract["address"]));
				DebugView.addText("   Transaction hash: "+String(contract["transactionHash"]));
				var contractsDataObj:Object = JSON.parse(contractsData);
				var linkName:String = this.contractLinkName(contractName);
				for (var currentContractName:String in contractsDataObj.contracts) {
					var currentContractObj:Object = contractsDataObj.contracts[currentContractName];
					if (currentContractName == contractName) {
						//flag contract as deployed
						currentContractObj.deployedAt = String(contract["address"]);
						break;
					}
				}
				this.linkContract(contractName, String(contract["address"]), contractsDataObj);
				for (currentContractName in contractsDataObj.contracts) {
					currentContractObj = contractsDataObj.contracts[currentContractName];				
					if (this.contractDeployable(currentContractObj)) {
						linkName = this.contractLinkName(currentContractName);
						this.deployContract(JSON.stringify(currentContractObj), currentContractName, currentContractObj.abi, currentContractObj.bin, contractsDataObj.account, contractsDataObj.password, this.onDeployContract);						
					}
				}
			} else {
				DebugView.addText ("   Contract in mining queue.");
				DebugView.addText ("   Pending transaction hash: "+String(contract["transactionHash"]));
			}
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
			}
			if (contract.address != undefined) {
				DebugView.addText ("PokerHand contract has been mined.");
		 * @param	contract The contract information, if any, that was send with the callback.
		 */
		public function onDeployPokerHandContract(err:*= null, contract:*=null):void {
			if (contract == null) {
				DebugView.addText("onDeployPokerHandContract error --- "+err);
				for (var item:* in err) {
					DebugView.addText(item+"="+err);
				}
				return;
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
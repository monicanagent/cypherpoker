/**
* Manages the invocation of a single smart contract function on behald of a parent SmartContract instance.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
	
	import flash.events.EventDispatcher;
	import org.cg.SmartContract;
	import flash.utils.Timer;
	import flash.events.TimerEvent;	
	import org.cg.events.SmartContractFunctionEvent;
	
	public class SmartContractFunction extends EventDispatcher {	
		
		private var _resultFormatter:String = null; //result format to apply to data returned from smart contrac function invocation		
		private var _ethereum:Ethereum = null; //reference to an active Ethereum instance to be used for smart contract interaction
		private var _contract:SmartContract; //reference to the parent / owning smart contract
		private var _functionABI:Object; //function ABI (object that describes the smart contract function, its parameters, return values, etc.)
		private var _parameters:Array = null; //optional parameters to include with the smart contract invocation
		private var _transactionDetails:Object = null; //transaction details such as originating account (from), and gas to be included with the function invocation
		private var _deferStates:Array = null; //all the deferral states that must be met before the associated function is invoked
		private var _result:* = null; //returned result of the function invocation
		private var _startingFunction:Boolean = false; //is this a starting function? if true, set parent SmartContract's "started" flag to true
		private var _held:Boolean = false; //is function being held for invocation?	
		private var _invoked:Boolean = false; //has function been invoked?
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	parentContract A reference to the parent or owning SmartContract instance.
		 * @param	ethereum A reference to the currently active Ethereum instance to be used to interacting with the smart contract.
		 * @param	functionABI An object containing the smart contract function definition, usually as defined within a contract ABI.
		 * @param	parameters Optional parameters to be included with the smart contract invocation. Include only function-specific parameters, not 
		 * transaction parameters such as gas, value, or sender (these are included with the "invoke" method).
		 */
		public function SmartContractFunction(parentContract:SmartContract, ethereum:Ethereum, functionABI:Object, parameters:Array = null) {
			this._contract = parentContract;
			this._ethereum = ethereum;
			this._functionABI = functionABI;
			this._parameters = parameters;
		}
		
		/**
		 * The formatting to apply to the result/returned data from the smart contract function invocation. This value is usually assigned by the
		 * parent SmartContract instance and may be any of the following: toHex, toString16 (same as toHex), toString, toInt, toNumber (same as toInt), 
		 * toBool, and toBoolean (same as toBool).
		 */
		public function set resultFormatter(formatSet:String):void {
			this._resultFormatter = formatSet;
		}
		
		public function get resultFormatter():String {
			return (this._resultFormatter);
		}
		
		/**		 
		 * @return True if the referenced smart contract function is an invocable function, false if it's a pseudo-function (value accessor / storage variable).
		 */
		public function get isFunction():Boolean {
			if (this._functionABI.constant == true) {
				//accessor / storage variable (not an invocable function)
				return (false);
			} else {
				//invocable function
				return (true);
			}
		}
		
		/**		 
		 * @return The name of the function as specified in the associated ABI, or null if not found.
		 */
		public function get functionName():String {
			if (this._functionABI == null) {
				return (null);
			}
			return (this._functionABI.name);
		}
		
		/**
		 * Has function already been invoked?
		 */
		public function get invoked():Boolean {
			return (this._invoked);
		}
		
		/**
		 * @return	The returned result of the function invocation.
		 */
		public function get result():* {
			return (this._result);
		}
		
		/**
		 * A reference to an initialized Ethereum instance that the instance can use to access the smart contract.
		 */
		public function get ethereum():Ethereum {
			return (this._ethereum);
		}
		
		/**
		 * Is this a starting function? If so, it will set the parent SmartContract's "started" flag to true.
		 */
		public function set startingFunction(startingSet:Boolean):void {
			this._startingFunction = startingSet;
		}
		
		public function get startingFunction():Boolean {
			return (this._startingFunction);
		}
		
		/**
		 * True if the contract is being held, false if it's available for deferred or direct invocation or deferral checks. A held function will not trigger
		 * any deferred or direct invocations or attempt any deferral property checks. Basically, a held function is entirely inactive unless the hold
		 * is released. This is useful when the function may be needed but not at the present time; for example, a "full-contract" function in a hand
		 * where "full-contract" mode is currently not being used but may still be required.
		 */
		public function set held(heldSet:Boolean):void {
			this._held = heldSet;
			if (!this._held) {
				this._contract.startDeferChecks();
			}
		}
		
		public function get held():Boolean {
			return (this._held);
		}
		
		/**
		 * Invokes or begins deferred invocation of the associated smart contract function.
		 * 
		 * @param	transactionDetails An object containing properties to include with the function transaction call (sendTransaction). For details
		 * see: https://github.com/ethereum/wiki/wiki/JavaScript-API#web3ethsendtransaction
		 * @param	hold If true the startDeferChecks function of the parent contract is not called automatically and must be started manually. If false,		 
		 * deferred invocation checking of the parent contract is started automatically.
		 * @param   startingFunction If true this function is considered the contract starting function and will set "started" flag
		 * in the associated contract to true when invoked.
		 * 
		 * @return The return value of the invocation. This may be a storage variable value or details of a function invocation transaction depending
		 * on the function being invoked and how it's being called.
		 */
		public function invoke(transactionDetails:Object = null, hold:Boolean = false, startingFunction:Boolean = false):* {
			if (this._invoked) {
				this._contract.onInvoke(this);
				return (this);
			}
			this._transactionDetails = transactionDetails;
			this._held = hold;
			this.startingFunction = startingFunction;	
			if (this._held || (this.allStatesComplete == false)) {
				this._contract.startDeferChecks();
				return (null);
			}
			var event:SmartContractFunctionEvent = new SmartContractFunctionEvent(SmartContractFunctionEvent.INVOKE);
			this.dispatchEvent(event);
			if (this.isFunction == false) {
				this._result = JSON.parse(this._ethereum.client.lib.invoke(this._resultFormatter,
																this._contract.address, 
																this._contract.abiString, 
																this._functionABI.name, 
																this._parameters));	
				this._invoked = true;
			} else {				
				DebugView.addText("SmartContractFunction.invoke: " + this._contract.contractName + "." + this._functionABI.name+ " (instance #"+this._contract.instanceNum+", account: "+this._contract.account+")");				
				DebugView.addText("   @ " + this._contract.address);
				if (transactionDetails != null) {
					this._result = JSON.parse(this._ethereum.client.lib.invoke(this._resultFormatter,
																	this._contract.address, 
																	this._contract.abiString, 
																	this._functionABI.name, 
																	this._parameters, 
																	JSON.stringify(this._transactionDetails), 
																	this._contract.account, 
																	this._contract.password));
				} else {
					this._result = JSON.parse(this._ethereum.client.lib.invoke(this._resultFormatter,
																	this._contract.address, 
																	this._contract.abiString, 
																	this._functionABI.name, 
																	this._parameters, 
																	null, 
																	this._contract.account, 
																	this._contract.password));
				}
				DebugView.addText("   TxHash: " + this._result);
				if ((this._result != null) && (this._result != "null")) {
					if (this.startingFunction) {
						this._contract.started = true;
					}
					var postEvent:SmartContractFunctionEvent = new SmartContractFunctionEvent(SmartContractFunctionEvent.ONINVOKE);
					this.dispatchEvent(postEvent);
					this._contract.onInvoke(this);
					this._invoked = true;
				}
			}			
			return (this._result);
		}
		
		/**
		 * Checks the deferred states for the function and invokes the associates smart contract function if all states have
		 * been successfully fullfilled. This method is periodically invoked by the associated SmartContract instance when the defer timer
		 * is active.
		 */
		public function onStateCheckTimer():void {			
			if (this.allStatesComplete && (!this._held)) {				
				this.invoke(this._transactionDetails, this._held, this.startingFunction);
			}
		}
		
		/**
		 * Defines defer state(s) for this instance. Any included states must validate before the associated function is invoked. Deferred
		 * invocations will not be executed until the "invoke" method is called.
		 * 
		 * @param	stateObjects An array of SmartContractDeferState instances. Any objects that are not of type SmartContractDeferState will
		 * be ignored.		 
		 * 
		 * @return A reference to this SmartContractFunction instance that mmay be used for chained invocation calls. For example:
		 * 			functionInstance.defer([deferStateInstance]).invoke({from: account, gas:200000});
		 */
		public function defer(stateObjects:Array):SmartContractFunction {			
			if (this._deferStates == null) {
				this._deferStates = new Array();
			}
			for (var count:int = 0; count < stateObjects.length; count++) {
				this._deferStates.push(stateObjects[count]);
			}			 			
			for (count = 0; count < this._deferStates.length; count++) {				
				SmartContractDeferState(this._deferStates[count]).smartContract = this._contract;
				SmartContractDeferState(this._deferStates[count]).smartContractFunction = this;
			}
			return (this);
		}
		
		/**
		 * Standard toString override method.
		 * 
		 * @return A standard class object string definition including the function name as defined in the function ABI definition.
		 */
		override public function toString():String {
			return ("[object SmartContractFunction " + this._functionABI.name+"]");
		}
		
		/**
		 * Prepare the instance for removal from application memory.
		 */
		public function destroy():void {			
			this._ethereum = null;
			this._contract = null;
			this._functionABI = null;
			this._parameters = null;
			this._transactionDetails = null;
			this._deferStates = null;
			this._result = null;
		}
		
		/**
		 * @return	True if all associated defer states are complete or fulfilled, or if no defer states have been specified. False if one or more states
		 * have yet to be fulfilled.
		 */
		private function get allStatesComplete():Boolean {
			if (this._deferStates == null) {
				return (true);
			}
			for (var count:int = 0; count < this._deferStates.length; count++) {
				if (this._deferStates[count] is SmartContractDeferState) {
					if (SmartContractDeferState(this._deferStates[count]).complete == false) {						
						return (false);
					}
				}
			}
			return (true);
		}
	}
}
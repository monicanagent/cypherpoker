/**
* Manages the invocation of a single smart contract function on behald of a parent SmartContract instance.
*
* (C)opyright 2016
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
	import org.cg.DebugView;
	import org.cg.events.SmartContractFunctionEvent;
	
	public class SmartContractFunction extends EventDispatcher {
		
		public static var deferStateCheckInterval:Number = 5000; //defines how often a deferred function should check the state of the smart contract, in milliseconds.
				
		private var _resultFormatter:String = null;
		private var _deferStateCheckInterval:Number = -1; //overrides the validation interval, in milliseconds, for the current instance if larger than 0
		private var _deferCheckTimer:Timer = null; //Timer instance used to periodically check defer states. Uses one of the above interval values.
		private var _ethereum:Ethereum = null; //reference to an active Ethereum instance to be used for smart contract interaction
		private var _contract:SmartContract; //reference to the parent / owning smart contract
		private var _functionABI:Object; //function ABI (object that describes the smart contract function, its parameters, return values, etc.)
		private var _parameters:Array = null; //optional parameters to include with the smart contract invocation
		private var _transactionDetails:Object = null; //transaction details such as originating account (from), and gas to be included with the function invocation
		private var _deferStates:Array = null; //all the deferral states that must be met before the associated function is invoked
		private var _result:* = null; //returned result of the function invocation
		
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
		 * @return	The returned result of the function invocation.
		 */
		public function get result():* {
			return (this._result);
		}
		
		public function get ethereum():Ethereum {
			return (this._ethereum);
		}
		
		/**
		 * Defines defer state(s) for this instance. Any included states must validate before the associated function is invoked. Deferred
		 * invocations will not be executed until the "invoke" method is called.
		 * 
		 * @param	stateObjects An array of SmartContractDeferState instances. Any objects that are not of type SmartContractDeferState will
		 * be ignored.
		 * @param	deferInterval Optional interval, in milliseconds, in which to check defer states. If omitted, -1 is used instead which 
		 * results in the "deferStateCheckInterval" value being used for the timer when it is instantiated.
		 * 
		 * @return A reference to this SmartContractFunction instance that mmay be used for chained invocation calls. For example:
		 * 			functionInstance.defer([deferStateInstance]).invoke({from: account, gas:470000});
		 */
		public function defer(stateObjects:Array, deferInterval:Number = -1):SmartContractFunction {
			this._deferStateCheckInterval = deferInterval;
			this._deferStates = stateObjects;
			for (var count:int = 0; count < this._deferStates.length; count++) {
				if (this._deferStates[count] is SmartContractDeferState) {
					SmartContractDeferState(this._deferStates[count]).smartContract = this._contract;
					SmartContractDeferState(this._deferStates[count]).smartContractFunction = this;
				}
			}
			return (this);
		}
		
		
		/**
		 * @return	True if all associated defer states are fulfilled, or if no defer states have been specified. False if one or more states
		 * have yet to be fulfilled.
		 */
		private function get allStatesFulfilled():Boolean {
			if (this._deferStates == null) {
				DebugView.addText("No defer states to check");
				return (true);
			}
			DebugView.addText("Checking " + this._deferStates.length + " defer states...");
			for (var count:int = 0; count < this._deferStates.length; count++) {
				if (this._deferStates[count] is SmartContractDeferState) {
					if (SmartContractDeferState(this._deferStates[count]).complete == false) {
						return (false);
					}
				}
			}
			DebugView.addText("All defer states pass");
			return (true);
		}
		
		private function onStateCheckTimer(eventObj:TimerEvent):void {
			if (this.allStatesFulfilled) {
				this._deferCheckTimer.stop();
				this._deferCheckTimer.removeEventListener(TimerEvent.TIMER, this.onStateCheckTimer);
				this.invoke(null, true);
			}
		}
		
		/**
		 * Invokes or begins deferred invocation of the associated smart contract function.
		 * 
		 * @param	transactionDetails An object containing properties to include with the function transaction call (sendTransaction). For details
		 * see: https://github.com/ethereum/wiki/wiki/JavaScript-API#web3ethsendtransaction
		 * @param	deferred If true the invocation is assumed to be deferred and the transactionDetails object is ignored since it's assumed to 
		 * already exist. For most common uses this value should be false (default).
		 * 
		 * @return The return value of the invocation. This may be a storage variable value or details of a function invocation transaction depending
		 * on the function being invoked and how it's being called.
		 */
		public function invoke(transactionDetails:Object = null, deferred:Boolean = false):* {
			if (!deferred) {
				this._transactionDetails = transactionDetails;
			}
			if (this.allStatesFulfilled == false) {
				if (this._deferStateCheckInterval < 0) {
					this._deferStateCheckInterval = deferStateCheckInterval;
				}
				this._deferCheckTimer = new Timer(this._deferStateCheckInterval);
				this._deferCheckTimer.addEventListener(TimerEvent.TIMER, this.onStateCheckTimer);
				this._deferCheckTimer.start();
				return;
			}
			DebugView.addText("All required deferral states fulfilled. Now executing: "+this._functionABI.name);
			var event:SmartContractFunctionEvent = new SmartContractFunctionEvent(SmartContractFunctionEvent.INVOKE);
			this.dispatchEvent(event);
			if (this.isFunction == false) {				
				this._result = JSON.parse(this._ethereum.client.lib.invoke(this._resultFormatter,
																this._contract.address, 
																this._contract.abiString, 
																this._functionABI.name, 
																this._parameters));
			} else {				
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
			}
			var postEvent:SmartContractFunctionEvent = new SmartContractFunctionEvent(SmartContractFunctionEvent.ONINVOKE);
			this.dispatchEvent(postEvent);
			return (this._result);
		}
		
	}

}
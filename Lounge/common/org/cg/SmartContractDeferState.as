/**
* Stores and verifies a state for deferred contract invocation. Instances of SmartContractDeferState are used in conjunction with 
* SmartContract and SmartContractFunction instances.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
	
	import org.cg.SmartContract;
	import org.cg.SmartContractFunction;
	
	public class SmartContractDeferState {
		
		//SmartContract and SmartContractFunction instances associated with this defer state. These references are set by the associated
		//SmartContractFunction instance when the "defer" method is called.
		public var smartContract:SmartContract = null;
		public var smartContractFunction:SmartContractFunction = null;
		
		private var _variable:String = null; //the name of the variable that should contain the _expectedValue value in order to fulfill the defer state
		private var _parameters:Array = null; //any parameters to be used to access the smart contract storage variable (for structs or multidimensional arrays, for example)
		private var _expectedValue:*; //the value(s) that the specified variable should contain in order to fulfill the defer state
		
		public function SmartContractDeferState(variable:String, parameters:Array, expectedValue:*) {
			this._variable = variable;
			this._parameters = parameters;
			this._expectedValue = expectedValue;
		}
		
		/**
		 * @return	True if the defer state has been fulfilled as specified, otherwise false.
		 */
		public function get fulfilled():Boolean {
			DebugView.addText ("Checking fullfillment of smart contract property: " + this._variable);
			DebugView.addText ("Expecting: " + this._expectedValue);
			var result:* = JSON.parse(this.smartContractFunction.ethereum.client.lib.invoke(this.smartContract.address, this.smartContract.abiString, this._variable, this._parameters));
			DebugView.addText ("Actual value: " + result);
			if (result == this._expectedValue) {
				return (true);
			} else {
				return (false);
			}
		}
		
	}

}
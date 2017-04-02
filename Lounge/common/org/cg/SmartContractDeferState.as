/**
* Provides standardized access for SmartContract and SmartContractFunction instances to evaluate states or conditions for deferred execution.
* Deferred state evaluation is accomplished through an externally referenced function.
*
* (C)opyright 2014 to 2017
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
		
		//reference to the state evaluation function (must accept SmartContractDefer state as it's first and only parameter and must return a boolean value)
		private var _function:Function = null; 
		private var _context:* = null; //optional context or scope in which _function is executed
		private var _data:* = null; //any additional data included with the instance
		private var _expectedValue:*; //the value that _function will return when the evaluation is successful
		private var _staticEval:Boolean = false; //should evaluation be run every time "complete" is called or should _complete be returned once it evaluates to true?
		private var _complete:Boolean = false; //stores the completion of the state check to prevent redundant evaluations
		
		//contract through which defer evaluations should be executed; getter/setter provided, 
		//defaults to "smartContract" reference
		private var _operationContract:SmartContract = null; 
		//contract containing the data to be accessed; getter/setter provided, defaults to "operationContract" reference
		private var _dataContract:SmartContract = null;
		/**
		 * Creates a new defer state evaluator instance.
		 * 
		 * @param	funcRef A reference to the function that will perform the state evaluation. The referenced function must accept a
		 * 		SmartContractDeferState object as its first and only parameter, and must return a boolean value: true if the evaluation passed
		 * 		and false if it hasn't.
		 * @param	data Optional additional data that "funcRef" may access for evaluation.
		 * @param	context The optional context or scope in which to execute "funcRef".
		 * @param	staticEval If true a check is forced on every call of "complete" even when prior evaluation returned true otherwise
		 * the internal complete state is returned once a successful evaluation is made.
		 */
		public function SmartContractDeferState(funcRef:Function, data:* = null, context:* = null, staticEval:Boolean = false) {
			this._function = funcRef;
			this._data = data;
			this._context = context;
			this._staticEval = staticEval;
		}
		
		/**
		 * Reference to the context or scope in which the evaluation function should execute.
		 */
		public function get context():* {
			return (this._context);
		}
		
		/**
		 * Any additional data that the evaluation function may require.
		 */
		public function get data():* {
			return (this._data);
		}
		
		/**
		 * @return	True if the defer state has been fulfilled (completed) according to the specified evaluation function. If the referenced evaluation
		 * function doesn't return a boolean value or throws an exception false will always be returned.
		 */
		public function get complete():Boolean {
			if (this._complete && (!this._staticEval)) {
				return (true);
			}
			try {				
				if (this.context != null) {
					this._complete = this._function.call(this.context, this);
				} else {
					this._complete = this._function(this);
				}
			} catch (err:*) {
				this._complete = false;
				DebugView.addText (err.getStackTrace());
			}
			return (this._complete);
		}		
		
		/**
		 * The SmartContract reference through which data read operations should be applied during deferred checks. 
		 * If not set (null) then the current "smartContract" reference is returned.
		 */
		public function get operationContract():SmartContract {
			if (this._operationContract == null) {
				this._operationContract = this.smartContract;
			}
			return (this._operationContract);
		}
		
		public function set operationContract(contractSet:SmartContract):void {
			this._operationContract = contractSet;
		}
		
		/**
		 * The SmartContract reference through containing data to be accessed. 
		 * If not set (null) then the current "operationContract" reference is returned.
		 */
		public function get dataContract():SmartContract {
			if (this._dataContract == null) {
				this._dataContract = this.operationContract;
			}
			return (this._dataContract);
		}
		
		public function set dataContract(contractSet:SmartContract):void {
			this._dataContract = contractSet;
		}
	}
}
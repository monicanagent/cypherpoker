/**
* Provides standardized access for SmartContract and SmartContractFunction instances to evaluate states or conditions for deferred execution.
* Deferred state evaluation is accomplished through an externally referenced function.
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
		
		//reference to the state evaluation function (must accept SmartContractDefer state as it's first and only parameter and must return a boolean value)
		private var _function:Function = null; 
		private var _context:* = null; //optional context or scope in which _function is executed
		private var _data:* = null; //any additional data included with the instance
		private var _expectedValue:*; //the value that _function will return when the evaluation is successful
		
		/**
		 * Creates a new defer state evaluator instance.
		 * 
		 * @param	funcRef A reference to the function that will perform the state evaluation. The referenced function must accept a
		 * 		SmartContractDeferState object as its first and only parameter, and must return a boolean value: true if the evaluation passed
		 * 		and false if it hasn't.
		 * @param	data Optional additional data that "funcRef" may access for evaluation.
		 * @param	context The optional context or scope in which to execute "funcRef".		 
		 */
		public function SmartContractDeferState(funcRef:Function, data:* = null, context:* = null) {
			this._function = funcRef;
			this._data = data;
			this._context = context;			
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
			try {
				if (this.context != null) {
					return(this._function.call(this.context, this));
				} else {
					return(this._function(this));
				}				
			} catch (err:*) {				
			}
			return (false);
		}		
	}
}
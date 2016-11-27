/**
* Stores information about a current ongoing operation (e.g. crypto), and automatically retries if it fails to complete in a certain amount of
* time. The retry operation may also be invoked directly if, for example, an expected value is not present.
* 
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/ 

package org.cg  {	
	
	import flash.events.TimerEvent
	import flash.utils.Timer;
	
	public class OperationRetry {
		
		//TODO: Add support for maximum retries and global failure handler
		
		private static var _retries:int = 0; //counts the number of retry instances that have not been cancelled
		private var _callback:Function = null;
		private var _parameters:Array = null;
		private var _context:* = null;
		private var _timeout:Number = -1;
		private var _timer:Timer = null;
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	callbackRef The callbackfunction to be invoked on a retry. Optional (may be set using setter). The referenced function *must* be public.
		 * @param	parameters The optional parameters to include with the retry function invocation.
		 * @param 	context The optional context or scope in which to invoke the retry operation.
		 * @param	timeout The optional timeout, in milliseconds, to wait before automatically invoking the function. If less than 0, no 
		 * timeout is used. If greater than 0 the timer is started immediately.
		 */
		public function OperationRetry(callbackRef:* = null, parameters:Array = null, context:* = null, timeout:Number = -1) {
			this.callback = callbackRef;
			this.parameters = parameters;
			this.context = context;
			this.timeout = timeout;
			_retries++;
		}
		
		/**
		 * Retries the operation by invoking the specified callback function with any supplied parameters and in the optional context.
		 * Up to 6 parameters are supported with a null-context invocation.
		 * Any currently running timer is stopped and removed.
		 */
		public function retry():void {
			this.cancel(); //cancel and remove timer
			if (this.callback != null) {
				if (this.context!=null) {
					if (this.parameters!=null) {
						this.callback.apply(this.context, this.parameters);
					} else {
						this.callback.apply(this.context);
					}
				} else {
					if (this.parameters != null) {
						switch (this.parameters.length) {
							case 1: this.callback(this.parameters[0]); break;
							case 2: this.callback(this.parameters[0],this.parameters[1]); break;
							case 3: this.callback(this.parameters[0],this.parameters[1],this.parameters[2]); break;
							case 4: this.callback(this.parameters[0],this.parameters[1],this.parameters[2],this.parameters[3]); break;
							case 5: this.callback(this.parameters[0],this.parameters[1],this.parameters[2],this.parameters[3],this.parameters[4]); break;
							case 6: this.callback(this.parameters[0],this.parameters[1],this.parameters[2],this.parameters[3],this.parameters[4],this.parameters[5]); break;
							//add more if necessary
							default: this.callback(); break;
						}						
					} else {
						this.callback();
					}
				}				
			}
		}
		
		/**
		 * Cancels the retry when it's no longer needed. Any running timer is automatically stopped and removed. Any non-cancelled
		 * retries are counted in the static _retries property so all successful retries should be cancelled.
		 */
		public function cancel():void {
			if (this._timer != null) {
				this._timer.stop();
				this._timer.removeEventListener(TimerEvent.TIMER, this.onTimeout);
				this._timer = null;
			}
			_retries--;
			if (_retries < 0) {
				_retries = 0;
			}
		}
		
		/**
		 * Restarte the timeout if a previously set timer was already running. If no timer was active this function does nothing.
		 */
		public function restart():void {
			this.timeout = this._timeout; //cancels and restart
		}
		
		/**
		 * The callback function to invoke on a retry. The referenced function *must* be public.
		 */
		public function set callback (functionRef:Function):void {
			this._callback = functionRef;
		}
		
		public function get callback():Function {
			return (this._callback);
		}
		
		/**
		 * The parameters to include with the callback function, stored in order as they appear in the callback function.
		 */
		public function set parameters (params:Array):void {
			this._parameters = params;
		}
		
		public function get parameters():Array {
			return (this._parameters);
		}
		
		/**
		 * The context or scope in which the callback function should be invoked.
		 */
		public function set context (contextSet:*):void {
			this._context = contextSet;
		}
		
		public function get context():* {
			return (this._context);
		}
		
		/**
		 * The timeout value, in milliseconds, after which the callback function is automatically invoked. If this value is greater
		 * than 0 the timeout timer is automatically started. If any timer is currently active it is first cleared and removed.
		 */
		public function set timeout (timeoutSet:Number):void {
			this.cancel();
			this._timeout = timeoutSet;
			if (this._timeout > 0) {
				this._timer = new Timer(this._timeout);
				this._timer.addEventListener(TimerEvent.TIMER, this.onTimeout);
				this._timer.start();
			}
		}
		
		public function get timeout():Number {
			return (this._timeout);
		}		
		
		/**
		 * Event listener invoked when the timeout timer has elapse.
		 * 
		 * @param	eventObj A standard TimerEvent object.
		 */
		private function onTimeout(eventObj:TimerEvent):void {
			this._timer.stop();
			this._timer.removeEventListener(TimerEvent.TIMER, this.onTimeout);
			this._timer = null;
			this.retry();
		}
	}
}
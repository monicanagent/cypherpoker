/**
* Used to track and filter CryptoWorkerHost request/response messages to ensure that they're being processed correctly.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
	
	import p2p3.workers.WorkerMessage;
	
	public class WorkerMessageFilter {
		
		private var _messages:Vector.<WorkerMessage> = new Vector.<WorkerMessage>(); //all worker messages being filtered by this instance
		
		public function WorkerMessageFilter() {
		}
		
		/**
		 * Adds the specified message to the internal _messages vector array.
		 */
		public function addMessage(msg:WorkerMessage):void {
			if (this._messages == null) {
				this._messages = new Vector.<WorkerMessage>();
			}
			this._messages.push(msg);
		}
		
		/**
		 * Determines if a specific message is included in the current filter instance.
		 * 
		 * @param	sourceMsg The source/response message that should be checked. The message's requestId property is used to determine
		 * if the message matches.
		 * @param   removeOnMatch If true the message referefence is removed once an internal match is found (subsequent calls to "includes" would
		 * return false). If false, the message reference is kept.
		 * 
		 * @return True if the requestId of the source message matches the requestId of a stored message, false otherwise.
		 */
		public function includes(sourceMsg:WorkerMessage, removeOnMatch:Boolean = true):Boolean {
			if (sourceMsg == null) {
				return (false);
			}
			for (var count:int = 0; count < this._messages.length; count++) {
				if (this._messages[count].requestId == sourceMsg.requestId) {
					if (removeOnMatch) {
						this._messages.splice(count, 1);
					}
					return (true);
				}
			}
			return (false);
		}
		
		/**
		 * Clears the internal list of stored messages and removes the internal array.
		 */
		public function destroy():void {
			for (var count:int = 0; count < this._messages.length; count++) {
				this._messages[count] = null;
			}
			this._messages = null;
		}		
	}
}
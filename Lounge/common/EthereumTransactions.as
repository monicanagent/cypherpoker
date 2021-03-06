/**
* Manages signed Ethereum transactions and associated data for an external class.
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package {
	
	public class EthereumTransactions 	{
		
		//each object contains a "tx" transaction object and optional "extra" data
		private var _transactions:Vector.<Object> = new Vector.<Object>();
		
		public function EthereumTransactions() 	{			
		}
		
		/**
		 * Returns a vector array of just the contained transaction objects, omitting any extra associated data.
		 */
		public function get rawTransactions():Vector.<Object> {
			var returnArr:Vector.<Object> = new Vector.<Object>();
			for (var count:int = 0; count < this._transactions.length; count++) {
				returnArr.push(this._transactions[count].tx);
			}
			return (returnArr);
		}
		
		/**
		 * Returns all stored transactions and extra data. Each object contains a "tx" signed transaction object and may contain
		 * an "extra" object with any extra associated data.
		 */
		public function get transactions():Vector.<Object> {
			return (this._transactions);		
		}
		
		/**
		 * Attempts to add a signed transaction object to internal storage.
		 * 
		 * @param	txObj The transaction object to store. This object must contain at least "data", "delimiter", "nonce" and "signature"
		 * properties such as would be generated by the Ethereum.sign method. In addition, "signature" must be at least 66 characters long.
		 * @param	extraData Any additional data to be included with the transaction. Optional.
		 * 
		 * @return True if the transaction contains all of the required properties and was added to internal storage, false otherwise.
		 */
		public function addTransaction(txObj:Object, extraData:* = null):Boolean {
			if (txObj == null) {
				return (false);
			}
			try {
				if ((txObj.data == null) || (txObj.delimiter == null) || (txObj.nonce == null) || (txObj.signature == null)) {
					return (false);
				}
				if (txObj.signature.length < 66) {
					return (false);
				}
				var storageObj:Object = new Object();
				storageObj.tx = txObj;
				storageObj.extra = extraData;
				//we should be storing these to disk in case we need to restore later
				this._transactions.push(storageObj);
				return (true);
			} catch (err:*) {				
			}
			return (false);
		}
	}
}
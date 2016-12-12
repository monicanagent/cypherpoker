/**
* Stores and retrieves multiple SRA (or SRA-like) keys and provides some basic associated operations.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package crypto {

	import crypto.interfaces.ISRAKey;
	import crypto.interfaces.ISRAMultiKey;
	import flash.events.EventDispatcher;
	import crypto.events.SRAMultiKeyEvent;
	import p2p3.interfaces.ICryptoWorkerHost;
	import p2p3.workers.events.CryptoWorkerHostEvent;
	import p2p3.workers.WorkerMessage;
	import flash.utils.getDefinitionByName;
	import org.cg.WorkerMessageFilter;
	import org.cg.DebugView;
	
	public class SRAMultiKey extends EventDispatcher implements ISRAMultiKey {
		
		private var _keys:Vector.<ISRAKey>; //Sequence of stored or generated keys.
		private var _cryptoWorkerHostGetter:Function = null; //Reference to a valid getter function for CryptoWorkerHost instances (implementations of ICryptoWorkerHost).
		private var _generateCBL:uint; //The crypto byte length to use for generating keys.
		private var _generateCounter:uint = 0; //Used to count the number of keys currently generated.
		private var _messageFilter:WorkerMessageFilter;
		
		/**
		 * Creates an instance of the SRAMultiKey class.
		 * 
		 * @param	initValues An anonymous object or array of ISRAKey implementations, Vector array of ISRAKey implementations, or existing SRAMultiKey instance to copy
		 * (not store references) to the current instance.
		 */
		public function SRAMultiKey(initValues:*=null) {
			if (initValues != null) {
				this.copyKeys(initValues);
			}
			this._messageFilter = new WorkerMessageFilter();
			super();
		}		
		
		/**
		 * Generates a series of SRA keys to be stored within the current class instance.
		 * 
		 * @param	cryptoWorkerHostGetter A reference to a function that will retrieve the next (possibly only) available CryptoWorkerHost instance.
		 * If null is specified or if the function does not return an ICryptoWorkerHost implementation an error event will be broadcast immediately.
		 * @param	numKeys The number of keys to generate. If 0, no keys will be genarated and the completion event will be broadcast immediately.
		 * @param	CBL The crypto byte length of the key(s) to generate.
		 * @param	prime A numeric string representing the shared prime value to be used to generate the key(s). ActionScript hexadecimal "0x" 
		 * notation can be used.
		 * 
		 */
		public function generateKeys(cryptoWorkerHostGetter:Function, numKeys:uint, CBL:uint, prime:String):void {
			if (numKeys == 0) {
				this.dispatchEvent(new SRAMultiKeyEvent(SRAMultiKeyEvent.ONGENERATEKEYS));
				return;
			}
			if (cryptoWorkerHostGetter == null) {
				DebugView.addText("SRAMultiKey.generateKeys - cryptoWorkerHostGetter is null");
				this.dispatchEvent(new SRAMultiKeyEvent(SRAMultiKeyEvent.ONGENERATEERROR));
				return;
			}
			if (!(cryptoWorkerHostGetter() is ICryptoWorkerHost)) {
				DebugView.addText("SRAMultiKey.generateKeys - cryptoWorkerHostGetter does not return an ICryptoWorkerHost implementation.");
				this.dispatchEvent(new SRAMultiKeyEvent(SRAMultiKeyEvent.ONGENERATEERROR));
				return;
			}
			this._cryptoWorkerHostGetter = cryptoWorkerHostGetter;
			this._keys = new Vector.<ISRAKey>();
			this._generateCounter = numKeys;
			this._generateCBL = CBL;
			var cryptoWorker:ICryptoWorkerHost = this._cryptoWorkerHostGetter();
			cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, this.onGenerateKey);
			cryptoWorker.directWorkerEventProxy = onGenerateKeyProxy;
			var msg:WorkerMessage = cryptoWorker.generateRandomSRAKey(prime, false, CBL);
			this._messageFilter.addMessage(msg);
		}
		
		/**
		 * Returns an ISRAKey implementation stored by this instance at the specified index.
		 * 
		 * @param	index The index of the stored ISRAKey implementation to return.
		 * 
		 * @return The stored ISRAKey implementation or null if either the index is out of range or the
		 * storage slot has been set to null.
		 */
		public function getKey(index:int = 0):ISRAKey {
			if (this._keys == null) {
				return (null);
			}
			if (index >= this._keys.length) {
				return (null);
			}
			return (this._keys[index]);
		}
		
		/**
		 * Stores an ISRAKey implementation to the specified index of the internal keys Vector array.
		 * 
		 * @param	key The ISRAKey implementation to set/store.
		 * @param	index The index at which to store the key. If index is less than 0 the key is appended on the end of the internal array.
		 * If the index is beyond the length of the array, null values are used to fill unalocated indexes (so that the key is at the specified index).
		 */
		public function setKey(key:ISRAKey, index:int = -1):void {
			if (this._keys == null) {
				this._keys = new Vector.<ISRAKey>();
			}
			if (index < 0) {
				this._keys.push(key);
				return;
			} else if (index >= this._keys.length) {
				for (var count:int = 0; count < (index-this._keys.length); count++) {
					this._keys.push(null);
				}
				this._keys.push(key);
				return;
			} else {
				this._keys[index] = key;
			}
		}
		
		/**
		 * Returns the number of keys being stored by this instance.
		 */
		public function get numKeys():int {
			if (this._keys == null) {
				return (0);
			}
			return (this._keys.length);
		}
		
		/**
		 * If true the key's data may be secured in the Encrypted Local Store otherwise they may only be stored in
		 * standard memory. This flag does not indicate the status of the key's current security status (use "secure" instead).
		 */
		public function get securable():Boolean	{
			if (EncryptedLocalStore == null) {
				return (false);
			}
			if (EncryptedLocalStore.isSupported == false) {
				return (false);
			}			
			return (true);
		}		
		
		/**
		 * Scrubs the instance by first scrubbing individual keys and then releasing used memory.
		 */
		public function scrub():void {
			for (var count:int = 0; count < this._keys.length; count++) {
				this._keys[count].scrub();
			}
			this._keys = null;
		}
		
		/**
		 * Returns a dynamic reference to the flash.data.EncryptedLocalStore class if available in the
		 * current environment, or null otherwise.
		 */
		private static function get EncryptedLocalStore():Class {
			try {
				var ELSClass:Class = getDefinitionByName("flash.data.EncryptedLocalStore") as Class;
				return (ELSClass);
			} catch (err:*) {
			}
			return (null);
		}
		
		/**
		 * Copies the supplied key(s) to the current instance.
		 * 
		 * @param	input The source keys to copy to this instance. May be an anonymous object, array, Vector array, or SRAMultiKey instance.
		 */
		private function copyKeys(input:*):void {
			this._keys = new Vector.<ISRAKey>();
			if (input is Object) {
				for (var item:* in input) {
					if (input[item] is ISRAKey) {
						var currentKey:ISRAKey = input[item];
						var newKey:SRAKey = new SRAKey(currentKey.encKey, currentKey.decKey, currentKey.modulus);
						this._keys.push(newKey);
					}
				}
				return;
			}
			if (input is Array) {
				for (item in input) {
					if (input[item] is ISRAKey) {
						currentKey = input[item];
						newKey = new SRAKey(currentKey.encKey, currentKey.decKey, currentKey.modulus);
						this._keys.push(newKey);
					}
				}
				return;
			}
			if (input is Vector.<ISRAKey>) {
				for (var count:int = 0; count < input.length; count++) {
					if (input[count] !=null) {
						currentKey = input[count];
						newKey = new SRAKey(currentKey.encKey, currentKey.decKey, currentKey.modulus);
						this._keys.push(newKey);
					}
				}
				return;
			}
			if (input is SRAMultiKey) {
				for (count = 0; count < SRAMultiKey(input).numKeys; count++) {
					currentKey = SRAMultiKey(input).getKey(count);
					if (currentKey != null) {
						newKey = new SRAKey(currentKey.encKey, currentKey.decKey, currentKey.modulus);
						this._keys.push(newKey);
					}
				}
			}
		}
		
		/**
		 * Event listener invoked when a single SRA keypair has been generated.
		 * 
		 * @param	eventObj A standard event object dispatched from a CryptoWorkerHost instance.
		 */
		private function onGenerateKey(eventObj:CryptoWorkerHostEvent):void {
			if (!this._messageFilter.includes(eventObj.message, true)) {
				return;
			}
			DebugView.addText  ("SRAMultiKey.onGenerateKey");
			DebugView.addText  ("   Operation took " + eventObj.message.elapsed + " ms");
			eventObj.target.removeEventListener(CryptoWorkerHostEvent.RESPONSE, this.onGenerateKey);	
			this._generateCounter--;
			this._keys.push(eventObj.data.sraKey);			
			if (this._generateCounter > 0) {
				//more keys remaining to be generated
				var cryptoWorker:ICryptoWorkerHost = this._cryptoWorkerHostGetter();
				cryptoWorker.addEventListener(CryptoWorkerHostEvent.RESPONSE, this.onGenerateKey);
				cryptoWorker.directWorkerEventProxy = onGenerateKeyProxy;
				var msg:WorkerMessage = cryptoWorker.generateRandomSRAKey(ISRAKey(eventObj.data.sraKey).modulusHex, false, this._generateCBL);
				this._messageFilter.addMessage(msg);
			} else {
				//all keys generated
				this.dispatchEvent(new SRAMultiKeyEvent(SRAMultiKeyEvent.ONGENERATEKEYS));
			}
		}
		
		/**
		 * Proxy event listener invoked when a single SRA keypair has been generated by a CryptoWorkerHost in single-threaded mode.
		 * 
		 * @param	eventObj  A standard event object dispatched from a CryptoWorkerHost instance.
		 */
		private function onGenerateKeyProxy(eventObj:CryptoWorkerHostEvent):void {
			this.onGenerateKey(eventObj);
		}
	}
}
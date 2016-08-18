/**
* Stores and retrieves SRA (or SRA-like) keys and provides some basic associated operations.
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package crypto 
{		
	import crypto.math.BigInt;
	import crypto.interfaces.ISRAKey;
	import flash.utils.getDefinitionByName;
	import flash.utils.ByteArray;
	import flash.utils.setTimeout;
	import flash.utils.clearTimeout;
	
	public class SRAKey implements ISRAKey 
	{		
		
		private static var _instances:uint = 0;
		private var _currentInstance:uint = 0;
		
		private var _encKey:Array = new Array();
		private var _decKey:Array = new Array();
		private var _modulus:Array = new Array();
		
		private static var _autoScrubInterval:Number = 500; //ms
		private var _autoScrubIntervalID:uint;
		
		/**
		 * Instantiates the instance with initial values.
		 * 
		 * @param	encKey The asymmetric encryption key to initialize with. This may be an arbitrary
		 * length (BigInt) array value, decimal integer string, or hexadecimal integer string. A native
		 * numeric type may also be used but this is typically insufficient for strong cryptographic security.
		 * @param	decKey The asymmetric decryption key to initialize with. This may be an arbitrary
		 * length (BigInt) array value, decimal integer string, or hexadecimal integer strong. A native
		 * numeric type may also be used but this is typically insufficient for string cryptographic security.
		 * @param	modulus The shared prime modulus to initialize with. This may be an arbitrary
		 * length (BigInt) array value, decimal integer string, or hexadecimal integer strong. A native
		 * numeric type may also be used but this is typically insufficient for string cryptographic security.
		 */
		public function SRAKey(encKey:*, decKey:*, modulus:*) 
		{
			_instances++;
			_currentInstance = _instances;
			if (!BigInt.initialized) {
				BigInt.initialize();
			}			
			copyArray(createBigIntArr(encKey), _encKey);
			copyArray(createBigIntArr(decKey), _decKey);
			copyArray(createBigIntArr(modulus), _modulus);
			storeAndScrub("_encKey");
			storeAndScrub("_decKey");
			storeAndScrub("_modulus");
			startAutoScrub();
		}
		
		/**
		 * Creates an arbitrary length integer array (BigInt) from the supplied parameter.
		 * 
		 * @param	val Any native data type including a BigInt array, arbitrary length decimal 
		 * integer string, arbitrary length hexadecimal value string (starts with "0x"), Number,
		 * uint, and int types.
		 * 
		 * @return A native arbitrary length BigInt array, or null if the input value can't be converted.
		 */
		private function createBigIntArr(val:*):Array 
		{
			if (val == null) {
				return (null);
			}
			var returnArr:Array;			
			if (val is String) {
				var dataSize:int = int(val.length + 5);
				if (val.indexOf("0x") > -1) {							
					var valHex:String = val.substr(val.indexOf("0x") + 2);	
					returnArr = BigInt.str2bigInt(valHex, 16, dataSize);
				} else {							
					returnArr = BigInt.str2bigInt(val, 10, dataSize);
				}
			} else if (val is Number) {
				returnArr = BigInt.str2bigInt(String(Math.round(val)), 10, 60);
			} else if ((val is uint) || ((val is int))) {
				returnArr = BigInt.str2bigInt(String(val), 10, 60);
			} else if (val is Array) {
				returnArr = val;
			} else {
				var err:Error = new Error("Value \"" + val + "\" is not a recognized data type for conversion to BigInt array.");
				throw (err);
			}
			return (returnArr);
		}
		
		/**
		 * @return Asymmetric encryption key as a BigInt array.
		 */
		public function get encKey():Array 
		{
			_encKey = load("_encKey");
			return (_encKey);
		}
		
		/**
		 * @return Asymmetric encryption key as a base 10 integer string.
		 */
		public function get encKeyBase10():String 
		{
			_encKey = load("_encKey");
			return (BigInt.bigInt2str(_encKey, 10));
		}
		
		/**
		 * @return Asymmetric encryption key as a hexadecimal string (starting with "0x").
		 */
		public function get encKeyHex():String 
		{
			_encKey = load("_encKey");
			return ("0x"+BigInt.bigInt2str(_encKey, 16));
		}
		
		/**
		 * @return Asymmetric encryption key as an octal string.
		 */
		public function get encKeyOct():String 
		{
			_encKey = load("_encKey");
			return (BigInt.bigInt2str(_encKey, 8));
		}
		
		/**
		 * @return Asymmetric decryption key as a BigInt array.
		 */
		public function get decKey():Array 
		{
			_decKey = load("_decKey");
			return (_decKey);
		}
		
		/**
		 * @return Asymmetric decryption key as a base 10 integer string.
		 */
		public function get decKeyBase10():String 
		{
			_decKey = load("_decKey");
			return (BigInt.bigInt2str(_decKey, 10));
		}
		
		/**
		 * @return Asymmetric decryption key as a hexadecimal string (starts with "0x").
		 */
		public function get decKeyHex():String 
		{
			_decKey = load("_decKey");
			return ("0x"+BigInt.bigInt2str(_decKey, 16));
		}
		/*
		* @return Asymmetric decryption key as a an octal string.
		*/
		public function get decKeyOct():String 
		{
			_decKey = load("_decKey");
			return (BigInt.bigInt2str(_decKey, 8));
		}
		
		/**
		 * @return Shared modulus as a BigInt array.
		 */
		public function get modulus():Array 
		{
			_modulus = load("_modulus");
			return (_modulus);
		}
		
		/**
		 * @return Shared modulus as a base 10 integer string.
		 */
		public function get modulusBase10():String 
		{
			_modulus = load("_modulus");
			return (BigInt.bigInt2str(_modulus, 10));
		}
		
		/**
		 * @return Shared modulus as a hexadecimal string (starts with "0x").
		 */
		public function get modulusHex():String 
		{
			_modulus = load("_modulus");
			return ("0x"+BigInt.bigInt2str(_modulus, 16));
		}
		
		/**
		 * @return Shared modulus as an octal string.
		 */
		public function get modulusOct():String 
		{
			_modulus = load("_modulus");
			return (BigInt.bigInt2str(_modulus, 8));
		}
		
		/**
		 * @return The bit length of the asymmetric encryption key.
		 */
		public function get encKeyBitLength():uint {
			return (uint(BigInt.bitSize(encKey)));
		}
		
		/**
		 * @return The bit length of the asymmetric decryption key.
		 */
		public function get decKeyBitLength():uint 
		{
			return (uint(BigInt.bitSize(decKey)));
		}
		
		/**
		 * @return The bit length of the shared modulus.
		 */
		public function get modBitLength():uint 
		{
			return (uint(BigInt.bitSize(modulus)));
		}
		
		/**
		 * Returns the starting and ending values needed to generate a list of quadratic residues / non-residues
		 * mod primeVal of a specified range.
		 * 
		 * @param	primeVal The prime value to use to calculate quadratic residues/non-residues. This value is 
		 * must be a decimal arbitrary length base 10 integer or hexadecimal ("0x...") string.
		 * @param  range The required range of values to generate. For example, for a single card deck this value
		 * would be "52". This value is must be a decimal arbitrary length base 10 integer or hexadecimal ("0x...") 
		 * string.
		 * @param radix An optional radix value for the returned "start" and "end" values. Acceptable values are "16"
		 * for hexadecimal outputs ("0x..."), or any other value for base 10. Default is 16.
		 * 
		 * @return An object containing "start" and "end" values, as strings in the specified radix, for the associated 
		 * prime. The range will be larger than the range specified to accomodate the required number of values.
		 */
		public static function getQRNRValues(primeVal:String, range:String, radix:uint = 16):Object 
		{
			if (!BigInt.initialized) {
				BigInt.initialize();
			}
			var dataSize:int = int(primeVal.length + 5);
			if (primeVal.indexOf("0x") > -1) {												
				var primeValStr:String = primeVal.substr(primeVal.indexOf("0x") + 2);						
				var primeValArr:Array = BigInt.str2bigInt(primeValStr, 16, dataSize);
			} else {												
				primeValArr = BigInt.str2bigInt(primeVal, 10, dataSize);
			}
			if (range.indexOf("0x") > -1) {												
				var rangeStr:String = range.substr(range.indexOf("0x") + 2);						
				var rangeValArr:Array = BigInt.str2bigInt(rangeStr, 16, dataSize);
			} else {												
				rangeValArr = BigInt.str2bigInt(range, 10, dataSize);
			}				
			var two:Array = BigInt.str2bigInt("2", 10, dataSize);
			var twenty:Array = BigInt.str2bigInt("20", 10, dataSize);			
			var q1:Array = BigInt.str2bigInt("0", 10, dataSize);
			var r1:Array= BigInt.str2bigInt("0", 10, dataSize);		
			var q2:Array= BigInt.str2bigInt("0", 10, dataSize);
			BigInt.divide_(primeValArr, two, q1, r1);			
			rangeValArr = BigInt.mult(rangeValArr, two);
			rangeValArr = BigInt.add(rangeValArr, twenty);
			q2 = BigInt.add(q1, rangeValArr);
			var returnObj:Object = new Object();
			if (radix==16) {
				returnObj.start = "0x"+BigInt.bigInt2str(q1, radix);
				returnObj.end = "0x"+BigInt.bigInt2str(q2, radix);	
			} else {
				returnObj.start = BigInt.bigInt2str(q1, radix);
				returnObj.end = BigInt.bigInt2str(q2, radix);	
			}
			return (returnObj);
		}
				
		/**
		 * Scrubs the key of all values by replacing them with pseudo-random data.
		 */
		public function scrub():void 
		{
			try {
				for (var count:uint = 0; count < _encKey.length; count++) {
					_encKey[count] = Math.floor(32767 * Math.random());					
				}
			} catch (err:*) {				
			}
			_encKey = null;
			try {
				for (count = 0; count < _decKey.length; count++) {
					_decKey[count] = Math.floor(32767 * Math.random());					
				}
			} catch (err:*) {				
			}
			_decKey = null;
			try {
				for (count= 0; count < _modulus.length; count++) {
					_modulus[count] = Math.floor(32767 * Math.random());					
				}
			} catch (err:*) {				
			}
			_modulus = null;
		}
		
		/**
		 * If true the key's data may be secured in the Encrypted Local Store otherwise they may only be stored in
		 * standard memory. This flag does not indicate the status of the key's current security status (use "secure" instead).
		 */
		public function get securable():Boolean
		{
			if (EncryptedLocalStore == null) {
				return (false);
			}
			if (EncryptedLocalStore.isSupported == false) {
				return (false);
			}			
			return (true);
		}
		
		/**
		 * If true the key's data are being stored in Encrypted Local Store and any in-memory locations are currently
		 * scrubbed. If false, either in-memory locations are still unscrubbed or the data are stored in standard memory 
		 * (always unscrubbed).
		 * 
		 * This status flag denotes only the vulnerability of the key to certain in-memory attacks in a compromised
		 * local environment, it does not represent the security of any specific key length.
		 */
		public function get secure():Boolean
		{
			if (EncryptedLocalStore == null) {
				return (false);
			}
			if (EncryptedLocalStore.isSupported == false) {
				return (false);
			}
			if ((_encKey != null) || (_decKey != null) || (_modulus != null)) {
				return (false);
			}
			return (true);
		}
		
		/**
		 * Copies the contents of one array to another at the same indexes  (source[0]=target[0], 
		 * source[1]=target[1], etc.) If either the source or target are null, this method does nothing.
		 * 
		 * @param	source The source array to copy from.
		 * @param	target The target array to copy to. 
		 */
		private function copyArray(source:Array, target:Array):void 
		{
			if ((source==null) || (target == null)) {
				return;
			}
			for (var count:uint = 0; count < source.length; count++) {				
				target[count] = source[count];
			}
		}
		
		/**
		 * Returns a dynamic reference to the flash.data.EncryptedLocalStore class if available in the
		 * current environment, or null otherwise.
		 */
		private static function get EncryptedLocalStore():Class 
		{
			try {
				var ELSClass:Class = getDefinitionByName("flash.data.EncryptedLocalStore") as Class;
				return (ELSClass);
			} catch (err:*) {
			}
			return (null);
		}
		
		/**
		 * Stores an internal property to the Encrypted Local Store and then scrubs it, if ELS is available. If ELS isn't
		 * available the property is not updated.
		 * 
		 * @param	propertyName The class property to store and scrub.
		 */
		private function storeAndScrub(propertyName:String):void
		{
			//validate environment
			if (EncryptedLocalStore == null) {
				return;
			}
			if (EncryptedLocalStore.isSupported == false) {
				return;
			}
			//store
			var ba:ByteArray = new ByteArray();
			ba.writeObject(this[propertyName]);
			ba.position = 0;
			//store unique property associated with this instance (also see "load")
			var extendedPropertyName:String = propertyName + "_" + String(_currentInstance);
			EncryptedLocalStore["setItem"](extendedPropertyName, ba);
			//scrub
			if (this[propertyName] is Array) {
				for (var count:uint = 0; count < this[propertyName].length; count++) {
					this[propertyName][count] = Math.floor(32767 * Math.random());
				}
				this[propertyName] = null;
			}			
		}
		
		/**
		 * Loads an internal property from the Encrypted Local Store or from standard memory if ELS is not available.
		 * 
		 * @param	propertyName The property to either load from the Encrypted Local Store or simply return.
		 * 
		 * @return The native data object stored in ELS or main memory if ELS isn't available, or null if the property 
		 * can't be accessed.
		 */
		private function load(propertyName:String):*
		{
			//validate environment
			if (EncryptedLocalStore == null) {
				return(this[propertyName]);
			}
			if (EncryptedLocalStore.isSupported == false) {
				return(this[propertyName]);
			}
			//load unique property associated with this instance (also see "storeAndScrub")
			var extendedPropertyName:String = propertyName + "_" + String(_currentInstance);
			//load
			var ba:ByteArray = EncryptedLocalStore["getItem"](extendedPropertyName); //this should always exist
			//assign
			try {
				this[propertyName]=ba.readObject();
			} catch (err:*) {				
			}
			return(this[propertyName]);
		}
		
		/**
		 * Begins a timed automatic scrub of in-memory key data if the Encrypted Local Store is available.
		 */
		private function startAutoScrub():void
		{
			stopAutoScrub();
			if (EncryptedLocalStore == null) {
				return;
			}
			if (EncryptedLocalStore.isSupported == false) {
				return;
			}			
			_autoScrubIntervalID = setTimeout(autoScrub, _autoScrubInterval, this);			
		}
		
		/**
		 * Scrubs all in-memory data on a timeout timer.
		 * 
		 * @param	selfRef A reference to the self or this object.
		 */
		private function autoScrub(selfRef:SRAKey):void
		{
			selfRef.scrub();
			selfRef.startAutoScrub();
		}
		
		/**
		 * Stops the timed automatic scrub of in-memory data.
		 */
		private function stopAutoScrub():void
		{
			try {
				clearTimeout(_autoScrubIntervalID);
			} catch (err:*) {				
			}
		}
	}
}
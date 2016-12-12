/**
* Implementation of the extended SRA cryptosystem as initially described by Shamir, Rivest, and Adleman in "Mental Poker".
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package crypto {
	
	import crypto.RNG;
	import crypto.math.BigInt;
	import crypto.math.EulerTotient;	
	import crypto.SRAKey;
	import flash.events.Event;	
	import flash.utils.getTimer;
	import flash.utils.setTimeout;	
	import flash.utils.clearTimeout;	
	import flash.errors.ScriptTimeoutError;	
	
	public class SRA {
		
		//Defaults
		private static const _defaultKeyLength:uint = 1024;
		private static const _defaultPrime:String = "8212180927702562960908503748064151209808789408266643524075961553863561872934400315244030547676283302877811916498965597264471114589941093595193026080142379";
		private static var _rng:RNG = null;		
		private var _bitLength:uint = _defaultKeyLength; //The cryto bit length (CB length * 8)			
		private var _prime:Array; //The current shared prime modulus
		private var _phi_n:Array; //phi(_prime)
		private var _totient:Array; //phi(_prime) -- duplicate, should be refactored!
		private var _totientCalc:EulerTotient; //Used to calculate Euler's totient, or phi(n)		
		//Minimum data size for BigInt data structures (array elements), calculated in constructor as ceiling((_bitLength/8)*1.5)+5; if this value is too small
		//many crypto operations will consistently fail starting at a specific bit length and higher.
		private static var _dataSize:int = int.MIN_VALUE; 		
		private static var zero:Array; //Stores a BigInt 0
		private static var one:Array; //Stores a BigInt 1
		private static var two:Array ; //Stores a BigInt 2		
		//Used in asynchronous operations
		private var k:Array, d:Array;
		private var valid:Boolean;		
		public static var _debug:Function = null; //Debugger output
		public static var _progress:Function = null; //Progress reporting output
		
		/**
		 * Instantiates the cryptosystem.
		 * 
		 * @param	encryptionBitLength The desired crypto bit length (CB length * 8). All subsequently generated 
		 * cryptographic values are be assumed to be this length. Default is _defaultKeyLength.
		 * @param	defaultPrime A default prime modulus value to use in subsequent operations. Default is _defaultPrime.
		 * @param	expIsVerified If true, defaultPrime is a known prime, won't be verified, and phi(defaultPrime) will
		 * be calculated simply as defaultPrime-1. If false, the prime will be verified and phi(defaultPrime) calculated.
		 */
		public function SRA (encryptionBitLength:uint = _defaultKeyLength, defaultPrime:String = _defaultPrime, expIsVerified:Boolean = false) {
			_bitLength = encryptionBitLength;
			var _calcDataSize:int=int(Math.ceil(_bitLength/8)) + 5;
			if (_calcDataSize > _dataSize) {
				_dataSize = _calcDataSize;
			}
			BigInt.initialize(rng);			
			_totientCalc = new EulerTotient(_dataSize);	
			_bitLength = encryptionBitLength;
			zero = BigInt.str2bigInt("0", 10, _dataSize);
			one = BigInt.str2bigInt("1", 10, _dataSize);
			two = BigInt.str2bigInt("2", 10, _dataSize);
			try {
				if (expIsVerified) {
					if (defaultPrime.indexOf("0x") > -1) {
						var primeValHex:String = defaultPrime.substr(defaultPrime.indexOf("0x") + 2);			
						_prime = BigInt.str2bigInt(primeValHex, 16, _dataSize);
					} else {
						_prime = BigInt.str2bigInt(defaultPrime, 10, _dataSize);
					}		
					_phi_n = BigInt.sub(_prime, one);		
					_totient = BigInt.sub(_prime, one);	
				} else {
					prime = defaultPrime;
				}
			} catch (err:ScriptTimeoutError) {
				var dbg:Function = debugger;
				dbg(err);
			}
		}	
		
		/**
		 * Validates and assigns prime and phi(prime) values to the class instance. An error is thrown if the parameter
		 * is null or isn't a prime (phi(prime)!=prime-1).
		 * 
		 * @param primeVal The prime number value to validate and assign to the class instance. This may be either
		 * a base 10 integer or a hexadecimal value (starting with "0x").
		 */
		public function set prime(primeVal:String):void {
			if (primeVal == null) {
				var err:Error = new Error("SRA.prime - Supplied parameter is null.");
				throw (err);			
			}
			if (primeVal.indexOf("0x") > -1) {
				var primeValHex:String = primeVal.substr(primeVal.indexOf("0x") + 2);			
				_prime = BigInt.str2bigInt(primeValHex, 16, _dataSize);
			} else {
				_prime = BigInt.str2bigInt(primeVal, 10, _dataSize);
			}			
			_phi_n = BigInt.sub(_prime, one);			
			var phiStr:String = BigInt.bigInt2str(_phi_n, 10);
			try {
				_totient = _totientCalc.totient(BigInt.bigInt2str(_prime, 10));			
			} catch (err:ScriptTimeoutError) {				
			}
			var totientString:String=BigInt.bigInt2str(_totient, 10);
			if (phiStr != totientString) {				
				_phi_n = zero;
				_totient = zero;
				err = new Error("SRA.prime - Euler totient of chosen prime is not equal to prime minus 1. Prime="+BigInt.bigInt2str(_prime, 10)+" Result="+totientString);
				throw (err);
			}		
		}
		
		/**
		 * @return Returns the class instance's current prime value as a base 10 integer string.
		 */
		public function get prime():String {
			return (BigInt.bigInt2str(_prime, 10));	
		}
		
		/**
		 * The current phi(prime) valus assigned to the class instance.
		 */
		public function get totient():Array	{
			return (_totient);
		}
		
		/**
		 * A reference to the debugger output function. 
		 */
		public static function set debugger(dbgFunc:Function):void {
			_debug = dbgFunc;
			BigInt.debugger = dbgFunc;
			RNG.debugger = dbgFunc;
		}
		
		public static function get debugger():Function {
			if (_debug == null) {
				_debug = function(... args):void { };
			}
			return (_debug);
		}
				
		/**
		 * Sends a progress update message to the progress reporting output.
		 * 
		 * @param	progressVal The progress output message to send to the output.
		 */
		public static function updateProgress(progressVal:String):void {
			var prFunc:Function = progressReport;
			prFunc(progressVal);			
		}
		
		/**
		 * A reference to the progress reporting output function. 
		 */
		public static function set progressReport(prgFunc:Function):void {
			_progress = prgFunc;
			BigInt.progressReport = prgFunc;
			RNG.progressReport = prgFunc;
		}
		
		public static function get progressReport():Function {
			if (_progress == null) {
				_progress = function(... args):void { };
			}
			return (_progress);
		}
		
		/**
		 * A reference to a cryptographically secure random number generator.
		 */
		public static function set rng(rngSet:RNG):void {
			_rng = rngSet;
		}
		
		public static function get rng():RNG {
			if (_rng == null) {
				_rng = new RNG();
			}
			return (_rng);
		}
		
		/**
		 * Returns the bit length (CB length * 8) of a supplied numeric value string.
		 * 
		 * @param	value The value for which to determine the bit length as either a base 10 integer string
		 * or a hexadecimal string beginning with "0x".
		 * 
		 * @return The number of bits required for the supplied value, or 0 if the value parameter is invalid.
		 */
		public static function getBitLength(value:String):uint {			
			if (value == null) {
				return (0);
			}
			if (!BigInt.initialized) {
				BigInt.initialize(rng);	
			}			
			var _localDataSize:int = Math.ceil((value.length  / 1.5)) + 5; //rough estimate assuming hexadecimal notation (most compact) to match constructor
			if (value.indexOf("0x") > -1) {
				var valueHex:String = value.substr(value.indexOf("0x") + 2);			
				var valueArr:Array = BigInt.str2bigInt(valueHex, 16, _localDataSize);
			} else {
				valueArr = BigInt.str2bigInt(value, 10, _localDataSize);				
			}
			return (uint(BigInt.bitSize(valueArr)));
		}
		
		/**
		 * Generates a random n-bit prime.
		 * 
		 * @param	bitLength The bit length (CB length * 8) of the prime number to generate.
		 * @param	probable If true, a random probable prime with probability of error < 2^-80 is generated. If false, 
		 * a true random prime is generated using Maurer's algorithm.
		 * @param	radix The desired radix for the returned prime number, If 16, the prime number is returned
		 * ias a hexadecimal value ("0x..."), otherwise the number is returned as a base 10
		 * 
		 * @return
		 */
		public static function genRandPrime(bitLength:uint = _defaultKeyLength, probable:Boolean = false, radix:uint = 10):String {
			if (!BigInt.initialized) {
				BigInt.initialize(rng);	
			}	
			var primeVal:String = new String();
			try {
				if (probable) {
					 primeVal = BigInt.bigInt2str(BigInt.randProbPrime(bitLength), radix);
				} else {
					primeVal = BigInt.bigInt2str(BigInt.randTruePrime(bitLength), radix);
				}
			} catch (err:*) {	
				return (err);
			}
			if (radix == 16) {
				primeVal = "0x" + primeVal;
			}
			return (primeVal);			
		}		
		
		/**
		 * Generates a random n-bit asymmetric keys using the current prime and phi(prime) values.
		 * 
		 * @param	bitLength The desired bit length (CB length * 8) of the output keys.
		 * 
		 * @return A SRAKey instance with containing the generated encryption and decryption keys and
		 * prime modulus at the specified bit length, or null if an error occurred.
		 */
		public function genRandKey(bitLength:uint = _defaultKeyLength):SRAKey {			
			try {
				_bitLength = bitLength;
				valid = false;				
				while (!valid) {						
					k = BigInt.randBigInt(_bitLength, 1);						
					valid = isValidEncryptionKey(k, _totient);					
				}
			} catch (err:*) {
				return (null);
			}
			d = multinv(k, _phi_n);
			var newKey:SRAKey = new SRAKey(k, d, _prime);			
			scrubArray(k);			
			scrubArray(d);			
			return (newKey);
		}
		
		/**
		 * Generates an asymmetric key pair from a key half using the current prime and phi(prime) values.
		 * 
		 * @param	asymKey An asymmetric key half as either a base 10 integer string or a hexadecimal 
		 * string beginning with "0x".
		 * 
		 * @return A SRAKey instance containing the original key half, newly generated key half, and prime
		 * values, or null if an error occurred.
		 */
		public function genAsymKey(asymKey:String):SRAKey {			
			if (asymKey == null) {
				return (null);
			}
			if (asymKey.indexOf("0x") > -1) {
				var asymKeyHex:String = asymKey.substr(asymKey.indexOf("0x") + 2);			
				var asymKeyArr:Array = BigInt.str2bigInt(asymKeyHex, 16, _dataSize);
			} else {
				asymKeyArr = BigInt.str2bigInt(asymKey, 10, _dataSize);				
			}
			if (!isValidEncryptionKey(asymKeyArr, _totient)) {
				return (null);
			}
			d = multinv(asymKeyArr, _phi_n);			
			var returnKey:SRAKey = new SRAKey(asymKeyArr, d, _prime);
			scrub(asymKey);						
			scrub(d);
			return (returnKey);
		}
			
		/**
		 * Returns an object containing information about quadratic residues of a range of numbers
		 * with a given prime. To prevent face value checking, only quadratic residues should be mapped to data.
		 * 
		 * @param	startRange The BigInt start range of values to evaluate.
		 * @param	endRange The BigInt end range of values to evaluate.
		 * @param 	modVal The shared modulus / prime within the values specified by startRange and endRange.
		 * @param 	radix The radix, 10 or 16, to store the values in. If 16, ActionScript hexadecimal notation "0x" is used.
		 * 
		 * @return On object containing an array "res", each element of which is a BigInt quadratic non-residue in the specified range,
		 * an array "nres", each element of which is a BigInt quadratic residue in the specified range.
		 */
		public static function quadResidues(startRange:Array, endRange:Array, modVal:Array, radix:uint = 16):Object {
			if (!BigInt.initialized) {
				BigInt.initialize(rng);	
			}
			//_dataSize may not be set yet if not instantiated
			if (startRange.length > _dataSize) {
				_dataSize = startRange.length; //no calculations needed since these are already arrays
			}
			if (endRange.length > _dataSize) {
				_dataSize = endRange.length;
			}
			if (modVal.length > _dataSize) {
				_dataSize = modVal.length;
			}
			_dataSize+= 5;
			var qrsum:Array = BigInt.str2bigInt("0", 10, _dataSize);
			var qnrsum:Array = BigInt.str2bigInt("0", 10, _dataSize);	
			var res:Array = new Array();
			var nres:Array = new Array();			
			var rangeCount:Array = BigInt.sub(endRange, startRange);
			if (one==null) {
				one = BigInt.str2bigInt("1", 10, _dataSize);
			}
			if (two==null) {
				two = BigInt.str2bigInt("2", 10, _dataSize);
			}
			var counter:Array = BigInt.str2bigInt("0", 10, _dataSize);			
			var progressCounter:Array = BigInt.str2bigInt("0", 10, _dataSize);
			var total:Array = BigInt.str2bigInt("0", 10, _dataSize);
			var quotient:Array = BigInt.str2bigInt("0", 10, _dataSize);
			var remainder:Array = BigInt.str2bigInt("0", 10, _dataSize);			
			var thirteen:Array = BigInt.str2bigInt("13", 10, _dataSize);			
			var phiPrime:Array= BigInt.sub(modVal, one);
			BigInt.divide_(phiPrime, two, quotient, remainder);
			BigInt.copy_(counter, startRange);
			BigInt.copy_(total, rangeCount);
			rangeCount = BigInt.add(rangeCount, one);		
			var returnObj:Object = new Object();
			returnObj.qr = new Array();
			returnObj.qnr = new Array();
			var ctrStrValue:String;
			var progressCtr:Array;
			while (!BigInt.isZero(rangeCount)) {			
				ctrStrValue = BigInt.bigInt2str(counter, radix);				
				if (radix == 16) {
					ctrStrValue = "0x" + ctrStrValue;
				}				
				var legendreSymbol:Array = modPower(counter, quotient, modVal);				
				if (BigInt.bigInt2str(legendreSymbol, 10) == "1") {
					//Quadratic residue			
					returnObj.qr.push(ctrStrValue);
				} else if (BigInt.bigInt2str(legendreSymbol, 10) == BigInt.bigInt2str(phiPrime, 10)) {
					//Quadratic non-residue					
					returnObj.qnr.push(ctrStrValue);
				} else {	
					/*
					//Invalid value
					var err:Error = new Error("SRA.quadResidues has invalid legendreSymbol value: 0x" + BigInt.bigInt2str(legendreSymbol, 16)+" - rangeCount: "+BigInt.bigInt2str(rangeCount, 10)+" - modulus: "+BigInt.bigInt2str(modVal, 16));
					throw(err);					
					*/
				}	
				rangeCount = BigInt.sub(rangeCount, one);
				counter = BigInt.add(counter, one);	
				if (progressReport != null) {					
					updateProgress((BigInt.bigInt2str(progressCounter, 10) + "/" + (BigInt.bigInt2str(total, 10))));
					progressCounter = BigInt.add(progressCounter, one);	
				}
			}			
			return (returnObj);
		}		
		
		/**
		 * Commutatively encrypts a numeric input string with a SRAKey and produces a numeric output string
		 * of a specified radix.
		 * 
		 * @param	dataVal The plaintext numeric data string to encrypt. This may be either a base 10 integer
		 * string or a hexadecimal string (starting with "0x"), and must not be larger than the prime value
		 * in the SRAKey instance.
		 * @param	sraKey A SRAKey instance containing valid encryption and decryption keys, and a shared prime
		 * modulus.
		 * @param	outputRadix The desired radix for the commutatively encrypted output, either 16 for hexadecimal
		 * (starting with "0x"), or all other values for base 10 integer.
		 * 
		 * @return The commutatively encrypted input data represented in the desired radix.
		 */
		public function encrypt(dataVal:String, sraKey:SRAKey, outputRadix:uint = 10):String {
			if (dataVal.indexOf("0x") == 0) {
				var dataValHex:String = dataVal.substr(dataVal.indexOf("0x") + 2);
				var bigData:Array = BigInt.str2bigInt(dataValHex, 16, _dataSize);
			} else {
				bigData = BigInt.str2bigInt(dataVal, 10, _dataSize);
			}
			var encData:String = BigInt.bigInt2str(modPower(bigData, sraKey.encKey, sraKey.modulus), outputRadix);
			if (outputRadix == 16) {
				encData = "0x" + encData;
			}
			return (encData);
		}
		
		/**
		 * Commutatively decrypts a numeric input string with a SRAKey and produces a numeric output string
		 * of a specified radix.
		 * 
		 * @param	dataVal The encrypted numeric data string to decrypt. This may be either a base 10 integer
		 * string or a hexadecimal string (starting with "0x"), and must not be larger than the prime value
		 * in the SRAKey instance.
		 * @param	sraKey A SRAKey instance containing valid encryption and decryption keys, and a shared prime
		 * modulus.
		 * @param	outputRadix The desired radix for the commutatively decrypted output, either 16 for hexadecimal
		 * (starting with "0x"), or all other values for base 10 integer.
		 * 
		 * @return The commutatively decrypted input data represented in the desired radix.
		 */
		public function decrypt(dataVal:String, sraKey:SRAKey, outputRadix:uint = 10):String {
			if (dataVal.indexOf("0x") == 0) {
				var dataValHex:String = dataVal.substr(dataVal.indexOf("0x") + 2);
				var bigData:Array = BigInt.str2bigInt(dataValHex, 16, _dataSize);
			} else {
				bigData = BigInt.str2bigInt(dataVal, 10, _dataSize);
			}			
			var decData:String = BigInt.bigInt2str(modPower(bigData, sraKey.decKey, sraKey.modulus), outputRadix);
			if (outputRadix == 16) {
				decData = "0x" + decData;
			}
			return (decData);
		}			
		
		/**
		 * Validates an encryption key against a phi(prime) value.
		 * 
		 * @param	keyVal The BigInt key value to validate.
		 * @param	totientVal A BigInt phi(prime) value to validate the key against.
		 * 
		 * @return True if the encryption key is valid (gcd(key, phi(n))==1), false otherwise.
		 */
		public function isValidEncryptionKey(keyVal:Array, totientVal:Array):Boolean {
			try {
				if (BigInt.bigInt2str(BigInt.GCD(keyVal, totientVal), 10) == "1") {				
					return (true);
				} else {				
					return (false);
				}
			} catch (err:*) {
				return (false);
			}
			return (false);
		}		
		
		/**
		 * Calculates x^n (mod p).
		 * 
		 * @param x The BigInt value to be encrypted or decrypted.
		 * @param n The BigInt exponent.
		 * @param p The BigInt shared prime modulus.
		 */
		private static function modPower(x:Array, n:Array, p:Array):* {	
			if (!BigInt.initialized) {
				BigInt.initialize(rng);	
			}			
			var powCalc:Array = BigInt.powMod(x, n, p);
			return (powCalc);						
		}
		
		/**
		 * Performs an extended gcd or Euclidian algorithm on BigInt values.
		 * 
		 * @param	x The first BigInt value to calculate egcd.
		 * @param	y The second BigInt value to calculate egcd.
		 * 
		 * @return An array containing the BigInt greatest common divisor (index 0), BigInt a (index 1) and BigInt
		 * b (index 2) coefficients of Bezout's identity: ax+by=gcd(x,y)
		 */
		private function extendedEuclidBigInt(x:Array, y:Array):Array {				
			var retArray:Array=new Array();
			var v:Array=BigInt.str2bigInt("0", 10, (_dataSize+20)); //provide overhead for calculations
			var a:Array=BigInt.str2bigInt("0", 10, (_dataSize+20));
			var b:Array = BigInt.str2bigInt("0", 10, (_dataSize+20));
			BigInt.eGCD_(x, y, v, a, b);			
			retArray.push(v); 
			retArray.push(a); //U coefficient
			retArray.push(b); //V coefficient
			return (retArray);
		}
				
		
		/**
		 * Performs a modular multiplicative inverse of a key using phi(prime) to generate an asymmetric key half.
		 * If the key fails validation against phi(prime) an error is thrown.
		 * 
		 * @param	n The BigInt key half for which to generate a matching half.
		 * @param	m The BigInt phi(prime) value to use to generate the key half.
		 * 
		 * @return The output BigInt asymmetric key half to be used with the subsequent commutative encryption or
		 * decryption.
		 */
		private function multinv(n:Array, m:Array):Array {				
			if (BigInt.bigInt2str(BigInt.GCD(n, m), 10) != "1") {
				var err:Error = new Error("SRA.multinv GCD failed to return 1 for " + BigInt.bigInt2str(n, 10) + " and " + BigInt.bigInt2str(m, 10));
				throw (err);
			} else {				
				var coeffsLong:Array = extendedEuclidBigInt(n, m);
				return (BigInt.mod(coeffsLong[1], m));			
			}			
		}
		
		/**
		 * Scrubs an input value by filling it with pseudo-random data.
		 * 
		 * @param	value The value to be scrubbed. May be an array or a string.
		 * 
		 * @return True if the value was successfully scrubbed, false if the input value type couldn't
		 * be recognized.
		 */
		private function scrub(value:*= null):Boolean {
			if (value == null) {
				return (false);
			}
			if (value is Array) {
				scrubArray(value);
				return (true);
			} else if (value is String) {
				scrubString(value);
				return (true);
			}
			return (false);
		}
			
		/**
		 * Scrubs an array by filling it with pseudo-random data.
		 * 
		 * @param	arr The array to scrub.
		 */
		private function scrubArray(arr:Array):void {
			try {
				for (var count:uint = 0; count < arr.length; count++) {
					arr[count] = Math.floor(32767 * Math.random());					
				}
			} catch (err:*) {				
			}
			arr = null;
		}
		
		/**
		 * Scrubs a string by filling it with pseudo-random data.
		 * 
		 * @param	arr The string to scrub.
		 */
		private function scrubString(str:String):void {
			try {
				str = "";
				for (var count:uint = 0; count < str.length; count++) {
					str += String.fromCharCode(Math.round(Math.random() * 0xFFFF));
				}
			} catch (err:*) {				
			}
			str = null;
		}
	}	
}
/**
* Interface for CryptoWorker host implementation.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.interfaces {
	
	import p2p3.workers.WorkerMessage;
	import crypto.interfaces.ISRAKey;
		
	public interface ICryptoWorkerHost {
		
		//generate a random bitLength-length number, optionally ensuring most significant bit is set to 1, and return result at the specified radix
		function generateRandom(bitLength:uint, setMSB:Boolean = true, returnRadix:uint = 16):WorkerMessage;
		//generate a random bitLength-length prime number and return result at the specified radix
		function generateRandomPrime(bitLength:uint, returnRadix:uint = 16):WorkerMessage;
		//generate a random SRA key using an optional base prime value, optionally checking the prime for primality; if no prime is supplied
		//a bitLength-length one is generated first.
		function generateRandomSRAKey(primeVal:String = "", primeIsVerified:Boolean = false, bitLength:uint = 0):WorkerMessage;
		//generate an assymetric SRA key half from a supplied one using an optional prime, optionally checking the prime for primality; if no
		//prime is supplied a bitLength-length one is generated first.
		function generateSRAKey(keyHalf:String, primeVal:String, primeIsVerified:Boolean = false, bitLength:uint = 0):WorkerMessage;
		//verifies that a supplied SRA key half is commutative with a given prime which is optionally checked for primality.
		function verifySRAKey(keyHalf:String, primeVal:String = "", primeIsVerified:Boolean = false):WorkerMessage;
		//encrypts a numeric value reresented as a string, using an ISRAKey implementation and returning the result at a specified radix
		function encrypt(dataValue:String, sraKey:ISRAKey, returnRadix:uint = 16):WorkerMessage;
		//decrypts a numeric value reresented as a string, using an ISRAKey implementation and returning the result at a specified radix.
		function decrypt(dataValue:String, sraKey:ISRAKey, returnRadix:uint = 16):WorkerMessage;
		//generates a range of quadratic residues and non-residues in a given range with respect to a prime, returning the result at a specified radix.
		function QRNR (startRangeVal:String, endRangeVal:String, primeVal:String, returnRadix:uint = 16):WorkerMessage;
		//enable or disable CryptoWorker debugging messages.
		function set debug(enableSet:Boolean):void;
		//enable or disable CryptoWorker progress messages.
		function set progress(enableSet:Boolean):void;
		//is CryptoWorker concurrency enabled?
		function get concurrent():Boolean;
		//standard EventDispatcher overrides
		function addEventListener (type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false): void;
		function removeEventListener (type:String, listener:Function, useCapture:Boolean = false): void;
		//direct callback function to use with a non-concurrent ICryptoWorkerHost implementation
		function set directWorkerEventProxy(proxySet:Function):void;
		function get directWorkerEventProxy():Function;
	}	
}
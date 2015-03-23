/**
* Interface for CryptoWorker host implementation.
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.interfaces 
{
	
	import p2p3.workers.WorkerMessage;
	import crypto.interfaces.ISRAKey;
		
	public interface ICryptoWorkerHost 
	{
		
		function generateRandom(bitLength:uint, setMSB:Boolean = true, returnRadix:uint = 16):WorkerMessage;
		function generateRandomPrime(bitLength:uint, returnRadix:uint = 16):WorkerMessage;
		function generateRandomSRAKey(primeVal:String = "", primeIsVerified:Boolean = false, bitLength:uint = 0):WorkerMessage;
		function generateSRAKey(keyHalf:String, primeVal:String, primeIsVerified:Boolean = false, bitLength:uint = 0):WorkerMessage;
		function verifySRAKey(keyHalf:String, primeVal:String = "", primeIsVerified:Boolean = false, bitLength:uint = 0):WorkerMessage;
		function encrypt(dataValue:String, sraKey:ISRAKey, returnRadix:uint = 16):WorkerMessage;
		function decrypt(dataValue:String, sraKey:ISRAKey, returnRadix:uint = 16):WorkerMessage;
		function QRNR (startRangeVal:String, endRangeVal:String, primeVal:String, returnRadix:uint = 16):WorkerMessage;
		function set debug(enableSet:Boolean):void;
		function set progress(enableSet:Boolean):void;
		function get concurrent():Boolean;
		function addEventListener (type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false): void;
		function removeEventListener (type:String, listener:Function, useCapture:Boolean = false): void;
		function set directWorkerEventProxy(proxySet:Function):void;
		function get directWorkerEventProxy():Function;
		
	}
	
}
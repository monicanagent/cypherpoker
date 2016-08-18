/**
* Interface for a multiple SRA (or SRA-like) key storage class.
*
* (C)opyright 2014 to 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package crypto.interfaces 
{
	
	public interface ISRAMultiKey 
	{
		function generateKeys(cryptoWorkerHostGetter:Function, numKeys:uint, CBL:uint, prime:String):void; //Generates a sequence of SRA keys which will be stored in the implementation.
		function getKey(index:int = 0):ISRAKey; //Returns a SRA key at the specified index.
		function setKey(key:ISRAKey, index:int =-1):void; //Sets a SRA key at a specific index. If not specified, the next available unused index is assumed.
		function get numKeys():int; //The number of keys currently being stored by the implementation.
		function get securable():Boolean; //Is multikey securable through EncryptedLocalStorage (true) or does it need to remain in memory (false)?
		function scrub():void; //Scrubs the implementation of all keys by calling their respective scrub functions and nulling their memory locations.
	}
	
}
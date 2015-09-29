/**
* Interface for a SRA (or SRA-like) key storage class.
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package crypto.interfaces 
{
	
	public interface ISRAKey 
	{
		
		function get encKey():Array; //Asymmetric encryption key as a BigInt array
		function get encKeyBase10():String; //Asymmetric encryption key as a base 10 integer string
		function get encKeyHex():String; //Asymmetric encryption key as a hexadecimal string ("0x...")
		function get encKeyOct():String; //Asymmetric encryption key as an octal string
		function get decKey():Array;  //Asymmetric decryption key as a BigInt array
		function get decKeyBase10():String; //Asymmetric decryption key as a base 10 integer string
		function get decKeyHex():String; //Asymmetric decryption key as a hexadecimal string ("0x...")
		function get decKeyOct():String; //Asymmetric decryption key as an octal string
		function get modulus():Array; //Shared prime modulus as a BigInt array
		function get modulusBase10():String; //Shared prime modulus as a base 10 integer string
		function get modulusHex():String; //Shared prime modulus as a hexadecimal string ("0x...")
		function get modulusOct():String; //Shared prime modulus as an octal string
		function get encKeyBitLength():uint; //The bit length of the asymmetric encryption key
		function get decKeyBitLength():uint; //The bit length of the asymmetric decryption key
		function get modBitLength():uint; //The big length of the shared prime modulus
		function scrub():void; //Scrubs the implementation of all values by replacing them with pseudo-random data and nulling them.
		function get securable():Boolean; //True of the key is securable from in-memory attacks
		function get secure():Boolean; //True if the key is currently secure from in-memory attacks
	}
	
}
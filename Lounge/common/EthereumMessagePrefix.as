/**
* Defines Ethereum message prefixes used when composing signed transaction objects.
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package {
	
	public class EthereumMessagePrefix {
		
		//Bet commit
		public static const BET:String = "B";
		//Prime generation
		public static const PRIME:String = "P";
		//Plaintex/Face-up card generation
		public static const CARD:String = "C";
		//Card encryption
		public static const ENCRYPT:String = "E";
		//Private card selection
		public static const PRIVATE_SELECT:String = "S";
		//Private card decryption
		public static const PRIVATE_DECRYPT:String = "D";
		//Public card selection
		public static const PUBLIC_SELECT:String = "s";
		//Public card decryption
		public static const PUBLIC_DECRYPT:String = "d";
	}
}
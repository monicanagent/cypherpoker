/**
* Multi-threaded options and operational commands used with the cryptosystem Worker.
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.workers
{
	
	public class CryptoWorkerCommand 
	{
		
		//Options
		public static const OPTION_ENABLEDEBUG:String = "enable_debug"; //Enable debug messages
		public static const OPTION_DISABLEDEBUG:String = "disable_debug"; //Disable debug messages
		public static const OPTION_ENABLEPROGRESS:String = "enable_progress"; //Enable progress reporting
		public static const OPTION_DISABLEPROGRESS:String = "disable_progress"; //Disable progress reporting
		
		//Operations
		public static const SRA_GENRANDOM:String = "genRand_sra"; //Generate a random number
		public static const SRA_GENRANDOMPRIME:String = "genRandPrime_sra"; //Generate a random prime number
		public static const SRA_GENRANDOMKEY:String = "genRandKey_sra"; //Generate a random SRA key
		public static const SRA_GENKEY:String = "genKey_sra"; //Generate a full SRA key from a key half
		public static const SRA_VERIFYKEY:String = "verifyKey_sra"; //Verify a SRA key half
		public static const SRA_ENCRYPT:String = "encrypt_sra"; //Commutatively encrypt data
		public static const SRA_DECRYPT:String = "decrypt_sra"; //Commutatively decrypt data
		public static const SRA_QRNR:String = "quadResidues_sra"; //Generate quadratic residues/non-residues
	}
}
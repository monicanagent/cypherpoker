/**
* Calculates Euler's Totient (phi(n) or φ(n)).
* Based on Alexei Kourbatov's JavaScript implementation (http://www.javascripter.net/math/calculators/eulertotientfunction.htm).
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package crypto.math 
{
	
	public class EulerTotient 
	{
		
		private var _smallPrimes:Array = [2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,101,103,107,109,113];
		private var _one:*=null;
		private var _zero:*=null;
		
		/**
		 * Constructor
		 */
		public function EulerTotient() 
		{			
		}
		
		/**
		 * @return A big interger representation of 1.
		 */
		public function get one():Array 
		{
			if (_one == null) {
				_one  = BigInt.str2bigInt(1, 10, 50);
			}
			return (_one);
		}
		
		/**
		 * @return A big interger representation of 0.
		 */
		public function get zero():Array 
		{
			if (_zero == null) {
				_zero  = BigInt.str2bigInt(0, 10, 50);
			}
			return (_zero);
		}
		
		/**
		 * Efficiently calculates Euler's Totient, Phi(n), or φ(n).
		 * 
		 * @param	n The string representation of the integer for which to calculate the totient. If this string begins with "0x", it
		 * is treated as a hexadeximal value, otherwise it's treated as a decimal value.
		 * 
		 * @return A BigInt array containing the result of the operation.
		 */
		public function totient(n:String):Array 
		{
			var s:* = n.toString().replace(/^\s+|\s+$/g, '');			
			var f:* = parseFloat(s);
			var len:*= s.length;			
			var phi:*;
			var q:*;
			var r:*;
			var res:*;
			var y:*;
			var t:*;
			var x:*;
			var factors:*;
			var f0:* = 1;
			var f1:* = 1;
			if (s == "" ) {
				var err:Error = new Error ("EulerTotient.totient: input parameter is blank.");
				throw (err);
			}		
			if (f < 1) {				
				return (BigInt.str2bigInt("0", 10, 50));
			}
			if (f < 3) {				
				return (BigInt.str2bigInt("1", 10, 50));
			}
			q = BigInt.str2bigInt("1",10,50);
			r = BigInt.str2bigInt("1",10,50);
			phi = BigInt.str2bigInt(s, 10, 50);			
			res = factor_(n);			
			if (res.indexOf('*') == -1) { 				
				return (BigInt.addInt(phi, -1));
			}			
			factors = res.split('*').sort(Array.NUMERIC);				
			for (var i:Number = 0; i < factors.length; i++) {
				BigInt.updateProgress(".");
				f0 = f1;
				f1 = factors[i];
				if (f1 != f0) {              // phi = phi*(1 - 1/f1); [in steps]	
					y = BigInt.str2bigInt(f1,10,50);  // y = f
					t = BigInt.addInt(y,-1);           // t = f-1
					x = BigInt.mult(phi,t);            // x = phi*(f-1)
					BigInt.divide_(x,y,q,r);           // q = x/f
					phi = q; //q = quotient					
				}		
			 }
			 return (phi);
		}
		
		/**
		 * Full native totient calculation.
		 * 
		 * @param	n The native number value for which to calculate the totient.
		 * 
		 * @return A BigInt array containing the result of the operation.
		 */
		public function totient_fullw(n:Number):Number
		{
		 var phi:Number = n;
			 for (var k:Number = 2; k <= n; k++) {
			  if (isPrime(k) && n%k==0) {
			   phi = phi*(k-1)/k;	
			  }
			 }
			 return phi;
		}

		/**
		 * Tests two input values for divisibility by another.
		 * 
		 * @param	d The shared divisor to test for.
		 * @param	hi The first value to test for divisibility by d.
		 * @param	lo The second value to test for divisibility by d.
		 * 
		 * @return True if hi and lo parameters are divisible by d.
		 */
		public function divisibleBy(d:*, hi:*, lo:*):Boolean
		{
			return (0 == ((1000000000000000 % d) * hi + lo) % d);
		}

		/**
		 * Determines the smallest factor for a native number value.
		 * 
		 * @param	n The input number to determine the smallest factor for.
		 * 
		 * @return The smallest factor for n or NaN if a factor can't be found.
		 */
		public function leastFactor (n:Number):Number 
		{
		  if (isNaN(n) || !isFinite(n)) return NaN;   
		  if (n==0) return 0;  
		  if (n%1 || n*n<2) return 1;
		  if (n%2==0) return 2;  
		  if (n%3==0) return 3;  
		  if (n%5==0) return 5;  
		  var q:* = Math.sqrt(n);
		  var m:* = q;
		  for (var i:*=7;i<=m;i+=30) {
		   if ((q=n/i)==Math.floor(q))      return i;
		   if ((q=n/(i+4))==Math.floor(q))  return i+4;
		   if ((q=n/(i+6))==Math.floor(q))  return i+6;
		   if ((q=n/(i+10))==Math.floor(q)) return i+10;
		   if ((q=n/(i+12))==Math.floor(q)) return i+12;
		   if ((q=n/(i+16))==Math.floor(q)) return i+16;
		   if ((q=n/(i+22))==Math.floor(q)) return i+22;
		   if ((q=n/(i+24))==Math.floor(q)) return i+24;
		  }
		  return n;
		}
			
		/**
		 * Determines the smallest factor for a native number or arbitrary length integer value.
		 * 
		 * @param	s The input number or arbitrary length array to determine the smallest factor for.
		 * 
		 * @return The smallest factor for s as a native number, or NaN, if s was a native number, or
		 * an arbitrary length integer array if was an arbitrary length integer.
		 */
		public function leastFactor_ (s:*):* 
		{ 
			if (typeof(s)=='number') return leastFactor(s);
			if (typeof(s)!='string') return NaN;
			if (s.match(/\D/)) return NaN;
			var n:* = parseFloat(s);
			if (isNaN(n) || !isFinite(n)) return NaN;
			if (n<9007199254740992) return leastFactor(n);
			var lo:*=0, hi:*=0, len:*=s.length;		
			if (len>15) {
				lo = parseInt(s.substring(len-15), 10);
				hi = parseInt(s.substring(0,len-15), 10);
			}
			else lo=parseInt(s, 10);
			if (lo%2==0)               return 2;
			if (divisibleBy(3,hi,lo))  return 3;
			if (lo%5==0)               return 5;
			if (divisibleBy(7,hi,lo))  return 7;
			if (divisibleBy(11,hi,lo)) return 11;
			if (divisibleBy(13,hi,lo)) return 13;
			if (divisibleBy(17,hi,lo)) return 17;
			if (divisibleBy(19,hi,lo)) return 19;
			if (divisibleBy(23,hi,lo)) return 23;
			if (divisibleBy(29,hi,lo)) return 29;
			if (divisibleBy(31,hi,lo)) return 31;
			var m:* = Math.ceil(Math.sqrt(n)+0.5);		 
			for (var i:*=7+30*Math.floor(m/30-100);i<=m;i+=30) {
				if (divisibleBy(i,hi,lo))    return leastFactor(i);
				if (divisibleBy(i+4,hi,lo))  return leastFactor(i+4);
				if (divisibleBy(i+6,hi,lo))  return leastFactor(i+6);
				if (divisibleBy(i+10,hi,lo)) return leastFactor(i+10);
				if (divisibleBy(i+12,hi,lo)) return leastFactor(i+12);
				if (divisibleBy(i+16,hi,lo)) return leastFactor(i+16);
				if (divisibleBy(i+22,hi,lo)) return leastFactor(i+22);
				if (divisibleBy(i+24,hi,lo)) return leastFactor(i+24);
			}
			for (i=37;i<=m;i+=30) {
				if (divisibleBy(i,hi,lo))    return i;
				if (divisibleBy(i+4,hi,lo))  return i+4;
				if (divisibleBy(i+6,hi,lo))  return i+6;
				if (divisibleBy(i+10,hi,lo)) return i+10;
				if (divisibleBy(i+12,hi,lo)) return i+12;
				if (divisibleBy(i+16,hi,lo)) return i+16;
				if (divisibleBy(i+22,hi,lo)) return i+22;
				if (divisibleBy(i+24,hi,lo)) return i+24;
			}
			return s;
		}			

		/**
		 * Performs a Miller-Rabin reduction on arbitrary length integers and returns the result.
		 * 
		 * @param	n 
		 * @param	a 
		 * 
		 * @return True (1) if the input value is a probably prime, false (0) if it's a composite value.
		 */
		public function miller_rabin(n:*, a:*):* 
		{
			var s:* = n.toString(); 
			var res:*, len:*=s.length;
			var mr_base:* =  BigInt.str2bigInt(a.toString(),10,50);
			var mr_cand:* =  BigInt.str2bigInt(s,10,50);
			var mr_temp:* =  BigInt.addInt(mr_cand, -1);
			res = mrr3 (mr_base, mr_temp, mr_cand);
			if ((typeof res=='object') &&  BigInt.equalsInt(res,1) ) return 1;
			return 0;
		}
		
		/**
		 * Tests a native number value for primality by calculating the smallest factor.
		 * 
		 * @param	n The value to test for primality.
		 * 
		 * @return True if the input value is a probable prime, false otherwise.
		 */
		public function isPrime (n:Number):Boolean
		{
			if (isNaN(n) || !isFinite(n) || n%1 || n<2) return false; 
			if (n==leastFactor(n)) return true;
			return false;
		}

		/**
		 * Tests an arbitray length integer value for primality by using the Miller-Rabin test.
		 * 
		 * @param	n The decimal string value to test for primality.
		 * 
		 * @return True if the input value is a probable prime, false otherwise.
		 */
		public function isPrimeMR15(n:String):* 
		{
			var a:*, s:* = n.toString(); 
			for (var k:*=0;k<15;k++) {
				a = _smallPrimes[k];
				if (s==''+a) return 1;
				if (miller_rabin(s,a)==0) return 0;
			}
			return 1;
		}

		/**
		 * Calculates the factors of a native number input value and returns them
		 * as an asterisk-separated list.
		 * 
		 * @param	n The value to calculate factors for.
		 * 
		 * @return The factors of the input value, separated by asterisks.
		 */
		public function factor(n:Number):String
		{
			if (isNaN(n) || !isFinite(n) || n%1 || n==0) return n.toString();
			if (n<0) return '-'+factor(-n);
			var minFactor:* = leastFactor(n);
			if (n==minFactor) return n.toString();
			return minFactor+'*'+factor(n/minFactor);
		}
		
		/**
		 * Calculates the factors of an arbitrary length integer value and returns
		 * them as a string of asterisk-separated values.
		 * 
		 * @param	n The string representation of the decimal integer to calculate factors for.
		 * 
		 * @return The factors of the input value, separated by asterisks.
		 */
		public function factor_(n:String):* 
		{		
			var s:* = n.toString().replace(/^\s+|\s+$/g,'');
			var f:* = parseFloat(s), len:* = s.length;	 
			if (s == "" ) {
				var err:Error = new Error("EulerTotient.factor_ parameter is blank");
				throw (Error);
			}
			var lastDigit:* = parseInt(s.charAt(len - 1), 10);	 
			if ((lastDigit==1) || (lastDigit==3) || (lastDigit==7) || (lastDigit==9)) {
				if (isPrimeMR15(s)) {		  
					return s;
				}
			}
			var minFactor:* = leastFactor_(s).toString();
			if (s == minFactor) {		 
				return s;
			}
			var x:* = BigInt.str2bigInt(s,10,50);
			var y:* = BigInt.str2bigInt(minFactor,10,50);
			var q:* = BigInt.str2bigInt('1',10,50);
			var r:* = BigInt.str2bigInt('1', 10, 50);
			BigInt.updateProgress(".");			
			BigInt.divide_(x, y, q, r);	 
			return (minFactor+'*'+factor_(BigInt.bigInt2str(q,10)));
		}

		/**
		 * Sorts an asterisk-separated list of factors numerically (smallest to largest).
		 * 
		 * @param	n The list of asterisk-separated factors to sort.
		 * 
		 * @return The sorted list of asterisk-separated values, n, sorted numerically.
		 */
		public function factorSort(n:String):String
		{
			var res:* = factor_(n);
			if (res.indexOf('*')==-1) return res;
			return res.split('*').sort(Array.NUMERIC).join('*');
		}
		
		/**
		 * Performs a Miller-Rabin reduction on arbitrary length integers and returns the result.
		 * 
		 * @param	a 
		 * @param	i 
		 * @param	n 
		 * 
		 * @return An arbitrary length integer representation of 1 if the input value is a probable prime,
		 * 0 if the integer value is composite.
		 */
		private function mrr3(a:*, i:*, n:*):Array
		{
			if (BigInt.isZero(i)) return one;
			//  j = floor(i/2)
			var j:* = BigInt.dup(i); 
			BigInt.divInt_(j,2);   
			var x:* = mrr3(a, j, n);    
			if (BigInt.isZero(x)) return zero;	 
			//  y = (x*x)%n
			var y:* =  BigInt.expand(x, n.length);  
			BigInt.squareMod_(y,n);
			if ( BigInt.equalsInt(y,1) && (!BigInt.equalsInt(x,1)) && (!BigInt.equals(x,  BigInt.addInt(n,-1))) ) return zero; 
			if (i[0]%2==1) BigInt.multMod_(y,a,n);
			return y;
		}

	}

}
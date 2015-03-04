/**
* Provides currency formatting services.
* 
* Format Rules:
*  Any values not in the following sets are treated as string literals.
* 
* To produce a hash mark, the hash-escape sequence "##;" is used.
* 
* A hash-escape sequence always begins with a hash (#) and ends with a semi-colon (;)
* The letter following the hash determines which part of the currency should be included in
* the output at that point:
* 
* "m" = main currency (part to the left of the decimal point)
* "f" = fractional currency (part to the right of the decimal point)
* 
* Optional formatting information may be included after the main or fractional currency are 
* specified. If none is added the main currency is returned as-is (a string of unaltered
* numeric text), and the fractional currency is returned rounded to two decimal points.
* 
* For the main currency, the number following "m" denotes the number of digit groups to separate
* using a separator which is included as the next character before the semi-colon. For example,
* to include the main currency separated into groups of three digits separated by a colon
* (e.g. 123,342,742,432) use "#m3,;";
* 
* For the fractional currency, the number following "f" determines the number of digits to 
* include after the decimal point. This is followed by a rounding method should the number
* of digits be insufficient: 
* 
* "r" = round to the nearest value
* "f" = floor to the nearest value
* "c" = ceiling to the nearest value		 
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg 
{	
	
	public class CurrencyFormat 
	{
		
		//$ + #m:3,; (main currency with 3-digit "," separator) + . + #f2r; (fractional currency rounded to 2 digits)
		public static const default_format:String = "$#m3,;.#f2r;";
		//$m; (main currency with no seperator) + . + #f2f; (fractional currency floored to 2 digits)
		public static const simple_format:String = "#m;.#f2f;";
		
		private var _nativeValue:String = new String(); //Converted to Number for operations		
		private static const NUMERIC_COMPS:String = "1234567890."; //Numeric string components including decimal point
		
		/**		 		 
		 * @param	initialValue The value with which to initialize the instance.
		 */
		public function CurrencyFormat(initialValue:*= null) 
		{
			parseValue(initialValue);
		}
		
		/**
		 * Rounds an input value based on the specified currency format. For example, if the currency
		 * format specifies 2 digits in the fractional currency
		 * 
		 * @param	inputVal The input value to round to the specified format.
		 * @param	format The format string determining the rounding precision.
		 * 
		 * @return The input value raounded to the rounding precision defined in the format.
		 */
		public function roundToFormat(inputVal:Number, format:String = null):Number 
		{
			var fractionalNumSize:Number = 2;
			if ((format != null) && (format != "")) {
				var formatStr:String = format.toLowerCase();
				var formatPos:int = formatStr.indexOf("f");
				if (formatPos >= 0) {
					try {
						fractionalNumSize = Number(formatStr.substr(formatPos + 1, 1));
						if (isNaN(fractionalNumSize)) {
							fractionalNumSize = 2;
						}
					} catch (err:*) {
						fractionalNumSize = 2;
					}
				}
			}			
			inputVal = Math.round(inputVal * (fractionalNumSize * 10)) / (fractionalNumSize * 10);
			return (inputVal);
		}
		
		/**
		 * Sets the native value in the CurrencyFormay instance.
		 * 
		 * @param	valueSet Any alpha-numeric native value that can be used in a currency context (currency symbols okay).
		 */
		public function setValue(valueSet:*):void 
		{			
			parseValue(valueSet);
		}
		
		public function getValue():Number 
		{
			return (Number(_nativeValue));
		}
		
		/**
		 * Returns the native CurrencyFormat value as a string using the formatting specified.
		 * 
		 * @param	format The format to return the native value in.
		 * 
		 * @return The formatted native value of this CurrencyFormat instance.
		 */
		public function getString(format:String = default_format):String 
		{
			if ((_nativeValue == null) || (_nativeValue.length == 0) ||
				(format == null) || (format == "")) {
				return("");
			}			
			//split the native currency string into main and fractional parts
			var valueSplit:Array = _nativeValue.split(".");
			try {
				var mainCurrency:String = valueSplit[0] as String;
				if ((mainCurrency == null) || (mainCurrency == "")) {
					mainCurrency = "0";
				}
			} catch (err:*) {
				mainCurrency = "0";
			}
			try {
				var fracCurrency:String = valueSplit[1] as String;
				if ((fracCurrency == null) || (fracCurrency == "")) {
					fracCurrency = "0";
				}
			} catch (err:*) {
				fracCurrency = "0";
			}			
			var outString:String = new String();
			var escapeBuffer:String = new String();
			var currencyType:String = "";
			var escActive:Boolean = false;
			for (var count:int = 0; count < format.length; count++) {
				var currentChar:String = format.substr(count, 1);				
				if (currentChar == "#") {
					escActive = true;
				}
				if (escActive) {
					escapeBuffer += currentChar;
					if (escapeBuffer.length == 2) {
						currencyType = currentChar;
					}
				} else {
					outString += currentChar;
				}
				if (currentChar == ";") {					
					if (currencyType == "#") {
						outString += "#";
					}
					if (currencyType == "m") {
						outString += generateMainCurrency(mainCurrency, escapeBuffer);
					}
					if (currencyType == "f") {
						outString += generateFracCurrency(fracCurrency, escapeBuffer);
					}
					if (currencyType == "#") {
						outString += "#";
					}
					currencyType = "";
					escapeBuffer = "";
					escActive = false;
				}
			}
			return (outString);
		}
		
		/**
		 * Parses the currency 
		 * 
		 * @param	value
		 */
		private function parseValue(value:*):void 
		{
			if (value == null) {
				return;
			}
			if (value is String) {
				_nativeValue = value;
			} else if ((value is Number) || (value is int) || (value is uint)) {
				_nativeValue = value.toString();
			} else {
				try {
					_nativeValue = String(value.toString());
				} catch (err:*) {
					_nativeValue = null;
				}
			}
			if (_nativeValue == null) {
				return;
			}
			var numericValue:String = new String();
			for (var count:int = 0; count < _nativeValue.length; count++) {
				var currentChar:String = _nativeValue.substr(count, 1);
				//strip out all non-numeric components
				if (isNumericComponent(currentChar)) {
					numericValue += currentChar;
				}
			}
			_nativeValue = numericValue;
		}
		
		/**
		 * Generates the main currency section of a currency format.
		 * 
		 * @param	currencyStr The currency value string to format.
		 * @param	formatSection The main currency formatting portion of a currency format.
		 * 
		 * @return The currency value string formatted using the specified main formatting.
		 */
		private function generateMainCurrency(currencyStr:String, formatSection:String):String 
		{			
			if ((formatSection == null) || (formatSection == "")) {
				return (currencyStr);
			}
			formatSection = formatSection.split("#").join("");
			formatSection = formatSection.split(";").join("");
			var splitGroupSize:uint = 0;
			var splitGroupSeparator:String = "";
			try {
				splitGroupSize = uint(formatSection.substr(0, 1));
			} catch (err:*) {
				splitGroupSize = 0;
			}
			try {
				splitGroupSeparator=formatSection.substr(1, 1);
			} catch (err:*) {
				splitGroupSeparator = "";
			}
			if ((splitGroupSize == 0) || (splitGroupSeparator == "")) {
				return (currencyStr);
			}
			var splitCount:uint = 0;			
			var returnStr:String = new String();
			for (var count:int = currencyStr.length; count >= 0; count--) {
				var currentChar:String = currencyStr.substr(count, 1);
				returnStr = currentChar + returnStr;
				splitCount++;
				if (splitCount >= splitGroupSize) {
					returnStr = splitGroupSeparator + returnStr;
				}
			}
			if (returnStr.substr(0, 1) == splitGroupSeparator) {
				returnStr = returnStr.substr(1);
			}
			return (returnStr);
		}
		
		/**
		 * Generates the fractional currency section of a currency format.
		 * 
		 * @param	currencyStr The currency value string to format.
		 * @param	formatSection The fractional currency formatting portion of a currency format.
		 * 
		 * @return The currency value string formatted using the specified fractional formatting.
		 */
		private function generateFracCurrency(currencyStr:String, formatSection:String):String 
		{					
			formatSection = formatSection.split("#").join("");
			formatSection = formatSection.split(";").join("");
			var splitGroupSize:uint = 2;
			var splitGroupRounding:String = "r";			
			try {
				splitGroupSize = uint(formatSection.substr(1, 1));
			} catch (err:*) {
				splitGroupSize = 2;
			}
			try {
				splitGroupRounding=formatSection.substr(2, 1);
			} catch (err:*) {
				splitGroupRounding = "r";
			}						
			if ((splitGroupSize == 0) || (splitGroupRounding == "")) {				
				return (currencyStr);
			}			
			var num:Number = new Number(currencyStr);
			switch (splitGroupRounding) {
				case "r" : num = Math.round(num);
					break;
				case "f" : num = Math.floor(num);
					break;
				case "c" : num = Math.ceil(num);
					break;
				default : num = Math.round(num);
					break;
			}			
			var returnStr:String = num.toString().substr(0, splitGroupSize);			
			if (returnStr.length < splitGroupSize) {
				for (var count:int = 0; count < (splitGroupSize-returnStr.length); count++) {
					returnStr += "0";
				}
			}
			return (returnStr);
		}
		
		/**
		 * Verifies a single-character string as a valid numeric string ("0" to "9" or ".").
		 * 
		 * @param input A single-character string to verify as a numeric string.
		 * 
		 * @return True if the input is a valid single-digit numeric string.
		 */
		private function isNumericComponent(input:String):Boolean
		{
			if (input == null) {
				return (false);
			}
			if (input.length == 0) {
				return (false);
			}
			if (input.length > 1) {
				return (false);
			}
			for (var count:int = 0; count < NUMERIC_COMPS.length; count++) {
				if (NUMERIC_COMPS.substr(count, 1) == input) {
					return (true);
				}
			}
			return (false);
		}
	}
}
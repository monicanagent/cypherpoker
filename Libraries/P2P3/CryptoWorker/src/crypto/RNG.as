/**
 * Provides cryptographically secure random number generation services.
 * 
 * (C)opyright 2014 to 2017
 * 
 * This source code is protected by copyright and distributed under license. 
 * Please see the root LICENSE file for terms and conditions.
 * 
 * Note: The generateRandomBytes function is available in Flash 11 and AIR 3.
 */

package crypto {
		
	import com.hurlant.crypto.hash.SHA256;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	import flash.utils.clearInterval;
	import flash.utils.setInterval;
	import flash.crypto.generateRandomBytes;
	
	public class RNG {
		
		private var _seed:uint = 0; //random interval seed
		private var _intervalID:uint; //used with setInterval
		private var _minGenRate:uint = 301; //ms
		private var _maxGenRate:uint = 953; //ms
		private var _bufferLength:uint = 32; //bytes
		private var _streamBuffer:ByteArray; //random stream byffer stores _bufferLength values
		private var _bufferIsStale:Boolean = true; //stream buffer needs to be refreshed?
		private var _targetIntervalDelta:Number; //the target interval delta
		private var _intervalDelta:int; //the actual interval delta		
		private static var _debug:Function = null;
		private static var _progress:Function = null;
		
		/**
		 * Creates an instance of the Random Number Generator class.
		 * 
		 * @param	bufferLength The length of the random stream buffer to use, in bytes.
		 * @param	minGenRate The minimum refresh rate for the random stream buffer, in milliseconds.
		 * @param	maxGenRate The maximum refresf rate for the random stream buffer, in milliseconds.
		 */
		public function RNG(bufferLength:uint = 0, minGenRate:uint = 0, maxGenRate:uint = 0) {			
			if (bufferLength != 0) {
				_bufferLength = bufferLength;
			}
			if (minGenRate != 0) {
				_minGenRate = minGenRate;
			}
			if (maxGenRate != 0) {
				_maxGenRate = maxGenRate;
			}
			_seed = getTimer();
			_streamBuffer = new ByteArray();			
			_targetIntervalDelta = Math.round(_seed * getRandomReal());			
			_intervalDelta = getTimer();
			_intervalID=setInterval(generateNextStreamBlock, _targetIntervalDelta);			
		}
		
		/**
		 * The progress reporting function reference or an anonymous
		 * and empty function if none has been assigned.
		 */
		public static function get progressReport():Function {
			if (_progress == null) {
				_progress = new function(... args):void { };
			}
			return (_progress);
		}
		
		public static function set progressReport(prgFunc:Function):void {
			_progress = prgFunc;
		}
		
		/**
		 * A reference to the debugging output function or an
		 * anonymous and empty function if none has been assigned.
		 */
		public static function get debugger():Function {
			if (_debug == null) {
				_debug = new function(... args):void { };
			}
			return (_debug);
		}
		 
		public static function set debugger(dbgFunc:Function):void {
			_debug = dbgFunc;
		}
		
		/**
		 * Sends a message to the debugger output if available.
		 * 
		 * @param	msg The message to send to the debugger output.
		 */
		public static function debug(msg:String):void {
			if (debugger != null) {
				debugger(msg);
			}
		}
		
		/**
		 * Sends a progress update message to the debugger output if available.
		 * 
		 * @param	msg The progress message to send to the debugger output.
		 */
		public static function updateProgress(progressVal:String):void {
			if (debugger != null) {
				debugger(progressVal);
			}
		}
		
		/**
		 * Pauses random stream buffer generation. Once the buffer is paused and stale,
		 * bytes will be read directly from the random number source.
		 */
		public function pauseStreamBuffer():void {
			try {
				clearInterval(_intervalID);
			} catch (err:*) {
			}
		}
		
		/**
		 * Resumes random stream buffer generation.
		 */
		public function resumeStreamBuffer():void {
			pauseStreamBuffer();
			_intervalID=setInterval(generateNextStreamBlock, _targetIntervalDelta);
		}
		
		/**
		 * Generates the next random bytes stream block and adds it to the stream buffer.
		 */
		public function generateNextStreamBlock():void {			
			clearInterval(_intervalID);
			try {
				/* 
				Entropy based on expected and actual timing differences in function call:
				Use delta value as input to SHA256. The resultant hash is applied 
				as a byte-by-byte XOR against the random bytes from the secure random byte stream.
				The result is added to the stream buffer.
				*/
				_intervalDelta = Math.abs((getTimer() - _intervalDelta)-_targetIntervalDelta);	
				var sha256:SHA256 = new SHA256();
				var hashSource:ByteArray = new ByteArray();
				hashSource.writeInt(_intervalDelta);
				hashSource.position = 0;			
				var intervalHash:ByteArray = sha256.hash(hashSource);	
				if (_seed > 1024) {
					_seed = 1022;
				}
				if (_seed < 1) {
					_seed = 2;
				}
				var stream:ByteArray = generateRandomBytes((_bufferLength - 1));
				intervalHash.position = 0;
				for (var count:uint = 0; count < intervalHash.length; count++) {
					if (count >= stream.length) {
						break;
					}
					try {									
						stream[count] = stream[count] ^ intervalHash[count];					
					} catch (err:*) {					
					}
				}	
				stream.position = 0;			
				_streamBuffer.writeBytes(stream, 0);			
				addToStreamBuffer(stream);				
			} catch (err:*) {				
			} finally {
				_seed = generateRandomBytes(4).readUnsignedInt() & 0x0FFF;
				if (_seed < _minGenRate) {
					_seed = _minGenRate;
				} else if (_seed > _maxGenRate) {				
					_seed = _maxGenRate-Math.round(_maxGenRate*getRandomReal());
				}
				while (_seed < 2) {
					_seed += Math.round(100 * getRandomReal());
				}
				_intervalDelta = getTimer();
				_targetIntervalDelta = Number(_seed);
				_intervalID = setInterval(generateNextStreamBlock, _seed);
			}
		}
		
		/**
		 * @return A cryptographically secure number equivalent to the output of 
		 * Math.random() from either the stream buffer or from the random source
		 * directly if buffer is stale.
		 */
		public function getRandomReal():Number {			
			var randBytes1:ByteArray = new ByteArray();
			var randBytes2:ByteArray = new ByteArray();
			randBytes2 = generateRandomBytes(4); //32 bits		
			if (!_bufferIsStale) {				
				if (_streamBuffer.bytesAvailable > 3) {					
					_streamBuffer.readBytes(randBytes1, 0, 4);					
				} else {
					_bufferIsStale = true;	
					randBytes1 = generateRandomBytes(4);
				}
			} else {			
				randBytes1 = generateRandomBytes(4);
			}
			randBytes1.position = 0;
			randBytes2.position = 0;
			var val1:Number = randBytes1.readUnsignedInt();
			var val2:Number = randBytes2.readUnsignedInt();
			var returnVal:Number = 0;			
			if (val1 > val2) {				
				returnVal=val2 / val1;
			} else {				
				returnVal=val1 / val2;
			}
			return (returnVal);
		}
		
		/**
		 * @return A cryptographically secure unsigned integer from either from the 
		 * stream buffer or from the random source directly if buffer is stale.
		 */
		public function getRandomUint():uint {			
			var randBytes:ByteArray = new ByteArray();
			if (!_bufferIsStale) {				
				if (_streamBuffer.bytesAvailable > 3) {					
					_streamBuffer.readBytes(randBytes, 0, 4);					
				} else {
					_bufferIsStale = true;	
					randBytes = generateRandomBytes(4);
				}
			} else {			
				randBytes = generateRandomBytes(4);
			}
			randBytes.position = 0;			
			var val:Number = randBytes.readUnsignedInt();			
			return (val);
		}
		
		/**
		 * @return A cryptographically secure signed integer from either from the 
		 * stream buffer or from the random source directly if buffer is stale.
		 */
		public function getRandomInt():int {			
			var randBytes:ByteArray = new ByteArray();
			if (!_bufferIsStale) {				
				if (_streamBuffer.bytesAvailable > 3) {					
					_streamBuffer.readBytes(randBytes, 0, 4);					
				} else {
					_bufferIsStale = true;	
					randBytes = generateRandomBytes(4);
				}
			} else {			
				randBytes = generateRandomBytes(4);
			}
			randBytes.position = 0;			
			var val:Number = randBytes.readInt();
			return (val);
		}
		
		/**
		 * Adds a random byte sequence to the stream buffer, overwriting
		 * existing buffer content if buffer is full.
		 * 
		 * @param	stream The sequence of random bytes to add to the stream buffer.
		 */
		private function addToStreamBuffer(stream:ByteArray):void {			
			_streamBuffer.writeBytes(stream, 0);			
			if (_streamBuffer.length > _bufferLength) {				
				var tempBuffer:ByteArray = new ByteArray();
				tempBuffer.position = 0;
				tempBuffer.writeBytes(_streamBuffer, 0, _bufferLength);
				_streamBuffer = tempBuffer;
				_streamBuffer.position = 0;				
				_bufferIsStale = false;				
			}			
		}		
		
		/**		 
		 * @return A sequence of random bytes of length _bufferLength from the stream
		 * buffer.
		 */
		private function get randomBytes():ByteArray {
			var returnBytes:ByteArray = new ByteArray();
			_streamBuffer = new ByteArray();
			_streamBuffer.readBytes(returnBytes, 0, _bufferLength);
			_bufferIsStale = true;
			return (returnBytes);
		}
	}
}
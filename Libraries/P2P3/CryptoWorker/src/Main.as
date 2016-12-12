/**
* Encapsulates the extended SRA cryptosystem into a Worker for multi-threaded execution. A "directResponder" model
* is used in environments that don't support Workers.
* 
* This is a top-level or document class and the enclosing project must be compiled in "Release" mode (debugging disabled)
* for the Worker to function correctly.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package {
		
	import crypto.math.BigInt;
	import crypto.RNG;
	import crypto.SRA;
	import crypto.SRAKey;
	import p2p3.workers.WorkerMessage;
	import p2p3.workers.CryptoWorkerCommand;	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.system.Worker;
	import flash.system.WorkerDomain;
	import flash.system.WorkerState
	import flash.system.MessageChannel;
	import flash.system.MessageChannelState;	
	import flash.utils.ByteArray;
	import flash.utils.setInterval;
	import flash.utils.setTimeout;
	
	public class Main extends Sprite {
				
		private static const _keyBitLength:uint = 1024; //Default key bit length (CB length * 8)
		private var _inputChannel:MessageChannel; //Worker input channel
		private var _outputChannel:MessageChannel; //Worker output channel
		private var _sra:SRA; //Current extended SRA cryptosystem instance		
		private var _rng:RNG = new RNG(33); //Current RNG instance, 33 byte buffer
		private var _currentRequestID:String = null; //Currently in-process request ID
		private var _directResponder:Function = null; //Reference to a direct responder model instance of a Worker host
		
		
		public function Main() {			
			setDefaults();		
			super();				
		}
		
		/**
		 * Stub function for any uncaptured debug messages in case we want to handle them here.
		 * 
		 * @param	debugMsg The debug message to capture.
		 * @param	params Additional parameters to capture.
		 */
		public function sendDebugStub(debugMsg:String, params:Object = null):void {
		}
				
		/**
		 * Sends a debug message to the Worker host.
		 * 
		 * @param	debugMsg The human readable debug message to send.
		 * @param	params Additional parameters to include.
		 */
		public function sendDebug(debugMsg:String, params:Object = null):void {
			sendStatus(debugMsg, 1, null, params);
		}		
		
		/**
		 * Stub function for any uncaptured progress update messages in case we want to handle them here.
		 * 
		 * @param	debugMsg The progress update message to capture.
		 * @param	params Additional parameters to capture.
		 */
		public function sendProgressStub(debugMsg:String, params:Object = null):void {
		}
		
		// -- DIRECT / NON-WORKER INTERFACE --
		
		/**
		 * Handles direct responses when multi-threading isn't available.
		 */
		public function get directResponder():Function {
			return (_directResponder);
		}
		
		public function set directResponder(responderSet:Function):void {
			_directResponder = responderSet;
		}
		
		/**
		 * Handles a direct channel message (as opposed to a channel message) from a worker host when multi-threading
		 * ins't available.
		 * 
		 * @param	inputStr The JSON-formatted direct channel message string to process.
		 */
		public function onDirectChannelMessage(inputStr:String):void {			
			var msgObject:WorkerMessage = parseRequestMessage(inputStr);	
			if (msgObject == null) {
				try {
					sendError("Message could not be parsed: " + inputStr, msgObj.requestId, msgObj.parameters);
				} catch (err:*) {					
				} finally {					
					sendError("Message format not understood: "+inputStr);					
					return;
				}
			}
			//Create response object...
			var msgObj:WorkerMessage = new WorkerMessage(msgObject.request, { }, msgObject.requestId);
			_currentRequestID = msgObj.requestId;
			var requestParts:Array = msgObject.request.split("/");
			var requestType:String = requestParts[0] as String;
			requestType = requestType.toUpperCase();
			var requestOperation:String = requestParts[1] as String;			
			if (requestType == "INVOKE") {
				processInvocation(requestOperation, msgObject);
			}		
			if (requestType == "OPTION") {
				processOption(requestOperation, msgObject);
			}
			_currentRequestID = null;
		}
		
		// --  WORKER INTERFACE --
		
		/**
		 * Handles a Worker channel message when running as a thread.
		 * 
		 * @param	inputStr The JSON-formatted direct channel message string to process.
		 */
		private function onChannelMessage(eventObj:Event):void {			
			var inputStr:String = _inputChannel.receive() as String;
			var msgObject:WorkerMessage = parseRequestMessage(inputStr);	
			if (msgObject == null) {
				try {					
					sendError("Message could not be parsed: " + inputStr, msgObj.requestId, msgObj.parameters);
				} catch (err:*) {					
				} finally {										
					sendError("Message format not understood: "+inputStr);					
					return;
				}
			}
			//Create response object...
			var msgObj:WorkerMessage = new WorkerMessage(msgObject.request, { }, msgObject.requestId);
			_currentRequestID = msgObj.requestId;
			var requestParts:Array = msgObject.request.split("/");
			var requestType:String = requestParts[0] as String;
			requestType = requestType.toUpperCase();
			var requestOperation:String = requestParts[1] as String;			
			if (requestType == "INVOKE") {
				processInvocation(requestOperation, msgObject);
			}		
			if (requestType == "OPTION") {
				processOption(requestOperation, msgObject);
			}
			_currentRequestID = null;
		}
		
		/**
		 * Processes a received invocation request and responds as appropriate.
		 * 
		 * @param	operationType An operation type matching one of the CryptoWorkerCommand constants.		 
		 * @param	requestObj The WorkerMessage request object containing additional invocation parameters.
		 */
		private function processInvocation(operationType:String, requestObj:WorkerMessage):void {
			try {
				var respMessage:WorkerMessage=new WorkerMessage(requestObj.request);
				switch (operationType) {					
					/**
					 * Generate random n-bit length number.
					 * 
					 * bits (uint) - bit length of generated random prime
					 * radix (uint) - the return radix, 10 (default) or 16. actionscript hexadecimal "0x" notation is used
					 * 
					 * returns string: generated value in specified radix 
					*/
					case CryptoWorkerCommand.SRA_GENRANDOM:
						if (!BigInt.initialized) {							
							BigInt.initialize(_rng);
						}	
						respMessage.parameters.bits = uint(requestObj.parameters.bits);
						respMessage.parameters.radix = uint(requestObj.parameters.radix);
						respMessage.parameters.msb = Boolean(requestObj.parameters.msb);
						respMessage.setDefaultParam("radix", 16); //Because hex is a little shorter
						respMessage.setDefaultParam("msb", true);
						var returnVal:Array;
						if (respMessage.parameters.msb) {
							returnVal=BigInt.randBigInt(respMessage.parameters.bits, 1);
						} else {
							returnVal=BigInt.randBigInt(respMessage.parameters.bits, 0);
						}
						respMessage.parameters.value = BigInt.bigInt2str(returnVal, respMessage.parameters.radix);
						if (respMessage.parameters.radix == 16) {
							respMessage.parameters.value = "0x" + respMessage.parameters.value;
						}
						sendResponse(operationType, respMessage.parameters, requestObj);						
						break;
					/**
					 * Generate random n-bit length verified prime.
					 * 
					 * bits (uint) - bit length of generated random prime
					 * radix (uint) - the return radix, 10 (default) or 16. actionscript hexadecimal "0x" notation is used
					 * 
					 * returns string: prime value in specified radix 
					*/
					case CryptoWorkerCommand.SRA_GENRANDOMPRIME:						
						respMessage.parameters.bits = requestObj.parameters.bits;
						respMessage.parameters.radix = requestObj.parameters.radix;						
						respMessage.setDefaultParam("radix", 16); //Because hex is a little shorter						
						respMessage.parameters.prime = SRA.genRandPrime(uint(respMessage.parameters.bits), false, uint(respMessage.parameters.radix));						
						sendResponse(operationType, respMessage.parameters, requestObj);												
						if (directResponder == null) {
							respMessage.parameters.prime = "";
							for (var count:uint = 0; count < uint(respMessage.parameters.bits); count++) {
								respMessage.parameters.prime += Math.random() * 0xFF;
							}					
						}
						break;
					case CryptoWorkerCommand.SRA_GENRANDOMKEY:
						/**
						* Generate random SRA encryption/decryption key.
						* 
						* prime (String) - the shared prime value. this value determines the maximal bit length for all other values. if null, blank, or 0, verified prime will be generated.
						* primeVerified (Boolean) - won't be verified if true, otherwise it will be (for shared primes not generated locally).
						* bits (uint) - bit length of the generated prime if one isn't specified, otherwise this value is ignored.
						* 
						* returns SRAKey as "_SRAKey" object
						*/						
						respMessage.parameters.prime = requestObj.parameters.prime;						
						respMessage.parameters.primeVerified = requestObj.parameters.primeVerified; //ignored if prime is empty string or < 1						
						respMessage.parameters.bits = requestObj.parameters.bits;						
						respMessage.setDefaultParam("prime", ""); //This means we generate a new prime, the slowest operation of them all						
						respMessage.setDefaultParam("primeVerified", false); //If false, prime will be verified (second slowest operation). If true, the fastest but least safe operation.						
						if ((respMessage.parameters.prime == "") || ((respMessage.parameters.prime == "0") || (respMessage.parameters.prime < 1))) {
							var sra:SRA = new SRA(uint(respMessage.parameters.bits), SRA.genRandPrime(uint(respMessage.parameters.bits), false), true);
						} else {
							sra = new SRA(SRA.getBitLength(String(respMessage.parameters.prime)), String(respMessage.parameters.prime), Boolean(respMessage.parameters.primeVerified));
						}												
						var key:SRAKey = sra.genRandKey(uint(respMessage.parameters.bits))
						respMessage.parameters._SRAKey = key;												
						sendResponse(operationType, respMessage.parameters, requestObj);						
						if (directResponder==null) {
							key.scrub();
							key = null;
							sra = null;
						}
						break;
					case CryptoWorkerCommand.SRA_GENKEY:
						/**
						* Generate assymetric SRA key half from specified key half.
						* 
						* key (String) - the key half for which to generate an asymetric key value.
						* prime (String) - the shared prime value. this value determines the maximal bit length for all other values.
						* primeVerified (Boolean) - won't be verified if true, otherwise it will be (for shared primes not generated locally).
						* bits (uint) - bit length of the generate prime if one isn't specified, otherwise this value is ignored.
						* 
						* returns SRAKey as "_SRAKey" object
						*/
						_rng.pauseStreamBuffer(); //No random data required for this operation
						respMessage.parameters.key = requestObj.parameters.key;						
						respMessage.parameters.prime = requestObj.parameters.prime;
						respMessage.parameters.primeVerified = requestObj.parameters.primeVerified; //ignored if prime is empty string or < 1						
						respMessage.setDefaultParam("prime", ""); //This means we generate a new prime, the slowest operation of them all
						respMessage.setDefaultParam("primeVerified", false); //If false, prime will be verified (second slowest operation). If true, the fastest but least safe operation.
						respMessage.setDefaultParam("key", "0");
						sra = new SRA(SRA.getBitLength(String(respMessage.parameters.prime)), String(respMessage.parameters.prime), Boolean(respMessage.parameters.primeVerified));						
						key = sra.genAsymKey(String(requestObj.parameters.key));
						respMessage.parameters._SRAKey = key;
						sendResponse(operationType, respMessage.parameters, requestObj);
						if (directResponder==null) {
							key.scrub();
							key = null;
							sra = null;
						}
						break;
					case CryptoWorkerCommand.SRA_VERIFYKEY:
						/**
						* Verifies an assymetric SRA key half against a specified modulus prime value
						* 
						* key (String) - the key half to verify against the specified modulus prime value
						* prime (String) - the prime modulus value to use in verification of the supplied key value
						* primeVerified (Boolean) - prime won't be verified if true, otherwise it will be (for shared primes not generated locally).						
						* 
						* returns "verified" boolean value denoting the success of the operation (true=key half is verified and is usable with the supplied prime modulus, false=fail).
						*/
						if (!BigInt.initialized) {							
							BigInt.initialize(_rng);
						}
						_rng.pauseStreamBuffer(); //No random data required for this operation
						var keyValArr:Array=createBigIntArr(requestObj.parameters.key);					
						respMessage.parameters.key = requestObj.parameters.key;
						respMessage.parameters.prime = requestObj.parameters.prime;
						respMessage.parameters.primeVerified = Boolean(requestObj.parameters.primeVerified);						
						respMessage.setDefaultParam("prime", "0");
						respMessage.setDefaultParam("primeVerified", false); //If false, prime will be verified (second slowest operation). If true, the fastest but least safe operation.
						respMessage.setDefaultParam("key", "0");
						respMessage.setDefaultParam("verified", false);
						sra = new SRA(SRA.getBitLength(String(respMessage.parameters.key)), String(respMessage.parameters.prime), Boolean(respMessage.parameters.primeVerified));
						respMessage.parameters.verified = sra.isValidEncryptionKey(keyValArr, sra.totient);
						sendResponse(operationType, respMessage.parameters, requestObj);
						if (directResponder==null) {
							key.scrub();
							key = null;
							sra = null;
						}
						break;
					case CryptoWorkerCommand.SRA_ENCRYPT:
						/**
						* Encrypts a plaintext value using a supplied SRA key object which includes both asymmetric key halves and the modulus (shared for commutativity).
						* 
						* _SRAKey (Object) - an anonymous object representation of a standard SRAKey object (all properties must match those in a SRAKey instance). The matching
						* values endKey, decKey, and modulus are use to construct a native SRAKey instance. All values are assumed to be properly generated and verified.
						* data (String) - the plaintext numeric string value to be encrypted. may be either standard integer or ActionScript hexadecimal notation ("0x"). The data
						* to be encrypted must always be slightly smaller than the key space, which is represented by the modulus length. Also, values near the extremes of this set
						* (near 0 and near the modulus value) tend to corrupt the cryptotext so it is advisable to avoid these.
						* radix (uint): the radix (10 or 16) in which to return the encrypted value in.
						* 
						* returns the encrypted plaintext "data" value as "result" within the parameters object
						*/						
						if ((requestObj.parameters["_SRAKey"] == undefined) || (requestObj.parameters["_SRAKey"] == null) || (requestObj.parameters["_SRAKey"] == "")) {
							sendError("CryptoWorker error: SRA key not defined for operation \"encrypt\"", requestObj.requestId, requestObj.parameters);
							break;
						} else {
							try {
								if (!BigInt.initialized) {
									BigInt.initialize(_rng);
								}
								_rng.pauseStreamBuffer();
								key = new SRAKey(requestObj.parameters._SRAKey.encKey, requestObj.parameters._SRAKey.decKey, requestObj.parameters._SRAKey.modulus);
								respMessage.parameters.radix = requestObj.parameters.radix;
								var data:String = new String(requestObj.parameters.data);
								sra = new SRA(key.modBitLength, key.modulusHex, true);
								respMessage.setDefaultParam("radix", 16);
								var result:String = sra.encrypt(data, key, respMessage.parameters.radix);
								respMessage.parameters._SRAKey = key;
								respMessage.parameters.result = result;
								sendResponse(operationType, respMessage.parameters, requestObj);
								if (directResponder==null) {
									key.scrub();
									scrub(result);
									scrub(data);
									key = null;
									sra = null;
								}
							} catch (err:*) {
							}
						}
						break;
					case CryptoWorkerCommand.SRA_DECRYPT:
						/**
						* Decryptes an encrypted value using a supplied SRA key object which includes both asymmetric key halves and the modulus (shared for commutativity). This
						* is the same operation as "encrypt" but the key halves are swapped.
						* 
						* _SRAKey (Object) - an anonymous object representation of a standard SRAKey object (all properties must match those in a SRAKey instance). The matching
						* values endKey, decKey, and modulus are use to construct a native SRAKey instance. All values are assumed to be properly generated and verified.
						* data (String) - the plaintext numeric string value to be encrypted. may be either standard integer or ActionScript hexadecimal notation ("0x"). The data
						* to be encrypted must always be slightly smaller than the key space, which is represented by the modulus length. Also, values near the extremes of this set
						* (near 0 and near the modulus value) tend to corrupt the cryptotext so it is advisable to avoid these.
						* radix (uint): the radix (10 or 16) in which to return the encrypted value in.
						* 
						* returns the encrypted plaintext "data" value as "result" within the parameters object
						*/						
						if ((requestObj.parameters["_SRAKey"] == undefined) || (requestObj.parameters["_SRAKey"] == null) || (requestObj.parameters["_SRAKey"] == "")) {
							sendError("CryptoWorker error: SRA key not defined for operation \"decrypt\"", requestObj.requestId, requestObj.parameters);
							break;
						} else {
							if (!BigInt.initialized) {
								BigInt.initialize(_rng);
							}
							_rng.pauseStreamBuffer();
							key = new SRAKey(requestObj.parameters._SRAKey.encKey, requestObj.parameters._SRAKey.decKey, requestObj.parameters._SRAKey.modulus);
							data = new String(requestObj.parameters.data);
							sra = new SRA(key.modBitLength, key.modulusHex, true);
							respMessage.parameters.radix = requestObj.parameters.radix;
							respMessage.setDefaultParam("radix", 16); //Because hex is a little shorter
							result = sra.decrypt(data, key, respMessage.parameters.radix);
							respMessage.parameters._SRAKey = key;
							respMessage.parameters.result = result;
							sendResponse(operationType, respMessage.parameters, requestObj);
							if (directResponder==null) {
								key.scrub();
								scrub(result);
								scrub(data);
								key = null;
								sra = null;
							}
						}
						break;
					case CryptoWorkerCommand.SRA_QRNR:
						/**
						* Generates lists of quadratic residues and quadratic non-residues when used with a given modulus prime.
						* 
						* startRange (String) - an integrer string representing the start range value of the generated values to return.
						* endRange (String) - an integrer string representing the end range value of the generated values to return.
						* prime (String) - the prime modulus against which to check for quadratic residuosity
						* radix (uint): the radix (10 or 16) in which to return the generates values
						* 
						* returns the arrays of quadratic residues, "qr", and quadratic non-residues, "qnr"
						*/
						if (!BigInt.initialized) {
							BigInt.initialize(_rng);
						}
						_rng.pauseStreamBuffer();
						var primeArr:Array = createBigIntArr(requestObj.parameters.prime);						
						var startRangeArr:Array = createBigIntArr(requestObj.parameters.startRange);						
						var endRangeArr:Array = createBigIntArr(requestObj.parameters.endRange);						
						respMessage.parameters.prime = requestObj.parameters.prime;						
						respMessage.parameters.startRange = requestObj.parameters.startRange;
						respMessage.parameters.endRange = requestObj.parameters.endRange;
						respMessage.parameters.radix = uint(requestObj.parameters.radix);
						respMessage.setDefaultParam("prime", "");						
						respMessage.setDefaultParam("startRange", [0]);
						respMessage.setDefaultParam("endRange", [0]);						
						respMessage.setDefaultParam("radix", 16);	
						var qrnrValues:Object=SRA.quadResidues(startRangeArr, endRangeArr, primeArr, respMessage.parameters.radix);
						respMessage.parameters.qr = qrnrValues.qr;
						respMessage.parameters.qnr = qrnrValues.qnr;
						sendResponse(operationType, respMessage.parameters, requestObj);
						break;						
					default: 
						sendError("Unsupported operation: \"" + operationType+"\"", requestObj.requestId, requestObj.parameters);
						break;
				}				
			} catch (err:*) {				
				sendError("CryptoWorker operation \""+operationType+"\" failed: " + err, requestObj.requestId, requestObj.parameters);
			} finally {
				respMessage.parameters.radix = 0;
				respMessage.parameters.bits = 0;
				respMessage.parameters.key = "";
				respMessage.parameters = null;				
				respMessage = null;
				_rng.resumeStreamBuffer();
			}
		}
		
		/**
		 * Processes a received option update request.
		 * 
		 * @param	operationType An option type matching one of the CryptoWorkerCommand constants.		 
		 * @param	requestObj The WorkerMessage request object containing any additional option parameters.
		 */
		private function processOption(optionType:String, requestObj:WorkerMessage):void {
			try {
				var respMessage:WorkerMessage=new WorkerMessage(requestObj.request);
				switch (optionType) {										
					case CryptoWorkerCommand.OPTION_ENABLEDEBUG:						
						SRA.debugger = sendDebug;
						BigInt.debugger = sendDebug;
						RNG.debugger = sendDebug;
						sendResponse(optionType, respMessage.parameters, requestObj);						
						break;
					case CryptoWorkerCommand.OPTION_DISABLEDEBUG:						
						SRA.debugger = sendDebugStub;
						BigInt.debugger = sendDebugStub;
						RNG.debugger =  sendDebugStub;
						sendResponse(optionType, respMessage.parameters, requestObj);						
						break;
					case CryptoWorkerCommand.OPTION_ENABLEPROGRESS:						
						SRA.progressReport = sendProgress;						
						BigInt.progressReport = sendProgress;
						RNG.progressReport =  sendProgress;
						sendResponse(optionType, respMessage.parameters, requestObj);						
						break;
					case CryptoWorkerCommand.OPTION_DISABLEPROGRESS:						
						SRA.progressReport = sendProgressStub;
						BigInt.progressReport = sendProgressStub;
						RNG.progressReport =  sendProgressStub;
						sendResponse(optionType, respMessage.parameters, requestObj);						
						break;		
					default: 
						sendError("Unsupported option: \"" + optionType+"\"", requestObj.requestId, requestObj.parameters);
						break;
				}				
			} catch (err:*) {
				sendError("CryptoWorker option \""+optionType+"\" update failed: " + err, requestObj.requestId, requestObj.parameters);
			} finally {				
				respMessage.parameters = null;				
				respMessage = null;
			}
		}
		
		/**
		 * Creates a BigInt array from an input value.
		 * 
		 * @param	val A string, either base 10 integer or hexadecimal (starting with "0x"), or a native numeric value
		 * to convert to a BigInt array. If an array is used it is returned with no changes.
		 * 
		 * @return A BigInt array of the numeric parameter string or null if the parameter was null.
		 */
		private function createBigIntArr(val:*):Array {
			if (val == null) {
				return (null);
			}							
			var returnArr:Array;
			if (val is String) {				
				var _localDataSize:int = int(val.length + 5);
				if (val.indexOf("0x") > -1) {
					var valHex:String = val.substr(val.indexOf("0x") + 2);
					returnArr = BigInt.str2bigInt(valHex, 16, _localDataSize);
				} else {
					returnArr = BigInt.str2bigInt(val, 10, _localDataSize);
				}
			} else if (val is Number) {
				returnArr = BigInt.str2bigInt(String(Math.round(val)), 10, 50);
			} else if ((val is uint) || (val is int)) {
				returnArr = BigInt.str2bigInt(String(val), 10, 50);
			} else if (val is Array) {
				returnArr = val;
			} else {
				var err:Error = new Error("Value \"" + val + "\" is not a recognized data type for conversion to BigInt array.");
				throw (err);
			}			
			return (returnArr);
		}
					
		/**
		 * Deserializes and parses a JSON-formatted request message and generates a WorkerMessage instance.
		 * 
		 * @param	msgString The input JSON object string.
		 * 
		 * @return A new WorkerMessage instance generated from the desrialized and parsed input string, or null
		 * if there was a problem.
		 */
		private function parseRequestMessage(msgString:String):WorkerMessage {
			try {
				var workerMsg:WorkerMessage = new WorkerMessage();
				workerMsg.deserialize(msgString);
				if (workerMsg.valid) {
					return (workerMsg);
				}
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		
		/**
		 * Sends a response to a Worker host request.
		 * 
		 * @param	msg The worker response message type, usually one of the CryptoWorkerCommand constants.
		 * @param	params Additional message parameters to include in the response.
		 * @param	sourceMsg The original request WorkerMessage being responded to.
		 */
		private function sendResponse(msg:String, params:Object = null, sourceMsg:WorkerMessage = null):void {			
			var sourceID:String = null;
			if ((sourceMsg.requestId != null) && (sourceMsg.requestId != "")) {
				sourceID = sourceMsg.requestId;
			}
			var responseMsg:WorkerMessage = new WorkerMessage("RESPONSE/" + msg, params, sourceID);			
			responseMsg.success = true;
			responseMsg.timestamp = sourceMsg.timestamp;
			if (Worker.isSupported) {
				try {
					_outputChannel.send(responseMsg.serialize());
				} catch (err:*) {
				}
			}
			if (directResponder != null) {
				try {
					directResponder(responseMsg.serialize());
				} catch (err:*) {						
				}
			}
		}
		
		/**
		 * Sends a status update message to the Worker host.
		 * 
		 * Valid status codes:
		 * 
		 * 0 - Startup (no statuses should be received before this)		 
		 * 1 - Debug / trace / informational status
		 * 2 - Update / progress status (includes source message ID of operation currently in progress)
		 * 3 - Error / try again (includes request source message ID)
		 * All other codes are available and currently treated as success codes.
		 * 
		 * @param msg A human readable status message to include with the update.
		 * @param statusCode A numeric status code to designate the update message (see valid status codes list above).
		 * @param sourceMessageId The ID of the source (request) message that this status update is associated with.
		 * @param params Additional parameters to include with the status update.
		 */
		private function sendStatus(msg:String, statusCode:uint = 0, sourceMessageId:String = null, params:Object = null):void {
			var statusMsg:WorkerMessage = new WorkerMessage("STATUS/" + String(statusCode) + ":" + msg, params, sourceMessageId);
			if (statusCode == 3)  {
				statusMsg.success = false;
			} else {
				statusMsg.success = true;
			}
			if (Worker.isSupported) {
				try {
					_outputChannel.send(statusMsg.serialize());
				} catch (err:*) {
				}
			}
			if (directResponder != null) {
				try {
					directResponder(statusMsg.serialize());
				} catch (err:*) {						
				}
			}
		}		
		
		/**
		 * Sends a progress update message to the Worker host.
		 * 
		 * @param debugMsg The human readable progress update message to send.
		 * @param sourceMessageId The source (request) message ID associated with this progress update.
		 * @param params Additional parameters to include.
		 */
		private function sendProgress(debugMsg:String, sourceMessageId:String = null, params:Object = null):void {
			if ((sourceMessageId == null) || (sourceMessageId == "")) {
				sourceMessageId = _currentRequestID; //may also be null, but try in any event
			}				
			sendStatus(debugMsg, 2, sourceMessageId, params);
		}
			
		/**
		 * Sends an error message to the Worker host.
		 * 
		 * @param debugMsg The human readable error message to send.
		 * @param sourceMessageId The source (request) message ID associated with the error.
		 * @param params Additional parameters to include.
		 */
		private function sendError(errorMsg:String, sourceMessageId:String = null, params:Object = null):void {
			sendStatus(errorMsg, 3, sourceMessageId, params);
		}
				
		/**
		 * Scrubs an input value by filling it with pseudo-random values.
		 * 
		 * @param	value The input value, string or array, to scrub.
		 * 
		 * @return True if the input value was successfully scrubbed, or false if the
		 * value was invalid or unrecognized.
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
		 * Scrubs an array by filling it with pseudo-random values.
		 * 
		 * @param	value The array to scrub.
		 * 		 
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
		 * Scrubs a string by filling it with pseudo-random values.
		 * 
		 * @param	value The string to scrub.
		 * 		 
		 */
		private function scrubString(str:String):void {
			try {
				var strLength:int = str.length;
				str = "";
				for (var count:int = 0; count < strLength; count++) {
					str += String.fromCharCode(Math.round(Math.random() * 0xFFFF));
				}
			} catch (err:*) {				
			}
			str = null;
		}
		
		/**
		 * Sets the startup defaults for the Worker instance.
		 */
		private function setDefaults():void {			
			if (!Worker.isSupported) {
				//Use public direct interface instead
				return;
			}
			_inputChannel = Worker.current.getSharedProperty("CryptoWorker_IN");			
			if (_inputChannel == null) {
				//Not launching in a valid Worker host.
				return;
			}
			try {
				_outputChannel = Worker.current.getSharedProperty("CryptoWorker_OUT");
				_inputChannel.addEventListener(Event.CHANNEL_MESSAGE, onChannelMessage);				
				SRA.rng = _rng;
				//Default all off (fastest mode of operation)
				SRA.debugger = sendDebugStub;
				SRA.progressReport = sendProgressStub;
				BigInt.debugger = sendDebugStub;
				BigInt.progressReport = sendProgressStub;
				RNG.debugger = sendDebugStub;
				RNG.progressReport = sendProgressStub;
				sendStatus("READY", 0);
			} catch (err:*) {				
			} finally {
			}
		}
	}
}
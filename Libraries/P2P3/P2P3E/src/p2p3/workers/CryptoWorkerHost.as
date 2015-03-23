/**
* Host for single or multi-threaded CryptoWorker, stored as an external SWF file.
* 
* The single-threaded CryptoWorker model is also referred to as "direct" since the CryptoWorker code runs in 
* the main thread of the player. Consequently, 
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.workers 
{
		
	import flash.display.MovieClip;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.system.LoaderContext;
	import flash.system.ApplicationDomain;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.system.Worker;
	import flash.system.WorkerDomain;
	import flash.system.WorkerState;
	import flash.system.MessageChannel;
	import flash.system.MessageChannelState;
	import flash.utils.ByteArray;	
	import flash.utils.getTimer;
	
	import p2p3.interfaces.ICryptoWorkerHost;
	import p2p3.workers.events.CryptoWorkerHostEvent;
	import p2p3.workers.CryptoWorkerCommand;
	import crypto.interfaces.ISRAKey;
	import crypto.SRAKey;
	import org.cg.DebugView;
	
	/**
	 * Hosts the main CryptoWorker as either a concurrent Worker process (desired), or as a direct SWF code library 
	 * which may cause script timeouts (therefore not desired). Direct mode is okay with small CB lengths.
	 */
	public class CryptoWorkerHost extends EventDispatcher implements ICryptoWorkerHost 
	{	
		//Embed Worker SWF.
		//Path is relative to this class file (not output SWF or project root).
		//With modifications to the class this SWF may also be loaded at runtime.
		[Embed(source="../../../../bin-workers/CryptoWorker.swf", mimeType="application/octet-stream")]
		private static var _CryptoWorkerClass:Class;	
		
		private var _workerThread:Worker; //Main CryptoWorker thread.	
		private static var _directWorker:Loader = null; //When Workers aren't available or forceNextNC=true (singleton required to prevent memory corruption).
		private static var _directWorkerBusy:Boolean = true; //This seems redundant -- it's a single thread
		private static var _directWorkerStarting:Boolean = false; //Direct Worker is initializing.
		private var _useConcurrency:Boolean = true; //Set to false to force non-concurrency even if available
		private var _channelToWorker:MessageChannel; //Sends requests to the CryptoWorker.
		private var _channelFromWorker:MessageChannel; //Receives responses and asynchronous updates from the CryptoWorker.
		private var _workerStarting:Boolean = false; //CryptoWorker is initializing, or the state between "new" and "running".
		private var _workerReady:Boolean = false; //CryptoWorker is ready and active.
		private var _workerAvailable:Boolean = false; //False when CryptoWorker is busy processing a request.
		private var _invocationQueue:Vector.<WorkerMessage> = new Vector.<WorkerMessage>();	//Stores requests when CryptoWorker is busy.
		private static var _directInvocationQueue:Vector.<WorkerMessage> = new Vector.<WorkerMessage>();			
		private var _directWorkerResponseProxy:Function = null;
		 
		/**
		 * Creates a new CryptoWorkerHost instance.
		 * 
		 * @param	useConcurrency True to enable multi-threading if available, false to disable.
		 */
		public function CryptoWorkerHost(useConcurrency:Boolean = true) 
		{
			_useConcurrency = useConcurrency;
			initialize();
		}
		
		/**
		 * Enable or disable CryptoWorker debugging messages. Default is false.
		 */
		public function set debug(enableSet:Boolean):void 
		{
			if (enableSet) {
				setOption(CryptoWorkerCommand.OPTION_ENABLEDEBUG);
			} else {
				setOption(CryptoWorkerCommand.OPTION_DISABLEDEBUG);
			}			
		}
		
		/**
		 * Enable or disable CryptoWorker progress messages. Default is false.
		 */
		public function set progress(enableSet:Boolean):void 
		{
			if (enableSet) {
				setOption(CryptoWorkerCommand.OPTION_ENABLEPROGRESS);
			} else {
				setOption(CryptoWorkerCommand.OPTION_DISABLEPROGRESS);
			}			
		}
		
		/**
		 * State of concurrency / multi-threading in this CryptoWorkerHost instance. Read-only since
		 * concurrency of a CryptoWorker can't be changed once instantiated.
		 */
		public function get concurrent():Boolean 
		{
				return (_useConcurrency);
		}	
		
		/**
		 * The function to invoke (more reliable) instead of an asynchronous event listener when host is in "direct" mode. Function
		 * reference MUST be public. If the proxy is set to null or unreachable a standard event is dispatched instead.
		 */
		public function set directWorkerEventProxy(proxySet:Function):void
		{
			_directWorkerResponseProxy = proxySet;
		}
		
		public function get directWorkerEventProxy():Function 
		{
			return (_directWorkerResponseProxy);
		}
		
		/**
		 * Starts the CryptoWorker instance with the currently set initialization parameters.
		 * 
		 * @return True if the CryptoWorker was started, false if it's already starting or running.
		 */
		public function start():Boolean
		{	
			if (_workerThread == null) {
				return (false);
			}
			if (_workerStarting) {
				return (false);
			}
			if (_workerThread.state == WorkerState.RUNNING) {
				return (false);
			}
			_workerStarting = true;
			_workerThread.start();
			return (true);
		}
		
		/**
		 * Halts the running CryptoWorker instance.
		 * 
		 * @return True if the CryptoWorker could be successfully halted, false if the CryptoWorker
		 * wasn't running.
		 */
		public function halt():Boolean 
		{
			_workerStarting = false;
			if (_workerThread == null) {
				return (false);
			}
			if (_workerThread.state != WorkerState.RUNNING) {
				return (false);
			}
			return (_workerThread.terminate());			
		}
		
		/**
		 * Generate a cryptographically secure n-bit random number.
		 * 
		 * @param	bitLength The bit-length of the returned random number.
		 * @param 	setMSB If true, the returned value will have its most significant bit set to 1 (to ensure full bit length), otherwise the MSB value depends
		 * on the random value of the first generated byte.
		 * @param	returnRadix The radix of the returned number. If 16, ActionScript hexadecimal notation ("0x") is used.
		 * 
		 * @return The WorkerMessage generated (check the "active" property to determine if it's queued or has been executed
		 * immediately).
		 * 
		 * The returned WorkerMessage's parameter object contains the generated number, "value", as a string in the specified radix.
		 */
		public function generateRandom(bitLength:uint, setMSB:Boolean = true, returnRadix:uint = 16):WorkerMessage 
		{
			return (invoke(CryptoWorkerCommand.SRA_GENRANDOM, { bits:bitLength, radix:returnRadix, msb:setMSB }, false));
		}
		
		/**
		 * Generate a n-bit verified random prime number.
		 * 
		 * @param	bitLength The bit-length of the returned verified random prime.
		 * @param	returnRadix The radix of the returned prime. If 16, ActionScript hexadecimal notation ("0x") is used.
		 * 
		 * @return The WorkerMessage generated (check the "active" property to determine if it's queued or has been executed
		 * immediately.
		 * 
		 * The returned WorkerMessage's parameter object contains the generated prime value, "prime", as a string in the specified radix.
		 */
		public function generateRandomPrime(bitLength:uint, returnRadix:uint = 16):WorkerMessage 
		{
			return (invoke(CryptoWorkerCommand.SRA_GENRANDOMPRIME, { bits:bitLength, radix:returnRadix }, false));
		}
		
		/**
		 * Generate a random n-bit asymmetric SRA key.
		 * 
		 * @param	primeVal The prime value to use to generate the key of the same bit length. If blank, null, or "0", a random 
		 * verified prime of the bit length specified by the bitLength parameter will be generated instead. ActionScript hexadecimal 
		 * "0x" notation can be used.
		 * @param	primeIsVerified If true, prime value will not be verified prior to key generation (faster but less secure).
		 * @param	bitLength The bit length of the generated SRA key if primeVal isn't specified. If primeVal is specified, it is
		 * used to determine the SRA key length and the bitLength parameter is ignored.
		 * 
		 * @return The WorkerMessage generated (check the "active" property to determine if it's queued or has been executed
		 * immediately.
		 * 
		 * The returned WorkerMessage's parameter object contains the generated SRAKey instance.
		 */
		public function generateRandomSRAKey(primeVal:String = "", primeIsVerified:Boolean = false, bitLength:uint = 0):WorkerMessage 
		{
			return (invoke(CryptoWorkerCommand.SRA_GENRANDOMKEY, { prime:primeVal, primeVerified:primeIsVerified, bits:bitLength }, false));
		}
		
		/**
		 * Generate a full SRA key from a supplied SRA key half.
		 * 
		 * @param	keyHalf The key half for which to produce an asymmetric key within the key space (bit length of primeVal).
		 * @param	primeVal The prime value (shared for commutativity). The bit length of the prime determines the key / data space.
		 * @param	primeIsVerified If true, the supplie primeVal is not verified (faster but less secure).
		 * 
		 * @return The WorkerMessage generated (check the "active" property to determine if it's queued or has been executed
		 * immediately.
		 * 
		 * The returned WorkerMessage's parameter object contains the full SRAKey instance.
		 */
		public function generateSRAKey(keyHalf:String, primeVal:String, primeIsVerified:Boolean = false, bitLength:uint = 0):WorkerMessage 
		{
			return (invoke(CryptoWorkerCommand.SRA_GENKEY, { key: keyHalf, prime:primeVal, primeVerified:primeIsVerified, bits:bitLength }, false));
		}
		
		/**
		 * Verifies a SRA key half for commutativity against a specified prime modulus.
		 * 
		 * @param	keyHalf The assymetric SRA key half to verify for validity and commutativity with the specified prime modulus value
		 * @param	primeVal The prime modulus value to use in verification of the keyHalf. The bit length of the prime determines the key / data space.
		 * @param	primeIsVerified If true, the supplie primeVal is not verified (faster but less secure).
		 * 
		 * @return The WorkerMessage generated (check the "active" property to determine if it's queued or has been executed
		 * immediately.
		 * 
		 * The returned WorkerMessage's parameter object contains a "verified" boolean property containing the result of the opeperation.
		 */
		public function verifySRAKey(keyHalf:String, primeVal:String = "", primeIsVerified:Boolean = false, bitLength:uint = 0):WorkerMessage 
		{
			return (invoke(CryptoWorkerCommand.SRA_VERIFYKEY, {key:keyHalf, prime:primeVal, primeVerified:primeIsVerified }, false));
		}
		
		/**
		 * Encrypts a plaintext value, represented as a numeric string, using a supplied SRA key. SRA key values should all be verified
		 * prior to invoking this operation. The encrypt and decrypt methods are identical when the modulus is the same, only the encryption and
		 * decryption keys are swapped in order to reverse the operation.
		 * 
		 * @param	dataValue The plaintext data value, as a numeric string, to encrypt (for example, "110920901"). ActionScript hexadecimal "0x" notation
		 * can also be used.
		 * @param	sraKey A valid SRAKey instance with all of the values (encryption/decryption keys, modulus) present.
		 * @param	returnRadix The radix of the returned data value, either 10 or 16 (hex).
		 * 
		 * @return The WorkerMessage generated (check the "active" property to determine if it's queued or has been executed
		 * immediately.
		 * 
		 * The returned WorkerMessage's parameter object contains an encrypted "result" numeric string property containing the result of the operation, in the radix
		 * specified.
		 */
		public function encrypt(dataValue:String, sraKey:ISRAKey, returnRadix:uint = 16):WorkerMessage 
		{
			return (invoke(CryptoWorkerCommand.SRA_ENCRYPT, {data: dataValue, _SRAKey:sraKey, radix:returnRadix }, false));
		}
		
		/**
		 * Decypts an encypted value, represented as a numeric string, using a supplied SRA key. SRA key values should all be verified
		 * prior to invoking this operation. The encrypt and decrypt methods are identical when the modulus is the same, only the encryption and
		 * decryption keys are swapped in order to reverse the operation.
		 * 
		 * @param	dataValue The encrypted data value, as a numeric string, to decrypt (for example, "64865463254"). ActionScript hexadecimal "0x" notation
		 * can also be used.
		 * @param	sraKey A valid SRAKey instance with all of the values (encryption/decryption keys, modulus) present.
		 * @param	returnRadix The radix of the returned data value, either 10 or 16 (hex).
		 * 
		 * @return The WorkerMessage generated (check the "active" property to determine if it's queued or has been executed
		 * immediately.
		 * 
		 * The returned WorkerMessage's parameter object contains a plaintext "result" numeric string property containing the result of the operation, in the radix
		 * specified.
		 */
		public function decrypt(dataValue:String, sraKey:ISRAKey, returnRadix:uint = 16):WorkerMessage 
		{
			return (invoke(CryptoWorkerCommand.SRA_DECRYPT, {data: dataValue, _SRAKey:sraKey, radix:returnRadix }, false));
		}
		
		/**
		 * Produces two arrays of values, one containing quadratic residues (QR), the other quadratic non-residues (NR), in a specified range when
		 * used with a specific modulus (prime).
		 * 
		 * @param	startRangeVal The starting or lowest value of the returned values, as a numeric string (for example, "687468468468151"). ActionScript hexadecimal
		 * notation "0x" can also be used.
		 * @param	endRangeVal The ending or highest value of the returned values, as a numeric string (for example, "987984649896849846"). ActionScript hexadecimal
		 * notation "0x" can also be used.
		 * @param	primeVal The modulus or prime value with which to test for quadratic residuosity.
		 * @param	returnRadix The radix of the returned data values, either 10 or 16 (hex).
		 * 
		 * @return The WorkerMessage generated (check the "active" property to determine if it's queued or has been executed
		 * immediately.
		 * 
		 * The returned WorkerMessage's parameter object contains a "values" object with two arrays, "qr" containg the quadratic residues in the specified
		 * range at the specified radix, and "qnr" containing the quadratic non-residues in the specified range at the specified radix.
		 */
		public function QRNR (startRangeVal:String, endRangeVal:String, primeVal:String, returnRadix:uint = 16):WorkerMessage 
		{
			return (invoke(CryptoWorkerCommand.SRA_QRNR, {startRange: startRangeVal, endRange:endRangeVal, prime:primeVal, radix:returnRadix }, false));
		}
		
		/**
		 * Overrides addEventListener allowing pre-emption of "forced silent" events.
		 * 
		 * @param	type Same as standard addEventListener parameter.
		 * @param	listener Same as standard addEventListener parameter.
		 * @param	useCapture Same as standard addEventListener parameter.
		 * @param	priority Same as standard addEventListener parameter.
		 * @param	useWeakReference Same as standard addEventListener parameter.
		 */
		override public function addEventListener (type:String, listener:Function, useCapture:Boolean = false, priority:int = 0, useWeakReference:Boolean = false) : void 
		{
			if (_useConcurrency) {
				super.addEventListener(type, listener, useCapture, priority, useWeakReference);
			}
		}
		
		/**
		 * Overrides removeEventListener allowing pre-emption of "forced silent" events.
		 * 
		 * @param	type Same as standard removeEventListener parameter.
		 * @param	listener Same as standard removeEventListener parameter.
		 * @param	useCapture Same as standard removeEventListener parameter.		 
		 */
		override public function removeEventListener (type:String, listener:Function, useCapture:Boolean = false) : void 
		{
			super.removeEventListener(type, listener, useCapture);
			directWorkerEventProxy = null;
		}
		
		/**
		 * Destroys the CryptoWorkerHost instance by removing any internal event listeners, cleaning up data structures,
		 * and otherwise preparing the instance for removal from memory. This method should be the last method
		 * invoked prior to flagging this instance for garbage collection.
		 */
		public function destroy():void 
		{
			_workerReady = false;
			_workerAvailable = false;
			halt();			
			if (_workerThread != null) {
				_workerThread.removeEventListener(Event.WORKER_STATE, onWorkerStateChange);				
			}
			if (_channelFromWorker != null) {
				_channelFromWorker.removeEventListener(Event.CHANNEL_MESSAGE, onWorkerMessage);
			}
			_workerThread = null;
			_channelFromWorker = null;
			_channelToWorker = null;
			for (var count:uint = 0; count < _invocationQueue.length; count++) {
				_invocationQueue[count] = null;
			}
			_invocationQueue = null;
		}
		
		/**
		 * Sets an option in the CryptoWorker.
		 * 
		 * @param	option The option to set. Use any valid option from the CryptoWorkerCommand class.
		 * @param	params Optional additional parameters to include with the option.
		 * 
		 * @return The message that was added to the invocation queue.
		 */
		private function setOption(option:String, params:Object = null):WorkerMessage 
		{
			start(); //just in case
			var workerMsg:WorkerMessage = new WorkerMessage("OPTION/" + option, params);
			workerMsg.active = false;
			if ((!_workerAvailable) || (!_workerReady) || (_directWorkerBusy)) {
				if (_useConcurrency) {
					_invocationQueue.unshift(workerMsg); //priority				
				} else {
					_directInvocationQueue.unshift(workerMsg);
				}
				return (workerMsg);
			} else {
				if (_useConcurrency) {
					_invocationQueue.unshift(workerMsg);
				} else {					
					_directInvocationQueue.unshift(workerMsg);
				}			
			}
			invokeNext();
			return (workerMsg);
		}
		
		/**
		 * Adds a CryptoWorker command to the invocation queue.
		 * 
		 * @param	operation A valid operation from the CryptoWorkerCommand class.
		 * @param	params Optional additional parameters to include with the operation. 
		 * @param	priority If true the message will be added to the beginning of the queue rather than the end.
		 * @return
		 */
		private function invoke(operation:String, params:Object = null, priority:Boolean = false):WorkerMessage 
		{		
			start();			
			var workerMsg:WorkerMessage = new WorkerMessage("INVOKE/" + operation, params);			
			workerMsg.active = false;			
			if (_useConcurrency) {
				if ((!_workerAvailable) || (!_workerReady)) {
					if (priority) {						
						_invocationQueue.unshift(workerMsg); //queued at beginning (next up)...						
					} else {						
						_invocationQueue.push(workerMsg); //queued at end...
					}
					return (workerMsg);
				} else {
					_invocationQueue.push(workerMsg);					
				}			
			} else {				
				if (_directWorkerBusy) {					
					if (priority) {
						_directInvocationQueue.unshift(workerMsg);						
					} else {
						_directInvocationQueue.push(workerMsg);					
					}					
					return (workerMsg);
				} else {					
					_directInvocationQueue.push(workerMsg);					
				}			
			}
			invokeNext();
			return (workerMsg);
		}
		
		/**
		 * Invokes the next operation or option update available on the queue.
		 */
		private function invokeNext():void 
		{							
			_workerAvailable = false;			
			if (_invocationQueue == null) {
				_invocationQueue = new Vector.<WorkerMessage>();
			}			
			if ((_invocationQueue.length == 0) && (_useConcurrency)) {				
				//nothing left to invoke							
				_workerAvailable = true;
				return;
			}			
			if (!_useConcurrency) {
				if (_directInvocationQueue == null) {
					_directInvocationQueue = new Vector.<WorkerMessage>();
				}
				if (_directInvocationQueue.length == 0) {
					_workerAvailable = true;										
					return;
				}
			}
			if ((!_useConcurrency) && _directWorkerBusy) {				
				return;
			}		
			if (_useConcurrency) {
				var invocation:WorkerMessage = _invocationQueue.shift(); //next up...
			} else {				
				invocation = _directInvocationQueue.shift(); //next up...
			}			
			invocation.active = true;			
			var eventObj:CryptoWorkerHostEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.EXECUTE);
			eventObj.message = invocation;
			eventObj.message.resetTimestamp();
			dispatchEvent(eventObj);
			eventObj.message.resetTimestamp();			
			if (Worker.isSupported && _useConcurrency) {				
				_channelToWorker.send(invocation.serialize());				
			} else {
				try {					
					_directWorkerBusy = true;
					_directWorker.content["onDirectChannelMessage"](invocation.serialize());					
				} catch (err:*) {					
					trace (err);
				}
			}
		}
		
		/**
		 * Handles state changes in the CryptoWorker.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private function onWorkerStateChange(eventObj:Event):void 
		{						
			switch (_workerThread.state) {
				case WorkerState.RUNNING:
					_workerStarting = false;
					var stateEvent:CryptoWorkerHostEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.RUN);
					dispatchEvent(stateEvent);
					break;
				case WorkerState.TERMINATED:
					stateEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.HALT);
					dispatchEvent(stateEvent);
					break;
				case WorkerState.NEW:
					stateEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.CREATED);
					dispatchEvent(stateEvent);
					break;
				default: break;
			}
		}
		
		/**
		 * Handles responses from the Direct (single-threaded) CryptoWorker. Not intended to be invoked
		 * directly from outside CryptoWorker.
		 * 
		 * @param	inputStr The response message from the CryptoWorker.
		 */
		public function directWorkerResponder(inputStr:String):void 
		{
			_workerStarting = false;
			_directWorkerBusy = false;
			var workerMsg:WorkerMessage = new WorkerMessage();			
			workerMsg.active = false;			
			try {
				workerMsg.deserialize(inputStr);				
				var completeMessage:String = workerMsg.request;
				var messageParts:Array=completeMessage.split(":");
				var codePart:String = messageParts[0] as String;
				var humanMessage:String = new String();
				//do this in case human message contains ":" parts...
				for (var count:uint = 1; count < messageParts.length; count++) {
					if (count > 1) {
						humanMessage += ":"+messageParts[count] as String;
					} else {
						humanMessage += messageParts[count] as String;
					}
				}
				var codeParts:Array = codePart.split("/");
				var messageType:String = codeParts[0] as String;
				var messageCode:uint = uint(codeParts[1] as String);
				switch (messageType) {
					case "STATUS":
						//either not responses to requests, or error responses to requests
						processWorkerStatusMsg(workerMsg, messageCode, humanMessage);						
						break;
					case "RESPONSE": 
						//only correctly fullfilled responses
						processWorkerResponseMsg(workerMsg, messageCode);						
						invokeNext();
						break;
					default:
						//this should never happen (maybe halt the application?) -- could indicate tampering
						processUnknownWorkerMsg(workerMsg);						
						break;
				}				
			} catch (err:*) {	
				trace (err);
				var statusEvent:CryptoWorkerHostEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.STATUS_ERROR);
				workerMsg.calculateElapsed();	
				statusEvent.message = workerMsg;			
				statusEvent.humanMessage = "Problem parsing worker message: "+inputStr;				
				dispatchEvent(statusEvent);
			}
		}
		
		/**
		 * Handles responses from the concurrent (multi-threaded) CryptoWorker.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private function onWorkerMessage(eventObj:Event):void 
		{			
			_workerStarting = false;
			var workerMsg:WorkerMessage = new WorkerMessage();			
			workerMsg.active = false;
			var channelMsg:String = _channelFromWorker.receive(true) as String;			
			try {
				workerMsg.deserialize(channelMsg);				
				var completeMessage:String = workerMsg.request;
				var messageParts:Array=completeMessage.split(":");
				var codePart:String = messageParts[0] as String;
				var humanMessage:String = new String();
				//do this in case human message contains ":" parts...
				for (var count:uint = 1; count < messageParts.length; count++) {
					if (count > 1) {
						humanMessage += ":"+messageParts[count] as String;
					} else {
						humanMessage += messageParts[count] as String;
					}
				}
				var codeParts:Array = codePart.split("/");
				var messageType:String = codeParts[0] as String;
				var messageCode:uint = uint(codeParts[1] as String);
				switch (messageType) {
					case "STATUS":
						processWorkerStatusMsg(workerMsg, messageCode, humanMessage);						
						break;
					case "RESPONSE": 
						processWorkerResponseMsg(workerMsg, messageCode);						
						invokeNext();
						break;
					default:
						processUnknownWorkerMsg(workerMsg);						
						break;
				}				
			} catch (err:*) {
				var statusEvent:CryptoWorkerHostEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.STATUS_ERROR);
				workerMsg.calculateElapsed();	
				statusEvent.message = workerMsg;			
				statusEvent.humanMessage = "Problem parsing worker message: "+channelMsg;				
				dispatchEvent(statusEvent);
			}
		}
		
		
		private var responseEvent:CryptoWorkerHostEvent;
		/**
		 * Processes a CryptoWorker response message by converting any custom serialized values to native objects and
		 * dispatching a CryptoWorkerHostEvent.RESPONSE event.
		 * 
		 * @param	msgObj The response message to process and include with the CryptoWorkerHostEvent.
		 * @param	code Response status code to include with the CryptoWorkerHostEvent.
		 */
		private function processWorkerResponseMsg(msgObj:WorkerMessage, code:uint):void 
		{							
			responseEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.RESPONSE);
			responseEvent.message = msgObj;			
			responseEvent.code = code;					
			responseEvent.data = msgObj.parameters;			
			//will more than one key ever be returned during a single operation? Seems unlikely...
			if ((msgObj.parameters["_SRAKey"] != null) && (msgObj.parameters["_SRAKey"] != undefined) && (msgObj.parameters["_SRAKey"] != "")) {				
				msgObj.parameters.sraKey = new SRAKey(msgObj.parameters["_SRAKey"].encKey, msgObj.parameters["_SRAKey"].decKey, msgObj.parameters["_SRAKey"].modulus);
				msgObj.parameters["_SRAKey"] = null;
				delete msgObj.parameters["_SRAKey"];
			}
			_workerReady = true;
			responseEvent.message.calculateElapsed();
			if (_useConcurrency) {				
				dispatchEvent(responseEvent);
			} else {				
				try {
					directWorkerEventProxy(responseEvent);
				} catch (err:*) {					
					dispatchEvent(responseEvent);
				}
			}
		}
		
		/**
		 * Processes an asynchronous CryptoWorker status message by converting any custom serialized values to native objects and
		 * dispatching one of the following events: 
		 * CryptoWorkerHostEvent.READY - The CryptoWorker is ready to receive  operations and 
		 * 
		 * @param	msgObj The response message to process and include with the CryptoWorkerHostEvent.
		 * @param	code Response status code to include with the CryptoWorkerHostEvent.
		 */
		private function processWorkerStatusMsg(msgObj:WorkerMessage, code:uint, humanMessage:String):void 
		{							
			switch (code) {
				case 0: 	
						//ready -- prior to this, worker can't / shouldn't be used
						var statusEvent:CryptoWorkerHostEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.READY);
						statusEvent.message = msgObj;
						statusEvent.code = code;
						statusEvent.humanMessage = humanMessage;
						statusEvent.data = msgObj.parameters;						
						_workerReady = true;	
						_workerAvailable = true;
						_workerStarting = false;
						statusEvent.message.calculateElapsed();
						dispatchEvent(statusEvent);
						invokeNext();
						break;
				case 1: 
						//developer debugging info
						_workerReady = true;
						_workerStarting = false;
						statusEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.DEBUG);
						statusEvent.message = msgObj;
						statusEvent.code = code;
						statusEvent.humanMessage = humanMessage;
						statusEvent.data = msgObj.parameters;
						statusEvent.message.calculateElapsed();
						dispatchEvent(statusEvent);						
						break;						
				case 2: 
						//called intermitently (depending on the operation) during lengthy functions
						_workerReady = true;
						_workerStarting = false;
						statusEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.PROGRESS);
						statusEvent.message = msgObj;
						statusEvent.message.active = true;
						statusEvent.code = code;
						statusEvent.humanMessage = humanMessage;
						statusEvent.data = msgObj.parameters;
						statusEvent.message.calculateElapsed();
						dispatchEvent(statusEvent);						
						break;										
				case 3: 
						//usually returned instead of a response whenever there's an error
						statusEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.ERROR);
						statusEvent.message = msgObj;
						statusEvent.code = code;
						statusEvent.humanMessage = humanMessage;
						statusEvent.data = msgObj.parameters;	
						statusEvent.message.calculateElapsed();
						dispatchEvent(statusEvent);
						_workerReady = true;	
						_workerAvailable = true;
						_workerStarting = false;
						invokeNext();
						break;						
				default: 
						//generic status (not currently in use)
						_workerReady = true;
						_workerStarting = false;
						statusEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.STATUS);
						statusEvent.message = msgObj;
						statusEvent.code = code;
						statusEvent.humanMessage = humanMessage;
						statusEvent.data = msgObj.parameters;
						statusEvent.message.calculateElapsed();
						dispatchEvent(statusEvent);
						break;
			}			
		}
		
		/**
		 * Processes an unrecogized CryptoWorker response message.
		 * 
		 * @param	msgObj The unrecognized CryptoWorker response message to process.
		 */
		private function processUnknownWorkerMsg(msgObj:WorkerMessage):void 
		{			
			var statusEvent:CryptoWorkerHostEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.STATUS_ERROR);
			statusEvent.message = msgObj;			
			statusEvent.humanMessage = "Unknown CryptoWorker message: "+msgObj.serialize();
			statusEvent.data = msgObj.parameters;
			statusEvent.message.calculateElapsed();
			dispatchEvent(statusEvent);
		}		
		
		/**
		 * Initializes the CryptoWorkerHost instance.
		 */
		private function initialize():void 
		{
			var workerBytes:ByteArray = new _CryptoWorkerClass() as ByteArray;			
			if ((!Worker.isSupported) || (!_useConcurrency)) {
				_useConcurrency = false;
				if (!Worker.isSupported) {
					trace ("CryptoWorkerHost.initialize: Starting CryptoWorkerHost in single-threaded mode. Multi-threaded execution not supported.");
				} else {
					trace ("CryptoWorkerHost.initialize: Starting CryptoWorkerHost in single-threaded mode. Multi-threaded execution disabled.");
				}
				//Non-concurrent operation
				if (_directWorker == null) {
					if (_directWorkerStarting) {
						return;
					}					
					_directWorkerStarting = true;
					_directWorker = new Loader();	
					var context:LoaderContext = new LoaderContext(false, ApplicationDomain.currentDomain);
					context.allowCodeImport = true;				
					_directWorker.loadBytes(workerBytes, context);				
					_directWorker.contentLoaderInfo.addEventListener(Event.INIT, onGenerateWorker);					
				} else if (!_workerStarting) {
					onGenerateWorker(new Event(Event.INIT));
				}				
			} else {
				trace ("CryptoWorkerHost.initialize: Starting CryptoWorkerHost in multi-threaded mode.");
				//Concurrent operation			
				_workerThread = WorkerDomain.current.createWorker(workerBytes);				
				_workerThread.addEventListener(Event.WORKER_STATE, onWorkerStateChange);
				_channelToWorker = Worker.current.createMessageChannel(_workerThread); //outbound
				_channelFromWorker = _workerThread.createMessageChannel(Worker.current); //inbound						
				_workerThread.setSharedProperty("CryptoWorker_IN", _channelToWorker); //IN-bound from CryptoWorker's point of view
				_workerThread.setSharedProperty("CryptoWorker_OUT", _channelFromWorker);		
				_channelFromWorker.addEventListener(Event.CHANNEL_MESSAGE, onWorkerMessage);
			}
		}
		
		/**
		 * Handles the creation of a Direct (non-concurrent) CryptoWorker, usually as a load operation.
		 * 
		 * @param	eventObj A standard Event object as broadcast from a ContentLoaderInfo instance.
		 */
		private function onGenerateWorker(eventObj:Event):void 
		{			
			try {				
				_directWorker.content["directResponder"] = directWorkerResponder;				
				var statusEvent:CryptoWorkerHostEvent = new CryptoWorkerHostEvent(CryptoWorkerHostEvent.READY);	
				_workerReady = true;	
				_workerAvailable = true;
				_workerStarting = false;	
				_directWorkerBusy = false;
				_directWorkerStarting = false;
				dispatchEvent(statusEvent);				
				invokeNext();
			} catch (err:*) {
				_directWorker.unloadAndStop(true);
				_directWorker = null;
			}		
		}		
		
	}

}
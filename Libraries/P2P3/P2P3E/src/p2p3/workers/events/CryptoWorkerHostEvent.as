/**
* Events and associated data dispatched by the CryptoWorkerHost. Although all events are
* asynchronous, those marked as "asynchronous" in this context may be dispatched at any time and not
* necessarily in response to a command.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.workers.events {
	
	import flash.events.Event;
	import p2p3.workers.WorkerMessage;

	public class CryptoWorkerHostEvent extends Event {
		
		//CryptoWorker has been created (not yet started).
		public static const CREATED:String = "Event.CryptoWorkerHostEvent.CREATED";
		//CryptoWorker is running but may not yet have been fully initialized.
		public static const RUN:String = "Event.CryptoWorkerHostEvent.RUN";
		//CryptoWorker is fully ready.
		public static const READY:String = "Event.CryptoWorkerHostEvent.READY";
		//CryptoWorker execution has halted.
		public static const HALT:String = "Event.CryptoWorkerHostEvent.HALT";
		//Next cryptoWorker command is about to execute.
		public static const EXECUTE:String = "Event.CryptoWorkerHostEvent.EXECUTE";
		//CryptoWorker generic asynchronous status message.
		public static const STATUS:String = "Event.CryptoWorkerHostEvent.STATUS"; 
		//CryptoWorkerHost error - the CryptoWorker status couldn't be understood. This is a host-generated error.
		public static const STATUS_ERROR:String = "Event.CryptoWorkerHostEvent.STATUS_ERROR";
		//CryptoWorker error. This is a Worker-generated error.
		public static const ERROR:String = "Event.CryptoWorkerHostEvent.ERROR";
		//CryptoWorker debugging message. Set the CryptoWorkerHost "debug: property to true to enable this event.
		public static const DEBUG:String = "Event.CryptoWorkerHostEvent.DEBUG";
		//CryptoWorker progress update message. Set the CryptoWorkerHost "progress" property to true to enable this event.
		public static const PROGRESS:String = "Event.CryptoWorkerHostEvent.PROGRESS";
		//CryptoWorker response to a request.
		public static const RESPONSE:String = "Event.CryptoWorkerHostEvent.RESPONSE";
		
		//The CryptoWorker message included with the event.
		public var message:WorkerMessage = null;
		//Message code 
		public var code:uint = 0;
		//Human-readable message
		public var humanMessage:String = "";
		//Included response data. Usually points to message.parameters
		public var data:Object = null;
		
		/**
		 * Creates a new CryptoWorkerHostEvent.
		 * 
		 * @param	type See Event constructor.
		 * @param	bubbles See Event constructor.
		 * @param	cancelable See Event constructor.
		 */
		public function CryptoWorkerHostEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false) {
			super(type, bubbles, cancelable);			
		}
		
		/**
		 * A toString override that provides additional information about the CryptoWorkerHost event.
		 * 
		 * @return A formatted string including information about the CryptoWorkerHost event such as the event type,
		 * result code, result data, and human-readable message.
		 */
		override public function toString():String 	{
			var returnStr:String = new String();
			returnStr = "[CryptoWorkerHostEvent]\n";
			returnStr += " Type             : " + super.type + "\n";
			returnStr += " Code             : " + code + "\n";
			returnStr += " Data      	    : " + data + "\n";
			returnStr += " Human message    : " + humanMessage + "\n";		
			if (message!=null) {
				returnStr += " Message object   : " + message; //has its own linefeed
			} else {
				returnStr += " Message object   : null\n";
			}				
			return (returnStr);
		}		
	}
}
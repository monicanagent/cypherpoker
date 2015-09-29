/**
* Stores data and calculates statistics for messages sent between Worker instances and their host.
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.workers 
{
	
	import flash.utils.getTimer;
	
	public class WorkerMessage 
	{
		
		private var _request:String; //Requested operation or option update		
		private var _params:Object; //Parameters included with the operation or option update
		private var _active:Boolean = false; //Is the operation or option update currently active?
		private var _reqId:String = null; //Unique sequential ID of the request
		private var _respId:String = null; //Unique sequential ID of the response
		private var _success:Boolean = false; //Was the requested operation or option update successful?		
		private var _timestamp:Number = -1; //Current timestamp, used for calculating operation time
		private var _elapsed:int = 0; //Number of elapsed milliseconds from request to response
		private static var _index:Number = 0; //Global message index
		//Enumerable properties (included with JSON data); if they don't appear here, they will not be serialized/deserialized (basically a filter)
		private static const _enumProperties:Array = ["request", "success", "requestId", "responseId", "parameters", "timestamp"];		
		
		/**
		 * Creates a new WorkerMesage instance.
		 * 
		 * @param	requestStr The requested operation or option.
		 * @param	params Additional parameters for the operation or option update request.
		 * @param	reqId A unique request ID, or an existing request ID when this instance is a reply.
		 */
		public function WorkerMessage(requestStr:String = "", params:Object = null, reqId:String = null) 
		{
			request = requestStr;		
			parameters = params;			
			generateId(reqId);
		}
		
		/**
		 * The requested operation or option update.
		 */
		public function set request(requestSet:String):void 
		{
			_request = requestSet;
		}
		
		public function get request():String 
		{
			return (_request);
		}
		
		/**
		 * True if the requested operation or option update completed successfully.
		 */
		public function set success(successSet:Boolean):void 
		{
			_success = successSet;
		}
		
		public function get success():Boolean 
		{
			return (_success);
		}
		
		/**
		 * The operation or option update parameters.
		 */
		public function get parameters():Object 
		{
			if (_params == null) {
				_params = new Object();
			}
			return (_params);
		}		
		
		public function set parameters(paramsSet:Object):void 
		{			
			_params = paramsSet;
		}		
		
		/**
		 * The ID of the initiating request message.
		 */
		public function get requestId():String 
		{
			return (_reqId);
		}
		
		/**
		 * The ID of the response message.
		 */
		public function get responseId():String 
		{
			return (_respId);
		}
		
		/**
		 * @return True if the WorkerMessage object appears to be valid.
		 */
		public function get valid():Boolean 
		{
			if (_request == null) {
				return (false);
			}
			if (_request == "") {
				return (false);
			}
			return (true);
		}
		
		/**
		 * The numeric timestamp of the WorkerMessage.
		 */
		public function get timestamp():Number 
		{
			return (_timestamp);
		}
		
		public function set timestamp(tsSet:Number):void 
		{			
			_timestamp = tsSet;			
		}
		
		/**
		 * The number of elapsed milliseconds between the time that the request was sent
		 * and the response was received.
		 */
		public function get elapsed():int 
		{
			return (_elapsed);
		}
		
		/**
		 * True if the current message operation or option update is currently active.
		 */
		public function set active(activeSet:Boolean):void 
		{
			_active = activeSet;			
		}
		
		public function get active():Boolean 
		{
			return (_active);
		}		
		
		/**
		 * Copies the contents of a request WorkerMessage to this instance so that
		 * it can be used as a reply.
		 * 
		 * @param	requestObj The initiating WorkerMessage.
		 * 
		 * @return True if the supplied WorkerMessage could be correctly parsed, false otherwise.
		 */
		public function createFromRequest(requestObj:WorkerMessage):Boolean 
		{
			if (requestObj == null) {
				return (false);
			}
			deserialize(requestObj.serialize());
			return (true);
		}
		
		/**
		 * Resets the current timestamp.
		 */
		public function resetTimestamp():void
		{
			_timestamp = Number(getTimer());
		}
				
		/**
		 * Calculates the elapsed time value as the difference between the current and previously set timestamps.
		 */
		public function calculateElapsed():void 
		{
			_elapsed = Number(getTimer()) - _timestamp;			
		}
		
		/**
		 * Sets a default parameter (only if it doesn't exist).
		 * 
		 * @param	paramName The new parameter name to set.
		 * @param	value The value to assign to the new default parameter.
		 * 
		 * @return True if the parameter was new and was set, false otherwise.
		 */
		public function setDefaultParam(paramName:String, value:*):Boolean 
		{			
			if ((parameters[paramName] != null) && (parameters[paramName] != undefined)) {
				//Already exists!
				return (false);
			}
			parameters[paramName] = value;
			return (true);
		}		
		
		/**		 		 
		 * @return A JSON-formatted string representation of the WorkerMessage instance containing
		 * only enumerable properties.
		 */
		public function serialize():String 
		{			
			var sObj:Object = new Object();
			for (var count:uint = 0; count < _enumProperties.length; count++) {
				var enumProp:String = _enumProperties[count] as String;
				sObj[enumProp] = this[enumProp];
			}
			return (JSON.stringify(sObj));
		}
		
		/**
		 * Deserializes a JSON-formatted string and assigns the contained values to this WorkerMessage
		 * instance.
		 * 
		 * @param	jsonString The JSON string to deserialize.
		 */
		public function deserialize(jsonString:String):void 
		{		
			var obj:Object = JSON.parse(jsonString);
			for (var item:String in obj) {				
				if (isEnumerable(item)) {
					try {
						switch (item) {							
							case "requestId":
								//read-only property
								_reqId = obj[item] as String;
								break;
							case "responseId":
								//read-only property
								_respId = obj[item] as String;
								break;							
							case "timestamp":								
								_timestamp = Number(obj[item]);
								break;		
							default: 
								this[item] = obj[item];
								break;
						}
					} catch (err:*) {						
					}
				}
			}
		}
		
		/**		 
		 * @return Human readable string output of the contents of this WorkerMessage instance.
		 */
		public function toString():String 
		{
			var returnStr:String = new String();
			returnStr += "[WorkerMessage]\n";
			returnStr += "   request     : " + request +"\n";
			returnStr += "   requestId   : " + requestId +"\n";
			returnStr += "   responseId  : " + responseId +"\n";
			returnStr += "   timestamp   : " + timestamp +"\n";
			returnStr += "   elapsed (ms): " + elapsed +"\n";
			returnStr += "       active  : " + _active +"\n";			
			returnStr += "   parameters  : \n";
			for (var item:* in parameters) {				
				returnStr += "     \""+item+"\" ("+typeof(parameters[item])+"): " + parameters[item] +"\n";
			}
			return (returnStr);
		}
		
		
		/**
		 * Generates a unique sequential request or response message ID.
		 * 
		 * @param	reqestIdStr If supplied, this ID is used as the original request ID
		 * and the newly generated ID becomes the response ID. If not supplied, the newly generated
		 * ID is used as the request ID.
		 */
		private function generateId(reqestIdStr:String = null):void 
		{
			var dateObj:Date = new Date();
			_reqId = new String();
			_reqId += String(dateObj.getUTCFullYear())
			if (dateObj.getUTCMonth() <= 9) {
				_reqId += "0";
			}
			_reqId += String(dateObj.getUTCMonth()+1);
			if ((dateObj.getUTCDate()+1) <= 9) {
				_reqId += "0";
			}
			_reqId += String(dateObj.getUTCDate());
			if (dateObj.getUTCHours() <= 9) {
				_reqId += "0";
			}
			_reqId += String(dateObj.getUTCHours());
			if (dateObj.getUTCMinutes() <= 9) {
				_reqId += "0";
			}
			_reqId += String(dateObj.getUTCMinutes());
			if (dateObj.getUTCSeconds() <= 9) {
				_reqId += "0";
			}
			_reqId += String(dateObj.getUTCSeconds());
			if (dateObj.getUTCMilliseconds() <= 9) {
				_reqId += "0";
			}
			if (dateObj.getUTCMilliseconds() <= 99) {
				_reqId += "0";
			}
			_reqId += String(dateObj.getUTCMilliseconds());
			_reqId += String(_index);
			if ((reqestIdStr != null) && (reqestIdStr != "")){
				_respId = _reqId;
				_reqId = reqestIdStr;
			}
			_index++;
		}
		
		/**
		 * Verifies whether or not a property of the WorkerMessage instance is enumerable 
		 * during serialization and deserialization operations. Only properties named in the
		 * _enumProperties array are enumerable.
		 * 
		 * @param	propName The property to verify.
		 * 
		 * @return True if the specified property should be enumerated, false otherwise.
		 */
		private function isEnumerable(propName:String):Boolean 
		{
			try {				
				if ((this[propName] == undefined) && (this[propName]!=null)) {				
					return (false);
				}
				for (var count:uint = 0; count < _enumProperties.length; count++) {
					var currentProp:String = _enumProperties[count] as String;
					if (currentProp == propName) {
						return (true);
					}
				}
			} catch (err:*) {				
			}			
			return (false);
		}		
	}
}
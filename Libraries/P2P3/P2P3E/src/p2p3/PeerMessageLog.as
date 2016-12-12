/**
* Handles logging and exporting of peer messages.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3 {	
	
	import flash.utils.ByteArray;
	import p2p3.interfaces.IPeerMessage;
	import p2p3.interfaces.IPeerMessageLog;
	
	public class PeerMessageLog implements IPeerMessageLog {
		
		private var _queue:Vector.<IPeerMessage> = new Vector.<IPeerMessage>(); //all of the peer messages stored by this log
		
		/**
		 * Creates a new instance.
		 */
		public function PeerMessageLog() {
		}
		
		/**
		 * Adds a valid peer message to the log.
		 * 
		 * @param	peerMessage A valid IPeerMessage implementation to add to the log.
		 */
		public function addMessage(peerMessage:IPeerMessage):void {
			if (peerMessage == null) {
				return;
			}
			if (!peerMessage.isValid) {
				return;
			}
			_queue.push(peerMessage);
		}
		
		/**
		 * Exports the recorded peer message log in the format specified.
		 * 
		 * @param	formatType The data type class to return (XML or JSON), or the strings 
		 * "xml, "json, "amf0" or "amf3" (only as strings since no native ActionScript type exists) 
		 * for the respective data types. 
		 * XML data is stored in a top-level <PeerMessageLog> node, with each child node 
		 * the XML output of the log messages. JSON is simply stored as an anonymous object 
		 * with each child object representing the JSON output of each peer message. 
		 * AMF output is a vector of ByteArray objects, each the AMF output of the peer message.
		 * 
		 * @return The complete peer message log in the data format specified.
		 */
		public function export(formatType:*):* {
			if (formatType == null) {
				return (null);
			}
			var formatStr:String = new String();
			if (formatType is XML) {
				formatStr = "xml";
			}
			if (formatType is JSON) {
				formatStr = "json";
			}
			if (formatType is String) {
				formatStr = formatType;
			}
			if ((formatStr == null) || (formatStr == "")) {
				return (null);
			}
			switch (formatStr) {
				case "xml": var returnData:* = new XML("<PeerMessageLog/>");
					break;
				case "json": returnData = new String();
					returnData = "{";
					break;
				case "amf0": returnData = new Vector.<ByteArray>();
					break;
				case "amf3": returnData = new Vector.<ByteArray>();
					break;
				default: return (null);
					break;
			}
			for (var count:int = 0; count < _queue.length; count++) {
				var currentItem:IPeerMessage = _queue[count];
				switch (formatStr) {
					case "xml": returnData.appendChild(currentItem.serializeToXML());
						break;
					case "json": returnData += currentItem.serializeToJSON();
						break;
					case "amf0": returnData.push(currentItem.serializeToAMF0());
						break;
					case "amf3": returnData.push(currentItem.serializeToAMF3());
						break;
					default: return (null);
						break;
				}
			}
			switch (formatStr) {			
				case "json": returnData += "}";
					break;				
			}
			return (returnData);
		}
		
		/**
		 * Clears out the internal queue so that the instance reference may be nulled.
		 */
		public function destroy():void {
			_queue = null;
		}
	}
}
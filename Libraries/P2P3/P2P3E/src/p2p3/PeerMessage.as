/**
* Handles a peer message and associated data.
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3 
{
		
	import flash.utils.ByteArray;
	import flash.net.ObjectEncoding;
	import flash.utils.CompressionAlgorithm;
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.interfaces.IPeerMessage;
	import p2p3.netcliques.NetCliqueMember;
	import com.hurlant.util.Base64;
	import flash.utils.getQualifiedClassName;
	import flash.utils.describeType;	
	
	public class PeerMessage implements IPeerMessage 
	{
		
		//Delimiter between peer IDs in a string (used to split into array).
		public static const defaultPeerIDDelimiter:String = "-";
		//SerializeToXML return message structure (can be used as a reference to an empty message).
		public static const serialXMLMsgStruct:XML = <PeerMessage timestampGenerated=""><nativeStruct type=""/></PeerMessage>;		
		//One or more hyphen-delimited source peer IDs. The first ID is the most recent, last-to-relay peer ID,
		//followed by the second last, and so one (this allows for rudimentary message relaying).
		//Using setter, this value can only be set once so messages received cannot be used
		//as replies or relays -- new instances must be created.
		private var _sourcePeerIDs:String = null;
		//One ore more hyphen-delimited target peer IDs. Messages will be sent to targets in the order
		//specified. The wildcard "*" targets all connected peers.
		//Using setter, this value can only be set once so messages received cannot be used
		//as replies or relays -- new instances must be created.
		private var _targetPeerIDs:String = null;
		//Vector of double-precision IEEE-754 values (largest integer that ActionScript supports).
		//This will hold int.MAX_VALUE number of records (maximum Vector size).
		private static var _indexes:Vector.<Number> = new <Number>[new Number(0)];		
		private var _timeStamp:String = null;
		private var _timestampReceived:String = null;
		private var _timestampGenerated:String = null;
		private var _timestampSent:String = null;
		private var _data:*= null;
		private var _dataType:String = null;
		internal var _updatedForRelay:Boolean = false;
		
		/**
		 * Creates an instance of a PeerMessage.
		 * 
		 * @param	incomingMessage An optional incoming peer message. If supplied, this PeerMessage
		 * instance will be instantiated as an incoming message (unless the supplied data is invalid).
		 * If not supplied or null, the PeerMessage instance is instantiated as on outgoing message.		 
		 */
		public function PeerMessage(incomingMessage:*= null) 
		{			
			if (incomingMessage != null) {
				_timestampReceived = generateTimestamp();
				processIncomingMessage(incomingMessage);
			} else {
				_timestampGenerated = generateTimestamp();
			}			
			_indexes[0]++;			
			if (_indexes[0] < 0) {
				//doesn't really matter where this value goes-they're all the same
				_indexes.push(Number.MAX_VALUE); 
				_indexes[0] = 0;
			}
			super();
		}
			
		/**
		 * The timestamp of the message set as it was received from the sending peer. Default value is null.
		 */
		public function get timestampReceived():String 
		{
			return (_timestampReceived);
		}
		
		public function set timestampReceived(stampSet:String):void 
		{			
			_timestampReceived = stampSet;
		}
		
		public function get timestampGenerated():String 
		{
			return (_timestampGenerated);	
		}
		
		public function set timestampGenerated(stampSet:String):void 
		{
			_timestampGenerated = stampSet;			
		}
		
		/**
		 * The timestamp of the message set as it was sent from us. Default value is null.
		 */
		public function get timestampSent():String 
		{
			return (_timestampSent);
		}
		
		public function set timestampSent(stampSet:String):void 
		{
			_timestampSent = stampSet;		
		}
		
		/**
		 * The data associated with the peer message. Automatically assigns the dataType property when set.
		 */
		public function set data (dataSet:*):void 
		{
			_data = dataSet;
			if (data is String) {
				_dataType = "string";
			} else if (data is XML) {
				_dataType = "xml";
			} else if (data is XMLList) {
				_dataType = "xmllist";				
			} else if (data is Number) {
				_dataType = "number";
			} else if (data is uint) {
				_dataType = "uint";
			} else if (data is int) {
				_dataType = "int";
			} else if (data is Boolean) {
				_dataType = "boolean";
			} else if (data is ByteArray) {
				_dataType = "bytearray";
			} else if (data is Array) {
				_dataType = "array";
			} else if (data is Object) {
				_dataType = "object";
			} else {
				_data = null;
				_dataType = null;
			}
		}
		
		public function get data():* 
		{
			return (_data);
		}
		
		/**
		 * The data type of the associated data property. Valid types are:
		 * "string", "xml", "xmllist", "number", "uint", "int", "boolean", "bytearray", "array", or "object".
		 * If the data type can't be determined null is returned.
		 * 
		 */
		public function get dataType():String 
		{
			return (_dataType);
		}
				
		/**
		 * Checks the validity of the message instance -- any number of values may have been set or set incorrectly
		 * (especially by incoming messages), so it's often a good idea to run this front-line analysis prior to
		 * taking further actions.
		 * 
		 * @return True if the current instance appears valid, false otherwise.
		 */
		public function get isValid():Boolean 
		{			
			if (timestampGenerated == null) { 				
				//no generated time stamp (done at instantiation so this shouldn't ever happen)			
				return (false);
			}
			if ((timestampReceived != null) && ((timestampSent == null) || (timestampSent == ""))) {								
				//received but not sent
				return (false);
			}
			if (((timestampReceived == null) || (timestampReceived == "")) && (timestampSent != null)) {								
				//sent but not received
				return (false);
			}
			if ((timestampReceived != null) && (timestampSent != null) &&
				((sourcePeerIDs == "") || (sourcePeerIDs == null))) {						
				//received with no source peer ID
				return (false);
			}			
			if (dataType == "") {
				//invalid data type
				return (false);
			}
			if ((data != null) && (dataType == null)) {
				//unrecognized data...
				return (false);
			}
			if ((dataType != null) && (data == null)) {
				//data type set but no data
				return (false);
			}
			if ((timestampReceived != null) && (timestampSent != null) &&
				((targetPeerIDs == "") || (targetPeerIDs == null))) {
				//broadcast to all peers
				return (true);
			}
			return (true);
		}
		
		/**
		 * Sets the timestampSent value. This method can only be called once, so it should
		 * be called just before the message is sent.
		 * 
		 * @return True if the timestampSent value could be set, false if it has already been set.
		 */
		public function setSentTimestamp():Boolean 
		{
			if (_timestampSent == null) {
				_timestampSent = generateTimestamp();
				return (true);
			}
			return (false);
		}
		
		/**
		 * Clones this instance and returns a new copy.
		 * 
		 * @return A new PeerMessage instance 
		 */
		public function clone():IPeerMessage 
		{
			var cloneMsg:PeerMessage = new PeerMessage();
			cloneMsg.sourcePeerIDs = sourcePeerIDs;
			cloneMsg.targetPeerIDs = targetPeerIDs;
			cloneMsg.data = data;
			return (cloneMsg);
		}		
		
		/**
		 * Updates the source and target lists for relay so that the current target peer becomes the current
		 * source peer. This function will only apply an update once to prevent skipping a hop in a relay.
		 */
		public function updateSourceTargetForRelay():void 
		{
			try {
				if (_updatedForRelay) {
					//prevents accidentally updating more than one relay hop				
					return;
				}
				_updatedForRelay = true;
				var	sources:Vector.<INetCliqueMember> = getSourcePeerIDList(NetCliqueMember);
				if (sources == null) {
					sources = new Vector.<INetCliqueMember>();
				}
				var	targets:Vector.<INetCliqueMember> = getTargetPeerIDList(NetCliqueMember);				
				if (targets == null) {
					targets = new Vector.<INetCliqueMember>();
				}
				if ((sources == null) && (targets == null)) {
					return;
				}
				sources.unshift(targets.shift());
				if (sources.length>0) {
					_sourcePeerIDs = sources[0].peerID;
					for (var count:uint = 1; count < sources.length; count++) {
						_sourcePeerIDs+=defaultPeerIDDelimiter+sources[count].peerID;
					}
				} else {
					_sourcePeerIDs = "";
				}
				if (targets.length>0) {
					_targetPeerIDs = targets[0].peerID;
					for (count = 1; count < targets.length; count++) {
						_targetPeerIDs+=defaultPeerIDDelimiter+targets[count].peerID;
					}
				} else {
					_targetPeerIDs = "*";
				}
			} catch (err:*) {	
				trace (err);
			}
		}
		
		/**
		 * Serialize the message and associated data to a JSON string.
		 * 
		 * @param	finalize If true, the message is also timestamped (if not already) for sending.
		 * 
		 * @return The JSON representation of the message and associated data.
		 */
		public function serializeToJSON(finalize:Boolean = false):String 
		{
			if (finalize) {
				setSentTimestamp();				
			}
			var jsonObj:Object = new Object();
			if (timestampGenerated!=null) {
				jsonObj.timestampGenerated = timestampGenerated;
			} else {
				jsonObj.timestampGenerated = "error";
			}
			if (timestampSent!=null) {
				jsonObj.timestampSent = timestampSent;
			} else {
				jsonObj.timestampSent = "";
			}
			if (timestampReceived!=null) {
				jsonObj.timestampReceived = timestampReceived;
			} else {
				jsonObj.timestampReceived = "";
			}			
			if (sourcePeerIDs!=null) {
				jsonObj.sourcePeerIDs = sourcePeerIDs;
			} else {
				jsonObj.sourcePeerIDs = "";
			}
			if (targetPeerIDs!=null) {
				jsonObj.targetPeerIDs = targetPeerIDs;
			} else {
				jsonObj.targetPeerIDs = "";
			}			
			if ((dataType != null) && (data!=null)) {
				jsonObj.nativeStruct = new Object();
				jsonObj.nativeStruct.type = dataType;			
				jsonObj.nativeStruct.data = dataString;
			}
			return (JSON.stringify(jsonObj));
		}
		
		/**
		 * Serialize the message and associated data to a XML document.
		 * 
		 * @param	finalize If true, the message is also timestamped (if not already), for sending.
		 * 
		 * @return The JSON representation of the message and associated data.
		 */
		public function serializeToXML(finalize:Boolean = false):XML 
		{
			if (finalize) {
				setSentTimestamp();				
			}
			var xmlObj:XML = new XML(serialXMLMsgStruct.toXMLString());	
			if (timestampGenerated!=null) {
				xmlObj.@timestampGenerated = timestampGenerated;
			} else {
				xmlObj.@timestampGenerated = "error";
			}
			if (timestampSent!=null) {
				xmlObj.@timestampSent = timestampSent;	
			} else {
				xmlObj.@timestampSent = "";	
			}
			if (timestampReceived!=null) {
				xmlObj.@timestampReceived = timestampReceived;
			} else {
				xmlObj.@timestampReceived = "";
			}
			if (sourcePeerIDs!=null) {
				xmlObj.@sourcePeerIDs = sourcePeerIDs;	
			} else {
				xmlObj.@sourcePeerIDs = "";	
			}
			if (targetPeerIDs!=null) {
				xmlObj.@targetPeerIDs = targetPeerIDs;	
			} else {
				xmlObj.@targetPeerIDs = "";	
			}
			if ((dataType != null) && (data!=null)) {
				xmlObj.nativeStruct.@type = dataType;			
				xmlObj.nativeStruct.appendChild(dataString);
			}
			return (xmlObj);
		}
		
		/**
		 * Serialize the message and associated data to AMF3 binary data.
		 * 
		 * @param	finalize If true, the message is also timestamped (if not already), for sending.
		 * 
		 * @return The AMF3 representation of the message and associated data.
		 */
		public function serializeToAMF3(finalize:Boolean = false):ByteArray 
		{
			if (finalize) {
				setSentTimestamp();				
			}
			var amfObj:Object = new Object();
			if (timestampGenerated!=null) {
				amfObj.timestampGenerated = timestampGenerated;
			} else {
				amfObj.timestampGenerated = "error";
			}
			if (timestampSent!=null) {
				amfObj.timestampSent = timestampSent;
			} else {
				amfObj.timestampSent = "";
			}
			if (timestampReceived!=null) {
				amfObj.timestampReceived = timestampReceived;
			} else {
				amfObj.timestampReceived = "";
			}
			if (sourcePeerIDs!=null) {
				amfObj.sourcePeerIDs = sourcePeerIDs;	
			} else {
				amfObj.sourcePeerIDs = "";
			}
			if (targetPeerIDs!=null) {
				amfObj.targetPeerIDs = targetPeerIDs;	
			} else {
				amfObj.targetPeerIDs = "";
			}
			if ((dataType != null) && (data!=null)) {
				amfObj.nativeStruct = new Object();
				amfObj.nativeStruct.type = dataType;
				amfObj.nativeStruct.data = data;
			}		
			ByteArray.defaultObjectEncoding = ObjectEncoding.AMF3;			
			var ba:ByteArray = new ByteArray();
			ba.writeObject(amfObj);
			ba.position = 0;
			return (ba);
		}
		
		/**
		 * Serialize the message and associated data to AMF0 binary data.
		 * 
		 * @param	finalize If true, the message is also timestamped (if not already), for sending.
		 * 
		 * @return The AMF0 representation of the message and associated data.
		 */
		public function serializeToAMF0(finalize:Boolean = false):ByteArray 
		{
			if (finalize) {
				setSentTimestamp();				
			}
			var amfObj:Object = new Object();
			if (timestampGenerated!=null) {
				amfObj.timestampGenerated = timestampGenerated;
			} else {
				amfObj.timestampGenerated = "error";
			}
			if (timestampSent!=null) {
				amfObj.timestampSent = timestampSent;
			} else {
				amfObj.timestampSent = "";
			}
			if (timestampReceived!=null) {
				amfObj.timestampReceived = timestampReceived;
			} else {
				amfObj.timestampReceived = "";
			}
			if (sourcePeerIDs!=null) {
				amfObj.sourcePeerIDs = sourcePeerIDs;	
			} else {
				amfObj.sourcePeerIDs = "";
			}
			if (targetPeerIDs!=null) {
				amfObj.targetPeerIDs = targetPeerIDs;	
			} else {
				amfObj.targetPeerIDs = "";
			}
			if ((dataType != null) && (data!=null)) {
				amfObj.nativeStruct = new Object();
				amfObj.nativeStruct.type = dataType;
				amfObj.nativeStruct.data = data;
			}
			ByteArray.defaultObjectEncoding = ObjectEncoding.AMF0;			
			var ba:ByteArray = new ByteArray();
			ba.writeObject(amfObj);
			ba.position = 0;
			return (ba);
		}
		
		/**
		 * The target peer ID(s) for the peer message.
		 * 
		 * Although it is handled by the PeerMessageHandler implementation, generally setting this value to "*"
		 * targets all connected peers.
		 * 
		 * Each peer in the list is delimited in the order in which peers are to be sequentially targeted.
		 */
		public function set targetPeerIDs(idSet:String):void 
		{
			_targetPeerIDs = idSet;
		}
		
		public function get targetPeerIDs():String 
		{
			return (_targetPeerIDs);
		}		
		
		/**
		 * Adds a target peer ID to the target peer ID list if it's unique. The new peer is added at the beginning
		 * of the list (next).
		 * 
		 * @param	newPeerID The unique target peer ID to add to the target peer ID list.
		 */
		public function addTargetPeerID(newPeerID:String):void 
		{
			if ((newPeerID == null) || (newPeerID == "")) {
				return;
			}
			if (hasTargetPeerID(newPeerID)) {
				return;
			}
			var targetList:Vector.<INetCliqueMember> = getTargetPeerIDList(NetCliqueMember, defaultPeerIDDelimiter);
			if (targetList == null) {
				targetPeerIDs = newPeerID;
				return;
			} else if (targetList.length == 0) {
				targetPeerIDs = newPeerID;
			} else {
				targetPeerIDs = newPeerID + defaultPeerIDDelimiter + targetPeerIDs;				
			}
		}
		
		/**
		 * Adds a source peer ID to the source peer ID list if it's unique. The new peer is added at the beginning
		 * of the list (next).
		 * 
		 * @param	sourcePeerID The unique source peer ID to add to the source peer ID list.
		 */
		public function addSourcePeerID(sourcePeerID:String):void 
		{
			if ((sourcePeerID == null) || (sourcePeerID == "")) {
				return;
			}
			if (hasSourcePeerID(sourcePeerID)) {
				return;
			}
			var sourceList:Vector.<INetCliqueMember> = getSourcePeerIDList(NetCliqueMember, defaultPeerIDDelimiter);
			if (sourceList == null) {
				sourcePeerIDs = sourcePeerID;
				return;
			} else if (sourceList.length == 0) {
				sourcePeerIDs = sourcePeerID;
			} else {
				sourcePeerIDs = sourcePeerID + defaultPeerIDDelimiter + sourcePeerIDs;
			}
		}
		
		/**
		 * Sets the target peer ID list from a supplied Vector array of INetCliqueMember implementations.
		 * 
		 * @param	peerIDList Vector array of INetCliqueMember implementations to parse to the targetPeerIDs list.
		 */
		public function setTargetPeerIDs(peerIDList:Vector.<INetCliqueMember>):void 
		{
			if (peerIDList == null) {
				return;
			}
			_targetPeerIDs = new String();
			for (var count:uint = 0; count < peerIDList.length; count++) {
				_targetPeerIDs += peerIDList[count].peerID + defaultPeerIDDelimiter;
			}
			_targetPeerIDs = _targetPeerIDs.substr(0, _targetPeerIDs.length - 1);			
		}
		
		/**
		 * Sets the source peer ID list from a supplied Vector array of INetCliqueMember implementations.
		 * 
		 * @param	peerIDList Vector array of INetCliqueMember implementations to parse to the sourcePeerIDs list.
		 */
		public function setSourcePeerIDs(peerIDList:Vector.<INetCliqueMember>):void 
		{
			if (peerIDList == null) {
				return;
			}
			_sourcePeerIDs = new String();
			for (var count:uint = 0; count < peerIDList.length; count++) {
				_sourcePeerIDs += peerIDList[count].peerID + defaultPeerIDDelimiter;
			}
			_sourcePeerIDs = _sourcePeerIDs.substr(0, _sourcePeerIDs.length - 1);			
		}		
		
		/**
		 * A list of target peer IDs based on the targetPeerIDs and separated by a delimiter.
		 * 		 
		 * @param NetCliqueMember_i A NetCliqueMember imlementation type to return in the return vector array.
		 * @param delimiter The delimiter, or separator, between successive peer IDs. Obviously this
		 * value must never be present in the peer IDs themselves. Default is defaultPeerIDDelimiter.
		 * 
		 * A vector array of NetCliqueMember_i-type objects (classes that implement INetCliqueMember) containing the 
		 * split peer IDs from the current targetPeerIDs value, or null if the request can't be fulfilled.
		 */
		public function getTargetPeerIDList(NetCliqueMember_i:Class = null, delimiter:String = defaultPeerIDDelimiter):Vector.<INetCliqueMember> 
		{
			if (targetPeerIDs == null) {
				return (null);
			}
			if (targetPeerIDs.length == 0) {
				return (null);
			}
			if (NetCliqueMember_i == null) {
				NetCliqueMember_i = NetCliqueMember;
			}
			var peerList:Array = targetPeerIDs.split(delimiter);
			var returnVec:Vector.<INetCliqueMember> = new Vector.<INetCliqueMember>();
			for (var count:uint = 0; count < peerList.length; count++) {
				var currentPeer:String = peerList[count] as String;
				var newMember:INetCliqueMember = new NetCliqueMember_i();
				newMember.peerID = currentPeer;
				returnVec.push(newMember);
			}
			return (returnVec);
		}		
		
		/**
		 * Checks the PeerMessage's target peer ID list for an occurance of the supplied peer ID.
		 * 
		 * @param	peerID The single peer ID to search for.
		 * @param   caseSensitive If true, a case-sensitive search is done, otherwise the search
		 * is case-insensitive. Not useful for all peer IDs -- for example, those employing IP addresses
		 * which contain no alpha characters (so parameter is ignored).
		 * 
		 * @return True if the single peer ID appears in the list of target peer IDs, false otherwise.
		 */
		public function hasTargetPeerID(peerID:String, caseSensitive:Boolean = false):Boolean 
		{
			var peerList:Vector.<INetCliqueMember> = getTargetPeerIDList(NetCliqueMember);
			if (peerList == null) {
				return (false);
			}
			if (peerList.length == 0) {
				return (false);
			}
			var findPeerID:String = new String(peerID);
			if (!caseSensitive) {
				findPeerID = findPeerID.toLowerCase();
			}
			for (var count:uint = 0; count < peerList.length; count++) {
				var currentID:INetCliqueMember = peerList[count];
				var cIDStr:String = currentID.peerID;
				if (!caseSensitive) {
					cIDStr = cIDStr.toLowerCase();
				}
				if ((cIDStr == findPeerID) || (cIDStr=="*")) {
					return (true);
				}
			}
			return (false);
		}
		
		/**
		 * Checks if the specified peer ID is the next in the list of target IDs for 
		 * this peer message instance.
		 * 
		 * @param	peerID The peer ID to check for position.
		 * @param	caseSensitive True to conduct a case-sensitive peer ID search.
		 * 
		 * @return True if the peer ID specified is next in the list of the target IDs of this message.
		 */
		public function isNextTargetID(peerID:String, caseSensitive:Boolean = false):Boolean 
		{
			var peerList:Vector.<INetCliqueMember> = getTargetPeerIDList(NetCliqueMember);			
			if (peerList == null) {
				return (false);
			}
			if (peerList.length == 0) {
				return (false);
			}
			var targetPeerID:String = new String(peerID);
			if (!caseSensitive) {
				targetPeerID = targetPeerID.toLowerCase();
			}
			try {
				var firstPeerID:INetCliqueMember = peerList[0];
				var fpIDStr:String = firstPeerID.peerID;				
				if (!caseSensitive) {
					fpIDStr = fpIDStr.toLowerCase();
				}
				if (fpIDStr == targetPeerID) {
					return (true);
				}
			} catch (err:*) {
				return (false);
			}
			return (false);
		}
		
		/**
		 * The source peer ID(s) of the peer message. 
		 * 
		 * Although the implementation may differ, generally peers will add their peer ID to this list such that the most
		 * recent peer appears at the beginning. This can also be used as a rudimentary network trace.
		 */
		public function set sourcePeerIDs(idSet:String):void 
		{			
			_sourcePeerIDs = idSet;			
		}
		
		public function get sourcePeerIDs():String 
		{		
			return (_sourcePeerIDs);
		}
		
		/**
		 * A list of source peer IDs, based on the sourcePeerIDs, and separated by a delimiter.
		 * 
		 * @param NetCliqueMember_i A NetCliqueMember imlementation type to return in the
		 * return vector array.
		 * @param delimiter The delimiter, or separator, between successive peer IDs. Obviously this
		 * value must never be present in the peer IDs themselves. Default is defaultPeerIDDelimiter.
		 * 
		 * A vector array of NetCliqueMember_i-type objects (classes that implement INetCliqueMember) containing the 
		 * split peer IDs from the current targetPeerIDs value, or null if the request can't be fulfilled.
		 */
		public function getSourcePeerIDList(NetCliqueMember_i:Class = null, delimiter:String = defaultPeerIDDelimiter):Vector.<INetCliqueMember> 
		{			
			if (sourcePeerIDs == null) {				
				return (null);
			}
			if (sourcePeerIDs.length == 0) {				
				return (null);
			}
			if (NetCliqueMember_i == null) {
				NetCliqueMember_i = NetCliqueMember;
			}
			var peerList:Array = sourcePeerIDs.split(delimiter);
			var returnVec:Vector.<INetCliqueMember> = new Vector.<INetCliqueMember>();			
			for (var count:uint = 0; count < peerList.length; count++) {
				var currentPeer:String = peerList[count] as String;							
				var newMember:INetCliqueMember = new NetCliqueMember_i();
				newMember.peerID = currentPeer;
				returnVec.push(newMember);
			}
			return (returnVec);
		}
		
		/**
		 * Checks the PeerMessage's source peer ID list for an occurance of the supplied peer ID.
		 * 
		 * @param	peerID The single peer ID to search for.
		 * @param   caseSensitive If true, a case-sensitive search is done, otherwise the search
		 * is case-insensitive. Not useful for all peer IDs -- for example, those employing IP addresses
		 * which contain no alpha characters (so parameter is ignored).
		 * 
		 * @return True if the single peer ID appears in the list of source peer IDs, false otherwise.
		 */
		public function hasSourcePeerID(peerID:String, caseSensitive:Boolean = false):Boolean 
		{
			var peerList:Vector.<INetCliqueMember> = getSourcePeerIDList(NetCliqueMember);
			if (peerList == null) {
				return (false);
			}
			if (peerList.length == 0) {
				return (false);
			}
			var findPeerID:String = new String(peerID);
			if (!caseSensitive) {
				findPeerID = findPeerID.toLowerCase();
			}
			for (var count:uint = 0; count < peerList.length; count++) {
				var currentID:INetCliqueMember = peerList[count];
				var idStr:String = currentID.peerID;
				if (!caseSensitive) {
					idStr = idStr.toLowerCase();
				}
				if ((idStr == findPeerID) || (idStr=="*")) {
					return (true);
				}
			}
			return (false);
		}
		
		/**
		 * Checks if a specified peer ID is the next (latest) source ID in the source ID list.
		 * 
		 * @param	peerID The peer ID to check.
		 * @param	caseSensitive True if a case senseitive search should be done.
		 * 
		 * @return True if the peerID parameter is the next (latest) source ID, false otherwise.
		 */
		public function isNextSourceID(peerID:String, caseSensitive:Boolean = false):Boolean 
		{
			var peerList:Vector.<INetCliqueMember> = getSourcePeerIDList(NetCliqueMember);
			if (peerList == null) {
				return (false);
			}
			if (peerList.length == 0) {
				return (false);
			}
			var sourcePeerID:String = new String(peerID);
			if (!caseSensitive) {
				sourcePeerID = sourcePeerID.toLowerCase();
			}
			try {
				var firstPeerID:INetCliqueMember = peerList[0];
				var fpIDStr:String = firstPeerID.peerID;
				if (!caseSensitive) {
					fpIDStr = fpIDStr.toLowerCase();
				}
				if (fpIDStr == sourcePeerID) {
					return (true);
				}
			} catch (err:*) {
				return (false);
			}
			return (false);
		}
		
		/*
		 * Generate a unique UTC-date-time-based indexed timestamp.
		 * 
		 * @param includeIndex If true include an incrementing index value at the end of the timestamp. This value is
		 * incremented every time any PeerMessage instance calls this function.
		 * 
		 * @return All values are "0" padded: year (4-digit), month (2-digit), day (2-digit), hours (2-digit), 
		 * minutes (2-digit), seconds (2-digit), milliseconds (3-digit) + [optional incrementing index value]
		 * 
		 * Each new instance increments current _indexes[0] value until it reaches Number.MAX_VALUE at which
		 * point the number is shifted into the _indexes array and a new Number instance is inserted at the beggining.
		 * This part happens in the constructor.
		 * 
		 */
		public function generateTimestamp(includeIndex:Boolean = true):String 
		{
			var dateObj:Date = new Date();
			var ts:String = new String();
			ts += String(dateObj.getUTCFullYear())
			if ((dateObj.getUTCMonth()+1) <= 9) {
				ts += "0";
			}
			ts += String((dateObj.getUTCMonth()+1));
			if ((dateObj.getUTCDate()) <= 9) {
				ts += "0";
			}
			ts += String(dateObj.getUTCDate());
			if (dateObj.getUTCHours() <= 9) {
				ts += "0";
			}
			ts += String(dateObj.getUTCHours());
			if (dateObj.getUTCMinutes() <= 9) {
				ts += "0";
			}
			ts += String(dateObj.getUTCMinutes());
			if (dateObj.getUTCSeconds() <= 9) {
				ts += "0";
			}
			ts += String(dateObj.getUTCSeconds());
			if (dateObj.getUTCMilliseconds() <= 9) {
				ts += "0";
			}
			if (dateObj.getUTCMilliseconds() <= 99) {
				ts += "0";
			}
			ts += String(dateObj.getUTCMilliseconds());
			if (includeIndex) { 
				//this will accomodate 2147483647 * 1.79^308 messages.
				//script will probably time out before this collated index value can be generated.
				for (var count:int =  (_indexes.length-1); count >=0 ; count--) {
					var currentIndex:Number = _indexes[count];
					ts += String(currentIndex);
				}
				//at this point we've reached the maximum number of messages so reset.
				//if we want to limit the number of indexes in the aboves loop we can set that value here.
				if (_indexes.length == int.MAX_VALUE) {
					_indexes = new <Number>[new Number(0)];		
				}
			}
			return (ts);
		}
		
		/**
		 * Returns a deeply-recursive string representation of the peer message object (useful for
		 * messages with unknown or unrecognized formats).
		 * 
		 * @return A deeply-recursive string representation of the peer message instance.
		 */
		public function toString():String 
		{
			var returnStr:String = new String();			
			returnStr = getQualifiedClassName(this) + ":\n";
			returnStr = returnStr.split("::").join(".");
			returnStr += recurseObjectToString(this, 1);			
			return (returnStr);
		}
		
		/**
		 * Parses an incoming message, usually from another peer.
		 * 
		 * @param	message The incoming message to parse. Strings are parsed as JSON objects and XML, ByteArray, 
		 * and Object types are parsed natively.
		 */
		private function processIncomingMessage(message:*):void 
		{			
			if (message is String) {				
				//try xml detection here?				
				var msgObj:Object = JSON.parse(message);				
				processIncomingMsgObj(msgObj);
			} else if (message is XML) {					
				processIncomingMsgXML(message);
			} else if (message is ByteArray) {				
				processIncomingMsgBA(message);				
			} else if (message is Object) {						
				processIncomingMsgObj(message);
			} else {				
			}
		}
		
		/**
		 * Processes an incoming peer message as a ByteArray object. The ByteArray is assumed to be an AMF3-encoded
		 * object containing the public properties of a PeerMessage object.
		 * 
		 * @param	msgObj AMF3-encoded ByteArray containing the incoming PeerMessage properties to process.
		 */
		private function processIncomingMsgBA(msgObj:ByteArray):void 
		{			
			_timestampReceived = generateTimestamp(true);
			//assume AMF3 object encoding for ..
			ByteArray.defaultObjectEncoding = ObjectEncoding.AMF3;
			var dsMsgOvj:Object = msgObj.readObject();		
			try {
				_timestampSent = dsMsgOvj.timestampSent;
			} catch (err:*) {
				_timestampSent = null;
			}
			try {
				_timestampGenerated = dsMsgOvj.timestampGenerated;
			} catch (err:*) {
				_timestampGenerated = null;
			}
			try {
				_sourcePeerIDs = dsMsgOvj.sourcePeerIDs;
			} catch (err:*) {
				_sourcePeerIDs = null;
			}
			try {
				_targetPeerIDs = dsMsgOvj.targetPeerIDs;
			} catch (err:*) {
				_targetPeerIDs = null;
			}
			try {				
				processIncomingData(dsMsgOvj.nativeStruct);
			} catch (err:*) {
				_data = null;
			}
		}
		
		/**
		 * Processes an incoming peer message as a native Object. 
		 *
		 * @param	msgObj Native Object containing the incoming PeerMessage properties to process.
		 */
		private function processIncomingMsgObj(msgObj:Object):void 
		{			
			try {
				_timestampSent = msgObj.timestampSent;
			} catch (err:*) {				
				_timestampSent = null;
			}
			try {
				_timestampGenerated = msgObj.timestampGenerated;
			} catch (err:*) {				
				_timestampGenerated = null;
			}
			try {
				_sourcePeerIDs = msgObj.sourcePeerIDs;
			} catch (err:*) {				
				_sourcePeerIDs = null;
			}
			try {
				_targetPeerIDs = msgObj.targetPeerIDs;
			} catch (err:*) {				
				_targetPeerIDs = null;
			}
			try {				
				processIncomingData(msgObj.nativeStruct);
			} catch (err:*) {				
				_data = null;
			}
		}
		
		/**
		 * Processes an incoming peer message as a native XML object. 
		 *
		 * @param	msgObj Native XML object containing the incoming PeerMessage properties to process. 
		 * See serialXMLMsgStruct for basic structure.
		 */
		private function processIncomingMsgXML(msgXML:XML):void 
		{
			if (msgXML == null) {
				return;
			}			
			try {
				_timestampSent = msgXML.@timestampSent;
			} catch (err:*) {
				_timestampSent = null;
			}
			try {
				_timestampGenerated = msgXML.@timestampGenerated;
			} catch (err:*) {
				_timestampGenerated = null;
			}
			try {
				_sourcePeerIDs = String(msgXML.@sourcePeerIDs);
			} catch (err:*) {
				_sourcePeerIDs = null;
			}
			try {
				_targetPeerIDs = String(msgXML.@targetPeerIDs);
			} catch (err:*) {
				_targetPeerIDs = null;
			}
			try {				
				processIncomingData(msgXML.nativeStruct[0]);
			} catch (err:*) {
				_data = null;
			}
		}
		
		/**
		 * Processes an incoming peer message's native data structure. 
		 *
		 * @param	dataItem A valid data payload from any incoming message processor (ByteArray, Object, XML).
		 */
		private function processIncomingData(dataItem:*):void 
		{			
			if ((dataItem == null) || (dataItem == undefined)) {
				return;
			}
			if (dataItem is XML) {				
				if ((dataItem.@type == null) || (dataItem.@type == "") || (dataItem.@type == undefined)) {
					return;
				}
				var typeVal:String = new String(dataItem.@type);				
				var dataObj:*= dataItem.children().toString();				
			} else {
				if ((dataItem.type == null) || (dataItem.type == "") || (dataItem.type == undefined)) {
					return;
				}
				typeVal = new String(dataItem.type);
				dataObj = dataItem.data;
			}
			typeVal = typeVal.toLowerCase();			
			try {
				switch (typeVal) {					
					case "string":						
						_data = new String(dataObj);
						_dataType = "string";
						break;
					case "number":
						_data = new Number(String(dataObj));
						_dataType = "number";
						break;
					case "uint":
						_data = new uint(String(dataObj));
						_dataType = "uint";
						break;
					case "int":
						_data = new int(String(dataObj));
						_dataType = "int";
						break;
					case "boolean":
						_data = new Boolean(Number(String(dataObj)));
						_dataType = "boolean";
						break;
					case "xml":
						_data = new XML(String(dataObj));
						_dataType = "xml";
						break;
					case "xmllist":
						var xmlObject:XML=new XML("<data>"+String(dataObj)+"</data>");
						_data = xmlObject.children();
						_dataType = "xmllist";
						break;
					case "bytearray":
						ByteArray.defaultObjectEncoding = ObjectEncoding.AMF3;
						_data = Base64.decodeToByteArray(String(dataObj));
						_dataType = "bytearray";
						break;
					case "array":
						var ba:ByteArray = Base64.decodeToByteArray(String(dataObj));
						ba.position = 0;
						ba.uncompress(CompressionAlgorithm.ZLIB);
						ba.position = 0;
						_data = ba.readObject();
						_dataType = "array";
						break;
					case "object":						
						_data = dataObj;
						_dataType = "object";
						break;
					default:
						_data = null;
						_dataType = null;
						break;
				}
			} catch (err:*) {
				_data = null;
				_dataType = null;
			}
		}
		
		/**
		 * The current data property as a string or null if not set.
		 * If dataType is "string" the data is returned unchanged.
		 * If dataType is "uint", "int", or "number" the data is returned as a radix 10 numeric string.
		 * If dataType is "xml" or "xmllist" the data is returned as the output of toXMLString().
		 * If dataType is "boolean" the string "1" is returned for true and "0" is returned for false.
		 * If dataType is "array" the data is returned as a native ZLIB-compressed object encoded as a Base64 string.
		 * If dataType is "bytearray" the data is returned as a native AMF3-encoded object encoded as a Base64 string.
		 * If dataType is "object" the data is returned as a ZLIB-compressed object encoded as a Base64 string.		 
		 */
		protected function get dataString():String 
		{
			if (dataType == null) {
				return (null);
			}
			if (dataType == "string") {
				return (data);
			}
			if ((dataType == "uint") || (dataType == "int") || (dataType == "number")) {
				return (data.toString(10)); //radix 16 would make this more compact
			}
			if ((dataType == "xml") || (dataType == "xmllist")) {
				return (data.toXMLString());
			}
			if (dataType == "boolean") {
				if (data) {
					return ("1");
				}
				return ("0");				
			}
			if (dataType == "array") {		
				var ba:ByteArray = new ByteArray();
				ba.writeObject(data);
				ba.compress(CompressionAlgorithm.ZLIB);				
				return (Base64.encodeByteArray(ba));
			}
			if (dataType == "bytearray") {		
				ByteArray.defaultObjectEncoding = ObjectEncoding.AMF3;
				return (Base64.encodeByteArray(data));
			}
			if (dataType == "object") {
				ba = new ByteArray();
				ba.writeObject(data);
				ba.compress(CompressionAlgorithm.ZLIB);				
				return (Base64.encodeByteArray(ba));
			}
			return (null);
		}
		
		/**
		 * Recurses a native object to a trace string.
		 * 
		 * @param	currentObj The object to recurse.
		 * @param	currentLevel An internal recursion level index - do not set.
		 * 
		 * @return The object recursed to a trace string.
		 */
		private function recurseObjectToString(currentObj:*, currentLevel:int = 0):String 
		{
			if (currentObj == null) {
				return("");
			}
			var currentObjString:String = new String();
			var indent:String = new String();
			for (var count:int = 0; count < currentLevel; count++) {
				indent += "  ";
			}
			var typeXML:XML = describeType(currentObj);
			var accessorList:XMLList = typeXML.accessor as XMLList;			
			for (count = 0; count < accessorList.length(); count++ ) {
				var currentAcc:XML = accessorList[count] as XML;				
				var accName:String = new String(currentAcc.attribute("name")[0]);
				var accType:String = new String(currentAcc.attribute("type")[0]);
				var accAccess:String = new String(currentAcc.attribute("access")[0]);				
				if ((typeof(currentObj[accName])=="object") || (accType=="*")) {
					try {						
						var tmp:String=recurseObjectToString(currentObj[accName], (currentLevel + 1));
						currentObjString += indent + "\"" + accName + "\" (" + accType + "/" + accAccess + "): " + currentObj[accName].toString() + "\n";
						currentObjString += tmp;
					} catch (err:*) {					
						currentObjString += indent + ">>> \"" + accName + "\" (" + accType + "/" + accAccess + ")=" + currentObj[accName] + "\n";	
					}
				} else {
					currentObjString += indent + "\"" + accName + "\" (" + accType + "/" + accAccess + ")=" + currentObj[accName] + "\n";
				}
			}
			return (currentObjString);
		}				
		
	}
	
}
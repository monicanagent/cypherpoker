/**
* Interface for a PeerMessage implementation.
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.interfaces 
{
			
	import flash.utils.ByteArray;
	import p2p3.interfaces.INetCliqueMember;
	
	public interface IPeerMessage 
	{		
		
		//The native data associated with the message.
		function set data(dataSet:*):void
		function get data():*;
		//Delimited list of source peer IDs - IDs that have sent, forwarded, or processed the message.
		function set sourcePeerIDs(idSet:String):void;
		function get sourcePeerIDs():String;
		//Delimited list of target peer IDs. The first ID is the first (current) target for the message.
		function set targetPeerIDs(idSet:String):void;
		function get targetPeerIDs():String;
		//Local timestamp of message when it was received.
		function get timestampReceived():String;
		function set timestampReceived(stampSet:String):void;
		//Local timestamp of message when it was generated.
		function get timestampGenerated():String;
		function set timestampGenerated(stampSet:String):void;
		//Local timestamp of message when it was sent.
		function get timestampSent():String;
		function set timestampSent(stampSet:String):void;
		//Generate a unique timestamp including an optional index.
		function generateTimestamp(includeIndex:Boolean = true):String;
		//Do the contents of the implemented instance appear valid?		
		function get isValid():Boolean;
		//Clone or copy the current IPeerMessage implementation. The original instance remains unchanged.
		function clone():IPeerMessage;
		//Add a peer ID to the target list.		
		function addTargetPeerID(newPeerID:String):void;
		//Set the list of target peer IDs.
		function setTargetPeerIDs(peerIDList:Vector.<INetCliqueMember>):void;
		//Retrieves the current target peer IDs as a list of INetCliqueMember implementations.
		function getTargetPeerIDList(INetCliqueMember_implementation:Class = null, delimiter:String = "-"):Vector.<INetCliqueMember>;
		//Checks for the existence of a target peer ID.
		function hasTargetPeerID(peerID:String, caseSensitive:Boolean = false):Boolean;		
		//Verifies if a supplied peer ID is the next target peer ID.
		function isNextTargetID(peerID:String, caseSensitive:Boolean = false):Boolean;	
		//Adds a peer ID to the source list.
		function addSourcePeerID(sourcePeerID:String):void;
		//Sets the source peer ID list.
		function setSourcePeerIDs(peerIDList:Vector.<INetCliqueMember>):void;
		//Retrieves the current source peer IDs as a list of INetCliqueMember implementations.
		function getSourcePeerIDList(INetCliqueMember_implementation:Class = null, delimiter:String = "-"):Vector.<INetCliqueMember>;
		//Checks for the existence of a source peer ID.
		function hasSourcePeerID(peerID:String, caseSensitive:Boolean = false):Boolean;
		//Verifies if a supplied peer ID is the next (most recent) source peer ID.
		function isNextSourceID(peerID:String, caseSensitive:Boolean = false):Boolean;		
		//Shifts the current target peer ID from the target list to the source list for relay-style operations.
		function updateSourceTargetForRelay():void;
		//Serializes the message to JSON formatting.
		function serializeToJSON(finalize:Boolean = false):String;
		//Serializes the message to XML formatting.
		function serializeToXML(finalize:Boolean = false):XML;
		//Serializes the message to binary AMF3 formatting.
		function serializeToAMF3(finalize:Boolean = false):ByteArray;
		//Serializes the message to binary AMF0 formatting.
		function serializeToAMF0(finalize:Boolean = false):ByteArray;
		//Produces a detailed information string about the message.
		function toDetailString():String;
		
	}
	
}
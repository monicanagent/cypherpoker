/**
* Handles and logs asynchronous peer messages.
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3 
{	
	import p2p3.interfaces.IPeerMessage;
	import p2p3.interfaces.IPeerMessageHandler;
	import p2p3.interfaces.INetClique;
	import flash.events.Event;
	import p2p3.events.NetCliqueEvent;
	import p2p3.interfaces.IPeerMessageLog;
	import flash.events.EventDispatcher;
	import p2p3.events.PeerMessageHandlerEvent;
	import p2p3.netcliques.NetCliqueMember;	
	import org.cg.DebugView;	
	
	public class PeerMessageHandler extends EventDispatcher implements IPeerMessageHandler 
	{
				
		private var _messageQueue:Vector.<IPeerMessage> = new Vector.<IPeerMessage>(); //stored messages; index 0 is next message, index _messageQueue.length-1 is last message
		private var _blockedQueue:Vector.<NetCliqueEvent> = new Vector.<NetCliqueEvent>(); //blocked clique events
		private var _cliques:Vector.<INetClique> = new Vector.<INetClique>(); //array of cliques for which this instance is a registered handler
		private var _messageLog:IPeerMessageLog; //default message log
		private var _errorLog:IPeerMessageLog; //default error log
		private var _localPeerID:String = null;
		private var _logEvents:Boolean = false;
		protected var _blocking:Boolean = false;
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	messageLogSet The IPeerMessageLog implementation to use for valid incoming peer messages.
		 * @param	errorLogSet The IPeerMessageLog implementation to use for incoming peer message errors.
		 */
		public function PeerMessageHandler(messageLogSet:IPeerMessageLog = null, errorLogSet:IPeerMessageLog = null) 
		{			
			_messageLog = messageLogSet;
			_errorLog = errorLogSet;
		}
		
		/**
		 * @return True if the local peer ID has been set.
		 */
		public function get localPeerIDSet():Boolean 
		{
			if ((localPeerID == null) || (localPeerID == "")) {
				return (false);
			}
			return (true);
		}		
		
		/**
		 * Peer IDs can't include quotes (these will be stripped out). This is
		 * for XML compatibility (it is contained in an attribute). Most other values should be okay:
		 * IPs: 256.128.66.132
		 * RTMFP peer ID: qwo132j1ljqwdlijqwp10pjp
		 * Telephone number: 111-555-1234
		 */
		public function set localPeerID(idSet:String):void 
		{
			_localPeerID = idSet;
			_localPeerID = _localPeerID.split("\"").join("");
		}
		
		public function get localPeerID():String 
		{
			return (_localPeerID);
		}
		
		/**
		 * Adds the instance to the target clique by assigning listeners to it.
		 * 
		 * @param	targetClique The clique to target with this instance.
		 * 
		 * @return True if the clique was successufully targeted and false if the clique was null or already added.
		 */
		public function addToClique(targetClique:INetClique = null):Boolean 
		{
			if (targetClique == null) {
				return (false);
			}
			if (addedToClique(targetClique)) {
				return (false);
			}
			_cliques.push(targetClique);
			setCliqueEventListeners(targetClique);
			return (true);
		}
		
		/**
		 * Removes the instance from the target clique by removing listeners from it.
		 * 
		 * @param	targetClique The clique to remove from this instance.
		 * 
		 * @return True if the clique was successufully removed and false if the clique was null or not added.
		 */
		public function removeFromClique(targetClique:INetClique = null):Boolean 
		{
			if (targetClique == null) {
				return (false);
			}
			if (!addedToClique(targetClique)) {
				return (false);
			}
			var newCliquesList:Vector.<INetClique> = new Vector.<INetClique>();
			for (var count:uint = 0; count < _cliques.length; count++) {
				var currentClique:INetClique = _cliques[count];
				if (currentClique != targetClique) {
					newCliquesList.push(currentClique);
				} else {
					clearCliqueEventListeners(currentClique);
				}
			}
			_cliques = newCliquesList;
			return (true);
		}
		
		/**
		 * Enables message blocking/queueing.
		 */
		public function block():void 
		{			
			this._blocking = true;			
		}
		
		/**
		 * Disables message blocking/queueing. Any queued messages are immediately dispatched.
		 */
		public function unblock():void 
		{		
			this._blocking = false;			
			//process any events currently blocked making sure to stop if blocking is enabled again during execution
			while (dispatchNextBlockedEvent()) {
			}
		}
		
		/**
		 * Dispatches the next blocked event.
		 * 
		 * @return True if the next blocked event was dispatched and false if blocking is enabled or no more events
		 * are available.
		 */
		public function dispatchNextBlockedEvent():Boolean 
		{
			if (this._blocking) {
				//blocking enabled while dispatching
				return (false);
			}
			var currentEvent:NetCliqueEvent = getNextBlockedEvent();
			if (currentEvent != null) {
				var event:PeerMessageHandlerEvent = new PeerMessageHandlerEvent(PeerMessageHandlerEvent.PEER_MSG);
				event.message = currentEvent.message;				
				dispatchEvent(event);
				return (true);
			}
			//no more events to dispatch
			return (false);
		}
		
		/**
		 * Assigns event listeners to a clique.
		 * 
		 * @param	targetClique The target clique to assign event listeners to.
		 */		 
		protected function setCliqueEventListeners(targetClique:INetClique):void 
		{
			if (targetClique == null) {
				return;
			}
			targetClique.addEventListener(NetCliqueEvent.PEER_MSG, onReceivePeerMessage);
			targetClique.addEventListener(NetCliqueEvent.CLIQUE_DISCONNECT, onCliqueDisconnect);
		}
		
		/**
		 * Removes event listeners from a clique.
		 * 
		 * @param	targetClique The target clique to remove event listeners from.
		 */
		protected function clearCliqueEventListeners(targetClique:INetClique):void 
		{
			if (targetClique == null) {
				return;
			}
			targetClique.removeEventListener(NetCliqueEvent.PEER_MSG, onReceivePeerMessage);
			targetClique.removeEventListener(NetCliqueEvent.CLIQUE_DISCONNECT, onCliqueDisconnect);
		}
		
		/**
		 * Checks if the handler is listening to events from the target clique.
		 * 
		 * @param	targetClique The target clique to check.
		 * 
		 * @return True if the handler is listening to events from the target clique.
		 */
		protected function addedToClique(targetClique:INetClique):Boolean 
		{
			for (var count:uint = 0; count < _cliques.length; count++) {
				var currentClique:INetClique = _cliques[count];
				if (currentClique == targetClique) {
					return (true);
				}
			}
			return (false);
		}
		
		/**
		 * Handles clique disconnection events.
		 * 
		 * @param	eventObj A CLIQUE_DISCONNECT event object.
		 */
		private function onCliqueDisconnect(eventObj:NetCliqueEvent):void 
		{
			var targetClique:INetClique = eventObj.target as INetClique;
			removeFromClique(targetClique);
		}
		
		/**
		 * Handles received peer message events.
		 * 
		 * @param	eventObj A PEER_MSG event.
		 */
		private function onReceivePeerMessage(eventObj:NetCliqueEvent):void 
		{								
			if (this._blocking) {
				//DebugView.addText ("PeerMessageHandler.onReceivePeerMessage from (blocking): " + eventObj.message.getSourcePeerIDList(NetCliqueMember)[0].peerID);				
				storeBlockedEvent(eventObj);
				return;
			} else {
				//DebugView.addText ("PeerMessageHandler.onReceivePeerMessage from (not blocking): " + eventObj.message.getSourcePeerIDList(NetCliqueMember)[0].peerID);
			}			
			var rawMsg:*= eventObj.message;
			try {
				var msgObj:PeerMessage = new PeerMessage(rawMsg);				
				if (msgObj.isValid) {
					storePeerLog(msgObj);
					var event:PeerMessageHandlerEvent = new PeerMessageHandlerEvent(PeerMessageHandlerEvent.PEER_MSG);
					event.message = eventObj.message;					
					dispatchEvent(event);
				} else {
					storeErrorLog(msgObj);					
				}
			} catch (err:*) {				
			}
		}
		
		/**
		 * Stores a blocked event by adding it to the end of the blocked queue.
		 * 
		 * @param	eventObj The blocked event to store on the queue.
		 */
		protected function storeBlockedEvent(eventObj:NetCliqueEvent):void 
		{
			_blockedQueue.push(eventObj);
		}
		
		/**
		 * Retrieves the next blocked event from the beginning of the blocked queue.
		 * 
		 * @return The next blocked event or null.
		 */
		protected function getNextBlockedEvent():NetCliqueEvent 
		{
			try {
				return (_blockedQueue.shift());
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Stores a peer message by adding it to the beginning of the message queue.
		 * 
		 * @param	eventObj The message to store on the queue.
		 */
		protected function storePeerMessage(msgObj:PeerMessage):void 
		{
			_messageQueue.unshift(msgObj);		
		}
		
		/**
		 * Stores a peer message to the message log if available.
		 * 
		 * @param	eventObj The message to store to the log.
		 */
		protected function storePeerLog(msgObj:PeerMessage):void 
		{
			if (_messageLog == null) {
				return;
			}
			_messageLog.addMessage(msgObj);
		}
		
		/**
		 * Stores a peer message to the error log if available.
		 * 
		 * @param	eventObj The message to store to the log.
		 */
		protected function storeErrorLog(msgObj:PeerMessage):void 
		{
			if (_errorLog == null) {
				return;
			}
			_errorLog.addMessage(msgObj);		
		}
	}
}
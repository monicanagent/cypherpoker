/**
* Peer to peer networking clique implementation via Adobe's RTMFP.
* 
* Adapted from the SWAG ActionScript toolkit: https://code.google.com/p/swag-as/
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.netcliques {

	import p2p3.interfaces.INetClique;
	import p2p3.events.NetCliqueEvent;
	import p2p3.netcliques.events.RTMFPEvent;
	import flash.events.EventDispatcher;	
	import p2p3.netcliques.RTMFPDataPacket;
	import p2p3.netcliques.RTMFPDataShare;
	import p2p3.interfaces.INetCliqueMember;
	import p2p3.netcliques.RTMFPCliqueMember;
	import p2p3.interfaces.IPeerMessage;
	import flash.display.DisplayObjectContainer;
	import flash.events.Event;
	import flash.events.NetStatusEvent;
	import flash.events.StatusEvent;
	import flash.media.Camera;
	import flash.media.Microphone;
	import flash.media.SoundTransform;
	import flash.media.Video;	
	import flash.net.NetConnection;
	import flash.net.NetGroup;
	import flash.net.NetStream;
	import flash.system.Security;
	import flash.system.SecurityPanel;
	import flash.utils.ByteArray;	
	import flash.net.NetGroup;
	import flash.net.NetGroupInfo;
	import flash.net.GroupSpecifier;			
	import flash.net.NetGroupReplicationStrategy;
	import flash.net.NetGroupReceiveMode;
	import flash.net.NetGroupReplicationStrategy;
	import flash.net.NetGroupSendMode;
	import flash.net.NetGroupSendResult;
	import p2p3.PeerMessage;
	import org.cg.DebugView;
	
	public class RTMFP extends EventDispatcher implements INetClique {	
				
		private const defaultServerAddress:String="rtmfp://p2p.rtmfp.net/";
		//private const defaultServerAddress:String="rtmfp://127.0.0.1/"; //local - port 1935 is default
		//private const defaultServerAddress:String="rtmfp://127.0.0.1:8080/"; //local using port 8080
		private const defaultDeveloperKey:String = "xxx"; //developer key to use with p2p.rtmfp.net (not used by default with OpenRTMFP/Cumulus)	
		private const defaultIPMulticasrAddress:String="225.225.0.33:33333";
		
		private const passwordHashModifier:String="p:tw0~Pt_HrE3=P0<e2;h4$h+"; //hash modifier
		
		//Use only one connection. Multiple groups (clouds) can be created on a single instance of a NetConnection.
		private static var _netConnection:NetConnection;
		private var _serverConnected:Boolean=false; //Is the rendezvous server connection established?		
		private var _sessionStarted:Boolean=false; //Is a connection or a connection attempt currently active?
		private var _localPeerID:String = new String(); //Peer ID of this connection (singleton since the value comes from the NetConnection instance)
		
		/**
		 * Contains the range of all separator ASCII characters (space, hyphen, underscore, back slash, forward slash), 
		 * that can be used with various string operations. 
		 */
		public static const SEPARATOR_RANGE:String=" -_\\/\n\r\t";
		
		//Fallback to default settings if supplied ones are invalid?
		public var defaultFallback:Boolean=true;		
		
		//Stores actual server address values used.
		private var _serverAddress:String=new String();
		private var _developerKey:String=new String();
		private var _connectionAddress:String = new String();
		private var _ipMulticastAddress:String = new String();
		
		private var _groupConnected:Boolean=false; //Is the current group connected?
		private var _groupConnecting:Boolean=false; //Is a group connection currently being established?
		private var _mediaStreamPublished:Boolean=false; //Is the media stream published?		
		
		private var _groupSpecifier:GroupSpecifier; //GroupSpecifier instance
		private var _groupName:String;
		private var _netGroup:NetGroup; //NetGroup instance 
		private var _openGroup:Boolean=true; //Can anyone post to group or only the creator?
		
		private var _netStream:NetStream; //Used for live streaming (audio / video)
		private var _distributedStream:NetStream; //Used for distributed streaming (audio / video)
		private var _gatherAppendStream:Boolean=false; //Used with "playDistributedStream" to insert
					//shared data into the _netStream object (via appendBytes) instead of a standard media stream.
		private var _mediaStreamName:String; //The media stream name currently being broadcast. 
					//A single stream can share a microphone and camera(recommended for propper A/V synch).
		private var _streamCamera:Camera; //The camera object currently attached and being streamed.
		private var _streamMicrophone:Microphone; //The microphone object currently attached and being streamed.

		private var _peerList:Array = new Array(); //List of attached peers.
		
		private var _parentClique:RTMFP = null; //parent or originating clique (if not null then this is a room connection)
				
		/**
		 * The replication strategy used by the netgroup when dealing with distributed / shared / relayed / replicated objects.
		 * This will hold one of the NetGroupReplicationStrategy constants and should be set depending on the type of application
		 * that the group has.
		 * <p>For streaming applications where data order is crucial, the LOWEST_FIRST strategy should be employed. For applications
		 * such as file sharing where the whole data piece is required, the RAREST_FIRST strategy is a better approach for both
		 * ensuring completion and for improving swarming data distribution.</p>
		 */
		private var _gatherStrategy:String;
		/**
		 * Specifies whether or not this cloud group should act as a data relay node for object replication.
		 * <p>Object replication is the basic tenet of most P2P systems and allows individual nodes to retain information
		 * to send on to other nodes, thereby reducing the load on the original source of the data and most efficiently using
		 * bandwidth.</p>
		 * <p>This is enabled by default and may be set before a group is created. If disabled, swarm-based functionality
		 * is effectively disabled as well and direct peer-to-peer communication must be used instead (using <code>send</code>
		 * or <code>broadcast</code>, for example).</p>
		 * <p>The other benefit to using relay replication is the ability to catch and potentially modify informational packets
		 * in the swarmed stream.</p>
		 */		
		private var _dataRelay:Boolean=true;		
		private var _dataShare:RTMFPDataShare=null;
		
		//If createGroup is called before a connection is established then queue it up.
		private var _queueCreateGroup:Boolean=false;
		private var _queuedGroupSpec:Object;	
		
		/**
		 * The default constructor for the class.
		 *  
		 * @param initServerAddress The initial RTMFP Rendezvous server server address that will perform the rendezvous operation. If already connected, this
		 * value will be ignored.
		 * @param initDeveloperKey The initial RTMFP Rendezvous server developer key with which to perform the rendezvous. If already connected, this value will
		 * be ignored.
		 * @param initIPMulticastAddress The initial IP multicast address to use when using LAN/WAN connections. Ignored for other types of connections.
		 * @param parentRef Reference to the parent or owning RTMFP instance. When operating as a child an instance will skip any initial connection attempts
		 * as it's assumed that the parent instance has already established one.
		 * 
		 */
		public function RTMFP(initServerAddress:String = null, initDeveloperKey:String = null, initIPMulticastAddress:String = null, parentRef:RTMFP = null) {
			if ((initServerAddress!=null) && (initServerAddress!="")) {
				this._serverAddress=initServerAddress;
			}//if
			if ((initDeveloperKey!=null) && (initDeveloperKey!="")) {
				this._developerKey=initDeveloperKey;
			}//if
			if ((initIPMulticastAddress!=null) && (initIPMulticastAddress!="")) {
				this._ipMulticastAddress=initIPMulticastAddress;
			}//if
			this._parentClique = parentRef;
			if (this._parentClique != null) {
				this._serverAddress = this._parentClique.serverAddress;
				this._developerKey = this._parentClique.developerKey;
				this._ipMulticastAddress = this._parentClique.ipMulticastAddress;
			}
		}//constructor
		
		//__/ INetClique implementation \__
		
		public function sendToPeer(peer:INetCliqueMember, msgObj:IPeerMessage):Boolean {
			if ((peer == null) || (msgObj==null)) {
				return (false);
			}//if
			if (!msgObj.isValid) {
				return (false);
			}//if			
			if (this.send(msgObj.serializeToAMF3(true), peer.peerID) == NetGroupSendResult.SENT) {
				return (true);
			} else {
				return (false);
			}//else
		}//sendToPeer
		
		public function sendToPeers(peers:Vector.<INetCliqueMember>, msgObj:IPeerMessage):Vector.<Boolean> {
			if ((peers == null) || (msgObj==null)) {
				return (null);
			}//if
			if (!msgObj.isValid) {
				return (null);
			}//if
			if (peers.length == 0) {
				return (null);
			}//if
			var returnSucc:Vector.<Boolean> = new Vector.<Boolean>();
			var serializedMsg:ByteArray = msgObj.serializeToAMF3(true);
			for (var count:int = 0; count < peers.length; count++) {
				var currentPeer:INetCliqueMember = peers[count];
				if (this.send(serializedMsg, currentPeer.peerID) == NetGroupSendResult.SENT) {
					returnSucc.push(true);
				} else {
					returnSucc.push(false);
				}//else
			}//for
			return (returnSucc); 
		}//sendToPeers
		
		public function broadcast(msgObj:IPeerMessage):Boolean {			
			if (msgObj == null) {				
				return (false);
			}//if
			if (!msgObj.isValid) {				
				return (false);
			}//if
			if ((msgObj.targetPeerIDs == "") || (msgObj.targetPeerIDs == null)) {
				msgObj.targetPeerIDs = "*";
			}//if			
			msgObj.addSourcePeerID(this.localPeerID);						
			var res:String = this.broadcastToAllPeers(msgObj.serializeToAMF3(true), false);				
			if ((res!= "") && (res!=null)) {
				return (true);
			} else {				
				return (false);
			}//else
		}//broadcast
		
		/**
		 * Calls the connectGroup method with any supplied arguments in order to start connecting the RTMFP instance.
		 * 
		 * @param	... args
		 * @return
		 */
		public function connect(... args):Boolean {
			DebugView.addText("Connecting...");
			if (args == null) {
				return (false);
			}//if
			if (args.length < 1) {
				return (false);
			}//if
			if (this.connected) {
				return (false);
			}//if			
			this.connectGroup.apply(this, args);
			return (false);
		}//connect
		
		
		
		/**
		 * Disconnects the current clique connection. If this is a child clique then only the local connection is closed
		 * but if this is the parent or originating connection then all children are disconnected first.
		 * 
		 * <p>Broadcasts a <code>RTMFPEvent.DISCONNECT</code> event when disconnected.</p>
		 * 
		 */
		public function disconnect():Boolean {
			if (this._rooms.length > 0) {
				for (var count:int = 0; count < this._rooms.length; count++) {
					this._rooms[count].disconnect();
				}
				this._rooms = null;
			}
			this.disconnectGroup();
			return (true);
		}//disconnect
						
		public function get connected():Boolean {
			return (this.groupConnected);
		}//get connected		
		
		public function destroy():void {
			_netConnection.removeEventListener(NetStatusEvent.NET_STATUS, this.onConnectionStatus);	
			if (this._netGroup!=null) {
				this._netGroup.removeEventListener(NetStatusEvent.NET_STATUS, this.onGroupStatus);
			}			
			//may also remove camera and microphone listeners here
			this.disconnectGroup();
			if ((_netConnection != null) && (this.parentClique == null)) {
				_netConnection.close();
			}
			_netConnection = null;
			this._gatherAppendStream=false;
			this._groupName = null;	
		}
		
		public function get connectedPeers():Vector.<INetCliqueMember> {
			var returnVec:Vector.<INetCliqueMember> = new Vector.<INetCliqueMember>();
			for (var count:uint = 0; count < this.peerList.length; count++) {
				var currentPeer:String = this.peerList[count] as String;
				var ncMember:RTMFPCliqueMember = new RTMFPCliqueMember(currentPeer);
				returnVec.push(ncMember);				
			}//for
			return (returnVec);
		}//get connectedPeers
		
		public function get localPeerInfo():INetCliqueMember {
			var returnObj:RTMFPCliqueMember = new RTMFPCliqueMember(this.localPeerID);
			return (returnObj);
		}	
		
		/**
		 * Creates a connection with the RTMFP Rendezvous server server in order to create the initial rendezvous between peers.
		 * <p>If a connection is already established nothing happens. Since a single <code>NetConnection</code>
		 * is used for all active NetGroup connections, multiple <code>RTMFP</code> instances can be created in exactly the same
		 * way (calling this method), without any additional checks.</p>
		 * 
		 * @return <code>True</code> if the connection can, or is already, established, or <code>false</code> if
		 * there's a problem (for example, the server address or developer key weren't set).
		 * 
		 */
		public function createConnection():Boolean {
			DebugView.addText("Creating new netconnection");
			if (_sessionStarted || _serverConnected) {			
				return (false);
			}//if
			if ((this._groupConnecting) || (this._groupConnected)) {
				return (false);
			}//if
			if ((this.serverAddress==null) || (this.serverAddress=="")) {				
				return (false);
			}//if
			if ((this.developerKey==null) || (this.developerKey=="")) {				
				return (false);
			}//if
			_sessionStarted=true;
			if (_netConnection!=null) {
				_netConnection.removeEventListener(NetStatusEvent.NET_STATUS, this.onConnectionStatus);	
			}//if
			if (_netConnection==null) {				
				_netConnection=new NetConnection();
				_netConnection.client=this;
				_netConnection.addEventListener(NetStatusEvent.NET_STATUS, this.onConnectionStatus);
				DebugView.addText ("1. Opening connection to: " + this.serverAddress);
				DebugView.addText ("2.   Developer key: " + this.developerKey);
				_netConnection.connect(this.serverAddress, this.developerKey); //p2p.rtmfp.net
			//	_netConnection.connect(this.serverAddress); //OpenRTMFP/Cumulus
			} else {				
				_netConnection.addEventListener(NetStatusEvent.NET_STATUS, this.onConnectionStatus);
				if (_netConnection.connected==false) {					
					_netConnection.client = this;
					DebugView.addText ("2. Opening connection to: " + this.serverAddress);
					DebugView.addText ("2.   Developer key: " + this.developerKey);
					_netConnection.connect(this.serverAddress, this.developerKey); //p2p.rtmfp.net
				//	_netConnection.connect(this.serverAddress); //OpenRTMFP/Cumulus
				}//if
			}//else
			return (true);
		}//createConnection
		
		private var _rooms:Vector.<INetClique> = new Vector.<INetClique>();
		
		/**
		 * Creates a new, segregated communication group for peers.
		 * 
		 * @param	options An options object containing parameters that will be passed to the child instance's "connectGroup" method. These include:
		 * 
		 * "groupName" (String) - The name of the room to create. All connecting members must join exactly the same room. This value must be specified and 
		 * may not be null.
		 * "open" (Boolean) - If true (default), anyone in the room may post and broadcast otherwise only the creator may post and all other peers join 
		 * in read-only (consumer) mode.
		 * "password" (String) - An optional password required to join the room. Default is null (no password required).
		 * "passwordHash" (String) - An optional hash value used to obfuscate/encrypt the room's communications. Default is null (no hash).
		 * "secure" (Boolean) - If true the "passwordHash" property is used to encrypt room communications otherwise it's ignored. Default is false.
		 * 
		 * @return A new RTMFP instance or null if one couldn't be created. A connection is attempted on the new instance immediately but it should
		 * not be assumed to be connected.
		 */
		public function newRoom(options:Object):INetClique {
			if (this.connected == false) {
				//main connection must be active before a room can be created
				return (null);
			}
			if (this.parentClique != null) {
				//return a new room through parent chain
				return (this.parentClique.newRoom(options));
			}			
			var newRoom:RTMFP = new RTMFP(null, null, null, this);
			newRoom.addEventListener(NetCliqueEvent.CLIQUE_DISCONNECT, this.onRoomDisconnect);
			if (options == null) {
				options = new Object();				
			}
			if ((options["groupName"] == undefined) || (options["groupName"] == null) || (options["groupName"] == "")) {
				return (null);
			}
			if ((options["open"] == undefined) || (options["open"] == null)) {
				options.open = true;
			}
			if ((options["password"] == undefined) || (options["password"] == null)) {
				options.password = true;
			}
			if ((options["passwordHash"] == undefined) || (options["passwordHash"] == null)) {
				options.passwordHash = null;
			}
			if ((options["secure"] == undefined) || (options["secure"] == null)) {
				options.secure = false;
			}
			newRoom.connectGroup(options.groupName, options.open, options.password, options.passwordHashModifier, options.secure);
			this._rooms.push(newRoom);
			return (newRoom);
		}
		
		private function onRoomDisconnect(eventObj:NetCliqueEvent):void {			
			eventObj.target.removeEventListener(NetCliqueEvent.CLIQUE_DISCONNECT, this.onRoomDisconnect);
			for (var count:int = 0; count < this._rooms.length; count++) {
				if (this._rooms[count] == eventObj.target) {
					this._rooms.splice(count, 1);
				}
			}
		}
		
		public function get parentClique():INetClique {
			return (this._parentClique);
		}
		
		public function get rooms():Vector.<INetClique> {
			if (this._rooms == null) {
				return (null);
			}
			if (this._rooms.length == 0) {
				return (null);
			}
			return (this._rooms);
		}
		
		/**
		 * Connects to a new or existing group to be associated with this <code>RTMFP</code> instance.
		 * <p>This automates the process of connecting to a group by first creating the group specifier and then creating
		 * the group object. If a net connection hasn't yet been established, the operation is queued and carried out automatically (this
		 * saves the developer the hassle of creating a series of listeners to create a group).</p>
		 * <p>In order to connect to an existing group, all of the parameters passed to this method must match the information for
		 * the target group (i.e. the group name, opennes, password, etc., must all be exactly the same). If even one aspect is not the same,
		 * a new group will be created instead (this is the way it works beneath the ActionScript layer).</p>		 
		 *  
		 * @param groupName The name of the group to create or connect to.
		 * @param open If <code>true</code>, posting / multicasting to the group is allowed. If <code>false</code>, the group is joined in
		 * read-only mode (consumer role).
		 * @param password The password to encode the group name with. This is used to control access to the group.
		 * @param passwordHash An extra hash string to double-encode the group name and password properties with. Used for extra-secure groups.
		 * @param secure If <code>true</code> the password and passwordHash parameters will be used to encrypt the group data. If <code>false</code>,
		 * these two parameters are ignored and data will be sent in plain text.
		 * @return <code>True</code> if the group was successfully connected to. <code>False</code> if the connection hasn't yet been established, in which
		 * case the group connection will be queued.
		 * 
		 */		
		public function connectGroup (groupName:String, open:Boolean = true, password:String = null, passwordHash:String = passwordHashModifier, secure:Boolean = true):Boolean {
			if ((this._groupConnecting) && (!this._queueCreateGroup)) {				
				return (false);
			}//if
			if (this.groupSpecifier==null) {
				if (this.createGroupSpec(groupName, password, passwordHash, secure)==false) {					
					this._queueCreateGroup=true;				
					return (false);
				}//if
			}//if			
			if (_netConnection==null) {						
				this._queueCreateGroup=true;
				if (!this.sessionStarted) {
					this.createConnection();
				}//if
				return (false);		
			} else if (_netConnection.connected == false) {	
				DebugView.addText("Net connection not connected");
				this._queueCreateGroup=true;
				if (!this.sessionStarted) {
					this.createConnection();
				}//if
				return (false);
			} else if (this._groupConnecting || this._groupConnected) {
				return (false);
			} else {
				_netConnection.removeEventListener(NetStatusEvent.NET_STATUS, this.onConnectionStatus);
				_netConnection.addEventListener(NetStatusEvent.NET_STATUS, this.onConnectionStatus);
			}//else
			if (this._netGroup!=null) {
				this._netGroup.removeEventListener(NetStatusEvent.NET_STATUS, this.onGroupStatus);
				this._netGroup=null;
			}//if
			_sessionStarted=true;
			this._groupConnecting=true;			
			this._queueCreateGroup = false;			
			//this._groupName = groupName;	
			DebugView.addText("Connect group: " + this._groupName);
			DebugView.addText("   open group: " + open);			
			if (this._openGroup) {
				//Can post							
				this._netGroup=new NetGroup(netConnection, this.groupSpecifier.groupspecWithAuthorizations());
			} else {
				//Receive only				
				this._netGroup=new NetGroup(netConnection, this.groupSpecifier.groupspecWithoutAuthorizations());
			}//else	
			DebugView.addText ("adding netgroup listeners");
			this._netGroup.addEventListener(NetStatusEvent.NET_STATUS, this.onGroupStatus);
			return (true);
		}//connectGroup		
		
		/**
		 * Disconnects from the associated <code>NetGroup</code>, closing any associated <code>NetStream</code>
		 * first,. This does not close the active <code>NetConnection</code> connection but will make this 
		 * particular <code>RTMFP</code> instance unfunctional until a new connection is established using 
		 * the <code>connectGroup</code> method.  
		 */
		public function disconnectGroup():Boolean {			
			if (this._netStream!=null) {
				this._netStream.removeEventListener(NetStatusEvent.NET_STATUS, this.onStreamStatus);
				//this._netStream.close();
				this._netStream=null;
				this._mediaStreamPublished=false;
			}//if
			if (this._netGroup!=null) {
				this._netGroup.removeEventListener(NetStatusEvent.NET_STATUS, this.onGroupStatus);
				this._netGroup.close();
				//this._netGroup=null;
				this._groupConnecting=false;
				this._groupConnected=false;
			}//if
			this._gatherAppendStream=false;
			this._groupName = null;
			return (true);
		}//disconnectGroup
		
		/**
		 * <p>Broadcasts a message to all connected peers using the <code>post</code> method.</p>
		 * <p>According to Adobe's documentation all messages must be unique, so including something like an <code>index</code>
		 * property is a good idea to ensure proper propagation to all peers.</p>
		 *  
		 * @param data Any valid simple or complex Flash data type(s). Data that exceeds 10 MB in size (for example, 
		 * <code>ByteArray</code> objects, should be chunked into smaller pieces for reliable delivery.
		 * @param neighbourhood If <code>true</code>, the message is propagated through only through the nearest neighbours. If <code>false</code>,
		 * the message is sent to all connected peers (this may be very data intensive if many peers are connected!)
		 * 
		 * @return The message ID sent. This is the hex value of the SHA256 of the serialized binary data of the message.
		 * 
		 */
		private function broadcastToAllPeers(data:*, neighbourhood:Boolean = true):String {			
			if (this.netGroup==null) {
				return (null);
			}//if			
			if (neighbourhood){				
				var directDataObject:RTMFPDataPacket=new RTMFPDataPacket("message");				
				directDataObject.data=data;		
				directDataObject.source=this.localPeerID;
				directDataObject.destination="";
				return (this.netGroup.sendToAllNeighbors(directDataObject));	
			} else {										
				directDataObject=new RTMFPDataPacket("message");			
				directDataObject.data=data;
				directDataObject.source=this.localPeerID;			
				return (this.netGroup.post(directDataObject));
			}//else
		}//broadcastToAllPeers
		
		/**
		 * <p>Sends a message to a specific peer via cloud propagation.</p>
		 * <p>The peer ID is one of the IDs stored in the <code>peerList</code> array, *not* an ID associated with a 
		 * received message. A message routed to a non-recognized peer will be lost. Peer propagation is used to
		 * route messages via nearest neighbours to the ultimate location using a shortest path algorithm.</p>
		 *  
		 * @param data The data to send directly to the peer. This can contain any valid Flash data types and will be encapsulated
		 * within the sending data object for routing.
		 * @param peerID The target peer ID to send to. If blank or <code>null</code>, no message will be sent and <code>null</code> will 
		 * be returned.
		 * 
		 * @return  The message ID sent. This is the hex value of the SHA256 hash of the serialized binary data of the message.
		 * 
		 */		
		private function send(data:*, peerID:String=null):String {
			if (this.netGroup==null) {
				return (null);
			}//if
			if ((peerID==null) || (peerID=="")) {
				return (null);
			}//if			
			var directDataObject:RTMFPDataPacket=new RTMFPDataPacket("message");			
			directDataObject.data=data;	
			directDataObject.source=this.localPeerID;
			directDataObject.destination=this.netGroup.convertPeerIDToGroupAddress(peerID);
			//return (this.netGroup.sendToNearest(directDataObject, directDataObject.destination));
			return (this.netGroup.sendToNeighbor(directDataObject, directDataObject.destination));
		}//send		
		
		/**
		 * Begins the distribution of a data object using relayed object replication.
		 * 
		 * <p>Because a single group can only replicate one data stream, calling this method while data is being replicated
		 * in the background causes any currently relaying data to be discarded.</p>
		 * <p>For this reason it's advisable to create a new <code>RTMFP</code> instance with any new distribution
		 * that's required.</p>
		 * 
		 * @param data The data object to be replicated. If this is a <code>ByteArray</code> it will be used as-is,
		 * otherwise the data will be serialized using AMF data serialization (so most Flash data types are supported).
		 * @param chunkSize The data chunk size to use for distribution. Larger chunks may cause unnecessary traffic
		 * as lossy UDP data may cause packets to be lost and re-requested, while small chunks will have excessive overhead
		 * added on them. 
		 * 
		 * @return The newly created <code>RTMFPDataPacket</code> instance associated with the group. An additional reference
		 * to this object is stored in this class instance (since a group can only replicate one object).
		 * 
		 */
		public function distribute(data:*=null, chunkSize:uint=64000):RTMFPDataShare {
			if (data==null) {
				return (null);
			}//if			
			this._gatherAppendStream=false;
			this._dataShare=new RTMFPDataShare();
			this._dataShare.dataChunkSize=chunkSize;
			this._dataShare.chunkData(data);
			this._netGroup.addHaveObjects(0, this._dataShare.numberOfChunks);
			return (this._dataShare);
		}//distribute
		
		/**
		 * Begins the gathering of a data object using relayed object replication.
		 * 
		 * <p>Since a single group can only distribute one stream of data (though that data can be a complex object),
		 * the received data for a group is associated with only one <code>RTMFPDataPacket</code> object.</p>		 		 
		 * 
		 * @appendStream If <em>true</em>, the associated <code>NetStream</code> object will begin streaming
		 * the gathered data as it's received. This is different from playing published audio / video
		 * streams as this data is not live.
		 * 
		 * @return A newly created <code>RTMFPDataPacket</code> instance into which the distributed data will be gathered.
		 * Once completed, the data will be de-serialized into a native Flash data type and can be used. Until then,
		 * however, the raw binary data may be analyzed if desired within this instance.
		 * 
		 */
		public function gather(appendStream:Boolean=false):RTMFPDataShare {
			this._gatherAppendStream=appendStream;
			this._dataShare=new RTMFPDataShare();
			this._netGroup.addWantObjects(0,0); //Send request for number of packets available
			return (this._dataShare);
		}//distribute
		
		/**
		 * Creates a media stream name for the cloud instance. This must be set in advance of starting
		 * a camera or microphone stream. 
		 *  
		 * @param streamName The exacr stream name to publish over the connected cloud instance.
		 * 
		 */
		public function createMediaStream(streamName:String):void {
			this._mediaStreamPublished=true;
			this._mediaStreamName=streamName;
		}//createMediaStream
		
		/**
		 * Attaches a camera to the outgoing group stream. Be sure to call the <code>createMediaStream</code>
		 * method to set the stream name before calling this method.
		 *  
		 * @param camera The <code>Camera</code> object to attach to the outgoing stream.
		 * @param snapshotMS The snapshot, or key frame rate, at which to insert the camera key frames into the stream.
		 * The default value is -1, which is the same as 0 (only one frame).
		 * 
		 * @return The <code>NetStream</code> object being used to transport the camera stream, or <em>null</em>
		 * if none can be found. 
		 * 
		 */
		public function streamCamera(cam:Camera, snapshotMS:int=-1):NetStream {
			if (cam==null) {
				//Broadcast error
				return (null);
			}//if
			if (this.stream==null) {
				//Broadcast error
				return (null);
			}//if			
			this._streamCamera=cam;
			if (cam.muted) {
				//Camera security dialog is showing...wait until it's done.
				cam.addEventListener(StatusEvent.STATUS, this.onCameraStatus);
				Security.showSettings(SecurityPanel.PRIVACY);
				return (null);
			} else {
				this.stream.attachCamera(cam, snapshotMS);				
				this.publishMediaStream(this._mediaStreamName);
			}//else
			return (this.stream)
		}//streamCamera
		
		/**
		 * Publishes an outgoing group video stream.
		 * 
		 * @param streamName A standard <code>StatusEvent</code> object.
		 * 
		 */
		private function onCameraStatus(eventObj:StatusEvent):void {			
			if (eventObj.code=="Camera.Unmuted") {
				this.stream.attachCamera(this._streamCamera);
				this.publishMediaStream(this._mediaStreamName);
			}//if
		}//onCameraStatus
		
		/**
		 * Attaches a microphone to the outgoing group stream.
		 *  
		 * @param camera
		 * @param snapshotMS
		 * 
		 * @return The <code>NetStream</code> object being used to transport the microphobe stream, or <em>null</em>
		 * if none can be found. 
		 * 
		 */
		public function streamMicrophone(mic:Microphone):NetStream {
			if (mic==null) {
				//Broadcast error
				return (null);
			}//if
			if (this.stream==null) {
				//Broadcast error
				return (null);
			}//if			
			this._streamMicrophone=mic;
			if (mic.muted) {
				//Microphone security dialog is showing...wait until it's done.
				this._streamMicrophone.addEventListener(StatusEvent.STATUS, this.onMicrophoneStatus);
				Security.showSettings(SecurityPanel.PRIVACY);
				return (null);
			} else {
				this.stream.attachAudio(mic);
				this.publishMediaStream(this._mediaStreamName);
			}//else
			return (this.stream)
		}//streamMicrophone
		
		/**
		 * Responds to a microphone security dialog status change, attaches the microphone to the stream,
		 * and publishes it.
		 * 
		 * @param streamName A standard <code>StatusEvent</code> object.
		 * 
		 */
		private function onMicrophoneStatus(eventObj:StatusEvent):void {		
			if (eventObj.code=="Microphone.Unmuted") {
				this.stream.attachAudio(this._streamMicrophone);
				this.publishMediaStream(this._mediaStreamName);
			}//if
		}//onMicrophoneStatus
		
		/**
		 * Stops an outgoing camera stream, if one is attached.  Be sure to call the <code>createMediaStream</code>
		 * method to set the stream name before calling this method.
		 *  
		 * @return <em>True</em> if the stream was stopped, <em>false</em> otherwise (for example, no stream
		 * exists). 
		 * 
		 */
		public function stopCameraStream():Boolean {
			if (this.stream==null) {
				//Broadcast error
				return (false);
			}//if
			try {
				this.stream.attachCamera(null);
				this._streamCamera=null;
				return (true);
			} catch (e:*) {
				return (false);
			}//catch
			return (false);
		}//stopCameraStream
		
		/**
		 * Stops an outgoing microphone stream, if one is attached.
		 *  
		 * @return <em>True</em> if the stream was stopped, <em>false</em> otherwise (for example, no stream
		 * exists). 
		 * 
		 */
		public function stopMicrophoneStream():Boolean {
			if (this.stream==null) {
				//Broadcast error
				return (false);
			}//if
			try {
				this.stream.attachAudio(null);
				this._streamMicrophone.removeEventListener(StatusEvent.STATUS, this.onMicrophoneStatus);
				this._streamMicrophone=null;
				return (true);
			} catch (e:*) {
				return (false);
			}//catch
			return (false);
		}//stopMicrophoneStream
		
		/**
		 * Publishes the media stream. This after camera / microphone have asynchonously checked security settings,
		 * if streaming from these devices, or directly if streaming from a file (or other native location).
		 *  
		 * @param streamName The stream name to publish.
		 * 
		 */
		private function publishMediaStream(streamName:String):void {
			this._mediaStreamPublished=true;
			this.stream.publish(streamName);
		}//publishMediaStream
		
		/**
		 * Attaches a <code>Video</code> object to the cloud's P2P media stream (if one is active).
		 *  
		 * @param video A reference to the <code>Video</code> object to attach to the the cloud's P2P
		 * media stream.
		 *  
		 * @return The <code>NetStream</code> object being used to transport the streaming media, or
		 * <em>null</em> if none exists (no stream is active). 
		 * 
		 */
		public function attachVideoStream(video:Video):NetStream {
			if (this.stream==null) {
				//Broadcast error
				return (null);
			}//if
			video.attachNetStream(this.stream);
			return (this.stream);
		}//attachVideoStream
		
		/**
		 * Plays an attached stream from an incoming group video stream.
		 * <p>Ensure that a <code>Video</code> instance is attached to the stream first
		 * by calling the <code>attachVideoStream</code> method, otherwise the stream
		 * will begin with no output.</p>
		 * 
		 * @param streamName The video stream to connect to and begin playing back. If
		 * an empty string or <em>null</em>, <code>mediaStreamName</code> is used instead. When
		 * a new stream is established for the group, the <code>mediaStreamName</code> is 
		 * automaticaly set. For outgoing connections, the <code>mediaStreamName</code> is set
		 * by the caller, but should also be available.
		 * 
		 */
		public function playVideoStream(streamName:String=null):void {
			if (this.stream==null) {
				//Broadcast error
				return;
			}//if
			if ((streamName==null) || (streamName=="")) {
				streamName=this.mediaStreamName;
			}//if
			this._gatherAppendStream=false;
			this.stream.play(streamName);
		}//playVideoStream
		
		/**
		 * Plays an attached stream from an incoming group audio stream.
		 * 
		 * @param streamName The audio stream to connect to and begin playing back. If
		 * an empty string or <em>null</em>, <code>mediaStreamName</code> is used instead. When
		 * a new stream is established for the group, the <code>mediaStreamName</code> is 
		 * automaticaly set. For outgoing connections, the <code>mediaStreamName</code> is set
		 * by the caller, but should also be available.
		 * 
		 * @return The <code>SoundTranform</code> object associated with the playing audio stream.
		 * 
		 */
		public function playAudioStream(streamName:String=null):SoundTransform {
			if (this.stream==null) {
				//Broadcast error
				return (null);
			}//if
			if ((streamName==null) || (streamName=="")) {
				streamName=this.mediaStreamName;
			}//if
			this._gatherAppendStream=false;
			this.stream.play(streamName);
			return (this.stream.soundTransform);
		}//playAudioStream
		
		/**
		 * Begins playback of a distributed stream associated with the <code>RTMFP</code> instance.
		 * <p>Unline traditional streams which are published, a gathered stream uses ordered distributed
		 * data for playback meaning that a valid FLV file (of FLV formatted data of any kind), can
		 * be streamed. The stream is appended to a <code>NetStream</code> object which can
		 * then be used as the source for video or audio playback just as a live published stream.</p>
		 * <p>Because the "data generation" <code>NetStream</code> object must have a <em>null</em> <code>NetConnection</code>,
		 * a separate <code>NetStream</code> object must be created and instructed to <code>.play(null)</code>, then passed
		 * to this method as a reference. The RTMFP will then append data into the <code>NetStream</code> object
		 * for playback.</p>
		 * 
		 * @param playbackStream A reference to the <code>NetStream</code> object, conected to a <em>null</em>
		 * <code>NetConnection</code> object, and instructed to <code>.play(null)</code> (data generation mode)
		 * into which the gathered stream will be collected for playback.
		 */
		public function playDistributedStream(playbackStream:NetStream):void {
			this._distributedStream=playbackStream;			
			this.gatherStrategy="stream";
			this.gather(true);			
		}//playDistributedStream
		
		/**
		 * Stops and closes any video / audio streams being received. Any outbound streams
		 * will have to be recreated, and any inbound streams will have to be re-attached,
		 * if playback is desired again.
		 */
		public function stopStreams():void {
			if (this._netStream!=null) {
				this._netStream.close();
				this._netStream=null;
			}//if
			this._mediaStreamPublished=false;
		}//stopStreams
		
		/**
		 * Pauses any video / audio streams being received.
		 */
		public function pauseStreams():void {
			if (this.stream!=null) {
				this.stream.pause();
			}//if
		}//pauseStreams
		
		/**
		 * Resumes any previously paused video / audio streams.
		 */
		public function resumeStreams():void {
			if (this.stream!=null) {
				this.stream.resume();
			}//if
		}//resumeStreams	
		
		/**
		 * Toggles between pause and play of any video / audio streams being received.
		 */
		public function togglePauseStreams():void {
			if (this.stream!=null) {
				this.stream.togglePause();
			}//if
		}//togglePauseStreams
		
		/**
		 * Validates a data object (usually received by the group), by creating a <code>RTMFPDataPacket</code> 
		 * object and assigning applicable parameter values to it.  
		 * 
		 * @param dataObject The object matching the properties of a standard <code>RTMFPDataPacket</code> object.
		 * Any additional properties will be ignored and any omitted properties will be set to default values.
		 * 
		 * @return A verified <code>RTMFPDataPacket</code> instance. 
		 * 
		 */
		private function validatePeerData(sourceObject:*):RTMFPDataPacket {
			var peerData:RTMFPDataPacket=new RTMFPDataPacket("message"); //default type
			if (sourceObject==null) {
				return (peerData);
			}//if
			if (sourceObject is NetStatusEvent) {
				//Data is nested within sourceObject.info.message structure...
				try {
					for (var item:String in sourceObject.info.message) {
						peerData[item]=sourceObject.info.message[item];
					}//for
				} catch (e:*) {}//catch
			} else if (sourceObject is RTMFPEvent) {				
				//Process standard return format first. Use fallbacks if data nesting is different.
				try {
					peerData.control=sourceObject.control;
				} catch (e:*) {}//catch
				try {
					peerData.data=sourceObject.data;
				} catch (e:*) {}//catch
				try {
					peerData.destination=sourceObject.destination;
				} catch (e:*) {}//catch			
				try {
					peerData.source=sourceObject.source;
				} catch (e:*) {}//catch
			}//else
			return (peerData);
		}//validatePeerData
		
		/**
		 * Strips all of the specified characters from an input string and returns the newly reformatted string.
		 *  
		 * <p>This method affects the whole string unlike the <code>stripLeadingChars</code>, <code>stripTrailingChars</code>, and
		 * <code>stripOutsideChars</code> methods.</p>
		 *  
		 * @param inputString The string from which to strip the characters. The contents of this parameter are copied
		 * so the original data is not affected.
		 * @param stripChars The character or characters to strip from <code>inputString</code>. Multiple characters may be included
		 * as a string or, alternately, this parameter may be an array of strings.
		 * 
		 * @return A newly created copy of <code>inputString</code> with all the specified characters stripped out.		
		 * 
		 */
		private function stripChars(inputString:String, stripChars:*=" "):String {
			if (inputString==null) {
				return(new String());
			}//if
			if ((inputString=="") || (inputString.length==0)) {
				return(new String());
			}//if
			if (stripChars==null) {
				return (inputString);
			}//if
			var localStripChars:String=new String();
			if (stripChars is Array) {
				for (var count:uint=0; count<stripChars.length; count++) {
					localStripChars.concat(String(stripChars[count] as String));
				}//for	
			} else if (stripChars is String) {
				localStripChars=new String(stripChars);
			} else {
				return (inputString);
			}//else
			if ((localStripChars=="") || (localStripChars.length==0)) {
				return (inputString);
			}//if
			var localInputString:String=new String(inputString);
			var returnString:String=new String();			
			for (var charCount:Number=(localInputString.length-1); charCount>=0; charCount--) {
				var currentChar:String=localInputString.charAt(charCount);
				if (localStripChars.indexOf(currentChar)<0) {
					returnString=currentChar+returnString;						
				}//if
			}//for
			return (returnString);
		}//stripChars
		
		/**
		 * @private
		 */
		private function addPeer(peerID:String):void {			
			if (this._peerList==null) {
				this._peerList=new Array();
				return;
			}//if
			for (var count:uint=0; count<this._peerList.length; count++) {
				var currentPeer:String=this._peerList[count] as String;
				if (currentPeer==peerID) {
					return;
				}//if
			}//for
			if (this.peerIsUnique(peerID)) {			
				this._peerList.push(peerID);	
			}//if
		}//addPeer
		
		/**
		 * @private
		 */
		private function removePeer(peerID:String):void {			
			if (this._peerList==null) {				
				this._peerList=new Array();
				return;
			}//if
			var updatedList:Array=new Array();
			for (var count:uint=0; count<this._peerList.length; count++) {
				var currentPeer:String=this._peerList[count] as String;
				if (currentPeer==peerID) {					
				} else {					
					if ((currentPeer!=null) && (currentPeer!="")) {
						updatedList.push(currentPeer);
					}//if
				}//else
			}//for		
			this._peerList=updatedList;		
		}//removePeer
		
		/**		 
		 * @private		 
		 */
		private function peerIsUnique(peerID:String):Boolean {
			if ((peerID==null) || (peerID=="")) {
				return (false);
			}//if
			for (var count:uint=0; count<this._peerList.length; count++) {
				var currentPeer:String=this._peerList[count] as String;
				if (currentPeer==peerID) {
					return (false);
				}//if
			}//for
			return (true);
		}//peerIsUnique
		
		/**
		 * @private
		 */
		private function createGroupSpec(groupName:String, password:String=null, passwordHash:String=passwordHashModifier, secure:Boolean=true): Boolean {			
			if ((groupName==null) || (groupName=="")) {
				return (false);
			}//if
			this._groupName = groupName;
			this._groupSpecifier=new GroupSpecifier(groupName);			
			// When set to "true", the Flash Player instance will send 
			// membership updates on a LAN to inform other LAN-connected group 
			// neighbors of their participation.
			this._groupSpecifier.ipMulticastMemberUpdatesEnabled = true;
			var serverAddressStr:String = this.serverAddress;
			serverAddressStr = serverAddressStr.toLowerCase();
			if (serverAddressStr != "rtmfp:") {				
				this._groupSpecifier.serverChannelEnabled = true; //Do we want handshaking to be automatic via server? If not we need to implement the "addBootstrapPeer" method. 
			} else {				
				this._groupSpecifier.serverChannelEnabled=false;	
				this._groupSpecifier.addIPMulticastAddress(this.ipMulticastAddress);
			}//else
			this._groupSpecifier.objectReplicationEnabled=this.dataRelay; //gather
			this._groupSpecifier.postingEnabled=true; //broadcast		
			this._groupSpecifier.routingEnabled=true; //direct
			this._groupSpecifier.multicastEnabled=true; //streams
			this._groupSpecifier.peerToPeerDisabled=false; //Must ALWAYS be false, otherwise no P2P!
			if ((password!=null) && (password!="")) {
				this._groupSpecifier.setPostingPassword(password, passwordHash);
				this._groupSpecifier.setPublishPassword(password, passwordHash);
			}//if
			return (true);
		}//createGroupSpec	
		
		//__/ CONNECTION HANDLERS \__
		
		/**
		 * @private
		 */
		private function onConnectionStatus(eventObj:NetStatusEvent):void {		
			DebugView.addText ("RTMFP.onConnectionStatus: " + eventObj.info.code);			
			switch (eventObj.info.code) {
				case "NetConnection.Connect.Success" : 
					_sessionStarted=true;
					_serverConnected=true;					
					_localPeerID=_netConnection.nearID;
					var event:RTMFPEvent=new RTMFPEvent(RTMFPEvent.CONNECT);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;		
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce = _netConnection.nearNonce;					
					this.dispatchEvent(event);					
					if (this._queueCreateGroup) {
						//group info has already been set
						this.connectGroup(null, this._openGroup, null, null, false);
					}//if						
					break;	
				//NetGroup connections are mediated by NetConnection, so it makes sense that their status is handled here.
				case "NetGroup.Connect.Success":					
					if (this._netGroup != eventObj.info.group) {
						//group does not belong to this instance
						return;
					}
					_sessionStarted=true;
					this._groupConnected=true;
					_sessionStarted=true;
					_serverConnected = true;
					_localPeerID=_netConnection.nearID;
					try {
						this._netGroup.replicationStrategy=this.gatherStrategy;
					} catch (e:*) {						
					}//catch
					event=new RTMFPEvent(RTMFPEvent.GROUPCONNECT);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.groupID = this._groupName;					
					this.dispatchEvent(event);
					var ncEvent:NetCliqueEvent = new NetCliqueEvent(NetCliqueEvent.CLIQUE_CONNECT);
					this.dispatchEvent(ncEvent);
					break;
				case "NetGroup.Connect.Failed":
					if (this._netGroup != eventObj.info.group) {
						//group does not belong to this instance
						return;
					}
					this._groupConnected=false;
					event=new RTMFPEvent(RTMFPEvent.GROUPCONNECTFAIL);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;			
					event.groupID=this._groupName;			
					this.dispatchEvent(event);	
					ncEvent = new NetCliqueEvent(NetCliqueEvent.CLIQUE_ERROR);
					this.dispatchEvent(ncEvent);
					break;
				case "NetGroup.Connect.Rejected":
					if (this._netGroup != eventObj.info.group) {
						//group does not belong to this instance
						return;
					}
					this._groupConnected=false;
					event=new RTMFPEvent(RTMFPEvent.GROUPREJECT);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;			
					event.groupID=this._groupName;				
					this.dispatchEvent(event);	
					ncEvent = new NetCliqueEvent(NetCliqueEvent.CLIQUE_ERROR);
					this.dispatchEvent(ncEvent);
					break;
				case "NetGroup.Connect.Closed":					
					if (this._netGroup != eventObj.info.group) {
						//group does not belong to this instance
						return;
					}
					this._groupConnected=false;
					event=new RTMFPEvent(RTMFPEvent.GROUPDISCONNECT);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;			
					event.groupID=this._groupName;				
					this.dispatchEvent(event);	
					ncEvent = new NetCliqueEvent(NetCliqueEvent.CLIQUE_DISCONNECT);
					this.dispatchEvent(ncEvent);
					break;
				case "NetStream.Connect.Closed":					
					this._groupConnected=false;
					event=new RTMFPEvent(RTMFPEvent.STREAMCLOSED);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;			
					//event.groupID=this._groupName;			
					this.dispatchEvent(event);					
					break;
				case "NetConnection.Connect.Closed":
					_sessionStarted=false;
					_serverConnected=false;
					event=new RTMFPEvent(RTMFPEvent.DISCONNECT);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;			
					//event.groupID=this._groupName;				
					this.dispatchEvent(event);	
					ncEvent = new NetCliqueEvent(NetCliqueEvent.CLIQUE_DISCONNECT);
					this.dispatchEvent(ncEvent);
					break;
			}//switch			
		}//onConnectionStatus
		
		/**
		 * <p>Processes messages for the P2P group.</p>
		 * 
		 * <p>A basic <code>switch</code> statement is used to determine what type of message was received. Typically,
		 * very little processing is done to the message and instead relevant details are extracted and packaged into
		 * a <code>RTMFPEvent</code> object which is then broadcast.</p>
		 * 
		 * <p>Some message codes such as "NetGroup.SendTo.Notify" are processed (in this case propagated), to ensure that
		 * P2P functionality is retained with the client.</p>
		 * 
		 * @param eventObj The <code>NetStatusEvent</code> event object received for the group status message.
		 * 
		 */
		private function onGroupStatus(eventObj:NetStatusEvent):void {
			//trace ("RTMFP.onGroupStatus: " + (eventObj.info.code));
			this._queueCreateGroup=false;			
			this._groupConnecting=false;
			switch (eventObj.info.code) {
				//__/ Single-Shot Communication and Relays \__
				case "NetGroup.Neighbor.Connect" :					
					_sessionStarted=true;					
					var event:RTMFPEvent=new RTMFPEvent(RTMFPEvent.PEERCONNECT);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;			
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;
					event.remotePeerID=eventObj.info.peerID;					
					event.remotePeerNonce=eventObj.info.neighbor;
					this.addPeer(event.remotePeerID);
					this.dispatchEvent(event);
					var ncEvent:NetCliqueEvent = new NetCliqueEvent(NetCliqueEvent.PEER_CONNECT);
					var memberObj:RTMFPCliqueMember = new RTMFPCliqueMember(eventObj.info.peerID);
					ncEvent.memberInfo = memberObj;
					ncEvent.nativeEvent = event;
					this.dispatchEvent(ncEvent);				
					break;
				case "NetGroup.Neighbor.Disconnect":
					_sessionStarted=true;
					event=new RTMFPEvent(RTMFPEvent.PEERDISCONNECT);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;			
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;					
					event.remotePeerID=eventObj.info.peerID;					
					event.remotePeerNonce=eventObj.info.neighbor;
					this.removePeer(event.remotePeerID);
					this.dispatchEvent(event);	
					ncEvent = new NetCliqueEvent(NetCliqueEvent.PEER_DISCONNECT);
					memberObj = new RTMFPCliqueMember(eventObj.info.peerID);
					ncEvent.memberInfo = memberObj;
					ncEvent.nativeEvent = event;
					this.dispatchEvent(ncEvent);
					break;
				case "NetGroup.Posting.Notify" :					
					_sessionStarted=true;
					var peerData:RTMFPDataPacket=this.validatePeerData(eventObj);
					if (peerData.control=="message") {
						event=new RTMFPEvent(RTMFPEvent.BROADCAST);
						event.statusLevel=eventObj.info.level;
						event.statusCode=eventObj.info.code;	
						event.data=peerData.data;
						event.peerData=peerData;
						event.messageID=eventObj.info.messageID;
						event.remotePeerID = peerData.source;
						event.remotePeerNonce=eventObj.info.neighbor;
						this.dispatchEvent(event);						
						ncEvent = new NetCliqueEvent(NetCliqueEvent.PEER_MSG);
						memberObj = new RTMFPCliqueMember(eventObj.info.peerID);
						var messageObj:PeerMessage = new PeerMessage(peerData.data);						
						ncEvent.memberInfo = memberObj;
						ncEvent.message = messageObj;
						ncEvent.nativeEvent = event;
						this.dispatchEvent(ncEvent);
					}//if
					break;
				case "NetGroup.SendTo.Notify" :						
					_sessionStarted=true;
					//eventObj.info.message.destination is set in the "broadcast" method. Update if it conflicts with something else.					
					peerData=this.validatePeerData(eventObj);				
					if ((eventObj.info.fromLocal == true) || (peerData.destination=="")) {
						var directDataObject:RTMFPDataPacket=new RTMFPDataPacket("message");															
						if (eventObj.info.message.control=="message") {
							event=new RTMFPEvent(RTMFPEvent.DIRECT);
							event.statusLevel=eventObj.info.level;
							event.statusCode=eventObj.info.code;	
							event.data=peerData.data;
							event.peerData=peerData;
							event.fromLocal=eventObj.info.fromLocal;
							event.localPeerID=_netConnection.nearID;
							event.localPeerNonce=_netConnection.nearNonce;
							event.serverID=_netConnection.farID;
							event.serverNonce=_netConnection.farNonce;					
							event.groupIDHash=eventObj.info.from;
							event.remotePeerID = peerData.source;		
							//trace ("->from: " + event.remotePeerID);							
							this.dispatchEvent(event);								
							ncEvent = new NetCliqueEvent(NetCliqueEvent.PEER_MSG);
							memberObj = new RTMFPCliqueMember(eventObj.info.peerID);
							messageObj = new PeerMessage(peerData.data);						
							ncEvent.memberInfo = memberObj;
							ncEvent.message = messageObj;
							ncEvent.nativeEvent = event;
							this.dispatchEvent(ncEvent);
						}//if
					} else {
						if (peerData.control=="message") {
							event=new RTMFPEvent(RTMFPEvent.ROUTE);
							event.statusLevel=eventObj.info.level;
							event.statusCode=eventObj.info.code;	
							event.data=peerData.data;
							event.peerData=peerData;
							event.fromLocal=eventObj.info.fromLocal;
							event.localPeerID=_netConnection.nearID;
							event.localPeerNonce=_netConnection.nearNonce;
							event.serverID=_netConnection.farID;
							event.serverNonce=_netConnection.farNonce;					
							event.groupIDHash=eventObj.info.from;
							event.remotePeerID=peerData.source;
							this.dispatchEvent(event);
							this.netGroup.sendToNearest(eventObj.info.message, eventObj.info.message.destination);
						}//if
					}//else
					break;
				//__/ Object-Replication / Sharing / Relay Communication \__
				case "NetGroup.Replication.Fetch.SendNotify":
					_sessionStarted=true;
					//About to send a chunk from a fetch operation. An FYI event.
					break;
				case "NetGroup.Replication.Fetch.Result":
					_sessionStarted=true;
					//Got a response from cloud with a requested chunk					
					var chunkIndex:Number=new Number(eventObj.info.index);
					if (chunkIndex==0) {
						//Header chunk
						//See format from "NetGroup.Replication.Request" below
						var chunkInfoObject:Object=eventObj.info.object;
						//chunkInfoObject includes: numChunks, chunkSize, dataSize
						this._dataShare.numberOfChunks=chunkInfoObject.numChunks;
						this._dataShare.dataChunkSize=chunkInfoObject.chunkSize;
						this._dataShare.encoding=chunkInfoObject.encoding;
						event=new RTMFPEvent(RTMFPEvent.GATHERINFO);
						event.statusLevel=eventObj.info.level;
						event.statusCode=eventObj.info.code;	
						event.dataShare=this._dataShare;
						this._netGroup.addWantObjects(1, 1);
					} else {	
						//Data chunk
						this._dataShare.addReceivedDataChunk(eventObj.info.object, chunkIndex);						
						this._netGroup.addHaveObjects(chunkIndex, chunkIndex);						
						var nextIndex:uint=this._dataShare.nextUnreceivedChunkIndex;						
						if ((nextIndex>0) && (nextIndex<=this._dataShare.numberOfChunks)) {														
							this._netGroup.addWantObjects(nextIndex, nextIndex);
							//Push data into NetStream if streaming from gathered / distributed source(s)
							if (this._gatherAppendStream) {
								if (this._distributedStream!=null) {
									this._distributedStream.appendBytes(eventObj.info.object);
								}//if
							}//if
						} else {							
							this._dataShare.distributedData.position=0; //Don't forget to reset!!
							if (this._dataShare.encoding=="AMF") {		
								this._dataShare.data=this._dataShare.distributedData.readObject();
							} else {
								this._dataShare.data=this._dataShare.distributedData;
							}//else
							event=new RTMFPEvent(RTMFPEvent.GATHER);
							event.statusLevel=eventObj.info.level;
							event.statusCode=eventObj.info.code;	
							event.data=this._dataShare.data;
							event.dataShare=this._dataShare;
							this.dispatchEvent(event);
						}//else
					}//else					
					break;
				case "NetGroup.Replication.Request":
					_sessionStarted=true;
					//Got a request from the cloud for a chunk					
					var requestIndex:Number=eventObj.info.index;
					var requestID:Number=eventObj.info.requestID;
					if (requestIndex==0) {
						var numChunks:Number=this._dataShare.numberOfChunks;
						var chunkSize:uint=this._dataShare.dataChunkSize;
						var encoding:String=this._dataShare.encoding;
						chunkInfoObject=new Object();
						chunkInfoObject.numChunks=numChunks;
						chunkInfoObject.chunkSize=chunkSize;
						chunkInfoObject.encoding=encoding;
						chunkInfoObject.dataSize=this._dataShare.distributedData.length;
						this._netGroup.writeRequestedObject(requestID, chunkInfoObject);
						event=new RTMFPEvent(RTMFPEvent.INFOREQUEST);
						event.requestID=requestID;
						event.dataShare=this._dataShare;
						this.dispatchEvent(event);
					} else {						
						var chunkData:ByteArray=this._dataShare.getChunk(requestIndex);						
						this._netGroup.writeRequestedObject(requestID, chunkData);
						event=new RTMFPEvent(RTMFPEvent.CHUNKREQUEST);
						event.requestID=requestID;
						event.dataShare=this._dataShare;
						this.dispatchEvent(event);
					}//else
					break;
				case "NetGroup.MulticastStream.PublishNotify" :
					_sessionStarted=true;
					event=new RTMFPEvent(RTMFPEvent.STREAMOPEN);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.streamID=eventObj.info.name;
					this._mediaStreamName=String(eventObj.info.name);
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;
					event.remotePeerID=eventObj.info.peerID;
					event.remotePeerNonce=eventObj.info.neighbor;					
					this.dispatchEvent(event);					
					break;
				case "NetGroup.MulticastStream.UnpublishNotify" :
					_sessionStarted=true;
					event=new RTMFPEvent(RTMFPEvent.STREAMCLOSED);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.streamID=eventObj.info.name;
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;
					event.remotePeerID=eventObj.info.peerID;
					event.remotePeerNonce=eventObj.info.neighbor;					
					this.dispatchEvent(event);					
					break;
			}//switch						
		}//onGroupStatus
		
		/**
		 * Handles <code>NetStatusEvent</code> events similarly to <code>onGroupStatus</code> except that it
		 * operates on the <code>stream</code> instance associated with this class instance.
		 *  
		 * @param eventObj A standard <code>NetStatusEvent</code> event object.
		 * 
		 */
		public function onStreamStatus(eventObj:NetStatusEvent):void {
			this._queueCreateGroup=false;	
			_sessionStarted=true;		
			switch (eventObj.info.code) {
				case "NetStream.Play.Start" : 
					var event:RTMFPEvent=new RTMFPEvent(RTMFPEvent.STREAMOPEN);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.streamID=this._mediaStreamName;
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;
					this.dispatchEvent(event);			
					break;
				case "NetStream.Play.Stop" : 
					event=new RTMFPEvent(RTMFPEvent.STREAMSTOP);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.streamID=this._mediaStreamName;
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;
					this.dispatchEvent(event);			
					break;
				case "NetStream.Publish.Start" :
					this._mediaStreamPublished=true;
					_sessionStarted=true;
					event=new RTMFPEvent(RTMFPEvent.STREAMOPEN);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.streamID=this._mediaStreamName;					
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;					
					this.dispatchEvent(event);	
					break;
				case "NetStream.Publish.BadName" :
					this._mediaStreamPublished=false;
					event=new RTMFPEvent(RTMFPEvent.STREAMPUBLISHFAIL);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.streamID=this._mediaStreamName;
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;
					this.dispatchEvent(event);		
					break;
				case "NetStream.Play.Reset" : 
					event=new RTMFPEvent(RTMFPEvent.STREAMRESET);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.streamID=this._mediaStreamName;
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;
					this.dispatchEvent(event);		
					break;
				case "NetStream.MulticastStream.Reset" : 
					event=new RTMFPEvent(RTMFPEvent.STREAMRESET);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.streamID=this._mediaStreamName;
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;
					this.dispatchEvent(event);		
					break;
				case "NetStream.Connect.Success" :
					this._mediaStreamPublished=true;
					event=new RTMFPEvent(RTMFPEvent.STREAMOPEN);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.streamID=eventObj.info.stream;
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;
					this.dispatchEvent(event);							
					break;
				case "NetStream.Connect.Closed" :
					this._mediaStreamPublished=false;
					this._netStream.removeEventListener(NetStatusEvent.NET_STATUS, this.onStreamStatus);
					if (this._netStream["dispose"] is Function) {
						this._netStream["dispose"]();
					}//if
					this._netStream=null;
					event=new RTMFPEvent(RTMFPEvent.STREAMCLOSED);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.streamID=eventObj.info.stream;
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;
					this.dispatchEvent(event);							
					break;
				case "NetStream.Connect.Failed" :
					this._mediaStreamPublished=false;
					this._netStream.removeEventListener(NetStatusEvent.NET_STATUS, this.onStreamStatus);
					if (this._netStream["dispose"] is Function) {
						this._netStream["dispose"]();
					}//if
					this._netStream=null;					
					event=new RTMFPEvent(RTMFPEvent.STREAMOPENFAIL);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.streamID=eventObj.info.stream;
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;
					this.dispatchEvent(event);							
					break;					
				case "NetStream.Connect.Rejected" :
					this._mediaStreamPublished=false;
					this._netStream.removeEventListener(NetStatusEvent.NET_STATUS, this.onStreamStatus);
					if (this._netStream["dispose"] is Function) {
						this._netStream["dispose"]();
					}//if
					this._netStream=null;
					event=new RTMFPEvent(RTMFPEvent.STREAMOPENFAIL);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.streamID=eventObj.info.stream;
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;
					this.dispatchEvent(event);							
					break;
				case "NetStream.Play.StreamNotFound" :
					this._mediaStreamPublished=false;
					this._netStream.removeEventListener(NetStatusEvent.NET_STATUS, this.onStreamStatus);
					if (this._netStream["dispose"] is Function) {
						this._netStream["dispose"]();
					}//if
					this._netStream=null;
					event=new RTMFPEvent(RTMFPEvent.STREAMOPENFAIL);
					event.statusLevel=eventObj.info.level;
					event.statusCode=eventObj.info.code;
					event.streamID=this._mediaStreamName;
					event.localPeerID=_netConnection.nearID;
					event.localPeerNonce=_netConnection.nearNonce;
					event.serverID=_netConnection.farID;
					event.serverNonce=_netConnection.farNonce;
					this.dispatchEvent(event);							
					break;				
			}//switch
		}//onStreamStatus
		
		/*
		public static function get connected():Boolean {
			if (_netConnection==null) {
				return (false);
			}//if
			return (_netConnection.connected);
		}//get connected
		*/
		
		public function get attachedCamera():Camera {
			return (this._streamCamera);
		}//get attachedCamera
		
		public function get attachedMicrophone():Microphone {
			return (this._streamMicrophone);
		}//get attachedMicrophone
		
		public function get mediaStreamName():String {
			return (this._mediaStreamName);
		}//get mediaStreamName
		
		public function get connectionAddress():String {
			this._connectionAddress=this.serverAddress+this.developerKey;
			return (this._connectionAddress);
		}//get connectionAddress
		
		public function get serverAddress():String {
			if ((this._serverAddress==null) || (this._serverAddress=="")) {
				if (this.defaultFallback) {
					this._serverAddress=this.defaultServerAddress;
				}//if
			}//if
			return (this._serverAddress);
		}//get serverAddress
		
		public function set serverAddress(serverSet:String):void {
			this._serverAddress=serverSet;
		}//set serverAddress
		
		public function get ipMulticastAddress():String {
			if ((this._ipMulticastAddress == null) || (this._ipMulticastAddress == "")) {
				this._ipMulticastAddress = defaultIPMulticasrAddress;
			}//if
			return (this._ipMulticastAddress);
		}
		
		public function set ipMulticastAddress(addressSet:String):void {			
			this._ipMulticastAddress = addressSet;			
		}
		
		public function get developerKey():String {
			if ((this._developerKey==null) || (this._developerKey=="")) {
				if (this.defaultFallback) {
					this._developerKey=this.defaultDeveloperKey;
				}//if
			}//if
			return (this._developerKey);
		}//get developerKey
		
		/**
		 * 
		 * @param strategySet The data gathering strategy for distributed / relayed / shared / replicated data with
		 * a group. This value should be set to match the target application for which it's being used, and should
		 * ideally match one of the <code>NetGroupReplicationStrategy</code> constants. Use a LOWEST_FIRST strategy
		 * when streaming data or when data ordering is important. When data can be distributed piecemeal, such as in
		 * file sharing applications, the RAREST_FIRST strategy is the best to employ to ensure that data is both 
		 * available to the swarm and to ensure easiest completion of the transfer.
		 * <p>This method attempts to more forgiving when specifying the strategy by providing support for a variety
		 * of alternate naming conventions. For example:
		 * <code>"lowest" = "LowestFirst" = " lowest First" = NetGroupReplicationStrategy.LOWEST_FIRST</code>
		 * 
		 */
		public function set gatherStrategy(strategySet:String):void {		
			this._gatherStrategy=new String();
			this._gatherStrategy=strategySet;
			this._gatherStrategy=this.stripChars(this._gatherStrategy, SEPARATOR_RANGE);
			this._gatherStrategy=this._gatherStrategy.toLowerCase();
			switch (this._gatherStrategy) {
				case "lowestfirst": 
							this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "lowest": 
							this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;							
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "low":
							this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;		
				case "first":
						this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
						if (this._netGroup!=null) {
							this._netGroup.replicationStrategy=this._gatherStrategy;
						}//if
						break;		
				case "numbered": 
							this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "number": 
							this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "num": 
							this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "indexed": 
							this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "index": 
							this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "ind": 
							this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "ordered": 
							this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "order": 
							this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "ord": 
							this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "stream": 
						this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
						if (this._netGroup!=null) {
							this._netGroup.replicationStrategy=this._gatherStrategy;
						}//if
						break;
				case "streaming": 
						this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
						if (this._netGroup!=null) {
							this._netGroup.replicationStrategy=this._gatherStrategy;
						}//if
						break;
				case "rarestfirst": 
							this._gatherStrategy=NetGroupReplicationStrategy.RAREST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "rarest": 
							this._gatherStrategy=NetGroupReplicationStrategy.RAREST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;				
				case "rare": 
							this._gatherStrategy=NetGroupReplicationStrategy.RAREST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "file": 
							this._gatherStrategy=NetGroupReplicationStrategy.RAREST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "share": 
							this._gatherStrategy=NetGroupReplicationStrategy.RAREST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				case "distributed": 
							this._gatherStrategy=NetGroupReplicationStrategy.RAREST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
				default : 
							this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
							if (this._netGroup!=null) {
								this._netGroup.replicationStrategy=this._gatherStrategy;
							}//if
							break;
			}//switch
		}//gatherStrategy
		
		/**		 
		 * @private		 
		 */
		public function get gatherStrategy():String {
			if ((this._gatherStrategy==null) || (this._gatherStrategy=="")) {
				this._gatherStrategy=new String();
				this._gatherStrategy=NetGroupReplicationStrategy.LOWEST_FIRST;
			}//if
			return (this._gatherStrategy);
		}//get gatherStrategy
		
		public static function get netConnection():NetConnection {
			return (_netConnection);
		}//get netConnection
		
		public function get rendezvousConnected():Boolean {
			return (_serverConnected);
		}//get rendezvousConnected

		public function get groupConnected():Boolean {
			return (this._groupConnected);
		}//get groupConnected
		
		public function get groupConnecting():Boolean {
			return (this._groupConnecting);
		}//get groupConnecting
		
		public function get mediaStreamPublished():Boolean {
			return (this._mediaStreamPublished);
		}//get mediaStreamPublished
		
		public function get stream():NetStream {
			if (_netConnection==null) {
				return (null);
			}//if
			if (_netConnection.connected==false) {
				return (null);
			}//if
			if (this._netStream==null) {
				if (this._openGroup) {
					//Can post
					this._netStream=new NetStream(_netConnection,this.groupSpecifier.groupspecWithAuthorizations());					
				} else {
					//Receive only
					this._netStream=new NetStream(_netConnection,this.groupSpecifier.groupspecWithoutAuthorizations());					
				}//else	
				this._netStream.addEventListener(NetStatusEvent.NET_STATUS, this.onStreamStatus);	
			}//if
			return (this._netStream);
		}//get stream
		
		/** 
		 * @return <em>True</code> is the session has been started (a connection attempt has been requested). This
		 * value does not indicate that a connection is necessarily opened.
		 */
		public function get sessionStarted():Boolean {
			return (_sessionStarted);
		}//get sessionStarted
		
		/** 
		 * @param keySet The developer key to use with the rtmfp.net server (not currently used at any other time). 
		 */
		public function set developerKey(keySet:String):void {
			this._developerKey=keySet;
		}//set developerKey
		
		/** 
		 * @return A reference to the internal <code>NetGroup</code> object being used for P2P communication.
		 */
		public function get netGroup():NetGroup {
			return (this._netGroup);
		}//get netGroup
		
		/** 
		 * @return The name of the group, as specified when invoking the <code>connectGroup</code> method.
		 */
		public function get groupName():String {
			return (this._groupName);
		}//get groupName
		
		/** 
		 * @return The <code>NetGroupInfo</code> object of associated <code>NetGroup</code> object, or 
		 * <em>null</em> if the group doesn't exist. 
		 */
		public function get netGroupInfo():NetGroupInfo {
			if (this._netGroup==null) {
				return (null);
			}//if
			return (this._netGroup.info);
		}//get netGroupInfo
		
		/** 
		 * @return The neighbour count value of the same name in the associated <code>NetGroup</code>
		 * object, or <em>null</em> none exists. 
		 */
		public function get neighbourCount():Number {
			if (this._netGroup==null) {				
				return (0);
			}//if
			return (this._netGroup.neighborCount);
		}//get neighbourCount
		
		/** 
		 * @return The estimated member count value of the same name in the associated <code>NetGroup</code>
		 * object, or <em>null</em> none exists. 
		 */
		public function get estimatedMemberCount():Number {
			if (this._netGroup==null) {
				return (0);
			}//if
			return (this._netGroup.estimatedMemberCount);
		}//get estimatedMemberCount
		
		/** 
		 * @return The <code>GroupSpecifier</code> object created and used with the local <code>NetGroup</code>
		 * instance to connect to the group, or <em>null</em> if none exists.
		 */
		public function get groupSpecifier():GroupSpecifier {
			return (this._groupSpecifier);
		}//get groupSpecifier
		
		/** 
		 * @return The dynamic encrypted local peer ID, as assigned by the rendezvous server to the local RTMFP 
		 * connection.
		 */
		public function get localPeerID():String {
			return (_localPeerID);
		}//get localPeerID		
		
		/** 
		 * @return An array of unique peer IDs connected directly to this <code>RTMFP</code> instance. 
		 */
		public function get peerList():Array {
			return (this._peerList);
		}//get peerList
		
		/** 
		 * @return <em>True</em> if this instance may act as a data relay for shared / distributed data,
		 * <code>false</code> otherwise.
		 */
		public function get dataRelay():Boolean {
			return (this._dataRelay);
		}//get dataRelay
		
		public function set dataRelay(relaySet:Boolean):void {
			this._dataRelay=relaySet;
			if (this._groupSpecifier!=null) {
				this._groupSpecifier.objectReplicationEnabled=relaySet;
			}//if
		}//set dataRelay	
		
	}

}
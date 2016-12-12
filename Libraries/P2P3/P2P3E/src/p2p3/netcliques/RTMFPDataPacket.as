/**
* Generic data transmisison packet for use with Adobe RTMFP networking.
* 
* Adapted from the SWAG ActionScript toolkit: https://code.google.com/p/swag-as/
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.netcliques  {
	
	import flash.utils.ByteArray;
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;
	
	public class RTMFPDataPacket extends Proxy {
		
		/**
		 * Defines the type of data being associated with this data object.
		 * <p>This allows the retrieving end to determine how to treat the received data.</p> 
		 */		
		private var _control:String=new String();		
		/**
		 * Determines the target destination (typically peer ID), to which to send the associated data to.
		 * <p>If <code>null</code> or blank, this typically denotes a broadcast object (to be sent to all peers).</p>  
		 */
		private var _destination:String=new String();
		/**
		 * The source (sender) peer ID.
		 */
		private var _source:String=new String();
		/**
		 * The data of the associated cloud object.
		 * <p>Unlike the other properties which are used for routing or control operations, this object contains the actual
		 * data to be sent to the group or associated peers. For this reason it's untyped and may contain any valid Flash data type.</p>  
		 */
		private var _data:*;
		
		
		public function RTMFPDataPacket(controlType:String=null) {
			this.setDefaults();
			if (controlType!=null) {
				this.control=controlType;
			}//if
		}//constructor
		
		override flash_proxy function setProperty(name:*, value:*):void {
			trace ("RTMFPDataPacket doesn't support the property \""+name+"\"");
		}//setProperty
		
		override flash_proxy function getProperty(name:*):* {
			trace ("RTMFPDataPacket doesn't have the property \""+name+"\"");
			return (null);
		}//getProperty
		
		public function set control(controlSet:String):void {
			this._control=controlSet;
		}//set control
		
		public function get control():String {
			return (this._control);
		}//get control
		
		public function set destination (destSet:String):void {
			this._destination=destSet;
		}//set destination
		
		public function get destination():String {
			return (this._destination);
		}//get destination	
		
		public function set source (sourceSet:String):void {
			this._source=sourceSet;
		}//set source
		
		public function get source():String {
			return (this._source);
		}//get source	
		
		public function set data(dataSet:*):void {
			this._data=dataSet;
		}//set data
		
		public function get data():* {
			return (this._data);
		}//get data
		
		private function setDefaults():void {
			this._destination="";		
		}//setDefaults
		
	}

}
/**
* Shared and distrubuted data handler for RTMFP networking.
* 
* Adapted from the SWAG ActionScript toolkit: https://code.google.com/p/swag-as/
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package p2p3.netcliques 
{
	
	import flash.errors.EOFError;
	import flash.utils.ByteArray;
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;
		
	public class RTMFPDataShare extends Proxy 	
	{
		
		/**
		 * The default data chunk size for chunked data. This value is assigned to the <code>_dataChunkSize</code> property
		 * at instantiation. 
		 */
		public const defaultChunkSize:uint=16383;		
		/**
		 * The data chunk size. Data will be chunked into pieces of this size (in bytes), before being distributed.
		 * <p>This value can be set manually but it's a good idea to keep it at the defaul size in order to prevent too much overhead
		 * (where the data and the data header are almost the same size).</p>
		 * <p>At the same time, it's a good idea not to create chunks that are too large since UDP is a lossy protocol and re-sending
		 * large chunks can be equally wasteful.</p>
		 */
		private var _dataChunkSize:uint;
		/**
		 * The data encoding applied to the <code>_distributedData</code> object. While the object is a <code>ByteArray</code>,
		 * it may contain either actual <code>ByteArray</code> data (in which case it can be used directly), or it may contain
		 * AMF-serialized data which will require it to be de-serialized before use. The two valid values for this property are
		 * currently "ByteArray" and "AMF".
		 * <p>New values may be added in the future to support other data types that can be made available while partially assembled
		 * (XML, for example).</p> 
		 */
		private var _dataEncoding:String;
		/**
		 * The number of chunks into which the _distributedDataArray object can be split. This is calculated as:
		 * Math.round(_distributedData.length / _dataChunkSize);
		 * If this is a receiving data object, this value is simply set by the associated <code>SwagP2PCloud</code> instance.
		 */
		private var _numberOfChunks:Number=0;
		/**
		* 
		 * The data to be deistributed, or being received, stored in a binary array.
		 * <p>Depending on the type of encoding, this data may either be used as-is, or it may need to be de-serialized before use.</p>
		* 
		*/
		private var _distributedData:ByteArray=null;
		/**
		 * Stores boolean flags for all the received indexes in the distributed data array. This allows for out-of-order
		 * receipt of indexed data and may be compared against the _numberOfChunks property to see if all data has been
		 * successfully received. 
		 */
		private var _receivedIndexes:Array=new Array();
		/**
		 * The de-serialized data from the <code>_distributedData</code> object.
		 * <p>This data will only be present when all of the data chunks are received, and is typically set by the associated 
		 * <code>SwagCloud</code> instance.</p>
		 * <p>Depending on the encoding, the data may either be a <code>ByteArray</code> object, or it may be a native data object
		 * of some sort.</p>  
		 */		
		private var _data:*;
		
		
		/**
		 * The default contructor for the class. 
		 */
		public function RTMFPDataShare() {
			this.setDefaults();
		}//constructor
		
		/**
		 * 
		 * @param chunkSize The chunk size into which to split the serialized binary data into. This value should
		 * strike a balance between not-to-small so that bandwidth is not being wasted on control data, and not too
		 * large so that packets that are not received are not too large when needing to be resent. 
		 * 
		 */
		public function set dataChunkSize(chunkSize:uint):void {			
			this._dataChunkSize=chunkSize;
		}//set dataChunkSize
		
		/**		 
		 * @private 		 
		 */
		public function get dataChunkSize():uint {			
			return (this._dataChunkSize);
		}//get dataChunkSize
		
		/**
		 * Adds a received data chunk to the distributed data chunks array as the data is received.
		 * <p>Once completed, the whole <code>ByteArray</code> object can be de-serialized into a native Flash data object.</p>
		 *  
		 * @param data The data to add to the chunked <code>ByteArray</code>.
		 * @param index The index at which to add the data. This is calculated as an offset with the data chunk size to set
		 * the specific byte offset within the <code>ByteArray</code> object.
		 * 
		 */
		public function addReceivedDataChunk(data:ByteArray, index:Number):void {
			if (this._distributedData==null) {
				this._distributedData=new ByteArray();
			}//if
			if (index>0) {
				this._distributedData.position=(index-1)*this.dataChunkSize;
				this._distributedData.writeBytes(data);
			}//if
			this.receivedIndexes[index]=true;
		}//addReceivedDataChunk		
		
		public function get nextUnreceivedChunkIndex():uint {
			if (this._receivedIndexes==null) {
				return (0);
			}//if
			for (var count:uint=1; count<=this._receivedIndexes.length; count++) {
				var currentIndex:Boolean=this._receivedIndexes[count] as Boolean;
				if (currentIndex==false) {
					return (count);
				}//if
			}//for
			return (0);
		}//get nextUnreceivedChunkIndex
		
		private function createReceivedIndexesArray():void {
			this._receivedIndexes=new Array();
			for (var count:uint=1; count<=this.numberOfChunks; count++) {
				this._receivedIndexes[count]=false;
			}//for
		}//createReceivedIndexesArray
		
		private function get receivedIndexes():Array {
			if (this._receivedIndexes==null) {
				this._receivedIndexes=new Array();
				this.createReceivedIndexesArray();
			}//if
			return (this._receivedIndexes);
		}//get receivedIndexes
		
		/**
		 * Chunks the supplied data into pieces. The <code>dataChunkSize</code> property should be set to the desired
		 * value before calling this method.
		 *  
		 * @param data The data to process into chunks for sending. This simply serializes the initial data object into
		 * AMF serialized data stored as a ByteArray, which will then be sent in pieces as requested.
		 * 
		 * @return A ByteArray object containing the AMF serialized data.
		 * 
		 */
		public function chunkData(data:*):ByteArray {			
			if (data is ByteArray) {
				this._dataEncoding="ByteArray";
				this._distributedData=data;
			} else {
				if (this._distributedData==null) {
					this._distributedData=new ByteArray();
				}//if
				this._dataEncoding="AMF";
				this._distributedData.writeObject(data);				
			}//else			
			var dividedCount:Number=this._distributedData.length / this._dataChunkSize;			
			this._numberOfChunks=Math.floor(this._distributedData.length / this._dataChunkSize);				
			if (this._numberOfChunks!=dividedCount) {
				//We need one extra chunk for leftover data since division wasn't clean (data's left over).
				this._numberOfChunks+=1;				
			}//if			
			return (this._distributedData);
		}//chunkData	
		
		/**
		 * @return The type of encoding for the data stored in the <code>distributedData</code> array. Valid values
		 * are currently "ByteArray" which means the data is binary to begin with and is stored as-is, or "AMF" meaning
		 * it's AMF-serialized native data.		 
		 */
		public function get encoding():String {
			if (this._dataEncoding==null) {
				this._dataEncoding="ByteArray";
			}//if
			return (this._dataEncoding);
		}//get encoding
		
		/**		 
		 * @private		 
		 */
		public function set encoding(encodeSet:String):void {
			this._dataEncoding=encodeSet;
		}//set encoding
		
		public function getChunk(index:uint):ByteArray {			
			var returnArray:ByteArray=new ByteArray();
			var dataOffset:uint=(index-1)*this.dataChunkSize;
			this._distributedData.position=dataOffset;
			try {
				this.distributedData.readBytes(returnArray, 0, this.dataChunkSize);
			} catch (e:EOFError) {
				//Last chunk of data but less than the size of a whole chunk
				this.distributedData.readBytes(returnArray, 0, 0);
			}//catch			
			return (returnArray);
		}//getChunk
		
		/**
		 *  
		 * @return The number of data chunks that the associated distributed data <code>ByteArray</code> object is split into.
		 * <p>If this is a sending object, this value will be calculated when the data is chunked, otherwise it will simply be set
		 * by the receiving <code>NetGroup</code> object.</p>
		 * 
		 */
		public function get numberOfChunks():Number {
			if (this._distributedData==null) {
				return (0);
			}//if
			return (this._numberOfChunks);
		}//get numberOfChunks
		
		/**
		 * @private
		 */
		public function set numberOfChunks(chunkSet:Number):void {
			this._numberOfChunks=chunkSet;			
			this.createReceivedIndexesArray();
		}//set numberOfChunks
		
		/**		 
		 * @return The number of unreceived, or outstanding chunks still waiting to be received. This value should never
		 * be greater than <code>numberOfChunks</code>.		 
		 */
		public function get numberOfUnreceivedChunks():uint {
			if (this._receivedIndexes==null) {
				return (0);
			}//if
			var chunkCount:uint=new uint(0);
			for (var count:uint=1; count<=this._receivedIndexes.length; count++) {
				var currentIndex:Boolean=this._receivedIndexes[count] as Boolean;
				if (currentIndex==false) {
					chunkCount++;
				}//if
			}//for
			return (chunkCount);
		}//get numberOfUnreceivedChunks
		
		/**		 
		 * @return The number of chunks stored in the received data buffer. This value should never be greater than 
		 * <code>numberOfChunks</code>.		 
		 */
		public function get numberOfReceivedChunks():uint {
			if (this._receivedIndexes==null) {
				return (0);
			}//if
			var chunkCount:uint=new uint(0);
			for (var count:uint=1; count<=this._receivedIndexes.length; count++) {
				var currentIndex:Boolean=this._receivedIndexes[count] as Boolean;
				if (currentIndex==true) {
					chunkCount++;
				}//if
			}//for
			return (chunkCount);
		}//get numberOfReceivedChunks
		
		/**
		 * 
		 * @return The binary data either to be sent or being received. Depending on the type of 
		 * encoding, this data may either be a non-serialized <code>ByteArray</code> object or a serialized
		 * AMF object. Either way, this data may be read directly as its being received although any serialized
		 * data may not be accessible until all the chunks have been filled. 
		 * 
		 */
		public function get distributedData():ByteArray {
			if (this._distributedData==null) {
				this._distributedData=new ByteArray();
			}//if
			return (this._distributedData);
		}//get distributedData
		
		/**		 
		 * 
		 * @param dataSet The de-serialized or raw data associated with the share object. Depending on the type of
		 * encoding, this may either be a native <code>ByteArray</code> object or it may be a de-serialized native
		 * Flash data object of some sort.
		 * <p>This data isn't available until all data chunks have been received (if receiving). Setting this property
		 * causes the <code>distributedData</code> array to be filled with chunked data using the current chunk size setting.</p>
		 * 		 
		 */
		public function set data(dataSet:*):void {
			this._data=dataSet;			
			this.chunkData(dataSet);
		}//set data
		
		/**		 
		 * @private 		 
		 */
		public function get data():* {
			return (this._data);
		}//get data
		
		override flash_proxy function setProperty(name:*, value:*):void {
			trace ("RTMFPDataShare doesn't support the property \""+name+"\"");
		}//setProperty
		
		override flash_proxy function getProperty(name:*):* {
			trace ("RTMFPDataShare doesn't have the property \""+name+"\"");
			return (null);
		}//getProperty
		
		private function setDefaults():void {
			this._receivedIndexes=new Array();
			this._dataChunkSize=this.defaultChunkSize;
		}//setDefaults
		
	}

}
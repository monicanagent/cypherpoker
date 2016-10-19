/**
* Events dispatched from the Ethereum class.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events {
	
	import flash.events.Event;
	
	public class EthereumEvent extends Event {
		
		//Dispatched at when a contract group (which may only have a single contract), has been deployed.
		public static const CONTRACTSDEPLOYED:String = "Events.EthereumEvent.CONTRACTSDEPLOYED";		
		//Dispatched at regular intervals when synchronization monitoring is enabled (via monitorSyncStatus).		
		public static const CLIENTSYNCEVENT:String = "Events.EthereumEvent.CLIENTSYNCEVENT";
		
		/**
		 * syncInfo will contain synchronization data for CLIENTSYNCEVENT events, otherwise null.
		 * 
		 * Contained properties include (see Ethereum.onMonitorSyncStatus):
		 * 		status (Number): -2 means connecting to peers/network, -1 means waiting for first sync message, 1 means syncing, 
		 * 					and 2 means fully synched (awaiting new blocks)
		 * 		statusText (String): A human-readable text version of the status.
		 * 		percentComplete (Number): The synchronization percentage that has completed.
		 *  	percentRemaining (Number): The synchronization percentage that is remaining.
		 *      blocksRemaining (Number): The number of blocks remaining to synchronize. Refer to the web3.eth.syncing object for additional 
		 * 					synchronization details.
		 * 		blocksPerSecond (Number): The average number of blocks transferred per second during the last sync status check.
		 * 		averageBlocksPerSecond (Number): The smoothed average number of blocks transferred, defined as: 
		 * 					averageBlocksPerSecond = (blocksPerSecond + averageBlocksPerSecond) / 2
		 * 	
		 */
		public var syncInfo:Object = null; 
		
		public function EthereumEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
		{ 
			if (type == CLIENTSYNCEVENT) {
				this.syncInfo = new Object();
				this.syncInfo.status = -2;
				this.syncInfo.statusText = "Waiting for peer connections";
				this.syncInfo.percentComplete = 0;
				this.syncInfo.percentRemaining = 0;
				this.syncInfo.blocksRemaining = 0;
				this.syncInfo.blocksPerSecond = 0;
				this.syncInfo.averageBlocksPerSecond = 0;
			}
			super(type, bubbles, cancelable);
			
		} 
		
		public override function clone():Event 
		{ 
			return new EthereumEvent(type, bubbles, cancelable);
		} 
		
		public override function toString():String 
		{ 
			return formatToString("EthereumEvent", "type", "bubbles", "cancelable", "eventPhase"); 
		}
		
	}
	
}
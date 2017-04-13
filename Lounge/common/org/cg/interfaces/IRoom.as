/**
* Interface for a room instance implementation as used by an IRoomManager implementation.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {
	
	import p2p3.interfaces.INetClique;
	
	public interface IRoom {
		
		//The clique through which the room communicates
		function get clique():INetClique;		
		//Destroy the instance (disconnect and clean up the clique, clear all data and references)
		function destroy():void;
	}
}
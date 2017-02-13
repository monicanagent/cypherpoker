/**
* Interface for a room manager implementation, usually used by an ILounge implementation to manage rooms (chat groups, tables, etc.)
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {
	
	import org.cg.interfaces.IRoomProfile;
	import org.cg.interfaces.IRoom;
	import p2p3.interfaces.INetClique;
	
	public interface IRoomManager {
		
		//Returns all the IRoom implementation instances being managed by this instance.
		function get rooms():Vector.<IRoom>;
		//The main clique connection to be used to establish new rooms. Implementation should reset itself on set.
		function get clique():INetClique;
		function set clique(cliqueRef:INetClique):void;
		//The IRoomProfile implementation instance to use within the manager and new IRoom instances.
		function get profile():IRoomProfile;
		function set profile(profileSet:IRoomProfile):void;
		//Destroy the instance, clean up references, remove listeners, etc.
		function destroy():void;
	}
}
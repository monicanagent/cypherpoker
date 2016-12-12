/**
* Interface for a status report object implementation.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {	
	
	import org.cg.interfaces.IStatusEvent;
	
	public interface IStatusReport {
		
		function get message():String; //Human-readable status message.
		function get data():*; //Optional data included with the status.		
		function get eventType():String; //The event type of the output of the createEvent function.
		function createEvent():IStatusEvent; //Create a status event associated with this report object.
		function report():void; //Report the event instance using the Status class.
	}	
}
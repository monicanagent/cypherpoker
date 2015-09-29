/**
* Interface for a centralized status event implementation.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces 
{	
	import org.cg.interfaces.IStatusReport;
	
	public interface IStatusEvent 
	{		
		//The status report associated with the event
		function get sourceStatusReport():IStatusReport; 
		function set sourceStatusReport(sourceSet:IStatusReport):void;
	}
}
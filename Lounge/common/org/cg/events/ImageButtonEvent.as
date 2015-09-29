/**
* Events dispatched from an ImageButton instance.
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events 
{
	import flash.events.Event;
	
	public class ImageButtonEvent extends Event 
	{
	
		public static const CLICKED:String = "Event.ImageButtonEvent.CLICKED";
		
		public function ImageButtonEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) 
		{
			super(type, bubbles, cancelable);
			
		}
	}
}
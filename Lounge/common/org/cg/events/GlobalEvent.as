/**
* Event encapsulation class for GlobalDispatcher events.
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events 
{
	
	import org.cg.interfaces.IGlobalEvent;
	
	public class GlobalEvent implements IGlobalEvent 
	{
		
		private var _source:*= null;
		private var _type:*= null;
		private var _method:*= null;
		
		public function GlobalEvent(eventType:String = null) 
		{
			type=eventType;
		}
				
		public function get source():* 
		{
			return (_source);
		}
		
		public function set source(value:*):void 
		{
			_source = value;
		}
		
		public function get type():String 
		{
			return (_type);
		}
		
		public function set type(typeSet:String):void 
		{
			_type = typeSet;
		}
		
		public function get method():Function 
		{
			return (_method);
		}
		
		public function set method(mSet:*):void 
		{
			_method = mSet;
		}
	}
}
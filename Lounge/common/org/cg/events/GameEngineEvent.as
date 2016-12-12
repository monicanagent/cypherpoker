/**
* Events dispatched by a dynamically loaded game engine.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.events {
	
	public class GameEngineEvent extends GlobalEvent {
		
		public static const CREATED:String = "Event.GameEngineEvent.CREATED";
		public static const READY:String = "Event.GameEngineEvent.READY";
		
		public function GameEngineEvent(eventType:String = null) {
			super(eventType);			
		}
	}
}
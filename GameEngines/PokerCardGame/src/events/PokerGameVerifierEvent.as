/**
* Events broadcast by PokerGameVerifier instances.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
package events {
	
	import flash.events.Event;
	
	public class PokerGameVerifierEvent extends Event {
		
		//Game verification successfully completed. If all reported values match calculated/verified values then the "conditional" flag is set to false.
		//If the winner matches the declared winner but some of the values reported don't match calculated/verified values then the "conditional" flag
		//is set to true.
		public static const SUCCESS:String = "Event.PokerGameVerifierEvent.SUCCESS";
		//Game verification failed. If a smart contract is associated with the verifier this event is dispatched after both local and contract
		//values have been verified, otherwise only local values should be assumed to have failed verification.
		public static const FAIL:String = "Event.PokerGameVerifierEvent.FAIL";
		//The verifier instance is about to be destroyed in preparation for removal from memory. The values contained in the verifier are cleared
		//immediately after this event is dispatched.
		public static const DESTROY:String = "Event.PokerGameVerifierEvent.DESTROY";
		
		//Set to true on SUCCESS events where the reported winner matches the verified winner but where the reported hand value/score
		//does not match the verified value/score. Always false on FAIL event.
		public var conditional:Boolean = false;
		
		public function PokerGameVerifierEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) { 
			super(type, bubbles, cancelable);			
		}		
	}	
}
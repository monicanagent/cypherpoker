/**
* Events broadcast by PokerBettingModule instances.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package events {	
	
	import flash.events.Event;
	import interfaces.IPokerPlayerInfo;
	
	public class PokerBettingEvent extends Event {
		
		//A new betting round has started.
		public static const BETTING_STARTED:String = "Event.PokerBettingEvent.BETTING_STARTED";
		//The betting UI for the local (self) player should be enabled. This event includes the current "amount", "minimumAmount", and "maximumAmount".
		public static const BETTING_ENABLE:String = "Event.PokerBettingEvent.BETTING_ENABLE";
		//The betting UI for the local (self) player should be disabled.
		public static const BETTING_DISABLE:String = "Event.PokerBettingEvent.BETTING_DISABLE";
		//Betting control has been passed to a player ("sourcePlayer"). The user interface should not necessarily be enabled on this event (for example,
		//this action may be part of an automated all-in action).
		public static const BETTING_PLAYER:String = "Event.PokerBettingEvent.BETTING_PLAYER";
		//Blind values have just been updated, usually as a result of the blinds timer expiring or a message from the dealer.
		public static const BETTING_NEW_BLINDS:String = "Event.PokerBettingEvent.BETTING_NEW_BLINDS";
		//The blinds timer has changed. The new remaining time value is included in the "blindsTime" property is a default-formatted string. 
		//Refer to the sending PokerBettingModule's "blindsTimer" property for custom formatting options.
		public static const BLINDS_TIMER:String = "Event.PokerBettingEvent.BLINDS_TIMER";
		//The current betting cycle has ended.
		public static const BETTING_DONE:String = "Event.PokerBettingEvent.BETTING_DONE";
		//The final bet of the game has been committed.
		public static const BETTING_FINAL_DONE:String = "Event.PokerBettingEvent.BETTING_FINAL_DONE";
		//Round has completed (all players have broadcast crypto keys and game results -- new dealer may now be assumed).
		public static const ROUND_DONE:String = "Event.PokerBettingEvent.ROUND_DONE";
		//A bet value ("amount") for a player ("sourcePlayer") has been updated. This value has not yet been committed.
		public static const BET_UPDATE:String = "Event.PokerBettingEvent.BET_UPDATE";
		//A bet value ("amount") for a player ("sourcePlayer") has been committed or finalized. No further betting updates from this player should 
		//be accepted until they are allowed to bet again.
		public static const BET_COMMIT:String = "Event.PokerBettingEvent.BET_COMMIT";
		//The pot value has been updated (this will almost always be an increase from a previous amount). The event
		//includes the new pot "amount" as well as the currency units (denom).
		public static const POT_UPDATE:String = "Event.PokerBettingEvent.POT_UPDATE";
		//A player ("sourcePlayer") has folded.
		public static const BET_FOLD:String = "Event.PokerBettingEvent.BET_FOLD";
		
		
		public var amount:Number = Number.NEGATIVE_INFINITY; //the current bet amount for the player in the native denomination
		public var minimumAmount:Number = Number.NEGATIVE_INFINITY; //the minimum amount for the range allowed
		public var maximumAmount:Number = Number.NEGATIVE_INFINITY; //the maximum amount for the range allowed
		public var denom:String = null; //denomination or currency unit for amount, minimumAmount, and maximumAmount values
		public var sourcePlayer:IPokerPlayerInfo = null; //the source player associated with the event
		public var blindsTime:String = null; //formatted remaining blinds time
		
		public function PokerBettingEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false) {
			super(type, bubbles, cancelable);			
		}
	}
}
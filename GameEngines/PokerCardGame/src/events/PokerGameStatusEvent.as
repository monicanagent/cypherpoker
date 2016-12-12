/**
* Events broadcast by the central Status class.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package events {
	
	import org.cg.events.StatusEvent;
		
	public class PokerGameStatusEvent extends StatusEvent {
		
		/**
		 * General informational game engine status message.
		 */
		public static const STATUS:String = "Event.StatusEvent.PokerGameStatusEvent.STATUS";
		/**
		 * A new game round is about to start.
		 */
		public static const ROUNDSTART:String = "Event.StatusEvent.PokerGameStatusEvent.ROUNDSTART";
		/**
		 * A game round has just ended. Round results should still be available when this event is dispatched.
		 */
		public static const ROUNDEND:String = "Event.StatusEvent.PokerGameStatusEvent.ROUNDEND";
		/**
		 * A player has won a round. The winning PokerPlayerInfo instance is included with the source status
		 * report's "data" property.
		 */
		public static const WIN:String = "Event.StatusEvent.PokerGameStatusEvent.WIN";
		/**
		 * A player has won the game (all other players' balances are 0). The winning PokerPlayerInfo instance is included with the source status
		 * report's "data" property.
		 */
		public static const GAME_WIN:String = "Event.StatusEvent.PokerGameStatusEvent.GAME_WIN";
		/**
		 * New player/private cards have just been fully decrypted and added to the UI. The new player/private cards are included as an array with the
		 * source status report's "data" property.
		 */
		public static const NEW_PLAYER_CARDS:String = "Event.StatusEvent.PokerGameStatusEvent.NEW_PLAYER_CARDS";
		/**
		 * New community/public cards have just been fully decrypted and added to the UI. The new community/public cards are included as an array with the
		 * source status report's "data" property.
		 */
		public static const NEW_COMMUNITY_CARDS:String = "Event.StatusEvent.PokerGameStatusEvent.NEW_COMMUNITY_CARDS";
		
		public function PokerGameStatusEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) {
			super(type, bubbles, cancelable);
		}
	}
}
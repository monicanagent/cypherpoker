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
		 * Generic game engine status message. This event is dispatched along with every other event so that all statuses may easily
		 * be handled/processed by a single listener if desired. This is the only event in which the specific "eventType" property is included along with
		 * the optional "info" property.
		 */
		public static const STATUS:String = "Event.StatusEvent.PokerGameStatusEvent.STATUS";
		/**
		 * An error has occurred. The event "info" includes:
		 * 
		 * description (String): A human-readable description of the error.
		 * fatal (Boolean): True if the error is fatal (the game engine can't continue), false if the error is non-fatal (the game engine is able to resume).
		 */
		public static const ERROR:String = "Event.StatusEvent.PokerGameStatusEvent.ERROR";
		/**
		 * A new Dealer or Player instance has been instructed to start a new round/game. Blinds and betting order may not yet have been
		 * established. The "info" object will contain:
		 * 
		 * "dealer" (Boolean): True if the instance is a Dealer instance and therefore acting as the dealer. If false the instance is
		 * a Player instance and acting as a standard player.
		 */
		public static const START:String = "Event.StatusEvent.PokerGameStatusEvent.START";
		/**
		 * A new SmartContract instance has been created. The "info" object will contain:
		 * 
		 * "contract" (SmartContract): A reference to the newly created SmartContract instance. A game may have multiple active SmartContract instances
		 * at any time, accessible via the game's "smartContracts" property. The current/most recent active contract is available via the game's "activeSmartContract"
		 * property.
		 */
		public static const NEW_CONTRACT:String = "Event.StatusEvent.PokerGameStatusEvent.NEW_CONTRACT";
		/**
		 * Dealer has established a new betting order. This event is typically dispatched only once per session as betting order will not change
		 * even when player roles do or as players drop out. The "info" object will contain:
		 * 
		 * "bettingModule" (PokerBettingModule): A reference to the PokerBettingModule containing the established betting order including
		 * the big blind player, small blind player, and dealer player.
		 */
		public static const DEALER_NEW_BETTING_ORDER:String = "Event.StatusEvent.PokerGameStatusEvent.DEALER_NEW_BETTING_ORDER";
		/**
		 * New blinds values have been set, either by a message from the dealer or because the blinds clock has elapse. The "info" object will contain:
		 * 
		 * "bigBlind" (Number): The new big blind amount.
		 * "smallBlind" (Number): The new small blind amount.
		 */
		public static const SET_BLINDS:String = "Event.StatusEvent.PokerGameStatusEvent.SET_BLINDS";
		/**
		 * New player balance values have been set. This event is usually dispatched only once at the beginning of a session when
		 * new buy-ins have been established. The "info" object will contain:
		 * 
		 * "players" (Vector<IPokerPlayerInfo>): Vector array of IPokerPlayerInfo implementation objects containing all assocated players and their
		 * initial balance information. Other information contained in player objects may not yet be correct or complete.
		 */
		public static const SET_BALANCES:String = "Event.StatusEvent.PokerGameStatusEvent.SET_BALANCES";
		/**
		 * Player balance values have been update. This event is usually dispatched only once at the end of a session when
		 * the hand has been verified. The "info" object will contain:
		 * 
		 * "players" (Vector<IPokerPlayerInfo>): Vector array of IPokerPlayerInfo implementation objects containing all assocated players and their
		 * balance information.
		 */
		public static const UPDATE_BALANCES:String = "Event.StatusEvent.PokerGameStatusEvent.UPDATE_BALANCES";
		/**
		 * Dealer is about to generate or select a new shared modulus value. Event "info" includes:
		 * 
		 * CBL (uint): The target crypto byte length of the modulus to generate
		 * preGen (Boolean): If true a pregenerated modulus value will be used from the game setttings XML, otherwise a new one will be dynamically
		 * generated.
		 */
		public static const DEALER_GEN_MODULUS:String = "Event.StatusEvent.PokerGameStatusEvent.DEALER_GEN_MODULUS";
		/**
		 * Dealer has generated or selected a new modulus value. Event "info" includes:
		 * 
		 * CBL (uint): The crypto byte length of the generated or selected modulus.
		 * modulus (String): The numeric string value of the generated or selected modulus.
		 * radix (uint): The radix of the generated modulus value (e.g. 10 for decimal, 16 for hexadecimal (in "0x" notation), or 8 for octal)
		 * preGen (Boolean): True if the modulus value was pregenerated or selected, false if the value was dynamically generated.
		 * elapsed (int): The number of milliseconds that the operation required; will be 0 if the value was pregenerated or received from an external dealer.
		 */
		public static const DEALER_NEW_MODULUS:String = "Event.StatusEvent.PokerGameStatusEvent.DEALER_NEW_MODULUS";
		/**
		 * A new encryption/decryption key set is about to be generated. Event "info" includes:
		 * 
		 * numKeys (uint): Number of keys to be generated for the key set.
		 * CBL (uint): The crypto byte length for the generated keys.
		 * modulus (String): The shared prime modulus on which to base the generated keys.
		 */
		public static const GEN_KEYS:String = "Event.StatusEvent.PokerGameStatusEvent.GEN_KEYS";
		/**
		 * A new encryption/decryption key set has been generated. Event "info" includes:
		 * 
		 * keys (ISRAMultiKey): The ISRAMultiKey instance containing the newly generated keys.
		 * keychain (Vector<ISRAMultiKey>): All of the currently active key sets for the session. The most recent key sets are stored first.
		 */
		public static const NEW_KEYS:String = "Event.StatusEvent.PokerGameStatusEvent.NEW_KEYS";
		/**
		 * A new, full, plaintext card deck is about to be generated. Event "info" includes:
		 * 
		 * rangeStart (String): The lowest value of the output range. All generated card values are quadratic residues modulo modulus greater than this value.
		 * rangeEnd (String): The highest value of the output range. All generated card values are quadratic residues modulo modulus lesser than this value.
		 * modulus (String): The shared prime modulus on which the card range is based.
		 */
		public static const GEN_DECK:String = "Event.StatusEvent.PokerGameStatusEvent.GEN_DECK";
		/**
		 * A new plaintext card deck has been generated. Event "info" includes:
		 * 
		 * deck (ICardDeck): Reference to an ICardDeck implementation containing the generated and mapped card values.
		 * elapsed (int): The number of elapsed milliseconds that the operation took. This value will be 0 if the deck was received from an external dealer.
		 */
		public static const NEW_DECK:String = "Event.StatusEvent.PokerGameStatusEvent.NEW_DECK";
		/**
		 * A plaintext or partially-encrypted card is about to be encrypted. Event "info" includes:
		 * 
		 * card (String): The value to be encrypted.
		 * key (ISRAKey): the ISRAKey implementation instance to be used to encrypt the card.
		 */
		public static const ENCRYPT_CARD:String = "Event.StatusEvent.PokerGameStatusEvent.ENCRYPT_CARD";
		/**
		 * A plaintext or partially encrypted card value has been encrypted. Event "info" includes:
		 * 
		 * card (String): The encrypted card value.
		 */
		public static const ENCRYPTED_CARD:String = "Event.StatusEvent.PokerGameStatusEvent.ENCRYPTED_CARD";
		/**
		 * A fully-encrypted deck is about to be shuffled. Event "info" includes:
		 * 
		 * shuffleCount (uint): The number of times that the deck will be shuffled.
		 */
		public static const SHUFFLE_DECK:String = "Event.StatusEvent.PokerGameStatusEvent.SHUFFLE_DECK";
		/**
		 * Two private/hole cards are being selected by a player. Event "info" includes:
		 * 
		 * player (IPokerPlayerInfo): The player info object of the player currently selecting two private cards.
		 */
		public static const SELECT_PRIVATE_CARDS:String = "Event.StatusEvent.PokerGameStatusEvent.SELECT_PRIVATE_CARDS";
		/**
		 * Private/hole cards for a specified player are being decrypted. Event "info" includes:
		 * 
		 * player (IPokerPlayerInfo): The player info object of the player to whom the private/hole cards belong.
		 * decryptor (IPokerPlayerInfo): The player info object of the player currently decrypting "player"'s cards.
		 */
		public static const DECRYPT_PRIVATE_CARDS:String = "Event.StatusEvent.PokerGameStatusEvent.DECRYPT_PRIVATE_CARDS";
		/**
		 * The local (self) player's private/hole cards have been fully decrypted and may be added to the UI. Event "info" contains:
		 * 
		 * cards (Vector.<ICard>): The ICard implementations of the cards that have been fully decrypted. 
		 * mappings (Vector.<String>): The plaintext mapping values associated with the "cards" entries, correlated directly by index (i.e.
		 * cards[0] is mappings[0], cards[1] is mappings [1]).
		 */
		public static const DECRYPTED_PRIVATE_CARDS:String = "Event.StatusEvent.PokerGameStatusEvent.DECRYPTED_PRIVATE_CARDS";
		/**
		 * Public/community cards have been selected by the dealer. Event "info" includes:
		 * 
		 * player (IPokerPlayerInfo): The player info object of the current dealer.
		 * numCards (uint): The number of cards that were selected.
		 */
		public static const SELECT_PUBLIC_CARDS:String = "Event.StatusEvent.PokerGameStatusEvent.SELECT_PUBLIC_CARDS";
		/**
		 * Selected public/community cards are about to be decrypted.
		 * 
		 * player (IPokerPlayerInfo): The player info object of the current dealer.
		 * decryptor (IPokerPlayerInfo): The player info object of the player about to decrypt the public/community cards.
		 * numCards (uint): The number of cards about to be decrypted by decryptor.
		 */
		public static const DECRYPT_PUBLIC_CARDS:String = "Event.StatusEvent.PokerGameStatusEvent.DECRYPT_PUBLIC_CARDS";
		/**
		 * A new group of public cards has been fully decrypted, broadcast by the dealer, and may be added to the UI. The event "info" includes:
		 * 
		 * newCards (Vector.<ICard>): The ICard implementations of the cards that have been newly decrypted. 
		 * mappings (Vector.<String>): The plaintext mapping values associated with the "cards" entries, correlated directly by index (i.e.
		 * cards[0] is mappings[0], cards[1] is mappings [1]).
		 * existingCards (Vector.<ICard>): The ICard implementations of the cards that have been decrypted on previous rounds. If no cards
		 * were decrypted on previous rounds this will be an empty vector array (length=0). The "existingCards" array will not contain the "newCards"
		 * array until the next time that DECRYPTED_PUBLIC_CARDS is dispatched.
		 */
		public static const DECRYPTED_PUBLIC_CARDS:String = "Event.StatusEvent.PokerGameStatusEvent.DECRYPTED_PUBLIC_CARDS";
		/**
		 * Private/hole and/or community/public cards are about to be removed from memory (usually because a hand or game has ended). Any instances
		 * should be removed from the display list and references/event listeners should be cleared. Event "info" includes:
		 * 
		 * hole (Boolean): True if the event is referring to the player's private or hole cards.
		 * community (Boolean): True of the event is referring to the public or community cards.
		 */
		public static const CLEAR_CARDS:String = "Event.StatusEvent.PokerGameStatusEvent.CLEAR_CARDS";		
		/**
		 * A new game round is about to start.
		 */
		public static const ROUNDSTART:String = "Event.StatusEvent.PokerGameStatusEvent.ROUNDSTART";
		/**
		 * A game round has just ended. Round results should still be available when this event is dispatched.
		 */
		public static const ROUNDEND:String = "Event.StatusEvent.PokerGameStatusEvent.ROUNDEND";
		/**
		 * A player has won a round. The "info" object contains:
		 * 
		 * player (Vector<IPokerPlayerInfo>): The info object of the winning player(s). Typically this will only
		 * contain one element but may contain more than one in the event of a tie.
		 */
		public static const WIN:String = "Event.StatusEvent.PokerGameStatusEvent.WIN";
		/**
		 * A player has won the game (all other players' balances are 0). The "info" object contains:
		 * 
		 * player (IPokerPlayerInfo): The info object of the winning player.		 
		 */
		public static const GAME_WIN:String = "Event.StatusEvent.PokerGameStatusEvent.GAME_WIN";
		/**
		 * The game instance is about to be destroyed and removed from memory (usually by the lounge).
		 */
		public static const DESTROY:String = "Event.StatusEvent.PokerGameStatusEvent.DESTROY";
		
		
		//Additional information included with the event. Refer to the various event constants above for contents.
		public var info:Object = null;
		//The dispatching source. This value should be used instead of the stanard "target" property as the target will only refer to the
		//dispatcher which will typically only ever be a single source (the game instance).
		public var source:* = null;
		//The event type being dispatched. This value is only set for "STATUS" events so that listeners may differentiate them. For all other
		//event types this value will remain null.
		public var eventType:String = null;
		
		public function PokerGameStatusEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false) {
			super(type, bubbles, cancelable);
		}
	}
}
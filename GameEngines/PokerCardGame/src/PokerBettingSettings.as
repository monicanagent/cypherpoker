/**
* Poker betting settings loading, parsing, updating, and saving functionality.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package  {
	import org.cg.GameTimer;
	import org.cg.events.GameTimerEvent;
	import org.cg.DebugView;

	public class PokerBettingSettings 
	{
		
		private static const _defaultTimerFormat:String = "h:M:S";
		private var _currentGameTypeDefinition:XML = null;
		private var _valid:Boolean = false;
		private var _currentLevel:uint = 0;
		private var _gameType:String;
		private var _gameName:String;
		private var _startingBalance:Number = Number.NEGATIVE_INFINITY; //per player
		private var _currencyFormat:String = "$#m3,;.#f2r;"; //currency format
		private var _smallIncr:Number = 0.1; //small increment/decrement value
		private var _largeIncr:Number = 1; //large increment/decrement value
		private var _timer:GameTimer;
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	gameTypeDefinition The current <gametype> node from the current global settings data.
		 */
		public function PokerBettingSettings(gameTypeDefinition:XML) 
		{
			DebugView.addText ("Creating PokerBettingSettings using definition: ");
			DebugView.addText (gameTypeDefinition);
			_currentGameTypeDefinition = gameTypeDefinition;
			parseGameTypeDefinition(_currentGameTypeDefinition);
		}
		
		/**
		 * @return True if the current poker settings definition data is valid after parsing.
		 */
		public function get valid():Boolean 
		{
			return (_valid);
		}
		
		/**
		 * The current level number (<level> node index) within the current game type levels (<gametype><levels>).
		 */
		public function get currentLevel():uint 
		{
			return (_currentLevel);
		}
		
		public function set currentLevel(levelSet:uint):void 		
		{			
			var levelData:XML = _currentGameTypeDefinition.child("levels")[0] as XML;
			if (levelData == null) {
				return;
			}		
			try {
				//use highest defined values if no higher level exists
				if (levelSet < levelData.children().length()) {
					_currentLevel = levelSet;
				}
			} catch (err:*) {				
			}						
		}	
		
		/**
		 * @return The contents of the definition's "type" attribute. Should match one of the GAMETYPE_ constants
		 * defined for the class.
		 */
		public function get gameType():String 
		{
			return (_gameType);
		}
		
		/**
		 * @return The contents of the definition's descriptive "name" attribute.
		 */
		public function get gameName():String 
		{
			return (_gameName);
		}
		
		/**
		 * @return The contents of the definition's <startingbalance> node.
		 */
		public function get startingBalance():Number 
		{
			return (_startingBalance);
		}
		
		/**
		 * @return The default timer display format to use if one can't be found.
		 */
		public function get defaultTimerFormat():String 
		{
			return (_defaultTimerFormat);
		}

		/**
		 * @return The current <level> node of the definition as determined by the currentLevel index value.
		 */
		public function get currentLevelData():XML 
		{
			try {
				var blindsNode:XML = _currentGameTypeDefinition.child("levels")[0] as XML;
				var currentLevelXML:XML = blindsNode.children()[currentLevel] as XML;
				if (currentLevelXML == null) {
					_valid = false;					
				}//if
			} catch (err:*) {
				_valid = false;
				return (null);
			}
			return (currentLevelXML);
		}
		
		/**
		 * @return A new, or current if one exists, GameTimer instance.
		 */
		public function get currentTimer():GameTimer 
		{
			if (_timer == null) {
				try {
					_timer = new GameTimer(currentTimerValue);
					_timer.addEventListener(GameTimerEvent.COUNTDOWN_END, onPokerGameTimerComplete);
				} catch (err:*) {
					_timer = new GameTimer();
					_timer.addEventListener(GameTimerEvent.COUNTDOWN_END, onPokerGameTimerComplete);
				}
			}
			return (_timer);
		}		
		
		/**
		 * @return The contents of the current level node's "timer" attribute defining the blinds timer.
		 */
		public function get currentTimerValue():String 
		{
			var levelData:XML = currentLevelData;
			if (levelData == null) {
				return ("");
			}
			try {
				var timerVal:String = new String(levelData.@timer);
				return (timerVal);
			} catch (err:*) {				
			}
			return ("");
		}
		
		/**
		 * @return The contents of the current level node's "timerformat" node used to format the current
		 * blinds timer display.
		 */
		public function get currentTimerFormat():String 
		{
			var levelData:XML = currentLevelData;
			if (levelData == null) {
				return (defaultTimerFormat);
			}
			try {
				var formatVal:String = new String(levelData.@timerformat);
				return (formatVal);
			} catch (err:*) {
				return (defaultTimerFormat);
			}
			return (defaultTimerFormat);
		}
		
		/**
		 * @return The big blind value defined for the current level, or Number.NEGATIVE_INFINITY if none can be found.
		 */
		public function get currentLevelBigBlind():Number 
		{
			var levelData:XML = currentLevelData;
			if (levelData == null) {
				return (Number.NEGATIVE_INFINITY);
			}
			try {
				var bigBlindVal:String = new String(levelData.child("bigblind")[0].children().toString());
				return (Number(bigBlindVal));
			} catch (err:*) {				
			}
			return (Number.NEGATIVE_INFINITY);
		}
		
		/**
		 * @return The small blind value defined for the current level, or Number.NEGATIVE_INFINITY if none can be found.
		 */
		public function get currentLevelSmallBlind():Number 
		{
			var levelData:XML = currentLevelData;
			if (levelData == null) {
				return (Number.NEGATIVE_INFINITY);
			}
			try {
				var smallBlindVal:String = new String(levelData.child("smallblind")[0].children().toString());
				return (Number(smallBlindVal));
			} catch (err:*) {				
			}
			return (Number.NEGATIVE_INFINITY);
		}
		
		/**
		 * @return The large increment/decrement value defined in the configuration data.
		 */
		public function get largeIncrement():Number {
			return (this._largeIncr);
		}
		
		/**
		 * @return The small increment/decrement value defined in the configuration data.
		 */
		public function get smallIncrement():Number {
			return (this._smallIncr);
		}
		
		/**
		 * @return The currency format, for use with the CurrencyFormat class, defined for the game settings.
		 */
		public function get currencyFormat():String {
			return (this._currencyFormat);
		}
		
		/**
		 * Stops and clears the current counter.
		 */
		public function clearCurrentTimer():void 
		{
			if (_timer!=null) {
				_timer.removeEventListener(GameTimerEvent.COUNTDOWN_END, onPokerGameTimerComplete);
				_timer.stopCountDown();
				_timer = null;
			}
		}
		
		/**
		 * Event responder invoked when the game timer completes.
		 * 
		 * @param	eventObj Event dispatched from a GameTimer or related instance.
		 */
		private function onPokerGameTimerComplete(eventObj:GameTimerEvent):void 
		{
			DebugView.addText("PokerBettingSettings.onPokerGameTimerComplete");
			currentTimer.stopCountDown();
		}		
		
		/**
		 * Parses the supplied game type definition XML data.
		 * 
		 * @param	gameTypeDefinition The game type definition data to parse (the root should be <gametypes>).
		 */
		private function parseGameTypeDefinition(gameTypeDefinition:XML):void 
		{
			_valid = true;
			try {
				_gameType = new String(gameTypeDefinition.@type);				
			} catch (err:*) {				
			}
			try {
				_currencyFormat = new String(gameTypeDefinition.child("currencyformat")[0].children().toString());
			} catch (err:*) {				
			}
			try {
				_smallIncr = new Number(gameTypeDefinition.child("smallincr")[0].children().toString());
			} catch (err:*) {				
			}
			try {
				_largeIncr = new Number(gameTypeDefinition.child("largeincr")[0].children().toString());
			} catch (err:*) {				
			}			
			try {
				_gameName = new String(gameTypeDefinition.@name);				
			} catch (err:*) {
				_gameName = "";
			}
			try {
				_gameName = new String(gameTypeDefinition.@name);				
			} catch (err:*) {
				_gameName = "";
			}
			_currentLevel = 0;
			try {
				var balanceStr:String = new String(gameTypeDefinition.child("startingbalance")[0].children().toString());
				_startingBalance = Number(balanceStr);
			} catch (err:*) {
				_startingBalance = Number.NEGATIVE_INFINITY;
			}			
		}
	}
}
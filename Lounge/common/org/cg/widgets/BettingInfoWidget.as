/**
* Displays betting information/statistics such as current bet amount, pot amount, etc., for the current game.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
		
	import events.PokerGameStatusEvent;
	import feathers.controls.Alert;
	import feathers.data.ListCollection;
	import org.cg.interfaces.ILounge;
	import events.PokerBettingEvent;
	import org.cg.events.GameTimerEvent;
	import starling.events.Event;
	import PokerBettingModule;
	import org.cg.CurrencyFormat;
	import org.cg.interfaces.IWidget;	
	import feathers.controls.Label;
	import feathers.controls.TextInput;
	import org.cg.StarlingViewManager;
	import org.cg.DebugView;
		
	public class BettingInfoWidget extends Widget implements IWidget {
		
		private var _currencyFormatter:CurrencyFormat; //used to format values for currency display
		private var _bettingModule:PokerBettingModule; //reference to the current game's active betting module
		//UI components rendered by StarlingViewManager:
		public var selectedBetAmount:TextInput;
		public var potAmount:TextInput;
		public var blindsAmounts:Label;
		public var blindsTime:Label;		
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	loungeRef A reference to the main ILounge implementation instance.
		 * @param	containerRef The widget's parent panel or display object container.
		 * @param	widgetData The widget's configuration XML data, usually from the global settings data.
		 */
		public function BettingInfoWidget(loungeRef:ILounge, containerRef:*, widgetData:XML) {
			DebugView.addText ("BettingInfoWidget created.");
			this._currencyFormatter = new CurrencyFormat();
			super(loungeRef, containerRef, widgetData);			
		}
		
		/**
		 * Initializes the widget after it's been added to the display list and all child components have been created.
		 */
		override public function initialize():void {
			DebugView.addText ("BettingInfoWidget.initialize");
			var currentGame:PokerCardGame = lounge.games[0] as PokerCardGame;
			this._bettingModule = currentGame.bettingModule;
			this._bettingModule.addEventListener(PokerBettingEvent.BET_UPDATE, this.onBetUpdate);
			this._bettingModule.addEventListener(PokerBettingEvent.BET_COMMIT, this.onBetCommit);
			this._bettingModule.addEventListener(PokerBettingEvent.POT_UPDATE, this.onPotUpdate);
			this._bettingModule.addEventListener(PokerBettingEvent.BLINDS_TIMER, this.onBlindsTimerTick);
			this._bettingModule.addEventListener(PokerBettingEvent.BETTING_NEW_BLINDS, this.onBlindsUpdated);
			currentGame.addEventListener(PokerGameStatusEvent.DESTROY, this.onGameDestroy);
		}
		
		/**
		 * Prepares the widget for removal from memory by removing event listeners and clearing references.
		 */
		override public function destroy():void {
			this._bettingModule.removeEventListener(PokerBettingEvent.BET_UPDATE, this.onBetUpdate);
			this._bettingModule.removeEventListener(PokerBettingEvent.BET_COMMIT, this.onBetCommit);
			this._bettingModule.removeEventListener(PokerBettingEvent.POT_UPDATE, this.onPotUpdate);
			this._bettingModule.removeEventListener(PokerBettingEvent.BLINDS_TIMER, this.onBlindsTimerTick);
			this._bettingModule.removeEventListener(PokerBettingEvent.BETTING_NEW_BLINDS, this.onBlindsUpdated);
			lounge.games[0].removeEventListener(PokerGameStatusEvent.DESTROY, this.onGameDestroy);
			this._bettingModule = null;
			super.destroy();
		}
		
		/**
		 * Event listener invoked when the main betting module reports that the bet amount has changed, updating the
		 * bet value in the interface.
		 * 
		 * @param	eventObj A PokerBettingEvent object.
		 */
		private function onBetUpdate(eventObj:PokerBettingEvent):void {
			this._currencyFormatter.setValue(eventObj.amount);
			var formattedAmount:String = this._currencyFormatter.getString(this._bettingModule.currentSettings.currencyFormat);
			this.selectedBetAmount.text = formattedAmount;
		}
		
		/**
		 * Event listener invoked when the main betting module reports that the current bet amount has been committed.
		 * 
		 * @param	eventObj A PokerBettingEvent object.
		 */
		private function onBetCommit(eventObj:PokerBettingEvent):void {			
		}
		
		/**
		 * Event listener invoked when the main betting module reports that the pot value has been changed, updating the pot
		 * value in the interface.
		 * 
		 * @param	eventObj A PokerBettingEvent object.
		 */
		private function onPotUpdate(eventObj:PokerBettingEvent):void {	
			this._currencyFormatter.setValue(eventObj.amount);
			var formattedAmount:String = this._currencyFormatter.getString(this._bettingModule.currentSettings.currencyFormat);
			this.potAmount.text = formattedAmount;
		}
		
		/**
		 * Event listener invoked when the main betting module's blinds timer changes, updating the remaining blinds time values
		 * in the interface.
		 * 
		 * @param	eventObj A PokerBettingEvent object.
		 */
		private function onBlindsTimerTick(eventObj:PokerBettingEvent):void {
			this._currencyFormatter.setValue(this._bettingModule.currentSettings.currentLevelSmallBlind);
			var smallBlindAmount:String = this._currencyFormatter.getString(this._bettingModule.currentSettings.currencyFormat);
			this._currencyFormatter.setValue(this._bettingModule.currentSettings.currentLevelBigBlind);
			var bigBlindAmount:String = this._currencyFormatter.getString(this._bettingModule.currentSettings.currencyFormat);
			this.blindsAmounts.text = smallBlindAmount + " / " + bigBlindAmount;
			this.blindsTime.text = eventObj.blindsTime;
		}
		
		/**
		 * Event listener invoked when the main betting module reports that the blinds values have changed. This causes an Alert to
		 * be displayed notifying the player of the changes.
		 * 
		 * @param	eventObj A PokerBettingEvent object.
		 */
		private function onBlindsUpdated(eventObj:PokerBettingEvent):void {
			var alert:Alert = StarlingViewManager.alert("Blinds values have been updated.", "New blinds values", new ListCollection([{label:"OK"}]), null, true, true);
		}
		
		/**
		 * Event listener invoked when the main game is about to be destroyed and removed from memory. This causes the 'detroy' method to
		 * be invoked.
		 * 
		 * @param	eventObj A PokerGameStatusEvent object.
		 */
		private function onGameDestroy(eventObj:PokerGameStatusEvent):void {
			this.destroy();
		}
	}
}
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
		
		public var selectedBetAmount:TextInput;
		public var potAmount:TextInput;
		public var blindsAmounts:Label;
		public var blindsTime:Label;
		private var _currencyFormatter:CurrencyFormat;
		private var _bettingModule:PokerBettingModule;
		
		public function BettingInfoWidget(loungeRef:ILounge, containerRef:*, widgetData:XML) {
			DebugView.addText ("BettingInfoWidget created.");
			this._currencyFormatter = new CurrencyFormat();
			super(loungeRef, containerRef, widgetData);			
		}
		
		private function onBetUpdate(eventObj:PokerBettingEvent):void {
			DebugView.addText ("BettingInfoWidget.onBetUpdate");
			DebugView.addText ("   New bet amount: " + eventObj.amount);
			DebugView.addText ("   Currency units: " + eventObj.denom);
			this._currencyFormatter.setValue(eventObj.amount);
			var formattedAmount:String = this._currencyFormatter.getString(this._bettingModule.currentSettings.currencyFormat);
			this.selectedBetAmount.text = formattedAmount;
		}
		
		private function onBetCommit(eventObj:PokerBettingEvent):void {
			
		}
		
		private function onPotUpdate(eventObj:PokerBettingEvent):void {	
			this._currencyFormatter.setValue(eventObj.amount);
			var formattedAmount:String = this._currencyFormatter.getString(this._bettingModule.currentSettings.currencyFormat);
			this.potAmount.text = formattedAmount;
		}
		
		private function onBlindsTimerTick(eventObj:PokerBettingEvent):void {			
			this._currencyFormatter.setValue(this._bettingModule.currentSettings.currentLevelSmallBlind);
			var smallBlindAmount:String = this._currencyFormatter.getString(this._bettingModule.currentSettings.currencyFormat);
			this._currencyFormatter.setValue(this._bettingModule.currentSettings.currentLevelBigBlind);
			var bigBlindAmount:String = this._currencyFormatter.getString(this._bettingModule.currentSettings.currencyFormat);
			this.blindsAmounts.text = smallBlindAmount + " / " + bigBlindAmount;		
			this.blindsTime.text = eventObj.blindsTime;
			//var timeFormat:String = this._bettingModule.currentSettings.currentTimerFormat;
			//this.blindsTime.text = this._bettingModule.currentSettings.currentTimer.getTimeString(timeFormat);			
		}		
		
		private function onBlindsUpdated(eventObj:PokerBettingEvent):void {
			var alert:Alert = StarlingViewManager.alert("Blinds values have been updated.", "New blinds values", new ListCollection([{label:"OK"}]), null, true, true);
		}
		
		private function onGameDestroy(eventObj:PokerGameStatusEvent):void {
			this.destroy();
		}
		
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
	}
}
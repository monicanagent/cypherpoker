/**
* Implements poker betting controls via integration with the currently active PokerBettingModule instance.
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/ 

package org.cg.widgets {
	
	
	import org.cg.SlidingPanel;
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.IPanelWidget;
	import PokerCardGame;
	import PokerBettingModule;
	import events.PokerBettingEvent;
	import events.PokerGameStatusEvent;
	import org.cg.DebugView;
	import feathers.controls.Button;
	import feathers.controls.NumericStepper;
	import org.cg.CurrencyFormat;
	import org.cg.interfaces.IWidget;
	import starling.events.Event;

	public class BettingControlsWidget extends Widget implements IWidget {
		
		public var betButton:Button;
		public var foldButton:Button;
		public var increaseBetButton:Button;
		public var decreaseBetButton:Button;
		public var betIncreaseStepper:NumericStepper;		
		protected var _game:PokerCardGame = null; //reference to associated PokerCardGame instance
		protected var _bettingModule:PokerBettingModule = null; //reference to associated PokerBettingModule instance
		private var _currentMinimumAmount:Number = Number.NEGATIVE_INFINITY; //minimum bet amount set at last enable event
		private var _currentMaximumAmount:Number = Number.NEGATIVE_INFINITY; //minimum bet amount set at last enable event
		private var _currentAmount:Number = Number.NEGATIVE_INFINITY; //current bet amount
		private var _currencyFormatter:CurrencyFormat;
		
		public function BettingControlsWidget(loungeRef:ILounge, containerRef:*, widgetData:XML) {
			DebugView.addText ("BettingControlsWidget created");
			this._game = loungeRef.games[0] as PokerCardGame;
			this._bettingModule = this._game.bettingModule;	
			this._currencyFormatter = new CurrencyFormat();
			super(loungeRef, containerRef, widgetData);
			
		}
		
		private function onBetButtonClick(eventObj:Event):void {
			this._bettingModule.onBetCommit();
			this.disableControls(null);
		}
		
		private function onFoldButtonClick(eventObj:Event):void {
			this._bettingModule.onFold();
		}
		
		private function disableControls(eventObj:PokerBettingEvent):void {
			DebugView.addText("BettingControlsWidget.disableControls");
			this.betButton.removeEventListener(Event.TRIGGERED, this.onBetButtonClick);
			this.foldButton.removeEventListener(Event.TRIGGERED, this.onFoldButtonClick);
			this.increaseBetButton.removeEventListener(Event.TRIGGERED, this.onIncreaseBetClick);
			this.decreaseBetButton.removeEventListener(Event.TRIGGERED, this.onDecreaseBetClick);
			this.betIncreaseStepper.removeEventListener(Event.CHANGE, this.onIncreaseStepperChange);
			this.betButton.isEnabled = false;
			this.foldButton.isEnabled = false;
			this.increaseBetButton.isEnabled = false;
			this.decreaseBetButton.isEnabled = false;
			this.betIncreaseStepper.isEnabled = false;
		}
		
		private function onIncreaseBetClick(eventObj:Event):void {
			var updateAmount:Number = Number(this.betIncreaseStepper.value);
			this._bettingModule.incrementBet(updateAmount);
		}
		
		private function onDecreaseBetClick(eventObj:Event):void {
			var updateAmount:Number = Number(this.betIncreaseStepper.value);
			this._bettingModule.decrementBet(updateAmount);
		}
		
		private function onIncreaseStepperChange(eventObj:Event):void {
			this.updateInterface(this._currentAmount);
		}
		
		private function enableControls(eventObj:PokerBettingEvent):void {
			DebugView.addText("BettingControlsWidget.enableControls");
			this.betButton.addEventListener(Event.TRIGGERED, this.onBetButtonClick);
			this.foldButton.addEventListener(Event.TRIGGERED, this.onFoldButtonClick);
			this.increaseBetButton.addEventListener(Event.TRIGGERED, this.onIncreaseBetClick);
			this.decreaseBetButton.addEventListener(Event.TRIGGERED, this.onDecreaseBetClick);
			this.betIncreaseStepper.addEventListener(Event.CHANGE, this.onIncreaseStepperChange);
			this.betButton.isEnabled = true;
			this.foldButton.isEnabled = true;			
			this._currentAmount = eventObj.amount;
			this._currentMinimumAmount = eventObj.minimumAmount;
			this._currentMaximumAmount = eventObj.maximumAmount;
			this.updateInterface(eventObj.amount);
		}
		
		private function updateInterface(amount:Number, updateButtons:Boolean = true):void {
			var totalIncAmount:Number = amount + Number(this.betIncreaseStepper.value);			
			totalIncAmount = this._currencyFormatter.roundToFormat(totalIncAmount, this._bettingModule.currentSettings.currencyFormat)
			var totalDecAmount:Number = amount - Number(this.betIncreaseStepper.value);			
			totalDecAmount = this._currencyFormatter.roundToFormat(totalDecAmount, this._bettingModule.currentSettings.currencyFormat)
			DebugView.addText ("BettingControlsWidget.updateInterface");
			DebugView.addText ("Current amount: " + amount);
			DebugView.addText ("Total increment amount: " + totalIncAmount);
			DebugView.addText ("Max amount: " + _currentMaximumAmount);
			DebugView.addText ("Total decrement amount: " + totalDecAmount);
			DebugView.addText ("Min amount: " + _currentMinimumAmount);
			DebugView.addText ("Stepper value: " + this.betIncreaseStepper.value);
			DebugView.addText ("-----------------");
			if (updateButtons) {
				if (totalDecAmount >= this._currentMinimumAmount) {
					this.decreaseBetButton.isEnabled = true;
				} else {
					this.decreaseBetButton.isEnabled = false;
				}
				if (totalIncAmount <= this._currentMaximumAmount) {
					this.increaseBetButton.isEnabled = true;
				} else {
					this.increaseBetButton.isEnabled = false;
				}
				this.betIncreaseStepper.isEnabled = true;
			}
		}
		
		private function onBetUpdate(eventObj:PokerBettingEvent):void {
			if (eventObj.sourcePlayer.netCliqueInfo.peerID == this._bettingModule.selfPlayerInfo.netCliqueInfo.peerID) {
				//bet update came from us
				this._currentAmount = eventObj.amount;
				this.updateInterface(eventObj.amount, true);
			} else {
				//if 
				this.updateInterface(eventObj.amount, false);
				//this.disableControls(null);
			}
		}
		
		private function onBettingPlayerUpdate(eventObj:PokerBettingEvent):void {
			if (eventObj.sourcePlayer.netCliqueInfo.peerID != this._bettingModule.selfPlayerInfo.netCliqueInfo.peerID) {				
				this.disableControls(null);
			}
		}
		
		private function onGameDestroy(eventObj:PokerGameStatusEvent):void {
			this.destroy();
		}
		
		override public function destroy():void {
			this._game.removeEventListener(PokerGameStatusEvent.DESTROY, this.onGameDestroy);
			this._bettingModule.removeEventListener(PokerBettingEvent.BETTING_DISABLE, this.disableControls);
			this._bettingModule.removeEventListener(PokerBettingEvent.BETTING_ENABLE, this.enableControls);
			this._bettingModule.removeEventListener(PokerBettingEvent.BET_UPDATE, this.onBetUpdate);
			this._bettingModule.removeEventListener(PokerBettingEvent.BETTING_PLAYER, this.onBettingPlayerUpdate);
			this.disableControls(null);
			this._game = null;
			this._bettingModule = null;			
			this._currencyFormatter = null;
			super.destroy();
		}
		
		override public function initialize():void {
			DebugView.addText ("BettingControlsWidget.initialize");
			this._bettingModule.addEventListener(PokerBettingEvent.BETTING_DISABLE, this.disableControls);
			this._bettingModule.addEventListener(PokerBettingEvent.BETTING_ENABLE, this.enableControls);
			this._bettingModule.addEventListener(PokerBettingEvent.BET_UPDATE, this.onBetUpdate);
			this._bettingModule.addEventListener(PokerBettingEvent.BETTING_PLAYER, this.onBettingPlayerUpdate);
			this._game.addEventListener(PokerGameStatusEvent.DESTROY, this.onGameDestroy);
		}	
	}
}
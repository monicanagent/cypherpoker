/**
* Manages a horizontal bar containing information about a game's players.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
	
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.IWidget;
	import org.cg.widgets.PlayerInfoBarItem;
	import events.PokerGameStatusEvent;
	import org.cg.StarlingViewManager;
	import org.cg.Table;
	import org.cg.DebugView;
	
	public class PlayerInfoBarWidget extends Widget implements IWidget {
		
		private var _currentGame:PokerCardGame;
		private var _bettingModule:PokerBettingModule;
		private var _currentTable:Table;
		private var _barItems:Vector.<PlayerInfoBarItem> = new Vector.<PlayerInfoBarItem>();
		
		public function PlayerInfoBarWidget(loungeRef:ILounge, containerRef:*, widgetData:XML) {
			DebugView.addText ("PlayerInfoBarWidget created");
			super(loungeRef, containerRef, widgetData);
		}
		
		public function get bettingModule():PokerBettingModule {
			return (this._bettingModule);
		}
		
		public function get table():Table {
			return (this._currentTable);
		}		
		
		public function get game():PokerCardGame {
			return (this._currentGame);
		}	
		
		private function generateBarItems():void {
			DebugView.addText ("PlayerInfoBarWidget.generateBarItems");
			DebugView.addText ("Generating # players: " + this.bettingModule.allPlayers.length);
			var barItemNode:XML = this.widgetData.child("baritem")[0];
			for (var count:int = 0; count < this.bettingModule.allPlayers.length; count++) {				
				var newItem:PlayerInfoBarItem = new PlayerInfoBarItem(this, this.bettingModule.allPlayers[count]);
				this.addChild(newItem);
				StarlingViewManager.renderComponents(barItemNode.children(), newItem, lounge);
				this._barItems.push(newItem);
				newItem.initialize();
			}			
		}
		
		private function onBettingOrderEstablished(eventObj:PokerGameStatusEvent):void {
			this.generateBarItems();
		}
		
		private function onGameDestroy(eventObj:PokerGameStatusEvent):void {
			this._currentGame.removeEventListener(PokerGameStatusEvent.DESTROY, this.onGameDestroy);
			for (var count:int = 0; count < this._barItems.length; count++) {
				 this._barItems[count].destroy();
			}
			this._barItems = null;
			super.destroy();
		}
		
		override public function initialize():void {
			DebugView.addText ("PlayerInfoBarWidget.initialize");
			this._currentGame = lounge.games[0] as PokerCardGame;
			this._bettingModule = lounge.games[0].bettingModule as PokerBettingModule;
			this._currentTable = this._currentGame.table;
			this._currentGame.addEventListener(PokerGameStatusEvent.DEALER_NEW_BETTING_ORDER, this.onBettingOrderEstablished);
			this._currentGame.addEventListener(PokerGameStatusEvent.DESTROY, this.onGameDestroy);
		}
	}
}
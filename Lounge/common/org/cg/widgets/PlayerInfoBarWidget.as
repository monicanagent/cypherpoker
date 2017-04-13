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
		
		private var _currentGame:PokerCardGame; //reference to the currently active PokerCardGame instance
		private var _bettingModule:PokerBettingModule; //reference to the game's PokerBettingModule instance
		private var _currentTable:Table; //reference to the game's currently active Table instance
		private var _barItems:Vector.<PlayerInfoBarItem> = new Vector.<PlayerInfoBarItem>(); //all currently active items appearing in the bar

		/**
		 * Creates a new instance.
		 * 
		 * @param	loungeRef A reference to the main ILounge implementation instance.
		 * @param	container The widget's parent panel or display object container.
		 * @param	widgetData The widget's configuration XML data, usually from the global settings data.
		 */
		public function PlayerInfoBarWidget(loungeRef:ILounge, containerRef:*, widgetData:XML) {
			DebugView.addText ("PlayerInfoBarWidget created");
			super(loungeRef, containerRef, widgetData);
		}
		
		/**
		 * @return A reference to the current game's PokerBettingModule instance.
		 */
		public function get bettingModule():PokerBettingModule {
			return (this._bettingModule);
		}
		
		/**
		 * @return A reference to the current game's main Table instance.
		 */
		public function get table():Table {
			return (this._currentTable);
		}		
		
		/**
		 * @return A reference to the currently active game (PokerCardGame) instance.
		 */
		public function get game():PokerCardGame {
			return (this._currentGame);
		}
		
		/**		 
		 * Initializes the widget after it's been added to the display list and all child components have been created.
		 */
		override public function initialize():void {
			DebugView.addText ("PlayerInfoBarWidget.initialize");
			this._currentGame = lounge.games[0] as PokerCardGame;
			this._bettingModule = lounge.games[0].bettingModule as PokerBettingModule;
			this._currentTable = this._currentGame.table;
			this._currentGame.addEventListener(PokerGameStatusEvent.DEALER_NEW_BETTING_ORDER, this.onBettingOrderEstablished);
			this._currentGame.addEventListener(PokerGameStatusEvent.DESTROY, this.onGameDestroy);
		}
		
		/**
		 * Generates individual bar items (PlayerInfoBarItem) for each player registered with the 'bettingModule'.
		 */
		private function generateBarItems():void {
			var barItemNode:XML = this.widgetData.child("baritem")[0];
			for (var count:int = 0; count < this.bettingModule.allPlayers.length; count++) {				
				var newItem:PlayerInfoBarItem = new PlayerInfoBarItem(this, this.bettingModule.allPlayers[count]);
				this.addChild(newItem);
				StarlingViewManager.renderComponents(barItemNode.children(), newItem, lounge);
				this._barItems.push(newItem);
				newItem.initialize();
			}			
		}
		
		/**
		 * Event listener invoked when the betting order has been reported to have been established by the main game instance. This
		 * invokes the 'generateBarItems' method.
		 * 
		 * @param	eventObj A PokerGameStatusEvent object.
		 */
		private function onBettingOrderEstablished(eventObj:PokerGameStatusEvent):void {
			this.generateBarItems();
		}
		
		/**
		 * Event listener invoked when the current game instance is about to be destroyed. All bar items and event listeners
		 * are removed.
		 * 
		 * @param	eventObj A PokerGameStatusEvent object.
		 */
		private function onGameDestroy(eventObj:PokerGameStatusEvent):void {
			this._currentGame.removeEventListener(PokerGameStatusEvent.DESTROY, this.onGameDestroy);
			for (var count:int = 0; count < this._barItems.length; count++) {
				 this._barItems[count].destroy();
			}
			this._barItems = null;
			super.destroy();
		}
	}
}
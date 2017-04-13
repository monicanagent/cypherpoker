/**
* Displays and manages the information for a single player within a PlayerInfoBarWidget instance.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
	
	import feathers.controls.TextInput;
	import feathers.controls.ImageLoader;
	import starling.display.Image;
	import feathers.controls.Label;
	import starling.textures.Texture;
	import starling.display.Sprite;
	import org.cg.widgets.PlayerInfoBarWidget;
	import events.PokerBettingEvent;
	import events.PokerGameStatusEvent;
	import interfaces.IPokerPlayerInfo;
	import org.cg.CurrencyFormat;
	import org.cg.DebugView;
	import net.kawa.tween.KTween;
	import net.kawa.tween.easing.Expo;
		
	public class PlayerInfoBarItem extends Sprite {
		
		//UI rendered by StarlingViewManager:
		public var iconImage:ImageLoader;
		public var playerHandle:Label;
		public var playerBalance:Label;
		private static var _items:Vector.<PlayerInfoBarItem> = new Vector.<PlayerInfoBarItem>(); //all currently active info bar items
		private var _itemIndex:int = -1; //0-based index of the current instance
		private var _parentBar:PlayerInfoBarWidget = null; //reference to the parent/containing PlayerInfoBarWidget instance
		private var _playerInfo:IPokerPlayerInfo; //reference to the player's info object used by the game's betting module
		private var _playerData:Object; //reference to the player's info object used by the game's current table instance
		private var _currencyFormatter:CurrencyFormat; //currency formatter used to convert player balance, etc. for display
		private var _icon:Image; //player's icon image
		private var _width:Number = Number.NEGATIVE_INFINITY; //width of the instance
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	parentBar A reference to the parent/containing PlayerInfoBarWidget instance.
		 * @param	playerInfo Reference to the game betting module's player and betting information.
		 */
		public function PlayerInfoBarItem(parentBar:PlayerInfoBarWidget, playerInfo:IPokerPlayerInfo) {
			this._parentBar = parentBar;
			this._playerInfo = playerInfo;
			this._currencyFormatter = new CurrencyFormat();
			this._itemIndex = _items.length;
			_items.push(this);
			super();			
		}
		
		/**
		 * The width of the instance.
		 */
		override public function set width(widthSet:Number):void {
			this._width = widthSet;
		}
		
		override public function get width():Number {
			if (this._width != Number.NEGATIVE_INFINITY) {
				return (this._width);
			}
			return (super.width);
		}
		
		/**
		 * @return Reference to the info bar item instance generated prior to this one. If this is the first
		 * instance then the last generated instance is returned.
		 */
		public function get previousItem():PlayerInfoBarItem {
			if (this._itemIndex > 0) {
				return (_items[this._itemIndex - 1]);
			}
			return (_items[_items.length -1]);
		}
		
		
		/**
		 * @return Reference to the info bar item instance generated after to this one. If this is the last instance
		 * then the first generated instance is returned.
		 */		
		public function get nextItem():PlayerInfoBarItem {
			if (this._itemIndex < (_items.length - 1)) {
				return (_items[this._itemIndex + 1]);
			}
			return (_items[0]);			
		}
		
		/**
		 * Initializes the item instance after it's been added to the display list and all pre-defined child components have
		 * been rendered.
		 */
		public function initialize():void {
			this._playerData = this._parentBar.table.getInfoForPeer(this._playerInfo.netCliqueInfo.peerID);
			this._icon = new Image(Texture.fromBitmapData(this._playerData.iconBMD));
			iconImage.addChild(this._icon);
			//iconImage.scaleX = 0.8
			//iconImage.scaleY = 0.8;
			this.playerHandle.text = this._playerData.handle;			
			if (this.previousItem != null) {
				this.x = this.previousItem.x + this.previousItem.width;
			} else {
				this.x = 0;
			}
			this._parentBar.bettingModule.addEventListener(PokerBettingEvent.BET_COMMIT, this.onNewBetCommit);			
			this._parentBar.bettingModule.addEventListener(PokerBettingEvent.BETTING_PLAYER, this.onNewBettingPlayer);
			this._parentBar.game.addEventListener(PokerGameStatusEvent.UPDATE_BALANCES, this.onBalanceUpdate);
		}
		
		/**
		 * Prepares the instance for removal from memory by clearing event listeners, removing references, and
		 * removing the instance reference from the list of active instances.
		 */
		public function destroy():void {
			this._parentBar.bettingModule.removeEventListener(PokerBettingEvent.BET_COMMIT, this.onNewBetCommit);
			this._parentBar.bettingModule.removeEventListener(PokerBettingEvent.BETTING_PLAYER, this.onNewBettingPlayer);
			this._parentBar.game.removeEventListener(PokerGameStatusEvent.UPDATE_BALANCES, this.onBalanceUpdate);
			this._parentBar = null;
			this._playerData = null;
			this._playerInfo = null;
			this._itemIndex = -1;
			iconImage.removeChild(this._icon);
			this._icon = null;
			iconImage = null;
			this._currencyFormatter = null;
			for (var count:int = 0; count < _items.length; count++) {
				if (_items[count] == this) {
					_items.splice(count, 1);
					return;
				}
			}
		}
		
		/**
		 * Starts an animation to align the item to a target horizontal or x position. This method is usually invoked
		 * by the new or current betting player's info bar item when betting positions have changed.
		 * 
		 * @param	xPos The target position to align the item to.
		 * @param 	animate If true a tweening animation is used for the alignment otherwise it is done immediately.
		 */
		public function alignToXPosition(xPos:Number, animate:Boolean = true):void {			
			if (this.x != xPos) {
				if (animate) {
					KTween.to (this, 1.5, {x:xPos}, Expo.easeOut);
				} else {
					this.x = xPos;
				}
			}			
		}
		
		/**
		 * @return Vector array of all currently active info bar item instances.
		 */
		public function get allItems():Vector.<PlayerInfoBarItem> {
			return (_items);
		}
		
		/**
		 * Updates the player's balance in the user interface from the player info object in the game's betting module.
		 */
		private function updatePlayerBalance():void {
			this._currencyFormatter.setValue(this._playerInfo.balance);
			var formattedAmount:String = this._currencyFormatter.getString(this._parentBar.bettingModule.currentSettings.currencyFormat);
			this.playerBalance.text = formattedAmount;
		}
		
		/**
		 * Event listener invoked when the game's betting module signals that a bet has been committed.
		 * 
		 * @param	eventObj A PokerBettingEvent object.
		 */
		private function onNewBetCommit(eventObj:PokerBettingEvent):void {
			this.updatePlayerBalance();
		}
		
		/**
		 * Updates the user interface to reflect that it's a new player's turn to bet when dispatched by the game's betting module.
		 * 
		 * @param	eventObj A PokerBettingEvent object.
		 */
		private function onNewBettingPlayer(eventObj:PokerBettingEvent):void {			
			if (eventObj.sourcePlayer.netCliqueInfo.peerID == this._playerInfo.netCliqueInfo.peerID) {				
				var xOffSet:Number = 0;
				this.alignToXPosition(0);
				xOffSet = this.width;
				var nextBarItem:PlayerInfoBarItem = this.nextItem;
				while (nextBarItem != this) {
					nextBarItem.alignToXPosition(xOffSet);
					xOffSet += nextBarItem.width;
					nextBarItem = nextBarItem.nextItem;
				}
			}
		}
		
		/**
		 * Event listener invoked when the game signals that the player's balance has been set or updated.
		 * 
		 * @param	eventObj A PokerGameStatusEvent object.
		 */
		private function onBalanceUpdate(eventObj:PokerGameStatusEvent):void {
			this.updatePlayerBalance();
		}
	}
}
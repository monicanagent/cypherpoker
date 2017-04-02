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
		
		private static var _items:Vector.<PlayerInfoBarItem> = new Vector.<PlayerInfoBarItem>();
		
		private var _itemIndex:int = -1;
		public var iconImage:ImageLoader;
		public var playerHandle:Label;
		public var playerBalance:Label;
		private var _parentBar:PlayerInfoBarWidget = null;
		private var _playerInfo:IPokerPlayerInfo;
		private var _playerData:Object;
		private var _currencyFormatter:CurrencyFormat;
		private var _icon:Image;
		private var _width:Number = Number.NEGATIVE_INFINITY;
		
		public function PlayerInfoBarItem(parentBar:PlayerInfoBarWidget, playerInfo:IPokerPlayerInfo) {
			this._parentBar = parentBar;
			this._playerInfo = playerInfo;
			this._currencyFormatter = new CurrencyFormat();
			this._itemIndex = _items.length;
			_items.push(this);
			super();			
		}
		
		override public function set width(widthSet:Number):void {			
			this._width = widthSet;
		}
		
		override public function get width():Number {
			if (this._width != Number.NEGATIVE_INFINITY) {
				return (this._width);
			}
			return (super.width);
		}
		
		public function get previousItem():PlayerInfoBarItem {
			if (this._itemIndex > 0) {
				return (_items[this._itemIndex - 1]);
			}
			return (_items[_items.length -1]);
		}
		
		public function get nextItem():PlayerInfoBarItem {
			if (this._itemIndex < (_items.length - 1)) {
				return (_items[this._itemIndex + 1]);
			}
			return (_items[0]);			
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
		
		public function get allItems():Vector.<PlayerInfoBarItem> {
			return (_items);
		}
		
		private function updatePlayerBalance():void {
			this._currencyFormatter.setValue(this._playerInfo.balance);
			var formattedAmount:String = this._currencyFormatter.getString(this._parentBar.bettingModule.currentSettings.currencyFormat);
			this.playerBalance.text = formattedAmount;
		}
		
		private function onNewBetCommit(eventObj:PokerBettingEvent):void {
			this.updatePlayerBalance();
		}
		
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
		
		private function onBalanceUpdate(eventObj:PokerGameStatusEvent):void {
			this.updatePlayerBalance();
		}
		
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
		
		public function initialize():void {
			DebugView.addText("PlayerInfoBarItem.initialize");
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
	}
}
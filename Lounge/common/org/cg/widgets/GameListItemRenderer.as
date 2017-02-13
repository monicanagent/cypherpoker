/**
* Custom list item rendererer used when generating a list of games (for example, in the TableManagerWidget).
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
	
	import feathers.controls.Button;
	import feathers.controls.Label;
	import org.cg.interfaces.ILounge;
	import feathers.controls.ToggleButton;		;
	import feathers.controls.renderers.IListItemRenderer;
    import feathers.controls.renderers.LayoutGroupListItemRenderer;
	import flash.geom.Point;
	import feathers.controls.ImageLoader;
	import starling.events.TouchEvent;
	import starling.events.TouchPhase;
	import starling.events.Touch;
    import feathers.layout.AnchorLayout;
    import feathers.layout.AnchorLayoutData;
	import starling.events.Event;
	import org.cg.StarlingViewManager;
	import org.cg.DebugView;
		
	public class GameListItemRenderer extends LayoutGroupListItemRenderer implements IListItemRenderer {
		
		public var tableID:Label;
		public var ownerPeerID:Label;
		public var buyInAmount:Label;
		public var numPlayers:Label;
		public var smallBlindAmount:Label;
		public var bigBlindAmount:Label;
		public var blindsTime:Label;
		public var handContractAddress:Label;			
		public var itemButton:ToggleButton;
		public var openTableIcon:ImageLoader;
		public var closedTableIcon:ImageLoader;
		public var contractIcon:ImageLoader;
		
		private var _selectable:Boolean = false;
		private var _listItemDefinition:XML = null;
		private var _lounge:ILounge = null;
		private var _onSelect:Function = null;
		
		public function GameListItemRenderer(listItemDefinition:XML, loungeRef:ILounge, onSelect:Function = null) {
			DebugView.addText("GameListItemRenderer created")
			this._listItemDefinition = listItemDefinition;
			this._lounge = loungeRef;
			this._onSelect = onSelect;
			super();			
		}
		
		override protected function commitData():void {			
            if (this._data && this._owner) {
				if ((this._data["selected"] == undefined) ||  (this._data["selected"] == null)) {
					this._data.selected = false;					
				}
				if ((this._data["tableType"] == undefined) ||  (this._data["tableType"] == null)) {
					this._data.tableType = "open";					
				}
				try {
					if (this._data.tableType == "closed") {
						this.openTableIcon.visible = false;
						this.closedTableIcon.visible = true;
					} else {
						this.openTableIcon.visible = true;
						this.closedTableIcon.visible = false;
					}
				} catch (err:*) {					
				}
				this.tableID.text = this._data.tableID;
				this.ownerPeerID.text = this._data.ownerPeerID;
				this.buyInAmount.text = this._data.buyInAmount;
				this.numPlayers.text = this._data.numPlayers;				
				this.bigBlindAmount.text = this._data.bigBlindAmount;
				this.smallBlindAmount.text = this._data.smallBlindAmount;
				this.blindsTime.text = this._data.blindsTime;
				if ((this._data.handContractAddress != null) && (this._data.handContractAddress != "")) {
					this.handContractAddress.text = this._data.handContractAddress;
					this.contractIcon.visible = true;
				} else {
					this.handContractAddress.text = "";
					this.contractIcon.visible = false;
				}
				this.blindsTime.text = this._data.blindsTime;
				this.itemButton.isSelected = this._data.selected;
            } else {                
            }
        }
		
		private function onStageInteract(eventObj:TouchEvent):void {			
			var down:Touch = eventObj.getTouch(this.stage, TouchPhase.BEGAN);
			var up:Touch = eventObj.getTouch(this.stage, TouchPhase.ENDED);
			if (down) {
				//Uncomment if mouse coordinates are needed
				//var localPos:Point = down.getLocation(this);
				//var stagePos:Point = down.getLocation(this.stage);
				if (!this.itemButton.isSelected && this._selectable) {						
					this.itemButton.isSelected = true;
				} else if (this.itemButton.isSelected && this._selectable) {					
					this.itemButton.isSelected = false;
				}
				this._data.selected = this.itemButton.isSelected;
				if (this._onSelect != null) {
					this._onSelect(this._data, this);
				}
			}
			if (up)	{				
				//localPos = up.getLocation(this);
				//stagePos = up.getLocation(this.stage);				
				this.itemButton.isSelected = this._data.selected				
			}
		}
		
		override protected function initialize():void {			
			this.layout = new AnchorLayout();
            var labelLayoutData:AnchorLayoutData = new AnchorLayoutData();
            labelLayoutData.top = 0;
            labelLayoutData.right = 0;
            labelLayoutData.bottom = 0;
            labelLayoutData.left = 0;
			if (this.itemButton == null) {
				this.itemButton = new ToggleButton();
				this.itemButton.layoutData = labelLayoutData;
				this.addChild(this.itemButton);
			}
			StarlingViewManager.renderComponents(this._listItemDefinition.children(), this, this._lounge);
			this.addEventListener(TouchEvent.TOUCH, this.onStageInteract);			
			super.initialize();
		}		
	}
}

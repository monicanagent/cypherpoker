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
	import org.cg.SmartContractFunction;
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
		
	public class GameStatusItemRenderer extends LayoutGroupListItemRenderer implements IListItemRenderer {
		
		//UI components rendered by StarlingViewManager:
		public var itemButton:ToggleButton;
		public var itemHeaderText:Label;
		public var itemDetailsText:Label;
		//type icons
		public var iconTypeSmartContract:ImageLoader;
		public var iconTypeGameEngine:ImageLoader;
		public var iconTypeClique:ImageLoader;
		public var iconTypeGeneral:ImageLoader;
		//status icons
		public var iconStatusWaiting:ImageLoader;
		public var iconStatusDone:ImageLoader;
		public var iconStatusError:ImageLoader;
		
		private static var _items:Vector.<GameStatusItemRenderer> = new Vector.<GameStatusItemRenderer>(); //all currently active list items
		private var _selectable:Boolean = false; //is item selectable?
		private var _listItemDefinition:XML = null; //item configuration definition, usually from global settings
		private var _lounge:ILounge = null; //reference to the main lounge instance
		private var _onSelect:Function = null; //callback function to invoke when item is selected
		private var _smartContractFunction:SmartContractFunction = null; //smart contract function reference associated with this renderer
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	listItemDefinition Configuration XML definition for list item, usually from the global settings data.
		 * @param	loungeRef Reference to the main ILounge implementation instance.
		 * @param	onSelect Callback function to invoke when the item is selected/clicked.
		 */
		public function GameStatusItemRenderer(listItemDefinition:XML, loungeRef:ILounge, onSelect:Function = null) {			
			this._listItemDefinition = listItemDefinition;
			this._lounge = loungeRef;
			this._onSelect = onSelect;
			_items.push (this);
			super();			
		}
		
		/**
		 * Retrieves a renderer instance associated with a specific SmartContractFunction instance.
		 * 
		 * @param	functionRef A reference to the SmartContractFunction associated with the renderer instance to find.
		 * 
		 * @return The GameStatusItemRenderer instance associated with 'functionRef' or null if none can be found.
		 */
		public static function getItemBySmartContractFunction(functionRef:SmartContractFunction):GameStatusItemRenderer {
			for (var count:int = 0; count < _items.length; count++) {
				if (_items[count].smartContractFunction == functionRef) {
					return (_items[count]);
				}
			}
			return (null);
		}
		
		/**
		 * @return The SmartContractFunction instance associated with this instance.
		 */
		public function get smartContractFunction():SmartContractFunction {
			return (this._smartContractFunction);
		}
		
		/**
		 * Standard Feathers renderer function invoked when item data is updated.
		 */
		override protected function commitData():void {			
            if (this._data && this._owner) {
				if ((this._data["selected"] == undefined) ||  (this._data["selected"] == null)) {
					this._data.selected = false;					
				}			
				if ((this._data["smartContractFunction"] != undefined) &&  (this._data["smartContractFunction"] != null)) {
					this._smartContractFunction = this._data.smartContractFunction;
				}
				this.itemHeaderText.text = this._data.itemHeader;
				this.itemDetailsText.text = this._data.itemDetails;
				this.updateItemTypeIcon();
				this.updateItemStatusIcon();
				this.itemButton.isSelected = this._data.selected;
            }
        }
		
		/**
		 * Updates the item type icon to the type defined in the item data's 'itemType' property.
		 */
		private function updateItemTypeIcon():void {
			switch (this._data.itemType) {
				case "smartcontract": 
					this.iconTypeSmartContract.visible = true;	
					this.iconTypeGameEngine.visible = false;
					this.iconTypeClique.visible = false;
					this.iconTypeGeneral.visible = false;
					break;
				case "gameengine": 
					this.iconTypeSmartContract.visible = false;	
					this.iconTypeGameEngine.visible = true;
					this.iconTypeClique.visible = false;
					this.iconTypeGeneral.visible = false;
					break;
				case "clique": 
					this.iconTypeSmartContract.visible = false;	
					this.iconTypeGameEngine.visible = false;
					this.iconTypeClique.visible = true;
					this.iconTypeGeneral.visible = false;
					break;					
				default:
					this.iconTypeSmartContract.visible = false;
					this.iconTypeGameEngine.visible = false;
					this.iconTypeClique.visible = false;
					this.iconTypeGeneral.visible = true;
					break;
			}
		}
		
		/**
		 * Updates the item status icon to the status defined in the item data's 'actionStatus' property.
		 */
		private function updateItemStatusIcon():void {
			switch (this._data.actionStatus) {
				case "waiting": 
					this.iconStatusDone.visible = false;
					this.iconStatusError.visible = false;
					this.iconStatusWaiting.visible = true;
					break;
				case "done":
					this.iconStatusDone.visible = true;
					this.iconStatusError.visible = false;
					this.iconStatusWaiting.visible = false;
					break;
				case "complete":
					this.iconStatusDone.visible = true;
					this.iconStatusError.visible = false;
					this.iconStatusWaiting.visible = false;
					break;
				case "error":
					this.iconStatusDone.visible = false;
					this.iconStatusError.visible = true;
					this.iconStatusWaiting.visible = false;
					break;
				case "problem":
					this.iconStatusDone.visible = false;
					this.iconStatusError.visible = true;
					this.iconStatusWaiting.visible = false;
					break;
				default:
					this.iconStatusDone.visible = false;
					this.iconStatusError.visible = false;
					this.iconStatusWaiting.visible = false;
					break;					
			}
		}
		
		/**
		 * Event listener invoked when the user interacts with the stage. If the event captures click/touch activity over this item,
		 * the '_onSelect' callback function is invoked.
		 * 
		 * @param	eventObj A Starling TouchEvent object.
		 */
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
		
		/**
		 * Initializes the instance and renders child components.
		 */
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
			super.initialize();
		}
	}
}

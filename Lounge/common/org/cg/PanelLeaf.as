/**
* Manages a single panel leaf (standalone panel extension).
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/ 

package org.cg {
	
	import flash.geom.Point;
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.IPanelLeaf;
	import org.cg.interfaces.ISlidingPanel;
	import starling.display.Sprite;
		
	public class PanelLeaf extends Sprite implements IPanelLeaf {
		
		protected var _panel:ISlidingPanel = null; //reference the associated sliding panel instance
		protected var _leafData:XML = null; //configuration data for the leaf, usually a part of the global settings data
		protected var _lounge:ILounge; //reference to the main lounge instance
		protected var _leafOrigin:Point = null; //the point at which the leaf was rendered
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	loungeRef A reference to the main ILounge implementation instance.
		 * @param	leafData The configuration data for the leaf, usually from the global settings data.
		 */
		public function PanelLeaf(loungeRef:ILounge, leafData:XML) {						
			this._lounge = loungeRef;
			this._leafData = leafData;
			DebugView.addText ("Created leaf at position: " + this.position);
			super();
		}	
		
		/**
		 * A reference to the associated sliding panel instance.
		 */
		public function set panel(panelRef:ISlidingPanel):void {
			this._panel = panelRef;
		}
		
		public function get panel():ISlidingPanel {
			return (this._panel);
		}
		
		/**
		 * @return The leaf position as related to the associated sliding panel. Currently valid values include
		 * "left", "bottom", and "right". If the position is not properly defined in the configuration XML data, "none"
		 * is returned.
		 */
		public function get position():String {
			try {
				var positionStr:String = String(this._leafData.@position);
				return (positionStr.toLowerCase());
			} catch (err:*) {				
			}
			return ("none");
		}
		
		/**
		 * @return The leaf width, as specifid in the configuration XML data. If not specified or not a valid value the dynamic
		 * panel width is returned instead.
		 */
		override public function get width():Number {
			try {
				if ((this._leafData.@width != null) && (this._leafData.@width != "")) {
					return (Number(this._leafData.@width));
				}
			} catch (err:*) {				
			}
			return (super.width);
		}
		
		/**
		 * @return The leaf height, as specifid in the configuration XML data. If not specified or not a valid value the dynamic
		 * panel height is returned instead.
		 */
		override public function get height():Number {
			try {
				if ((this._leafData.@height != null) && (this._leafData.@height != "")) {
					return (Number(this._leafData.@height));
				}
			} catch (err:*) {				
			}
			return (super.height);			
		}
		
		/**
		 * @return The horizontal offset of the leaf with respect to its associated sliding panel. If this value isn't correctly defined
		 * in the configuration XML data, 0  is returned.
		 */
		public function get hOffset():Number {
			try {
				if ((this._leafData.@hoffset != null) && (this._leafData.@hoffset != "")) {
					return (Number(this._leafData.@hoffset));
				}
			} catch (err:*) {				
			}
			return (0);			
		}
		
		/**
		 * @return The vertical offset of the leaf with respect to its associated sliding panel. If this value isn't correctly defined
		 * in the configuration XML data, 0  is returned.
		 */
		public function get vOffset():Number {
			try {
				if ((this._leafData.@voffset != null) && (this._leafData.@voffset != "")) {
					return (Number(this._leafData.@voffset));
				}
			} catch (err:*) {				
			}
			return (0);			
		}
		
		/**
		 * Method invoked when the leaf's associated panel has updated its size of position, causing the leaf to re-align itself. This
		 * method may also be invoked manually if a re-alignment is required.
		 */
		public function onPanelUpdate():void {			
			if (this.position == "right") {				
				this.x = this.panel.x - this.width + this.hOffset;
				this.y = this.panel.y + this.vOffset;
				
			} else if (this.position == "left") {				
				this.x = this.panel.x + this.panel.width + this.hOffset;
				this.y = this.panel.y + this.vOffset;
			} else if (this.position == "bottom") {				
				this.x = this.panel.x + this.hOffset;
				this.y = this.panel.y - this.height + this.vOffset;
			} else {				
				//unrecognized position value!
			}
			
		}
		
		/**
		 * Initializes the newly-created leaf instance; usually invoked by the StarlingViewManager immediately after the leaf
		 * has been added to the display list.
		 */
		public function initialize():void {
			for (var count:int = 0; count < SlidingPanel.panels.length; count++) {
				if (SlidingPanel.panels[count].position == this.position) {
					SlidingPanel.panels[count].addPanelLeaf(this);
					this._panel = SlidingPanel.panels[count];
					break;
				}
			}		
			this.onPanelUpdate();
		}		
		
		/**
		 * Cleanup method invoked when the panel leaf is about to be removed from memory.
		 */
		public function destroy():void {
		}
	}
}
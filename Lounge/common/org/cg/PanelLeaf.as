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
		
		protected var _panel:ISlidingPanel = null;
		protected var _leafData:XML = null;
		protected var _lounge:ILounge;
		protected var _leafOrigin:Point = null;
		
		
		public function PanelLeaf(loungeRef:ILounge, leafData:XML) {						
			this._lounge = loungeRef;
			this._leafData = leafData;
			DebugView.addText ("Created leaf at position: " + this.position);
			super();
		}	
		
		public function set panel(panelRef:ISlidingPanel):void {
			this._panel = panelRef;
		}
		
		public function get panel():ISlidingPanel {
			return (this._panel);
		}
		
		public function get position():String {
			try {
				var positionStr:String = String(this._leafData.@position);
				return (positionStr.toLowerCase());
			} catch (err:*) {				
			}
			return ("none");
		}
		
		override public function get width():Number {
			try {
				if ((this._leafData.@width != null) && (this._leafData.@width != "")) {
					return (Number(this._leafData.@width));
				}
			} catch (err:*) {				
			}
			return (super.width);
		}
		
		override public function get height():Number {
			try {
				if ((this._leafData.@height != null) && (this._leafData.@height != "")) {
					return (Number(this._leafData.@height));
				}
			} catch (err:*) {				
			}
			return (super.height);			
		}
		
		public function get hOffset():Number {
			try {
				if ((this._leafData.@hoffset != null) && (this._leafData.@hoffset != "")) {
					return (Number(this._leafData.@hoffset));
				}
			} catch (err:*) {				
			}
			return (0);			
		}
		
		public function get vOffset():Number {
			try {
				if ((this._leafData.@voffset != null) && (this._leafData.@voffset != "")) {
					return (Number(this._leafData.@voffset));
				}
			} catch (err:*) {				
			}
			return (0);			
		}
		
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
		
		public function destroy():void {
			
		}
	}
}
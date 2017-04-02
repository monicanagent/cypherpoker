/**
* Used to manage the local (self) player's profile information.
* 
* This implementation uses a simple delay timer to establish the leader/dealer role.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
	
	import feathers.controls.TextInput;	
	import flash.net.FileFilter;
	import org.cg.events.LoungeEvent;
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.IPanelWidget;
	import org.cg.SlidingPanel;
	import starling.events.Event;
	import feathers.events.FeathersEventType;
	import feathers.controls.Button;
	import org.cg.GlobalSettings;
	import org.cg.DebugView;
	import flash.filesystem.File;
		
	public class PlayerProfileWidget extends PanelWidget implements IPanelWidget {
		
		public var updatePlayerIconButton:Button;
		public var playerHandleInput:TextInput;		
		private var _iconFileBrowser:File;
		
		public function PlayerProfileWidget(loungeRef:ILounge, panelRef:SlidingPanel, widgetData:XML) {
			DebugView.addText("PlayerProfileWidget created");
			super(loungeRef, panelRef, widgetData);			
		}
		
		private function onUpdatePlayerIconClick(eventObj:Event):void {
			this._iconFileBrowser = File.desktopDirectory;
			this._iconFileBrowser.addEventListener("select", this.onIconFileSelect);
			var fileFilter:FileFilter = new FileFilter("Image", "*.jpg;*.png;*.gif");
			this._iconFileBrowser.browseForOpen("Select icon image", [fileFilter]);
		}
		
		private function onIconFileSelect(eventObj:Object):void {
			DebugView.addText("Selected icon: " + this._iconFileBrowser.nativePath);
			this._iconFileBrowser.removeEventListener("select", this.onIconFileSelect);
			lounge.currentPlayerProfile.profileData.child("icon")[0].replace("*", new XML("<![CDATA[" + this._iconFileBrowser.nativePath + "]]>"));			
			GlobalSettings.saveSettings();
			lounge.currentPlayerProfile.load();
		}
		
		private function updateProfileInfo(eventObj:LoungeEvent):void {			
			this.updatePlayerIconButton.defaultIcon = lounge.currentPlayerProfile.newIconImage;
			this.updatePlayerIconButton.invalidate();
			this.playerHandleInput.text = lounge.currentPlayerProfile.profileHandle;
		}
		
		private function onPlayerHandleInputLoseFocus(eventObj:Event):void {
			lounge.currentPlayerProfile.profileData.child("handle")[0].replace("*", new XML("<![CDATA[" + this.playerHandleInput.text + "]]>"));
			GlobalSettings.saveSettings();
			lounge.currentPlayerProfile.load();
		}
		
		override public function initialize():void {
			DebugView.addText("PlayerProfileWidget.initialize");
			this.updatePlayerIconButton.addEventListener(Event.TRIGGERED, this.onUpdatePlayerIconClick);
			if (lounge.currentPlayerProfile.iconLoaded) {
				this.updateProfileInfo(null);
			}
			lounge.addEventListener(LoungeEvent.UPDATED_PLAYERPROFILE, this.updateProfileInfo);
			this.playerHandleInput.addEventListener(FeathersEventType.FOCUS_OUT, this.onPlayerHandleInputLoseFocus);
		}		
	}
}
/**
* Provides access to player profile information stored in the global settings data. Global settings data must be fully loaded and parsed
* prior to instantiating this class.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
	
	import flash.utils.ByteArray;
	import org.cg.interfaces.IRoomProfile;
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.events.EventDispatcher;
	import flash.display.Loader;
	import flash.net.URLRequest;
	import starling.textures.Texture;
	import starling.display.Image;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.events.Event;
	import org.cg.events.PlayerProfileEvent;
	
	public class PlayerProfile extends EventDispatcher implements IRoomProfile {
		
		public static var defaultPlayerHandle:String = "Player";
		public static var defaultIconPath:String = "./assets/icons/profile_icon_default.png"; //relative to root application location
		private var _profileNode:XML = null; //Reference to the associated profile node within the global settings data or null if none exists
		private var _profileName:String = "default";
		private var _iconLoaded:Boolean = false;
		private var _iconLoader:Loader; //this allows both local and remote files to be used		
		
		/**
		 * Creates an instance of the player profile object.
		 * 
		 * @param	profileName The profile name (name of the child node), to use with this instance. If no such profile
		 * exists then default values are used instead.
		 */
		public function PlayerProfile(profileName:String) {
			DebugView.addText ("Creating new player profile instance for: " + profileName);
			this._profileName = profileName;
			super (this);
		}
		
		public function get profileData():XML {
			return (this._profileNode);
		}
		
		public function get profileHandle():String {
			if (this._profileNode == null) {
				return (defaultPlayerHandle);
			}
			return (this._profileNode.child("handle")[0].children().toString());
		}
		
		public function get iconPath():String {
			if (this._profileNode == null) {
				return (defaultIconPath);
			}
			return (this._profileNode.child("icon")[0].children().toString());
		}
		
		public function get iconData():BitmapData {
			try {
				var bmp:Bitmap = this._iconLoader.content as Bitmap;
				if ((bmp.width != 64) || (bmp.height != 64)) {
					if (bmp.width > bmp.height) {
						var scale:Number = 64 / bmp.width;		
					} else {
						scale = 64 / bmp.height;
					}
					var matrix:Matrix = new Matrix();
					matrix.scale(scale, scale);
					var scaledBMD:BitmapData = new BitmapData(bmp.width * scale, bmp.height * scale, true, 0x000000);
					scaledBMD.draw(bmp, matrix, null, null, null, true);
					return (scaledBMD);
				} else {
					return (bmp.bitmapData);
				}
			} catch (err:*) {				
			}
			return (null);
		}
				
		
		public function get newIconTexture():Texture {
			return (Texture.fromBitmapData(this.iconData));
		}
		
		public function get newIconImage():Image {
			var returnImg:Image = new Image(this.newIconTexture);
			return (returnImg);
		}
		
		public function get newIconByteArray():ByteArray {
			var bmd:BitmapData = this.iconData;
			var bounds:Rectangle = new Rectangle(0, 0, bmd.width, bmd.height);
			return (bmd.getPixels(bounds));
		}
		
		public function get iconLoaded():Boolean {
			return (this._iconLoaded);
		}		
		
		private function loadIcon():void {
			this._iconLoader = new Loader();
			var request:URLRequest = new URLRequest(this.iconPath);
			this._iconLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, this.onLoadIcon);
			this._iconLoader.load(request);
		}
		
		private function onLoadIcon(eventObj:Event):void {
			DebugView.addText ("PlayerProfile.onLoadIcon");
			eventObj.target.removeEventListener(Event.COMPLETE, this.onLoadIcon);
			this._iconLoaded = true;
			var event:PlayerProfileEvent = new PlayerProfileEvent(PlayerProfileEvent.UPDATED);
			this.dispatchEvent(event);
		}
		
		/**
		 * Load or reload player profile information from the global settings data.
		 * 
		 * @param createIfMissing If true the profile data will be created and saved to the global settings data if it's missing otherwise
		 * it will be left as is.
		 */
		public function load(createIfMissing:Boolean = true):void {
			DebugView.addText ("Loading player profile \""+this._profileName+"\"");
			var profilesNode:XML = GlobalSettings.getSettingsCategory("playerprofiles");
			if (profilesNode == null) {
				if (!createIfMissing) {
					return;
				}
				profilesNode = new XML("<playerprofiles />");
				GlobalSettings.data.appendChild(profilesNode);
			}
			for (var count:int = 0; count < profilesNode.children().length(); count++) {
				var currentNode:XML = profilesNode.children()[count];
				if (currentNode.localName() == this._profileName) {
					this._profileNode = currentNode;
					break;
				}
			}
			if (this._profileNode == null) {
				if (!createIfMissing) {
					return;
				}
				this._profileNode = new XML("<"+this._profileName+" />");
				this._profileNode.appendChild(new XML("<handle>"+defaultPlayerHandle+"</handle>"));
				this._profileNode.appendChild(new XML("<icon><![CDATA[" + defaultIconPath+ "]]></icon>"));
				profilesNode.appendChild(this._profileNode);
				GlobalSettings.saveSettings();
			}
			this.loadIcon();
		}
	}
}
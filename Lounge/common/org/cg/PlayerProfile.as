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
	import flash.net.SharedObject;
	import starling.textures.Texture;
	import starling.display.Image;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.events.Event;
	import org.cg.events.PlayerProfileEvent;
	
	public class PlayerProfile extends EventDispatcher implements IRoomProfile {
		
		public static var defaultPlayerHandle:String = "Player"; //default handle
		public static var defaultIconPath:String = "./assets/icons/profile_icon_default.png"; //default icon, relative to root application location
		private var _profileNode:XML = null; //Reference to the associated profile node within the global settings data or null if none exists
		private var _profileName:String = "default"; //profile name to read from the global settings XML data
		private var _iconLoaded:Boolean = false; //has the profile icon been fully loaded?
		private var _iconLoader:Loader; //this allows both local and remote files to be used		
		
		/**
		 * Creates an instance of the player profile object.
		 * 
		 * @param	profileName The profile name (name of the child node), to use with this instance. If no such profile
		 * exists then default values are used instead.
		 */
		public function PlayerProfile(profileName:String) {
			this._profileName = profileName;
			super (this);
		}
		
		/**
		 * @return The profile data associated with this instance, usually from the global configuration XML data.
		 */
		public function get profileData():XML {
			return (this._profileNode);
		}
		
		/**
		 * @return The name of the currently loaded profile, as specified by the name of the node within the global settings data,
		 * or null if no profile is currently available.
		 */
		public function get profileName():String {
			if (this.profileData == null) {
				return (null);
			}
			return (new String(this.profileData.localName()));
		}
		
		/**
		 * @return The profile handle defined in the profile XML data, or 'defaultPlayerHandle' if none is defined.
		 */
		public function get profileHandle():String {
			if (this._profileNode == null) {
				return (defaultPlayerHandle);
			}
			return (this._profileNode.child("handle")[0].children().toString());
		}
		
		/**
		 * @return The path to the associated profile icon image defined in the profile XML data, or 'defaultIconPath' if none is defined.
		 */
		public function get iconPath():String {
			if (this._profileNode == null) {
				return (defaultIconPath);
			}
			return (this._profileNode.child("icon")[0].children().toString());
		}
		
		/**
		 * @return The loaded and scaled profile icon. If none has been loaded, null is returned.
		 */
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
				
		
		/**
		 * @return A new Starling Texture instance containing the loaded and scaled icon image.
		 */
		public function get newIconTexture():Texture {
			return (Texture.fromBitmapData(this.iconData));
		}
		
		/**
		 * @return A new Starling Image instance containing the loaded and scaled icon image.
		 */
		public function get newIconImage():Image {
			var returnImg:Image = new Image(this.newIconTexture);
			return (returnImg);
		}
		
		/**
		 * @return A new ByteArray instance containing the loaded and scaled icon image data.
		 */
		public function get newIconByteArray():ByteArray {
			var bmd:BitmapData = this.iconData;
			var bounds:Rectangle = new Rectangle(0, 0, bmd.width, bmd.height);
			return (bmd.getPixels(bounds));
		}
		
		/**
		 * @return True if the profile icon has been successfully loaded and parsed, false otherwise.
		 */
		public function get iconLoaded():Boolean {
			return (this._iconLoaded);
		}		
		
		/**
		 * Load or reload player profile information from the global settings data.
		 * 
		 * @param createIfMissing If true the profile data will be created and saved to the global settings data if it's missing otherwise
		 * it will be left as is.
		 */
		public function load(createIfMissing:Boolean = true):void {
			DebugView.addText ("Loading player profile \"" + this._profileName+"\"");			
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
		
		/**
		 * Attempts to load the icon specified in the profile XML data ('iconPath'), associated with this instance.
		 */
		private function loadIcon():void {
			DebugView.addText ("Loading icon from: " + iconPath); this._iconLoader = new Loader();
			this._iconLoader = new Loader();
			this._iconLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, this.onLoadIcon);
			if (this.iconPath.indexOf("lso://") > -1) {
				//load from LSO (probably web runtime)
				var varNameStartIndex:int = this.iconPath.indexOf("lso://") + 6;
				var lsoVarName:String = this.iconPath.substr(varNameStartIndex);
				var lso:SharedObject = SharedObject.getLocal("profileicons");
				DebugView.addText ("LSO variable: " + lsoVarName);				
				this._iconLoader.loadBytes(lso.data[lsoVarName]);
				lso.close();
			} else {
				//load from disk				
				var request:URLRequest = new URLRequest(this.iconPath);				
				this._iconLoader.load(request);
			}
		}
		
		/**
		 * Event listener invoked when the profile icon has been sucecssfully loaded and parsed. The 'iconLoaded' property is
		 * set to true and the icon data becomes available through any of the public getters.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onLoadIcon(eventObj:Event):void {			
			eventObj.target.removeEventListener(Event.COMPLETE, this.onLoadIcon);
			this._iconLoaded = true;
			var event:PlayerProfileEvent = new PlayerProfileEvent(PlayerProfileEvent.UPDATED);
			this.dispatchEvent(event);
		}
	}
}
/**
* Core or root container for all Starling / Feathers elements.
* 
* This implementation uses a simple delay timer to establish the leader/dealer role.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
	
	import starling.display.Sprite;
	import starling.events.Event;
	import feathers.themes.MetalWorksMobileTheme;
	import feathers.controls.Button;
	
	dynamic public class StarlingContainer extends Sprite {
		
		public static var onInitialize:Function = null; //callback function to invoke when initialization is complete
		public static var instance:StarlingContainer; //the singleton instance of StarlingContainer
		private var _containers:Vector.<Object> = new Vector.<Object>(); //child containers for various modules
		
		public function StarlingContainer() {
			instance = this;
			this.addEventListener(Event.ADDED_TO_STAGE, this.initialize);
		}
		
		/**
		 * Creates a new Starling containing.
		 * 
		 * @param	owner A reference to the owner object of the new container. This property 
		 * is used when searching containers using the 'getContainer' method.
		 * @param	name The symbolic name of the new container. This property is used when searching
		 * containers using the 'getContainerByName' method.
		 * 
		 * @return The newly created Starling Sprite container.
		 */
		public function newContainer(owner:*, name:String = null):Sprite {
			var containerObj:Object = new Object();
			containerObj.owner = owner;
			containerObj.name = name;
			containerObj.target = new Sprite();
			this._containers.push(containerObj);
			return (containerObj.target);
		}
		
		/**
		 * Attempts to find a container instance by a specific owner reference.
		 * 
		 * @param	owner The owner reference, as specified when calling 'newContainer', to attempt to find.
		 * 
		 * @return The first matching container that matches the 'owner' reference, or null if one can't be found.
		 */
		public function getContainer(owner:*):Sprite {
			for (var count:int = 0; count < this._containers.length; count++) {
				var currentContainerObj:Object = this._containers[count];
				if (currentContainerObj.owner == owner) {
					return (currentContainerObj.target);
				}
			}
			return (null);
		}
		
		/**
		 * Attempts to find a container instance by a specific symbolic name.
		 * 
		 * @param	name The symbolic name, as specified when calling 'newContainer', to attempt to find.
		 * 
		 * @return The first matching container that matches the 'name' or null if one can't be found.
		 */
		public function getContainerByName(name:String):Sprite {
			for (var count:int = 0; count < this._containers.length; count++) {
				var currentContainerObj:Object = this._containers[count];
				if ((currentContainerObj.name == name) && (currentContainerObj.name != null)) {
					return (currentContainerObj.target);
				}
			}
			return (null);
		}
		
		/**
		 * Event handler invoked when the instance is added to the stage.
		 * 
		 * @param	eventObj A Starling Event object.
		 */
		private function initialize(eventObj:Event):void {
			this.removeEventListener(Event.ADDED_TO_STAGE, this.initialize);			
			if (onInitialize != null) {
				onInitialize(this);
			}
		}
	}
}
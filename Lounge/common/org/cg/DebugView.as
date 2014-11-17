/**
* Developer debugging and logging class.
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg 
{
	
	import flash.display.MovieClip;
	import flash.events.ContextMenuEvent;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.ui.ContextMenuBuiltInItems;
	import flash.ui.ContextMenuClipboardItems;
	import flash.ui.Keyboard;
	import flash.desktop.Clipboard;
	import flash.desktop.ClipboardFormats;
	import flash.desktop.ClipboardTransferMode;
	import org.cg.interfaces.IView;
	
	public class DebugView extends MovieClip implements IView 
	{
		
		private static var _debugLog:Vector.<String> = new Vector.<String>(); //debug messages added in order
		private var _currentDebugPosition:int = 0; //current line in _debugLog
		private static var _instances:Vector.<DebugView> = new Vector.<DebugView>();
		private var _toggleContextAction:ContextMenuItem = null; //switches to debugview
		private var _copyContextAction:ContextMenuItem = null; //copies log to clipboard
		
		public function DebugView() 
		{
			_instances.push(this);
			addEventListener(Event.ADDED_TO_STAGE, initialize);
			addEventListener(Event.REMOVED_FROM_STAGE, destroy);
			super();			
		}
		
		/**
		 * Initializes the view. Implements IView interface.
		 */
		public function initView():void 
		{
			addText("DebugView.initView");
		}
		
		/**
		 * Add text to the debug log and output stream.
		 * 
		 * @param	textStr An ActionScript object to trace to
		 * the debug log and output stream, like the trace() parameter.
		 */
		public static function addText(textStr:*):void 
		{			
			_debugLog.push(String(textStr) + "\n");
			trace (textStr);
		}
		
		/**
		 * Resets all DebugView instances by clearing the log and log displays.
		 */
		public static function reset():void 
		{
			_debugLog = new Vector.<String>();
			for (var count:uint = 0; count < _instances.length; count++) {
				_instances[count].resetDebugText();
			}//for	
		}
		
		/**
		 * Clears the displays of all of the DebugView instances, but does not
		 * clear the log.
		 * 
		 * @param	updateAfterClear If true, the DebugView instances will be
		 * updated with any new log messages added since the last update.
		 */
		public static function clear(updateAfterClear:Boolean = false):void 
		{
			for (var count:uint = 0; count < _instances.length; count++) {
				_instances[count].clearDebugText(updateAfterClear);
			}
		}
		
		/**
		 * Destroys the DebugView and removes it from its parent display list.
		 * 
		 * @param	... args
		 */
		public function destroy(... args):void 
		{
			removeEventListener(Event.REMOVED_FROM_STAGE, destroy);
			//stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			var compInstances:Vector.<DebugView> = new Vector.<DebugView>();
			for (var count:uint = 0; count < _instances.length; count++) {
				var currentInstance:DebugView = _instances[count];
				if (currentInstance != this) {
					compInstances.push(currentInstance);
				}
			}
			_instances = compInstances;
		}
		
		/**
		 * Resets the debug log position. Does not clear the contents.
		 */
		protected function resetDebugText():void 
		{
			_currentDebugPosition = 0;
		}
		
		/**
		 * Clears the contents of the debug log and resets its position.
		 * 
		 * @param	updateAfterClear If true, an update is invoked in the debugging UI after
		 * the reset.
		 */
		protected function clearDebugText(updateAfterClear:Boolean = false):void 
		{
			_debugLog = new Vector.<String>();
			resetDebugText();
			if (updateAfterClear) {
				updateDebugText();
			}
		}
		
		/**
		 * Updates the debugging UI.
		 */
		protected function updateDebugText():void 
		{
		}
		
		/**
		 * Copies the debugging log to the OS clipboard.
		 */
		private function copyLogToClipboard():void 
		{
			var dataStr:String = new String();
			for (var count:int = 0; count < _debugLog.length; count++) {
				dataStr += _debugLog[count] + "\n";
			}
			Clipboard.generalClipboard.setData(ClipboardFormats.TEXT_FORMAT, dataStr, true);
		}
		
		/**
		 * Handles "copy to clipboard" functionality via mouse click.
		 * 
		 * @param	eventObj A MouseEvent object.
		 */
		private function onCopyClick(eventObj:MouseEvent):void 
		{
			copyLogToClipboard();
		}
		
		/**
		 * Toggles UI visibility.
		 */
		private function toggleViewVisibility():void 
		{
			if (visible == false) {
				//about to show view...				
				parent.setChildIndex(this, parent.numChildren - 1);
				visible = true;
				updateDebugText();
			} else {
				visible = false;
			}			
		}
		
		
		/**
		 * Handles player context menu selections.
		 * 
		 * @param	eventObj A ContextMenuEvent object.
		 */
		private function onContextMenuSelect(eventObj:ContextMenuEvent):void 
		{			
			var contextMenuItem:ContextMenuItem = eventObj.target as ContextMenuItem;
			if (contextMenuItem == _toggleContextAction) {
				toggleViewVisibility();
			}
			if (contextMenuItem == _copyContextAction) {
				onCopyClick(null);
			}
		}
		
		/**
		 * Handles key press events.
		 * 
		 * @param	eventObj A KeyBoardEvent object.
		 */
		private function onKeyPress(eventObj:KeyboardEvent):void 
		{			
			if (eventObj.ctrlKey) {
				if ((eventObj.charCode == 96) || (eventObj.charCode == 126)) {
					toggleViewVisibility();		
				}
			}
		}
		
		/**
		 * Initializes tne DebugView instance and adds context menu options.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function initialize(eventObj:Event):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, initialize);			
			if (ContextMenu.isSupported) {
				var menu:ContextMenu = new ContextMenu();							
				_copyContextAction = new ContextMenuItem("Copy debug log to clipboard", "copydebuglog"));
				_copyContextAction.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, onContextMenuSelect);
				menu.customItems.push(_copyContextAction);
				parent.contextMenu = menu;
				menu.hideBuiltInItems();	
			}
			//stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);			
			visible = false;
		}
		
	}

}
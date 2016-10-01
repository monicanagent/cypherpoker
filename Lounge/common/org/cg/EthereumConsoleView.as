/**
* Ethereum client debugging, logging, and interactivity class. 
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg 
{		
	import Ethereum;
	import com.bit101.components.InputText;
	import flash.display.MovieClip;
	import flash.events.ContextMenuEvent;
	import flash.events.DataEvent;
	import flash.events.Event;
	import events.EthereumWeb3ClientEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.ui.ContextMenu;
	import flash.ui.ContextMenuItem;
	import flash.ui.ContextMenuBuiltInItems;
	import flash.ui.ContextMenuClipboardItems;
	import flash.ui.Keyboard;
	import org.cg.interfaces.ILounge;	
	import flash.desktop.Clipboard;
	import flash.desktop.ClipboardFormats;
	import flash.desktop.ClipboardTransferMode;
	import flash.utils.ByteArray;
	import flash.utils.getTimer;
	import org.cg.interfaces.IView;
	import com.bit101.components.TextArea;
	import com.bit101.components.PushButton;
	import com.bit101.components.CheckBox;
	import flash.utils.IDataOutput;
	
	public class EthereumConsoleView extends MovieClip implements IView 
	{
					
		
		private static var _debugLog:Vector.<String> = new Vector.<String>(); //debug messages added in order
		private var _currentDebugPosition:int = 0; //current line in _debugLog
		private static var _instances:Vector.<EthereumConsoleView> = new Vector.<EthereumConsoleView>();
		private var _contextMenu:ContextMenu = null;
		private var _toggleContextAction:ContextMenuItem = null; //switches to console view		
		private var _clearContextAction:ContextMenuItem = null; //clears log
		
		private static var _ethereum:Ethereum = null;
		private static var _client:EthereumWeb3Client = null;
		private var _consoleSTDIN:IDataOutput = null;		
		private var _STDIN_EOL:String = String.fromCharCode(10);// + String.fromCharCode(13); //STDIN End-Of-Line character(s)
		
		protected var _textEntryPrompt:String = "{ENTER CONSOLE COMMANDS HERE}";
		public var consoleText:TextArea;
		public var inputText:TextArea;
		protected var clearDebugBtn:PushButton;
		protected var compileClipboardBtn:PushButton;
		protected var toggleDebugBtn:PushButton;
		protected var submitBtn:PushButton;
		protected var compileFileBtn:PushButton;
		protected var enterSubmitToggle:CheckBox
		
		/**
		 * Creates a new instance. Add the instance to the display list to initialize.
		 */
		public function EthereumConsoleView() 
		{		
			_instances.push(this);
			addEventListener(Event.ADDED_TO_STAGE, this.initialize);
			addEventListener(Event.REMOVED_FROM_STAGE, this.destroy);
			super();			
		}
		
		/**
		 * Associates an EthereumWeb3Client instance with this console view instance for input/output.
		 * 
		 * @param	clientRef A reference to a valid EthereumWeb3Client instance.
		 */
		public function attachClient(clientRef:EthereumWeb3Client):void {
			_client = clientRef;
			this._consoleSTDIN = clientRef.STDIN;
			if (this._consoleSTDIN != null) {
				addText("View #"+instanceNum(this)+" attached to console STDIN.");				
			}
			stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);	
			stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			_ethereum = new Ethereum(_client);
		}	
		
		/**
		 * Returns an instance number for a specified EthereumConsoleView instance.
		 * 
		 * @param	instanceRef A reference to the EthereumConsoleView instance for which to find an instance number for.
		 * 
		 * @return The instance number of the specified EthereumConsoleVew instance.
		 */
		public static function instanceNum(instanceRef:EthereumConsoleView):int {
			for (var count:int = 0; count < _instances.length; count++) {
				if (_instances[count] == instanceRef) {
					return (count);
				}
			}
			return ( -1);
		}
		
		/**
		 * Returns a specific EthereumConsoleView instance.
		 * 
		 * @param	instanceNum the instance number of the EthereumConsoleView instance to return.
		 * 
		 * @return The EthereumConsoleView instance specified.
		 */
		public static function instance(instanceNum:int):EthereumConsoleView {			
			return (_instances[instanceNum]);
		}
		
		/**
		 * Initializes the view. Implements IView interface.
		 */
		public function initView():void 
		{			
			consoleText = new TextArea(this);
			consoleText.width = stage.stageWidth;
			consoleText.height = stage.stageHeight-180;			
			consoleText.selectable = true;
			consoleText.editable = false;			
			inputText = new TextArea(this);
			inputText.width = stage.stageWidth;
			inputText.height = 150;
			inputText.y = stage.stageHeight - 180;
			inputText.selectable = true;			
			inputText.editable = true;	
			inputText.text = this._textEntryPrompt;
			inputText.addEventListener(MouseEvent.CLICK, this.onInputTextClick);
			clearDebugBtn = new PushButton(this, 0, stage.stageHeight-25, "CLEAR", onClearClick);			
			toggleDebugBtn = new PushButton(this, 110, stage.stageHeight - 25, "TOGGLE CONSOLE", onToggleClick);
			submitBtn = new PushButton(this, 220, stage.stageHeight - 25, "SUBMIT", onSubmitClick);
			compileClipboardBtn = new PushButton(this, 330, stage.stageHeight - 25, "COMPILE & DEPLOY CLIPBOARD", onCompileClipboardClick);
			compileClipboardBtn.width = 150;
			compileFileBtn =  new PushButton(this, 490, stage.stageHeight - 25, "COMPILE & DEPLOY FILE", onCompileSolidityClick);
			compileFileBtn.width = 130;
			//we check state for toggle when necessary so no event listener used
			enterSubmitToggle = new CheckBox(this, 635, stage.stageHeight - 20, "SUBMIT ON ENTER");
			enterSubmitToggle.selected = true;
		}
		
		/**
		 * Add text to the debug log and output stream.
		 * 
		 * @param	textStr An ActionScript object to trace to
		 * the debug log and output stream, like the trace() parameter.
		 * @param	omitLE If true the line-end character is omitted from the output.
		 */
		public static function addText(textStr:*, omitLE:Boolean = false):void 
		{			
			if (omitLE) {
				if (_client!=null) {
					_client.coopProxyOutput(textStr);
				}
				_debugLog.push(String(textStr));	
			} else {
				if (_client!=null) {
					_client.coopProxyOutput(textStr + "\n");
				}
				_debugLog.push(String(textStr) + "\n");	
			}
			trace (textStr);
			for (var count:int = 0; count < _instances.length; count++) {
				_instances[count].updateDebugText();
			}			
		}
		
		/**
		 * Resets all EthereumConsoleView instances by clearing the log and log displays.
		 */
		public static function reset():void 
		{
			_debugLog = new Vector.<String>();
			for (var count:uint = 0; count < _instances.length; count++) {
				_instances[count].resetDebugText();
			}	
		}
		
		/**
		 * Clears the displays of all of the EthereumConsoleView instances, but does not
		 * clear the log.
		 * 
		 * @param	updateAfterClear If true, the EthereumConsoleView instances will be
		 * updated with any new log messages added since the last update.
		 */
		public static function clear(updateAfterClear:Boolean = false):void 
		{
			for (var count:uint = 0; count < _instances.length; count++) {
				_instances[count].clearDebugText(updateAfterClear);
			}
		}
		
		/**
		 * Destroys the EthereumConsoleView and removes it from its parent display list.
		 * 
		 * @param	... args
		 */
		public function destroy(... args):void 
		{
			removeEventListener(Event.REMOVED_FROM_STAGE, destroy);
			stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			var compInstances:Vector.<EthereumConsoleView> = new Vector.<EthereumConsoleView>();
			for (var count:uint = 0; count < _instances.length; count++) {
				var currentInstance:EthereumConsoleView = _instances[count];
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
			consoleText.text="";
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
			if (_currentDebugPosition > _debugLog.length) {
				_currentDebugPosition = 0;	
			}
			for (var count:int = _currentDebugPosition; count < _debugLog.length; count++) {
				try {
					consoleText.text += _debugLog[count];
					_currentDebugPosition++;
				} catch (err:*) {					
				}
			}
			this.inputText.scrollToEnd();
		}
		
		/**
		 * Handles "copy to clipboard" functionality via mouse click.
		 * 
		 * @param	eventObj A MouseEvent object.
		 */
		protected function onCompileClipboardClick(eventObj:MouseEvent):void 
		{
			var solditySource:String = Clipboard.generalClipboard.getData(ClipboardFormats.TEXT_FORMAT) as String;
			_client.removeEventListener(EthereumWeb3ClientEvent.SOLCOMPILED, this.onCompileSolidity);
			_client.addEventListener(EthereumWeb3ClientEvent.SOLCOMPILED, this.onCompileSolidity);
			addText("Starting miner...");
			_client.web3.miner.start();
			_client.compileSolidityData(solditySource);
		}
		
		/**
		 * Handles "clear clipboard" functionality via mouse click.
		 * 
		 * @param	eventObj A MouseEvent object.
		 */
		protected function onClearClick(eventObj:MouseEvent):void 
		{			
			clearDebugText(true);
		}
		
		/**
		 * Handles "toggle log" functionality via mouse click.
		 * 
		 * @param	eventObj A MouseEvent object.
		 */
		protected function onToggleClick(eventObj:MouseEvent):void 
		{
			toggleViewVisibility();
		}
		
		/**
		 * Handles "submit" (to client) functionality via mouse click.
		 * 
		 * @param	eventObj A MouseEvent object.
		 */
		protected function onSubmitClick(eventObj:MouseEvent):void 
		{
			this.submitToSTDIN(this.inputText.text);
		}
		
		/**
		 * Event handler invoked when the "Compile & Deploy File" button is clicked.
		 * 
		 * @param	eventObj A standard MouseEvent object.		 
		 */
		protected function onCompileSolidityClick(eventObj:MouseEvent):void {
			_client.removeEventListener(EthereumWeb3ClientEvent.SOLCOMPILED, this.onCompileSolidity);
			_client.addEventListener(EthereumWeb3ClientEvent.SOLCOMPILED, this.onCompileSolidity);
			addText("Starting miner...");
			_client.web3.miner.start();
			_client.compileSolidityFile();
		}
		
		/**
		 * Even handler invoked when Solidity source code has been successfully compiled.
		 * 
		 * @param	eventObj An EthereumWeb3Client event object.
		 */
		protected function onCompileSolidity(eventObj:EthereumWeb3ClientEvent):void {
			_client.removeEventListener(EthereumWeb3ClientEvent.SOLCOMPILED, this.onCompileSolidity);			
			_ethereum.deployLinkedContracts(eventObj.compiledData, _client.web3.eth.accounts[0], "test");
		}
		
		/**
		 * Submits data to the STANDARD INPUT of a native Ethereum client console. If the client was not started natively
		 * by the current application instance then the data is sent to a cooperative instance (via LocalConnection) if available.
		 * 
		 * @param	data The data (e.g. command) to send.
		 * @param   raw If true the data to be sent will be sent as-is (without processing or additional linefeeds, etc.)
		 */
		public function submitToSTDIN(data:String):void {
			if (data == _textEntryPrompt) {
				return;
			}
			consoleText.text += data;			
			if (this._consoleSTDIN != null) {				
				try {					
					var dataSplit:Array = data.split(String.fromCharCode(13));
					for (var count:Number = 0; count < dataSplit.length; count++) {
						this._consoleSTDIN.writeMultiByte(dataSplit[count]+_STDIN_EOL, "us-ascii");
					}					
					this.inputText.textField.text = "";
					this.inputText.textField.addEventListener(Event.CHANGE, this.onInputFieldUpdated);					
					_client.coopProxyOutput(data + _STDIN_EOL);									
				} catch (err:*) {					
					consoleText.text += "STDIN not available. Is Ethereum child process running?\n";					
				}
			} else {				
				_client.coopProxyInput(data);
			}
		}
		
		/**
		 * Event handler invoked when the console input text field is clicked on. This will clear the text if it
		 * is currently the default text entry prompt.
		 * 
		 * @param	eventObj A standard MouseEvent object.
		 */
		protected function onInputTextClick(eventObj:MouseEvent):void {
			if (inputText.text == _textEntryPrompt) {
				inputText.text = "";
			}
		}
		
		/**
		 * Toggles UI visibility.
		 */
		protected function toggleViewVisibility():void 
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
		protected function onContextMenuSelect(eventObj:ContextMenuEvent):void 
		{			
			var contextMenuItem:ContextMenuItem = eventObj.target as ContextMenuItem;
			if (contextMenuItem == _toggleContextAction) {
				toggleViewVisibility();
			}			
			if (contextMenuItem == _clearContextAction) {
				clear(true);
			}
		}
		
		/**
		 * Handles key press events.
		 * 
		 * @param	eventObj A KeyBoardEvent object.
		 */
		protected function onKeyPress(eventObj:KeyboardEvent):void 
		{
			if (enterSubmitToggle.selected && this.visible) {				
				if (eventObj.charCode == Keyboard.ENTER) {
					this.submitToSTDIN(this.inputText.text);
				}
				//The following doesn't work correctly but may be useful
				/*
				if ((String.fromCharCode(eventObj.charCode).toLowerCase() == "c") && (eventObj.controlKey)) {
					///send CTRL-C to running process
					this.submitToSTDIN(String.fromCharCode(3));
				}
				*/
			}
		}
			
		/**
		 * Event listener invoked when the console input text field has been updated. This function will clear the input text field.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		protected function onInputFieldUpdated(eventObj:Event):void {
			this.inputText.textField.text = "";
			this.inputText.textField.removeEventListener(Event.CHANGE, this.onInputFieldUpdated);
		}
		
		/**
		 * Initializes tne EthereumConsoleView instance and adds context menu options.
		 * 
		 * @param	eventObj An Event object.
		 */
		protected function initialize(eventObj:Event):void 
		{
			removeEventListener(Event.ADDED_TO_STAGE, initialize);			
			if (ContextMenu.isSupported) {				
				if (parent.contextMenu == null) {
					var _contextMenu:ContextMenu = new ContextMenu();						
				} else {
					_contextMenu = parent.contextMenu as ContextMenu;
				}
				_toggleContextAction = new ContextMenuItem("ETHEREUM » Toggle console");
				_toggleContextAction.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, onContextMenuSelect);				
				_clearContextAction = new ContextMenuItem("ETHEREUM » Clear console");
				_clearContextAction.addEventListener(ContextMenuEvent.MENU_ITEM_SELECT, onContextMenuSelect);
				_contextMenu.customItems.push(_toggleContextAction);				
				_contextMenu.customItems.push(_clearContextAction);
				_contextMenu.hideBuiltInItems();
				parent.contextMenu = _contextMenu;				
			}
			visible = false;
		}		
	}
}
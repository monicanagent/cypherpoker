/**
* Provides Ethereum client API services integration via the Web3.js library.
* 
* (C)opyright 2014-2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package 
{	
	import events.EthereumWeb3ClientEvent;
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.events.IOErrorEvent;
	import flash.events.UncaughtErrorEvent;
	import flash.net.URLRequest;
	import flash.net.LocalConnection;
	import flash.net.SharedObject;
	import flash.system.ApplicationDomain;
	import flash.events.EventDispatcher;
	import flash.utils.ByteArray;
	import flash.utils.IDataOutput;
	import flash.utils.setTimeout;
	import flash.external.ExternalInterface;
	import flash.utils.getDefinitionByName;
	import EthereumWeb3Proxy;
	import deng.fzip.FZip;
	import com.hurlant.crypto.hash.SHA256;
	import flash.utils.setTimeout;
	import org.cg.DebugView;
	import org.cg.EthereumConsoleView;	
	
	public class EthereumWeb3Client extends EventDispatcher
	{	
		public static const version:String = "1.0"; //current version of the EthereumWeb3Client class, usually used for compatibility detection
		public static const localConnectionNamePrefix:String = "_EthereumWeb3Client_";
		
		//Native Ethereum client settings (not used when Ethereum client is started independently):
				
		public static const CLIENTNET_OLYMPIC:String = "NativeClientMode_OLYMPIC"; //usedin conjunction with "_nativeClientNetwork" to start client in pre-configured Olympic mode
		public static const CLIENTNET_TEST:String = "NativeClientMode_TESTNET"; //usedin conjunction with "_nativeClientNetwork" to start client in pre-configured test-net mode
		public static const CLIENTNET_DEV:String = "NativeClientMode_DEVNET"; //usedin conjunction with "_nativeClientNetwork" to start client in pre-configured dev-net mode
		//Native client update information. The first entry is the newest/most recent, the second is the second newest/most recent, etc.,
		//so nativeClientUpdates[0] should be the most current version. Usually this vector is populated by a containing Lounge from settings XML data.
		public static var nativeClientUpdates:Vector.<Object> = new <Object>[
			{
				url:"https://github.com/ethereum/go-ethereum/releases/download/v1.4.18/geth-windows-amd64-1.4.18-ef9265d0.zip",				           
				sha256sig:"d26dd020c7c2a3bbae9e9cdfb278a24d2e840be3910c88b87e7a04fb46fa7bf1", 
				version:"1.4.18"				
			},
			{
				url: "https://github.com/ethereum/go-ethereum/releases/download/v1.4.11/Geth-Win64-20160818153642-1.4.11-fed692f.zip",
				sha256sig:"",
				version:"1.4.11"
			}
		];
		//Should the SHA256 signature of a downloaded native client ZIP file be checked against nativeClientUpdates data? Verification is very slow so use only when necessary.
		public static var verifyNativeClientSig:Boolean = true;
		public static var useNativeClientIndex:uint = 0; //The index of the native client update data to use currently
		//List of valid executable names. When running as a native desktop app and direct Ethereum client integration is being used, these will be tried sequentially until one is found.
		//File names found here are used for both native file searches and for searching within download ZIP updates.
		public static var nativeClientExecs:Vector.<String> = new < String > ["geth.exe"];		
		private var _nativeClientFolder:*; //(File) containing folder of the native client executable
		private var _clientPath:*; //(File) _nativeClientFolder + valid nativeClientExecs entry
		private var _nativeClientProc:*; //(NativeProcess) A reference to the NativeProcess instance handling the Ethereum client.
		private var _solcProc:*; //(NativeProcess) A reference to the NativeProcess instance handling the native Solidity compiler (solc.exe)
		private static const _solcPath:String = "app:/ethereum/solc/"; //path to native Solidity compiler (include trailing slash!)
		private static const _solcExecutable:String = "solc.exe"; //name of native Solidity compiler executable
		private var _solcFile:*; //(File) Resolved File reference to the solc compiler.
		private var _compiledData:String = new String(); //compiled solidity data in JSON format, as output from solc compiler
		public var coopMode:Boolean = true; //if true, instance is started in "cooperative mode" which uses settings from the first active and verified instance on the machine.
		private var _nativeClientLC:LocalConnection; //used to detect multiple running instances in "cooperative mode"
		private var _nativeClientLCName:String; //connection name for the current instance when running in "cooperative mode"
		private var _nativeClientProxyOuts:Vector.<String> = new Vector.<String>(); //proxied client outputs when running in "cooperative mode"
		private var _nativeClientNetwork:String = null; //native client network; may be null empty string for live mode (default), or one of the CLIENTMODE_* constants
		private var _nativeClientPort:uint = 30304; //default client listening port (use 0 for default)
		private var _nativeClientNetworkID:int = 1; //network ID:  0=Olympic, 1=Frontier, 2=Morden; other IDs are considered private
		private var _nativeClientFastSync:Boolean = true; //If true, use state downloads for fast blockchain synchronization
		private var _lightkdf:Boolean = true; //if true, reduce key-derivation RAM & CPU usage at some expense of KDF strength
		private var _nativeClientRPCCORSDomain:String="*"; //default client allowed cross-domain URL
		private var _nativeClientDataDir:String = "./data/"; //default data directory, relative to the Ethereum client executable (leave null for default), %#% metacode will be replaced by instance number		
		public var nativeClientInitGenesis:Boolean = false;	//if true the native client is initialized with the custom genesis block and then relaunched
		//Custom genesis block for dev/test/private net uses. Pre-accolated Ether to address "e57dc93f87a9a0860afe46fe8dfa7042081fdf0e" (extra nodes may be added)
		public var nativeClientGenesisBlock:XML = <blockdata>
<![CDATA[{
	"nonce": "0xdeadbeefdeadbeef",
	"timestamp": "0x0",
	"parentHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
	"extraData": "0x0",
	"gasLimit": "0xF000000000",
	"difficulty": "0x400",
	"mixhash": "0x0000000000000000000000000000000000000000000000000000000000000000",
	"coinbase": "0x3333333333333333333333333333333333333333",
	"alloc": {
      "e57dc93f87a9a0860afe46fe8dfa7042081fdf0e":{
         "balance":"100000000000000000000000000000"
      }
   }
}]]></blockdata>
		
		private var _web3Container:* = null; //Web3 client container
		private var _clientAddress:String = null; //client address (e.g. "127.0.0.1")
		private var _clientPort:uint = 0; //client port (eg. 8545)
		private var _ready:Boolean = false; //is client initialized?
		
		/**
		 * Creates a new instance.
		 * 
		 * @param clientAddress The address of the Ethereum client's RPC host.
		 * @param clientPort  The port of the Ethereum client's RPC host.
		 * @param nativeClientFolder  An optional string or File object pointing to the containing folder of the Ethereum installation. If the
		 * folder doesn't exist, it will be created. If no value or nulll are provided, no native client process will be used. One instance is shared
		 * among all active EthereumWeb3Client instances.
		 * @param dataDir The directory within the native client installation folder to use for the native Ethereum client's data. Default is "./data/".
		 * This value is ignored if the current runtime is unable to launch native client executables. To use the blockchain & wallet data of a specific 
		 * installed version use a path such as "../v1.4.18/data/" (for version 1.4.18).
		 * 
		 */
		public function EthereumWeb3Client(clientAddress:String="localhost", clientPort:uint=8545, nativeClientFolder:*=null, dataDir:String=null) 
		{
			DebugView.addText("EthereumWeb3Client created.");
			DebugView.addText("         Client address: " + clientAddress);
			DebugView.addText("            Client port: " + clientPort);
			DebugView.addText("   Native client folder: " + nativeClientFolder);
			if ((dataDir != null) && (dataDir != "")) {
				this._nativeClientDataDir = dataDir;
			}
			_clientAddress = clientAddress;
			_clientPort = clientPort;			
			var vString:String = "v" + String(nativeClientUpdates[useNativeClientIndex].version);
			if (nativeClientFolder!=null) {
				if (nativeClientFolder is File) {
					_nativeClientFolder = nativeClientFolder;
				} else if (nativeClientFolder is String) {
					_nativeClientFolder = new File(nativeClientFolder+vString+"/");
				} else {					
					_nativeClientFolder = new File("app-storage:/ethereum_client/"+vString+"/");
				}				
			}
			super();
		}
		
		/**
		 * Initializes the new instance.
		 */
		public function initialize():void 
		{
			DebugView.addText("EthereumWeb3Client.initialize");	
			if (!coopMode) {
				DebugView.addText ("   Cooperative mode disabled. Using local settings.");
				this.onDetectCoopClient();
			} else {
				DebugView.addText ("   Cooperative mode enabled. Attempting to detect existing settings...");
				this.detectCoopClient();
			}
		}
		
		/**
		 * Begins the detection of a cooperative LocalConnection for sharing a native Ethereum client console.
		 */
		private function detectCoopClient():void {
			DebugView.addText("EthereumWeb3Client.detectCoopClient");	
			this._nativeClientLC = new LocalConnection();
			this._nativeClientLCName = null;
			var connCount:uint = 0;
			var testName:String = new String();
			while (this._nativeClientLCName == null) {
				connCount++;
				testName = localConnectionNamePrefix + String(connCount);
				try  {
					this._nativeClientLC.connect(testName);
					this._nativeClientLCName = testName;
				} catch (err:*) {
				}
			}
			DebugView.addText("   Local connection name resolved to: " + this._nativeClientLCName);
			this._nativeClientLC.allowDomain("*");
			this._nativeClientLC.allowInsecureDomain("*");
			this._nativeClientLC.client = this;
			if (connCount > 1) {
				//this is a secondary instance
				this._nativeClientLC.send(localConnectionNamePrefix+"1", "getConnectionInfo", this._nativeClientLCName);
			} else {
				//this is the initial instance
				this.onDetectCoopClient(false);
			}
		}
		
		/**
		 * LocalConnection responder function which replies with information about the current native client
		 * setup, if available.
		 * 
		 * @param	responseConnName A LocalConnection name to respond to with the client information object.
		 */
		public function getConnectionInfo(responseConnName:String):void {
			if (responseConnName == this._nativeClientLCName) {
				//don't respond to self!
				return;
			}
			DebugView.addText("EthereumWeb3Client.getConnectionInfo");
			DebugView.addText("Sending cooperative mode connection info to: " + responseConnName);
			var infoObj:Object = new Object();
			infoObj._clientAddress = this._clientAddress;
			infoObj._clientPort = this._clientPort;
			infoObj._clientPath = this._clientPath;			
			this._nativeClientLC.send(responseConnName, "onGetConnectionInfo", infoObj, this._nativeClientLCName);
		}
		
		/**
		 * LocalConnection responder function which stores information about an external, local Ethereum client
		 * instance capable of sharing its console and RPC connection.
		 * 
		 * @param	connectionInfo An object containing information about the external, local Ethereum client available
		 * for console and RPC sharing.
		 * @param	sourceConnName The source name of the external, local Ethereum client LocalConnection host.
		 */
		public function onGetConnectionInfo(connectionInfo:Object, sourceConnName:String):void {
			DebugView.addText("EthereumWeb3Client.onGetConnectionInfo");
			DebugView.addText("Received cooperative mode connection info from: " + sourceConnName);
			for (var item:* in connectionInfo) {
				DebugView.addText("   " + item + "=" + connectionInfo[item]);
				try {
					this[item] = connectionInfo[item];					
				} catch (err:*) {
					DebugView.addText("      Property \""+item+"\" can't be mapped locally: "+err);
				}
			}
			this._nativeClientLC.send(sourceConnName, "registerCoopProxyOut", this._nativeClientLCName);		
			this.onDetectCoopClient(true);
		}
		
		/**
		 * Sends console output from the native Ethereum client (running in this instance) to registered external 
		 * LocalConnection listeners.
		 * 
		 * @param	str The console string to send to registered LocalConnection listeners.
		 */
		public function coopProxyOutput(str:String):void {
			for (var count:int = 0; count < this._nativeClientProxyOuts.length; count++) {
				this._nativeClientLC.send(this._nativeClientProxyOuts[count], "onCoopProxyOutput", str);
			}
		}		
		
		/**
		 * Event listener invoked by a LocalConnection when an external native Ethereum client has sent console output.
		 * 
		 * @param	str The console output data sent from the native external Ethereum client.
		 */
		public function onCoopProxyOutput(str:String):void {
			EthereumConsoleView.addText(str);
		}
				
		/**
		 * Sends console input (for example, a command) to an external native Ethereum client via LocalConnection.
		 * 
		 * @param	str The console input to send to an external native Etherem client.
		 */
		public function coopProxyInput(str:String):void {
			this._nativeClientLC.send(localConnectionNamePrefix+"1", "onCoopProxyInput", str);
		}
		
		/**
		 * Inputs and logs a proxied command to the local native client stadard input pipe (as though it was typed locally).
		 * Invoked by external proxied client instances, usually via LocalConnection.
		 * 
		 * @param	str The command (or data) to send to the running native client instance.
		 */
		public function onCoopProxyInput(str:String):void {
			EthereumConsoleView.instance(0).submitToSTDIN(str);
		}
		
		/**
		 * Registers an external console to receive input and output from the local native Ethereum client.
		 * 
		 * @param	coopConnName The external LocalConnection name to register for Ethereum client console I/O.
		 */
		public function registerCoopProxyOut(coopConnName:String):void {
			DebugView.addText("EthereumWeb3Client.registerCoopProxyOut: " + coopConnName);
			this._nativeClientProxyOuts.push(coopConnName);
			this._nativeClientLC.send(coopConnName, "onCoopProxyOutput", EthereumConsoleView.instance(0).consoleText.text);
		}
		
		/**
		 * Function invoked when cooperative Ethereum client console detection has completed and initialization may continue.
		 * 
		 * @param	coopSet True of cooperative values such as port and address haev been externally set (i.e. the native Ethereum client
		 * is available externally via LocalConnection).
		 */
		private function onDetectCoopClient(coopSet:Boolean=false):void {
			DebugView.addText("EthereumWeb3Client.onDetectCoopClient. Coop mode variables assigned? "+coopSet);
			if ((_nativeClientFolder == null) || (coopSet) || (coopMode)) {
				this.loadWeb3Object();
			} else {
				this.loadNativeClient();
			}
		}
		
		/**
		 * A reference to the Ethereum Web3 object.
		 */
		public function get web3():Object {
			return (_web3Container.window.web3);
		}
		
		/**
		 * A reference to the CypherPoker JavaScript integration library object (usually the "window")
		 */
		public function get lib():Object {			
			return (_web3Container.window);
		}
		
		/**
		 * Network identifier (integer, 0=Olympic, 1=Frontier, 2=Morden). Default is 1 and other IDs are considered private. This value is ignored if 
		 * Ethereum client is not launched as a native process by this instance or if client has already been launched.
		 */
		public function set networkID(nIDSet:int):void {			
			this._nativeClientNetworkID = nIDSet;
		}
		
		public function get networkID():int {
			return (this._nativeClientNetworkID);
		}
			
		/**
		 * If true, native client fast synchronization is enabled through state downloads. This value is ignored
		 * if Ethereum client is not launched as a native process by this instance, or if client has already been launched.
		 */
		public function set fastSync(syncSet:Boolean):void {
			this._nativeClientFastSync = syncSet;
		}
		
		public function get fastSync():Boolean {
			return (this._nativeClientFastSync);
		}
		
		/**
		 * If true, native client key-derivation RAM and CPU usage are reduced at some expense of KDF strength.
		 * This value is ignored if Ethereum client is not launched as a native process by this instance or if client 
		 * has already been launched.
		 */
		public function set lightKDF(LKDFSet:Boolean):void {
			this._lightkdf = LKDFSet;
		}
		
		public function get lightKDF():Boolean {
			return (this._lightkdf);
		}
		
		public function set nativeClientNetwork(networkSet:String):void {
			switch (networkSet) {
				case CLIENTNET_OLYMPIC: 
					this._nativeClientNetwork = CLIENTNET_OLYMPIC;
					break;
				case CLIENTNET_TEST: 
					this._nativeClientNetwork = CLIENTNET_TEST;
					break;
				case CLIENTNET_DEV: 
					this._nativeClientNetwork = CLIENTNET_DEV;
					break;
				default:
					this._nativeClientNetwork = null;
					break;

			}
		}		
		
		/**
		 * @return Native client network setting. May be null empty string for live mode (default), or one of the CLIENTMODE_* constants.
		 */
		public function get nativeClientNetwork():String {
			return (this._nativeClientNetwork);
		}
		
		/**
		 * JavaScript-acccessible function to provide external "trace" output via the DebugView.
		 * 
		 * @param	traceObj The data (usually a string) to send to the DebugView output window.
		 */
		public function flashTrace(traceObj:*):void
		{
			DebugView.addText(traceObj);
		}
		
		/**
		 * Returns the IDataOutput (STANDARD INPUT) reference for the native client, if available (i.e. was started as a background 
		 * process by this instance), otherwise null is returned.
		 */
		public function get STDIN():IDataOutput {
			if (this._nativeClientProc == null) {
				return (null);
			}
			if (this._nativeClientProc.running == false) {
				return (null);
			}
			return (this._nativeClientProc.standardInput);
		}
		
		/**
		 * Compiles supplied Solidity source code.
		 * 
		 * @param	soliditySource The Solidity source code to compile. May contain multiple contracts and libraries.
		 * @param	fileRef An optional File object reference or path string in which to temporarily store the Solidity source
		 * code for compilation. If not supplied the file will be generated in the application storage directory as "solidity/$clipboard.sol".
		 */
		public function compileSolidityData(soliditySource:String, fileRef:* = null):void {
			if (fileRef!=null) {
				if (fileRef is String) {
					var solFile:*= this._nativeClientFolder.resolvePath(fileRef);
				}
				if (fileRef is File) {
					solFile = fileRef;
				}								
			} else {
				solFile = this._nativeClientFolder.resolvePath("app-storage:/Solidity/$clipboard.sol");				
			}
			var filestream:* = new FileStream();
			filestream.open(solFile, FileMode.WRITE);
			filestream.writeMultiByte(soliditySource, "iso-8859-1");
			filestream.close();		
			DebugView.addText("Wrote clipboard data to: " + solFile.nativePath);
			this.compileSolidityFile(solFile);
		}
		
		/**
		 * Begins the process of compiling a Solidity file using the native solc compiler.
		 * 
		 * @param An optional File object reference of path string pointing to the Solidity source code file to compile. If omitted the default
		 * browse-for-open file dialog will be opened to allow the user to select which file to compile. Multiple files are currently not supported.
		 * 
		 */
		public function compileSolidityFile(fileRef:* = null):void {
			if (fileRef!=null) {
				if (fileRef is String) {
					var solFile:*= this._nativeClientFolder.resolvePath(fileRef);
				}
				if (fileRef is File) {
					solFile = fileRef;
				}
				executeSolc(solFile);
				return;
			}
			var solFileFilter:* = new FileFilter("Solidity Source Files", "*.sol;*.solidity;*.txt");
			var file:* = new File();
			file.addEventListener(Event.SELECT, this.onSelectSolidityFile);
			file.addEventListener(Event.CANCEL, this.onSelectSolidityFileCancel);
			file.browseForOpen("Choose Solidity source file", [solFileFilter]);
		}
		
		/**
		 * Event listener invoked when a Solidity file is selected for compilation via the default system browse-for-open file dialog. The method
		 * invokes the executeSol method.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private function onSelectSolidityFile(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.SELECT, this.onSelectSolidityFile);
			eventObj.target.removeEventListener(Event.CANCEL, this.onSelectSolidityFileCancel);
			this.executeSolc(eventObj.target);
		}
		
		/**
		 * Event listener invoked when a Solidity file selection using the default system browser-for-open file dialog is cancelled.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private function onSelectSolidityFileCancel(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.SELECT, this.onSelectSolidityFile);
			eventObj.target.removeEventListener(Event.CANCEL, this.onSelectSolidityFileCancel);
		}
		
		/**
		 * Executes the native solc compiler in order to compile a specified Solidity source file. The compiler is instructed to 
		 * produce combined JSON output of any contained contracts or libraries including their ABI, compiled binary code (in hex), interface
		 * definition, developer documentation output, user documentation output, and generated opcodes. The output of the compiler is captured
		 * on the standard output pipe via the onSolcSTDO method.
		 * 
		 * @param	fileRef A File object reference pointing to the Solidity source code file to compile.
		 */
		private function executeSolc(fileRef:*):void {
			DebugView.addText("Compiling Solidity file: " + fileRef.nativePath);			
			_solcProc = new NativeProcess();
			_solcProc.addEventListener(ProgressEvent["STANDARD_OUTPUT_DATA"], this.onSolcSTDO); //standard out			
			_solcProc.addEventListener(ProgressEvent["STANDARD_ERROR_DATA"], this.onSolcSTDERR);
			_solcProc.addEventListener(NativeProcessExitEvent.EXIT, this.onSolidityCompileComplete);
			var procStartupInfo:* = new NativeProcessStartupInfo();
			procStartupInfo.executable = new File(_solcPath+_solcExecutable);
			DebugView.addText("Solidity compiler: "+ procStartupInfo.executable.nativePath);
			procStartupInfo.workingDirectory = new File(_solcPath);
			DebugView.addText("Working directory: "+ procStartupInfo.workingDirectory.nativePath);
			procStartupInfo.arguments = new Vector.<String>();
			procStartupInfo.arguments.push("--combined-json");
			//procStartupInfo.arguments.push("abi,bin,interface,devdoc,userdoc,opcodes");	
			procStartupInfo.arguments.push("abi,bin,interface");	
			procStartupInfo.arguments.push("--optimize");
			procStartupInfo.arguments.push(fileRef.nativePath);	
			_solcProc.start(procStartupInfo);
		}
		
		/**
		 * Event listener invoked whenever data is pushed to the standard output pipe by the solc compiler.
		 * 
		 * @param	eventObj A standard ProgressEvent object.
		 */
		private function onSolcSTDO(eventObj:ProgressEvent):void {			
			var stdOut:* = _solcProc.standardOutput;
			var data:String = stdOut.readUTFBytes(_solcProc.standardOutput.bytesAvailable);			
			this._compiledData += data;
		}
		
		/**
		 * Event listener invoked whenever data is pushed to the standard error pipe by the solc compiler.
		 * 
		 * @param	eventObj A standard ProgressEvent object.
		 */
		private function onSolcSTDERR(eventObj:ProgressEvent):void {			
			var stdErr:* = _solcProc.standardError;
			var data:String = stdErr.readUTFBytes(_solcProc.standardError.bytesAvailable);			
			DebugView.addText("solc.exe error: "+data);
		}		
		
		/**
		 * Event listener invoked when the solc compiler has signalled completion via an NativeProcessExitEvent.EXIT event. The data
		 * captured on the standard output pipe of the solc process is parsed to a native object from its JSON representation and a 
		 * EthereumWeb3ClientEvent.SOLCOMPILED event is dispatched.
		 * 
		 * @param	eventObj A NativeProcessExitEvent event object.
		 */
		private function onSolidityCompileComplete(eventObj:*):void {
			_solcProc.removeEventListener(ProgressEvent["STANDARD_OUTPUT_DATA"], this.onSolcSTDO);	
			_solcProc.removeEventListener(ProgressEvent["STANDARD_ERROR_DATA"], this.onSolcSTDERR);
			_solcProc.removeEventListener(NativeProcessExitEvent.EXIT, this.onSolidityCompileComplete);
			_solcProc = null;
			var event:EthereumWeb3ClientEvent = new EthereumWeb3ClientEvent(EthereumWeb3ClientEvent.SOLCOMPILED);
			event.compiledRaw = this._compiledData;			
			try {
				event.compiledData = JSON.parse(this._compiledData);
				this._compiledData = "";
				this.dispatchEvent(event);
			} catch (err:*) {
				DebugView.addText(err);
				DebugView.addText("Compiler output: " + this._compiledData);
			}
		}
		
		/**
		 * Eevent handler invoked when the Web3.js library had been loaded and initialized.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private function onWeb3Load(eventObj:Event):void
		{
			DebugView.addText("EthereumWeb3Client.onWeb3Load");	
			_web3Container.removeEventListener(Event.COMPLETE, onWeb3Load);
			try {
				if (_web3Container is EthereumWeb3Proxy) {
					_web3Container.refreshObjectMap();
				}
				if (_web3Container.window.connect(this._clientAddress, this._clientPort)) {	
					if ((_web3Container is EthereumWeb3Proxy) == false) {	
						_web3Container.window.gameObj = this;
						//_web3Container.window.flashTrace = this.flashTrace;
					}
					_ready = true;
					DebugView.addText("   Web3 client connected and listening.");
					var event:Event = new Event(EthereumWeb3ClientEvent.WEB3READY);
					setTimeout(dispatchEvent, 150, event); //extra time to allow listener(s) to be set when using proxy
				} else {
					DebugView.addText ("   Web3 library wasn't loaded! web3 and lib references will be unavailable.");
				}
			} catch (err:*) {
				DebugView.addText ("   "+err);
			}
		}
		
		/**
		 * Dynamically returns a referenece to the flash.html.HTMLLoader class, if available. Null is returned if the
		 * current runtime environment doesn't include HTMLLoader.
		 */
		private function get HTMLLoader():Class
		{
			try {
				var htmlLoaderClass:Class = getDefinitionByName("flash.html.HTMLLoader") as Class;
				return (htmlLoaderClass);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Dynamically returns a referenece to the flash.desktop.NativeProcess class, if available. Null is returned if the
		 * current runtime environment doesn't include NativeProcess.
		 */
		private function get NativeProcess():Class
		{
			try {
				var nativeProcessClass:Class = getDefinitionByName("flash.desktop.NativeProcess") as Class;
				return (nativeProcessClass);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Dynamically returns a referenece to the flash.events.NativeProcessExitEvent class, if available. Null is returned if the
		 * current runtime environment doesn't include NativeProcess.
		 */
		private function get NativeProcessExitEvent():Class
		{
			try {
				var nativeProcessEEClass:Class = getDefinitionByName("flash.events.NativeProcessExitEvent") as Class;
				return (nativeProcessEEClass);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Dynamically returns a referenece to the flash.desktop.NativeApplication class, if available. Null is returned if the
		 * current runtime environment doesn't include NativeApplication.
		 */
		private function get NativeApplication():Class
		{
			try {
				var nativeApplicationClass:Class = getDefinitionByName("flash.desktop.NativeApplication") as Class;
				return (nativeApplicationClass);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Dynamically returns a referenece to the flash.desktop.NativeProcessStartupInfo class, if available. Null is returned if the
		 * current runtime environment doesn't include NativeProcessStartupInfo.
		 */
		private function get NativeProcessStartupInfo():Class
		{
			try {
				var nativeProcessSIClass:Class = getDefinitionByName("flash.desktop.NativeProcessStartupInfo") as Class;
				return (nativeProcessSIClass);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Dynamically returns a referenece to the flash.filesystem.File class, if available. Null is returned if the
		 * current runtime environment doesn't include File.
		 */
		private function get File():Class
		{
			try {
				var fileClass:Class = getDefinitionByName("flash.filesystem.File") as Class;
				return (fileClass);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}		
		
		/**
		 * Dynamically returns a referenece to the flash.filesystem.FileStream class, if available. Null is returned if the
		 * current runtime environment doesn't include FileStream.
		 */
		private function get FileStream():Class
		{
			try {
				var fileStreamClass:Class = getDefinitionByName("flash.filesystem.FileStream") as Class;
				return (fileStreamClass);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Dynamically returns a referenece to the flash.filesystem.FileMode class, if available. Null is returned if the
		 * current runtime environment doesn't include FileMode.
		 */
		private function get FileMode():Class
		{
			try {
				var fileModeClass:Class = getDefinitionByName("flash.filesystem.FileMode") as Class;
				return (fileModeClass);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}
		
		/**
		 * Dynamically returns a referenece to the flash.net.FileReference class, if available. Null is returned if the
		 * current runtime environment doesn't include FileReference.
		 */
		private function get FileReference():Class
		{
			try {
				var fileReferenceClass:Class = getDefinitionByName("flash.net.FileReference") as Class;
				return (fileReferenceClass);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}		
		
		/**
		 * Dynamically returns a referenece to the flash.net.FileFilter class, if available. Null is returned if the
		 * current runtime environment doesn't include FileFilter.
		 */
		private function get FileFilter():Class
		{
			try {
				var fileFilterClass:Class = getDefinitionByName("flash.net.FileFilter") as Class;
				return (fileFilterClass);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}		
		
		/**
		 * Dynamically returns a referenece to the flash.events.HTMLUncaughtScriptExceptionEvent class, if available. Null is returned if the
		 * current runtime environment doesn't include HTMLUncaughtScriptExceptionEvent.
		 */
		private function get HTMLUncaughtScriptExceptionEvent():Class
		{
			try {
				var HTMLUSEEClass:Class = getDefinitionByName("flash.events.HTMLUncaughtScriptExceptionEvent") as Class;
				return (HTMLUSEEClass);
			} catch (err:*) {
				return (null);
			}
			return (null);
		}		
		
		/**
		 * Begins the process of loading the local native Ethereum client executable. If the client installation can't be found,
		 * a ZIP file download will be initiated.
		 */
		private function loadNativeClient():void {
			DebugView.addText("EthereumWeb3Client.loadNativeclient");
			DebugView.addText("   Native client storage location: " + this._nativeClientFolder.nativePath);
			if (this._nativeClientFolder.exists == false) {
				this._nativeClientFolder.createDirectory();
				this.downloadNativeClient(nativeClientUpdates[useNativeClientIndex].url);
			} else {
				for (var count:int = 0; count < nativeClientExecs.length; count++) {					
					this._clientPath = this._nativeClientFolder.resolvePath(nativeClientExecs[count]);
					DebugView.addText("   Checking for existence of file: " + this._clientPath.nativePath);
					if (this._clientPath.exists) {
						this.executeNativeClient(this.nativeClientInitGenesis);
					} else {
						this.downloadNativeClient(nativeClientUpdates[useNativeClientIndex].url);
						return;
					}
				}
			}
		}
		
		/**
		 * Starts the local native Ethereum client executable in "init" mode during which a custom genesis block is imported. The native
		 * Ethereum client is assumed to automatically exit when the genesis block has been fully imported.
		 */
		public function initGenesis():void {
			DebugView.addText("EthereumWeb3Client.initGenesis");			
			var genesisFile:*= this._nativeClientFolder.resolvePath("genesisblock.json"); //should match file name in createStartupArguments
			EthereumConsoleView.addText("Using custom genesis block: " + genesisFile.nativePath);
			EthereumConsoleView.addText(nativeClientGenesisBlock.toString());
			var fileStream:*= new FileStream();
			fileStream.open (genesisFile, FileMode.WRITE);				
			fileStream.writeMultiByte(this.nativeClientGenesisBlock, "iso-8895-1");
			fileStream.close();
			EthereumConsoleView.addText("Genesis block successfully generated.");
			_nativeClientProc = new NativeProcess();
			_nativeClientProc.addEventListener(ProgressEvent["STANDARD_OUTPUT_DATA"], this.onNativeClientSTDO); //standard out
			_nativeClientProc.addEventListener(ProgressEvent["STANDARD_ERROR_DATA"], this.onNativeClientSTDOErr); //error & info IO
			_nativeClientProc.addEventListener(NativeProcessExitEvent.EXIT, this.onInitGenesis);
			var procStartupInfo:* = new NativeProcessStartupInfo();
			procStartupInfo.executable = this._clientPath;
			procStartupInfo.workingDirectory = this._nativeClientFolder;
			procStartupInfo.arguments = new Vector.<String>();
			procStartupInfo.arguments.push("init");
			procStartupInfo.arguments.push("./genesisblock.json");			
			_nativeClientProc.start(procStartupInfo);			
		}
		
		/**
		 * Event listener invoked when the local native Ethereum client has completed importing the genesis block during an "init" operation.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private function onInitGenesis(eventObj:Event):void {
			DebugView.addText("EthereumWeb3Client.onInitGenesis");
			_nativeClientProc.removeEventListener(NativeProcessExitEvent.EXIT, this.onInitGenesis);
			_nativeClientProc.removeEventListener(ProgressEvent["STANDARD_OUTPUT_DATA"], this.onNativeClientSTDO);
			_nativeClientProc.removeEventListener(ProgressEvent["STANDARD_ERROR_DATA"], this.onNativeClientSTDOErr);
			try {
				_nativeClientProc.exit(true);
			} catch (err:*) {				
			}
			_nativeClientProc = null;
			this.executeNativeClient(false);
		}
		
		/**
		 * Executes the local native Ethereum client, optionally importing a custom genesis block first.
		 * 
		 * @param	createGenesis If true, a custom genesis block will first be imported after which this function will be re-run
		 * in order to start the client fully.
		 */
		private function executeNativeClient(createGenesis:Boolean=false):void {
			if (createGenesis) {
				this.initGenesis();
				return;
			}			
			DebugView.addText("EthereumWeb3Client.executeNativeClient");			
			NativeApplication.nativeApplication.addEventListener(Event["EXITING"], this.onApplicationClosing);
			_nativeClientProc = new NativeProcess();
			_nativeClientProc.addEventListener(ProgressEvent["STANDARD_OUTPUT_DATA"], this.onNativeClientSTDO); //standard IO
			_nativeClientProc.addEventListener(ProgressEvent["STANDARD_ERROR_DATA"], this.onNativeClientSTDOErr); //error & info IO
			var procStartupInfo:* = new NativeProcessStartupInfo();
			procStartupInfo.executable = this._clientPath;
			procStartupInfo.workingDirectory = this._nativeClientFolder;
			procStartupInfo.arguments = this.createStartupArguments();
			var commandLine:String = this._clientPath.nativePath;
			for (var count:int = 0; count < procStartupInfo.arguments.length; count++) {
				commandLine+= " " + procStartupInfo.arguments[count];
			}
			DebugView.addText(commandLine);
			_nativeClientProc.start(procStartupInfo);			
			DebugView.addText("   Process successfully started? " + _nativeClientProc.running);
			if (_nativeClientProc.running) {
				this.loadWeb3Object();
			}
		}
		
		/**		 
		 * @return Startup arguments with which to execute the local native Ethereum client, based on the settings of this
		 * instance.
		 */
		private function createStartupArguments():Vector.<String> {
			var args:Vector.<String> = new Vector.<String>();			
			args.push("--verbosity");
			args.push("3");
			if (this._nativeClientPort>0) {
				args.push("--port");
				args.push(String(this._nativeClientPort));
			}
			args.push("--ipcdisable");
			args.push("--rpc");
			args.push("--rpcport");
			args.push(String(this._clientPort));			
			args.push("--rpcapi");
			args.push("db,eth,net,web3,admin,personal,miner,debug,shh,txpool");
			args.push("--rpccorsdomain");
			args.push(this._nativeClientRPCCORSDomain);			
			if (this._nativeClientDataDir!=null) {
				args.push("--datadir");
				var dataDir:String = this._nativeClientDataDir;
				args.push(dataDir);
			}		
			if (this._nativeClientFastSync) {
				args.push("--fast");
			}			
			if (this._lightkdf) {
				args.push("--lightkdf");
			}
			if (this._nativeClientNetwork == CLIENTNET_OLYMPIC) {
				args.push("--olympic");
			} else if (this._nativeClientNetwork == CLIENTNET_TEST) {
				args.push("--testnet");
			} else if (this._nativeClientNetwork == CLIENTNET_DEV) {
				args.push("--dev");
			} else {
				//omit command line option if not specified
			}			
			if (this._nativeClientNetworkID > -1) {
				args.push("--networkid");
				args.push(this._nativeClientNetworkID);
			}
			args.push("console");
			return (args);
		}
		
		/**
		 * Event handler for standard messages from the native client pipe.
		 * 
		 * @param	eventObj A standard ProgressEvent object.
		 */
		private function onNativeClientSTDO(eventObj:ProgressEvent):void {
			var stdOut:* = _nativeClientProc.standardOutput; 
			var data:String = stdOut.readUTFBytes(_nativeClientProc.standardOutput.bytesAvailable); 
			EthereumConsoleView.addText(data, true);
		}
		
		/**
		 * Event handler for error and info messages from the native client pipe.
		 * 
		 * @param	eventObj A standard ProgressEvent object.
		 */
		private function onNativeClientSTDOErr(eventObj:ProgressEvent):void {			
			var stdErr:* = _nativeClientProc.standardError; 
			var data:String = stdErr.readUTFBytes(_nativeClientProc.standardError.bytesAvailable); 
			EthereumConsoleView.addText(data, true);
		}
		
		/**
		 * Event listener invoked when the native application window is closing. This causes the running local Ethereum client to
		 * be terminated, if applicable.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private function onApplicationClosing(eventObj:Event):void {
			if (_nativeClientProc!=null) {
				_nativeClientProc.removeEventListener(ProgressEvent["STANDARD_OUTPUT_DATA"], this.onNativeClientSTDO);
				_nativeClientProc.removeEventListener(ProgressEvent["STANDARD_ERROR_DATA"], this.onNativeClientSTDOErr);
				if (_nativeClientProc.running) {
					_nativeClientProc.standardInput.writeUTF("exit\n"); 
					_nativeClientProc.closeInput();
					_nativeClientProc.exit(true); //let's try with not forcing the exit first
				}
			}
			_nativeClientProc = null;
		}		
		
		/**
		 * Begins the download of a ZIP file containing a native Ethereum client executable.
		 * 
		 * @param	downloadURL The full URL from which to download the Ethereum client executable ZIP file.
		 */
		public function downloadNativeClient(downloadURL:String):void {
			DebugView.addText("EthereumWeb3Client.downloadNativeClient");
			DebugView.addText("   Update URL: " + downloadURL);
			try {
				var fileRef:* = new File();
				fileRef.addEventListener(IOErrorEvent.IO_ERROR, this.onDownloadError); 
				fileRef.addEventListener(IOErrorEvent.NETWORK_ERROR, this.onDownloadError); 
				fileRef.addEventListener(ProgressEvent.PROGRESS, this.onDownloadProgress); 
				fileRef.addEventListener(Event.COMPLETE, this.onDownloadComplete); 
				var request:URLRequest = new URLRequest(); 
				request.url = downloadURL; 
				fileRef.download(request);
				DebugView.addText("   Downloading: 0%");
			} catch (err:*) {
				DebugView.addText (err);
			}
		}
		
		/**
		 * Event listener invoked when a download is encountered while retrieving the native Ethereum client executable ZIP file.
		 * 
		 * @param	eventObj A standard IOErrorEvent object.
		 */
		private function onDownloadError(eventObj:IOErrorEvent):void {
			DebugView.addText("EthereumWeb3Client.onDownloadError - " + eventObj.toString());
			var fileRef:* = eventObj.target;
			fileRef.removeEventListener(IOErrorEvent.IO_ERROR, this.onDownloadError); 
			fileRef.removeEventListener(IOErrorEvent.NETWORK_ERROR, this.onDownloadError); 
			fileRef.removeEventListener(ProgressEvent.PROGRESS, this.onDownloadProgress); 
			fileRef.removeEventListener(Event.COMPLETE, this.onDownloadComplete); 
		}
		
		/**
		 * Event listener invoked during download progress of the native Ethereum client executable ZIP file.
		 * 
		 * @param	eventObj A standard ProgressEvent object.
		 */
		private function onDownloadProgress(eventObj:ProgressEvent):void {
			DebugView.addText("   Downloading: "+Math.floor((eventObj.bytesLoaded/eventObj.bytesTotal)*100)+"%");
		}
		
		/**
		 * Event listener invoked when the download of the native Ethereum client executable ZIP file has completed.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private function onDownloadComplete(eventObj:Event):void {
			DebugView.addText("EthereumWeb3Client.onDownloadComplete");
			var fileRef:* = eventObj.target;
			fileRef.removeEventListener(IOErrorEvent.IO_ERROR, this.onDownloadError); 
			fileRef.removeEventListener(IOErrorEvent.NETWORK_ERROR, this.onDownloadError); 
			fileRef.removeEventListener(ProgressEvent.PROGRESS, this.onDownloadProgress); 
			fileRef.removeEventListener(Event.COMPLETE, this.onDownloadComplete); 
			DebugView.addText("File downloaded to: " + fileRef.nativePath);			
			var sha256:SHA256 = new SHA256();			
			var ZIPlib:FZip = new FZip();
			var filestream:* = new FileStream();
			filestream.open(fileRef, FileMode.READ);
			var zipFileData:ByteArray = new ByteArray();
			filestream.readBytes(zipFileData, 0, 0);
			filestream.close();
			var fileFullPath:String = "";
			ZIPlib.loadBytes(zipFileData);
			for (var count:int = 0; count < nativeClientExecs.length; count++) {				
				for (var count2:int = 0; count2 < ZIPlib.getFileCount(); count2++) {
					var fileName:String = ZIPlib.getFileAt(count2).filename;
					DebugView.addText("   Searching archive: " + ZIPlib.getFileAt(count2).filename);
					var filePathParts:Array = fileName.split("/");
					for (var count3:int = 0; count3 < filePathParts.length; count3++) {
						if (filePathParts[count3] == nativeClientExecs[count]) {
							DebugView.addText("   Found matching executable: " + nativeClientExecs[count]);
							fileFullPath = fileName;
						}
					}
				}
				if (ZIPlib.getFileByName(fileFullPath) != null) {
					var fileContents:ByteArray = ZIPlib.getFileByName(fileFullPath).content;
					if (verifyNativeClientSig) {
						DebugView.addText("Checking SHA256 signature...");
						var hashData:ByteArray = sha256.hash(zipFileData);					
						var hashStr:String = "";
						hashData.position = 0;
						while (hashData.bytesAvailable > 0) {
							var byteToAdd:uint = hashData.readUnsignedByte();
							if (byteToAdd <= 15) {
								hashStr += "0";
							}
							hashStr += byteToAdd.toString(16);						
						}
						DebugView.addText ("  Generated SHA256 signature: " + hashStr);
						if (hashStr == nativeClientUpdates[useNativeClientIndex].sha256sig) {
							DebugView.addText ("   File integrity verified.");
						} else {
							DebugView.addText ("   File integrity verification failed!");
							return;
						}
					}
					DebugView.addText("   Unzipping archive contents to: "+this._nativeClientFolder.nativePath);
					var newFile:* = this._nativeClientFolder.resolvePath(nativeClientExecs[count]);
					DebugView.addText("      "+ZIPlib.getFileByName(fileFullPath).filename+" ["+ZIPlib.getFileByName(fileFullPath).sizeCompressed+" bytes -> "+ZIPlib.getFileByName(fileFullPath).sizeUncompressed+" bytes]");	
					filestream = new FileStream();
					filestream.open(newFile, FileMode.WRITE);
					filestream.writeBytes(fileContents, 0, 0);
					filestream.close();	
					//if download and extraction went well, one of the extracted files will match a known client executable
					this.loadNativeClient();
					return;				
				} else {
					DebugView.addText ("   Couldn't find any matching executables in archive!");
					return;
				}
			}
		}
		
		/**
		 * Handles any uncaught JavaScript error events in the HTMLLoader's JS runtime.
		 * 
		 * @param	eventObj An HTMLUncaughtScriptExceptionEvent object. Typed as anonymous for compatibility.
		 */
		private function onJavaScriptError(eventObj:*):void {
			DebugView.addText("EthereumWeb3Client.onJavaScriptError: "+eventObj.exceptionValue);
		}
		
		/**
		 * Loads the Web3 JavaScript code into either the containing JavaScript environment or into a HTMLLoader instance.
		 */
		private function loadWeb3Object():void {
			DebugView.addText("EthereumWeb3Client.loadWeb3Object");
			if (HTMLLoader!=null) {
				if (HTMLLoader.isSupported) {
					DebugView.addText ("   Using internal JavaScript runtime.");
					_web3Container = new HTMLLoader();
					_web3Container.runtimeApplicationDomain = ApplicationDomain.currentDomain;
					_web3Container.useCache = false;				
					_web3Container.addEventListener(Event.COMPLETE, onWeb3Load);
					_web3Container.addEventListener(HTMLUncaughtScriptExceptionEvent.UNCAUGHT_SCRIPT_EXCEPTION, this.onJavaScriptError);
					var request:URLRequest = new URLRequest("./ethereum/ethereumjslib/web3.js.html");
					_web3Container.load(request);				
				} else {
					DebugView.addText ("   JavaScript runtime is disabled. Can't continue.");
				}
			} else {
				DebugView.addText ("   Using external JavaScript runtime.");
				var web3Obj:Object = null;
				if (ExternalInterface.available) {						
					_web3Container = new EthereumWeb3Proxy();
					ExternalInterface.addCallback("flashTrace", flashTrace);
					onWeb3Load(null);
				}
			}			
		}
	}
}
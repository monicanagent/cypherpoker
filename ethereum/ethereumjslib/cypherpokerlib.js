/**
* 
* CypherPoker + Ethereum integration library. 
* Used to initialize and control the Web3.js library and provide CypherPoker-specific functionality.
*
* (C)opyright 2016 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
var version="2.0"; //CypherPoker Library version
var web3 = null; //main Web3 object
var gameObj = this; //game object on which callbacks are invoked; should be "this" for desktop and "Lounge" for web
var accountLocks = new Object(); //status of accounts (accountLocks[account] == false if account is currently unlocked, otherwise it's locked)

//default debugging trace function
var trace=function (msg) {
	try {
		console.log(msg);
	} catch (err) {
	}
	try {
		if (window.Lounge != undefined) {
			gameObj=window.Lounge;
		}		
		gameObj.flashTrace(msg);
	} catch (err) {
	}
}

//-- Main Functions --

/**
* Connects to an Ethereum client at a specified address and port (defaults: "localhost" and 8545 respectively).
*/
function connect(address, port) {
	if ((address==null) || (address=="") || (address==undefined)) {
		address="localhost";
	}
	if ((port==null) || (port=="") || (port==undefined) || isNaN(Number(port))) {
		port=8545;
	}
	trace ("cypherpokerlib.js -> connect (\""+address+"\", "+port+")");
	web3 = new Web3(new Web3.providers.HttpProvider("http://"+address+":"+port));
	var moduleOptions={};
	moduleOptions.admin=true;
	moduleOptions.personal=true;
	moduleOptions.miner=true;
	moduleOptions.shh=true;
	moduleOptions.eth=true;
	moduleOptions.debug=true;
	createWeb3Extensions(moduleOptions);
	if (web3) {		
		return (true);
	} else {
		return (false);
	}
}

/**
* Gets the balance of an Ethereum account in a specified denomination (defalt is 'ether')
*/
function getBalance(address, denomination) {
	if (!web3) {return (null);}	
	//this may be called often so we probably don't want traces here unless necessary
	if ((address==null) || (address==undefined) || (address=="")) {
		address=web3.eth.accounts[0];
	}
	if ((denomination==null) || (denomination==undefined) || (denomination=="")) {
		denomination="ether";
	}
	var balance=String(web3.fromWei(web3.eth.getBalance(address), denomination));	
	return (balance);
}


/**
* Sends an Ether transaction from an account to another account.
*/
function sendTransaction(fromAdd, toAdd, valAmount, fromPW) {	
	unlockAccount(fromAdd, fromPW);
	return (web3.eth.sendTransaction({from:fromAdd, to:toAdd, value:valAmount}));
}

/**
* Unlocks an account if it's currently locked. Use this function instead of directly unlocking an account to prevent unnecessary delays.
*
* @param account The Ethereum account to unlock.
* @param password The password to use to unlock the account.
* @param duration Optional duration, in seconds, to unlock the account. If this duration has not yet elapsed the account is assumed to be unlocked.
* Default is 1200 (20 minutes);
*
* @return True if the account was unlocked or is currently unlocked, false otherwise.
*/
function unlockAccount(account, password, duration) {	
	if (accountIsLocked(account)) {
		if ((duration == undefined) || (duration==null) || (duration < 1)) {
			duration = 1200;
		}
		web3.eth.defaultAccount=account;		
		accountLocks[account] = false;
		setTimeout(lockAccount, (duration-1)*1000, account); //lock one second early
		trace ("unlocking account: "+account);
		trace ("using password: "+password);
		trace ("duration: "+duration);
		try {
			return (web3.personal.unlockAccount(account, password, duration));
		} catch (err) {
			trace (err);
		}
		return (false);
	}
	return (true);
}

/**
* Returns true if the specified account is locked, false if it's unlocked (duration timer is still active).
*
* @param account The account to check.
*/
function accountIsLocked(account) {	
	if ((accountLocks[account] == undefined) || (accountLocks[account] == null) || (accountLocks[account] == true)) {
		return (true);
	}
	return (false);
}

/**
* Sets the lock status for the specified account to true.
*
* @param account The account for which to set the lock status.
*/
function lockAccount(account) {	
	accountLocks[account] = true;
}

/**
* Deploys a compiled contract.
*
* @param contractsData A JSON string representing single or multi-contract data to be passed back to the callback function.
* @param contractName The name of the contract currently being deployed, to be passed to the callback function.
* @param params JSON representation of an array of parameters to include in the contract's instantiation code. Use an empty array ("[]") for no parameters.
* @param abiStr JSON representation of the contract's interface definition to be converted to a native object.
* @param bytecode Compiled bytecode of the contract.
* @param account The account to use to pay for the deployment of the contract.
* @param password The password for the deployment account.
* @param callback Optional callback function to invoke during various stages of the deployment.
* @param gasValue Optional gas amount to use to deploy the contract. Default is 4000000.
*/
function deployContract(contractsData, contractName, params, abiStr, bytecode, account, password, callback, gasValue) {	
	trace ("cypherpokerlib.js -> deployContract: "+contractName);	
	var abi=JSON.parse(abiStr);
	if ((gasValue==undefined) || (gasValue==null) || (gasValue=="") || (gasValue<1)) {
		gasValue = 4000000;
	}
	unlockAccount(account, password);
	/*
	try {	
		web3.eth.defaultAccount=account; //otherwise we get an "invalid address" error
		web3.personal.unlockAccount(account, password);		
	} catch (err) {
		trace ("cypherpokerlib.js -> "+err);
		return;
	}
	*/
	try {		
		if (params==null) {
			params=[];
		} else {
			params=JSON.parse(params); 
		}		
		if (bytecode.indexOf("0x") < 0) {
			bytecode="0x"+bytecode;
		}
		params.push ({from: account, data: bytecode, gas: gasValue});		
		params.push (function (e, c) {try {callback(contractsData, contractName, e, c);} catch (err) {}});		
		var contractInterface = web3.eth.contract(abi);
		//.new causes JavaScript error in AIR WebKit so use ["new"] instead				
		var contract = contractInterface["new"].apply(contractInterface, params);		
	} catch (err) {
		trace ("cypherpokerlib.js -> "+err);
		return;
	}
}

/**
* Invokes a smart contract function.
*
* @param	resultFormat String specifying the formatting to apply to the returned data. Valid values are null or "" which applies no formatting (raw),
*			"hex" or "toString16" which returns a hexadecimal encoded string of the numeric return value, "int" or "Number" which returns a parsed integer value, 
			and "string" ot "toString" which returns the string representation.
* @param	address The address of the smart contract on the blockchain.
* @param	abiStr A JSON-encoded string representation of the contract interface or ABI.
* @param	functionName The smart contract function to invoke.
* @param	parameters Optional numerically-indexed array of parameters to pass to the function being invoked.
* @param	transactionDetails Additional optional details (such as "gas", "from" and "to" accounts), to include with the function call when invoking 
*			it as a transaction. 
* @param	account Optional account to unlock and use when invoking the function as a transaction.
* @param	password Password for the optional account being used during a transactional function invocation.
* 
*/
function invoke(resultFormat, address, abiStr, functionName, parameters, transactionDetails, account, password) {
	try {
		var abi=JSON.parse(abiStr);
		var contractInterface = web3.eth.contract(abi);
		var contract = contractInterface.at(address);
		if ((account==null) || (account==undefined) || (account=="") || (password==null) || (password==undefined) || (password=="")) {
			//return storage variable			
			var storageData = contract[functionName].apply(contractInterface, parameters);			
			return (JSON.stringify(formatResult(resultFormat, storageData)));
		} else {
			unlockAccount(account, password);
			if ((transactionDetails!=null) && (transactionDetails!=undefined) && (transactionDetails!="")) {
				var txDetailsObj = JSON.parse(transactionDetails);
				if ((parameters == null) || (parameters == undefined)) {
					parameters=[];
				}
				parameters.push(txDetailsObj);				
				var returnData = contract[functionName].apply(contractInterface, parameters);				
			} else {
				var returnData = contract[functionName].apply(contractInterface, parameters);
			}				
			return (JSON.stringify(formatResult(resultFormat, returnData)));
		}
	} catch (err) {
		trace ("cypherpokerlib.js -> "+err);		
	}
	return (null);
}

/**
* Formats the result of a smart function call and returns the formatted data.
*
* @param format The desired format to apply to the function result. Valid formats include null or "" for no (raw) formatting, "hex" or
* 	"toString16" for hexadecimal string encoding, "int" or "Number" for parsed integer output, and "string" or "toString" for
*	the string representation.
* @param result The result data to apply the format to.
*
*/
function formatResult(format, result) {
	if ((format == null) || (format == undefined) || (format == "")) {
		return (result);
	}
	if ((format == "hex") || (format == "toString16")) {
		return ("0x"+result.toString(16));
	}
	if ((format == "int") || (format == "Number")) {
		return (parseInt(result));
	}
	if ((format == "string") || (format == "toString")) {
		return (result.toString());
	}
	if ((format == "boolean") || (format=="bool")) {
		if (result) {
			return (true);
		} else {
			return (false);
		}	
	}
	return (result);
}

/**
* Checks for the existence of a contract on the blockchain and returns true if the described contract exists.
* 
* @param address The address of the contract on the blockchain.
* @param abiStr The JSON string representation of the contract interface (abi).
* @param checkProp A property that should exist in the valid contract.
* @param checkVal The value that the property should have.
* @param checkEqual  If true an equality check is done on the property and value, if false (default) an inequality check is done.
*
*/
function checkContractExists(address, abiStr, checkProp, checkVal, checkEqual) {
	var abi=JSON.parse(abiStr);
	if ((checkEqual != true) && (checkEqual != false)) {
		checkEqual = false;
	}	
	var contractInterface = web3.eth.contract(abi);	
	try {
		var contract = contractInterface.at(address);		
		if ((contract == null) || (contract == undefined) || (contract == "")) {			
			return (false);
		}		
		var propValue=contract[checkProp]();
		if (checkEqual) {
			if (propValue != checkVal) {
				return (false);
			}
		} else {
			if (propValue == checkVal) {
				return (false);
			}		
		}
	} catch (err) {		
		return (false);
	}
	return (true);
}


/**
* Creates support for extended modules: personal, admin, debug, miner, txpool, eth (some extra functions). The "web3" object
* must exist and be initialized prior to calling this function.
*
* Adapted from: https://github.com/The18thWarrior/web3_extended
*
* @param options An object containing boolean flags denoting the modules to enable. For example: options.admin=true;
*/
function createWeb3Extensions(options) {
	//personal
	if (options.personal) {
		//Geth
		web3._extend({
		  property: 'personal',
		  methods: [new web3._extend.Method({
		       name: 'unlockAccount',
		       call: 'personal_unlockAccount',
		       params: 3,
		       inputFormatter: [web3._extend.utils.toAddress, toStringVal, toIntVal],
		       outputFormatter: toBoolVal
		  })]
		});
		//Parity
		/*
		web3._extend({
		  property: 'personal',
		  methods: [new web3._extend.Method({
		       name: 'unlockAccount',
		       call: 'personal_unlockAccount',
		       params: 3,
		       inputFormatter: [web3._extend.utils.toAddress, toStringVal, toStringVal],
		       outputFormatter: toBoolVal
		  })]
		});
		*/
		web3._extend({
		  property: 'personal',
		  methods: [new web3._extend.Method({
		       name: 'newAccount',
		       call: 'personal_newAccount',
		       params: 1,
		       inputFormatter: [toStringVal],
		       outputFormatter: toStringVal
		  })]
		});
		web3._extend({
		  property: 'personal',
		  methods: [new web3._extend.Method({
		       name: 'listAccounts',
		       call: 'personal_listAccounts',
		       params: 0,
		       outputFormatter: toNativeObject
		  })]
		});
		web3._extend({
		  property: 'personal',
		  methods: [new web3._extend.Method({
		       name: 'deleteAccount',
		       call: 'personal_deleteAccount',
		       params: 2,
		       inputFormatter: [web3._extend.utils.toAddress, toStringVal],
		       outputFormatter: toBoolVal
		  })]
		});
		web3._extend({
		  property: 'personal',
		  methods: [new web3._extend.Method({
		       name: 'sign',
		       call: 'personal_sign',
		       params: 3,
		       inputFormatter: [toStringVal, web3._extend.utils.toAddress, toStringVal],
		       outputFormatter: toStringVal
		  })]
		});
		web3._extend({
		  property: 'personal',
		  methods: [new web3._extend.Method({
		       name: 'ecRecover',
		       call: 'personal_ecRecover',
		       params: 2,
		       inputFormatter: [toStringVal, toStringVal],
		       outputFormatter:  web3._extend.utils.toAddress
		  })]
		});
	}
	
	//admin
	if (options.admin) {
		/*
		//deprecated in 1.3.5
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'chainSyncStatus',
		       call: 'admin_chainSyncStatus',
		       params: 0,
		       outputFormatter: toJSONObject
		  })]
		});
		*/
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'nodeInfo',
		       call: 'admin_nodeInfo',
		       params: 0,
		       outputFormatter: toNativeObject
		  })]
		});		
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'addPeer',
		       call: 'admin_addPeer',
		       params: 1,
		       inputFormatter: [toStringVal],
		       outputFormatter: toBoolVal
		  })]
		});		
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'peers',
		       call: 'admin_peers',
		       params: 0,
		       outputFormatter: toNativeObject
		  })]
		});		
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'startRPC',
		       call: 'admin_startRPC',
		       params: 4,
		       inputFormatter: [toStringVal, toIntVal, toStringVal, toStringVal],
		       outputFormatter: toBoolVal
		  })]
		});		
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'stopRPC',
		       call: 'admin_stopRPC',
		       params: 0,
		       outputFormatter: toBoolVal
		  })]
		});		
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'sleepBlocks',
		       call: 'admin_sleepBlocks',
		       params: 1,
		       inputFormatter: [toIntVal]
		  })]
		});		
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'datadir',
		       call: 'admin_datadir',
		       params: 0,
		       outputFormatter: toStringVal
		  })]
		});		
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'setSolc',
		       call: 'admin_setSolc',
		       params: 1,
		       inputFormatter: [toStringVal],
		       outputFormatter: toStringVal
		  })]
		});		
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'startNatSpec',
		       call: 'admin_startNatSpec',
		       params: 0
		  })]
		});		
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'stopNatSpec',
		       call: 'admin_stopNatSpec',
		       params: 0
		  })]
		});
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: '',
		       call: 'admin_',
		       params: 0,
		       inputFormatter: [web3._extend.utils.toAddress, toStringVal, toIntVal],
		       outputFormatter: toStringVal
		  })]
		});
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'getContractInfo',
		       call: 'admin_getContractInfo',
		       params: 1,
		       inputFormatter: [web3._extend.utils.toAddress],
		       outputFormatter: toNativeObject
		  })]
		});
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'saveInfo',
		       call: 'admin_saveInfo',
		       params: 0,
		       inputFormatter: [toJSONObject, toStringVal],
		       outputFormatter: toStringVal
		  })]
		});
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'register',
		       call: 'admin_register',
		       params: 3,
		       inputFormatter: [web3._extend.utils.toAddress, web3._extend.utils.toAddress, toStringVal],
		       outputFormatter: toBoolVal
		  })]
		});
		web3._extend({
		  property: 'admin',
		  methods: [new web3._extend.Method({
		       name: 'registerUrl',
		       call: 'admin_registerUrl',
		       params: 3,
		       inputFormatter: [web3._extend.utils.toAddress, toStringVal, toStringVal],
		       outputFormatter: toBoolVal
		  })]
		});
	}
	
	//debug
	if (options.debug) {
		web3._extend({
		  property: 'debug',
		  methods: [new web3._extend.Method({
		       name: 'setHead',
		       call: 'debug_setHead',
		       params: 1,
		       inputFormatter: [toIntVal],
		       outputFormatter: toBoolVal
		  })]
		});
		web3._extend({
		  property: 'debug',
		  methods: [new web3._extend.Method({
		       name: 'seedHash',
		       call: 'debug_seedHash',
		       params: 1,
		       inputFormatter: [toIntVal],
		       outputFormatter: toStringVal
		  })]
		});
		web3._extend({
		  property: 'debug',
		  methods: [new web3._extend.Method({
		       name: 'processBlock',
		       call: 'debug_processBlock',
		       params: 1,
		       inputFormatter: [toIntVal],
		       outputFormatter: toBoolVal
		  })]
		});
		web3._extend({
		  property: 'debug',
		  methods: [new web3._extend.Method({
		       name: 'getBlockRlp',
		       call: 'debug_getBlockRlp',
		       params: 1,
		       inputFormatter: [toIntVal],
		       outputFormatter: toStringVal
		  })]
		});
		web3._extend({
		  property: 'debug',
		  methods: [new web3._extend.Method({
		       name: 'printBlock',
		       call: 'debug_printBlock',
		       params: 1,
		       inputFormatter: [toIntVal],
		       outputFormatter: toStringVal
		  })]
		});
		web3._extend({
		  property: 'debug',
		  methods: [new web3._extend.Method({
		       name: 'dumpBlock',
		       call: 'debug_dumpBlock',
		       params: 1,
		       inputFormatter: [toIntVal],
		       outputFormatter: toStringVal
		  })]
		});
		web3._extend({
		  property: 'debug',
		  methods: [new web3._extend.Method({
		       name: 'metrics',
		       call: 'debug_metrics',
		       params: 1,
		       inputFormatter: [toBoolVal],
		       outputFormatter: toStringVal
		  })]
		});
		web3._extend({
		  property: 'debug',
		  methods: [new web3._extend.Method({
		       name: 'verbosity',
		       call: 'debug_verbosity',
		       params: 1,
		       inputFormatter: [toIntValRestricted]
		  })]
		});
	}
	
	//miner
	if (options.miner) {		
		web3._extend({
		  property: 'miner',
		  methods: [new web3._extend.Method({
		       name: 'start',
		       call: 'miner_start',
		       params: 1,
		       inputFormatter: [toIntVal],
		       outputFormatter: toBoolVal
		  })]
		});		
		web3._extend({
		  property: 'miner',
		  methods: [new web3._extend.Method({
		       name: 'stop',
		       call: 'miner_stop',
		       params: 1,
		       inputFormatter: [toIntVal],
		       outputFormatter: toBoolVal
		  })]
		});		
		web3._extend({
		  property: 'miner',
		  methods: [new web3._extend.Method({
		       name: 'startAutoDAG',
		       call: 'miner_startAutoDAG',
		       params: 0
		  })]
		});		
		web3._extend({
		  property: 'miner',
		  methods: [new web3._extend.Method({
		       name: 'makeDAG',
		       call: 'miner_makeDAG',
		       params: 2,
			   inputFormatter: [toIntVal, toStringVal],
		       outputFormatter: toBoolVal
		  })]
		});		
		web3._extend({
		  property: 'miner',
		  methods: [new web3._extend.Method({
		       name: 'hashrate',
		       call: 'miner_hashrate',
		       params: 0
		  })]
		});		
		web3._extend({
		  property: 'miner',
		  methods: [new web3._extend.Method({
		       name: 'setExtra',
		       call: 'miner_setExtra',
		       params: 1,
			   inputFormatter: [toStringVal]
		  })]
		});		
		web3._extend({
		  property: 'miner',
		  methods: [new web3._extend.Method({
		       name: 'setGasPrice',
		       call: 'miner_setGasPrice',
		       params: 1,
			   inputFormatter: [toIntVal]
		  })]
		});		
		web3._extend({
		  property: 'miner',
		  methods: [new web3._extend.Method({
		       name: 'setEtherbase',
		       call: 'miner_setEtherbase',
		       params: 1,
			   inputFormatter: [web3._extend.utils.toAddress]
		  })]
		});
	}
	
	//txpool
	if (options.txpool) {		
		web3._extend({
		  property: 'txpool',
		  methods: [new web3._extend.Method({
		       name: 'status',
		       call: 'txpool_status',
		       params: 0,
			   inputFormatter: [],
		       outputFormatter: toNativeObject
		  })]
		});
	}
	
	//eth
	if (options.eth) {		
		web3._extend({
		  property: 'eth',
		  methods: [new web3._extend.Method({
		       name: 'sign',
		       call: 'eth_sign',
		       params: 2,
			   inputFormatter: [web3._extend.utils.toAddress, toStringVal],
		       outputFormatter: toStringVal
		  })]
		});		
		web3._extend({
		  property: 'eth',
		  methods: [new web3._extend.Method({
		       name: 'pendingTransactions',
		       call: 'eth_pendingTransactions',
		       params: 0
		  })]
		});		
		web3._extend({
		  property: 'eth',
		  methods: [new web3._extend.Method({
		       name: 'resend',
		       call: 'eth_resend',
		       params: 3,
			   inputFormatter: [toJSONObject, toIntVal, toIntVal],
		       outputFormatter: toStringVal
		  })]
		});
	}

	//extension utility functions
	
	function toStringVal(val) {
		return String(val);
	}

	function toBoolVal(val) {
		if (String(val) == 'true') {
			return true;
		} else {
			return false;
		}
	}

	function toIntVal(val) {
		return parseInt(val);
	}

	function toIntValRestricted(val) {
		var check = parseInt(val);
		if (check > 0 && check <= 6) {
			return check;
		} else {
			return null;
		}
		
	}

	function toJSONObject(val) {
		try {
			return JSON.parse(val);
		} catch (e){
			return String(val);
		}
	}
	
	function toNativeObject(val) {
		return (val);
	}
}

/**
* Uses the freegeoip.net service to identify public IP address and uses WebRTC, if available, to determine the local IP address.
*
* @param onFindIP Callback function will receive an object containing "localv4Addr" (if it could be determined), and "remoteV4Addr" properties.
*
* Adapted from: http://stackoverflow.com/questions/391979/get-client-ip-using-just-javascript/32841164#32841164
*/
function findIP(onFindIP) {
	var localv4Addr=null;	
	function findRemoteIP(onFindRemoteIP) {
		var xmlhttp = new XMLHttpRequest();
		var url = "//freegeoip.net/json/";
		xmlhttp.onreadystatechange = function() {
			if (xmlhttp.readyState == 4 && xmlhttp.status == 200) {
				var returnObj = JSON.parse(xmlhttp.responseText);
				returnObj.localv4Addr=localv4Addr;
				returnObj.remoteV4Addr=returnObj.ip; //a little redundant but it maintains consistency
				onFindRemoteIP(returnObj);
			}
		};
		xmlhttp.open("GET", url, true);
		xmlhttp.send();
	}
	try {
	  var myPeerConnection = window.RTCPeerConnection || window.mozRTCPeerConnection || window.webkitRTCPeerConnection; //compatibility for firefox and chrome
	  var pc = new myPeerConnection({iceServers: []}),
		noop = function() {},
		localIPs = {},
		ipRegex = /([0-9]{1,3}(\.[0-9]{1,3}){3}|[a-f0-9]{1,4}(:[a-f0-9]{1,4}){7})/g,
		key;

	  function ipIterate(ip) {
		if (!localIPs[ip]) {
			localv4Addr=localIPs[ip];
			findRemoteIP(onFindIP);
		}
		localIPs[ip] = true;
	  }
	  pc.createDataChannel(""); //create a bogus data channel
	  pc.createOffer(function(sdp) {
		sdp.sdp.split('\n').forEach(function(line) {
		  if (line.indexOf('candidate') < 0) return;
		  line.match(ipRegex).forEach(ipIterate);
		}); 
		pc.setLocalDescription(sdp, noop, noop);
	  }, noop); // create offer and set local description
	  pc.onicecandidate = function(ice) { //listen for candidate events
		if (!ice || !ice.candidate || !ice.candidate.candidate || !ice.candidate.candidate.match(ipRegex)) return;
		ice.candidate.candidate.match(ipRegex).forEach(ipIterate);
	  };
	} catch (err) {
		findRemoteIP(onFindIP);
	}
}
trace ("cypherpokerlib.js -> CypherPoker (JavaScript) Library version "+version+" created.");
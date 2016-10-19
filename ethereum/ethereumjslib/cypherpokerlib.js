/**
* 
* CypherPoker + Ethereum integration library. 
* Used to initialize and control the Web3.js library and provide CypherPoker-specific functionality.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
var version="1.1"; //CypherPoker Library version
var web3 = null; //main Web3 object
var gameObj = this; //game object on which callbacks are invoked; should be "this" for desktop and "Lounge" for web

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
	web3.personal.unlockAccount(fromAdd, fromPW);
	return (web3.eth.sendTransaction({from:fromAdd, to:toAdd, value:valAmount}));
}


/**
* Deploys a generic, compiled contract.
*
* @param contractsData A JSON string representing single or multi-contract data to be passed back to the callback function.
* @param contractName The name of the contract currently being deployed, to be passed to the callback function.
* @param params Array of parameters to include in the contract's instantiation code. Use an empty array ([]) for no parameters.
* @param abiStr JSON representation of the contract's interface definition to be converted to a native object.
* @param bytecode Compiled bytecode of the contract.
* @param account The account to use to pay for the deployment of the contract.
* @param password The password for the deployment account.
* @param callback Optional callback function to invoke during various stages of the deployment.
* @param gasValue Optional gas amount to use to deploy the contract. Default is 4700000.
*/
function deployContract(contractsData, contractName, params, abiStr, bytecode, account, password, callback, gasValue) {	
	trace ("cypherpokerlib.js -> deployContract: "+contractName);
	var abi=JSON.parse(abiStr);
	if ((gasValue==undefined) || (gasValue==null) || (gasValue=="") || (gasValue<1)) {
		gasValue = 4700000;
	}	
	try {
		web3.personal.unlockAccount(account, password);		
	} catch (err) {
		trace ("cypherpokerlib.js -> "+err);
		return;
	}
	try {
		if (params==null) {
			params=new Array()
		}
		params.push({from: account, data: bytecode, gas: gasValue}, function (e, c) {try {callback(contractsData, contractName, e, c);} catch (err) {}});
		trace ("fully parameters: "+params);
		var contractInterface = web3.eth.contract(abi);
		//.new causes JavaScript error in AIR WebKit so use ["new"] instead
		var contract = contractInterface["new"].call(params);
	} catch (err) {
		trace ("cypherpokerlib.js -> "+err);
		return;
	}
}

/*
* Stores a community/public card to a specific "PokerHand" contract.
*/
function storePublicCard(contractAddress, card, gasVal) {
	trace ("cypherpokerlib.js -> storePublicCard (\""+contractAddress+"\", "+card+", "+gasVal+")");
	card=parseInt(card, 16);
	trace ("   card="+card);
	if ((contractAddress==null) || (contractAddress=="") || (contractAddress==undefined)) {
		return (null);
	}
	if ((gasVal==undefined) || (gasVal==null) || (gasVal=="")) {
		gasVal = 6000000;
	}	
	var pokerhand = pokerhandContract().at(contractAddress);
	var txhash=pokerhand.storePublicCard(card, {from: web3.eth.accounts[0], gas:gasVal});
	trace ("   TXhash="+txhash);
}
/*
* Stores private cards to a specific "PokerHand" contract.
*/
function storePrivateCards(contractAddress, cards, gasVal) {
	trace ("cypherpokerlib.js -> storePrivateCards (\""+contractAddress+"\", ["+cards+"], "+gasVal+")");
	for (var count=0; count<cards.length; count++) {
		cards[count]=parseInt(cards[count], 16);
		trace ("   parsed card value: "+cards[count]);
	}
	if ((contractAddress==null) || (contractAddress=="") || (contractAddress==undefined)) {
		return (null);
	}
	if ((gasVal==undefined) || (gasVal==null) || (gasVal=="")) {
		gasVal = 6000000;
	}	
	var pokerhand = pokerhandContract().at(contractAddress);
	var txhash=pokerhand.storePrivateCards(cards, {from: web3.eth.accounts[0], gas:gasVal});
	trace ("   TXhash="+txhash);
}
/*
* Stores a buy-in card to a specific "PokerHand" contract (for buy-in/tournament gaming).
*/
function storeBuyIn(contractAddress, etherValue) {
	trace ("cypherpokerlib.js -> storeBuyIn (\""+contractAddress+"\", "+ether+")");
	if ((contractAddress==null) || (contractAddress=="") || (contractAddress==undefined)) {
		return (null);
	}	
	var txhash=web3.eth.sendTransaction({from: web3.eth.accounts[0], to: contractAddress, value:web3.toWei(etherValue, 'ether')});
	trace ("   TXhash="+txhash);
}
/*
* Stores a a single bet to a specific "PokerHand" contract (for "cash" games).
*/
function storeBet(contractAddress, etherValue, gasVal) {
	trace ("cypherpokerlib.js -> storeBet (\""+contractAddress+"\", "+etherValue+", "+gasVal+")");
	if ((contractAddress==null) || (contractAddress=="") || (contractAddress==undefined)) {
		return (null);
	}
	if ((gasVal==undefined) || (gasVal==null) || (gasVal=="")) {
		gasVal = 3000000;
	}
	//var txhash=web3.eth.sendTransaction({from: web3.eth.accounts[0], to: contractAddress, value:web3.toWei(etherValue, 'ether')});
	var pokerhand = pokerhandContract().at(contractAddress);
	var txhash=pokerhand.storeBet({from: web3.eth.accounts[0], gas:gasVal, value:web3.toWei(etherValue, 'ether')});
	trace ("   TXhash="+txhash);
}
/*
* Folds the hand on a specific "PokerHand" contract.
*/
function fold(contractAddress, gasVal) {
	trace ("cypherpokerlib.js -> fold (\""+contractAddress+"\"");
	if ((contractAddress==null) || (contractAddress=="") || (contractAddress==undefined)) {
		return (null);
	}
	if ((gasVal==undefined) || (gasVal==null) || (gasVal=="")) {
		gasVal = 1000000;
	}
	var pokerhand = pokerhandContract().at(contractAddress);	
	var txhash=pokerhand.fold({from: web3.eth.accounts[0], gas:gasVal});
	trace ("   TXhash="+txhash);
}
/*
* Concedes a losing hand to the other player in a specific "PokerHand" contract.
*/
function concede(contractAddress, gasVal) {
	trace ("cypherpokerlib.js -> concede (\""+contractAddress+"\"");
	if ((contractAddress==null) || (contractAddress=="") || (contractAddress==undefined)) {
		return (null);
	}
	if ((gasVal==undefined) || (gasVal==null) || (gasVal=="")) {
		gasVal = 1000000;
	}
	var pokerhand = pokerhandContract().at(contractAddress);	
	var txhash=pokerhand.fold({from: web3.eth.accounts[0], gas:gasVal}); //currently just a fold
	trace ("   TXhash="+txhash);
}
/*
* Stores the crypto keypair for the playr in a specific "PokerHand" contract.
*/
function storeKeys(contractAddress, encKey, decKey, gasVal) {
	trace ("cypherpokerlib.js -> storeKeys (\""+contractAddress+"\", "+encKey+", "+decKey+", "+gasVal+")");	
	encKey=parseInt(encKey, 16);
	decKey=parseInt(decKey, 16);
	trace (" encKey="+encKey);
	trace (" decKey="+decKey);
	trace (" prime=59");
	if ((contractAddress==null) || (contractAddress=="") || (contractAddress==undefined)) {
		return (null);
	}
	if ((gasVal==undefined) || (gasVal==null) || (gasVal=="")) {
		gasVal = 60000000;
	}	
	var pokerhand = pokerhandContract().at(contractAddress);	
	var txhash=pokerhand.storeKeys(encKey, decKey, {from: web3.eth.accounts[0], gas:gasVal});
	trace ("   TXhash="+txhash);
	maxRetries[contractAddress]=0;
	setTimeout(generatePlayerScore, 15000, contractAddress, txhash);
}

var maxRetries=[];
/**
* Generates the player's best hand score when a hand is completed in a specific "PokerHand" contract.
*/
function generatePlayerScore(contractAddress, txhash, gasVal) {
	return;
	trace ("cypherpokerlib.js -> generatePlayerScore (\""+contractAddress+"\", \""+txhash+"\", "+gasVal+")");
	if ((contractAddress==null) || (contractAddress=="") || (contractAddress==undefined)) {
		return (null);
	}
	if (maxRetries[contractAddress]==10) {
		trace ("      Contract re-try limit (10) reached! Giving up.");
		return;
	}
	if ((gasVal==undefined) || (gasVal==null) || (gasVal=="")) {
		gasVal = 600000000;
	}
	var pokerhand = pokerhandContract().at(contractAddress);	
	if (handValuesDecrypted(pokerhand)) {
		trace ("      Contract completed. Now generating score.");
		try {
			trace ("   using gasVal="+gasVal);
			var txhash=pokerhand.generatePlayerScore({from: web3.eth.accounts[0], gas:gasVal});
		} catch (err) {
			trace (err);
		}
		trace ("   TXhash="+txhash);
	} else {
		trace ("      Contract incomplete. Re-trying in 15 seconds.");
		setTimeout(generatePlayerScore, 15000, contractAddress, gasVal);
	}
	maxRetries[contractAddress]++;
}

/**
* Returns true if the hand values (player's private and community cards) for a specific contract have been fully decrypted. This typically indicates
* the end of the associated hand.
*/
function handValuesDecrypted(pokerhand) {
	var cardIndexes=[];
	try {
		cardIndexes.push(playerCardIndex(pokerhand,0));	
		cardIndexes.push(playerCardIndex(pokerhand,1));
		cardIndexes.push(comunityCardIndex(pokerhand,0));
		cardIndexes.push(comunityCardIndex(pokerhand,1));
		cardIndexes.push(comunityCardIndex(pokerhand,2));
		cardIndexes.push(comunityCardIndex(pokerhand,3));
		cardIndexes.push(comunityCardIndex(pokerhand,4));
		cardIndexes.push(comunityCardIndex(pokerhand,5));
	} catch (err) {
		trace (err);
		cardIndexes.push(0);
	}
	for (var count=0; count<cardIndexes.length; count++) {
		var currentCardIndex=cardIndexes[count];
		if ((currentCardIndex==0) || (currentCardIndex=="0") || (currentCardIndex==null) || (currentCardIndex==undefined)) {
			return (false);
		}
	}
	return (true);
}

/**
* Returns the player's decrypted private/hole card at a specific index in a "PokerHand" contract.
*/
function playerCardIndex(contract, storageIndex) {
	return (contract.playerCards(web3.eth.accounts[0],storageIndex)[0]);
}
/**
* Returns the player's decrypted community card at a specific index in a "PokerHand" contract.
*/
function comunityCardIndex(contract, storageIndex) {
	return (contract.communityCards(storageIndex));
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
		web3._extend({
		  property: 'personal',
		  methods: [new web3._extend.Method({
		       name: 'newAccount',
		       call: 'personal_newAccount',
		       params: 2,
		       inputFormatter: [toStringVal, toStringVal],
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
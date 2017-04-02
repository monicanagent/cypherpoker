// loadScript("C:/Users/Patrick/Desktop/Desktop folders/CypherPoker source code/trunk/ethereum/solidity/tests.js")
console.log("Cleaning up environment...");

miner.stop();
debug.verbosity(2);
var successCount=0;
var failCount=0;

console.log("Setting up testing accounts...");
personal.unlockAccount(eth.accounts[0], "test", 900000);
personal.unlockAccount(eth.accounts[1], "test", 900000);
var txObj1=Object();
txObj1.from = eth.accounts[0];
txObj1.gas=3000000;
var txObj2=Object();
txObj2.from = eth.accounts[1];
txObj2.gas=3000000;
console.log("Starting miner...");
miner.start(6);


function waitForTxHash(txhash) {
	while (eth.getBlock(eth.getTransaction(txhash).blockNumber) == null) {
		admin.sleepBlocks(1);
	}
	console.log ("   Block number #"+eth.getBlock(eth.getTransaction(txhash).blockNumber).number+" (tx:"+txhash+") mined.");	
}

function testHasPassed(passed) {
	if (passed) {
		successCount++;
		console.log("   PASSED");
	} else {
		failCount++;
		console.log("   FAIL");
	}
}

/*
console.log("Test #1: Verifying that no accessor is attached");
if (pokerhanddata.attachedPokerHandContracts(0) == "0x") {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #2: Attaching authorized accessor");
waitForTxHash (pokerhanddata.setAuthorizedGameContracts([eth.accounts[0]], txObj1));
if (pokerhanddata.attachedPokerHandContracts(0) == eth.accounts[0]) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}
console.log("Test #3: Clearing authorized accessor");
waitForTxHash (pokerhanddata.setAuthorizedGameContracts([], txObj1));
if ((pokerhanddata.attachedPokerHandContracts(0) == "0x") && (pokerhanddata.attachedPokerHandContracts(1) == "0x")) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #4: Re-attaching authorized accessor");
waitForTxHash (pokerhanddata.setAuthorizedGameContracts([eth.accounts[0]], txObj1));
if (pokerhanddata.attachedPokerHandContracts(0) == eth.accounts[0]) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #5: Verifying that registered players array is empty");
if ((pokerhanddata.players(0) == "0x") && (pokerhanddata.players(1) == "0x")) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #6: Attempt to set new players by non-accessor");
waitForTxHash (pokerhanddata.new_players(["0x1", "0x2"], txObj2));
if ((pokerhanddata.players(0) == "0x") && (pokerhanddata.players(1) == "0x") && (pokerhanddata.num_Players() == 0)) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #7: Attempt to set new players by accessor");
waitForTxHash (pokerhanddata.new_players(["0x1", "0x2"], txObj1));
if ((pokerhanddata.players(0) == 1) && (pokerhanddata.players(1) == 2) && (pokerhanddata.num_Players() == 2)) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #8: Attempt to reset new players by accessor");
waitForTxHash (pokerhanddata.new_players([eth.accounts[0], eth.accounts[1]], txObj1));
if ((pokerhanddata.players(0) == eth.accounts[0]) && (pokerhanddata.players(1) == eth.accounts[1]) && (pokerhanddata.num_Players() == 2)) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #9: Initialize contract");
waitForTxHash (pokerhanddata.initialize(3, 1000, 0xFFFF, 12, txObj1));
if ((pokerhanddata.prime() == 3) && (pokerhanddata.baseCard() == 1000) && (pokerhanddata.buyIn() == 65535) && (pokerhanddata.timeoutBlocks() == 12)) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #10: Attempt to attach new hand contract address as non-accessor after initialize");
waitForTxHash (pokerhanddata.setAuthorizedGameContracts([eth.accounts[1]], txObj2));
if ((pokerhanddata.attachedPokerHandContracts(0) == eth.accounts[0]) && 
	(pokerhanddata.attachedPokerHandContracts(1) != eth.accounts[1])){
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #11: Attempt to attach new hand contract address as accessor after initialize");
waitForTxHash (pokerhanddata.setAuthorizedGameContracts([eth.accounts[1]], txObj1));
if ((pokerhanddata.attachedPokerHandContracts(0) == eth.accounts[0]) && 
	(pokerhanddata.attachedPokerHandContracts(1) != eth.accounts[1])){
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #12: Attempt to set contract data as non-accessor after initialize");
waitForTxHash (pokerhanddata.set_privateCards(eth.accounts[0], [0xFEEDDEADBEEF, 0x255], txObj2));
if ((pokerhanddata.privateCards(eth.accounts[0], 0) == 0) && 
	(pokerhanddata.privateCards(eth.accounts[0], 1) == 0) &&
	(pokerhanddata.num_PrivateCards(0xFEEDDEADBEEF) == 0)) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #13: Attempt to set contract data as accessor after initialize");
waitForTxHash (pokerhanddata.set_privateCards(eth.accounts[0], [0xFEEDDEADBEEF, 0x255], txObj1));
if ((pokerhanddata.privateCards(eth.accounts[0], 0) == 0xFEEDDEADBEEF) && 
	(pokerhanddata.privateCards(eth.accounts[0], 1) == 0x255) &&
	(pokerhanddata.num_PrivateCards(eth.accounts[0]) == 2)) {
	testHasPassed(true);
} else {
	console.log("pokerhanddata.privateCards(eth.accounts[0], 0)="+pokerhanddata.privateCards(eth.accounts[0], 0));
	console.log("pokerhanddata.privateCards(eth.accounts[0], 1)="+pokerhanddata.privateCards(eth.accounts[0], 1));
	testHasPassed(false);
}
*/
//PokerHandValidator : Tx(0x6fccb4c301d3133af84f099bbe892428a6d52c1aa80d000cbdafabdf961394d1) created: 0xb03ca81766b9fc13a8f2c3a64bbff324001cb32f (devnet)
var pokerhandvalidatorContract = web3.eth.contract([{"constant":true,"inputs":[],"name":"pokerHandData","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"},{"name":"msgSender","type":"address"}],"name":"validate","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"lastSender","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"uint256"}],"name":"sortedGroups","outputs":[{"name":"index","type":"uint256"},{"name":"suit","type":"uint256"},{"name":"value","type":"uint256"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"},{"name":"challenger","type":"address"}],"name":"challenge","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"owner","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"workCards","outputs":[{"name":"index","type":"uint256"},{"name":"suit","type":"uint256"},{"name":"value","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"value","type":"uint256"},{"name":"baseCard","type":"uint256"},{"name":"prime","type":"uint256"}],"name":"getCardIndex","outputs":[{"name":"index","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"}],"name":"sortedGroup","outputs":[{"name":"index","type":"uint256"},{"name":"suit","type":"uint256"},{"name":"value","type":"uint256"}],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"","type":"uint256"},{"name":"","type":"uint256"}],"name":"cardGroups","outputs":[{"name":"index","type":"uint256"},{"name":"suit","type":"uint256"},{"name":"value","type":"uint256"}],"payable":false,"type":"function"},{"inputs":[],"payable":false,"type":"constructor"}]);
var pokerhandvalidator = pokerhandvalidatorContract.at("0xb03ca81766b9fc13a8f2c3a64bbff324001cb32f");

//PokerHandStartup : Tx(0xa1cdf70f2fe3cdbc6e3fe9787534f93c84f999ddc39f9a1189387b79b231dc6a) created: 0x884b4e8e6fb450a726f927372825726eb7d127e7 (devnet)
var pokerhandstartupContract = web3.eth.contract([{"constant":true,"inputs":[],"name":"validator","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"},{"name":"cards","type":"uint256[]"}],"name":"storePublicDecryptCards","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"},{"name":"cards","type":"uint256[]"},{"name":"targetAddr","type":"address"}],"name":"storePrivateDecryptCards","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"}],"name":"reset","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"requiredPlayers","type":"address[]"},{"name":"primeVal","type":"uint256"},{"name":"baseCardVal","type":"uint256"},{"name":"buyInVal","type":"uint256"},{"name":"timeoutBlocksVal","type":"uint256"},{"name":"dataAddr","type":"address"}],"name":"initialize","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[],"name":"destroy","outputs":[],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"owner","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"},{"name":"cards","type":"uint256[]"}],"name":"storeEncryptedDeck","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"},{"name":"cards","type":"uint256[]"}],"name":"storePrivateCards","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"},{"name":"cards","type":"uint256[]"}],"name":"storePublicCards","outputs":[],"payable":false,"type":"function"},{"inputs":[],"payable":false,"type":"constructor"},{"payable":false,"type":"fallback"}]);
var pokerhandstartup = pokerhandstartupContract.at("0x884b4e8e6fb450a726f927372825726eb7d127e7");

//PokerHandActions : Tx(0x310b8a416901bf567bfe8cf82941a6e5717ac62f13d331bbd8dc9c5d7f074ff4) created: 0x8fa0b8e335b210e60898fb51421eb5e35529c1ef (devnet)
var pokerhandactionsContract = web3.eth.contract([{"constant":false,"inputs":[{"name":"dataAddr","type":"address"},{"name":"hash","type":"bytes32"},{"name":"v","type":"uint8"},{"name":"r","type":"bytes32"},{"name":"s","type":"bytes32"}],"name":"processSignedTransaction","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"},{"name":"betValue","type":"uint256"}],"name":"storeBet","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[],"name":"destroy","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"input","type":"uint256"}],"name":"uintToBytes32","outputs":[{"name":"result","type":"bytes32"}],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"owner","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"},{"name":"winnerAddr","type":"address"}],"name":"declareWinner","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"input","type":"bytes32"}],"name":"bytes32ToString","outputs":[{"name":"","type":"string"}],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"data","type":"bytes32"},{"name":"v","type":"uint8"},{"name":"r","type":"bytes32"},{"name":"s","type":"bytes32"}],"name":"verifySignature","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"dataAddr","type":"address"},{"name":"reset","type":"bool"}],"name":"allPlayersHaveBet","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"constant":false,"inputs":[],"name":"PokerHandStartup","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"input","type":"string"}],"name":"stringToUint256","outputs":[{"name":"result","type":"uint256"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"}],"name":"fold","outputs":[],"payable":false,"type":"function"},{"payable":false,"type":"fallback"}]);
var pokerhandactions = pokerhandactionsContract.at("0x8fa0b8e335b210e60898fb51421eb5e35529c1ef");

//PokerHandResolutions : Tx(0xa65d1171bd8c4e3f930ed15f8983fb4d88cc5e9d3f038eab587019162d0bddd4) created: 0x53ec8f564e7187eca2c5fbecd341620c53bc7a87
var pokerhandresolutionsContract = web3.eth.contract([{"constant":false,"inputs":[{"name":"dataAddr","type":"address"}],"name":"resolveWinner","outputs":[],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"},{"name":"validatorAddr","type":"address"},{"name":"encKeys","type":"uint256[]"},{"name":"decKeys","type":"uint256[]"},{"name":"challengeValue","type":"uint256"}],"name":"challenge","outputs":[],"payable":true,"type":"function"},{"constant":false,"inputs":[],"name":"destroy","outputs":[],"payable":false,"type":"function"},{"constant":true,"inputs":[],"name":"owner","outputs":[{"name":"","type":"address"}],"payable":false,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"},{"name":"validatorAddr","type":"address"}],"name":"L2Validate","outputs":[],"payable":true,"type":"function"},{"constant":false,"inputs":[{"name":"dataAddr","type":"address"},{"name":"encKeys","type":"uint256[]"},{"name":"decKeys","type":"uint256[]"},{"name":"bestCards","type":"uint256[]"}],"name":"L1Validate","outputs":[],"payable":false,"type":"function"},{"constant":true,"inputs":[{"name":"dataAddr","type":"address"}],"name":"hasTimedOut","outputs":[{"name":"","type":"bool"}],"payable":false,"type":"function"},{"inputs":[],"payable":false,"type":"constructor"},{"payable":false,"type":"fallback"}]);
var pokerhandresolutions = pokerhandresolutionsContract.at("0x53ec8f564e7187eca2c5fbecd341620c53bc7a87")

console.log("Test #1: Adding authorized accessor pokerhandstartup @ "+pokerhandstartup.address);
waitForTxHash (pokerhanddata.setAuthorizedGameContracts([pokerhandstartup.address], txObj1));
if ((pokerhanddata.attachedPokerHandContracts(0) == pokerhandstartup.address) && (pokerhanddata.attachedPokerHandContracts(1) == "0x")) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #2: Attempt initialize contract via accessor");
waitForTxHash (pokerhandstartup.initialize([eth.accounts[0], eth.accounts[1]], 3, 1000, 0xFFFF, 12, pokerhanddata.address, txObj1));
if ((pokerhanddata.prime() == 3) && (pokerhanddata.baseCard() == 1000) && (pokerhanddata.buyIn() == 65535) && (pokerhanddata.timeoutBlocks() == 12)) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #3: Attempt to re-initialize contract via accessor");
waitForTxHash (pokerhandstartup.initialize([eth.accounts[0], eth.accounts[1]], 963, 28910928398, 27, 48, pokerhanddata.address, txObj1));
if ((pokerhanddata.prime() == 3) && (pokerhanddata.baseCard() == 1000) && (pokerhanddata.buyIn() == 65535) && (pokerhanddata.timeoutBlocks() == 12)) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #4: Attempt initialize contract via non-accessor");
waitForTxHash (pokerhanddata.initialize(67, 345678, 876543, 27, pokerhanddata.address, txObj1));
if ((pokerhanddata.prime() == 3) && (pokerhanddata.baseCard() == 1000) && (pokerhanddata.buyIn() == 65535) && (pokerhanddata.timeoutBlocks() == 12)) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #5: Agreeing to contract using account "+eth.accounts[0]);
txObj1.value = "65535";
waitForTxHash (pokerhanddata.agreeToContract(1234567, txObj1));
if ((pokerhanddata.agreed(eth.accounts[0]) == true) && (pokerhanddata.agreed(eth.accounts[1]) == false)) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log("Test #6: Agreeing to contract using account "+eth.accounts[1]);
txObj2.value = "65535";
waitForTxHash (pokerhanddata.agreeToContract(8901234, txObj2));
if ((pokerhanddata.agreed(eth.accounts[0]) == true) && (pokerhanddata.agreed(eth.accounts[1]) == true)) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}
txObj1.value = "0";
txObj2.value = "0";

console.log("Test #7: Verifying contract value");
//65535 * 2
if (eth.getBalance(pokerhanddata.address) == 131070) {
	testHasPassed(true);
} else {
	testHasPassed(false);
}

console.log ("Cleaning up...");
miner.stop();
debug.verbosity(3);
console.log ("Testing done.");
console.log ("---------------------------------------");
console.log (successCount+" out of "+(successCount+failCount)+" tests passed.");
console.log (failCount+" out of "+(successCount+failCount)+" tests failed.");
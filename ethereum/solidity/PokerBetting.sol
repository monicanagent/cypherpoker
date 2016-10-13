/**
* 
* Provides cryptographic services for CypherPoker hand contracts.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
* Morden testnet address: 0xc5c51c3d248cba19813292c5c5089b8413e75a50
*
*/
library PokerBetting {
    
     struct playersType {address[] list;} //players mapped by addresses
     struct betsType {mapping (address => uint256) bet;} //total bets mapped by player addresses.
	 struct chipsType {mapping (address => uint256) chips;} //player chips remaining, mapped by player addresses.
     struct potType {uint256 value;} //current hand pot, in wei
     struct positionType {uint index;} //current betting position
    
     /*
	 * Stores a bet for a player in a referenced contract.
	 */
	 function storeBet(playersType storage self, 
                       betsType storage betsRef, 
					   chipsType storage chipsRef,
                       potType storage potRef, 
                       positionType storage positionRef, 
                       uint256 betVal) 
                        returns (bool updatePhase) {
	  updatePhase=false;
	  if (chipsRef.chips[msg.sender] < betVal) {
		  //not enough chips available
		  return (updatePhase);
	  }
      betsRef.bet[msg.sender]+=betVal;
	  chipsRef.chips[msg.sender]-=betVal;
      potRef.value+=betVal;
      positionRef.index=(positionRef.index + 1) % self.list.length;      
	  updatePhase=true;
      return (updatePhase);
    }
    
    /*
	* Resets all players' bets in a referenced contract to 0.
	*/
	function resetBets(playersType storage self, betsType storage betsRef) {
        for (uint8 count=0; count<self.list.length; count++) {
            betsRef.bet[self.list[count]] = 0;
        } 
    }
    
    /*
	* True if all players in a referenced contract have placed equal bets.
	*/
	function playerBetsEqual(playersType storage self, betsType storage betsRef) returns (bool) {
        //update must take into account 0 bets (check/call)!
        uint256 betVal=betsRef.bet[self.list[0]];
        if (betVal==0) {
            return (false);
        }
        for (uint8 count=1; count<self.list.length; count++) {
            if ((betsRef.bet[self.list[count]] != betVal) || (betsRef.bet[self.list[count]] == 0)) {
                return (false);
            }
        }
        return (true);
    }
}
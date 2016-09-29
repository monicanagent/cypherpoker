/**
* 
* Provides cryptographic services for CypherPoker hand contracts.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
library PokerBetting {
    
     struct playersType {address[] list;} //players mapped by addresses
     struct betsType {mapping (address => uint256) bet;} //bets mapped by player addresses
     struct potType {uint256 value;} //current hand pot
     struct positionType {uint index;} //current betting position
    
     /*
	 * Stores a bet for a player in a referenced contract.
	 */
	 function storeBet(playersType storage playersRef, 
                       betsType storage betsRef, 
                       potType storage potRef, 
                       positionType storage positionRef, 
                       uint256 betVal) 
                        returns (bool updatePhase) {
      betsRef.bet[msg.sender]+=betVal;
      potRef.value+=betVal;
      positionRef.index=(positionRef.index + 1) % playersRef.list.length;
      updatePhase=false;
      if (playerBetsEqual(playersRef, betsRef)) {
          updatePhase=true;
      }
      return (updatePhase);
    }
    
    /*
	* Resets all players' bets in a referenced contract to 0.
	*/
	function resetBets(playersType storage playersRef, betsType storage betsRef) {
        for (uint8 count=0; count<playersRef.list.length; count++) {
            betsRef.bet[playersRef.list[count]] = 0;
        } 
    }
    
    /*
	* True if all players in a referenced contract have placed equal bets.
	*/
	function playerBetsEqual(playersType storage playersRef, betsType storage betsRef) returns (bool) {
        //update must take into account 0 bets (check/call)!
        uint256 betVal=betsRef.bet[playersRef.list[0]];
        if (betVal==0) {
            return (false);
        }
        for (uint8 count=1; count<playersRef.list.length; count++) {
            if ((betsRef.bet[playersRef.list[count]] != betVal) || (betsRef.bet[playersRef.list[count]] == 0)) {
                return (false);
            }
        }
        return (true);
    }
    
}
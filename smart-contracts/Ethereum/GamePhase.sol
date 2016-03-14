/**
* 
* Game phase tracking library for CypherPoker.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
library GamePhase {
    
    /*
	* A player phase structure.
	*/
	struct Phase {
        address player;
        uint8 phaseNum;
    }
	/*
	* Phases mapped to players.
	*/
    struct PhasesMap {
        Phase[] phases;
    }
    
    /*
	* Sets the phase for a specified player (address) in a referenced contract.
	*/
	function setPlayerPhase(PhasesMap storage phasesRef, address player, uint8 phaseNum)  {
        for (uint8 count=0; count<phasesRef.phases.length; count++) {
            if (phasesRef.phases[count].player == player) {
                phasesRef.phases[count].phaseNum = phaseNum;
                return;
            }
        }
    }
    
    /*
	* Retrieves the phase value currently stored for a player in a referenced contract.
	*/
	function getPlayerPhase(PhasesMap storage phasesRef, address player) returns (uint8) {
        for (uint8 count=0; count<phasesRef.phases.length; count++) {
            if (phasesRef.phases[count].player == player) {
                return (phasesRef.phases[count].phaseNum);
            }
        }
    }
   
    /*
	* True if all players are at a specific phase in a referenced contract.
	*/
	function allPlayersAtPhase(PhasesMap storage phasesRef, uint8 phaseNum) returns (bool) {
        if (phasesRef.phases.length == 0) {
            return (false);
        }
        for (uint8 count=0; count<phasesRef.phases.length; count++) {
            if (phasesRef.phases[count].phaseNum != phaseNum) {
                return (false);
            }
        }
        return (true);
    }
   
     /*
	* True if all players are above a specific phase in a referenced contract.
	*/
	function allPlayersAbovePhase(PhasesMap storage phasesRef, uint8 phaseNum) returns (bool) {
        if (phasesRef.phases.length == 0) {
            return (false);
        }
        for (uint8 count=0; count<phasesRef.phases.length; count++) {
            if (phasesRef.phases[count].phaseNum <= phaseNum) {
                return (false);
            }
        }
        return (true);
    }    
}
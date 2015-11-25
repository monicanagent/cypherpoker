/**
* Interface for game parameters storage implementation.
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.interfaces {
	
	public interface IGameParameters 
	{		
		function get funBalances():Number; //for-fun balances applied equally to all players
		function set funBalances(balancesSet:Number):void;		
	}	
}
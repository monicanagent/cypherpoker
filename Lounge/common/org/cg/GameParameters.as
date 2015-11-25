/**
* Contains starting parameters to be passed to new game.
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg 
{	
	import org.cg.interfaces.IGameParameters;
		
	public class GameParameters implements IGameParameters 
	{
		
		private var _funBalances:Number = new Number(0);
		
		public function get funBalances():Number
		{
			return (_funBalances);
		}
		
		public function set funBalances(balancesSet:Number):void
		{
			_funBalances = balancesSet;
		}
		
	}

}
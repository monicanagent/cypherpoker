/**
* Errors thrown by the poker betting module.
*
* (C)opyright 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package  {
	
	public class PokerBettingError extends Error {
		
		public function PokerBettingError(message:*= "", id:*= 0) 
		{
			super(message, id);			
		}		
	}
}
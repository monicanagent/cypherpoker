/**
* 
* Poker Hand Analysis library for CypherPoker.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
* Morden testnet address: 0x1887b0571d8e42632ca6509d31e3edc072408a90
*
*/
library PokerHandAnalyzer {
    
	using CryptoCards for *;
	
    /*
    Hand score:
    
    > 800000000 = straight/royal flush
    > 700000000 = four of a kind
    > 600000000 = full house
    > 500000000 = flush
    > 400000000 = straight
    > 300000000 = three of a kind
    > 200000000 = two pair
    > 100000000 = one pair
    > 0 = high card
    */   
	
	struct CardGroups {
		mapping (uint256 => CryptoCards.Card[15]) groups;
	}


	/*
	* Analyzes and scores a single 5-card permutation.
	*/
    function analyze(CryptoCards.Card[5] storage workCards, CryptoCards.Card[] storage sortedGroup, CryptoCards.Card[][] storage sortedGroups, CryptoCards.Card[][15] storage cardGroups) returns (uint256) {
		uint256 workingHandScore=0;
		bool acesHigh=false;  		
        sortWorkCards(workCards, cardGroups, acesHigh);
        workingHandScore=scoreStraights(sortedGroups, workCards, acesHigh);
        if (workingHandScore==0) {
           //may still be royal flush with ace high           
		   acesHigh=true;
		   sortWorkCards(workCards, cardGroups, acesHigh);
           workingHandScore=scoreStraights(sortedGroups, workCards, acesHigh);
        } else {
           //straight / straight flush 
           clearGroups(sortedGroup, sortedGroups, cardGroups);
           return (workingHandScore);
        }
        if (workingHandScore>0) {
           //royal flush
		   clearGroups(sortedGroup, sortedGroups, cardGroups);
           return (workingHandScore);
        } 
        clearGroups(sortedGroup, sortedGroups, cardGroups);
		acesHigh=false;
        groupWorkCards(true, sortedGroup, sortedGroups, workCards, cardGroups); //group by value
        if (sortedGroups.length > 4) {         
		    clearGroups(sortedGroup, sortedGroups, cardGroups);
			acesHigh=false;
            groupWorkCards(false, sortedGroup, sortedGroups, workCards, cardGroups); //group by suit
            workingHandScore=scoreGroups(false, sortedGroups, workCards, acesHigh);
        } else {
            workingHandScore=scoreGroups(true, sortedGroups, workCards, acesHigh);
        }
        if (workingHandScore==0) {            
			acesHigh=true;    
		    clearGroups(sortedGroup, sortedGroups, cardGroups);
            workingHandScore=addCardValues(0, sortedGroups, workCards, acesHigh);
        }
		clearGroups(sortedGroup, sortedGroups, cardGroups);
		return (workingHandScore);
    }
    
     /*
	* Sort work cards in preparation for group analysis and scoring.
	*/
    function groupWorkCards(bool byValue, CryptoCards.Card[] storage sortedGroup, CryptoCards.Card[][] storage sortedGroups, CryptoCards.Card[5] memory workCards,  CryptoCards.Card[][15] storage cardGroups) internal {
        for (uint count=0; count<5; count++) {
            if (byValue == false) {
                cardGroups[workCards[count].suit].push(CryptoCards.Card(workCards[count].index, workCards[count].suit, workCards[count].value));
            } 
            else {
                cardGroups[workCards[count].value].push(CryptoCards.Card(workCards[count].index, workCards[count].suit, workCards[count].value));
            }
        }
        uint8 maxValue = 15;
        if (byValue == false) {
            maxValue = 4;
        }
        uint pushedCards=0;
        for (count=0; count<maxValue; count++) {
           for (uint8 count2=0; count2<cardGroups[count].length; count2++) {
               sortedGroup.push(CryptoCards.Card(cardGroups[count][count2].index, cardGroups[count][count2].suit, cardGroups[count][count2].value));
               pushedCards++;
           }
           if (sortedGroup.length>0) {
             sortedGroups.push(sortedGroup);
			 sortedGroup.length=0;
           }
        }
    }
    
    
    function clearGroups(CryptoCards.Card[] storage sortedGroup, CryptoCards.Card[][] storage sortedGroups, CryptoCards.Card[][15] storage cardGroups) {
         for (uint count=0; count<sortedGroup.length; count++) {
             delete sortedGroup[count];
        }
        sortedGroup.length=0;
		for (count=0; count<cardGroups.length; count++) {
		    delete cardGroups[count];
        }
        for (count=0; count<sortedGroups.length; count++) {
             delete sortedGroups[count];
        }
        sortedGroups.length=0;
    }
    
    /*
	* Sort work cards in preparation for straight analysis and scoring.
	*/
	function sortWorkCards(CryptoCards.Card[5] memory workCards,  CryptoCards.Card[][15] storage cardGroups, bool acesHigh) internal {
        uint256 workValue;
		CryptoCards.Card[5] memory swapCards;
        for (uint8 value=1; value<15; value++) {
            for (uint8 count=0; count < 5; count++) {
                workValue=workCards[count].value;
                if (acesHigh && (workValue==1)) {
                    workValue=14;
                }
                if (workValue==value) {
                    swapCards[count]=workCards[count];
                }
            }
        }        
        for (count=0; count<swapCards.length; count++) {
			workCards[count]=swapCards[count];            
        }		
    }
        
   /*
	* Returns a straight score based on the current 5-card permutation, if a straigh exists.
	*/
	function scoreStraights(CryptoCards.Card[][] storage sortedGroups, CryptoCards.Card[5] memory workCards, bool acesHigh) internal returns (uint256) {
        uint256 returnScore;
        uint256 workValue;
        for (uint8 count=1; count<5; count++) {
            workValue = workCards[count].value;
            if (acesHigh && (workValue==1)) {
                workValue=14;
            }
            if ((workValue-workCards[count-1].value) != 1) {
                //not a straight, delta between sucessive values must be 1
                return (0);
            }
        }
        uint256 suitMatch=workCards[0].suit;
        returnScore=800000000; //straight flush
        for (count=1; count<5; count++) {
            if (workCards[count].suit != suitMatch) {
                returnScore=400000000; //straight (not all suits match)
                break;
            }
        }
        return(addCardValues(returnScore, sortedGroups, workCards, acesHigh));
    }    
    
    /*
	* Returns a group score based on the current 5-card permutation, if either suit or face value groups exist.
	*/
    function scoreGroups(bool valueGroups, CryptoCards.Card[][] storage sortedGroups, CryptoCards.Card[5] memory workCards, bool acesHigh) internal returns (uint256) {
        if (valueGroups) {
            //cards grouped by value
            if (checkGroupExists(4, sortedGroups)) {
                //four of a kind
                acesHigh=true;
                return (addCardValues(700000000, sortedGroups, workCards, acesHigh));
            } 
            else if (checkGroupExists(3, sortedGroups) && checkGroupExists(2, sortedGroups)) {
                //full house
                acesHigh=true;
                return (addCardValues(600000000, sortedGroups, workCards, acesHigh));
            }  
            else if (checkGroupExists(3, sortedGroups) && checkGroupExists(1, sortedGroups)) {
                //three of a kind
                acesHigh=true;
                return (addCardValues(300000000, sortedGroups, workCards, acesHigh));
            } 
            else if (checkGroupExists(2, sortedGroups)){
                uint8 groupCount=0;
                for (uint8 count=0; count<sortedGroups.length; count++) {
                    if (sortedGroups[count].length == 2) {
                        groupCount++;
                    }
                }
                acesHigh=true;
                if (groupCount > 1)  {
                    //two pair
                   return (addCardValues(200000000, sortedGroups, workCards, acesHigh));
                } else {
                    //one pair
                    return (addCardValues(100000000, sortedGroups, workCards, acesHigh));
                }
            }
        } 
        else {
            //cards grouped by suit
            if (sortedGroups[0].length==5) {
                //flush
                acesHigh=true;
                return (addCardValues(500000000, sortedGroups, workCards, acesHigh));
            }
        }
        return (0);
    }
    
	/*
	* Returns true if a group exists that has a specified number of members (cards) in it.
	*/
    function checkGroupExists(uint8 memberCount,  CryptoCards.Card[][] storage sortedGroups) returns (bool) {
        for (uint8 count=0; count<sortedGroups.length; count++) {
            if (sortedGroups[count].length == memberCount) {
                return (true);
            }
        }
        return (false);
    }
    
    /*
	* Adds individual card values to the hand score after group or straight scoring has been applied.
	*/
	function addCardValues(uint256 startingValue,  CryptoCards.Card[][] storage sortedGroups, CryptoCards.Card[5] memory workCards, bool acesHigh) internal returns (uint256) {
        uint256 groupLength=0;
        uint256 workValue;
        uint256 highestValue = 0;
        uint256 highestGroupValue = 0;
        uint256 longestGroup = 0;
        uint8 count=0;
        if (sortedGroups.length > 1) {
            for (count=0; count<sortedGroups.length; count++) {
                groupLength=getSortedGroupLength32(count, sortedGroups);
                for (uint8 count2=0; count2<sortedGroups[count].length; count2++) {
                    workValue=sortedGroups[count][count2].value;
                    if (acesHigh && (workValue==1)) {
                       workValue=14;
                    }
                    if ((sortedGroups[count].length>1) && (sortedGroups[count].length<5)) {
                        startingValue+=(workValue * (10**(groupLength+2))); //start at 100000
                        if ((longestGroup<groupLength) || ((longestGroup==groupLength) && (workValue > highestGroupValue))) {
                            //add weight to longest group or to work value when group lengths are equal (two pair)
                            highestGroupValue=workValue;
                            longestGroup=groupLength;
                        }
                    } 
                    else {
                        startingValue+=workValue;
                        if (workValue > highestValue) highestValue=workValue;
                    }
                }
            }
            startingValue+=highestValue**3;
            startingValue+=highestGroupValue*1000000;
        } 
        else {
            //bool isFlush=(workCards.length == sortedGroups[0].length);
            for (count=0; count<5; count++) {
                workValue=workCards[count].value;
                if (acesHigh && (workValue==1)) {
                   workValue=14;
                }
                startingValue+=workValue**(count+1); //cards are sorted so count+1 produces weight
                if (workValue > highestValue) {
                    highestValue=workValue;
                }
            }
            startingValue+=highestValue*1000000;
        }
        return (startingValue);
    }
    
    /*
    * Returns the group length of a specific sorted group as a uint32 (since .length property is natively uint256)
    */
    function getSortedGroupLength32(uint8 index,  CryptoCards.Card[][] storage sortedGroups)  returns (uint32) {
        uint32 returnVal;
         for (uint8 count=0; count<sortedGroups[index].length; count++) {
             returnVal++;
         }
         return (returnVal);
    }  
}
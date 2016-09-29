/**
* 
* Poker Hand Analysis library for CypherPoker.
*
* (C)opyright 2016
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/
contract pha {
    
    uint256 public highestHandScore=0; //current highest hand score (may be higher if evaluation hasn't completed)
    uint256 private workingHandScore=0; //current working hand score (changes with each evaluation)
    Card[] public bestHand;
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

    /*
	* A suit+value card structure
	*/
    struct Card {
        uint256 suit; //0-3
        uint256 value; //1-13
    }

    Card[] public cards; //all cards
    Card[] public workCards; //currently being analyzed
    Card[] public swapCards; //used during sorting (there's probably a leaner way to do this)
    mapping (uint256 => Card[]) public cardGroups; //grouped cards (by suit or value)
    Card[] public sortedGroup; //a group of sorted cards
    Card[][] public sortedGroups; //groups of sorted card groups
    bool private acesHigh; //are aces currently being treated as high?
    
    
    /*
	* Constructor.
	*/
	function pha() {
    }
    
    
    /*
	* Analyzes matching suit+value combinations to produce a numeric score based on the best
	* available hand found.
	*/
	function analyze(uint[] suits, uint[] values) external returns (uint256) {
         if ((suits.length != values.length) || (suits.length > 7)) {
           // throw;
        }
        for (uint8 count=0; count<suits.length; count++) {
            cards.push(Card(suits[count], values[count]));
        }
        analyzePerm(0,1,2,3,4);
        highestHandScore = workingHandScore;
        analyzePerm(0,2,3,4,5);
        if (workingHandScore > highestHandScore) {
            highestHandScore = workingHandScore;
        }
        analyzePerm(0,3,4,5,6);
        if (workingHandScore > highestHandScore) {
            highestHandScore = workingHandScore;
        }
        analyzePerm(1,2,3,4,5);
        if (workingHandScore > highestHandScore) {
            highestHandScore = workingHandScore;
        }
        analyzePerm(1,3,4,5,6);
        if (workingHandScore > highestHandScore) {
            highestHandScore = workingHandScore;
        }
        analyzePerm(1,4,5,6,0);
        if (workingHandScore > highestHandScore) {
            highestHandScore = workingHandScore;
        }
        analyzePerm(2,3,4,5,6);
        if (workingHandScore > highestHandScore) {
            highestHandScore = workingHandScore;
        }
        analyzePerm(2,4,5,6,0);
        if (workingHandScore > highestHandScore) {
            highestHandScore = workingHandScore;
        }
        analyzePerm(3,5,6,0,1);
        if (workingHandScore > highestHandScore) {
            highestHandScore = workingHandScore;
        }
        analyzePerm(3,6,0,1,2);
        if (workingHandScore > highestHandScore) {
            highestHandScore = workingHandScore;
        }
        analyzePerm(4,6,0,1,2);
        if (workingHandScore > highestHandScore) {
            highestHandScore = workingHandScore;
        }
        analyzePerm(5,0,1,2,3);
        if (workingHandScore > highestHandScore) {
            highestHandScore = workingHandScore;
        }
        analyzePerm(6,1,2,3,4);
        if (workingHandScore > highestHandScore) {
            highestHandScore = workingHandScore;
        }
        delete cards;
        return (highestHandScore);
    }
    
    
	/*
	* Analyzes and scores a single 5-card permutation.
	*/
    function analyzePerm(uint8 index1, uint8 index2, uint8 index3, uint8 index4, uint8 index5) private {
        workCards.push(cards[index1]);
        workCards.push(cards[index2]);
        workCards.push(cards[index3]);
        workCards.push(cards[index4]);
        workCards.push(cards[index5]);
        workingHandScore=0;
        setAcesLow();
        sortWorkCards();
        workingHandScore=scoreStraights();
        if (workingHandScore==0) {
           //may still be royal flush with ace high
           setAcesHigh();
           sortWorkCards();
           workingHandScore=scoreStraights();
        } else {
           //straight / straight flush
           cleanUp();
           return;
        }
        if (workingHandScore>0) {
           //royal flush
           cleanUp();
           return;
        }
        clearCardGroups();
        setAcesLow();
        groupWorkCards(true); //group by value
        workingHandScore=scoreGroups(true);
        if (sortedGroups.length > 4) {
            clearCardGroups();
            setAcesLow();
            groupWorkCards(false); //group by suit
            workingHandScore=scoreGroups(false);
        }
        if (workingHandScore==0) {
            setAcesHigh();
            clearCardGroups(); //force use of sorted workCards array
            workingHandScore=addCardValues(0);
        }
        cleanUp();
    }
    
    /*
	* Cleans up any active, working cards and card groups.
	*/
	function cleanUp() private {
        clearWorkCards();
        clearCardGroups();
    }
    
    /*
	* Cleans up any active card groups.
	*/ 
	function clearCardGroups() private {
        for (uint8 count=0; count<15; count++) {
            delete cardGroups[count];
        }
        delete sortedGroups;
    }
    
    /*
	* Cleans up any active working cards.
	*/
	function clearWorkCards() private {
        uint256 cardLength=workCards.length;
        for (uint8 count=0; count<cardLength; count++) {
            delete workCards[count];
        }
        delete workCards;
    }
    
    /*
	* Returns a straight score based on the current 5-card permutation, if a straigh exists.
	*/
	function scoreStraights() private returns (uint256) {
        uint256 returnScore;
        uint256 workValue;
        for (uint8 count=1; count<workCards.length; count++) {
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
        for (count=1; count<workCards.length; count++) {
            if (workCards[count].suit != suitMatch) {
                returnScore=400000000; //straight (not all suits match)
                break;
            }
        }
        return(addCardValues(returnScore));
    }    
    
    /*
	* Returns a group score based on the current 5-card permutation, if either suit or face value groups exist.
	*/
    function scoreGroups(bool valueGroups) private returns (uint256) {
        if (valueGroups) {
            //cards grouped by value
            if (checkGroupExists(4)) {
                //four of a kind
                setAcesHigh();
                return (addCardValues(700000000));
            } 
            else if (checkGroupExists(3) && checkGroupExists(2)) {
                //full house
                setAcesHigh();
                return (addCardValues(600000000));
            }  
            else if (checkGroupExists(3) && checkGroupExists(1)) {
                //three of a kind
                setAcesHigh();
                return (addCardValues(300000000));
            } 
            else if (checkGroupExists(2)){
                uint8 groupCount=0;
                for (uint8 count=0; count<sortedGroups.length; count++) {
                    if (sortedGroups[count].length == 2) {
                        groupCount++;
                    }
                }
                setAcesHigh();
                if (groupCount > 1)  {
                    //two pair
                   return (addCardValues(200000000));
                } else {
                    //one pair
                    return (addCardValues(100000000));
                }
            }
        } 
        else {
            //cards grouped by suit
            if (sortedGroups[0].length==5) {
                //flush
                setAcesHigh();
                return (addCardValues(500000000));
            }
        }
        return (0);
    }
    
	/*
	* Returns true if a group exists that has a specified number of members (cards) in it.
	*/
    function checkGroupExists(uint8 memberCount) returns (bool) {
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
	function addCardValues(uint256 startingValue) returns (uint256) {
        uint256 groupLength=0;
        uint256 workValue;
        uint256 highestValue = 0;
        uint256 highestGroupValue = 0;
        uint256 longestGroup = 0;
        uint8 count=0;
        if (sortedGroups.length > 1) {
            for (count=0; count<sortedGroups.length; count++) {
                groupLength=getSortedGroupLength32(count);
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
            for (count=0; count<workCards.length; count++) {
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
    * Returns the group length of a specific sorted group as a uint24 (since .length property is natively uint256)
    */
    function getSortedGroupLength32(uint8 index) returns (uint32) {
        uint32 returnVal;
         for (uint8 count=0; count<sortedGroups[index].length; count++) {
             returnVal++;
         }
         return (returnVal);
    }
    
    /*
	* Sets aces high (scored as 14 and sorted above kings)
	*/
	function setAcesHigh() private {
       acesHigh=true;
    }
    
    /*
	* Sets aces low (scored as 1 and sorted before twos).
	*/
	function setAcesLow() private {
        acesHigh=false;
    }
    
    /*
	* Sort work cards in preparation for straight analysis and scoring.
	*/
	function sortWorkCards() private {
        uint256 workValue;
        for (uint8 value=1; value<15; value++) {
            for (uint8 count=0; count < workCards.length; count++) {
                workValue=workCards[count].value;
                if (acesHigh && (workValue==1)) {
                    workValue=14;
                }
                if (workValue==value) {
                    swapCards.push(workCards[count]);
                }
            }
        }
        delete workCards;
        for (count=0; count<swapCards.length; count++) {
            workCards.push(swapCards[count]);
        }
        delete swapCards;
    }
    
    /*
	* Sort work cards in preparation for group analysis and scoring.
	*/
    function groupWorkCards(bool byValue) private {
        for (uint8 count=0; count<workCards.length; count++) {
            if (byValue == false) {
                cardGroups[workCards[count].suit].push(Card(workCards[count].suit, workCards[count].value));
            } 
            else {
                cardGroups[workCards[count].value].push(Card(workCards[count].suit, workCards[count].value));
            }
        }
        uint8 maxValue = 15;
        if (byValue == false) {
            maxValue = 4;
        }
        for (count=0; count<maxValue; count++) {
           for (uint8 count2=0; count2<cardGroups[count].length; count2++) {
               sortedGroup.push(Card(cardGroups[count][count2].suit, cardGroups[count][count2].value));
           }
           if (sortedGroup.length>0) {
             sortedGroups.push(sortedGroup);
             delete sortedGroup; //clears reference, not contents pushed above
           }
        }
    }
}
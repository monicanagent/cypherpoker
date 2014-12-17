/**
* A generic game timer.
*
* Adapted from the SWAG ActionScript toolkit: https://code.google.com/p/swag-as/
*
* (C)opyright 2014
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
	
	import flash.events.EventDispatcher;
	import org.cg.events.GameTimerEvent;	
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	import org.cg.events.GameTimerEvent;	
		
	public class GameTimer extends EventDispatcher {
	
		/**
		 * @private 
		 */
		private var _hours:uint=new uint();
		/**
		 * @private 
		 */
		private var _minutes:uint=new uint();
		/**
		 * @private 
		 */
		private var _seconds:uint=new uint();
		/**
		 * @private 
		 */
		private var _milliSeconds:uint=new uint();
		/**
		 * @private 
		 */
		private var _totalMilliSeconds:uint = new uint();
		/**
		 * @private 
		 */
		private var _intervalTimer:Timer = null;
		/**
		 * @private 
		 */
		private var _countDownTimer:Timer = null;
		/**
		 * @private 
		 */
		private var _countUpTimer:Timer = null;
		/**
		 * @private 
		 */
		private var _lastTimerMilliseconds:int = new int();
		/**
		 * @private 
		 */
		private var _elapsedMilliseconds:uint = new uint();
		/**
		 * @private 
		 */
		private var _timerInitData:Object = new Object();

		
		public function GameTimer(... args) {
			if (args[0] is String) {
				var localString:String=new String(args[0]);
				var sections:Array = localString.split(":");
				var sectionsAlt:Array=localString.split("."); //decimal milliseconds instead of semi-colon
				if (sections[0] != undefined) {
					this._hours=uint(sections[0]);
				}//if
				if (sections[1] != undefined) {
					this._minutes=uint(sections[1]);
				}//if
				if (sections[2] != undefined) {
					this._seconds=uint(sections[2]);
				}//if
				if (sections[3] != undefined) {
					this._milliSeconds=uint(sections[3]);
				} else if (sectionsAlt[1] != undefined) {
					this._milliSeconds=uint(sectionsAlt[1]);
				}//if
				var totalMS:uint=new uint();
				totalMS=(this._hours*60*60*1000)+(this._minutes*60*1000)+(this._seconds*1000)+(this._milliSeconds);
				this._totalMilliSeconds = Math.floor(totalMS);
				this._elapsedMilliseconds = 0;
			}//if
			super();
		}//constructor
		
		/**
		 * 
		 * Returns a formatted time string based on the time value of the time object and the specified format string supplied as a parameter.
		 * 
		 * @param args Specifies the format of the output time string. All characters in the time string that are not one
		 * of the special format characters listed below will be included, as specified, in the output string.
		 * <p>Valid format characters include:
		 * <ul> 
		 * <li>"h" - Hours with no leading 0 if less than 10.</li>
		 * <li>"H" - Hours with leading 0 if less than 10.</li>
		 * <li>"m" - Minutes with no leading 0 if less than 10.</li>
		 * <li>"M" - Minutes with leading 0 if less than 10.</li>
		 * <li>"s" - Seconds with no leading 0 if less than 10.</li>
		 * <li>"S" - Seconds with leading 0 if less than 10.</li>
		 * <li>"l" - Milliseconds. Leading 0 is not used in this value.</li>
		 * </ul></p>
		 * <p>For example, the string "H:M:S.l" would produce (assuming the instance had the following values): "09:12:01.999"
		 * Default format string is "h:m:s:l".</p>
		 * 
		 * @return The time string representation of this time object, as specified by the format string.
		 * 
		 */
		public function getTimeString(... args):String {
			var format:String=new String();
			var outStr:String=new String();
			if ((args[0] is String) == false) {
				format="h:m:s:l";
			} else {
				format=args[0];
			}//else
			outStr=replaceString(format, String(this._hours), "h");
			outStr=replaceString(outStr, String(this._minutes), "m");
			outStr=replaceString(outStr, String(this._seconds), "s");
			outStr=replaceString(outStr, String(this._milliSeconds), "l");
			var hourString:String=new String();
			var minuteString:String=new String();
			var secondString:String=new String();
			if (this._hours<10) {
				hourString="0";
			}//if
			if (this._minutes<10) {
				minuteString="0";
			}//if
			if (this._seconds<10) {
				secondString="0";
			}//if
			hourString+=this._hours.toString();
			minuteString+=this._minutes.toString();
			secondString+=this._seconds.toString();
			outStr=replaceString(outStr, hourString, "H");
			outStr=replaceString(outStr, minuteString, "M");
			outStr=replaceString(outStr, secondString, "S");
			return (outStr);
		}//getTimeString
		
		public static function replaceString(sourceString:String, insertString:String, patternString:String):String {
			var localSourceString:String=new String(sourceString);
			var replaceSplit:Array=localSourceString.split(patternString);
			var returnString:String=replaceSplit.join(insertString);
			return (returnString);
		}//replaceString
		
		/**
		 * @param args Specifies a notification interval, in milliseconds, at which the time object will broadcast updates. 
		 * It is highly recommended to keep this value greater than 100 milliseconds to prevent bombarding the event system with too many events. 
		 * Setting this value to 0 disables the count down timer tick and causes the countdown to broadcast only when it is complete.
		 */
		public function startCountDown(... args):void {
			this.stopCountDown();
			if (this._totalMilliSeconds == 0) { return };
			var interval:uint = new uint();
			if (args[0] is uint) {
				interval = args[0];
			} else {
				interval = 500;
			}//else
			this._intervalTimer = new Timer(interval, 0);
			this._countDownTimer = new Timer(this._totalMilliSeconds, 1); //Run only once and stop
			this._intervalTimer.addEventListener(TimerEvent.TIMER, this.onCountDownTick);
			this._countDownTimer.addEventListener(TimerEvent.TIMER_COMPLETE, this.onCountDownComplete);
			var event:GameTimerEvent=new GameTimerEvent(GameTimerEvent.COUNTDOWN_START);
			dispatchEvent(event);
			//Store data just prior to starting
			this._elapsedMilliseconds = 0;
			this._timerInitData.totalMilliseconds = this.totalMilliseconds;
			this._lastTimerMilliseconds = getTimer();
			this._countDownTimer.start();
			this._intervalTimer.start();
		}//startCountDown
		
		/**
		 * Starts a countup timer. This is an indefinite timer that will continue to count until it is stopped. 
		 * <p>This does not reset the current time settings of the object since this command may be used to re-start a previous
		 * counter. When starting a new counter, be sure to call <code>resetCountUp</code> first in order to clear the current time
		 * object and reset all values to 0.</p>
		 * <p>Since countup timers don't have a set end, a TIME_COMPLETE event will never be used and so this timer is never assumed
		 * to be complete. Rather, the caller must control the completion state of this instance.</p>
		 * 
		 * 
		 * @param args Specifies a notification interval, in milliseconds, at which the time object will broadcast updates. 
		 * <p>It is highly recommended to keep this value greater than 100 milliseconds to prevent bombarding the
		 * event system with too many events. Setting this value to 0 disables the count down timer tick and causes the countup
		 * to broadcast only when it is complete.</p>
		 * 
		 * @eventType SwagTimeEvent.STARTCOUNTUP
		 * 
		 * @see #stopCountUp()
		 * @see #resetCountUp()
		 */
		public function startCountUp(... args):void {
			var interval:uint = new uint();
			if (args[0] is uint) {
				interval = args[0];
			} else {
				interval = 500;
			}//else
			this._intervalTimer = new Timer(interval, 0);
			this._countUpTimer = new Timer(interval, 0);		
			this._countUpTimer.addEventListener(TimerEvent.TIMER, this.onCountUpTick);
			this._intervalTimer.addEventListener(TimerEvent.TIMER, this.onCountUpTick);
			this._countUpTimer.addEventListener(TimerEvent.TIMER_COMPLETE, this.onCountUpComplete);
			var event:GameTimerEvent=new GameTimerEvent(GameTimerEvent.COUNTUP_START);
			dispatchEvent(event);
			this._lastTimerMilliseconds = getTimer();
			this._countUpTimer.start();			
		}//startCountUp
		
		/**
		 * Stops the count down timer. 
		 * <p>This does not reset the time object so the last elapsed time remains until <code>resetCountDown</code> is invoked.</p>
		 * <p>This method does not affect the count up timer.</p>
		 * 		 
		 * @eventType SwagTimeEvent.STOPCOUNTDOWN
		 *  
		 * @see #startCountDown()
		 * @see #resetCountDown()
		 */
		public function stopCountDown():void {			
			try {
				this._intervalTimer.removeEventListener(TimerEvent.TIMER, this.onCountDownTick);
				this._intervalTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, this.onCountDownComplete);
				this._intervalTimer.stop();
				this._intervalTimer = null;
			} catch (err:*) {			
			}//catch
			try {
				this._countDownTimer.removeEventListener(TimerEvent.TIMER, this.onCountDownTick);
				this._countDownTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, this.onCountDownComplete);
				this._countDownTimer.stop();
				this._countDownTimer = null;
			} catch (err:*) {			
			}//catch
			//var event:GameTimerEvent=new GameTimerEvent(GameTimerEvent.COUNTDOWN_END);
			//dispatchEvent(event);
		}//stopCountDown
		
		/**		 
		 * Stops the count up timer. 
		 * <p>This does not reset the time object so the last elapsed time remains until <code>resetCountUp</code> is invoked.</p>
		 * <p>This method does not affect the count down timer.</p>
		 * 
		 * @eventType SwagTimeEvent.STOPCOUNTUP
		 * 
		 * @see #startCountUp()
		 * @see #resetCountUp()
		 */
		public function stopCountUp():void {
			if (this._countUpTimer is Timer) {
				this._countUpTimer.stop();
			}//if			
			var event:GameTimerEvent=new GameTimerEvent(GameTimerEvent.COUNTUP_END);
			dispatchEvent(event);
		}//stopCountUp
		
		/**
		 * Resets the count down timer. 
		 * <p>This resets the time object value to the state it was at just before the count down timer started. The
		 * count down timer is not affected so that if it's running, it will continue to run. The count up timer is not affected.</p>
		 * 
		 * @eventType SwagTimeEvent.RESETCOUNTDOWN
		 * 
		 * @see #startCountUp()
		 * @see #resetCountUp()
		 */
		public function resetCountDown(... args):void {
			this.totalMilliseconds = this._timerInitData.totalMilliseconds;
			this._elapsedMilliseconds = 0;
			this._lastTimerMilliseconds = getTimer();
			var event:GameTimerEvent=new GameTimerEvent(GameTimerEvent.COUNTDOWN_RESET);
			dispatchEvent(event);	
		}//resetCountDown
		
		/**
		 * Resets the countup timer. 
		 * <p>This resets the time object value to 0, the initial state of the counter. This should be 
		 * called whenever the timer is restarted as this is not done automatically by starting the counter.</p>
		 * 
		 * @eventType SwagTimeEvent.RESETCOUNTUP
		 * 		
		 * @see #startCountUp()
		 * @see #resetCountUp()
		 */
		public function resetCountUp(... args):void {
			this.totalMilliseconds = 0;
			this._elapsedMilliseconds = 0;		
			this._lastTimerMilliseconds = getTimer();
			var event:GameTimerEvent=new GameTimerEvent(GameTimerEvent.COUNTUP_RESET);
			dispatchEvent(event);	
		}//resetCountUp
		
		/**
		 * Invoked on every countdown interval tick.
		 * <p>This method broadcasts regular updates to all listeners with updated elapsed time and the new remaining time 
		 * in the time object.</p>
		 * 
		 * @param eventObj A standard Flash <code>TimerEvent</code> object dispatched by the <code>Timer</code> instance.
		 * @param silent Specifies whether the <code>SwagTimeEvent.ONCOUNTDOWN</code> event should be broadcast with
		 * each timer tick (<em>true</em>), or not (<em>false</em>). Setting this property to <em>false</em> reduces
		 * some of the overhead associated with the count down loop if this event is not used.
		 * 
		 * @eventType SwagTimeEvent.ONCOUNTDOWN
		 * 
		 * @see #stopCountDown()
		 * @see #resetCountDown()
		 */		
		public function onCountDownTick (eventObj:TimerEvent, silent:Boolean=false):void {
			var sysElapsedMilliseconds:int = getTimer();
			//Handle the unlikely event that the application has been running for 49 days straight
			if (sysElapsedMilliseconds < this._lastTimerMilliseconds) {
				//Rolled over the maximum integer value so add end value plus new value counted from 0
				var rollingDelta:int = int.MAX_VALUE - this._lastTimerMilliseconds;
				var milliSecondDelta:int = sysElapsedMilliseconds+rollingDelta;
			} else {
				//Regular calculation
				milliSecondDelta = getTimer() - this._lastTimerMilliseconds;
			}//else
			if ((this.totalMilliseconds-milliSecondDelta)<0) {
				this.totalMilliseconds = 0;
				this.onCountDownComplete(eventObj);
				return;
			} else {
				this.totalMilliseconds -= milliSecondDelta;
			}//else
			this._elapsedMilliseconds += milliSecondDelta;
			if (!silent) {
				var event:GameTimerEvent=new GameTimerEvent(GameTimerEvent.COUNTDOWN_TICK);
				dispatchEvent(event);
			}//if
			this._lastTimerMilliseconds = getTimer();
		}//onCountDownTick
		
		/**
		 * Invoked on every countup interval tick. 
		 * <p>This method broadcasts regular updates to all listeners with updated elapsed time.</p>
		 * 
		 * @param eventObj A standard Flash <code>TimerEvent</code> object dispatched by the <code>Timer</code> instance.
		 * @param silent Specifies whether the <code>SwagTimeEvent.ONCOUNTUP</code> event should be broadcast with
		 * each timer tick (<em>true</em>), or not (<em>false</em>). Setting this property to <em>false</em> reduces
		 * some of the overhead associated with the count up loop if this event is not used.
		 * 
		 * @eventType SwagTimeEvent.ONCOUNTUP
		 * 
		 * @see #stopCountUp()
		 * @see #resetCountUp()
		 */
		public function onCountUpTick (eventObj:TimerEvent, silent:Boolean=false):void {
			var milliSecondDelta:uint = getTimer() - this._lastTimerMilliseconds;		
			this._elapsedMilliseconds += milliSecondDelta;			
			this.totalMilliseconds = this._elapsedMilliseconds;
			if (!silent) {
				var event:GameTimerEvent=new GameTimerEvent(GameTimerEvent.COUNTUP_TICK);
				dispatchEvent(event);
			}//if
			this._lastTimerMilliseconds = getTimer();
		}//onCountUpTick
		
		/**
		 * Invoked when the count down timer completes. 
		 * <p>This may either happen as the result of the countdown <code>Timer</code> instance elapsing, or the 
		 * calculated internal timer elapsing to 0.</p>
		 * 
		 * @param eventObj A standard Flash <code>TimerEvent</code> object (usually a reference to the instance
		 * used internally by <code>SwagTime</code>.
		 * 
		 * @eventType SwagTimeEvent.STOPCOUNTDOWN
		 * @eventType SwagTimeEvent.ENDCOUNTDOWN
		 * 
		 * @see #startCountDown()
		 * @see #stopCountDown()
		 * @see #resetCountDown()
		 * 
		 */
		public function onCountDownComplete(eventObj:TimerEvent):void {
			try {
				this._intervalTimer.removeEventListener(TimerEvent.TIMER, this.onCountDownTick);
				this._intervalTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, this.onCountDownComplete);
				this._intervalTimer.stop();
				this._intervalTimer = null;
			} catch (err:*) {			
			}//catch
			try {
				this._countDownTimer.removeEventListener(TimerEvent.TIMER, this.onCountDownTick);
				this._countDownTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, this.onCountDownComplete);
				this._countDownTimer.stop();
				this._countDownTimer = null;
			} catch (err:*) {
			}//catch			
			var event:GameTimerEvent = new GameTimerEvent(GameTimerEvent.COUNTDOWN_END);			
			dispatchEvent(event);
		}//onCountDownComplete
		
		/**
		 * Invoked when the countdown timer completes. 
		 * <p>This may either happen as the result of the countdown <code>Timer</code> instance elapsing, or the 
		 * calculated internal timer elapsing to / past 0.</p>
		 * 
		 * @param eventObj A standard Flash <code>TimerEvent</code> object (usually a reference to the instance
		 * used internally by <code>SwagTime</code>.
		 * 
		 * @eventType SwagTimeEvent.STOPCOUNTUP
		 * @eventType SwagTimeEvent.ENDCOUNTDOWN
		 * 
		 * @see #startCountUp()
		 * @see #stopCountUp()
		 * @see #resetCountUp()
		 * 
		 */
		public function onCountUpComplete(eventObj:TimerEvent):void {
			if (this._intervalTimer!=null) {
				this._intervalTimer.stop();
			}//if
			if (this._countUpTimer!=null) {
				this._countUpTimer.stop();
			}//if
			var event:GameTimerEvent=new GameTimerEvent(GameTimerEvent.COUNTUP_END);
			dispatchEvent(event);			
		}//onCountUpComplete		
		
		/**
		 * 
		 * Calculates the total milliseconds from the appropriate class member variables. All private member variables are updated
		 * so that all getters and other output methods will have correctly calculated time values.
		 * 
		 * @private
		 */
		private function calculateTotalMilliseconds():void {
			var totalMS:uint=new uint();
			totalMS=(this._hours*60*60*1000)+(this._minutes*60*1000)+(this._seconds*1000)+(this._milliSeconds);
			this._totalMilliSeconds=Math.floor(totalMS);
			this._hours=Math.floor(totalMS/1000/60/60);
			this._minutes=Math.floor((totalMS/1000/60)%60);
			this._seconds=Math.floor((totalMS/1000)%60);
			this._milliSeconds=Math.floor(totalMS%1000);
		}//calculateTotalMilliseconds				
		
		/**
		 * Sets the number of milliseconds in the <code>SwagTime</code> object. 
		 * <p>This value only affects milliseconds absolutely, and no other values are affected. In other words, updating milliseconds 
		 * does not affect seconds, minutes, or hours. Milliseconds are converted to proper values using modulo math so that 1001
		 * milliseconds becomes 1 second. This is useful for setting individual components of the time object without affecting the 
		 * overall time value.</p>
		 */
		public function set milliseconds (msVal:uint):void {
			this._milliSeconds=Math.floor(msVal % 1000);
			this.calculateTotalMilliseconds();
		}//set milliseconds
		
		/**
		 * Sets the number of seconds in the <code>SwagTime</code> object. 
		 * <p>This value only affects seconds absolutely, no other values are affected. In other words, updating seconds does not affect 
		 * milliseconds, minutes, or hours. Seconds are converted to proper values so that 61 seconds becomes 1 second. This is useful 
		 * for setting individual components of the time object without affecting the overall time value.</p>		 
		 */
		public function set seconds(secondVal:uint):void {
			this._seconds=Math.floor(secondVal % 60);
			this.calculateTotalMilliseconds();
		}//set seconds
		
		/**		 
		 * Sets the number of minutes in the <code>SwagTime</code> object.
		 * <p>This value only affects minutes absolutely, no other values are affected.
		 * In other words, updating minutes does not affect milliseconds, seconds, or hours. Minutes are converted to proper values so that
		 * 61 minutes becomes 1 minute. This is useful for setting individual components of the time object without affecting the overall
		 * time value.</p>		 
		 */
		public function set minutes (minuteVal:uint):void {
			this._minutes=Math.floor(minuteVal % 60);
			this.calculateTotalMilliseconds();
		}//set minutes
		
		/**
		 * Sets the number of hours in the time object. 
		 * <p>Any number of hours may be set for the class, but fractional values will only have their whole part used. 
		 * That is, minute, second, and millisecond calculations aren't applied.</p>		 
		 */
		public function set hours(hourVal:uint):void {
			this._hours=Math.floor(hourVal);
			this.calculateTotalMilliseconds();
		}//set hours
		
		/**
		 * The milliseconds component of the <code>SwagTime</code> object. 
		 * <p>This is not the total, aggregated milliseconds but rather the portion of the time object representing the left-over 
		 * milliseconds from total time calculations.</p>		 
		 */
		public function get milliseconds ():uint {
			return (this._milliSeconds);
		}//get milliseconds
		
		/**
		 * The seconds component of the <code>SwagTime</code> object. 
		 * <p>This is not the total, aggregated seconds but rather the portion of the time object representing the left-over seconds 
		 * from total time calculations.</p>		 
		 */
		public function get seconds ():uint {
			return (this._seconds);
		}//get seconds
		
		/**		 
		 * The minutes component of the <code>SwagTime</code> object. 
		 * <p>This is not the total, aggregated minutes but rather the portion of the time object representing the left-over minutes
		 * from total time calculations.</p>		 
		 */
		public function get minutes ():uint {
			return (this._minutes);
		}//get minutes
		
		/**
		 * The hours component of the <code>SwagTime</code> object.
		 * <p>This is not the total, aggregated hours but rather the portion of the time object representing the left-over hours from 
		 * total time calculations.</p>		 
		 */
		public function get hours ():uint {
			return (this._hours);
		}//get hours
		
		/**		 
		 * Sets the total hours value for the whole <code>SwagTime</code> object. 
		 * <p>This is translated to the total number of hours, minutes, seconds, and milliseconds (especially when fractional 
		 * values are used). Because this value is manipulated before being stored, non whole values (fractional values) will result 
		 * in different values on the getter. For example, setting 36 hours will return simply 36 hours and 0 minutes. However, setting
		 * 36.5 hours will result in 36 hours and 30 minutes. Because all values area affected, setting any "total" value
		 * will effectively overwrite any other set values.</p>		 
		 */
		public function set totalHours(thVal:Number):void {
			var msecVal:Number=thVal*60*60*1000;
			this._totalMilliSeconds=Math.floor(msecVal);
			this._hours=Math.floor(msecVal/1000/60/60);
			this._minutes=Math.floor((msecVal/1000/60)%60);
			this._seconds=Math.floor((msecVal/1000)%60);
			this._milliSeconds=Math.floor(msecVal%1000);			
		}//set totalHours
		
		/**
		 * Sets the total minutes value for the whole <code>SwagTime</code> object. 
		 * <p>This is translated to the total number of hours, minutes, seconds, and milliseconds (especially when fractional values 
		 * are used or minutes exceeds 59). For example, setting 59 minutes will return simply 59 minutes and 0 hours. However, setting 
		 * 60 minutes will cause 1 hour and 0 minutes to be returned. Because all values area affected, setting any "total" value will 
		 * effectively overwrite any other set values.</p>		 
		 */
		public function set totalMinutes(tmVal:Number):void {												
			var msecVal:Number=tmVal*60*1000;	
			this._totalMilliSeconds=Math.floor(msecVal);
			this._hours=Math.floor(msecVal/1000/60/60);
			this._minutes=Math.floor((msecVal/1000/60)%60);
			this._seconds=Math.floor((msecVal/1000)%60);
			this._milliSeconds=Math.floor(msecVal%1000);									
		}//set totalMinutes
		
		/**		 
		 * Sets the total seconds value for the whole <code>SwagTime</code> object. 
		 * <p>This is translated to the total number of hours, minutes, seconds, and milliseconds (especially when fractional values are 
		 * used or seconds exceeds 59). For example, setting 59 seconds will return simply 59 seconds and 0 minutes. However, setting 60 
		 * seconds will cause 1 minute and 0 seconds to be returned. Because all values area affected, setting any "total" value will 
		 * effectively overwrite any other set values.</p>		 
		 */
		public function set totalSeconds(tsVal:Number):void {												
			var msecVal:Number=tsVal*1000;	
			this._totalMilliSeconds=Math.floor(msecVal);
			this._hours=Math.floor(msecVal/1000/60/60);
			this._minutes=Math.floor((msecVal/1000/60)%60);
			this._seconds=Math.floor((msecVal/1000)%60);
			this._milliSeconds=Math.floor(msecVal%1000);			
		}//set totalSeconds
		
		/**		
		 * Sets the total milliseconds value for the whole <code>SwagTime</code> object. 
		 * <p>This is translated to the total number of hours, minutes, seconds, and milliseconds (especially when fractional values are used 
		 * or milliseconds exceeds 999). For example, setting 999 milliseconds will return simply 999 milliseconds and 0 seconds. However, 
		 * setting 1000 milliseconds will cause 1 second and 0 milliseconds to be returned on the other class getters. Because all values area 
		 * affected, setting any "total" value will effectively overwrite any other set values.</p>		 
		 */
		public function set totalMilliseconds(tmsVal:uint):void {												
			var msecVal:Number=tmsVal;	
			this._totalMilliSeconds=Math.floor(msecVal);
			this._hours=Math.floor(msecVal/1000/60/60);
			this._minutes=Math.floor((msecVal/1000/60)%60);
			this._seconds=Math.floor((msecVal/1000)%60);
			this._milliSeconds=Math.floor(msecVal%1000);
		}//set totalMilliseconds
		
		/**
		 * Stores the total milliseconds value for the internal timer (the "totalMilliseconds" value is used for counting down). 
		 * <p>Typically this is not a value that should be touched directly, but some applications of TimeObject (e.g. Thread object)
		 * require a manual invokation of timer tick methods which, in turn, depend on this value.</p>		 
		 */
		public function set timerTotalMilliseconds(ttmsVal:uint):void {
			if (this._timerInitData==null) {
				this._timerInitData=new Object();
			}//if
			this._timerInitData.totalMilliseconds = new uint(ttmsVal);
		}//set timerTotalMilliseconds
		
		/**
		 * Returns the stored milliseconds value used when <code>SwagTime</code> is used as a counter. 
		 * <p>Once the internal counter is complete, this value will be assigned to "totalMilliseconds" when reset methods are invoked.</p>		 
		 */
		public function get timerTotalMilliseconds():uint {
			if (this._timerInitData==null) {
				this._timerInitData=new Object();
			}//if
			if (this._timerInitData.totalMilliseconds==undefined) {
				this._timerInitData.totalMilliseconds=new uint();
			}//if
			return (this._timerInitData.totalMilliseconds);
		}//get timerTotalMilliseconds
		
		/**
		 * Sets the hours, minutes, and seconds value for the <code>SwagTime</code> object from a 16-bit packed MS-DOS time format stored 
		 * in an unsigned integer (uint). 
		 * <p>Any values above the 16th bit will be ignored. This value is assumed to be stored in MSB (Most Significant Bit first) format.</p> 
		 * 
		 * @see swag.core.instances.SwagDate#MSDOSDate		
		 */
		public function set MSDOSTime(MSDOSTimeValue:uint):void {												
			var timeVal:uint=MSDOSTimeValue & 0xFFFF;
			this._seconds=(timeVal & 0x1F) as Number;
			this._minutes=((timeVal & 0x7E0 ) >> 5) as Number;			
			this._hours=((timeVal & 0xF800 ) >> 11) as Number;			
			this._milliSeconds=Math.floor((this._seconds*1000)%1000);			
			this._totalMilliSeconds=(this._hours*3600000)+(this._minutes*60000)+(this._seconds*1000);
		}//set MSDOSTime
		
		/**
		 * The total calculated hours for the <code>SwagTime</code> object. 
		 * <p>This is an aggregate value of hours, minutes, seconds, and milliseconds.</p>		 
		 */
		public function get totalHours():Number {			
			var totalHours:Number=new Number();
			totalHours=(this._hours)+(this._minutes/60)+(this._seconds/60/60)+(this._milliSeconds/60/60/1000);
			return (totalHours);
		}//get totalHours
		
		/**
		 * The total calculated minutes for the <code>SwagTime</code> object. 
		 * <p>This is an aggregate value of hours, minutes, seconds, and milliseconds.</p>		 
		 */
		public function get totalMinutes():Number {			
			var totalMin:Number=new Number();
			totalMin=(this._hours*60)+(this._minutes)+(this._seconds/60)+(this._milliSeconds/60/1000);
			return (totalMin);
		}//get totalMinutes
		
		/**
		 * The total calculated seconds for the <code>SwagTime</code> object. 
		 * <p>This is an aggregate value of hours, minutes, seconds, and milliseconds.</p>		 
		 */
		public function get totalSeconds():Number {			
			var totalSec:Number=new Number();
			totalSec=(this._hours*60*60)+(this._minutes*60)+(this._seconds)+(this._milliSeconds/1000);
			return (totalSec);
		}//get totalSeconds
		
		/**		
		 * Returns the total calculated milliseconds for the <code>SwagTime</code> object. 
		 * <p>This is an aggregate value of hours, minutes, seconds, and milliseconds.</p>		 
		 */
		public function get totalMilliseconds():uint {			
			var totalMS:uint=new uint();
			totalMS=(this._hours*60*60*1000)+(this._minutes*60*1000)+(this._seconds*1000)+this._milliSeconds;
			return (totalMS);
		}//get totalMilliseconds
		
		/**		
		 * The total number of elapsed hours for the current count down timer. 
		 * <p>This value is valid while the count down timer is running, or when it has stopped but before the 
		 * <code>resetCountDown</code> method is invoked.</p>		 
		 */
		public function get elapsedHours():uint {
			var hourVal:uint = new uint();
			hourVal = Math.floor(this._elapsedMilliseconds/1000/60 / 60);
			return (hourVal);
		}//get elapsedHours
		
		/**
		 * The total number of elapsed minutes for the current count down timer. 
		 * <p>This value is valid while the count down timer is running, or when it has stopped but before the 
		 * <code>resetCountDown</code> method is invoked.</p>		 
		 */
		public function get elapsedMinutes():uint {
			var minuteVal:uint = new uint();
			minuteVal = Math.floor(this._elapsedMilliseconds/1000/60);
			return (minuteVal);
		}//get elapsedMinutes
		
		/**
		 * The total number of elapsed seconds for the current count down timer. 
		 * <p>This value is valid while the count down timer is running, or when it has stopped but before the 
		 * <code>resetCountDown</code> method is invoked.</p>		 
		 */
		public function get elapsedSeconds():uint {
			var secondVal:uint = new uint();
			secondVal = Math.floor(this._elapsedMilliseconds / 1000);
			return (secondVal);
		}//get elapsedSeconds
		
		/**		
		 * The total number of elapsed milliseconds for the current count down timer. 
		 * <p>This value is valid while the count down timer is running, or when it has stopped but before the 
		 * <code>resetCountDown</code> method is invoked.</p>		 
		 */
		public function get elapsedMilliseconds():uint {
			return (this._elapsedMilliseconds);
		}//get elapsedMilliseconds
		
		/**
		 * The string representation of the <code>SwagTime</code> object, in the format "H:M:S.l".
		 * Refer to the <code>getTimeString</code> method for the format of this ouput.
		 *  
		 * @return The string representation of the <code>SwagTime</code> object, in the format "H:M:S.l".
		 * 
		 */
		override public function toString():String {
			var returnString:String=this.getTimeString("H:M:S.l");
			return (returnString);
		}//toString

	}
	
}//package
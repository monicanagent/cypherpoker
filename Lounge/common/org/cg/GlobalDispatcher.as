/**
* A global non-source-bound event dispatcher.
* 
* Adapted from the SWAG ActionScript toolkit: https://code.google.com/p/swag-as/
* 
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/ 

package org.cg {
		
	import org.cg.GlobalListener;	
	import org.cg.interfaces.IGlobalEvent;		

	public class GlobalDispatcher {		
		
		private static var _listeners:Vector.<GlobalListener>;				
		
		/**
		 * Adds an event listener to the dispatcher.		 
		 * 
		 * @param eventType The event type to listen to.
		 * @param eventMethod The method to invoke when the eventType is dispatched.
		 * @param thisRef A reference to the object (class, instance, etc.), containing the method to be invoked. Used for context.
		 * @param sourceObject The object(s) from which the event is being dispatched.
		 * 		 
		 * 
		 */
		public static function addEventListener(eventType:String, eventMethod:Function, thisRef:*=null, sourceObject:*=null):GlobalListener {
			if ((eventType==null) || (eventMethod==null)) {
				return (null);
			}//if			
			if (eventType=="") {
				return (null);
			}//if			
			var newEventListener:GlobalListener=new GlobalListener(eventType, eventMethod, thisRef, sourceObject);
			listeners.push(newEventListener);
			return (newEventListener);
		}//addEventListener
		
		/**
		 * Removes an event listener.
		 *  
		 * @param eventType The event type to remove.
		 * @param sourceObject The optional source object associated with the event to remove. If null,
		 * it is ignored. If this is an object reference, it must match the object used to register the event with 
		 * the addEventListener function. 
		 * 
		 * @return True if the listener was successfully removed, or false.
		 * 		 
		 */
		public static function removeEventListener(eventType:String, eventMethod:Function, sourceObject:*=null):Boolean {
			if ((eventType==null) || (eventMethod==null)) {
				return (false);
			}//if
			if (eventType=="") {
				return (false);
			}//if
			var listenerCount:uint=listeners.length;
			//Prefetch the listener count in case new ones are added or removed while removing
			for (var count:uint=0; count<listenerCount; count++) {
				var currentListener:GlobalListener=listeners[count] as GlobalListener;
				if ((currentListener.type==eventType) && (currentListener.method==eventMethod) && (sourcesMatch(sourceObject, currentListener.source))) {
					listeners.splice(count,1);
					return (true);
				}//if
			}//for
			return (false);
		}//removeEventListener
		
		/**
		 * Dispatches a globally-listenable event.
		 * 
		 * @param eventObj A <code>IGlobalEvent</code> implementation.
		 * @param source The source object from which the event is being dispatched (for listeners that filter events by source).
		 * 
		 */
		public static function dispatchEvent(eventObj:IGlobalEvent, source:*):Boolean {	
			if (eventObj==null) {				
				return (false);
			}//if
			if (source==null) {				
				return (false);
			}//if
			var listenerCount:uint=listeners.length;
			var dispatchSent:Boolean=false;				
			for (var count:uint=0; count<listenerCount; count++) {				
				if (listeners.length<=count) {
					return (dispatchSent);
				}//if					
				var currentListener:GlobalListener=listeners[count] as GlobalListener;				
				if ((eventObj.type==currentListener.type) && sourcesMatch(source, currentListener.source)) {						
					if (currentListener.invoke(eventObj, source)==false) {
						removeEventListener(currentListener.type, currentListener.method);
					} else {
						dispatchSent=true;
					}//else
				}//if
			}//for		
			return (dispatchSent);
		}//dispatchEvent		
		
		/**
		 * Removes orphaned event listeners.
		 * 
		 */
		public static function cleanUpListeners():void {
			var listenerCount:uint=listeners.length;
			for (var count:uint=0; count<listenerCount; count++) {
				var currentListener:GlobalListener=listeners[count] as GlobalListener;
				if ((currentListener.type==null)|| (currentListener.method==null)) {
					listeners.splice(count,1);					
				}//if
			}//for
		}//cleanUpListeners
		
		/**
		 * Stores a packed vector array of all registered GlobalListener instances.
		 *  
		 * @return A vector array of GlobalListener instances.
		 * 		 
		 */
		public static function get listeners():Vector.<GlobalListener> {
			if (_listeners==null) {
				_listeners=new Vector.<GlobalListener>()
			}//if
			return (_listeners);
		}//get listeners
		
		/**
		 * Verifies that a dispatcher and allowable dispatch source match.
		 * 
		 * @param dispatcher The dispatcher reference to verify.
		 * @param An array of valid source references to verify against.
		 * 
		 * @return True of the source matches one of the source filters, or false.
		 */
		private static function sourcesMatch(dispatcher:*, sourceFilter:*):Boolean {
			if (sourceFilter==null) {
				return (true);
			}//if
			if ((dispatcher==null) && (sourceFilter!=null)){
				return (false);
			}//if
			if (sourceFilter is Array) {
				for (var item:* in sourceFilter) {
					if (sourceFilter[item]==dispatcher) {
						return (true);
					}//if
				}//for
			} else {
				if (sourceFilter==dispatcher) {
					return (true);
				}//if
			}//else
			return (false);
		}//sourceMatch
	}
}
/**
* A global non-source-bound event listener binding used together with GlobalDispatcher.
* 
* Adapted from the SWAG ActionScript toolkit: https://code.google.com/p/swag-as/
* 
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/ 

package org.cg 
{
		
	import org.cg.events.GlobalEvent;
	import org.cg.interfaces.IGlobalEvent;	
	import flash.utils.*;	

	public final class GlobalListener {
		
		/**
		 * @private 
		 */		
		private var _eventType:String=null;
		/**
		 * @private 
		 */
		private var _eventMethod:Function=null;
		/**
		 * @private 
		 */
		private var _methodParameters:Array=null;
		/**
		 * @private 
		 */
		private var _sourceObject:*=null;
		/**
		 * @private 
		 */
		private var _sourceContainer:*=null;
		
		public function GlobalListener(eventType:String=null, eventMethod:Function=null, thisRef:*=null, sourceObject:*=null)	{
			this.type=eventType;
			this._sourceContainer=thisRef;
			this.method=eventMethod;
			this.source=sourceObject;			
		}//constructor
		
		/**
		 * The event type string associated with the listener.
		 * <p>This value may also be set within the class constructor.</p>
		 *  
		 * @param typeSet The event type associated with this event. It's advisable to use one of the defined <code>GlobalEvent</code> 
		 * (or derived), event constants rather than a basic string for easy maintainability and future compatibility.
		 * 
		 */
		public function set type(typeSet:String):void {
			this._eventType=typeSet;
		}//set type
		
		/**
		 * @private
		 * 
		 */		
		public function get type():String {
			return (this._eventType);
		}//get type
		
		/**
		 * The method to invoke when a matching event is dispatched.
		 *  
		 * @param methodSet The method to associate with the event (the method to invoke when the matching event is dispatched).
		 * 
		 */
		public function set method(methodSet:Function):void {
			this._eventMethod=methodSet;
			if (this._sourceContainer!=null) {
				this._methodParameters=getMethodParameters(this._eventMethod, this._sourceContainer);
			}//if
		}//set eventMethod
		
		public static function getMethodParameters(method:Function, container:*):Array {			
			if (method==null) {
				return (null);
			}//if
			if (container==null) {
				return (null);
			}//if
			var returnArray:Array=new Array();
			var containerInfo:XML=describeType(container) as XML;
			if (hasData(containerInfo.method)==false) {
				return (null);
			}//if
			var methods:XMLList=containerInfo.method as XMLList;				
			for (var count:uint=0; count<methods.length(); count++) {
				var currentMethodNode:XML=methods[count] as XML;				
				if (hasData(currentMethodNode.@name)) {
					var methodName:String=new String(currentMethodNode.@name);					
					if (container[methodName]===method) {						
						if (hasData(currentMethodNode.parameter)) {
							var parameterIndex:uint=0;
							var parameterNodes:XMLList=currentMethodNode.parameter as XMLList;							
							for (var count2:uint=0; count2<parameterNodes.length(); count2++) {
								var currentParameterNode:XML=parameterNodes[count2] as XML;
								if (hasData(currentParameterNode.@index)) {
									parameterIndex=uint(String(currentParameterNode.@index));
									parameterIndex-=1; //parameters are 1-indexed
								}//if
								if (hasData(currentParameterNode.@type)) {
									var typeString:String=new String(currentParameterNode.@type);
									if (typeString=="*") {
										returnArray[parameterIndex]=null;
									} else {
										try {
											typeString=typeString.split(".").join("::");											
											var typeClass:Class=getDefinitionByName(typeString) as Class;
											if (typeClass!=null) {
												returnArray[parameterIndex]=typeClass;		
											}//if
										} catch (e:*) {											
										}//catch
									}//else
								}//if
								parameterIndex++;
							}//for
						}//if
					}//if
				}//if
			}//for
			return (returnArray);
		}//getMethodParameters
		
		public static function hasData(... args):Boolean {
			try {
				if (args[0]==undefined) {
					return (false);
				}//if
				if (args[0]==null) {
					return (false);
				}//if
			} catch (e:*) {
				return (false);
			}//catch
			return (true);
		}//hasData
		
		/**
		 * @private
		 */
		public function get method():Function {
			return (this._eventMethod);
		}//get eventMethod
		
		/**
		 * The source object(s) for the listener.
		 * <p>The listener is only invoked if the source is <em>null</em>, or if the source matches the dispatching object(s). 
		 * This value may either be a singular object reference or an array of object references.</p>
		 *  
		 * @param sourceSet The source object(s) associated with the listener, or <em>null</em> to associate with all events
		 * that match the event <code>type</code>.
		 * 
		 */
		public function set source(sourceSet:*):void {
			this._sourceObject=sourceSet;
		}//set source
		
		/**
		 * @private 
		 */
		public function get source():* {
			return (this._sourceObject);
		}//get source
		
		/**
		 * @private
		 */
		private function get sourceContainer():* {
			return (this._sourceContainer);
		}//get sourceContainer
		
		/**
		 * @private
		 */
		private function get methodParameters():Array {
			return (this._methodParameters);
		}//get methodParameters
		
		/**
		 * @private
		 */
		private function get methodParameterInstances():Array {
			if (this.methodParameters==null) {
				return (null);
			}//if
			if (this.methodParameters.length==0) {
				return (new Array());
			}//if
			var returnArray:Array=new Array();
			for (var count:uint=0; count<this.methodParameters.length; count++) {
				var currentParameterType:Class=this.methodParameters[count] as Class;
				if (currentParameterType==null) {
					returnArray.push(null);	
				} else {					
					returnArray.push(new currentParameterType());				
				}//else
			}//for
			return (returnArray);
		}//get methodParameterInstances
				
		public function invoke(event:IGlobalEvent, source:*):Boolean {
			var fnc:Function = this.method;
			if (fnc==null) {
				return (false);
			}			
			event.source=source;			
			if (this.methodParameters==null) {					
				try {
					fnc(event);
					return (true);
				} catch (e:ArgumentError) {
					trace (e);						
					return (false);
				}
			}
			if (this.methodParameters.length==0) {				
				try {
					fnc();
					return (true);
				} catch (e:ArgumentError) {
					trace (e);						
					return (false);
				}
			}
			if ((this.methodParameters[0] is IGlobalEvent) || (this.methodParameters[0] is GlobalEvent) 
				||(getQualifiedSuperclassName(event) == getQualifiedClassName(GlobalEvent)) ) {				
				try {					
					fnc(event);
					return (true);
				} catch (e:ArgumentError) {
					trace (e);						
					return (false);
				}
			} else {				
				if (this.sourceContainer!=null) {
					try {						
						fnc.apply(this.sourceContainer, this.methodParameterInstances);
						return (true);
					} catch (e:ArgumentError) {
						trace (e);							
						return (false);
					}
				} else {
					try {							
						fnc(event);
						return (true);
					} catch (e:ArgumentError) {
						trace (e);							
						return (false);
					}
				}
			}
			return (false);
		}
	}
}
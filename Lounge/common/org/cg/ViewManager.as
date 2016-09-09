/**
* Builds a component-based user interface from XML data. See the <views> node of the settings.xml file for some examples.
*
* (C)opyright 2014, 2015
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg 
{
	import org.cg.interfaces.IView;	
	import org.cg.DebugView; 
	import org.cg.EthereumConsoleView; EthereumConsoleView;
	import flash.display.DisplayObjectContainer;
	import flash.display.MovieClip;
	import flash.system.LoaderContext;	
	import flash.utils.getDefinitionByName;
	import flash.utils.describeType;	
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.net.URLRequest;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.system.Security;
	import flash.system.ApplicationDomain;
	import flash.system.SecurityDomain;	
	
	import com.bit101.utils.MinimalConfigurator;
	//the following declarations force the compiler to include the declared classes
	import com.bit101.components.Component; Component;
	import com.bit101.components.Accordion; Accordion;	
	import com.bit101.components.Calendar; Calendar;
	import com.bit101.components.CheckBox; CheckBox;
	import com.bit101.components.ColorChooser; ColorChooser;
	import com.bit101.components.ComboBox; ComboBox;
	import com.bit101.components.FPSMeter; FPSMeter;
	import com.bit101.components.HBox; HBox;
	import com.bit101.components.HRangeSlider; HRangeSlider;
	import com.bit101.components.HScrollBar; HScrollBar;
	import com.bit101.components.HSlider; HSlider;
	import com.bit101.components.HUISlider; HUISlider;
	import com.bit101.components.IndicatorLight; IndicatorLight;
	import com.bit101.components.InputText; InputText;
	import com.bit101.components.Knob; Knob;
	import com.bit101.components.Label; Label;
	import com.bit101.components.List; List;
	import com.bit101.components.ListItem; ListItem;
	import com.bit101.components.Meter;	Meter;
	import com.bit101.components.NumericStepper; NumericStepper;
	import com.bit101.components.Panel; Panel;
	import com.bit101.components.ProgressBar; ProgressBar ;
	import com.bit101.components.PushButton; PushButton;
	import com.bit101.components.RadioButton; RadioButton;
	import com.bit101.components.RangeSlider; RangeSlider;
	import com.bit101.components.RotarySelector; RotarySelector;
	import com.bit101.components.ScrollBar; ScrollBar;
	import com.bit101.components.ScrollPane; ScrollPane;
	import com.bit101.components.Slider; Slider;
	import com.bit101.components.Style; Style;
	import com.bit101.components.Text; Text;
	import com.bit101.components.TextArea; TextArea;
	import com.bit101.components.UISlider; UISlider;
	import com.bit101.components.VBox; VBox;
	import com.bit101.components.VRangeSlider; VRangeSlider;
	import com.bit101.components.VScrollBar; VScrollBar;
	import com.bit101.components.VSlider; VSlider;
	import com.bit101.components.VUISlider; VUISlider;
	import com.bit101.components.WheelMenu; WheelMenu;
	import com.bit101.components.Window; Window;
	import com.bit101.charts.BarChart; BarChart;
	import com.bit101.charts.Chart; Chart;
	import com.bit101.charts.LineChart; LineChart;
	import com.bit101.charts.PieChart; PieChart;
	
	//custom components
	import org.cg.ImageButton; ImageButton;
	
	//TextField renderer
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.text.TextFieldAutoSize;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	import flash.text.TextFormatDisplay;	
	
	dynamic public class ViewManager 
	{
		/**
		* Embedded application fonts (paths are relative to location of ViewManager.as file).
		*/
		[Embed(source = "/../../assets/fonts/pf_ronda_seven.ttf", embedAsCFF = "false", fontName = "PF Ronda Seven", mimeType = "application/x-font")]
		public var PF_Ronda_Seven_TTF:Class;
		[Embed(source = "/../../assets/fonts/Cabin-Regular-TTF.ttf", embedAsCFF = "false", fontName = "Cabin", mimeType = "application/x-font")]
		public var Cabin_Regular_TTF:Class;		
		[Embed(source = "../../../../assets/fonts/Cabin-Bold-TTF.ttf", embedAsCFF = "false", fontName = "Cabin Bold", mimeType = "application/x-font")]
		public var Cabin_Bold_TTF:Class;
		[Embed(source = "../../../../assets/fonts/airstrip_four.ttf", embedAsCFF = "false", fontName = "Airstrip Four", mimeType = "application/x-font")]
		public var Airstrip_Four_TTF:Class;
		
		private static var _renderTarget:DisplayObjectContainer;	
		private static var _loadsPayloads:Vector.<Object> = new Vector.<Object>();
		
		/**
		 * Renders a XML definition to a target display object container.
		 * 
		 * @param	viewSource The XML definition to render to the target.
		 * @param	target The target to render the viewSource into.
		 * @param	onRender An optional callback function invoked when the view is rendered.
		 */
		public static function render(viewSource:XML, target:DisplayObjectContainer, onRender:Function = null):void 
		{			
			if ((viewSource == null) || (target == null)) {
				return;
			}
			var viewSourceNodes:XMLList = viewSource.children();			
			target = createContainer(viewSource, target);
			for (var count:uint = 0; count < viewSourceNodes.length(); count++) {
				var currentNode:XML = viewSourceNodes[count] as XML;
				var currentNodeContent:String = new String(currentNode.children().toString());				
				switch (currentNode.localName()) {
					case "component": renderComponent(currentNode, target, onRender); break;
					case "swf": renderSWF(currentNode, target, onRender); break;
					case "image": renderImage(currentNode, target, onRender); break;
					case "textfield": renderTextField(currentNode, target, onRender); break;
					default: break;
				}
			}
			if (target is IView) {
				IView(target).initView();				
				if (onRender!=null) {	
					try {
						onRender();
					} catch (err:*) {						
					}					
				}				
			}
		}
		
		/**
		 * Creates a container for in a target with supplied XML specifications.
		 * 
		 * @param	viewSource The XML view definition with container specifications.
		 * @param	target The target into which the container will be rendered.
		 * 
		 * @return A container for the XML definition with the included specifications.
		 */
		private static function createContainer(viewSource:XML, target:DisplayObjectContainer):DisplayObjectContainer 
		{			
			try {
				var componentClassStr:String = new String(viewSource.attribute("class")[0]);
				if ((componentClassStr == null) || (componentClassStr == "") || (componentClassStr == "undefined") || (componentClassStr == "null")) {
					return (target);
				}				
				var instanceName:String = null;				
				var componentClass:Class = getDefinitionByName(componentClassStr) as Class;
				var componentInstance:* = new componentClass();
				if (viewSource.attribute("name").length()>0) {
					instanceName = new String(viewSource.attribute("name")[0]);
					componentInstance["name"] = instanceName;
				}				
				target.addChild(componentInstance);	
				return (componentInstance as DisplayObjectContainer);
			} catch (err:*) {				
				return (target);
			}
			return (target);
		}
		
		/**
		 * Renders an external SWF file specified in a XML node into a target container.
		 * 
		 * @param	swfNode The node containing the external SWF file specifications.
		 * @param	target The target into which to render the external SWF file.
		 * @param	onRender An optional callback function to invoke when the render has completed.
		 */
		private static function renderSWF(swfNode:XML, target:DisplayObjectContainer, onRender:Function = null):void 
		{			
			var swfPath:String = new String(swfNode.children().toString());
			var instanceName:String = null;
			if (swfNode.attribute("name").length()>0) {
				instanceName = new String(swfNode.attribute("name")[0]);
			}
			_renderTarget = target;
			var request:URLRequest = new URLRequest(swfPath);
			var swfLoader:Loader = new Loader();				
			_renderTarget.addChild(swfLoader);
			if (instanceName!=null) {
				_renderTarget[instanceName] = swfLoader.content;
				swfLoader.name = instanceName;
			} 
			addLoadPayload(swfLoader.contentLoaderInfo, swfNode, onRender);
			swfLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadSWF);
			swfLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onLoadSWFError);
			try {
				Security.allowDomain("*");
				Security.allowInsecureDomain("*");
			} catch (err:*) {			
			}
			swfLoader.load(request, new LoaderContext(false, ApplicationDomain.currentDomain));				
		}

		/**
		 * Invoked when an external SWF is loaded.
		 * 
		 * @param	eventObj An Event object.
		 */
		private static function onLoadSWF(eventObj:Event):void 
		{
			var payload:Object = removeLoadPayload(eventObj.target as LoaderInfo);
			var swfData:XML = payload.payload;
			var onRenderCB:Function = payload.onRender;
			eventObj.target.removeEventListener(Event.COMPLETE, onLoadSWF);
			eventObj.target.removeEventListener(IOErrorEvent.IO_ERROR, onLoadSWFError);
			var props:XMLList = swfData.children();
			for (var count:uint = 0; count < props.length(); count++) {
				var prop:XML = props[count] as XML;
				var propName:String = prop.localName();
				var propValue:String = String(prop.children().toString());
				applyValueToTarget(propName, propValue, eventObj.target.content);
			}
			if (onRenderCB!=null) {
				if (!payloadCBExists(onRenderCB)) {
					try {
						onRenderCB();
					} catch (err:*) {						
					}
				}				
			}
		}		

		/**
		 * Invoked when an external SWF load experiences an error.
		 * 
		 * @param	eventObj an Event object.
		 */
		private static function onLoadSWFError(eventObj:Event):void 
		{
			var payload:Object = removeLoadPayload(eventObj.target as LoaderInfo);
			var swfData:XML = payload.payload;
			var onRenderCB:Function = payload.onRender;
			eventObj.target.removeEventListener(Event.COMPLETE, onLoadSWF);
			eventObj.target.removeEventListener(IOErrorEvent.IO_ERROR, onLoadSWFError);
			DebugView.addText ("ViewManager.onLoadSWFError: "+eventObj);
		}
		
		/**
		 * Determines if a specific callback function exists for a load.
		 * 
		 * @param	payloadCB The function to check for.
		 * 
		 * @return True if a callback function exists for a load, false otherwise.
		 */
		private static function payloadCBExists(payloadCB:Function):Boolean 
		{
			if (payloadCB == null) {
				return (false);
			}
			for (var count:uint = 0; count < _loadsPayloads.length; count++) {				
				var currentLoadPayload:Object = _loadsPayloads[count];	
				if (currentLoadPayload.onRender == payloadCB) {
					return (true);
				}
			}
			return (false);
		}

		
		/**
		 * Adds payload data to a load that may be queried on load completion.
		 * 
		 * @param	loaderInfo The LoaderInfo instance of the associated load.
		 * @param	payloadData Payload XML data to include.
		 * @param	onRender Optional callback function to invoke when the load completes.
		 */
		private static function addLoadPayload(loaderInfo:LoaderInfo, payloadData:XML, onRender:Function = null):void 
		{		
			var newObj:Object = new Object();
			newObj.loaderInfo = loaderInfo;
			newObj.payload = payloadData;
			newObj.onRender = onRender;
			_loadsPayloads.push(newObj);
		}
		
		/**
		 * Removes payload data from a load.
		 * 
		 * @param	loaderInfo The LoaderInfo instance of the associated load.		 
		 */
		private static function removeLoadPayload(loaderInfo:LoaderInfo):Object 
		{
			var packedVec:Vector.<Object> = new Vector.<Object>();
			var foundObj:Object = null;
			for (var count:uint = 0; count < _loadsPayloads.length; count++) {
				try {
					var currentLoadPayload:Object = _loadsPayloads[count];			    
					if (currentLoadPayload.loaderInfo == loaderInfo) {
						foundObj = currentLoadPayload;
					} else {
						packedVec.push(currentLoadPayload);
					}
				} catch (err:*) {					
				}
			}
			_loadsPayloads = packedVec;
			return (foundObj);
		}
		
		/**
		 * Renders an external image file specified in a XML node into a target container.
		 * 
		 * @param	imageNode The node containing the external image file specifications.
		 * @param	target The target into which to render the external image file.
		 * @param	onRender An optional callback function to invoke when the render has completed.
		 */
		private static function renderImage(imageNode:XML, target:DisplayObjectContainer, onRender:Function = null):void 
		{			
			var imagePath:String = new String(imageNode.@src);
			var instanceName:String = null;
			if (imageNode.attribute("name").length()>0) {
				instanceName = new String(imageNode.attribute("name")[0]);				
				instanceName = new String(imageNode.attribute("name")[0]);				
			}
			_renderTarget = target;
			var request:URLRequest = new URLRequest(imagePath);
			var imageLoader:Loader = new Loader();				
			_renderTarget.addChild(imageLoader);
			if (instanceName!=null) {
				_renderTarget[instanceName] = imageLoader;				
				imageLoader.name = instanceName;
			} 
			addLoadPayload(imageLoader.contentLoaderInfo, imageNode, onRender);
			imageLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadImage);
			imageLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, onLoadImageError);
			try {
				Security.allowDomain("*");
				Security.allowInsecureDomain("*");			
			} catch (err:*) {				
			}
			imageLoader.load(request, new LoaderContext(false, ApplicationDomain.currentDomain));				
		}
			
		/**
		 * Invoked when the external image is loaded.
		 * 
		 * @param	eventObj An Event object.
		 */
		private static function onLoadImage(eventObj:Event):void 
		{				
			var payload:Object = removeLoadPayload(eventObj.target as LoaderInfo);			
			var imageData:XML = payload.payload;			
			var onRenderCB:Function = payload.onRender;			
			eventObj.target.removeEventListener(Event.COMPLETE, onLoadSWF);
			eventObj.target.removeEventListener(IOErrorEvent.IO_ERROR, onLoadSWFError);	
			var props:XMLList = imageData.children();
			for (var count:uint = 0; count < props.length(); count++) {
				var prop:XML = props[count] as XML;
				var propName:String = prop.localName();
				var propValue:String = String(prop.children().toString());
				applyValueToTarget(propName, propValue, eventObj.target.content);
			}
			if (onRenderCB!=null) {
				if (!payloadCBExists(onRenderCB)) {
					try {
						onRenderCB();
					} catch (err:*) {						
					}
				}				
			}			
		}
		
		/**
		 * Invoked when an image load experiences an error.
		 * 
		 * @param	eventObj An Event object.
		 */
		private static function onLoadImageError(eventObj:Event):void 
		{
			var payload:Object = removeLoadPayload(eventObj.target as LoaderInfo);
			var imageData:XML = payload.payload;
			var onRenderCB:Function = payload.onRender;
			eventObj.target.removeEventListener(Event.COMPLETE, onLoadSWF);
			eventObj.target.removeEventListener(IOErrorEvent.IO_ERROR, onLoadSWFError);
			DebugView.addText ("ViewManager.onLoadImageError: "+eventObj);
		}
		
		/**
		 * Renders a TextField instance specified in a XML node into a target container.
		 * 
		 * @param	textfieldNode The node containing the TextField specifications.
		 * @param	target The target into which to render the TextField.
		 * @param	onRender An optional callback function to invoke when the render has completed.
		 */
		private static function renderTextField(textfieldNode:XML, target:DisplayObjectContainer, onRender:Function = null):void 
		{			
			try {
				var instanceName:String = null;
				if (textfieldNode.attribute("name").length()>0) {
					instanceName = new String(textfieldNode.attribute("name")[0]);					
				}				
				var field:TextField = new TextField();
				if ((instanceName != null) && (instanceName != "")) {
					field.name = instanceName;				
				}
				target.addChild(field);	
				try {
					target[instanceName] = field;
				} catch (err:*) {					
				}
				var format:TextFormat = null;
				try {
					if (textfieldNode.@font != null) {
						if (format == null) {
							format = new TextFormat();
						}
						format.font = String(textfieldNode.@font);
					}
				} catch (err:*) {					
				}
				try {
					if (textfieldNode.@size != null) {
						if (format == null) {
							format = new TextFormat();
						}
						format.size = Number(textfieldNode.@size);
					}
				} catch (err:*) {					
				}
				try {
					if (textfieldNode.@color != null) {
						if (format == null) {
							format = new TextFormat();
						}						
						format.color = Number(textfieldNode.@color);
					}
				} catch (err:*) {					
				}
				var props:XMLList = textfieldNode.children();				
				for (var count:uint = 0; count < props.length(); count++) {
					var prop:XML = props[count] as XML;
					var propName:String = prop.localName();
					var propValue:String = String(prop.children().toString());
					applyValueToTarget(propName, propValue, field);
				}
				//if this is done before the properties, many of them aren't applied properly
				if (format != null) {
					field.textColor = uint(String(format.color));
					field.defaultTextFormat = format;
					field.setTextFormat(format);
				}
				if (onRender != null) {
					onRender();
				}
			} catch (err:*) {
				DebugView.addText ("ViewManager.renderTextField ERROR: " + err);
			}			
		}
		
		/**
		 * Renders a custom component class specified in a XML node into a target container.
		 * 
		 * @param	componentNode The node containing the component specifications.
		 * @param	target The target into which to render the component.
		 * @param	onRender An optional callback function to invoke when the render has completed.
		 */
		private static function renderComponent(componentNode:XML, target:DisplayObjectContainer, onRender:Function = null):void 
		{			
			try {
				var componentClassStr:String = new String(componentNode.attribute("class")[0]);				
				var instanceName:String = null;
				if (componentNode.attribute("name").length()>0) {
					instanceName = new String(componentNode.attribute("name")[0]);					
				}
				var componentClass:Class = getDefinitionByName(componentClassStr) as Class;				
				var componentInstance:* = new componentClass();			
				target.addChild(componentInstance);				
				if (instanceName!=null) {
					target[instanceName] = componentInstance;					
				}				
				var props:XMLList = componentNode.children();
				for (var count:uint = 0; count < props.length(); count++) {
					var prop:XML = props[count] as XML;
					var propName:String = prop.localName();
					var propValue:String = String(prop.children().toString());					
					applyValueToTarget(propName, propValue, componentInstance);
				}
				if (onRender != null) {
					onRender();
				}
			} catch (err:*) {
				DebugView.addText ("ViewManager.renderComponent ERROR: " + err);
			}
		}
		
		/**
		 * Attempts to apply a named value to a target object.
		 * 
		 * @param	varName The variable name to attempt to set.
		 * @param	value The value to attempt to assign to the variable denoted by varName.
		 * @param	target The target object in which the variable should exist.
		 */
		private static function applyValueToTarget(varName:String, value:*, target:*):void 
		{
			if ((varName == null) || (varName == "")) {
				return;
			}
			if ((target == null) || (target == "")) {
				return;
			}
			try {
				if (target[varName] is String) {
					target[varName] = String(value);					
				} else if (target[varName] is Number) {
					target[varName] = Number(value);
				} else if (target[varName] is uint) {
					target[varName] = uint(value);
				} else if (target[varName] is int) {
					target[varName] = int(value);
				} else if (target[varName] is XML) {
					target[varName] = new XML(String(value));
				} else if (target[varName] is Boolean) {
					var boolStr:String = new String(value);
					boolStr = boolStr.toLowerCase();
					boolStr = boolStr.split(String.fromCharCode(32)).join("");
					switch (boolStr) {
						case "true" : target[varName] = true; break;
						case "false" : target[varName] = false; break;
						case "t" : target[varName] = true; break;
						case "f" : target[varName] = false; break;
						case "1" : target[varName] = true; break;
						case "0" : target[varName] = false; break;
						case "on" : target[varName] = true; break;
						case "off" : target[varName] = false; break;
						case "enable" : target[varName] = true; break;
						case "disable" : target[varName] = false; break;
						case "enabled" : target[varName] = true; break;
						case "disabled" : target[varName] = false; break;
						case "e" : target[varName] = true; break;
						case "d" : target[varName] = false; break;
						case "yes" : target[varName] = true; break;
						case "no" : target[varName] = false; break;
						case "y" : target[varName] = true; break;
						case "n" : target[varName] = false; break;
						case "+" : target[varName] = true; break;
						case "-" : target[varName] = false; break;
						case "okay" : target[varName] = true; break;
						case "ok" : target[varName] = true; break;
						case "checked" : target[varName] = true; break;
						case "selected" : target[varName] = true; break;
						default : target[varName] = Boolean(varName); break;
					}					
				} else {
					target[varName] = value;
				}
			} catch (err:*) {				
			}
		}
	}
}
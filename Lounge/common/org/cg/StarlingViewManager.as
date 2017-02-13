/**
* Builds a component-based user interface from XML data. See the <views> node of the settings.xml file for some examples.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg {
					
	import feathers.controls.text.BaseTextRenderer;
	import feathers.core.BaseTextEditor;
	import feathers.core.ITextEditor;
	import feathers.text.BitmapFontTextFormat;
	import flash.display.DisplayObjectContainer;
	import flash.display.Stage;
	import org.cg.StarlingContainer; 
	import org.cg.interfaces.IPanelLeaf;
	import org.cg.interfaces.ISlidingPanel;
	import org.cg.interfaces.IWidget;
	import org.cg.widgets.Widget;
	import org.cg.interfaces.IPanelWidget;
	import org.cg.widgets.PanelWidget;	
	import org.cg.widgets.ConnectedPeersWidget;
	import org.cg.widgets.ConnectivitySelectorWidget;
	import org.cg.widgets.EthereumAccountWidget;
	import org.cg.widgets.EthereumStatusWidget;
	import org.cg.widgets.EthereumMiningControlWidget;
	import org.cg.widgets.NewWindowWidget;
	import org.cg.widgets.TableManagerWidget;
	import starling.display.Image;
	import starling.display.Sprite;
	import starling.textures.Texture;
	import starling.display.DisplayObject;
	import org.cg.interfaces.ILounge;
	import org.cg.Lounge;
	import flash.utils.getDefinitionByName;
	import org.cg.DebugView; 
	import starling.events.Event;
	
	//Containers
	import org.cg.SlidingPanel;
	import org.cg.PanelLeaf;	
	
	//Themes
	import feathers.themes.MetalWorksMobileTheme; MetalWorksMobileTheme;
	import feathers.themes.MetalWorksDesktopTheme; MetalWorksDesktopTheme;
	import feathers.themes.AeonDesktopTheme; AeonDesktopTheme;
	import feathers.themes.MinimalDesktopTheme; MinimalDesktopTheme;
	import feathers.themes.MinimalMobileTheme; MinimalMobileTheme;
	import feathers.themes.TopcoatLightMobileTheme; TopcoatLightMobileTheme;
	
	//Feathers UI components
	import feathers.skins.StyleProviderRegistry;
	import feathers.core.ITextRenderer;	
	import feathers.controls.renderers.IListItemRenderer;
	import feathers.data.ListCollection;
	import feathers.core.FeathersControl;
	import feathers.controls.renderers.DefaultListItemRenderer; DefaultListItemRenderer;
	import feathers.controls.text.TextFieldTextRenderer; TextFieldTextRenderer;
	import feathers.controls.text.BitmapFontTextRenderer; BitmapFontTextRenderer
	import feathers.controls.text.TextBlockTextRenderer; TextBlockTextRenderer;
	import feathers.controls.Alert; Alert;
	import feathers.controls.AutoComplete; AutoComplete;
	import feathers.controls.AutoSizeMode; AutoSizeMode;
	import feathers.controls.BasicButton; BasicButton;
	import feathers.controls.Button; Button;
	import feathers.controls.ButtonGroup; ButtonGroup;
	import feathers.controls.ButtonState; ButtonState;
	import feathers.controls.Callout; Callout;
	import feathers.controls.Check; Check;
	import feathers.controls.DateTimeMode; DateTimeMode;
	import feathers.controls.DateTimeSpinner; DateTimeSpinner;
	import feathers.controls.DecelerationRate; DecelerationRate;
	import feathers.controls.DragGesture; DragGesture;
	import feathers.controls.Drawers; Drawers;
	import feathers.controls.GroupedList; GroupedList;
	import feathers.controls.Header; Header;
	import feathers.controls.ImageLoader; ImageLoader;
	import feathers.controls.ItemRendererLayoutOrder; ItemRendererLayoutOrder;
	import feathers.controls.Label; Label;
	import feathers.controls.LayoutGroup; LayoutGroup;
	import feathers.controls.List; List;
	import feathers.controls.NumericStepper; NumericStepper;
	import feathers.controls.Panel; Panel;
	import feathers.controls.PageIndicator; PageIndicator;
	import feathers.controls.PageIndicatorInteractionMode; PageIndicatorInteractionMode;
	import feathers.controls.PanelScreen; PanelScreen;
	import feathers.controls.PickerList; PickerList;
	import feathers.controls.ProgressBar; ProgressBar;
	import feathers.controls.Radio; Radio;
	import feathers.controls.Screen; Screen;
	import feathers.controls.ScreenNavigator; ScreenNavigator;
	import feathers.controls.ScreenNavigatorItem; ScreenNavigatorItem;
	import feathers.controls.ScrollBar; ScrollBar;
	import feathers.controls.ScrollBarDisplayMode; ScrollBarDisplayMode;
	import feathers.controls.ScrollContainer; ScrollContainer;
	import feathers.controls.Scroller; Scroller;
	import feathers.controls.ScrollInteractionMode; ScrollInteractionMode;
	import feathers.controls.ScrollPolicy; ScrollPolicy;
	import feathers.controls.ScrollScreen; ScrollScreen;
	import feathers.controls.ScrollText; ScrollText;
	import feathers.controls.SimpleScrollBar; SimpleScrollBar;
	import feathers.controls.Slider; Slider;
	import feathers.controls.SpinnerList; SpinnerList;
	import feathers.controls.StackScreenNavigator; StackScreenNavigator;
	import feathers.controls.StackScreenNavigatorItem; StackScreenNavigatorItem;
	import feathers.controls.StepperButtonLayoutMode; StepperButtonLayoutMode;
	import feathers.controls.TabBar; TabBar;
	import feathers.controls.TabNavigator; TabNavigator;
	import feathers.controls.TabNavigatorItem; TabNavigatorItem;
	import feathers.controls.TextArea; TextArea;
	import feathers.controls.TextCallout; TextCallout;
	import feathers.controls.TextInput; TextInput;
	import feathers.controls.TextInputState; TextInputState;
	import feathers.controls.ToggleButton; ToggleButton;
	import feathers.controls.ToggleState; ToggleState;
	import feathers.controls.ToggleSwitch; ToggleSwitch;
	import feathers.controls.TrackInteractionMode; TrackInteractionMode;
	import feathers.controls.TrackLayoutMode; TrackLayoutMode;
	import feathers.controls.TrackScaleMode; TrackScaleMode;
	import feathers.controls.WebView; WebView;
	
	import flash.text.Font;
	import flash.text.TextFormat;
	import starling.text.TextFormat;
	
	dynamic public class StarlingViewManager {		
		
		/**
		* Embedded application fonts (paths are relative to location of ViewManager.as file).
		*/
		[Embed(source = "/../../assets/fonts/Rubik-Regular.ttf", embedAsCFF = "false", fontName = "Rubik-Regular", mimeType = "application/x-font")]
		public static const Rubik_Regular_TTF:Class;			
		public static const Rubik_Regular_font:Font = new Rubik_Regular_TTF();	
		[Embed(source = "/../../assets/fonts/Ubuntu-Title.ttf", embedAsCFF = "false", fontName = "Ubuntu-Title", mimeType = "application/x-font")]
		public static const Ubuntu_Title_TTF:Class;			
		public static const Ubuntu_Title_font:Font = new Ubuntu_Title_TTF();
		[Embed(source = "/../../assets/fonts/Abel-Regular.ttf", embedAsCFF = "false", fontName = "Abel", mimeType = "application/x-font")]
		public static const Abel_Regular_TTF:Class;			
		public static const Abel_Regular_font:Font = new Abel_Regular_TTF();	
		[Embed(source = "/../../assets/fonts/Confidel.otf", embedAsCFF = "false", fontName = "Confidel", mimeType = "application/x-font")]
		public static const Confidel_TTF:Class;			
		public static const Confidel_font:Font = new Confidel_TTF();
		
		public static var useEmbededFonts:Boolean = false;
		
		private static var _alertIcons:Vector.<Object> = new Vector.<Object>();

		
		
		public static function setTheme(themeName:String):void {			
			switch (themeName) {
				case "MetalWorksMobileTheme": new MetalWorksMobileTheme(); break;
				case "MetalWorksDesktopTheme": new MetalWorksDesktopTheme(); break;				
				case "AeonDesktopTheme": new AeonDesktopTheme(); break;	
				case "MinimalDesktopTheme": new MinimalDesktopTheme(); break;
				case "MinimalMobileTheme": new MinimalMobileTheme(); break;
				case "TopcoatLightMobileTheme": new TopcoatLightMobileTheme(); break;
			}
			preloadAlertIcons();
		}
		
		private static function preloadAlertIcons():void {
			var alertNode:XML = GlobalSettings.getSetting("views", "alert");
			var childNodes:XMLList = alertNode.children();
			for (var count:int = 0; count < childNodes.length(); count++) {
				var node:XML = childNodes[count];
				if (node.localName() == "icon") {					
					var iconSrc:String = node.child("src")[0].toString();
					var icon:ImageLoader = new ImageLoader();
					icon.addEventListener(Event.COMPLETE, onIconImageLoad);						
					icon.source = iconSrc;
				}
			}
		}
		
		private static function onLoadAlertIcon(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.COMPLETE, onIconImageLoad);
			var iconImage:Image = new Image(Texture.fromData(eventObj.target));
			_alertIcons.push ({icon:iconImage, src:ImageLoader(eventObj.target).source});
		}
		
		/**
		 * Renders a XML definition to the current StarlingContainer instance.
		 * 
		 * @param	viewSource The XML definition to render.
		 * @param	loungeRef Reference to the parent lounge instance.
		 * @param	onRender An optional callback function invoked when the view is rendered.
		 * 
		 * @return A Reference to the rendered UI element(s) / container, or null if there was a problem.
		 */
		public static function render(viewSource:XML, loungeRef:ILounge, onRender:Function = null):* {	
			DebugView.addText("StarlingViewManager.render");			
			if (viewSource == null) {
				return;
			}			
			var viewType:String = viewSource.localName();			
			//enable TrueType font rendering via TextFormat
			FeathersControl.defaultTextRendererFactory = function():ITextRenderer {
				return new TextFieldTextRenderer();
			};
			switch (viewType.toLowerCase()) {
				case "panel": 
					return (renderSlidingPanel(viewSource, loungeRef));
					break;
				case "leaf": 
					return (renderPanelLeaf(viewSource, loungeRef));
					break;
				case "widget": 
					var widgetRef:IWidget = renderWidget(viewSource, loungeRef, loungeRef);					
					try {
						widgetRef.initialize();
					} catch (err:*) {
						DebugView.addText ("Couldn't invoke initialize method on widget " + widgetRef);
						DebugView.addText(err.getStackTrace());
					}
					return (widgetRef);
					break;
				default: 
					return (renderComponents(viewSource.children(), loungeRef, loungeRef));
					break;
			}			
		}
		
		public static function alert(message:String, title:String = null, buttons:ListCollection = null, iconName:String = null, 
					isModal:Boolean = true, isCentered:Boolean = true):Alert {						
			if (iconName != null) {
				var icon:ImageLoader;
				var iconPath:String = getAlertIconPath(iconName);
				if (iconPath != null) {
					for (var count:int = 0; count < _alertIcons.length; count++) {
						DebugView.addText("_alertIcons[count].source=" + _alertIcons[count].src);
						if (_alertIcons[count].src == iconPath) {
							icon = _alertIcons[count].icon;
							break;
						}
					}
				}
				if (icon == null) {
					icon = new ImageLoader();
					_alertIcons.push (icon);
					icon.source = iconPath;
				}
			} else {
				icon = null;
			}
			return(Alert.show(message, title, buttons, icon, isModal, isCentered, skinnedAlertBox));
		}
		
		private static function getAlertIconPath(iconName:String):String {
			var alertNode:XML = GlobalSettings.getSetting("views", "alert");
			var childNodes:XMLList = alertNode.children();
			for (var count:int = 0; count < childNodes.length(); count++) {
				var node:XML = childNodes[count];
				if (node.localName() == "icon") {
					var name:String = node.child("name")[0].toString();
					if (name == iconName) {
						return (node.child("src")[0].toString());
					}
				}
			}
			return (null);
		}
		
		public static function skinnedAlertBox():Alert {			
			var alertNode:XML = GlobalSettings.getSetting("views", "alert");
			var alert:Alert = new Alert();
			if (alertNode != null) {		
				applyTextFormat(alertNode, "promptformat", alert, "fontStyles", false);
				applyTextFormat(alertNode, "headerformat", alert.headerProperties, "fontStyles", false);
				alert.buttonGroupFactory = function():ButtonGroup {
					var buttonGroup:ButtonGroup = new ButtonGroup();					
					buttonGroup.buttonFactory = function():Button {
						var button:Button = new Button();						
						applyTextFormat(alertNode, "buttonformat", button, "fontStyles", false);
						return button;
					}
					return buttonGroup;
				}
			}			
			return(alert);			
		}
		
		private static function renderSlidingPanel (panelData:XML, loungeRef:ILounge):ISlidingPanel {
			var panelPosition:String = new String(panelData.@position);
			var panel:ISlidingPanel = null;
			for (var count:int = 0; count < SlidingPanel.panels.length; count++) {
				if (SlidingPanel.panels[count].position == panelPosition) {
					panel = SlidingPanel.panels[count];
					break;
				}
			}
			if (panel == null) {
				//create new panel
				panel = new SlidingPanel(loungeRef, panelData);			
				StarlingContainer.instance.addChild(panel as Sprite);
				renderComponents(panelData.children(), panel, loungeRef);
				panel.initialize();
			} else {
				//use existing panel
				renderComponents(panelData.children(), panel, loungeRef);
				panel.update(panelData);
			}
			return (panel);
		}
		
		private static function renderPanelLeaf (leafNode:XML, loungeRef:ILounge):IPanelLeaf {
			DebugView.addText("StarlingViewManager.renderPanelLeaf");
			try {				
				var panelLeaf:IPanelLeaf = new PanelLeaf(loungeRef, leafNode);			
				StarlingContainer.instance.addChild(panelLeaf as Sprite);			
				renderComponents(leafNode.children(), panelLeaf, loungeRef);
				panelLeaf.initialize();
				return (panelLeaf);
			} catch (err:*) {
				DebugView.addText ("   Panel leaf class \""+leafNode.attribute("class")[0]+"\" can't be found in application memory. Has it been included in the StarlingViewManager class header definition?");
			}
			return (null);
		}
		
		public static function renderComponents (componentList:XMLList, target:*, loungeRef:ILounge):* {
			var renderedComponents:Vector.<*> = new Vector.<*>();
			for (var count:int = 0; count < componentList.length(); count++) {
				var currentComponent:XML = componentList[count] as XML;
				var elementType:String = currentComponent.localName();				
				var componentRef:* = null;
				switch (elementType.toLowerCase()) {
					case "widget": componentRef = renderWidget(currentComponent, target, loungeRef); break;
					case "image": componentRef=renderImage(currentComponent, target); break;
					case "button": componentRef=renderButton(currentComponent, target); break;
					case "check": componentRef = renderCheck(currentComponent, target); break;
					case "radio": componentRef = renderRadio(currentComponent, target); break;
					case "text": componentRef = renderText(currentComponent, target); break;
					case "hline": componentRef = renderHLine(currentComponent, target); break;
					case "label": componentRef = renderText(currentComponent, target); break;
					case "togglebutton": componentRef = renderToggleButton(currentComponent, target); break;
					case "toggleswitch": componentRef = renderToggleSwitch(currentComponent, target); break;
					case "textinput": componentRef = renderTextInput(currentComponent, target); break;
					case "numericstepper": componentRef = renderNumericStepper(currentComponent, target); break;
					case "list": componentRef = renderList(currentComponent, target); break;
					case "pickerlist": componentRef = renderPickerList(currentComponent, target); break;
					default:
						try {
							var valueStr:String = currentComponent.toString();
							//Most of these values must be set in the class at instantiation time
							if (target[elementType] is String) {								
								target[elementType] = valueStr;							 
							} else if (target[elementType] is Number) {								
								target[elementType] = Number(valueStr);
							} else if (target[elementType] is uint) {
								target[elementType] = uint(valueStr);
							} else if (target[elementType] is int) {
								target[elementType] = int(valueStr);
							} else if (target[elementType] is XML) {
								target[elementType] = currentComponent;
							} else if (target[elementType] is Boolean) {
								if (valueStr.toLowerCase() == "true") {
									target[elementType] = true;
								} else {
									target[elementType] = false;
								}
							} else {
								//If values not set try blind assignent stack
								try {
									target[elementType] = valueStr;
								} catch (err:*) {
									try {
										target[elementType] = Number(valueStr);
									} catch (err:*) {
										try {
											target[elementType] = uint(valueStr);
										} catch (err:*) {
											try {
												target[elementType] = int(valueStr);
											} catch (err:*) {
												try {
													target[elementType] = XML(new XML(valueStr));
												} catch (err:*) {
													try {
														//should also work with Booleans
														target[elementType] = JSON.parse(valueStr);
													} catch (err:*) {
													}													
												}
											}
										}
									}
								}
							}
						} catch (err:*) {							
						}
						break;
					
				}
				if (componentRef != null) {
					renderedComponents.push(componentRef);
				}
				if ((currentComponent.@instance != null) && (currentComponent.@instance != undefined) && (currentComponent.@instance != "")) {
					try {
						target[currentComponent.@instance] = componentRef;
					} catch (err:*) {
						DebugView.addText("Property \"" + currentComponent.@instance+"\" either does not exist or is of the wrong type in target " + target);
						DebugView.addText("Component = " + componentRef);
						DebugView.addText(err.getStackTrace());
					}
				}
				if (elementType.toLowerCase() == "widget") {
					try {
						componentRef.initialize();
					} catch (err:*) {
						DebugView.addText ("Couldn't invoke initialize method on widget " + componentRef);
						DebugView.addText(err.getStackTrace());
					}
				}
			}
			return (renderedComponents);
		}		
		
		private static function renderWidget(widgetNode:XML, target:*, loungeRef:ILounge):IWidget {
			if ((widgetNode.attribute("class")[0] != null) && (widgetNode.attribute("class")[0] != undefined) && (widgetNode.attribute("class")[0] != "")) {
				try {
					var widgetClass:Class = getDefinitionByName(widgetNode.attribute("class")[0]) as Class;
				} catch (err:*) {
					DebugView.addText ("   There was a problem finding the widget class \"" + widgetNode.attribute("class")[0] + "\".");
					DebugView.addText ("   Ensure that the class is present in the compiler path, imported, and referenced in a loaded application class.");
					return (null);
				}
			} else {
				widgetClass = Widget;
			}			
			var widget:IWidget = new widgetClass(loungeRef, target, widgetNode);	
			renderComponents(widgetNode.children(), widget, loungeRef);
			if (target is SlidingPanel) {	
				target.addWidget(widget);
			} else {
				if (target is flash.display.DisplayObjectContainer) {
					StarlingContainer.instance.addChild(widget as DisplayObject);
				} else {
					target.addChild(widget);
				}
			}
			return (widget);
		}
		
		private static function renderImage(componentNode:XML, target:*):ImageLoader {				
			var image:ImageLoader = new ImageLoader();
			setIfExists(image, "x", componentNode, "Number");
			setIfExists(image, "y", componentNode, "Number");
			setIfExists(image, "width", componentNode, "Number");
			setIfExists(image, "height", componentNode, "Number");	
			try {
				image.source = componentNode.child("src")[0].toString();
			} catch (err:*) {				
			}
			target.addChild(image);			
			return (image);
		}
		
		private static function renderButton(componentNode:XML, target:*):Button {				
			var button:Button = new Button();
			setIfExists(button, "x", componentNode, "Number");
			setIfExists(button, "y", componentNode, "Number");
			setIfExists(button, "width", componentNode, "Number");
			setIfExists(button, "height", componentNode, "Number");
			setIfExists(button, "label", componentNode, "String");
			loadIcon(button, componentNode);
			loadSkin(button, componentNode);
			applyTextFormat(componentNode, "format", button.defaultLabelProperties, "textFormat", true);
			applyTextFormat(componentNode, "disabledformat", button, "disabledFontStyles", false);			
			target.addChild(button);
			button.invalidate();
			return (button);
		}
			
		private static function loadIcon(target:*, componentNode:XML, nodeName:String="icon", targetProperty:String="defaultIcon"):void {
			try {
				if (componentNode.child(nodeName).length() > 0) {				
					var iconLoader:ImageLoader = new ImageLoader();
					iconLoader.addEventListener(Event.COMPLETE, onIconImageLoad);					
					iconLoader.source = componentNode.child("icon")[0].toString();
					target[targetProperty] = iconLoader;
				}
			} catch (err:*) {				
			}			
		}
		
		private static function onIconImageLoad(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.COMPLETE, onIconImageLoad);	
			//take some other action if necessary
		}
		
		private static function loadSkin(target:*, componentNode:XML, nodeName:String="skin", targetProperty:String="defaultSkin"):void {
			try {
				if (componentNode.child(nodeName).length() > 0) {				
					var iconLoader:ImageLoader = new ImageLoader();
					iconLoader.addEventListener(Event.COMPLETE, onSkinImageLoad);					
					iconLoader.source = componentNode.child("skin")[0].toString();
					target[targetProperty] = iconLoader;
				}
			} catch (err:*) {				
			}			
		}
		
		private static function onSkinImageLoad(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.COMPLETE, onSkinImageLoad);	
			//take some other action if necessary
		}
				
			
		
		private static function renderCheck(componentNode:XML, target:*):Check {			
			var check:Check = new Check();
			setIfExists(check, "x", componentNode, "Number");
			setIfExists(check, "y", componentNode, "Number");
			setIfExists(check, "width", componentNode, "Number");
			setIfExists(check, "height", componentNode, "Number");
			setIfExists(check, "label", componentNode, "String");
			setIfExists(check, "selected", componentNode, "Boolean", "isSelected");				
			applyTextFormat(componentNode, "format", check.defaultLabelProperties, "textFormat", true);			
			target.addChild(check);
			check.invalidate();
			return (check);
		}
		
		private static function renderToggleButton(componentNode:XML, target:*):ToggleButton {
			var toggle:ToggleButton = new ToggleButton();
			setIfExists(toggle, "x", componentNode, "Number");
			setIfExists(toggle, "y", componentNode, "Number");
			setIfExists(toggle, "width", componentNode, "Number");
			setIfExists(toggle, "height", componentNode, "Number");
			setIfExists(toggle, "label", componentNode, "String");
			applyTextFormat(componentNode, "format", toggle, "fontStyles");			
			applyTextFormat(componentNode, "formatselected", toggle, "selectedFontStyles");
			loadIcon(toggle, componentNode);			
			target.addChild(toggle);
			toggle.invalidate();
			return (toggle);
		}
		
		private static function renderToggleSwitch(componentNode:XML, target:*):ToggleSwitch {
			var toggle:ToggleSwitch = new ToggleSwitch();
			setIfExists(toggle, "x", componentNode, "Number");
			setIfExists(toggle, "y", componentNode, "Number");
			setIfExists(toggle, "width", componentNode, "Number");
			setIfExists(toggle, "height", componentNode, "Number");
			setIfExists(toggle, "label", componentNode, "String");
			applyTextFormat(componentNode, "format", toggle, "fontStyles");			
			applyTextFormat(componentNode, "formatselected", toggle, "selectedFontStyles");
			loadIcon(toggle, componentNode);			
			target.addChild(toggle);
			toggle.invalidate();
			return (toggle);
		}
		
		private static function renderTextInput(componentNode:XML, target:*):TextInput {		
			var inputField:TextInput = new TextInput();
			setIfExists(inputField, "x", componentNode, "Number");
			setIfExists(inputField, "y", componentNode, "Number");
			setIfExists(inputField, "width", componentNode, "Number");
			setIfExists(inputField, "height", componentNode, "Number");
			setIfExists(inputField, "prompt", componentNode, "String");
			setIfExists(inputField, "text", componentNode, "String");
			setIfExists(inputField, "restrict", componentNode, "String");			
			setIfExists(inputField, "maxchars", componentNode, "int", "maxChars");
			setIfExists(inputField, "password", componentNode, "Boolean", "displayAsPassword");				
			setIfExists(inputField, "editable", componentNode, "Boolean", "isEditable");			
			setIfExists(inputField, "selectable", componentNode, "Boolean", "isSelectable");
			loadIcon(inputField, componentNode);
			applyTextFormat(componentNode, "inputformat", inputField, "fontStyles", false);
			target.addChild(inputField);
			inputField.invalidate();
			return (inputField);
		}
		
		private static function renderHLine(componentNode:XML, target:*):Image {			
			var hLineProps:Object = new Object();
			hLineProps.color = 0x000000;
			hLineProps.alpha = 1;
			hLineProps.x = 0;
			hLineProps.y = 0;
			hLineProps.width = 150;
			hLineProps.thickness = 1;
			setIfExists(hLineProps, "x", componentNode, "Number");
			setIfExists(hLineProps, "y", componentNode, "Number");
			setIfExists(hLineProps, "width", componentNode, "Number");
			setIfExists(hLineProps, "thickness", componentNode, "Number");		
			setIfExists(hLineProps, "color", componentNode, "uint");
			setIfExists(hLineProps, "alpha", componentNode, "Number");
			var bgTexture:Texture = Texture.fromColor(hLineProps.width, hLineProps.thickness, hLineProps.color, hLineProps.alpha);
			var bgImage:Image = new Image(bgTexture);
			bgImage.x = hLineProps.x;
			bgImage.y = hLineProps.y;
			target.addChild(bgImage);
			return (bgImage);
		}
		
		private static function renderRadio(componentNode:XML, target:*):Radio {	
			var radio:Radio = new Radio();
			setIfExists(radio, "x", componentNode, "Number");
			setIfExists(radio, "y", componentNode, "Number");
			setIfExists(radio, "width", componentNode, "Number");
			setIfExists(radio, "height", componentNode, "Number");			
			setIfExists(radio, "label", componentNode, "String");
			loadIcon(radio, componentNode);
			applyTextFormat(componentNode, "format", radio, "fontStyles");
			target.addChild(radio);
			radio.invalidate();
			//toggle group should be added in the target widget/view
			return (radio);
		}
		
		private static function renderText(componentNode:XML, target:*):Label {	
			var label:Label = new Label();
			setIfExists(label, "x", componentNode, "Number");
			setIfExists(label, "y", componentNode, "Number");
			setIfExists(label, "width", componentNode, "Number");
			setIfExists(label, "height", componentNode, "Number");			
			setIfExists(label, "text", componentNode, "String");
			setIfExists(label, "wordwrap", componentNode, "Boolean", "wordWrap");
			setIfExists(label, "padding", componentNode, "Number");
			setIfExists(label, "paddingbottom", componentNode, "Number", "paddingBottom");
			setIfExists(label, "paddingtop", componentNode, "Number", "paddingTop");
			setIfExists(label, "paddingleft", componentNode, "Number", "paddingLeft");
			setIfExists(label, "paddingRight", componentNode, "Number", "paddingRight");
			loadIcon(label, componentNode);
			applyTextFormat(componentNode, "format", label, "fontStyles");
			target.addChild(label);
			label.invalidate();
			return (label);
		}
		
		private static function renderNumericStepper(componentNode:XML, target:*):NumericStepper {
			var stepper:NumericStepper = new NumericStepper();
			setIfExists(stepper, "x", componentNode, "Number");
			setIfExists(stepper, "y", componentNode, "Number");
			setIfExists(stepper, "width", componentNode, "Number");
			setIfExists(stepper, "height", componentNode, "Number");						
			setIfExists(stepper, "minimum", componentNode, "Number");
			setIfExists(stepper, "maximum", componentNode, "Number");
			setIfExists(stepper, "step", componentNode, "Number");
			setIfExists(stepper, "value", componentNode, "Number");
			stepper.textInputFactory = function():TextInput {
				var returnInput:TextInput = new TextInput();
				applyTextFormat(componentNode, "format", returnInput, "fontStyles", false);
				applyTextFormat(componentNode, "disabledformat", returnInput, "disabledFontStyles", false);
				return (returnInput);				
			}
			loadIcon(stepper, componentNode);			
			target.addChild(stepper);
			stepper.invalidate();
			return (stepper);
		}
		
		private static function renderList(componentNode:XML, target:*):List {
			var list:List = new List();
			setIfExists(list, "x", componentNode, "Number");
			setIfExists(list, "y", componentNode, "Number");
			setIfExists(list, "width", componentNode, "Number");
			setIfExists(list, "height", componentNode, "Number");						
			loadIcon(list, componentNode);
			applyTextFormat(componentNode, "format", list, "fontStyles");
			target.addChild(list);
			list.invalidate();
			return (list);
		}
		
		private static function renderPickerList(componentNode:XML, target:*):PickerList {
			var list:PickerList = new PickerList();
			var listFormat:starling.text.TextFormat = generateTextFormat(componentNode, "listformat");			
			var selectedFormat:starling.text.TextFormat = generateTextFormat(componentNode, "selectedformat");			
			var buttonFormat:starling.text.TextFormat = generateTextFormat(componentNode, "buttonformat");
			var buttonDisabledFormat:starling.text.TextFormat = generateTextFormat(componentNode, "buttondisabledformat");
			if (buttonFormat!=null) {
				list.buttonFactory = function():Button {
					var button:Button = new Button();
					button.defaultLabelProperties = buttonFormat;
					button.fontStyles = buttonFormat;
					button.disabledFontStyles = buttonDisabledFormat;					
					return button;
				};
			}
			if (listFormat!=null) {
				list.listFactory = function():List {
					var list:List = new List(); //List or SpinnerList
					list.itemRendererFactory = function():IListItemRenderer {
						var itemRenderer:DefaultListItemRenderer = new DefaultListItemRenderer();
						itemRenderer.fontStyles = listFormat;
						itemRenderer.selectedFontStyles = selectedFormat;						
						return itemRenderer;
					};
					return list;
				};
			}
			list.listProperties.itemRendererFactory = function():IListItemRenderer {
				var renderer:DefaultListItemRenderer = new DefaultListItemRenderer();
				renderer.labelField = "text";
				renderer.iconSourceField = "thumbnail";
				renderer.fontStyles = listFormat;
				renderer.selectedFontStyles = selectedFormat;
				return renderer;
			};
			list.labelFunction = function(item:Object):String	{
				if (item == null) {
					return ("");
				}
				if ((item["labelText"] != undefined) && (item["labelText"] != null)) {
					return (item.labelText);
				} else {
					return (item.text);
				}
			};
			setIfExists(list, "x", componentNode, "Number");
			setIfExists(list, "y", componentNode, "Number");
			setIfExists(list, "width", componentNode, "Number");
			setIfExists(list, "height", componentNode, "Number");			
			setIfExists(list, "text", componentNode, "String");
			setIfExists(list, "prompt", componentNode, "String");
			setIfExists(list, "selectedindex", componentNode, "int", "selectedIndex");			
			target.addChild(list);
			list.invalidate();
			return (list);
		}
		
		private function createItemRenderer():IListItemRenderer {
			var itemRenderer:DefaultListItemRenderer = new DefaultListItemRenderer();
			itemRenderer.labelField = "text";
			return itemRenderer;
		}		
		
		private static function generateTextFormat(componentNode:XML, formatNodeName:String):starling.text.TextFormat {
			if (componentNode.child(formatNodeName).length() > 0) {
				var formatNode:XML = componentNode.child(formatNodeName)[0] as XML;				
				var sizeStr:String = getPropNode("size", formatNode );
				if (sizeStr != null) {
					var size:Number = Number(sizeStr);
				} else {
					size = 18;
				}
				var fontName:String = getPropNode("font", formatNode);				
				if (fontName == null) {
					fontName = "Abel";
				}
				var colorStr:String = getPropNode("color", formatNode);
				if (colorStr != null) {
					var color:uint = uint(colorStr);
				} else {
					color = 0xFFFFFF;
				}
				var boldStr:String = getPropNode("bold", formatNode);
				if (boldStr == "true") {
					var bold:Boolean = true;
				} else {
					bold = false;
				}
				var italicStr:String = getPropNode("italic", formatNode);
				if (italicStr == "true") {
					var italic:Boolean = true;
				} else {
					italic = false;
				}
				var underlineStr:String = getPropNode("underline", formatNode);
				if (underlineStr == "true") {
					var underline:Boolean = true;
				} else {
					underline = false;
				}				
				var align:String = getPropNode("align", formatNode);
				var hAlign:String = align;
				var vAlign:String = getPropNode("valign", formatNode);
				return (new starling.text.TextFormat(fontName, size, color, hAlign, vAlign));
			}
			return (null);
		}
		
		
		private static function applyTextFormat (componentNode:XML, formatNodeName:String, target:*, formatProperty:String = "textFormat", useFlashFormat:Boolean = false):void {
			var format:starling.text.TextFormat = generateTextFormat(componentNode, formatNodeName);
			if (useEmbededFonts) {
				try {
					target.embedFonts = true;
				} catch (err:*) {
				}
			}
			try {				
				if (useFlashFormat) {
					target[formatProperty] = new flash.text.TextFormat(format.font, format.size, format.color, format.bold, format.italic, format.underline, null, null, format.horizontalAlign);
				} else {					
					target[formatProperty] = format;
				}
			} catch (err:*) {
			}		
		}
		
		private static function getPropNode (propertyName:String, node:XML):String {
			try {
				if (node.child(propertyName).length() > 0) {
					return (node.child(propertyName)[0].toString());
				}
			} catch (err:*) {
			}
			return (null);
		}
		
		private static function setIfExists(target:*, propertyName:String, componentNode:XML, targetType:String, targetProperty:String = null):void {			
			var value:String = getPropNode(propertyName, componentNode);			
			if (targetProperty == null) {
				//allows for setting different property than found in XML definition
				targetProperty = propertyName;
			}
			if (value != null) {
				try {
					switch (targetType.toLowerCase()) {
						case "string": 
							target[targetProperty] = value; break;
						case "number": 
							target[targetProperty] = Number(value); break;
						case "int": 
							target[targetProperty] = int(value); break;
						case "uint": 
							target[targetProperty] = uint(value); break;
						case "xml": 
							target[targetProperty] = componentNode.child(propertyName)[0]; break;
						case "boolean": 						
							var boolStr:String = new String(value);
							boolStr = boolStr.toLowerCase();
							boolStr = boolStr.split(" ").join("");						
							switch (boolStr) {
								case "true" : target[targetProperty] = true; break;
								case "false" : target[targetProperty] = false; break;
								case "t" : target[targetProperty] = true; break;
								case "f" : target[targetProperty] = false; break;
								case "1" : target[targetProperty] = true; break;
								case "0" : target[targetProperty] = false; break;
								case "on" : target[targetProperty] = true; break;
								case "off" : target[targetProperty] = false; break;
								case "enable" : target[targetProperty] = true; break;
								case "disable" : target[targetProperty] = false; break;
								case "enabled" : target[targetProperty] = true; break;
								case "disabled" : target[targetProperty] = false; break;
								case "e" : target[targetProperty] = true; break;
								case "d" : target[targetProperty] = false; break;
								case "yes" : target[targetProperty] = true; break;
								case "no" : target[targetProperty] = false; break;
								case "y" : target[targetProperty] = true; break;
								case "n" : target[targetProperty] = false; break;
								case "+" : target[targetProperty] = true; break;
								case "-" : target[targetProperty] = false; break;
								case "okay" : target[targetProperty] = true; break;
								case "ok" : target[targetProperty] = true; break;
								case "checked" : target[targetProperty] = true; break;
								case "unchecked" : target[targetProperty] = false; break;
								case "selected" : target[targetProperty] = true; break;
								case "unchecked" : target[targetProperty] = false; break;
								default : target[targetProperty] = Boolean(value); break;
							}
						
					}
				} catch (err:*) {					
				}
			}
		}		
	}
}
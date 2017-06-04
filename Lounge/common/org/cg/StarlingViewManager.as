/**
* Builds component-based user interfaces from XML data. See the <views> node of the global settings XML data (settings.xml) for some examples.
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
	import flash.text.Font;
	import flash.text.TextFormat;
	import starling.text.TextFormat;
	
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
	
	dynamic public class StarlingViewManager {		
		
		/**
		* Embedded application fonts (paths are relative to location of ViewManager.as file).
		*/
		//Sample font embedding example:
		//[Embed(source = "/../../assets/fonts/Rubik-Regular.ttf", embedAsCFF = "false", fontName = "Rubik-Regular", mimeType = "application/x-font")]
		//public static const Rubik_Regular_TTF:Class;			
		//public static const Rubik_Regular_font:Font = new Rubik_Regular_TTF();
		
		public static var useEmbededFonts:Boolean = false; //should font embedding be used?		
		private static var _alertIcons:Vector.<Object> = new Vector.<Object>(); //objects contain "icon" (Image), and "src" (ImageLoader) properties
		
		/**
		 * Sets the active theme from the available, imported Starling Feathers themes. The theme must be set prior to activating Feathers.
		 * 
		 * @param	themeName The name of the theme, matching the imported class name, to set.
		 */
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
						DebugView.addText ("StarlingViewManager: Couldn't invoke initialize method on widget " + widgetRef);
						DebugView.addText(err.getStackTrace());
					}
					return (widgetRef);
					break;
				default: 
					return (renderComponents(viewSource.children(), loungeRef, loungeRef));
					break;
			}			
		}
		
		/**
		 * Removes any widgets, including children, specified in the rendered XML definition.
		 * 
		 * @param	viewSource The XML definition of the rendered view.	
		 */
		public static function removeWidgets(viewSource:XML):void {			
			var childNodes:XMLList = viewSource.children();			
			for (var count:int = 0; count < childNodes.length(); count++) {
				var currentNode:XML = childNodes[count] as XML;
				if (currentNode.children().length() > 0) {
					removeWidgets(currentNode);
				}
				if ((currentNode.attribute("class")[0] != undefined) && (currentNode.attribute("class")[0] != "undefined") && 
					(currentNode.attribute("class")[0] != "") && (currentNode.attribute("class")[0] != null)) {
					var className:String = String (currentNode.attribute("class")[0]);					
					var widgets:Vector.<IWidget> = Widget.getInstanceByClass(className);
					for (var count2:int = 0; count2 < widgets.length; count2++) {
						widgets[count2].destroy();
					}
				}
			}
		}
		
		/**
		 * Creates a generic Feathers Alert dialog and immediately adds it to the main display list.
		 * 
		 * @param	message The message to use to populate the Alert with.
		 * @param	title The title to use to populate the Alert with.
		 * @param	buttons A ListCollection instance containing an array of objects to use to populate the Alert with. If null the
		 * dialog wil be created with no buttons.
		 * @param	iconName The name of the settings-defined icon (see "preloadAlertIcons" method), to add to the Alert. If null no icon is added.
		 * @param	isModal True if the dialog Alert should be modal, false if it may be bypassed without closing.
		 * @param	isCentered True if the dialog should be centered in the main display area, false if it will be positioned manually.
		 * 
		 * @return A reference to the newly-created Alert instance, null if there was a problem creating it.
		 */
		public static function alert(message:String, title:String = null, buttons:ListCollection = null, iconName:String = null, 
					isModal:Boolean = true, isCentered:Boolean = true):Alert {						
			if (iconName != null) {
				var icon:ImageLoader;
				var iconPath:String = getAlertIconPath(iconName);
				if (iconPath != null) {
					for (var count:int = 0; count < _alertIcons.length; count++) {
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
		
		/**
		 * Renders widgets or Feathers components into a target display compoment using XML definition(s), usually part of the global
		 * settings data.
		 * 
		 * @param	componentList An XMLList of nodes containing individual component definitions.
		 * @param	target The target display list object into which to render the list of components. The target must be added to the stage display
		 * list prior to invoking this method.
		 * @param	loungeRef A reference to the main ILounge implementation, used by widgets and possibly other components.
		 * 
		 * @return An untyped vector array of the successfully rendered and initialized components.
		 */
		public static function renderComponents (componentList:XMLList, target:*, loungeRef:ILounge):* {
			var renderedComponents:Vector.<*> = new Vector.<*>();
			for (var count:int = 0; count < componentList.length(); count++) {
				var currentComponent:XML = componentList[count] as XML;
				var elementType:String = currentComponent.localName();				
				var componentRef:* = null;
				switch (elementType.toLowerCase()) {
					case "widget": componentRef = renderWidget(currentComponent, target, loungeRef); break;
					case "image": componentRef = renderImage(currentComponent, target); break;
					case "button": componentRef = renderButton(currentComponent, target); break;
					case "check": componentRef = renderCheck(currentComponent, target); break;
					case "radio": componentRef = renderRadio(currentComponent, target); break;
					case "text": componentRef = renderText(currentComponent, target); break;
					case "hline": componentRef = renderHLine(currentComponent, target); break;
					case "label": componentRef = renderText(currentComponent, target); break;
					case "togglebutton": componentRef = renderToggleButton(currentComponent, target); break;
					case "toggleswitch": componentRef = renderToggleSwitch(currentComponent, target); break;
					case "textinput": componentRef = renderTextInput(currentComponent, target); break;
					case "numericstepper": componentRef = renderNumericStepper(currentComponent, target); break;
					case "spinnerlist": componentRef = renderSpinnerList(currentComponent, target); break;
					case "list": componentRef = renderList(currentComponent, target); break;
					case "pickerlist": componentRef = renderPickerList(currentComponent, target); break;
					default:
						try {
							var valueStr:String = currentComponent.toString();
							//most of these values must be set in the class at instantiation time
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
								//if values not yet set try blind assignent fallbacks until one works
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
						DebugView.addText("StarlingViewManager: Property \"" + currentComponent.@instance+"\" either does not exist or is of the wrong type in target " + target);
						DebugView.addText("   Component = " + componentRef);
						DebugView.addText(err.getStackTrace());
					}
				}
				if (elementType.toLowerCase() == "widget") {
					try {
						componentRef.initialize();
					} catch (err:*) {
						DebugView.addText ("StarlingViewManager: Couldn't invoke initialize method on widget " + componentRef);
						DebugView.addText(err.getStackTrace());
					}
				}
			}
			return (renderedComponents);
		}
		
		/**
		 * Attempts to find a file path for a named icon definition in the global settings XML data.
		 * 
		 * @param	iconName The name of the icon for which to find a file path.
		 * 
		 * @return The file path found for the icon name, or null if no matching icon could be found.
		 */
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
		
		/**
		 * Preloads Feathers Alert dialog icons defined in the settings XML data.
		 */
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
		
		/**
		 * Event listener invoked whenever an Alert icon is completely loaded via the "preloadAlertIcons" method.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private static function onLoadAlertIcon(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.COMPLETE, onIconImageLoad);
			var iconImage:Image = new Image(Texture.fromData(eventObj.target));
			_alertIcons.push ({icon:iconImage, src:ImageLoader(eventObj.target).source});
		}
		
		/**
		 * Creates a component icon, as a ImageLoader instance, from an XML definition.
		 * 
		 * @param	target The Starling display object to add the icon to.
		 * @param	componentNode The XML node of the parent component or widget of the icon.
		 * @param	nodeName The name of the child node within 'componentNode' containing the icon definition.
		 * @param	targetProperty The name of the property within the 'target' to assign the new icon instance to. The target property
		 * must be an ImageLoader or generic type (*).
		 */
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
		
		/**
		 * Event listener invoked when an icon image is successfully loaded via the 'loadIcon' method.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private static function onIconImageLoad(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.COMPLETE, onIconImageLoad);	
			//take some other action if necessary
		}
		
		/**
		 * Creates a skin, as an ImageLoader instance, to apply to a Feathers component based on an XML definition.
		 * 
		 * @param	target The target Feathers component to apply the skin to.
		 * @param	componentNode The XML node defining the properties of parent or containing component.
		 * @param	nodeName The name of the child node of 'componentNode' defining the properties of the skin.
		 * @param	targetProperty The property within 'target' to assign the skin to.
		 */
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
		
		/**
		 * Event listener invoked when a new skin is loaded via the 'loadSkin' method.
		 * 
		 * @param	eventObj A standard Event object.
		 */
		private static function onSkinImageLoad(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.COMPLETE, onSkinImageLoad);	
			//take some other action if necessary
		}
		
		/**
		 * Generates a skinned Feathers Alert instance using skinning information found in the settings XML.
		 * 
		 * @return A skinned Feathers Alert instance or null if there was a problem creating one.
		 */
		private static function skinnedAlertBox():Alert {			
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
		
		/**
		 * Renders a sliding panel to act as a container for child widgets and components, and adds it to the main display list.
		 * 
		 * @param	panelData The panel XML definition, usually as defined in the global settings XML data.
		 * @param	loungeRef A reference to the main ILounge implementation instance to initialize the panel with.
		 * 
		 * @return A reference to the newly-created and added ISLidingPanel implementation instance, or null if there was a problem
		 * creating it.
		 */
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
		
		/**
		 * Renders a panel leaf, or external panel container, into which to render child widgets and components. The panel
		 * leaf is automatically initialized, appended to its parent panel, and added to the display list.
		 * 
		 * @param	leafNode XML node defining the panel leaf and its contained widgets and components.
		 * @param	loungeRef A reference to the main ILounge implementation instance with which to initialize the panel leaf with.
		 * 
		 * @return The newly created and appended IPanelLeaf implementation instance, or null if there was a problem creating it.
		 */
		private static function renderPanelLeaf (leafNode:XML, loungeRef:ILounge):IPanelLeaf {
			try {				
				var panelLeaf:IPanelLeaf = new PanelLeaf(loungeRef, leafNode);			
				StarlingContainer.instance.addChild(panelLeaf as Sprite);			
				renderComponents(leafNode.children(), panelLeaf, loungeRef);
				panelLeaf.initialize();
				return (panelLeaf);
			} catch (err:*) {
				DebugView.addText ("StarlingViewManager: Panel leaf class \""+leafNode.attribute("class")[0]+"\" can't be found in application memory. Has it been included in the StarlingViewManager class header definition?");
			}
			return (null);
		}
		
		/**
		 * Renders a widget, or functional component group, into a Starling display container from an XML definition. The widget is automatically
		 * added to the display list.
		 * 
		 * @param	widgetNode The XML node defining the widget and its child components to render.
		 * @param	target The target Starling display container into which to render the widget and its components.
		 * @param	loungeRef A reference to the main ILounge imlementation instance to initialize the widget with.
		 * 
		 * @return The newly created and added IWidget implementation instance or null if there was a problem creating it.
		 */
		private static function renderWidget(widgetNode:XML, target:*, loungeRef:ILounge):IWidget {
			if ((widgetNode.attribute("class")[0] != null) && (widgetNode.attribute("class")[0] != undefined) && (widgetNode.attribute("class")[0] != "")) {
				try {
					var widgetClass:Class = getDefinitionByName(widgetNode.attribute("class")[0]) as Class;
				} catch (err:*) {
					DebugView.addText ("StarlingViewManager: There was a problem finding the widget class \"" + widgetNode.attribute("class")[0] + "\".");
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
		
		/**
		 * Renders an image, as an ImageLoader instance, from an XML definition and adds it to the display list. The image is
		 * automaticallty added to the display list.
		 * 
		 * @param	componentNode The XML node containing the definition of the external image to render. Any valid image type
		 * supported by the Starling ImageLoader class may be used.
		 * @param	target The target Starling display object to add the new image to.
		 * 
		 * @return The newly created and added ImageLoader instance or null if there was a problem creating it.
		 */
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
		
		/**
		 * Renders a Feathers Button instance using XML data and adds it to the display list.
		 * 
		 * @param	componentNode The XML node containing the definition for the button's properties.
		 * @param	target The Starling display object to add the new button instance to.
		 * 
		 * @return The newly created and added Button instance, or null if there was a problem creating it.
		 */
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
		
		/**
		 * Renders a Feathers Check instance from XML data and adds it to the display list.
		 * 
		 * @param	componentNode The XML node containing the definition for the checkbox's properties.
		 * @param	target The Starling display object to add the new checkbox instance to.
		 * 
		 * @return The newly created and added Check instance, or null if there was a problem creating it.
		 */
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
		
		/**
		 * Renders a Feathers ToggleButton instance from XML data and adds it to the display list.
		 * 
		 * @param	componentNode The XML node containing the definition for the toggle button's properties.
		 * @param	target The Starling display object to add the new toggle button instance to.
		 * 
		 * @return The newly created and added ToggleButton instance, or null if there was a problem creating it.
		 */
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
		
		/**
		 * Renders a Feathers ToggleSwitch instance from XML data and adds it to the display list.
		 * 
		 * @param	componentNode The XML node containing the definition for the toggle switch's properties.
		 * @param	target The Starling display object to add the new toggle switch instance to.
		 * 
		 * @return The newly created and added ToggleSwitch instance, or null if there was a problem creating it.
		 */
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
		
		/**
		 * Renders a Feathers TextInput instance from XML data and adds it to the display list.
		 * 
		 * @param	componentNode The XML node containing the definition for the text input field's properties.
		 * @param	target The Starling display object to add the new text input field instance to.
		 * 
		 * @return The newly created and added TextInput instance, or null if there was a problem creating it.
		 */
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
		
		/**
		 * Renders a Feathers Radio instance from XML data and adds it to the display list.
		 * 
		 * @param	componentNode The XML node containing the definition for the text input field's properties.
		 * @param	target The Starling display object to add the new text input field instance to.
		 * 
		 * @return The newly created and added Radio instance, or null if there was a problem creating it.
		 */
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
		
		/**
		 * Renders a Feathers Label instance from XML data and adds it to the display list.
		 * 
		 * @param	componentNode The XML node containing the definition for the text label's properties.
		 * @param	target The Starling display object to add the new text label instance to.
		 * 
		 * @return The newly created and added Label instance, or null if there was a problem creating it.
		 */
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
		
		/**
		 * Renders a Feathers NumericStepper instance from XML data and adds it to the display list.
		 * 
		 * @param	componentNode The XML node containing the definition for the stepper's properties.
		 * @param	target The Starling display object to add the new numeric stepper instance to.
		 * 
		 * @return The newly created and added NumericStepper instance, or null if there was a problem creating it.
		 */
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
		
		/**
		 * Renders a Feathers SpinnerList instance from XML data and adds it to the display list.
		 * 
		 * @param	componentNode The XML node containing the definition for the spinner lists's properties.
		 * @param	target The Starling display object to add the new numeric spinner list instance to.
		 * 
		 * @return The newly created and added SpinnerList instance, or null if there was a problem creating it.
		 */
		private static function renderSpinnerList(componentNode:XML, target:*):SpinnerList {
			var spinnerList:SpinnerList = new SpinnerList();
			setIfExists(spinnerList, "x", componentNode, "Number");
			setIfExists(spinnerList, "y", componentNode, "Number");
			setIfExists(spinnerList, "width", componentNode, "Number");
			setIfExists(spinnerList, "height", componentNode, "Number");
			var listFormat:starling.text.TextFormat = generateTextFormat(componentNode, "format");
			spinnerList.itemRendererFactory = function():IListItemRenderer	{
				var itemRenderer:DefaultListItemRenderer = new DefaultListItemRenderer();
				itemRenderer.fontStyles = listFormat;
				itemRenderer.labelField = "text";
				itemRenderer.iconSourceField = "thumbnail";
				return itemRenderer;
			}						
			target.addChild(spinnerList);
			spinnerList.invalidate();
			return (spinnerList);
		}
		
		/**
		 * Renders a Feathers List instance from XML data and adds it to the display list.
		 * 
		 * @param	componentNode The XML node containing the definition for the item list's properties.
		 * @param	target The Starling display object to add the new item list instance to.
		 * 
		 * @return The newly created and added List instance, or null if there was a problem creating it.
		 */
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
		
		/**
		 * Renders a Feathers PickerList instance from XML data and adds it to the display list.
		 * 
		 * @param	componentNode The XML node containing the definition for the picker list's properties.
		 * @param	target The Starling display object to add the new picker list instance to.
		 * 
		 * @return The newly created and added PickerList instance, or null if there was a problem creating it.
		 */
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
		
		/**
		 * Renders a generated horizontal line or divider from XML data and adds it to the display list.
		 * 
		 * @param	componentNode The XML node containing the definition for the horizontal line's properties.
		 * @param	target The Starling display object to add the new horizontal line instance to.
		 * 
		 * @return The newly created and added horizontal line instance, or null if there was a problem creating it.
		 */
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
		
		/**
		 * Creates a default list item renderer instance for Feathers list item components.
		 * 
		 * @return A IListItemRenderer implementation instance as a DefaultListItemRenderer with the 'labelField' property set to "text".
		 */
		private function createItemRenderer():IListItemRenderer {
			var itemRenderer:DefaultListItemRenderer = new DefaultListItemRenderer();
			itemRenderer.labelField = "text";
			return itemRenderer;
		}		
		
		/**
		 * Creates a Starling TextFormat instance that may be applied to Feathers textual components from an XML definition.
		 * 
		 * @param	componentNode The parent component node within which the text format node appears.
		 * @param	formatNodeName The name of the 'componentNode' child node that contains the text format to parse and generate.
		 * 
		 * @return A new starling TextFormat object or null if there was a problem generating it.
		 */
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
		
		/**
		 * Applies an XML-defined text format to a target Feathers textual component.
		 * 
		 * @param	componentNode The parent component node containg the child text format definition.
		 * @param	formatNodeName The name of the child node of 'componentNode' containing the text format definition to apply to the 'target'.
		 * @param	target The target Feathers component to which to apply the defined text format.
		 * @param	formatProperty The name of the property of 'target' to apply the text format object to.
		 * @param	useFlashFormat If true the standard flash.text.TextFormat is applied to the component, otherwise a starling.text.TextFormat is applied.
		 */
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
		
		/**
		 * Returns the first found node's text data, excluding any surrounding XML, of a parent node.
		 * 
		 * @param	propertyName The first found child node name, or property, to access within 'node'.
		 * @param	node The parent node within which to find the 'propertyName' node.
		 * 
		 * @return The text contents of the first found child property node, or null if none can be found.
		 */
		private static function getPropNode (propertyName:String, node:XML):String {
			try {
				if (node.child(propertyName).length() > 0) {
					return (node.child(propertyName)[0].toString());
				}
			} catch (err:*) {
			}
			return (null);
		}
		
		/**
		 * Sets a specific property within an object from an XML definition, casting the data to a specific type.
		 * 
		 * @param	target The target object within which to set the property.
		 * @param	propertyName The name of the propery within 'target' to set.
		 * @param	componentNode The parent or containing node within which the 'propertyName' node exists.
		 * @param	targetType The data type of the 'targetProperty' property to cast the data to before assigning it.
		 * @param	targetProperty The property name (variable) within 'target' to assign the type-cast data to.
		 */
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
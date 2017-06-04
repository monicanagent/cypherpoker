package org.cg.widgets 
{
	
	import events.EthereumWeb3ClientEvent;
	import feathers.controls.Check;
	import feathers.data.XMLListListCollectionDataDescriptor;
	import flash.utils.setTimeout;
	import org.cg.events.EthereumEvent;
	import org.cg.events.LoungeEvent;
	import org.cg.interfaces.IPanelWidget;
	import org.cg.Lounge;
	import org.cg.SlidingPanel;
	import org.cg.DebugView;
	import org.cg.StarlingViewManager;
	import feathers.controls.TextInput;
	import feathers.controls.Button;
	import feathers.controls.Alert;
	import feathers.events.FeathersEventType;
	import starling.events.Event;
	import flash.geom.Point;
	import org.cg.GlobalSettings;
	import feathers.controls.Label;
	import feathers.controls.PickerList;
	import feathers.data.ListCollection;
	import net.kawa.tween.KTween;
	import net.kawa.tween.KTJob;	
	import net.kawa.tween.easing.Quad;
	import flash.utils.setTimeout;
	
	public class EthereumAccountWidget extends PanelWidget implements IPanelWidget {
		
		//UI components rendered by StarlingViewManager:
		public var accountPicker:PickerList;
		public var accountEdit:TextInput;
		public var passwordEdit:TextInput;
		public var cancelButton:Button;
		public var okButton:Button;
		public var createAccountButton:Button;
		public var newAccountButton:Button;
		public var deleteAccountButton:Button;
		public var updateAccountButton:Button;
		public var savePasswordInConfig:Check;
		public var accountBalance:Label;
		private var _passwordStartingLocation:Point;
		private var _okButtonStartingLocation:Point;
		private var _savePasswordStartingLocation:Point;		
		private var _createButtonStartingLocation:Point;
		private var _newAccountStartingPosition:Point;
		private var _updateAccountStartingPosition:Point;
		private var _deleteAccountStartingPosition:Point;
		private var _accounts:Vector.<XML> = new Vector.<XML>(); //references to accounts stored in global settings
		private var _accountPickerTween:KTJob;
		private var _accountEditTween:KTJob;
		private var _passwordEditTween:KTJob;
		private var _cancelButtonTween:KTJob;
		private var _savePasswordTween:KTJob;
		private var _createAccountButtonTween:KTJob;
		private var _newAccountButtonTween:KTJob;
		private var _deleteAccountButtonTween:KTJob;
		private var _updateAccountButtonTween:KTJob;
		private var _okButtonTween:KTJob;
		private var _editing:Boolean = false; //should account info just be updated or added when current process completes?
		private var _currentlyEditingAccount:String =  null; //the account currently being edited
		
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	loungeRef A reference to the main ILounge implementation instance.
		 * @param	panelRef The widget's parent panel or display object container.
		 * @param	widgetData The widget's configuration XML data, usually from the global settings data.
		 */
		public function EthereumAccountWidget(loungeRef:Lounge, panelRef:SlidingPanel, widgetData:XML) {
			DebugView.addText("EthereumAccount widget created.");
			super (loungeRef, panelRef,	widgetData)			
		}
		
		/**
		 * Initializes the widget after it's been added to the display list and all child components have been created.
		 */
		override public function initialize():void {
			DebugView.addText("EthereumAccountWidget initialize");
			lounge.addEventListener(LoungeEvent.NEW_ETHEREUM, this.onEthereumEnabled);			
			this._accounts = new Vector.<XML>();		
			this.accountPicker.addEventListener(Event.CHANGE, this.onPickerListUpdate);			
			accountEdit.text = GlobalSettings.getSettingData("accounts", "selected");
			passwordEdit.text = this.getPasswordFor(accountEdit.text);
			passwordEdit.visible = false;
			passwordEdit.alpha = 0;
			accountEdit.visible = false;
			this.okButton.alpha = 0;
			this.okButton.visible = false;
			this.cancelButton.visible = false;
			this.cancelButton.alpha = 0;
			this.savePasswordInConfig.visible = false;
			this.savePasswordInConfig.alpha = 0;
			this._passwordStartingLocation = new Point(passwordEdit.x, passwordEdit.y);
			this._okButtonStartingLocation = new Point(this.okButton.x, this.okButton.y);	
			try {
				this._createButtonStartingLocation = new Point(this.createAccountButton.x, this.createAccountButton.y);
				this._newAccountStartingPosition = new Point(this.newAccountButton.x, this.newAccountButton.y);
				this._updateAccountStartingPosition = new Point(this.updateAccountButton.x, this.updateAccountButton.y);
				this._deleteAccountStartingPosition = new Point(this.deleteAccountButton.x, this.deleteAccountButton.y);
			} catch (err:*) {
			}
			this._savePasswordStartingLocation = new Point(this.savePasswordInConfig.x, this.savePasswordInConfig.y);
			this.passwordEdit.x = this.accountEdit.x;
			this.passwordEdit.y = this.accountEdit.y;
			this.okButton.x = this.cancelButton.x;
			this.okButton.y = this.cancelButton.y;			
			this.savePasswordInConfig.y = 0;	
			if (this._accounts.length < 1) {
				this.deleteAccountButton.visible = false;
				this.deleteAccountButton.alpha = 0;
				this.deleteAccountButton.y = 0;
				this.updateAccountButton.visible = false;
				this.updateAccountButton.alpha = 0;
				this.updateAccountButton.y = 0;				
			}
			this.createAccountButton.addEventListener(Event.TRIGGERED, this.onCreateAccountClick);
			this.newAccountButton.addEventListener(Event.TRIGGERED, this.onNewAccountClick);
			this.updateAccountButton.addEventListener(Event.TRIGGERED, this.onUpdateAccountClick);
			this.deleteAccountButton.addEventListener(Event.TRIGGERED, this.onDeleteAccountClick);
			this.passwordEdit.addEventListener(Event.CHANGE, this.onPasswordEditUpdate);
			this.cancelButton.addEventListener(Event.TRIGGERED, this.onCancelClick);
			this.okButton.addEventListener(Event.TRIGGERED, this.onOkClick);				
			this.accountPicker.isEnabled = false;			
			this.hidePasswordEdit();
			this.hideAccountEdit();
			this.hideCreateAccountButton();
			this.hideNewAccountButton();
			this.hideUpdateAccountButton();
			this.hideDeleteAccountButton();
			this.hideOkButton();
			this.hideCancelButton();
			this.hideSavePaswordCheck();
			this.updateAccountBalance();
			super.initialize();
		}
		
		/**
		 * Populates the user interface with data from the currently active Ethereum instance and the client to which it's connected.
		 */
		public function populateFromEthereumClient():void {
			try {
				//try retrieving default account
				var account:String = lounge.ethereum.web3.eth.accounts[0];
			} catch (err:*) {
				return;
			}
			if (this.accountPicker.dataProvider != null) {
				var numItems:int = this.accountPicker.dataProvider.length;
			} else {
				numItems = 0;
			}
			var clientAccount:int = 0;			
			var accountObjects:Array = new Array();
			while ((account != null) && (account != "") && (account != "0x") && (account != "0x0")) {					
				var accountObj:Object = new Object();
				var addAccount:Boolean = true;
				if (this.accountPicker.dataProvider!=null) {
					numItems = this.accountPicker.dataProvider.length-1;
				} else {
					numItems++;
				}
				try {
					accountObj.type = "client";
					accountObj.address = account;
					accountObj.text = "["+String(numItems)+"]: "+accountObj.address; //for item in list
					accountObj.labelText = accountObj.text; //for item when selected (as button)					
					accountObj.settingsData = getAccountNodeFor(account, true);		
					addAccount = true;
				} catch (err:*) {
					addAccount = false;
				}
				try {
					accountObj.password = this._accounts[clientAccount].child("password")[0].toString();
				} catch (err:*) {
					accountObj.password = "";
				}
				if (addAccount) {					
					if (this.accountPicker.dataProvider != null) {
						this.accountPicker.dataProvider.addItem(accountObj);
					} else {
						accountObjects.push(accountObj);
					}
					this._accounts.push(accountObj.setttingsData);
				}
				clientAccount++;				
				account = lounge.ethereum.web3.eth.accounts[clientAccount];
			}
			if (accountObjects.length > 0) {				
				var accountsList:ListCollection = new ListCollection(accountObjects);			
				this.accountPicker.dataProvider = accountsList;	
				this.updateAccountButton.isEnabled = true;
				this.deleteAccountButton.isEnabled = true;
			} else {
				this.accountPicker.prompt = "no account found";	
				this.updateAccountButton.isEnabled = false;
				this.deleteAccountButton.isEnabled = false;
			}
			this.accountPicker.invalidate();
		}
		
		/**
		 * Updates the visibility of user interface components after a fade tween. Any component that has an alpha value of 0
		 * is made invisible in order to disable user interactions.
		 */
		public function updateUIVisibilityOnFade():void {
			if (this.accountEdit.alpha == 0) {
				this.accountEdit.visible = false;
			}
			if (this.passwordEdit.alpha == 0) {
				this.passwordEdit.visible = false;
			}
			if (this.cancelButton.alpha == 0) {
				this.cancelButton.visible = false;
			}
			if (this.savePasswordInConfig.alpha == 0) {
				this.savePasswordInConfig.visible = false;
			}
			if (this.newAccountButton.alpha == 0) {
				this.newAccountButton.visible = false;
			}
			if (this.deleteAccountButton.alpha == 0) {
				this.deleteAccountButton.visible = false;
			}
			if (this.updateAccountButton.alpha == 0) {
				this.updateAccountButton.visible = false;
			}
			if (this.accountPicker.alpha == 0) {
				this.accountPicker.visible = false;
				this.accountPicker.isEnabled = false;
			}
			if (this.accountBalance.alpha == 0) {
				this.accountBalance.visible = false;
			}
		}
		
		/**
		 * Callback function invoked when a new Ethereum account has been created. This method is typically invoked
		 * as a direct callback from the JavaScript client interface.
		 * 
		 * @param	err The error message/object from the new account creation operation.
		 * @param	result The success message/object from the new account creation operation.
		 */
		public function accountCreated(err:*, result:*):void {
			var newAccount:String = String(result);
			if (this.accountPicker.dataProvider != null) {
				var numAccounts:int = this.accountPicker.dataProvider.length + 1;
			} else {
				this.accountPicker.dataProvider = new ListCollection();
				numAccounts = 1;
			}
			var accountObj:Object = new Object();
			accountObj.type = "client";
			accountObj.address = newAccount;
			accountObj.password = this.passwordEdit.text;
			accountObj.text = String(numAccounts)+": "+newAccount; //for item in list
			accountObj.labelText = accountObj.text; //for item when selected (as button)
			accountObj.settingsData = getAccountNodeFor(newAccount, true);			
			if (this.savePasswordInConfig.isSelected) {
				accountObj.settingsData.child("password")[0].replace ("*", this.passwordEdit.text);
			}
			this.accountPicker.dataProvider.addItem(accountObj);
			this.accountPicker.selectedIndex = this.accountPicker.dataProvider.length - 1;
			this.updateAccountBalance();
			GlobalSettings.saveSettings();
			setTimeout(this.restoreUI, 500);				
		}
		
		/**
		 * Restores the user interface to its initial enabled state; for example, when it's been disabled during an
		 * account creation operation.
		 */
		public function restoreUI():void {
			this.accountPicker.isEnabled = true;
			this.hideCancelButton();
			this.hideOkButton();
			this.hideAccountEdit();
			this.hidePasswordEdit();			
			this.hideSavePaswordCheck();
			this.showAccountPicker();
			this.showCreateAccountButton();
			this.showNewAccountButton();
			if (this.accountPicker.dataProvider != null) {
				if (this.accountPicker.dataProvider.length > 0) {
					this.deleteAccountButton.isEnabled = true;
					this.updateAccountButton.isEnabled = true;
					this.showDeleteAccountButton();
					this.showUpdateAccountButton();	
				}
			}
		}
		
		/**
		 * Merges saved account information into the account picker from the global settings XML data.
		 */
		public function mergeFromGlobalSettings():void {
			var accountsList:Vector.<XML> = globalSettingsAccountsData;
			var accountObjects:Array = new Array();
			for (var count:int = 0; count < accountsList.length; count++) {
				var accountObj:Object = new Object();				
				var addAccount:Boolean = true;
				if (this.accountPicker.dataProvider!=null) {
					var numItems:int = this.accountPicker.dataProvider.length+1;
				} else {
					numItems = 1;
				}
				try {
					accountObj.type = "settings";
					accountObj.address = accountsList[count].child("address")[0].toString();					
					accountObj.text = String(numItems)+": "+accountObj.address; //for item in list
					accountObj.labelText = accountObj.text; //for item when selected (as button)										
					accountObj.settingsData = getSettingsDataForNode(accountsList[count]);					
					if (accountObj.settingsData != null) {
						//already populated, probably by "populateFromEthereumClient" -- just add a password if stored						
						accountObj.settingsData.child("password")[0].replace("*", accountsList[count].child("password")[0].toString());						
						addAccount = false;
					} else {						
						//doesn't yet exist						
						accountObj.settingsData = getAccountNodeFor(accountsList[count].child("address")[0].toString(), true);						
						addAccount = true;
					}
				} catch (err:*) {					
					addAccount = false;
				}
				try {
					accountObj.password = accountsList[count].child("password")[0].toString();
				} catch (err:*) {					
					accountObj.password = "";
				}
				if (addAccount) {					
					if (this.accountPicker.dataProvider != null) {
						this.accountPicker.dataProvider.addItem(accountObj);
					} else {						
						accountObjects.push(accountObj);
					}
					this._accounts.push(accountObj.settingsData);
				}
			}
			if (accountObjects.length > 0) {				
				var accountsProvider:ListCollection = new ListCollection(accountObjects);			
				this.accountPicker.dataProvider = accountsProvider;	
			}			
			this.accountPicker.invalidate();			
		}
		
		/**
		 * Event listener invoked when the account picker list has been updated (i.e. a new account has been selected).
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onPickerListUpdate(eventObj:Event):void {
			//reset text fields in order to reset icons, if supplied
			this.accountEdit.text = " ";
			this.accountEdit.text = "";
			this.passwordEdit.text = " ";
			this.passwordEdit.text = "";
			try {
				var account:String = this.accountPicker.selectedItem.settingsData.child("address")[0].toString();
				var password:String = this.accountPicker.selectedItem.settingsData.child("password")[0].toString();
			} catch (err:*) {
				account = "";
				password = "";
			}
			if (lounge.ethereum != null) {
				if ((password == "") && (account == lounge.ethereum.account)) {				
					password = lounge.ethereum.password;
				}
			}
			this.passwordEdit.text = password;
			if ((password == "") && (this.accountPicker.dataProvider.length > 0)) {
				this.showPasswordEdit();
				this.showCancelButton();
				this.showOkButton();
				this.showSavePaswordCheck();
				this.hideCreateAccountButton();
				this.hideNewAccountButton();
				this.hideDeleteAccountButton();
				this.hideUpdateAccountButton();				
			} else {
				if (this.lounge.ethereum!=null) {
					this.lounge.ethereum.account = account;
					this.lounge.ethereum.password = password;
				}
			}
			this.updateAccountBalance();
		}
		
		/**
		 * Updates the account balance field for the currently selected Ethereum account.
		 */
		private function updateAccountBalance():void {
			try {
				var account:String = this.accountPicker.selectedItem.settingsData.child("address")[0].toString();
				var balanceValueWei:Object = this.lounge.ethereum.client.lib.getBalance(account, "wei");
				var balanceValueEther:String = this.lounge.ethereum.client.lib.getBalance(account, "ether");
				this.accountBalance.text = "Balance: Ξ" + balanceValueEther;
			} catch (err:*) {
				this.accountBalance.text = "Balance: ";
			}
		}
		
		/**
		 * Event listener invoked whenever the account picker list is clicked on.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onPickerListClick(eventObj:Event):void {
			this.hideNewAccountButton();
			this.hideDeleteAccountButton();
			this.hideUpdateAccountButton();
		}		
		
		/**
		 * Shows / animates to visibility the "create account" button.
		 */
		private function showCreateAccountButton():void {
			if (this._createAccountButtonTween != null) {
				this._createAccountButtonTween.close();
				this._createAccountButtonTween = null;
			}	
			this.createAccountButton.visible = true;
			this.createAccountButton.isEnabled = true;
			this._createAccountButtonTween = KTween.to(this.createAccountButton, 0.7, {y:this._createButtonStartingLocation.y, alpha:1}, Quad.easeInOut);			
		}
		
		/**
		 * Hides / animates to invisibility the "create account" button.
		 */
		private function hideCreateAccountButton():void {
			if (this._createAccountButtonTween != null) {
				this._createAccountButtonTween.close();
				this._createAccountButtonTween = null;
			}			
			this._createAccountButtonTween = KTween.to(this.createAccountButton, 0.3, {y:0, alpha:0 }, Quad.easeInOut, this.updateUIVisibilityOnFade);			
		}
		
		/**
		 * Shows / animates to visibility the account picker.
		 */
		private function showAccountPicker():void {
			if (this._accountPickerTween != null) {
				this._accountPickerTween.close();
				this._accountPickerTween = null;
			}	
			this.accountPicker.visible = true;
			this.accountPicker.isEnabled = true;
			this.accountBalance.visible = true;
			this._accountPickerTween = KTween.to(this.accountPicker, 0.7, {alpha:1}, Quad.easeInOut);	
			KTween.to (this.accountBalance, 0.3, {alpha:1}, Quad.easeInOut);
		}
		
		/**
		 * Hides / animates to invisibility the account picker.
		 */
		private function hideAccountPicker():void {
			if (this._accountPickerTween != null) {
				this._accountPickerTween.close();
				this._accountPickerTween = null;
			}
			this._accountPickerTween = KTween.to(this.accountPicker, 0.3, {alpha:0 }, Quad.easeInOut, this.updateUIVisibilityOnFade);
			KTween.to (this.accountBalance, 0.3, {alpha:0}, Quad.easeInOut, this.updateUIVisibilityOnFade);
		}
		
		/**
		 * Shows / animates to visibility the "new account" button.
		 */
		private function showNewAccountButton():void {
			if (this._newAccountButtonTween != null) {
				this._newAccountButtonTween.close();
				this._newAccountButtonTween = null;
			}	
			this.newAccountButton.visible = true;
			if (this._newAccountStartingPosition == null) {
				_newAccountStartingPosition = new Point(this.newAccountButton.x, this.newAccountButton.y);
			}
			this._newAccountButtonTween = KTween.to(this.newAccountButton, 0.7, {y:this._newAccountStartingPosition.y, alpha:1}, Quad.easeInOut);			
		}
		
		/**
		 * Hides / animates to invisibility the "new account" button.
		 */
		private function hideNewAccountButton():void {
			if (this._newAccountButtonTween != null) {
				this._newAccountButtonTween.close();
				this._newAccountButtonTween = null;
			}			
			this._newAccountButtonTween = KTween.to(this.newAccountButton, 0.3, {y:0, alpha:0 }, Quad.easeInOut, this.updateUIVisibilityOnFade);			
		}
		
		/**
		 * Shows / animates to visibility the "update account" button.
		 */
		private function showUpdateAccountButton():void {
			if (this._updateAccountButtonTween != null) {
				this._updateAccountButtonTween.close();
				this._updateAccountButtonTween = null;
			}	
			this.updateAccountButton.visible = true;
			this._updateAccountButtonTween = KTween.to(this.updateAccountButton, 0.7, {y:this._updateAccountStartingPosition.y, alpha:1}, Quad.easeInOut);			
		}
		
		/**
		 * Hides / animates to invisibility the "update account" button.
		 */
		private function hideUpdateAccountButton():void {
			if (this._updateAccountButtonTween != null) {
				this._updateAccountButtonTween.close();
				this._updateAccountButtonTween = null;
			}			
			this._updateAccountButtonTween = KTween.to(this.updateAccountButton, 0.3, {y:0, alpha:0 }, Quad.easeInOut, this.updateUIVisibilityOnFade);			
		}
		
		/**
		 * Shows / animates to visibility the "delete account" button.
		 */
		private function showDeleteAccountButton():void {
			if (this._deleteAccountButtonTween != null) {
				this._deleteAccountButtonTween.close();
				this._deleteAccountButtonTween = null;
			}	
			this.deleteAccountButton.visible = true;
			this._deleteAccountButtonTween = KTween.to(this.deleteAccountButton, 0.7, {y:this._deleteAccountStartingPosition.y, alpha:1}, Quad.easeInOut);			
		}
		
		/**
		 * Hides / animates to invisibility the "delete account" button.
		 */
		private function hideDeleteAccountButton():void {
			if (this._deleteAccountButtonTween != null) {
				this._deleteAccountButtonTween.close();
				this._deleteAccountButtonTween = null;
			}			
			this._deleteAccountButtonTween = KTween.to(this.deleteAccountButton, 0.3, {y:0, alpha:0 }, Quad.easeInOut, this.updateUIVisibilityOnFade);			
		}
		
		/**
		 * Shows / animates to visibility the "save password" checkbox.
		 */
		private function showSavePaswordCheck():void {
			if (this._savePasswordTween != null) {
				this._savePasswordTween.close();
				this._savePasswordTween = null;
			}	
			this.savePasswordInConfig.visible = true;
			if (this._savePasswordStartingLocation == null) {
				this._savePasswordStartingLocation = new Point(this.savePasswordInConfig.x, this.savePasswordInConfig.y);
			}
			this._savePasswordTween = KTween.to(this.savePasswordInConfig, 0.7, {y:this._savePasswordStartingLocation.y, alpha:1}, Quad.easeInOut);			
		}
		
		/**
		 * Hides / animates to invisibility the "save password" checkbox.
		 */
		private function hideSavePaswordCheck():void {
			if (this._savePasswordTween != null) {
				this._savePasswordTween.close();
				this._savePasswordTween = null;
			}			
			this._savePasswordTween = KTween.to(this.savePasswordInConfig, 0.3, {y:0, alpha:0 }, Quad.easeInOut, this.updateUIVisibilityOnFade);
			var widget:IPanelWidget = this;			
		}
		
		/**
		 * Shows / animates to visibility the "cancel" button in the account edit interface.
		 */
		private function showCancelButton():void {
			if (this._cancelButtonTween != null) {
				this._cancelButtonTween.close();
				this._cancelButtonTween = null;
			}	
			this.cancelButton.visible = true;
			this._cancelButtonTween = KTween.to(this.cancelButton, 0.7, {alpha:1}, Quad.easeInOut);			
		}
		
		/**
		 * Hides / animates to invisibility the "cancel" button in the account edit interface.
		 */
		private function hideCancelButton():void {
			if (this._cancelButtonTween != null) {
				this._cancelButtonTween.close();
				this._cancelButtonTween = null;
			}			
			this._cancelButtonTween = KTween.to(this.cancelButton, 0.3, {alpha:0 }, Quad.easeInOut, this.updateUIVisibilityOnFade);			
		}
		
		/**
		 * Shows / animates to visibility the "OK" button in the account edit interface.
		 */
		private function showOkButton():void {
			if (this._okButtonTween != null) {
				this._okButtonTween.close();
				this._okButtonTween = null;
			}	
			this.okButton.visible = true;
			this._okButtonTween = KTween.to(this.okButton, 0.5, {x:this._okButtonStartingLocation.x, y:this._okButtonStartingLocation.y, alpha:1}, Quad.easeInOut);			
		}
		
		/**
		 * Hides / animates to invisibility the "OK" button in the account edit interface.
		 */
		private function hideOkButton():void {
			if (this._okButtonTween != null) {
				this._okButtonTween.close();
				this._okButtonTween = null;
			}			
			this._okButtonTween = KTween.to(this.okButton, 0.15, {x:cancelButton.x, y:cancelButton.y, alpha:0 }, Quad.easeInOut, this.updateUIVisibilityOnFade);			
		}
		
		/**
		 * Shows / animates to visibility the password input text field.
		 */
		private function showPasswordEdit():void {
			if (this._passwordEditTween != null) {
				this._passwordEditTween.close();
				this._passwordEditTween = null;
			}	
			this.passwordEdit.visible = true;
			KTween.to(this.accountBalance, 0.3, {alpha:0}, Quad.easeInOut, this.updateUIVisibilityOnFade);
			this._passwordEditTween = KTween.to(this.passwordEdit, 0.5, { x:this._passwordStartingLocation.x, y:this._passwordStartingLocation.y, alpha:1 }, Quad.easeInOut);			
		}
		
		/**
		 * Hides / animates to invisibility the password input text field.
		 */
		private function hidePasswordEdit():void {
			if (this._passwordEditTween != null) {
				this._passwordEditTween.close();
				this._passwordEditTween = null;
			}
			this.accountBalance.visible = true;
			KTween.to(this.accountBalance, 0.3, {alpha:1}, Quad.easeInOut);
			this._passwordEditTween = KTween.to(this.passwordEdit, 0.3, { x:accountEdit.x, y: accountEdit.y, alpha:0 }, Quad.easeInOut, this.updateUIVisibilityOnFade);			
		}
		
		/**
		 * Shows / animates to visibility the account input text field.
		 */
		private function showAccountEdit():void {
			if (this._accountEditTween != null) {
				this._accountEditTween.close();
				this._accountEditTween = null;
			}	
			this.accountEdit.visible = true;
			this._accountEditTween = KTween.to(this.accountEdit, 0.5, {alpha:1 }, Quad.easeInOut);			
		}
		
		/**
		 * Hides / animates to invisibility the account input text field.
		 */
		private function hideAccountEdit():void {
			if (this._accountEditTween != null) {
				this._accountEditTween.close();
				this._accountEditTween = null;
			}			
			this._accountEditTween = KTween.to(this.accountEdit, 0.3, { alpha:0 }, Quad.easeInOut, this.updateUIVisibilityOnFade);			
		}
		
		/**
		 * Retrieve all stored account information from global settings.
		 * 
		 * @return A vector array of all saved XML account nodes from the global settings data.
		 */
		private function get globalSettingsAccountsData():Vector.<XML> {
			var returnAccounts:Vector.<XML> = new Vector.<XML>();
			var accountsNode:XML = GlobalSettings.getSettingsCategory("accounts");
			if (accountsNode == null) {
				return (returnAccounts);
			}
			var accountNodes:XMLList = accountsNode.children();
			for (var count:int = 0; count < accountNodes.length(); count++) {
				returnAccounts.push (accountNodes[count] as XML);
			}
			return (returnAccounts);
		}		
		
		/**
		 * Retrieves a saved password for an account from the global settings data.
		 * 
		 * @param	account The account for which to retrieve a saved password for.
		 * 
		 * @return The password saved for the accuont in the global settings data, or an empty string ("")
		 * if none could be found.
		 */
		private function getPasswordFor(account:String):String {
			if (account == null) {
				return ("");
			}
			for (var count:int = 0; count < this._accounts.length; count++) {
				var currentAccount:XML = this._accounts[count];
				try {
					if (currentAccount.child("account")[0].toString() == account) {
						return (currentAccount.child("password")[0].toString());
					}
				} catch (err:*) {
				}
			}
			return ("");
		}
		
		/**
		 * Retrieves the node for a saved Ethereum account from the global settings data, optionally creating and inserting 
		 * a new node if one doesn't exist.
		 * 
		 * @param	account The Ethereum account for which to retrieve the XML node.
		 * @param	createIfNotFound If true a new node is created and inserted into the global settings data if no
		 * matching account node is found, otherwise no node is created.
		 * 
		 * @return The XML node from the global settings data matching the specified 'account'. Null is returned if
		 * no matching node exists and 'createIfNotFound' is false.
		 */
		private function getAccountNodeFor(account:String, createIfNotFound:Boolean = true):XML {
			var accountNodes:XML = GlobalSettings.getSettingsCategory("accounts");
			for (var count:int = 0; count < accountNodes.children().length(); count++) {
				var currentNode:XML = accountNodes.children()[count] as XML;
				var address:String = currentNode.child("address")[0].toString();
				if (address == account) {
					return (currentNode);
				}
			}
			if (createIfNotFound) {
				var newNode:XML = new XML("<account><address>" + account + "</address><password/></account>");
				accountNodes.appendChild(newNode);
				return (newNode);
			} else {
				return (null);
			}
		}
		
		/**
		 * Retrieves the 'settingData' object of an account picker item for a specific account node.
		 * 
		 * @param	accountNode The account XML node for which to retrieve the 'settingData' object.
		 * 
		 * @return The 'settingData' object of the account picker item associated with the 'accountNode', or null
		 * if none can be found.
		 */
		private function getSettingsDataForNode(accountNode:XML):XML {
			for (var count:int = 0; count < this.accountPicker.dataProvider.length; count++) {
				var itemObj:Object = this.accountPicker.dataProvider.getItemAt(count);
				if (itemObj.settingsData == accountNode) {
					return (itemObj.settingsData);
				}
			}
			return (null);
		}
		
		/**
		 * Event listener invoked when the "cancel" button is clicked in the account edit interface.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onCancelClick(eventObj:Event):void {
			if (this.accountEdit.visible) {
				//cancelled on new or update account
				this.hideAccountEdit();
				this.hidePasswordEdit();
				this.hideCancelButton();
				this.hideOkButton();
				this.hideSavePaswordCheck();
				this.showNewAccountButton();
				this.showCreateAccountButton();
				if (this._accounts.length > 0) {
					this.showUpdateAccountButton();
					this.showDeleteAccountButton();
				}
				this.showAccountPicker();				
			} else {
				//cancelled on password entry
				this.hidePasswordEdit();
				this.hideCancelButton();
				this.hideOkButton();
				this.hideSavePaswordCheck();
				this.showNewAccountButton();
				this.showCreateAccountButton();
				if (this._accounts.length > 0) {
					this.showUpdateAccountButton();
					this.showDeleteAccountButton();
				}
			}
		}
		
		/**
		 * Event listener invoked when the "OK" button is clicked in the account edit interface.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onOkClick(eventObj:Event):void {
			if (this.accountEdit.visible == false) {				
				try {
					var account:String = this.accountPicker.selectedItem.settingsData.child("address")[0].toString();
					if (lounge.ethereum!=null) {
						lounge.ethereum.account = account;
						lounge.ethereum.password = this.passwordEdit.text;
					}
					var accountNode:XML = new XML(this.accountEdit.text);					
					XML(this.accountPicker.selectedItem.settingsData.child("account")[0]).setChildren(accountNode);					
					if (this.savePasswordInConfig.isSelected) {
						var passwordNode:XML = new XML(this.passwordEdit.text);
						this.accountPicker.selectedItem.settingsData.child("password")[0].setChildren(passwordNode);
					}					
					GlobalSettings.saveSettings();
				} catch (err:*) {	
					DebugView.addText(err);
				} finally {
					this.hideCancelButton();
					this.hideOkButton();
					this.hidePasswordEdit();
					this.hideSavePaswordCheck();
					this.showCreateAccountButton();
					this.showNewAccountButton();
					this.showDeleteAccountButton();
					this.showUpdateAccountButton();
				}				
			} else {
				if (this.accountEdit.text == "") {
					return;
				}
				if (this.accountEdit.isEnabled == false) {
					//creating a new account
					this.createNewAccount();
					return;
				}
				if (this.lounge.ethereum!=null) {
					lounge.ethereum.account = this.accountEdit.text;
					lounge.ethereum.password = this.passwordEdit.text;
				}
				if (this._currentlyEditingAccount == null) {
					accountNode = this.getAccountNodeFor(this.accountEdit.text);					
				} else {
					accountNode = this.getAccountNodeFor(this._currentlyEditingAccount, false);					
					if (accountNode == null) {						
						var err:Error = new Error("Currently editing account node is not available!");
						throw(err);
					}
				}
				var accountAddressNode:XML = new XML(this.accountEdit.text);
				XML(accountNode.child("address")[0]).setChildren(accountAddressNode);
				if (this.savePasswordInConfig.isSelected) {
					passwordNode = new XML(this.passwordEdit.text);
					XML(accountNode.child("password")[0]).setChildren(passwordNode);
				}				
				if (!this._editing) {
					this._accounts.push(accountNode);
				}
				GlobalSettings.saveSettings();				
				var numAccounts:int = this.accountPicker.dataProvider.length + 1;
				this.accountPicker.removeEventListener(Event.CHANGE, this.onPickerListUpdate);
				if (!this._editing) {					
					var accountObj:Object = new Object();
					accountObj.type = "settings";
					accountObj.address = this.accountEdit.text;
					accountObj.password = this.passwordEdit.text;
					accountObj.text = String(numAccounts)+": "+this.accountEdit.text; //for item in list
					accountObj.labelText = accountObj.text; //for item when selected (as button)
					accountObj.settingsData = accountNode;					
					this.accountPicker.dataProvider.addItem(accountObj);
					this.accountPicker.selectedIndex = this.accountPicker.dataProvider.length - 1;
				} else {					
					this.accountPicker.selectedItem.address = this.accountEdit.text;
					this.accountPicker.selectedItem.password = this.passwordEdit.text;
					if (this.accountPicker.selectedItem.type == "client") {
						this.accountPicker.selectedItem.text = "["+String(this.accountPicker.selectedIndex + 1) + "]: " + this.accountEdit.text;
					} else {
						this.accountPicker.selectedItem.text = String(this.accountPicker.selectedIndex + 1) + ": " + this.accountEdit.text;
					}
					this.accountPicker.selectedItem.labelText = this.accountPicker.selectedItem.text;
					this.accountPicker.dataProvider.updateItemAt(this.accountPicker.selectedIndex);
				}
				this.accountPicker.invalidate();
				this.accountPicker.addEventListener(Event.CHANGE, this.onPickerListUpdate);
				GlobalSettings.saveSettings();
				this.hideCancelButton();
				this.hideOkButton();
				this.hidePasswordEdit();
				this.hideSavePaswordCheck();
				this.hideAccountEdit();
				this.showAccountPicker();
				this.showNewAccountButton();
				this.showCreateAccountButton();
				if (this.accountPicker.dataProvider.length > 0) {
					this.showDeleteAccountButton();
					this.showUpdateAccountButton();
				}
			}
			this._currentlyEditingAccount = null;
			this._editing = false;
			lounge.ethereum.unlockAccount(this.accountPicker.selectedItem.address, this.accountPicker.selectedItem.password);
		}
		
		/**
		 * Creates a new account using the password entered into the password input text field via the main Ethereum instance.
		 */
		private function createNewAccount():void {
			if (this.passwordEdit.text.split(" ").join("") == "") {
				return;
			}
			var password:String = this.passwordEdit.text;
			this.passwordEdit.isEnabled = false;
			var newAccount:String = lounge.ethereum.web3.personal.newAccount(password, this.accountCreated);			
		}		
		
		/**
		 * Event listener invoked when the "new account" button is clicked.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onNewAccountClick(eventObj:Event):void {
			this.accountEdit.text = " ";
			this.accountEdit.text = "";
			this.accountEdit.isEnabled = true;
			//the following resets the icon position on the TextInput components (otherwise they begin shifted)
			this.passwordEdit.text = " ";
			this.passwordEdit.text = "";
			this.passwordEdit.isEnabled = true;
			this.showPasswordEdit();
			this.showAccountEdit();
			this.showOkButton();
			this.showCancelButton();
			this.showSavePaswordCheck();
			this.hideDeleteAccountButton();
			this.hideUpdateAccountButton();
			this.hideNewAccountButton();
			this.hideCreateAccountButton();
			this.hideAccountPicker();
		}
		
		/**
		 * Event listener invoked when the "create account" button is clicked.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onCreateAccountClick(eventObj:Event):void {
			this.accountEdit.text = " ";
			this.accountEdit.text = "(TO BE GENERATED)";
			this.accountEdit.isEnabled = false;
			this.passwordEdit.text = " ";
			this.passwordEdit.text = "";
			this.hideCreateAccountButton();
			this.hideNewAccountButton();
			this.hideDeleteAccountButton();
			this.hideUpdateAccountButton();
			this.hideAccountPicker();
			this.showCancelButton();
			this.showOkButton();
			this.showSavePaswordCheck();
			this.showAccountEdit();
			this.showPasswordEdit();			
		}
		
		/**
		 * Event listener invoked when the "delete account" button is clicked. An Alert dialog is displayed to confirm the deletion.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onDeleteAccountClick(eventObj:Event):void {
			var alert:Alert = StarlingViewManager.alert("Are you sure you want to delete " + this.accountPicker.selectedItem.address + "?", "Are you sure?", new ListCollection([{label:"YES", doDelete:true}, {label:"NO", doDelete:false}]), null, true, true);
			alert.addEventListener(Event.CLOSE, this.onDeleteAlertClose);
			this.hideNewAccountButton();
			this.hideDeleteAccountButton();
			this.hideUpdateAccountButton();
			this.hideCreateAccountButton();
		}
		
		/**
		 * Event listener invoked when the delete account confirmation Alert dialog is closed. If the deletion is confirmed the account
		 * node is removed from the global settings data and the accuont is cleared from the account picker.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onDeleteAlertClose(eventObj:Event):void {
			if (eventObj.data.doDelete) {				
				this.accountPicker.removeEventListener(Event.CHANGE, this.onPickerListUpdate);				
				//re-number all following items since current one is about to be removed
				for (count = (this.accountPicker.selectedIndex+1); count <= this.accountPicker.dataProvider.length; count++) {
					var dataItem:Object = this.accountPicker.dataProvider.getItemAt(count - 1);	
					if (dataItem.type == "client") {
						dataItem.text = "["+String(count - 1) + "]: " + dataItem.address;
					} else {
						dataItem.text = String(count - 1) + ": " + dataItem.address;
					}
					dataItem.labelText = dataItem.text;
				}
				for (var count:int = 0; count < this._accounts.length; count++) {
					try {
						if (this._accounts[count].child("address")[0].toString() == this.accountPicker.selectedItem.address) {
							delete getAccountNodeFor(this.accountPicker.selectedItem.settingsData.address, false);
							var accountNodes:XMLList = GlobalSettings.data.child("accounts")[0].children();
							try {
								for (var count2:int = 0; count2 < accountNodes.length(); count2++) {						
									var currentNode:XML = accountNodes[count2];							
									if (currentNode.child("address")[0].toString() == this.accountPicker.selectedItem.address) {
										delete GlobalSettings.data.child("accounts")[0].children()[count2];								
									}
								}
							} catch (err:*) {								
							}
							this._accounts.splice(count, 1);
							break;
						}
					} catch (err:*) {						
					}
				}
				this.accountPicker.dataProvider.removeItemAt(this.accountPicker.selectedIndex);	
				this.accountPicker.invalidate();
				this.accountPicker.selectedIndex = 0;
				this.accountPicker.addEventListener(Event.CHANGE, this.onPickerListUpdate);
			}
			this.showNewAccountButton();
			this.showCreateAccountButton();
			if (this.accountPicker.dataProvider.length > 0) {
				this.showDeleteAccountButton();
				this.showUpdateAccountButton();
			} else {
				this.accountPicker.selectedIndex = -1;
			}
			GlobalSettings.saveSettings();
		}
		
		/**
		 * Event listener invoked when the "update account" button is clicked.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onUpdateAccountClick(eventObj:Event):void {
			this.accountEdit.text = this.accountPicker.selectedItem.settingsData.child("address")[0].toString();
			//the following resets the icon position on the TextInput components (otherwise they begin shifted)
			this.passwordEdit.text = " ";
			this.passwordEdit.text = "";
			this.accountEdit.isEnabled = true;
			this.passwordEdit.isEnabled = true;
			if (this.lounge.ethereum!=null) {
				if (this.accountEdit.text == lounge.ethereum.account) {
					this.passwordEdit.text = lounge.ethereum.password;
				} else {
					this.passwordEdit.text = this.accountPicker.selectedItem.settingsData.child("password")[0].toString();
				}
			} else {
				this.passwordEdit.text = this.accountPicker.selectedItem.settingsData.child("password")[0].toString();
			}
			this._currentlyEditingAccount = this.accountEdit.text;
			this._editing = true;
			this.showOkButton();
			this.showCancelButton();
			this.showSavePaswordCheck();
			this.showAccountEdit();
			this.showPasswordEdit();
			this.hideCreateAccountButton();
			this.hideNewAccountButton();
			this.hideDeleteAccountButton();
			this.hideUpdateAccountButton();
			this.hideAccountPicker();
		}
		
		/**
		 * Event listener invoked whenever the password edit input text field is updated.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onPasswordEditUpdate(eventObj:Event):void {
		}
		
		/**
		 * Event listener dispatched from the main Ethereum instance, invoked when it's been disabled / become unavailable.
		 * 
		 * @param	eventObj An EthereumEvent object.
		 */
		private function onEthereumDisabled(eventObj:EthereumEvent):void {
			eventObj.target.removeEventListener(EthereumEvent.DESTROY, this.onEthereumDisabled);
			this.hideOkButton();
			this.hideCancelButton();
			this.hideSavePaswordCheck();
			this.hideAccountEdit();
			this.hidePasswordEdit();
			this.hideCreateAccountButton();
			this.hideNewAccountButton();
			this.hideDeleteAccountButton();
			this.hideUpdateAccountButton();
			this.accountPicker.isEnabled = false;
			this.updateAccountBalance();
			this.lounge.ethereum.account = null;
			this.lounge.ethereum.password = null;
		}
		
		/**
		 * Event listener invoked when the main Ethereum instance has been enabled / become available. This event
		 * is dispatched from the main lounge instance since it's responsible for managing Ethereum instances.
		 * 
		 * @param	eventObj A LoungeEvent object.
		 */
		private function onEthereumEnabled(eventObj:LoungeEvent):void {
			this.lounge.ethereum.addEventListener(EthereumEvent.DESTROY, this.onEthereumDisabled);			
			this.accountPicker.removeEventListener(Event.CHANGE, this.onPickerListUpdate);	
			if (this.accountPicker.dataProvider != null) {				
				this.accountPicker.dataProvider.removeAll();
			}
			this.accountPicker.dataProvider = null;
			this.populateFromEthereumClient(); //do first!
			this.mergeFromGlobalSettings();
			this.showCreateAccountButton();
			this.showNewAccountButton();
			if (this.accountPicker.dataProvider == null) {
				this.accountPicker.dataProvider = new ListCollection();
			}
			if (this.accountPicker.dataProvider.length > 0) {
				this.showUpdateAccountButton();
				this.showDeleteAccountButton();
			}
			this.accountPicker.isEnabled = true;
			this.accountPicker.addEventListener(Event.CHANGE, this.onPickerListUpdate);	
			if (this.accountPicker.selectedItem != null) {
				this.lounge.ethereum.account = this.accountPicker.selectedItem.address;
				this.lounge.ethereum.password = this.accountPicker.selectedItem.password;
			}
			this.updateAccountBalance();
		}		
	}
}
/**
* Manages and tracks Ethereum mining activity.
* 
* This implementation uses a simple delay timer to establish the leader/dealer role.
*
* (C)opyright 2014 to 2017
*
* This source code is protected by copyright and distributed under license.
* Please see the root LICENSE file for terms and conditions.
*
*/

package org.cg.widgets {
	
	import feathers.controls.ImageLoader;
	import feathers.controls.Label;
	import feathers.controls.ToggleSwitch;
	import org.cg.events.EthereumEvent;
	import org.cg.interfaces.ILounge;
	import org.cg.interfaces.IWidget;
	import org.cg.interfaces.IPanelWidget;
	import org.cg.SlidingPanel;
	import feathers.controls.NumericStepper;
	import starling.display.Image;
	import org.cg.events.LoungeEvent;
	import starling.events.Event;
	import feathers.controls.ToggleButton;
	import org.cg.StarlingViewManager;
	import feathers.controls.Alert;
	import feathers.data.ListCollection;
	import flash.utils.Timer;
	import flash.events.TimerEvent;
	import org.cg.DebugView;
	
	public class EthereumMiningControlWidget extends PanelWidget implements IPanelWidget {
		
		private static const _hashRateSampleTime:Number = 6000; //hash rate sample timer when mining
		private var _sampleTimer:Timer; //timer used to sample the mining hashrate when mining is enabled
		//UI components rendered by StarlingViewManager:
		public var toggle:ToggleSwitch;
		public var miningActiveIcon:ImageLoader;
		public var miningStartingIcon:ImageLoader;
		public var miningStoppedIcon:ImageLoader;
		public var numThreadsStepper:NumericStepper;
		public var hashrateLabel:Label;
		public var coinbaseLabel:Label;		
		
		/**
		 * Creates a new instance.
		 * 
		 * @param	loungeRef A reference to the main ILounge implementation instance.
		 * @param	panelRef The widget's parent panel or display object container.
		 * @param	widgetData The widget's configuration XML data, usually from the global settings data.
		 */
		public function EthereumMiningControlWidget(loungeRef:ILounge, panelRef:SlidingPanel, widgetData:XML) {
			DebugView.addText ("EthereumMiningControlWidget created");
			super(loungeRef, panelRef, widgetData);
		}
		
		/**
		 * Initializes the widget after it's been added to the display list and all child components have been created.
		 */
		override public function initialize():void {
			DebugView.addText ("EthereumMiningControlWidget.initalize");
			lounge.addEventListener(LoungeEvent.NEW_ETHEREUM, this.onEthereumEnable);
			if (lounge.ethereum == null) {
				this.toggle.isEnabled = false;
				this.numThreadsStepper.isEnabled = false;
			}
			this.toggle.addEventListener(Event.CHANGE, this.onMiningToggle);
			this.numThreadsStepper.addEventListener(Event.CHANGE, this.onNumThreadsChange);
			this.miningActiveIcon.visible = false;
			this.miningStartingIcon.visible = false;
			if (lounge.ethereum != null) {
				if (lounge.ethereum.web3.eth.mining) {
					this.onStartMining(null);
				}
			}
		}
		
		/**
		 * Event listener invoked when the mining enable toggle switch is clicked. When activated, mining is started with the
		 * specified number of threads. If Etherem isn't enabled an Alert is displayed allowing the user to enable it.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onMiningToggle(eventObj:Event):void {
			if (this._sampleTimer != null) {
				this._sampleTimer.stop();
				this._sampleTimer.removeEventListener(TimerEvent.TIMER, this.onSampleTimerTick);
			}			
			if (this.toggle.isSelected) {
				if (lounge.ethereum == null) {
					this.toggle.removeEventListener(Event.CHANGE, this.onMiningToggle);
					this.toggle.isSelected = false;
					var alert:Alert=StarlingViewManager.alert("Ethereum integration must be enabled for mining. Would you like to enable it now?", "Ethereum not available", new ListCollection([{label:"YES", enableEthereum:true}, {label:"NO", enableEthereum:false}]), null, true, true);
					alert.addEventListener(Event.CLOSE, this.onNoEthereumAlertClose);
					this.toggle.addEventListener(Event.CHANGE, this.onMiningToggle);
					return;
				}
				lounge.ethereum.startMining(this.numThreadsStepper.value);
			} else {
				lounge.ethereum.stopMining();
			}
		}
		
		/**
		 * Event listener invoked by the main Ethereum instance when mining has been enabled / started. The hash rate is sampled
		 * every '_hashRateSampleTime' milliseconds until stopped.
		 * 
		 * @param	eventObj An EthereumEvent object.
		 */
		private function onStartMining(eventObj:EthereumEvent):void {
			this.miningStoppedIcon.visible = false;
			this.miningStartingIcon.visible = false;
			this.miningActiveIcon.visible = true;
			this.toggle.isSelected = true;
			this.toggle.invalidate();
			this.numThreadsStepper.isEnabled = false;
			this.coinbaseLabel.text = String(lounge.ethereum.web3.eth.coinbase);
			this._sampleTimer = new Timer(_hashRateSampleTime);
			this._sampleTimer.addEventListener(TimerEvent.TIMER, this.onSampleTimerTick);
			this._sampleTimer.start();
			this.onSampleTimerTick(null); //take first sample right away
		}
		
		/**
		 * Event listener that stops the hash rate sample timer and resets the interface to its "off" position. The event is dispatched
		 * from the main Ethereum instance so that this state may be detected whenever any part of the application stops the miner.
		 * 
		 * @param	eventObj An EthereumEvent object.
		 */
		private function onStopMining(eventObj:EthereumEvent):void {
			this.hashrateLabel.text = "0 H/s";
			this.toggle.isSelected = false;
			this.toggle.invalidate();
			this.miningStoppedIcon.visible = true;
			this.miningStartingIcon.visible = false;
			this.miningActiveIcon.visible = false;
			this.numThreadsStepper.isEnabled = true;
		}
		
		/**
		 * Event listener invoked on every timer tick of the hash rate sample timer. The interface is updated with the currently
		 * calculated hash rate.
		 * 
		 * @param	eventObj A TimerEvent object.
		 */
		private function onSampleTimerTick(eventObj:TimerEvent):void {		
			try {
				this.hashrateLabel.text = String(lounge.ethereum.web3.eth.hashrate) + " H/s";
			} catch (err:*) {
				this.hashrateLabel.text = "0 H/s";
			}
		}
		
		/**
		 * Event listener invoked when the "Ethereum not enabled" Alert dialog is closed. If the user selects to enable Ethereum the EthereumEnableWidget
		 * instance is activated.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onNoEthereumAlertClose(eventObj:Event):void {
			eventObj.target.removeEventListener(Event.CLOSE, this.onNoEthereumAlertClose);
			if (eventObj.data.enableEthereum) {
				try {
					var ethereumWidget:IWidget = getInstanceByClass("org.cg.widgets.EthereumEnableWidget")[0];
					ethereumWidget.activate(true);
				} catch (err:*) {
					DebugView.addText ("EthereumMiningControlWidget: Couldn't find registered widget instance from class  \"org.cg.widgets.EthereumEnableWidget\"");
				}
			} else {
				
			}
		}
		
		/**
		 * Event listener invoked when the number of threads selected changes in the numeric stepper of the interface.
		 * 
		 * @param	eventObj An Event object.
		 */
		private function onNumThreadsChange(eventObj:Event):void {
			//stepper value is read when mining is started so nothing to do here
		}
		
		/**
		 * Event listener invoked when the main Ethereum instance has been enabled. This event is dispatched from the main lounge instance
		 * since its responsible for managing Ethereum instances.
		 * 
		 * @param	eventObj A LoungeEvent object.
		 */
		private function onEthereumEnable(eventObj:LoungeEvent):void {
			lounge.ethereum.addEventListener(EthereumEvent.DESTROY, this.onEthereumDisable);
			lounge.ethereum.addEventListener(EthereumEvent.MINING_START, this.onStartMining);
			lounge.ethereum.addEventListener(EthereumEvent.MINING_STOP, this.onStopMining);
			this.toggle.isEnabled = true;
			this.numThreadsStepper.isEnabled = true;			
			if (lounge.ethereum.web3.eth.mining) {
				this.onStartMining(null);
			}			
		}
		
		/**
		 * Event listener invoked when the main Ethereum instance has been disabled / become unavailable and the interface is updated
		 * to its "off" position. This event is dispatched directly from the Ethereum instance itself.
		 * 
		 * @param	eventObj An EthereumEvent object.
		 */
		private function onEthereumDisable(eventObj:EthereumEvent):void {
			lounge.ethereum.removeEventListener(EthereumEvent.DESTROY, this.onEthereumDisable);
			lounge.ethereum.removeEventListener(EthereumEvent.MINING_START, this.onStartMining);
			lounge.ethereum.removeEventListener(EthereumEvent.MINING_STOP, this.onStopMining);
			this.toggle.isSelected = false;
			this.toggle.isEnabled = false;
			this.numThreadsStepper.isEnabled = false;
			this.hashrateLabel.text = "0 H/s";
			this.coinbaseLabel.text = "";
		}
	}
}
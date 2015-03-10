package {
	import flash.text.TextFormat;
	import flash.system.Capabilities;
	import flash.utils.setTimeout;
	import flash.text.TextField;
	import flash.display.Sprite;
	import flash.events.Event;

	[SWF(width="320",height="480",frameRate="120",backgroundColor="#FFFFFF")]

	/**
	 * @author Yusuke Kawasaki
	 */
	public class Benchmark extends Sprite {
		private var canvas:BenchBase;
		private var textField:TextField;
		private var classList:Array;
		private var count:Number = 0;

		public function Benchmark():void {
			classList = [BenchKTween, BenchTweener, BenchTweenNano, BenchGTween, BenchBetweenAS3, BenchEazeTween];
			// classList = [BenchKTween, BenchBetweenAS3, BenchEazeTween];
			// classList = [BenchKTween];
			addEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
		}

		private function addedToStageHandler(event:Event):void {
			var textFormat:TextFormat = new TextFormat('_sans', 14);
			textField = new TextField();
			textField.width = stage.stageWidth;
			textField.height = stage.stageHeight;
			textField.defaultTextFormat = textFormat;
			textField.cacheAsBitmap = true;
			addChild(textField);

			runTween();
		}

		private function runTween():void {
			if (textField.textHeight > stage.stageHeight * 0.8) return;
			if (count % classList.length == 0) {
				for(var i:int = 0;i < classList.length;i++) {
					var x:int = Math.random() * classList.length;
					var swap:Class = classList[i];
					classList[i] = classList[x];
					classList[x] = swap;
				}
			}
			count++;
			
			var benchClass:Class = classList[count % classList.length];
			var name:String = benchClass + ' ';
			name = name.replace('class Bench', '');
			textField.appendText(name);

			canvas = new benchClass();
			canvas.addEventListener(Event.COMPLETE, doneTween, false, 0, true);
			addChild(canvas);
		}

		private function doneTween(event:Event):void {
			canvas.removeEventListener(Event.COMPLETE, doneTween);
			
			// show FPS
			textField.appendText(canvas.fps + ' fps\n');
			// the first tween may take time
			if (count == 1) {
				var debug:String = Capabilities.isDebugger ? ' Debugger' : '';
				textField.text = Capabilities.version + ' '+ Capabilities.playerType + debug + '\n';
			}
			
			// remove test sprite
			removeChild(canvas);
			canvas = null;
			
			setTimeout(runTween, 1000);
		}
	}
}

import flash.utils.getTimer;
import flash.display.PixelSnapping;
import flash.display.DisplayObject;
import flash.events.Event;
import flash.geom.Rectangle;
import flash.display.BitmapData;
import flash.display.Bitmap;
import flash.display.Sprite;

class BenchBase extends Sprite {
	private static const MAXOBJ:Number = 4000;
	protected static const SWIDTH:Number = 320;
	protected static const SHEIGHT:Number = 480;
	protected static const IWIDTH:Number = 4;
	protected static const IHEIGHT:Number = 4;
	protected static const MINSEC:Number = 2;
	protected static const MAXSEC:Number = 6;
	private static var COLORPAT:Array;
	private var count:Number = 0;
	private var startTime:Number;
	private var frame:Number = 0;
	protected var bmList:Array = [];
	public var fps:Number;
	private static var inited:Boolean = false;
	private static var yList0:Array = [];
	private static var yList1:Array = [];
	private static var secList:Array = [];

	public function BenchBase() {
		var i:int;
		var bmdList:Array = [];
		
		if (COLORPAT == null) {
			COLORPAT = new Array();
			for(i = 0;i < 360;i += 30) {
				var col:uint = 0xFF000000 | HSVtoRGB(i, 0.5, 1.0);
				COLORPAT.push(col);
			}
		}

		var rect:Rectangle = new Rectangle(0, 0, IWIDTH, IHEIGHT);
		for(i = 0;i < COLORPAT.length;i++) {
			var bmdata:BitmapData = new BitmapData(IWIDTH, IHEIGHT);
			bmdata.fillRect(rect, COLORPAT[i]);
			bmdList.push(bmdata);
		}
			
		for(i = 0;i < MAXOBJ;i++) {
			var bitmap:Bitmap = new Bitmap();
			bitmap.pixelSnapping = PixelSnapping.ALWAYS;
			bitmap.bitmapData = bmdList[i % bmdList.length];
			bmList.push(bitmap);
			addChild(bitmap);
		}
			
		addEventListener(Event.ENTER_FRAME, enterFrameHandler, false, 0, true);
		
		if (!inited) init();

		startTime = getTimer();
		for(i = 0;i < bmList.length;i++) {
			var mc:DisplayObject = bmList[i];
			mc.x = -IWIDTH;
			mc.y = yList0[i];
			runTween(mc, yList1[i], secList[i]);
		}
	}

	private function init():void {
		for(var i:int = 0;i < bmList.length;i++) {
			var y0:Number = Math.floor(Math.random() * SHEIGHT);
			var y1:Number = Math.floor(Math.random() * SHEIGHT);
			var secs:Number = Math.random() * (MAXSEC - MINSEC) + MINSEC;
			yList0.push(y0);
			yList1.push(y1);
			secList.push(secs);
		}
		inited = true;
	}

	protected function runTween(mc:DisplayObject, lastY:Number, secs:Number):void {
		// override this
	}

	private function enterFrameHandler(event:Event):void {
		frame++;
	}

	protected function countDone(dummy:* = null):void {
		if (!stage) return;
		dummy; // dummy
		count++;
		if (count < MAXOBJ) return;
		removeEventListener(Event.ENTER_FRAME, enterFrameHandler);
		var endTime:Number = getTimer();
		var spendTime:Number = (endTime - startTime) / 1000;
		fps = Math.round(frame / spendTime * 100) / 100;
		dispatchEvent(new Event(Event.COMPLETE));
	}

	private function HSVtoRGB(h:Number, s:Number, v:Number):uint {
		var rgb:uint = 0;
		var hi:uint = Math.floor(h / 60.0) % 6;
		var f:Number = h / 60.0 - hi;
		var vv:uint = Math.round(255 * v);
		var pp:uint = Math.round(255 * v * ( 1 - s ));
		var qq:uint = Math.round(255 * v * ( 1 - f * s ));
		var tt:uint = Math.round(255 * v * ( 1 - (1 - f) * s ));
		if ( vv > 255 ) vv = 255;
		if ( pp > 255 ) pp = 255;
		if ( qq > 255 ) qq = 255;
		if ( tt > 255 ) tt = 255;
		switch (hi) {
			case 0: 
				rgb = (vv << 16) | (tt << 8) | pp; 
				break;
			case 1: 
				rgb = (qq << 16) | (vv << 8) | pp; 
				break;
			case 2: 
				rgb = (pp << 16) | (vv << 8) | tt; 
				break;
			case 3: 
				rgb = (pp << 16) | (qq << 8) | vv; 
				break;
			case 4: 
				rgb = (tt << 16) | (pp << 8) | vv; 
				break;
			case 5: 
				rgb = (vv << 16) | (pp << 8) | qq; 
				break;
		}
		return rgb;
	}
}

class BenchKTween extends BenchBase {
	import net.kawa.tween.KTween;
	import net.kawa.tween.easing.Linear;
	protected override function runTween(mc:DisplayObject, lastY:Number, secs:Number):void {
		KTween.to(mc, secs, {x: SWIDTH, y: lastY}, Linear.easeOut, countDone);
	}
}

class BenchTweener extends BenchBase {
	import caurina.transitions.Tweener;
	protected override function runTween(mc:DisplayObject, lastY:Number, secs:Number):void {
		Tweener.addTween(mc, {x: SWIDTH, y:lastY, time: secs, transition: "linear", onComplete: countDone});
	}
}

class BenchTweenNano extends BenchBase {
	import com.greensock.TweenNano;
	import com.greensock.easing.Linear;
	protected override function runTween(mc:DisplayObject, lastY:Number, secs:Number):void {
		TweenNano.to(mc, secs, {x: SWIDTH, y:lastY, ease:Linear.easeNone, onComplete:countDone});
	}
}

class BenchGTween extends BenchBase {
	import com.gskinner.motion.GTween;
	import com.gskinner.motion.GTweener;
	import com.gskinner.motion.easing.Linear;
	protected override function runTween(mc:DisplayObject, lastY:Number, secs:Number):void {
		var tween:GTween = GTweener.to(mc, secs, {x: SWIDTH, y:lastY}, {ease:Linear.easeNone});
		tween.onComplete = countDone;
	}
}

class BenchBetweenAS3 extends BenchBase {
	import org.libspark.betweenas3.BetweenAS3;
	import org.libspark.betweenas3.events.TweenEvent;
	import org.libspark.betweenas3.tweens.IObjectTween;
	import org.libspark.betweenas3.easing.Linear;
	protected override function runTween(mc:DisplayObject, lastY:Number, secs:Number):void {
		var tween:IObjectTween = BetweenAS3.tween(mc, {x: SWIDTH, y:lastY}, null, secs, Linear.easeNone);
		tween.addEventListener(TweenEvent.COMPLETE, countDone);
		tween.play();
	}
}

class BenchEazeTween extends BenchBase {
	import aze.motion.eaze;
	import aze.motion.easing.Linear;
	protected override function runTween(mc:DisplayObject, lastY:Number, secs:Number):void {
		eaze(mc).to(secs, {x: SWIDTH, y:lastY}).easing(Linear.easeNone).onComplete(countDone);
	}
}

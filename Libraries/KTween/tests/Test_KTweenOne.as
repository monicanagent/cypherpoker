package {
	import flash.events.Event;
	import flash.display.Sprite;

	import net.kawa.tween.KTween;
	import net.kawa.tween.easing.*;

	[SWF(width="320",height="480",frameRate="30",backgroundColor="#FFFFFF")]

	/**
	 * @author Yusuke Kawasaki
	 */
	public class Test_KTweenOne extends Sprite {
		public function Test_KTweenOne():void {
			addEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
		}

		private function addedToStageHandler(event:Event):void {
			var easeIn:KTweenEaseTest = new KTweenEaseTest(); 
			var easeOut:KTweenEaseTest = new KTweenEaseTest(); 
			var easeInOut:KTweenEaseTest = new KTweenEaseTest(); 
			easeIn.y = 5;
			easeOut.y = 165;
			easeInOut.y = 325;
		
			addChild(easeIn);
			addChild(easeOut);
			addChild(easeInOut);

			var duration:Number = 2;

			KTween.to(easeIn, duration, {curX:320}, Linear.easeOut);
			KTween.to(easeOut, duration, {curX:320}, Linear.easeOut);
			KTween.to(easeInOut, duration, {curX:320}, Linear.easeOut);

			KTween.from(easeIn, duration, {curY:150}, Back.easeIn);
			KTween.from(easeOut, duration, {curY:150}, Back.easeOut);
			KTween.from(easeInOut, duration, {curY:150}, Back.easeInOut);
			
			easeIn.save();
			easeOut.save();
			easeInOut.save();
		}
	}
}

import flash.events.Event;
import flash.display.Sprite;

class KTweenEaseTest extends Sprite {
	public var prevX:Number = Number.NaN;
	public var prevY:Number = Number.NaN;
	public var curX:Number = 0;
	public var curY:Number = 0;

	public function KTweenEaseTest():void {
		graphics.lineStyle(1.0, 0x000000, 1, true);
		graphics.drawRect(0, 0, 320, 150);
		addEventListener(Event.ENTER_FRAME, update);
	}

	private function update(e:Event):void {
		graphics.lineStyle(2.0, 0x2020C0, 1.0);
		graphics.moveTo(prevX, prevY);
		graphics.lineTo(curX, curY);
		prevX = curX;
		prevY = curY;
	}

	public function save():void {
		prevX = curX;
		prevY = curY;
	}
}
	

package {
	import flash.text.TextFormat;
	import flash.text.TextField;
	import flash.events.MouseEvent;

	import net.kawa.tween.KTJob;

	import flash.events.Event;
	import flash.display.Sprite;

	import net.kawa.tween.KTween;
	import net.kawa.tween.easing.*;

	[SWF(width="320",height="480",frameRate="30",backgroundColor="#FFFFFF")]

	/**
	 * @author Yusuke Kawasaki
	 */
	public class Test_KTweenRepeat extends Sprite {
		private var pausing:Boolean = false;
		private var textField:TextField;

		public function Test_KTweenRepeat():void {
			addEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
		}

		private function addedToStageHandler(event:Event):void {
			textField = drawTextField();
			addChild(textField);

			var normal:Circle = new Circle();
			var repeat:Circle = new Circle();
			var yoyo:Circle = new Circle();
			normal.y = 100;
			repeat.y = 250;
			yoyo.y = 400;
			addChild(normal);
			addChild(repeat);
			addChild(yoyo);
			var duration:Number = 2;

			KTween.to(normal, duration, {x:320}, Quad.easeOut);
			KTween.to(repeat, duration, {x:320}, Quad.easeOut).repeat = true;
			var tyoyo:KTJob = KTween.to(yoyo, duration, {x:320}, Quad.easeOut);
			tyoyo.repeat = true;
			tyoyo.yoyo = true;
			
			stage.addEventListener(MouseEvent.CLICK, clickListener);
		}

		private function clickListener(event:MouseEvent):void {
			if (pausing) {
				textField.appendText('resume\n');
				KTween.resume();
			} else {
				textField.appendText('pause\n');
				KTween.pause();
			}
			pausing = !pausing;		
		}

		private function drawTextField():TextField {
			var sp:TextField = new TextField();
			sp.multiline = false;
			var textFormat:TextFormat = new TextFormat('_sans', 16, 0);
			sp.defaultTextFormat = textFormat;
			sp.width = stage.stageWidth;
			sp.height = stage.stageHeight;
			sp.text = 'KTween repeat/resume/pause test\n\n';
			return sp;
		}
	}
}

import flash.display.Sprite;

class Circle extends Sprite {
	public function Circle():void {
		graphics.beginFill(0xff0000);
		graphics.drawCircle(0, 0, 50);
		graphics.endFill();
	}
}
	

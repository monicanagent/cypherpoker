package {
	import flash.display.DisplayObject;
	import flash.events.MouseEvent;
	import flash.utils.setTimeout;
	import flash.text.TextFormat;
	import flash.text.TextField;
	import flash.events.Event;
	import flash.display.Sprite;

	import net.kawa.tween.KTJob;
	import net.kawa.tween.KTween;
	import net.kawa.tween.easing.*;

	[SWF(width="320",height="480",frameRate="30",backgroundColor="#FFFFFF")]

	/**
	 * @author Yusuke Kawasaki
	 */
	public class Test_KTweenCallback extends Sprite {
		private var duration:Number = 1.5;
		private var textField:TextField;
		private var finished:Boolean;
		private var plane:Sprite;

		public function Test_KTweenCallback():void {
			addEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
		}

		private function addedToStageHandler(event:Event):void {
			plane = new Sprite();
			addChild(plane);

			textField = drawTextField();
			plane.addChild(textField);
			
			addEventListener(MouseEvent.CLICK, clickHandler);
			
			setTimeout(run1, 1000);
			setTimeout(run2, 3000);
			setTimeout(run3, 5000);
			setTimeout(run4, 7000);
			setTimeout(done, 9000);
		}

		private function done():void {
			finished = true;
			var text:String = '\nclick to restart.\n';
			textField.appendText(text);
		}

		private function clickHandler(event:MouseEvent):void {
			if (finished) {
				removeChild(plane);
				finished = false;
				addedToStageHandler(event);
			} else {
				if (event.altKey) {
					KTween.abort();
				} else if (event.shiftKey) {
					KTween.complete();
				} else {
					KTween.cancel();
				}
			}
		}

		private function run1():void {
			var ball:Circle = new Circle();
			ball.y = 100;
			plane.addChild(ball);
			var job:KTJob = KTween.to(ball, duration, {x:320}, Quad.easeOut);
			setupEvent(job, 1);
		}

		private function run2():void {
			var ball:Circle = new Circle();
			ball.y = 200;
			plane.addChild(ball);
			var job:KTJob = KTween.from(ball, duration, {x:320}, Quad.easeOut);
			setupEvent(job, 2);
		}

		private function run3():void {
			var ball:Circle = new Circle();
			ball.y = 300;
			plane.addChild(ball);
			var job:KTJob = KTween.fromTo(ball, duration, {x:0}, {x:320}, Quad.easeOut);
			setupEvent(job, 3);
		}

		private function run4():void {
			var ball:Circle = new Circle();
			ball.y = 400;
			plane.addChild(ball);
			var job:KTJob = KTween.fromTo(ball, duration, {x:320}, {x:0}, Quad.easeOut);
			setupEvent(job, 4);
		}

		private function setupEvent(job:KTJob, id:int):void {
			job.onInit = callback; // these not work
			job.onInitParams = [id, 'onInit'];
			job.onComplete = callback;
			job.onCompleteParams = [id, 'onComplete'];
			job.onClose = callback;
			job.onCloseParams = [id, 'onClose'];
			job.onCancel = callback;
			job.onCancelParams = [id, 'onCancel'];
			
			job.addEventListener(Event.INIT, eventHandler);
			job.addEventListener(Event.COMPLETE, eventHandler);
			job.addEventListener(Event.CLOSE, eventHandler);
			job.addEventListener(Event.CANCEL, eventHandler);
		}

		private function eventHandler(event:Event):void {
			var job:KTJob = event.target as KTJob;
			var sprite:DisplayObject = job.target as DisplayObject;
			var text:String = 'event: ' + event.type + ' ' + sprite.x + '\n';
			textField.appendText(text);
		}

		private function callback(id:int = 0, type:String = null):void {
			var text:String = 'callback: ' + type + ' #' + id + '\n';
			textField.appendText(text);
		}

		private function drawTextField():TextField {
			var sp:TextField = new TextField();
			sp.multiline = false;
			var textFormat:TextFormat = new TextFormat('_sans', 16, 0);
			sp.defaultTextFormat = textFormat;
			sp.width = stage.stageWidth;
			sp.height = stage.stageHeight;
			sp.text = 'KTween callback/event test\n';
			sp.appendText('Click: cancel()\n');
			sp.appendText('Shift+Click: complete()\n');
			sp.appendText('Alt+Click: abort()\n\n');
			return sp;
		}
	}
}

import flash.display.Sprite;

class Circle extends Sprite {
	public function Circle():void {
		graphics.beginFill(0xff0000);
		graphics.drawCircle(0, 0, 40);
		graphics.endFill();
	}
}
	

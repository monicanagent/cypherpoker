package {
	import flash.utils.setTimeout;
	import flash.text.TextFormat;
	import flash.text.TextField;
	import flash.events.Event;
	import flash.display.Sprite;

	import net.kawa.tween.KTween;
	import net.kawa.tween.easing.Linear;

	[SWF(width="320",height="480",frameRate="30",backgroundColor="#FFFFFF")]

	/**
	 * @author Yusuke Kawasaki
	 */
	public class Test_KTweenTicks extends Sprite {
		private var tf:TextField;
		private var startTime:Number;
		private var objA:TestObject;
		private var objB:TestObject;
		private var objC:TestObject;

		public function Test_KTweenTicks():void {
			addEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
		}

		private function addedToStageHandler(event:Event):void {
			removeEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);

			tf = drawTextField();
			addChild(tf);

			objA = new TestObject('A');
			objB = new TestObject('B');
			objC = new TestObject('C');

			startTime = getTime();
			addEventListener(Event.EXIT_FRAME, exitFrameListener);
			
			setTimeout(runTestA, 100);
			setTimeout(runTestB, 300);
			setTimeout(runTestC, 500);
		}

		private function getTime():Number {
			var date:Date = new Date();
			return date.time;
		}

		private function exitFrameListener(event:Event):void {
			showStatus();
			if (objC.x >= 1) {
				removeEventListener(Event.EXIT_FRAME, exitFrameListener);
			}
		}

		private function showStatus():void {
			var numA:String = numFormat(objA.x);
			var numB:String = numFormat(objB.x);
			var numC:String = numFormat(objC.x);
			var str:String = getSec() + ' \tA:' + numA + ' \tB:' + numB  + ' \tC:' + numC + '\n';
			tf.appendText(str);
		}

		private function getSec():String {
			var time:Number = (getTime() - startTime) / 1000;
			var sec:String = numFormat(time);
			return sec;
		}

		private function numFormat(x:Number):String {
			if (isNaN(x)) return '-----';
			var str:String = String(Math.round(x * 1000) / 1000);
			if (str.search(/\./) < 0) str += '.';
			while (str.length < 5) str += '0';
			return str;
		}

		private function runTest(obj:TestObject):void {
			tf.appendText(getSec() + '\t' + obj.name + ':start\n');
			KTween.fromTo(obj, 1, {x:0}, {x:1}, Linear.easeOut, onClose).onCloseParams = [obj];
		}

		private function runTestA():void {
			runTest(objA);
		}

		private function runTestB():void {
			runTest(objB);
		}

		private function runTestC():void {
			runTest(objC);
		}

		private function onClose(obj:TestObject):void {
			tf.appendText(getSec() + '\t' + obj.name + ':done\n');
		}

		private function drawTextField():TextField {
			var sp:TextField = new TextField();
			sp.multiline = false;
			var textFormat:TextFormat = new TextFormat('_sans', 14, 0);
			sp.defaultTextFormat = textFormat;
			sp.width = stage.stageWidth;
			sp.height = stage.stageHeight;
			sp.text = '';
			return sp;
		}
	}
}

class TestObject {
	public var name:String;
	public var x:Number = Number.NaN;

	public function TestObject(name:String) {
		this.name = name;
	}
}
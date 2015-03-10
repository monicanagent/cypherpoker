package {
	import net.kawa.tween.util.KTUtil;

	import flash.text.TextFormat;
	import flash.text.TextField;

	import net.kawa.tween.util.KTColorTransformUtil;
	import net.kawa.tween.easing.Linear;
	import net.kawa.tween.KTJob;
	import net.kawa.tween.KTween;

	import flash.geom.ColorTransform;
	import flash.display.BitmapData;
	import flash.events.MouseEvent;
	import flash.geom.Matrix;
	import flash.display.GradientType;
	import flash.events.Event;
	import flash.display.Sprite;

	[SWF(width="320",height="480",frameRate="15",backgroundColor="#FFFFFF")]

	/**
	 * @author Yusuke Kawasaki
	 */
	public class Test_KTColorTransform extends Sprite {
		private var bmData:BitmapData;
		private var circles:Sprite;
		private var colorTrans:ColorTransform;
		private var textField:TextField;

		public function Test_KTColorTransform():void {
			addEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
		}

		private function addedToStageHandler(event:Event):void {
			var color7:Array = [0xFF0000, 0xFFFF00, 0x00FF00, 0x00FFFF, 0x0000FF, 0xFF00FF, 0xFF0000];
			var alpha7:Array = [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0];
			var ratio7:Array = [0, 42, 85, 128, 170, 214, 255];
			
			var colorBlack:Array = [0x000000, 0x000000];
			var colorWhite:Array = [0xFFFFFF, 0xFFFFFF];
			var alphaUp:Array = [1.0, 0.0];
			var alphaDown:Array = [0.0, 1.0];
			var ratio2:Array = [0, 255];
			
			var sx:Number = stage.stageWidth;
			var sy:Number = stage.stageHeight;
			var by:Number = sx / 8;
			
			var matrixH:Matrix = new Matrix();
			matrixH.createGradientBox(sx, by);
			var matrixV:Matrix = new Matrix();
			matrixV.createGradientBox(sx, by, Math.PI / 2);
			
			var bg:Sprite = drawBackground(sx, sy);
			addChild(bg);
			
			circles = drawCircles(sx, sy - by * 3);
			circles.y = by * 3;
			addChild(circles);
			
			var cbar:Sprite = new Sprite();
			cbar.graphics.beginGradientFill(GradientType.LINEAR, color7, alpha7, ratio7, matrixH);
			cbar.graphics.drawRect(0, 0, sx, by);
			cbar.graphics.endFill();
			addChild(cbar);
			
			var lback:Sprite = new Sprite();
			lback.graphics.beginGradientFill(GradientType.LINEAR, color7, alpha7, ratio7, matrixV);
			lback.graphics.drawRect(0, 0, sx, by);
			lback.graphics.endFill();
			lback.y = by;
			addChild(lback);
			
			var lbar:Sprite = new Sprite();
			lbar.graphics.beginGradientFill(GradientType.LINEAR, colorWhite, alphaDown, ratio2, matrixH);
			lbar.graphics.drawRect(0, 0, sx, by);
			lbar.graphics.endFill();
			lbar.y = by;
			addChild(lbar);
			
			var bback:Sprite = new Sprite();
			bback.graphics.beginGradientFill(GradientType.LINEAR, color7, alpha7, ratio7, matrixV);
			bback.graphics.drawRect(0, 0, sx, by);
			bback.graphics.endFill();
			bback.y = by * 2;
			addChild(bback);
						
			var dbar:Sprite = new Sprite();
			dbar.graphics.beginGradientFill(GradientType.LINEAR, colorBlack, alphaUp, ratio2, matrixH);
			dbar.graphics.drawRect(0, 0, sx, by);
			dbar.graphics.endFill();
			dbar.y = by * 2;
			addChild(dbar);
			
			bmData = new BitmapData(sx, sy);
			bmData.draw(this);

			colorTrans = circles.transform.colorTransform;
			
			textField = drawTextField(sx);
			textField.y = sy - textField.textHeight - 2;
			addChild(textField);
			
			cbar.addEventListener(MouseEvent.CLICK, changeColor);
			lbar.addEventListener(MouseEvent.CLICK, changeLightness);
			dbar.addEventListener(MouseEvent.CLICK, changeDarkness);
			addEventListener(MouseEvent.CLICK, resetBox);
		}

		private function drawTextField(sx:Number):TextField {
			var sp:TextField = new TextField();
			sp.multiline = false;
			var textFormat:TextFormat = new TextFormat('_sans', 16, 0);
			sp.defaultTextFormat = textFormat;
			sp.width = sx;
			sp.text = 'Click to start.';
			return sp;
		}

		private function drawBackground(sx:Number, sy:Number):Sprite {
			var sp:Sprite = new Sprite();
			sp.graphics.beginFill(0xCCCCCC);
			sp.graphics.drawRect(0, 0, sx, sy);
			sp.graphics.endFill();
			return sp;
		}

		private function drawCircles(sx:Number, sy:Number):Sprite {
			var cx:Number = sx / 2;
			var cy:Number = sy / 2;
			
			var sp:Sprite = new Sprite();
			sp.graphics.clear();
			sp.graphics.beginFill(0xFFFFFF);
			sp.graphics.drawCircle(cx, cy, sx / 3);
			sp.graphics.endFill();
			sp.graphics.lineStyle(sx / 10, 0x000000);
			sp.graphics.drawCircle(cx - sx / 4, cy - sx / 4, sx / 6);
			sp.graphics.lineStyle(sx / 10, 0xFF0000);
			sp.graphics.drawCircle(cx + sx / 4, cy - sx / 4, sx / 6);
			sp.graphics.lineStyle(sx / 10, 0x00FF00);
			sp.graphics.drawCircle(cx + sx / 4, cy + sx / 4, sx / 6);
			sp.graphics.lineStyle(sx / 10, 0x0000FF);
			sp.graphics.drawCircle(cx - sx / 4, cy + sx / 4, sx / 6);
			return sp;
		}

		private function changeDarkness(event:MouseEvent):void {
			event.stopPropagation();
			KTween.abort();
			var level:Number = 1 - event.localX / stage.stageWidth;
			var job:KTJob = KTween.to(colorTrans, 1, KTColorTransformUtil.darkness(level), Linear.easeOut);
			job.onChange = updateColorTransform;
			level = Math.round(level * 1000) / 1000;
			textField.text = 'KTColorTransformUtil.darkness(' + level + ')';
		}

		private function changeLightness(event:MouseEvent):void {
			event.stopPropagation();
			KTween.abort();
			var level:Number = event.localX / stage.stageWidth;
			var job:KTJob = KTween.to(colorTrans, 1, KTColorTransformUtil.lightness(level), Linear.easeOut);
			job.onChange = updateColorTransform;
			level = Math.round(level * 1000) / 1000;
			textField.text = 'KTColorTransformUtil.lightness(' + level + ')';
		}

		private function resetBox(event:Event):void {
			event.stopPropagation();
			KTween.abort();
			var job:KTJob = KTween.to(colorTrans, 1, KTUtil.resetColorTransform(), Linear.easeOut);
			job.onChange = updateColorTransform;
			textField.text = 'KTUtil.resetColorTransform()';
		}

		private function changeColor(event:MouseEvent):void {
			event.stopPropagation();
			KTween.abort();
			var color:uint = bmData.getPixel(event.localX, event.localY);
			var level:Number = event.shiftKey ? 1.0 : 0.5;
			var job:KTJob = KTween.to(colorTrans, 1, KTColorTransformUtil.color(color, level), Linear.easeOut);
			job.onChange = updateColorTransform;
			level = Math.round(level * 1000) / 1000;
			textField.text = 'KTColorTransformUtil.color(' + color.toString(16) + ', ' + level + ')';
		}

		private function updateColorTransform():void {
			circles.transform.colorTransform = colorTrans;
		}
	}
}

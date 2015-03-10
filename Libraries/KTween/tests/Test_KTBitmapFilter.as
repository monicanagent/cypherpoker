package {
	import flash.text.TextFormat;
	import flash.text.TextField;
	import flash.filters.BevelFilter;
	import flash.filters.DropShadowFilter;
	import flash.filters.BlurFilter;
	import flash.filters.BitmapFilter;
	import flash.events.MouseEvent;
	import flash.geom.Matrix;
	import flash.display.GradientType;
	import flash.events.Event;
	import flash.display.Sprite;

	import net.kawa.tween.KTween;
	import net.kawa.tween.easing.Linear;

	[SWF(width="320",height="480",frameRate="15",backgroundColor="#FFFFFF")]

	/**
	 * @author Yusuke Kawasaki
	 */
	public class Test_KTBitmapFilter extends Sprite {
		private var circles:Sprite;
		private var filterBlur:BitmapFilter;
		private var filterBevel:BitmapFilter;
		private var filterShadow:BitmapFilter;
		private var clearBlur:Object;
		private var clearShadow:Object;
		private var clearBevel:Object;
		private var textField:TextField;

		public function Test_KTBitmapFilter():void {
			addEventListener(Event.ADDED_TO_STAGE, addedToStageHandler);
		}

		private function addedToStageHandler(event:Event):void {
			var sx:Number = stage.stageWidth;
			var sy:Number = stage.stageHeight;
			var gx:Number = sx / 3;
			var gy:Number = Math.round(gx);

			filterBlur = new BlurFilter(0, 0);
			filterShadow = new DropShadowFilter(0, 0, 0, 0, 0, 0);
			filterBevel = new BevelFilter(0, 0, 0xFFFFFF, 0.5, 0, 0.5, 0, 0);

			clearBlur = {blurX: 0, blurY: 0};
			clearShadow = {angle: 0, distance: 0, blurX: 0, blurY: 0};
			clearBevel = {angle: 0, distance: 0, blurX: 0, blurY: 0};
			
			var bg:Sprite = drawBackground(sx, sy);
			addChild(bg);
			
			circles = drawCircles(sx, sy - gy);
			circles.y = gy;
			addChild(circles);
			
			var boxBlur:Sprite = drawGradientRadial(gx, gy);
			addChild(boxBlur);
			boxBlur.x = gx / 2;
			boxBlur.y = gx / 2;
			boxBlur.addEventListener(MouseEvent.CLICK, applyBlur);
			
			var boxShadow:Sprite = drawGradientRadial(gx, gy);
			addChild(boxShadow);
			boxShadow.x = gx / 2 * 3;
			boxShadow.y = gx / 2;
			boxShadow.addEventListener(MouseEvent.CLICK, applyShadow);

			var boxBevel:Sprite = drawGradientRadial(gx, gy);
			addChild(boxBevel);
			boxBevel.x = gx / 2 * 5;
			boxBevel.y = gx / 2;
			boxBevel.addEventListener(MouseEvent.CLICK, applyBevel);
			
			textField = drawTextField(sx);
			textField.y = sy - textField.textHeight - 2;
			addChild(textField);

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

		private function applyBevel(event:MouseEvent):void {
			event.stopPropagation();
			KTween.abort();
			
			var bx:Number = event.localX;
			var by:Number = event.localY;
			var angle:Number = Math.atan2(by, bx) * 180 / Math.PI;
			var distance:Number = Math.sqrt(bx * bx + by * by) / 10;
			var toBevel:Object = {angle: angle, distance: distance, blurX: 4, blurY: 4};
			if (!event.shiftKey) smartRotate(filterBevel, toBevel, 'angle', 'distance');
			
			KTween.to(filterBlur, 1, clearBlur, Linear.easeOut);
			KTween.to(filterShadow, 1, clearShadow, Linear.easeOut);
			KTween.to(filterBevel, 1, toBevel, Linear.easeOut).onChange = updateFilter;
			
			angle = Math.round(toBevel['angle']);
			distance = Math.round(toBevel['distance'] * 10) / 10;
			textField.text = 'BevelFilter: distance=' + distance + ' angle=' + angle;
		}

		private function applyShadow(event:MouseEvent):void {
			event.stopPropagation();
			KTween.abort();
			
			var bx:Number = event.localX;
			var by:Number = event.localY;
			var angle:Number = Math.atan2(by, bx) * 180 / Math.PI;
			var distance:Number = Math.sqrt(bx * bx + by * by);
			var toShadow:Object = {angle: angle, distance: distance, blurX: distance / 2, blurY: distance / 2, alpha: 0.5};
			if (!event.shiftKey) smartRotate(filterShadow, toShadow, 'angle', 'distance');
			
			KTween.to(filterBlur, 1, clearBlur, Linear.easeOut);
			KTween.to(filterShadow, 1, toShadow, Linear.easeOut).onChange = updateFilter;
			KTween.to(filterBevel, 1, clearBevel, Linear.easeOut);
			
			angle = Math.round(toShadow['angle']);
			distance = Math.round(toShadow['distance'] * 10) / 10;
			textField.text = 'DropShadowFilter: distance=' + distance + ' angle=' + angle;
		}

		private function smartRotate(from:Object, to:Object, angleKey:String, distKey:String):void {
			var toA:Number = to[angleKey] % 360;
			var fromA:Number = from[angleKey] % 360;
			var diff:Number = toA - fromA;
			if (diff < -180) {
				diff += 360;
			} else if (diff > 180) {
				diff -= 360;
			}
			to[angleKey] = fromA + diff;
			
			var toD:Number = to[distKey];
			var fromD:Number = from[distKey];
			if (fromD == 0) {
				from[angleKey] = to[angleKey];
			} else if (toD == 0) {
				to[angleKey] = from[angleKey];
			}
		}

		private function applyBlur(event:MouseEvent):void {
			event.stopPropagation();
			KTween.abort();
			
			var bx:Number = Math.abs(event.localX);
			var by:Number = Math.abs(event.localY);
			var toBlur:Object = {blurX: bx, blurY: by};

			KTween.to(filterBlur, 1, toBlur, Linear.easeOut).onChange = updateFilter;
			KTween.to(filterShadow, 1, clearShadow, Linear.easeOut);
			KTween.to(filterBevel, 1, clearBevel, Linear.easeOut);
			
			by = Math.round(by * 10) / 10;
			bx = Math.round(bx * 10) / 10;
			textField.text = 'DropShadowFilter: blurX=' + bx + ' blurY=' + by;
		}

		private function resetBox(event:MouseEvent):void {
			event.stopPropagation();
			KTween.abort();

			if (!event.shiftKey) smartRotate(filterShadow, clearShadow, 'angle', 'distance');
			if (!event.shiftKey) smartRotate(filterBevel, clearBevel, 'angle', 'distance');
			
			KTween.to(filterBlur, 1, clearBlur, Linear.easeOut);
			KTween.to(filterShadow, 1, clearShadow, Linear.easeOut);
			KTween.to(filterBevel, 1, clearBevel, Linear.easeOut).onChange = updateFilter;
			
			textField.text = 'Reset: ';
		}

		private function drawBackground(sx:Number, sy:Number):Sprite {
			var sp:Sprite = new Sprite();
			sp.graphics.beginFill(0xCCCCCC);
			sp.graphics.drawRect(0, 0, sx, sy);
			sp.graphics.endFill();
			return sp;
		}

		private function drawGradientRadial(gx:Number, gy:Number):Sprite {
			var color2:Array = [0xFFFFFF, 0x000000];
			var alpha2:Array = [1.0, 1.0];
			var ratio2:Array = [0, 255];

			var matrix:Matrix = new Matrix();
			matrix.createGradientBox(gx * 1.4, gy * 1.4, 0, -gx * 0.7, -gy * 0.7);
			var sp:Sprite = new Sprite();
			sp.graphics.beginGradientFill(GradientType.RADIAL, color2, alpha2, ratio2, matrix);
			sp.graphics.drawRect(-gx / 2, -gy / 2, gx, gy);
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

		private function updateFilter():void {
			circles.filters = [filterBevel, filterBlur, filterShadow];
		}
	}
}

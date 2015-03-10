package net.kawa.tween.util {

	/**
	 * Util class for using ColorTransform with KTween.
	 * @author Yusuke Kawasaki
	 * @version 1.0
	 */
	public class KTColorTransformUtil {
		/**
		 * Generates an object to set color for ColorTransform class.
		 * @param color	Color. 0x000000: black, 0xFFFFFF: white.
		 * @param level Level of transition. 0.0: no change, 1.0: replacement.
		 * @return		An object for KTween.
		 */
		public static function color(color:uint, level:Number = 1.0):Object {
			var r:uint = level * (255 & (color >> 16));
			var g:uint = level * (255 & (color >> 8));
			var b:uint = level * (255 & color);
			var m:Number = 1.0 - level;
			return {redMultiplier: m, greenMultiplier: m, blueMultiplier: m, redOffset: r, greenOffset: g, blueOffset: b, alphaMultiplier: 1.0, alphaOffset: 0.0};
		}

		/**
		 * Generates an object to set lightness for ColorTransform class.
		 * @param level Level of lightness. 0.0: no change, 1.0: white.
		 * @return		An object for KTween.
		 */
		public static function lightness(level:Number):Object {
			var w:Number = level * 255;
			var m:Number = 1 - level;
			return {redMultiplier: m, greenMultiplier: m, blueMultiplier: m, redOffset: w, greenOffset: w, blueOffset: w, alphaMultiplier: 1.0, alphaOffset: 0.0};
		}

		/**
		 * Generates an object to set darkness for ColorTransform class.
		 * @param level Level of darkness. 0.0: no change, 1.0: black.
		 * @return		An object for KTween.
		 */
		public static function darkness(level:Number):Object {
			var m:Number = 1 - level;
			return {redMultiplier: m, greenMultiplier: m, blueMultiplier: m, redOffset: 0.0, greenOffset: 0.0, blueOffset: 0.0, alphaMultiplier: 1.0, alphaOffset: 0.0};
		}
	}
}

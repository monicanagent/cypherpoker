package net.kawa.tween.util {

	/**
	 * Util class for KTween. This provides static functions.
	 * @author Yusuke Kawasaki
	 * @version 1.0
	 */
	public class KTUtil {
		/**
		 * Generates an object to reset attribtues of BevelFilter class.
		 * @return	A reset object.
		 */
		public static function resetBevelFilter():Object {
			return {angle: 0.0, blurX: 0.0, blurY: 0.0, distance: 0.0, highlightAlpha: 0.0, shadowAlpha: 0.0, strength: 0.0};
		}

		/**
		 * Generates an object to reset attribtues of BlurFilter class.
		 * @return	A reset object.
		 */
		public static function resetBlurFilter():Object {
			return {blurX: 0.0, blurY: 0.0};
		}

		/**
		 * Generates an object to reset attribtues of DropShadowFilter class.
		 * @return	A reset object.
		 */
		public static function resetDropShadowFilter():Object {
			return {alpha: 0.0, angle: 0.0, blurX: 0.0, blurY: 0.0, distance: 0.0, strength: 0.0};
		}

		/**
		 * Generates an object to reset attribtues of GlowFilter class.
		 * @return	A reset object.
		 */
		public static function resetGlowFilter():Object {
			return {alpha: 0.0, blurX: 0.0, blurY: 0.0, strength: 0.0};
		}

		/**
		 * Generates an object to reset attribtues of Matrix class.
		 * @return	A reset object.
		 */
		public static function resetMatrix():Object {
			return {a: 0.0, b: 0.0, c: 0.0, d: 0.0, tx: 0.0, ty: 0.0};
		}

		/**
		 * Generates an object to reset attribtues of ColorTransform class.
		 * @return	A reset object.
		 */
		public static function resetColorTransform():Object {
			return {alphaMultiplier: 1.0, alphaOffset: 0.0, blueMultiplier: 1.0, blueOffset: 0.0, greenMultiplier: 1.0, greenOffset: 0.0, redMultiplier: 1.0, redOffset: 0.0};
		}

		/**
		 * Generates an object to reset attribtues of Point class.
		 * @return	A reset object.
		 */
		public static function resetPoint():Object {
			return {x: 0.0, y: 0.0};
		}

		/**
		 * Generates an object to reset attribtues of Rectangle class.
		 * @return	A reset object.
		 */
		public static function resetRectangle():Object {
			return {x: 0.0, y: 0.0, width: 0.0, height: 0.0};
		}
	}
}

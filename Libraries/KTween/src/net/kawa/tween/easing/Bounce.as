package net.kawa.tween.easing {

	/**
	 * Bounce
	 * Easing equations (bound) for the KTween class
	 * @author Yusuke Kawasaki
	 * @version 1.0
	 */
	public class Bounce {
		private static const DH:Number = 1 / 22;
		private static const D1:Number = 1 / 11;
		private static const D2:Number = 2 / 11;
		private static const D3:Number = 3 / 11;
		private static const D4:Number = 4 / 11;
		private static const D5:Number = 5 / 11;
		private static const D7:Number = 7 / 11;
		private static const IH:Number = 1 / DH;
		private static const I1:Number = 1 / D1;
		private static const I2:Number = 1 / D2;
		private static const I4D:Number = 1 / D4 / D4;

		/**
		 * Easing equation function for bound tween
		 * @param t		Current time (0.0: begin, 1.0:end)
		 * @return      Current ratio (0.0: begin, 1.0:end) 
		 */
		static public function easeIn(t:Number):Number {
			var s:Number;
			if (t < D1) {
				s = t - DH;
				s = DH - s * s * IH;
			} else if (t < D3) {
				s = t - D2;
				s = D1 - s * s * I1;
			} else if (t < D7) {
				s = t - D5;
				s = D2 - s * s * I2;
			} else {
				s = t - 1;
				s = 1 - s * s * I4D;
			}
			return s;
		}

		/**
		 * Easing equation function for bound tween
		 * @param t		Current time (0.0: begin, 1.0:end)
		 * @return      Current ratio (0.0: begin, 1.0:end) 
		 */
		static public function easeOut(t:Number):Number {
			return 1.0 - easeIn(1.0 - t);
		}

		/**
		 * Easing equation function for bound tween
		 * @param t		Current time (0.0: begin, 1.0:end)
		 * @return      Current ratio (0.0: begin, 1.0:end) 
		 */
		static public function easeInOut(t:Number):Number {
			return (t < 0.5) ? easeIn(t * 2.0) * 0.5 : 1 - easeIn(2.0 - t * 2.0) * 0.5;
		}
	}
}

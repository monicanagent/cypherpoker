package net.kawa.tween.easing {

	/**
	 * Linear
	 * Easing equations (t) for the KTween class
	 * @author Yusuke Kawasaki
	 * @version 1.0
	 */	
	public class Linear {
		/**
		 * Easing equation function for linear tween
		 * @param t		Current time (0.0: begin, 1.0:end)
		 * @return      Current ratio (0.0: begin, 1.0:end) 
		 */
		static public function easeIn(t:Number):Number {
			return t;
		}

		/**
		 * Easing equation function for linear tween
		 * @param t		Current time (0.0: begin, 1.0:end)
		 * @return      Current ratio (0.0: begin, 1.0:end) 
		 */
		static public function easeOut(t:Number):Number {
			return t;
		}

		/**
		 * Easing equation function for linear tween
		 * @param t		Current time (0.0: begin, 1.0:end)
		 * @return      Current ratio (0.0: begin, 1.0:end) 
		 */
		static public function easeInOut(t:Number):Number {
			return t;
		}
	}
}

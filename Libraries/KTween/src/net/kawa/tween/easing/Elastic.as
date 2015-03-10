package net.kawa.tween.easing {

	/**
	 * Elastic
	 * Easing equations (elastic) for the KTween class
	 * @author Yusuke Kawasaki
	 * @version 1.0
	 */
	public class Elastic {
		/**
		 * Easing equation function for elastic tween
		 * @param t		Current time (0.0: begin, 1.0:end)
		 * @return      Current ratio (0.0: begin, 1.0:end) 
		 */
		static public function easeIn(t:Number):Number {
			return 1.0 - easeOut(1.0 - t);
		}

		/**
		 * Easing equation function for elastic tween
		 * @param t		Current time (0.0: begin, 1.0:end)
		 * @return      Current ratio (0.0: begin, 1.0:end) 
		 */
		static public function easeOut(t:Number):Number {
			var s:Number = 1 - t;
			return 1 - Math.pow(s, 8) + Math.sin(t * t * 6 * Math.PI) * s * s;
		}

		/**
		 * Easing equation function for elastic tween
		 * @param t		Current time (0.0: begin, 1.0:end)
		 * @return      Current ratio (0.0: begin, 1.0:end) 
		 */
		static public function easeInOut(t:Number):Number {
			return (t < 0.5) ? easeIn(t * 2.0) * 0.5 : 1 - easeIn(2.0 - t * 2.0) * 0.5;
		}
	}
}

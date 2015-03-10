package net.kawa.tween {
	import flash.utils.getTimer;
	import flash.utils.setTimeout;
	import flash.display.Sprite;
	import flash.events.Event;

	import net.kawa.tween.KTJob;

	/**
	 * Tween job manager class
	 * @author Yusuke Kawasaki
	 * @version 1.0.1
	 * @see net.kawa.tween.KTJob
	 */
	public class KTManager {
		private var stage:Sprite;
		private var running:Boolean = false;
		private var firstJob:KTJob;
		private var lastJob:KTJob;
		private var firstAdded:KTJob;
		private var lastAdded:KTJob;

		/**
		 * Constructs a new KTManager instance.
		 **/
		public function KTManager():void {
			stage = new Sprite();
		}

		/**
		 * Regists a new tween job to the job queue.
		 *
		 * @param job 		A job to be added to queue.
		 * @param delay 	Delay until job started in seconds.
		 **/
		public function queue(job:KTJob, delay:Number = 0):void {
			if (delay > 0) {
				var that:KTManager = this;
				var closure:Function = function ():void {				
					that.queue(job);		
				};
				setTimeout(closure, delay * 1000);
				return;
			}
			job.init();
			if (lastAdded != null) {
				lastAdded.next = job;
			} else {
				firstAdded = job;
			}
			lastAdded = job;

			if (!running) awake();
		}

		private function awake():void {
			if (running) return;
			stage.addEventListener(Event.ENTER_FRAME, enterFrameHandler, false, 0, true);
			running = true;
		}

		private function sleep():void {
			stage.removeEventListener(Event.ENTER_FRAME, enterFrameHandler);
			running = false;
		}

		private function enterFrameHandler(e:Event):void {
			// check new jobs added
			if (firstAdded != null) {
				mergeList();
			}
			
			// check all jobs done
			if (firstJob == null) {
				sleep();
				return;
			}
			
			var curTime:Number = getTimer();
			var prev:KTJob = null;
			var job:KTJob = firstJob;
			for(job = firstJob;job != null;job = job.next) {
				if (job.finished) {
					if (prev == null) {
						firstJob = job.next;
					} else {
						prev.next = job.next;
					}
					if (job.next == null) {
						lastJob = prev;
					}
					job.close();
				} else {
					job.step(curTime);
					prev = job;
				}
			}
		}

		/**
		 * Terminates all tween jobs immediately.
		 * @see net.kawa.tween.KTJob#abort()
		 */
		public function abort():void {
			mergeList();
			var job:KTJob;
			for(job = firstJob;job != null;job = job.next) {
				job.abort();
			}
		}

		/**
		 * Stops and rollbacks to the first (beginning) status of all tween jobs.
		 * @see net.kawa.tween.KTJob#cancel()
		 */
		public function cancel():void {
			mergeList();
			var job:KTJob;
			for(job = firstJob;job != null;job = job.next) {
				job.cancel();
			}
		}

		/**
		 * Forces to finish all tween jobs.
		 * @see net.kawa.tween.KTJob#complete()
		 */
		public function complete():void {
			mergeList();
			var job:KTJob;
			for(job = firstJob;job != null;job = job.next) {
				job.complete();
			}
		}

		/**
		 * Pauses all tween jobs.
		 * @see net.kawa.tween.KTJob#pause()
		 */
		public function pause():void {
			mergeList();
			var job:KTJob;
			for(job = firstJob;job != null;job = job.next) {
				job.pause();
			}
		}

		/**
		 * Proceeds with all tween jobs paused.
		 * @see net.kawa.tween.KTJob#resume()
		 */
		public function resume():void {
			// mergeList(); // this isn't needed
			var job:KTJob;
			for(job = firstJob;job != null;job = job.next) {
				job.resume();
			}
		}

		private function mergeList():void {
			if (!firstAdded) return;
			if (lastJob != null) {
				lastJob.next = firstAdded;	
			} else {
				firstJob = firstAdded;
			}
			lastJob = lastAdded;
			firstAdded = null;
			lastAdded = null;
		}
	}
}

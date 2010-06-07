package rx.tests.operators
{
	import org.flexunit.Assert;
	
	import rx.IObservable;
	import rx.ICancelable;
	import rx.Observable;
	import rx.impl.ClosureScheduledAction;
	import rx.ICancelable;
	import rx.scheduling.IScheduler;
	import rx.tests.mocks.ClosureScheduler;
	import rx.tests.mocks.NullScheduler;
	
	[TestCase]
	public class EmptyFixture
	{
		[Test]
		public function immediately_completes_when_subscribed_to_with_no_scheduler() : void
		{
			var obs : IObservable = Observable.empty();
			
			var completed : Boolean = false;
			
			obs.subscribeFunc(null, function():void
			{
				completed = true;	
			});
			
			Assert.assertTrue(completed);
		}
		
		[Test]
		public function publishing_is_run_through_publishing_scheduler() : void
		{
			var sched : IScheduler = new NullScheduler();
			
			var obs : IObservable = Observable.empty(Object, sched);
			
			var completed : Boolean = false;
			
			obs.subscribeFunc(null, function():void
			{
				completed = true;	
			});
			
			Assert.assertFalse(completed);
		}
		
		[Test]
		public function unsubscribing_does_not_throw_an_error() : void
		{
			var obs : IObservable = Observable.empty();
			
			var subscription : ICancelable = obs.subscribeFunc(null);
			subscription.cancel();
		}
		
		[Test]
        public function schedule_is_cancelled_when_completed() : void
        {
            var disposed : Boolean = false;

            var scheduler : ClosureScheduler = new ClosureScheduler(function(action:Function, dueTime:uint) : ICancelable
            {
            	action();
            	
            	return new ClosureScheduledAction(function():void
            	{
            		disposed = true;
            	});
            });

            var obs : IObservable = Observable.empty(Object, scheduler);

           var subscription : ICancelable = obs.subscribeFunc(null);

            Assert.assertTrue(disposed);
        }
	}
}
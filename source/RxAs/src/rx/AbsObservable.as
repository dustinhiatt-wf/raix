package rx
{
	import flash.errors.IllegalOperationError;
	import flash.utils.getQualifiedClassName;
	
	import rx.impl.ClosureObservable;
	import rx.impl.ClosureObserver;
	import rx.impl.ClosureSubscription;
	import rx.impl.CompositeSubscription;
	import rx.impl.OnCompleted;
	import rx.impl.OnError;
	import rx.impl.OnNext;
	import rx.joins.Pattern;
	import rx.scheduling.IScheduledAction;
	import rx.scheduling.IScheduler;
	import rx.util.ComparerUtil;
	
	public class AbsObservable implements IObservable
	{
		public function AbsObservable()
		{
		}
		
		public function get type() : Class
		{
			return Object;
		}
		
		public function subscribe(observer : IObserver) : ISubscription
		{
			// Abstract methods not supported by AS3
			throw new IllegalOperationError("subscribe() must be overriden");
		}
		
		public function subscribeFunc(onNext : Function, onComplete : Function = null, 
			onError : Function = null) : ISubscription
		{
			var observer : IObserver = new ClosureObserver(onNext, onComplete, onError);
			
			return subscribe(observer);
		}

		public function aggregate(accumulator:Function):IObservable
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function and(right:IObservable):Pattern
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function asynchronous():IObservable
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function bufferWithCount(count:int, skip:int=0):IObservable
		{
			if (count == 0)
			{
				throw new ArgumentError("count must be > 0");
			}
			
			// skip == count and skip == 0 are functionally equivalent
			if (skip == count)
			{
				skip = 0;
			}
			
			var source : IObservable = this;

			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				var buffer : Array = new Array();
				
				var valuesToSkip : uint = 0;
				
				var dec : IObserver = new ClosureObserver(
					function(pl : Object) : void
					{
						buffer.push(pl);
						
						while(buffer.length > 0 && valuesToSkip > 0)
						{
							buffer.shift();
							valuesToSkip--;
						}
						
						if (buffer.length == count)
						{
							observer.onNext(buffer);
							
							if (skip == 0)
							{
								buffer = [];
							}
							else
							{
								valuesToSkip = skip;
								
								while(buffer.length > 0 && valuesToSkip > 0)
								{
									buffer.shift();
									valuesToSkip--;
								}
							}
						}
					},
					function () : void
					{
						if (buffer.length > 0)
						{
							observer.onNext(buffer);
							buffer = [];
						}
						observer.onCompleted();
					},
					function (error : Error) : void
					{
						if (buffer.length > 0)
						{
							observer.onNext(buffer);
							buffer = [];
						}
						observer.onError(error);
					});
					
				return source.subscribe(dec);
			});
		}
		
		public function bufferWithTime(timeMs:int, timeShiftMs:int=0, scheduler:IScheduler=null):IObservable
		{
			if (timeMs == 0)
			{
				throw new ArgumentError("timeMs must be > 0");
			}
			
			// skip == count and skip == 0 are functionally equivalent
			if (timeShiftMs == timeMs)
			{
				timeShiftMs = 0;
			}
			
			var source : IObservable = this;
			
			scheduler = Observable.resolveScheduler(scheduler);

			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				var buffer : Array = new Array();
				var startTime : Number = new Date().time;
				
				var flushBuffer : Function = function():void
				{
					if (buffer.length > 0)
					{
						var outBuffer : Array = new Array(buffer.length);
						
						for (var i:int =0; i<buffer.length; i++)
						{
							outBuffer[i] = buffer[i].value;
						}
						
						observer.onNext(outBuffer);
						
						buffer = [];
					}
					
					
				};
				
				var intervalSubscription : ISubscription = Observable.interval(timeMs, scheduler)
					.subscribeFunc(function(i:int):void
					{
						while(buffer.length > 0 && buffer[0].timestamp < startTime)
						{
							buffer.shift();
						}
						
						flushBuffer();
						
						startTime += timeShiftMs;
					});
				
				var dec : IObserver = new ClosureObserver(
					function(pl : Object) : void
					{
						buffer.push(pl);
					},
					function () : void
					{
						flushBuffer();
						observer.onCompleted();
					},
					function (error : Error) : void
					{
						flushBuffer();
						observer.onError(error);
					});
					
				var subscription : ISubscription = 
					source.timestamp(scheduler).subscribe(dec);
				
				return new ClosureSubscription(function():void 
				{
					subscription.unsubscribe();
					intervalSubscription.unsubscribe();
				});
			});
		}
		
		public function cast(type : Class) : IObservable
		{
			return this.select(type, function(x:Object):Object
			{
				if (x != null)
				{
					var obj : Object = x as type;
					
					if (obj == null)
					{
						var fromType : String = getQualifiedClassName(x);
						var toType : String = getQualifiedClassName(type);
						
						throw new TypeError(
							"Error #1034: Type Coercion failed: cannot convert " +
							fromType + " to " + toType
						);
					}
				}
				
				return x;
			});
		}
		
		public function combineLatest(right:IObservable, selector:Function):IObservable
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function concat(sources:Array, scheduler:IScheduler=null):IObservable
		{
			var source : IObservable = this;
			
			scheduler = scheduler || Observable.resolveScheduler(scheduler);
			
			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				var currentSource : IObservable = source;
			
				var subscription : ISubscription = null;
				
				var remainingSources : Array = [].concat(sources);
				
				var dec : IObserver = null;
				
				var onNext : Function = function onNext(pl : Object) : void
				{
					scheduler.schedule(function():void { observer.onNext(pl); });
				};
				
				var onError : Function = function (error : Error) : void { observer.onError(error); };
				
				var onComplete : Function = function () : void
				{
					subscription.unsubscribe();
					
					if (remainingSources.length > 0)
					{
						trace("concat :: Move to next source");
						
						currentSource = IObservable(remainingSources.shift());
						subscription = currentSource.subscribe(dec);
					}
					else
					{
						trace("concat :: Completed");
						
						observer.onCompleted();
					}
				}
				
				dec = new ClosureObserver(onNext, onComplete, onError);

				subscription = currentSource.subscribe(dec);
				
				return new ClosureSubscription(function():void
				{
					subscription.unsubscribe();
				});
			});
		}
		
		public function contains(value : Object, comparer : Function = null) : IObservable
		{
			var source : IObservable = this;
			
			var defaultComparer : Function = function(a:Object, b:Object) : Boolean { return a == b; }
			
			comparer = (comparer == null)
				? defaultComparer
				: ComparerUtil.normalizeComaparer(comparer);
			
			return new ClosureObservable(Boolean, function(observer : IObserver) : ISubscription
			{
				return source.subscribeFunc(
					function(pl:Object) : void
					{
						var result : Boolean = false
						
						try
						{
							result = (comparer(pl, value) == true);
						}
						catch(err : Error)
						{
							observer.onError(err);
							return;
						}
						
						if (result)
						{
							observer.onNext(true);
							observer.onCompleted();
						}
					},
					
					function():void
					{
						observer.onNext(false);
						observer.onCompleted();
					},
					function(e : Error):void { observer.onError(e); }
				);
			});
		}
		
		public function count():int
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function delay(delayMs:int, scheduler:IScheduler=null):IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				scheduler = scheduler || Observable.resolveScheduler(scheduler);
				
				var scheduledActions : Array = [];
				var nextScheduledAction : IScheduledAction = null;
				var completeScheduledAction : IScheduledAction = null;
				
				var subscription : ISubscription = source.subscribeFunc(
					function(pl : Object) : void
					{
						scheduledActions.push( 
							scheduler.schedule(function():void { observer.onNext(pl); }, delayMs)
						);
					},
					function () : void
					{
						scheduledActions.push( 
							scheduler.schedule(function():void { observer.onCompleted(); }, delayMs)
						);
					},
					function (error : Error) : void { observer.onError(error); }
					);
					
				return new ClosureSubscription(function():void
				{
					while (scheduledActions.length > 0)
					{
						scheduledActions.shift().cancel();
					}
				});
			});
		}
		
		public function delayUntil(dt:Date, scheduler:IScheduler=null):IObservable
		{
			var source : IObservable = this;
			
			var dtValue : Number = dt.time;
			
			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				scheduler = scheduler || Observable.resolveScheduler(scheduler);
				
				var isPastDate : Boolean = (new Date().time >= dtValue);
				var scheduledActions : Array = [];
				
				var subscription : ISubscription = source.materialize().subscribeFunc(
					function(pl : Notification) : void
					{
						var now : Number = 0;
						
						if (!isPastDate)
						{
							now = new Date().time;
							
							if (now >= dtValue)
							{							
								isPastDate = true;
							}
						}
						
						if (isPastDate)
						{
							scheduledActions.push(
								scheduler.schedule(function():void { pl.accept(observer); })
							);
						}
						else
						{
							var delayMs : Number = dtValue - now;
							
							scheduledActions.push( 
								scheduler.schedule(function():void { pl.accept(observer); }, delayMs)
							);
						}
					}
					);
					
				return new ClosureSubscription(function():void
				{
					while(scheduledActions.length > 0)
					{
						scheduledActions.shift().cancel();
					}
					
					subscription.unsubscribe();
				});
			});
		}
		
		public function dematerialize(type : Class):IObservable
		{
			var source : IObservable = this;
			
			if (source.type != Notification)
			{
				throw new ArgumentError("dematerialize can only be called on IObservable of " +
					"Notification, which is returned by materialize");
			}
			
			return new ClosureObservable(type, function(observer : IObserver):ISubscription
			{
				var dec : IObserver = new ClosureObserver(
					function(pl : Notification) : void
					{
						switch(pl.kind)
						{
							case NotificationKind.ON_NEXT:
								observer.onNext(pl.value);
								break;
							case NotificationKind.ON_COMPLETED:
								observer.onCompleted();
								break;
							case NotificationKind.ON_ERROR:
								observer.onError(pl.error);
								break;
						}
					});
					
				return source.subscribe(dec);
			});
		}
		
		public function doAction(nextAction:Function, completeAction:Function = null, errorAction:Function = null):IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				var dec : IObserver = new ClosureObserver(
					function(pl : Object) : void
					{
						try
						{
							if (nextAction != null) nextAction(pl);
						}
						catch(err : Error)
						{
							if (completeAction == null && errorAction == null)
							{
								observer.onError(err);
							}
							else
							{
								throw err;
							}
						}
						
						observer.onNext(pl);
						
					},
					function () : void
					{
						if (completeAction != null)
						{
							completeAction();
						}
						
						observer.onCompleted();
					},
					function (error : Error) : void
					{
						if (errorAction != null)
						{
							errorAction(error);
						}
						
						observer.onError(error);
					});
					
				return source.subscribe(dec);
			});
		}
		
		public function finallyAction(finallyAction:Function):IObservable
		{
			if (finallyAction == null) throw new ArgumentError("finallyAction");
			
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				var dec : IObserver = new ClosureObserver(
					function(pl : Object) : void { observer.onNext(pl); },
					function () : void { finallyAction(); observer.onCompleted(); },
					function (error : Error) : void { finallyAction(); observer.onError(error); });
					
				return source.subscribe(dec);
			});
		}
		
		public function first():IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				var dec : IObserver = new ClosureObserver(
					function(pl : Object) : void
					{
						observer.onNext(pl);
						observer.onCompleted();
					},
					function () : void { observer.onError(new Error("The sequence contained no values")); },
					function (error : Error) : void { observer.onError(error); });
					
				return source.subscribe(dec);
			});
		}
		
		public function firstOrDefault():IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				var dec : IObserver = new ClosureObserver(
					function(pl : Object) : void
					{
						observer.onNext(pl);
						observer.onCompleted();
					},
					function () : void
					{
						observer.onNext(null);
						observer.onCompleted();
					},
					function (error : Error) : void { observer.onError(error); });
					
				return source.subscribe(dec);
			});
		}
		
		public function forkJoin(sources:Array):IObservable
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function asObservable():IObservable
		{
			var source : IObservable = this;
			
			return Observable.defer(source.type, function():IObservable
			{
				return source;
			});
		}
		
		public function distinctUntilChanged(comparer:Function = null):IObservable
		{
			var source : IObservable = this;
			
			var defaultComparer : Function = function(a:Object, b:Object) : Boolean { return a == b; }
			
			comparer = (comparer == null)
				? defaultComparer
				: ComparerUtil.normalizeComaparer(comparer);
			
			return new ClosureObservable(Boolean, function(observer : IObserver) : ISubscription
			{
				var lastValue : Object = null;
				var hasValue : Boolean = false;
				
				return source.subscribeFunc(
					function(pl:Object) : void
					{
						var result : Boolean = false
						
						try
						{
							result = (comparer(lastValue, pl) == true);
						}
						catch(err : Error)
						{
							observer.onError(err);
							return;
						}
						
						if (!(result && hasValue))
						{
							hasValue = true;
							lastValue = pl;
							
							observer.onNext(pl);
						}
					},
					
					function():void { observer.onCompleted(); },
					function(e : Error):void { observer.onError(e); }
				);
			});
		}
		
		public function join(plans:Array):IObservable
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function last():IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				var lastValue : Object = null;
				var hasValue : Boolean = false;
				
				var dec : IObserver = new ClosureObserver(
					function(pl : Object) : void
					{
						lastValue = pl;
						hasValue = true;
					},
					function () : void
					{
						if (hasValue)
						{
							observer.onNext(lastValue);
							observer.onCompleted();
						}
						else
						{
							observer.onError(new Error("The sequence contained no values"));
						}
					},
					function (error : Error) : void { observer.onError(error); });
					
				return source.subscribe(dec);
			});
		}
		
		public function lastOrDefault():IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				var lastValue : Object = null;
				var hasValue : Boolean = false;
				
				var dec : IObserver = new ClosureObserver(
					function(pl : Object) : void
					{
						lastValue = pl;
						hasValue = true;
					},
					function () : void
					{
						if (hasValue)
						{
							observer.onNext(lastValue);
						}
						else
						{
							observer.onNext(null);
						}
						
						observer.onCompleted();
					},
					function (error : Error) : void { observer.onError(error); });
					
				return source.subscribe(dec);
			});
		}
		
		public function latest():Array
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function let(func : Function) : IObservable
		{
			return IObservable(func(this));
		}
		
		public function materialize():IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(Notification, function(observer : IObserver):ISubscription
			{
				var dec : IObserver = new ClosureObserver(
					function(pl : Object) : void { observer.onNext(new OnNext(pl)); },
					function () : void { observer.onNext(new OnCompleted()); observer.onCompleted(); },
					function (error : Error) : void { observer.onNext(new OnError(error)); observer.onCompleted(); });
					
				return source.subscribe(dec);
			});
		}
		
		public function merge(sources : IObservable, scheduler:IScheduler=null):IObservable
		{
			return Observable.merge(this.type, sources.startWith(this), scheduler);
		}
		
		public function mostRecent(initialValue:Object):IObservable
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function ofType(type : Class) : IObservable
		{
			return this.where(function(x:Object):Boolean
			{
				return x is type;
			});
		}
		
		public function observeOn(scheduler:IScheduler):IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				var subscription : ISubscription = null;
				
				var scheduledAction : IScheduledAction = scheduler.schedule(function():void
				{
					subscription = source.subscribe(observer);
				});
				
				return new ClosureSubscription(function():void
				{
					if (subscription == null)
					{
						scheduledAction.cancel();
					}
					else
					{
						subscription.unsubscribe();
					}
				});
			});
		}
				
		public function onErrorResumeNext(sources:Array, scheduler:IScheduler=null):IObservable
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function publish(scheduler:IScheduler=null):Subject
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function removeTimeInterval(type : Class) : IObservable
		{
			if (this.type != TimeInterval)
			{
				throw new IllegalOperationError("Cannot remove timeInterval from observable that is of type " +
					getQualifiedClassName(this.type));
			}
			
			return this.select(type, function(ts:TimeInterval):Object
			{
				return ts.value;
			});
		}
		
		public function removeTimestamp(type : Class) : IObservable
		{
			if (this.type != TimeStamped)
			{
				throw new IllegalOperationError("Cannot remove timestamp from observable that is of type " +
					getQualifiedClassName(this.type));
			}
			
			return this.select(type, function(ts:TimeStamped):Object
			{
				return ts.value;
			});
		}
		
		public function repeat(repeatCount:int=0, scheduler:IScheduler=null):IObservable
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function retry(retryCount:int, scheduler:IScheduler=null):IObservable
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function returnValue(value:Object):IObservable
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function select(result : Class, selector:Function):IObservable
		{
			return selectInternal(result, selector);
		}
		
		private function selectInternal(type : Class, selector:Function, scheduler : IScheduler = null):IObservable
		{
			var source : IObservable = this;
			
			scheduler = Observable.resolveScheduler(scheduler);
			
			return new ClosureObservable(type, function (observer : IObserver) : ISubscription
			{
				var countSoFar : uint = 0;
				
				var subscription : ISubscription;
				
				var decoratorObserver : IObserver = new ClosureObserver(
					function (value : Object) : void
					{
						try
						{
							value = selector(value);
						}
						catch(err : Error)
						{
							observer.onError(err);
							return;
						}
						
						scheduler.schedule(function():void { observer.onNext(value); });
					},
					function () : void { scheduler.schedule(observer.onCompleted); },
					function (error : Error) : void { scheduler.schedule(function():void { observer.onError(error); }); }
					);
				
				subscription = source.subscribe(decoratorObserver);
				
				return subscription;
			});
		}
		
		public function selectMany(type : Class, selector:Function):IObservable
		{
			var source : IObservable = this;
			
			return Observable.merge(type, this.select(IObservable, selector)); 
		}
		
		public function single():IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				var hasValue : Boolean = false;
				var value : Object = null;
				
				var dec : IObserver = new ClosureObserver(
					function(pl : Object) : void
					{
						if (hasValue)
						{
							observer.onError(new Error("The sequence contained more than one value"));
						}
						else
						{
							value = pl;
							hasValue = true;
						}
					},
					function () : void
					{
						if (hasValue)
						{
							observer.onNext(value);
							observer.onCompleted();
						}
						else
						{
							observer.onError(new Error("The sequence contained no values"));
						}
					},
					function (error : Error) : void { observer.onError(error); });
					
				return source.subscribe(dec);
			});
		}
		
		public function singleOrDefault():IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function(observer : IObserver):ISubscription
			{
				var hasValue : Boolean = false;
				var value : Object = null;
				
				var dec : IObserver = new ClosureObserver(
					function(pl : Object) : void
					{
						if (hasValue)
						{
							observer.onError(new Error("The sequence contained more than one value"));
						}
						else
						{
							value = pl;
							hasValue = true;
						}
					},
					function () : void
					{
						observer.onNext(value);
						observer.onCompleted();
					},
					function (error : Error) : void { observer.onError(error); });
					
				return source.subscribe(dec);
			});
		}
		
		public function skip(count:int):IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function (observer : IObserver) : ISubscription
			{
				var skippedSoFar : uint = 0;
				
				var subscription : ISubscription;
				
				var decoratorObserver : IObserver = new ClosureObserver(
					function (value : Object) : void
					{
						if (++skippedSoFar > count)
						{
							observer.onNext(value);
						}
					},
					function () : void { observer.onCompleted(); },
					function (error : Error) : void { observer.onError(error); }
					);
				
				subscription = source.subscribe(decoratorObserver);
				
				return subscription;
			});
		}
		
		public function skipUntil(other:IObservable):IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function (observer : IObserver) : ISubscription
			{
				var subscription : ISubscription;
				
				var pastSkip : Boolean = false;
				
				var primarySubscription : ISubscription;
				var otherSubscription : ISubscription;
				
				primarySubscription = source.subscribeFunc(
					function (value : Object) : void
					{
						if (pastSkip)
						{
							observer.onNext(value);
						}
					},
					function () : void { observer.onCompleted(); },
					function (error : Error) : void { observer.onError(error); }
					);
					
				otherSubscription = other.subscribeFunc(
					function (value : Object) : void
					{
						pastSkip = true;
						if (otherSubscription != null)
						{
							otherSubscription.unsubscribe();
						}
					},
					function () : void  { },
					function (error : Error) : void  { observer.onError(error); }
					);
				
				if (pastSkip)
				{
					otherSubscription.unsubscribe();
					otherSubscription = null;
				}
				
				return new ClosureSubscription(function():void
				{
					if (primarySubscription != null)
					{
						primarySubscription.unsubscribe();
					}
					
					if (otherSubscription != null)
					{
						otherSubscription.unsubscribe();
					}
				});
			});
		}
		
		public function skipWhile(predicate:Function):IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function (observer : IObserver) : ISubscription
			{
				var skipping : Boolean = true;
				
				var decoratorObserver : IObserver = new ClosureObserver(
					function (value : Object) : void
					{
						if (skipping)
						{
							try
							{
								skipping &= predicate(value);
							}
							catch(err : Error)
							{
								observer.onError(err);
							}
						}
						
						if (!skipping)
						{
							observer.onNext(value);
						}
					},
					function () : void { observer.onCompleted(); },
					function (error : Error) : void { observer.onError(error); }
					);
				
				return source.subscribe(decoratorObserver);
			});
		}
		
		public function startWith(value : Object) : IObservable
		{
			return Observable.returnValue(this.type, value).concat([this]);
		}

		public function sum():Number
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function take(count:int, scheduler:IScheduler=null):IObservable
		{
			var source : IObservable = this;
			
			scheduler = Observable.resolveScheduler(scheduler);
			
			return new ClosureObservable(source.type, function (observer : IObserver) : ISubscription
			{
				var countSoFar : uint = 0;
				
				var subscription : ISubscription;
				
				var decoratorObserver : IObserver = new ClosureObserver(
					function (value : Object) : void
					{
						scheduler.schedule(function():void { observer.onNext(value); });
						
						if (++countSoFar == count)
						{
							subscription.unsubscribe();
							scheduler.schedule(function():void { observer.onCompleted(); });
						}
					},
					function () : void { scheduler.schedule(function():void { observer.onCompleted(); }); },
					function (error : Error) : void { scheduler.schedule(function():void { observer.onError(error); }); }
					);
				
				subscription = source.subscribe(decoratorObserver);
				
				return subscription;
			});
		}
		
		public function takeUntil(other:IObservable):IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function (observer : IObserver) : ISubscription
			{
				var subscription : ISubscription;
				
				var primarySubscription : ISubscription;
				var otherSubscription : ISubscription;
				
				primarySubscription = source.subscribeFunc(
					function (value : Object) : void
					{
						observer.onNext(value);
					},
					function () : void { observer.onCompleted(); },
					function (error : Error) : void { observer.onError(error); }
					);
					
				otherSubscription = other.subscribeFunc(
					function (value : Object) : void { observer.onCompleted(); },
					function () : void  { observer.onCompleted(); },
					function (error : Error) : void  { observer.onError(error); }
					);
				
				return new ClosureSubscription(function():void
				{
					if (primarySubscription != null)
					{
						primarySubscription.unsubscribe();
					}
					
					if (otherSubscription != null)
					{
						otherSubscription.unsubscribe();
					}
				});
			});
		}
		
		public function takeWhile(predicate:Function):IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function (observer : IObserver) : ISubscription
			{
				var decoratorObserver : IObserver = new ClosureObserver(
					function (value : Object) : void
					{
						var result : Boolean = false;
						
						try
						{
							result = predicate(value);
						}
						catch(err : Error)
						{
							observer.onError(err);
						}
							
						if (result)
						{
							observer.onNext(value);
						}
						else
						{
							observer.onCompleted();
						}
					},
					function () : void { observer.onCompleted(); },
					function (error : Error) : void { observer.onError(error); }
					);
				
				return source.subscribe(decoratorObserver);
			});
		}
		
		public function throttle(dueTimeMs:int, scheduler:IScheduler=null):IObservable
		{
			var source : IObservable = this;
			
			scheduler = Observable.resolveScheduler(scheduler);
			
			return new ClosureObservable(source.type, function (observer : IObserver) : ISubscription
			{
				var lastValueTimestamp : Number = 0;
				
				var subscription : ISubscription;
				
				var decoratorObserver : IObserver = new ClosureObserver(
					function (value : TimeStamped) : void
					{
						var diffMs : Number = value.timestamp - lastValueTimestamp;
						
						if (diffMs > dueTimeMs)
						{
							lastValueTimestamp = value.timestamp;
							
							scheduler.schedule(function():void { observer.onNext(value.value); });
						}
					},
					function () : void { scheduler.schedule(function():void { observer.onCompleted(); }); },
					function (error : Error) : void { scheduler.schedule(function():void { observer.onError(error); }); }
					);
				
				subscription = source.timestamp().subscribe(decoratorObserver);
				
				return subscription;
			});
		}
		
		public function throwError(error:Error):IObservable
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function timeInterval(scheduler:IScheduler=null):IObservable
		{
			var source : IObservable = this;
			
			scheduler = Observable.resolveScheduler(scheduler);
			
			return new ClosureObservable(TimeInterval, function (observer : IObserver) : ISubscription
			{
				var lastTimeMs : Number = -1;
				
				var decoratorObserver : IObserver = new ClosureObserver(
					function (value : Object) : void
					{
						var now : Number = (new Date()).time;
						var interval : Number = (lastTimeMs == -1)
							? 0
							: now - lastTimeMs;
							
						lastTimeMs = now;
							
						var intervalValue : TimeInterval = new TimeInterval(value, interval);
							
						scheduler.schedule(
							function():void { observer.onNext(intervalValue); });
					},
					function () : void { observer.onCompleted(); },
					function (error : Error) : void { observer.onError(error); }
					);
				
				return source.subscribe(decoratorObserver);
			});
		}
		
		public function timeout(timeoutMs:int, other:IObservable=null, scheduler:IScheduler=null):IObservable
		{
			var source : IObservable = this;
			
			scheduler = Observable.resolveScheduler(scheduler);
			
			return new ClosureObservable(source.type, function (observer : IObserver) : ISubscription
			{
				var subscription : ISubscription = null;
				
				var timeout : Function = function():void
				{
					if (other == null)
					{
						observer.onError(new TimeoutError("Sequence timed out"));
					}
					else
					{
						subscription.unsubscribe();
						subscription = other.subscribe(observer);
					}
				};
				
				var timeoutAction : IScheduledAction = scheduler.schedule(timeout, timeoutMs);
				
				subscription = source.subscribeFunc(
					function (value : Object) : void
					{
						timeoutAction.cancel();
						timeoutAction = scheduler.schedule(timeout, timeoutMs);
						
						observer.onNext(value);
					},
					function () : void
					{
						timeoutAction.cancel();
						observer.onCompleted();
					},
					function (error : Error) : void { observer.onError(error); }
					);
				
				return new ClosureSubscription(function():void
				{
					subscription.unsubscribe();
				});
			});
		}
		
		public function timer(dueTimeMs:int):IObservable
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function timestamp(scheduler:IScheduler=null):IObservable
		{
			return selectInternal(TimeStamped, function(value : Object) : TimeStamped
			{
				return new TimeStamped(value, new Date().getTime());
			}, scheduler);
		}
		
		public function toAsync(func:Function):IObservable
		{
			throw new IllegalOperationError("Not implemented");
		}
		
		public function where(predicate:Function):IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(source.type, function (observer : IObserver) : ISubscription
			{
				var decoratorObserver : IObserver = new ClosureObserver(
					function (value : Object) : void
					{
						var result : Boolean = false;
						
						try
						{
							result = predicate(value);
						}
						catch(err : Error)
						{
							observer.onError(err);
						}
							
						if (result)
						{
							observer.onNext(value);
						}
					},
					function () : void { observer.onCompleted(); },
					function (error : Error) : void { observer.onError(error); }
					);
				
				return source.subscribe(decoratorObserver);
			});
		}
		
		public function zip(resultType : Class, rightSource:IObservable, selector:Function):IObservable
		{
			var source : IObservable = this;
			
			return new ClosureObservable(resultType, function (observer : IObserver) : ISubscription
			{
				var leftValues : Array = new Array();
				var rightValues : Array = new Array();
				
				var leftSubscription : ISubscription, 
					rightSubscription : ISubscription;
				
				var unsubscribeAll : Function = function():void
				{
					if (leftSubscription != null)
					{
						leftSubscription.unsubscribe();
						leftSubscription = null;
					}
					
					if (rightSubscription != null)
					{
						rightSubscription.unsubscribe();
						rightSubscription = null;
					}
				};				
				
				var leftObserver : IObserver = new ClosureObserver(
					function (value : Object) : void
					{
						trace("zip :: left");
						
						if (rightValues.length > 0)
						{
							value = selector(value, rightValues.shift());
							
							observer.onNext(value);
						}
						else
						{
							leftValues.push(value);
						}
					},
					function () : void { unsubscribeAll(); observer.onCompleted(); },
					function (error : Error) : void { unsubscribeAll(); observer.onError(error); }
					);
					
				var rightObserver : IObserver = new ClosureObserver(
					function (value : Object) : void
					{
						trace("zip :: right");
						
						if (leftValues.length > 0)
						{
							value = selector(leftValues.shift(), value);
							
							observer.onNext(value);
						}
						else
						{
							rightValues.push(value);
						}
					},
					function () : void { unsubscribeAll(); observer.onCompleted(); },
					function (error : Error) : void { unsubscribeAll(); observer.onError(error); }
					);
					
				leftSubscription = source.subscribe(leftObserver);
				rightSubscription = rightSource.subscribe(rightObserver);
				
				return new ClosureSubscription(function():void
				{
					if (leftSubscription != null)
					{
						leftSubscription.unsubscribe();
						leftSubscription = null;
					}
					
					if (rightSubscription != null)
					{
						rightSubscription.unsubscribe();
						rightSubscription = null;
					}
				});
			});
		}		
	}
}
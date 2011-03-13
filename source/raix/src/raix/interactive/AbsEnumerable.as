package raix.interactive
{
	import flash.errors.IllegalOperationError;
	import flash.utils.Proxy;
	import flash.utils.flash_proxy;
	
	import raix.reactive.ICancelable;
	import raix.reactive.IObservable;
	import raix.reactive.IObserver;
	import raix.reactive.Observable;
	import raix.reactive.scheduling.IScheduler;
	import raix.reactive.scheduling.Scheduler;
	
	public class AbsEnumerable extends Proxy implements IEnumerable
	{
		private var _currentEnumerator : IEnumerator;
		private var _currentIndex : int = 0;
		
		public function AbsEnumerable()
		{
		}
		
		public function any(predicate : Function = null) : Boolean
		{
			for each(var value : Object in this)
			{
				if (predicate == null)
				{
					return true;
				}
				else
				{
					if (predicate(value))
					{
						return true;
					}
				}
			}
			
			return false;
		}
		
		public function all(predicate : Function) : Boolean
		{
			if (predicate == null)
			{
				throw new ArgumentError("predicate cannot be null");
			}
			
			for each(var value : Object in this)
			{
				if (!predicate(value))
				{
					return false;
				}
			}
			
			return true;
		}
		
		public function first(predicate : Function = null) : Object
		{
			for each(var value : Object in this)
			{
				if (predicate == null || predicate(value))
				{
					return value;
				}
			}
			
			throw new IllegalOperationError("No matching items found");
		}
		
		public function firstOrDefault(defaultValue : Object = null, predicate : Function = null) : Object
		{
			for each(var value : Object in this)
			{
				if (predicate == null || predicate(value))
				{
					return value;
				}
			}
			
			return defaultValue;
		}
		
		public function single(predicate : Function = null) : Object
		{
			var matchedAny : Boolean = false;
			var matchedValue : Object = null;
			
			for each(var value : Object in this)
			{
				if (predicate == null || predicate(value))
				{
					if (matchedAny)
					{
						throw new IllegalOperationError("Sequence contained multiple elements");
					}
					else
					{
						matchedAny = true;
						matchedValue = value;
					}
				}
			}
			
			if (matchedAny)
			{
				return matchedValue;
			}
			
			throw new IllegalOperationError("No matching items found");
		}
		
		public function singleOrDefault(defaultValue : Object = null, predicate : Function = null) : Object
		{
			var matchedAny : Boolean = false;
			var matchedValue : Object = null;
			
			for each(var value : Object in this)
			{
				if (predicate == null || predicate(value))
				{
					if (matchedAny)
					{
						throw new IllegalOperationError("Sequence contained multiple elements");
					}
					else
					{
						matchedAny = true;
						matchedValue = value;
					}
				}
			}
			
			if (matchedAny)
			{
				return matchedValue;
			}
			
			return defaultValue;
		}
		
		public function last(predicate : Function = null) : Object
		{
			var matchedAny : Boolean = false;
			var matchedValue : Object = null;
			
			for each(var value : Object in this)
			{
				if (predicate == null || predicate(value))
				{
					matchedAny = true;
					matchedValue = value;
				}
			}
			
			if (matchedAny)
			{
				return matchedValue;
			}
			
			throw new IllegalOperationError("No matching items found");
		}
		
		public function lastOrDefault(defaultValue : Object = null, predicate : Function = null) : Object
		{
			var matchedAny : Boolean = false;
			var matchedValue : Object = null;
			
			for each(var value : Object in this)
			{
				if (predicate == null || predicate(value))
				{
					matchedAny = true;
					matchedValue = value;
				}
			}
			
			if (matchedAny)
			{
				return matchedValue;
			}
			
			return defaultValue;
		}
		
		public function defaultIfEmpty(defaultValue : Object = null) : IEnumerable
		{
			var source : IEnumerable = this;
			
			return new ClosureEnumerable(function():IEnumerator
			{
				var isFirst : Boolean = true;
				var usedDefault : Boolean = false;
				var innerEnumerator : IEnumerator = source.getEnumerator(); 
				
				return new ClosureEnumerator(function():Boolean
				{
					if (usedDefault)
					{
						return false;
					}
					
					if (!innerEnumerator.moveNext())
					{
						if (isFirst)
						{
							usedDefault = true;
							return true;
						}
						
						return false;
					}
					
					isFirst = false;
					return true;
					
				}, function():Object
				{
					if (usedDefault)
					{
						return defaultValue;
					}
					
					return innerEnumerator.current;
				});
			});
		}
		
		public function concat(other : IEnumerable) : IEnumerable
		{
			var source : IEnumerable = this;
			
			return new ClosureEnumerable(function():IEnumerator
			{
				var isFirst : Boolean = true;
				var innerEnumerator : IEnumerator = source.getEnumerator(); 
				
				return new ClosureEnumerator(function():Boolean
				{
					if (!innerEnumerator.moveNext())
					{
						if (isFirst)
						{
							isFirst = false;
							innerEnumerator = other.getEnumerator();
							
							return innerEnumerator.moveNext();
						}
						else
						{
							return false;
						}
					}
					
					return true;
				},
				function():Object { return innerEnumerator.current; });
			});
		}
		
		public function take(count : int) : IEnumerable
		{
			var source : IEnumerable = this;
			
			return new ClosureEnumerable(function():IEnumerator
			{
				var currentCount : int = 0;
				var innerEnumerator : IEnumerator = source.getEnumerator(); 
				
				return new ClosureEnumerator(function():Boolean
				{
					return (currentCount++ < count) && innerEnumerator.moveNext(); 
				},
				function():Object { return innerEnumerator.current; });
			});
		}
		
		public function map(selector : Function) : IEnumerable
		{
			var source : IEnumerable = this;
			
			return new ClosureEnumerable(function():IEnumerator
			{
				var innerEnumerator : IEnumerator = source.getEnumerator();
				
				var currentValue : Object = null; 
				
				return new ClosureEnumerator(function():Boolean
				{
					if (innerEnumerator.moveNext())
					{
						currentValue = selector(innerEnumerator.current);
						return true;
					} 
					else
					{
						return false;
					}
				},
				function():Object { return currentValue; });
			});
		}
		
		public function mapMany(collectionSelector : Function, resultSelector : Function = null) : IEnumerable
		{
			if (collectionSelector == null)
			{
				throw new ArgumentError("collectionSelector cannot be null");
			}
			
			var source : IEnumerable = this;
			
			return new ClosureEnumerable(function():IEnumerator
			{
				var leftEnumerator : IEnumerator = source.getEnumerator();
				var rightEnumerator : IEnumerator = null; 
				
				var currentValue : Object = null;
				var leftIndex : int = -1;
				
				var rightMoveNext : Function = function():Boolean
				{
					if (rightEnumerator.moveNext())
					{
						if (resultSelector != null)
						{
							currentValue = resultSelector(
								leftEnumerator.current,
								rightEnumerator.current);
						}
						else
						{
							currentValue = rightEnumerator.current;
						}
						
						return true;
					}
					
					rightEnumerator = null;
						
					return false;
				};
				
				return new ClosureEnumerator(function():Boolean
				{
					if (rightEnumerator != null && rightMoveNext())
					{
						return true;
					}
					
					while (leftEnumerator.moveNext())
					{
						rightEnumerator = IEnumerable(collectionSelector(
							leftEnumerator.current, ++leftIndex)).getEnumerator();
						
						if (rightMoveNext())
						{
							return true;
						}
					} 
					
					return false;
				},
				function():Object { return currentValue; });
			});
		}
		
		public function filter(predicate : Function) : IEnumerable
		{
			var source : IEnumerable = this;
			
			return new ClosureEnumerable(function():IEnumerator
			{
				var innerEnumerator : IEnumerator = source.getEnumerator(); 
				
				return new ClosureEnumerator(function():Boolean
				{
					while(innerEnumerator.moveNext())
					{
						if (predicate(innerEnumerator.current))
						{
							return true;
						}
					}
					
					return false;
				},
				function():Object { return innerEnumerator.current; });
			});
		}
		
		public function repeat(count : uint = 0) : IEnumerable
		{
			var source : IEnumerable = this;
			
			return new ClosureEnumerable(function():IEnumerator
			{
				var repetitionsRemaining : uint = count;
				var innerEnumerator : IEnumerator = source.getEnumerator(); 
				
				return new ClosureEnumerator(function():Boolean
				{
					if (!innerEnumerator.moveNext())
					{
						if (count == 0 || --repetitionsRemaining > 0)
						{
							innerEnumerator = source.getEnumerator();
							
							return innerEnumerator.moveNext();
						}
						else
						{
							return false;
						}
					}
					
					return true;
				},
				function():Object { return innerEnumerator.current; });
			});
		}
		
		public function count() : uint
		{
			var count : uint = 0;
			
			for each(var val : Object in this)
			{
				count++;
			} 
			
			return count;
		}
		
		public function toObservable(scheduler : IScheduler = null) : IObservable
		{
			scheduler = scheduler || Scheduler.asynchronous;
			
			var source : IEnumerable = this;
			
			return Observable.createWithCancelable(Object, function(observer : IObserver) : ICancelable
			{
				var enumerator : IEnumerator = source.getEnumerator(); 
				
				return Scheduler.scheduleRecursive(scheduler, function(reschedule : Function) : void
				{
					var valueAvailable : Boolean;
							
					try
					{
						valueAvailable = enumerator.moveNext();
					}
					catch(error : Error)
					{
						observer.onError(error);
						return;
					}
					
					if (valueAvailable)
					{
						observer.onNext(enumerator.current);
						
						reschedule();
					}
					else
					{
						observer.onCompleted();
					}
				});
			});
		}
		
		public function toArray() : Array
		{
			var output : Array = new Array();
			
			for each(var value : Object in this)
			{
				output.push(value);
			}
			
			return output;
		}
		
		override flash_proxy function nextNameIndex(index:int):int
		{
			if (index == 0)
            {
            	reset();
            	
            	_currentEnumerator = getEnumerator();
            }
            else
            {
            	if (_currentIndex != index)
            	{
            		throw new IllegalOperationError("Parallel enumerations are not supported");
            	}
            }
            
            if (_currentEnumerator.moveNext())
            {
            	_currentIndex = index+1;
            	
            	return _currentIndex;
            }
            else
            {
            	reset();
            	
            	return 0;
            }
		}
		
		override flash_proxy function nextValue(index:int):*
		{
            return _currentEnumerator.current;
        }
		
        public function cancel() : void
        {
        	
        }
		
		public function getEnumerator() : IEnumerator
		{
			throw new IllegalOperationError("abstract method getEnumerator not implemented");
		}
		
		private function reset() : void
        {
        	_currentEnumerator = null;
        	_currentIndex = 0;
        }
	}
}